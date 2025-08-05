#!/bin/bash

# 🎤 Script de Instalação Automatizada - WhisperX API
# Este script instala e configura a API de transcrição WhisperX em uma VPS sem GPU

set -e  # Parar em caso de erro

echo "🎤 Iniciando instalação da WhisperX API..."
echo "=================================================="

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se está rodando como usuário normal (não root)
if [ "$EUID" -eq 0 ]; then
    log_error "Não execute este script como root. Use um usuário normal com sudo."
    exit 1
fi

# Verificar se sudo está disponível
if ! command -v sudo &> /dev/null; then
    log_error "sudo não está instalado. Instale sudo primeiro."
    exit 1
fi

log_info "Verificando sistema operacional..."
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    log_error "Este script é apenas para sistemas Linux."
    exit 1
fi

# Atualizar sistema
log_info "Atualizando sistema..."
sudo apt update && sudo apt upgrade -y

# Instalar dependências do sistema
log_info "Instalando dependências do sistema..."
sudo apt install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3-pip \
    ffmpeg \
    git \
    curl \
    wget \
    build-essential \
    pkg-config \
    libssl-dev

# Verificar se Python 3.11 foi instalado
if ! command -v python3.11 &> /dev/null; then
    log_error "Python 3.11 não foi instalado corretamente."
    exit 1
fi

log_success "Dependências do sistema instaladas!"

# Instalar Rust
log_info "Instalando Rust..."
if ! command -v rustc &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
    log_success "Rust instalado!"
else
    log_info "Rust já está instalado."
fi

# Criar diretório de trabalho
WORK_DIR="$HOME/whisperx_transcription"
log_info "Criando diretório de trabalho: $WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Clonar WhisperX
log_info "Clonando repositório WhisperX..."
if [ ! -d "whisperX" ]; then
    git clone https://github.com/m-bain/whisperX.git
    log_success "WhisperX clonado!"
else
    log_info "WhisperX já existe, atualizando..."
    cd whisperX
    git pull
    cd ..
fi

# Criar aplicação Flask
log_info "Criando aplicação Flask..."
if [ ! -d "whisperx_api" ]; then
    # Simular o comando manus-create-flask-app
    mkdir -p whisperx_api/{src/{routes,models,static,database},venv}
    cd whisperx_api
    
    # Criar ambiente virtual
    python3.11 -m venv venv
    source venv/bin/activate
    
    # Instalar Flask básico
    pip install --upgrade pip
    pip install flask flask-cors flask-sqlalchemy
    
    log_success "Estrutura Flask criada!"
else
    log_info "Aplicação Flask já existe."
    cd whisperx_api
    source venv/bin/activate
fi

# Instalar PyTorch CPU
log_info "Instalando PyTorch para CPU..."
pip install torch==2.5.1+cpu torchaudio==2.5.1+cpu --index-url https://download.pytorch.org/whl/cpu

# Instalar WhisperX
log_info "Instalando WhisperX..."
pip install ../whisperX

# Criar arquivos da aplicação
log_info "Criando arquivos da aplicação..."

# Criar main.py
cat > src/main.py << 'EOF'
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from flask import Flask, send_from_directory
from flask_cors import CORS
from src.routes.transcription import transcription_bp

app = Flask(__name__, static_folder=os.path.join(os.path.dirname(__file__), 'static'))
app.config['SECRET_KEY'] = 'whisperx-api-secret-key-change-in-production'

# Habilitar CORS
CORS(app)

# Registrar blueprints
app.register_blueprint(transcription_bp, url_prefix='/api')

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def serve(path):
    static_folder_path = app.static_folder
    if static_folder_path is None:
        return "Static folder not configured", 404

    if path != "" and os.path.exists(os.path.join(static_folder_path, path)):
        return send_from_directory(static_folder_path, path)
    else:
        index_path = os.path.join(static_folder_path, 'index.html')
        if os.path.exists(index_path):
            return send_from_directory(static_folder_path, 'index.html')
        else:
            return "index.html not found", 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

# Criar routes/transcription.py
mkdir -p src/routes
cat > src/routes/transcription.py << 'EOF'
import os
import tempfile
import whisperx
from flask import Blueprint, request, jsonify
from werkzeug.utils import secure_filename

transcription_bp = Blueprint('transcription', __name__)

ALLOWED_EXTENSIONS = {'wav', 'mp3', 'mp4', 'avi', 'mov', 'flv', 'm4a', 'aac', 'ogg', 'wma'}
MAX_FILE_SIZE = 100 * 1024 * 1024  # 100MB

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@transcription_bp.route('/transcribe', methods=['POST'])
def transcribe_audio():
    try:
        if 'audio' not in request.files:
            return jsonify({'error': 'Nenhum arquivo de áudio foi enviado'}), 400
        
        file = request.files['audio']
        
        if file.filename == '':
            return jsonify({'error': 'Nenhum arquivo selecionado'}), 400
        
        if not allowed_file(file.filename):
            return jsonify({'error': 'Tipo de arquivo não suportado'}), 400
        
        file.seek(0, os.SEEK_END)
        file_size = file.tell()
        file.seek(0)
        
        if file_size > MAX_FILE_SIZE:
            return jsonify({'error': 'Arquivo muito grande. Máximo permitido: 100MB'}), 400
        
        filename = secure_filename(file.filename)
        temp_dir = tempfile.mkdtemp()
        temp_path = os.path.join(temp_dir, filename)
        file.save(temp_path)
        
        try:
            device = "cpu"
            compute_type = "int8"
            
            model = whisperx.load_model("base", device, compute_type=compute_type)
            audio = whisperx.load_audio(temp_path)
            result = model.transcribe(audio, batch_size=16)
            
            try:
                model_a, metadata = whisperx.load_align_model(language_code=result["language"], device=device)
                result = whisperx.align(result["segments"], model_a, metadata, audio, device, return_char_alignments=False)
            except:
                pass  # Continuar sem alinhamento se falhar
            
            response = {
                'success': True,
                'language': result.get("language", "unknown"),
                'segments': result["segments"],
                'text': ' '.join([segment['text'] for segment in result["segments"]])
            }
            
            return jsonify(response), 200
            
        except Exception as e:
            return jsonify({'error': f'Erro durante a transcrição: {str(e)}'}), 500
        
        finally:
            try:
                os.remove(temp_path)
                os.rmdir(temp_dir)
            except:
                pass
    
    except Exception as e:
        return jsonify({'error': f'Erro interno do servidor: {str(e)}'}), 500

@transcription_bp.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'message': 'API de transcrição WhisperX está funcionando',
        'device': 'cpu',
        'compute_type': 'int8'
    }), 200
EOF

# Criar interface web simples
cat > src/static/index.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WhisperX API - Transcrição de Áudio</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { text-align: center; color: #333; }
        .upload-area { border: 2px dashed #ccc; padding: 40px; text-align: center; margin: 20px 0; border-radius: 10px; }
        .btn { background: #007bff; color: white; padding: 12px 24px; border: none; border-radius: 5px; cursor: pointer; margin: 10px; }
        .btn:disabled { background: #ccc; cursor: not-allowed; }
        .result { margin-top: 20px; padding: 20px; border-radius: 5px; }
        .success { background: #d4edda; color: #155724; }
        .error { background: #f8d7da; color: #721c24; }
        .transcription { background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; white-space: pre-wrap; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎤 WhisperX API - Transcrição de Áudio</h1>
        <div class="upload-area">
            <p>Selecione um arquivo de áudio para transcrição</p>
            <input type="file" id="audioFile" accept="audio/*,video/*">
            <br><br>
            <button class="btn" onclick="transcribe()">Transcrever</button>
        </div>
        <div id="result"></div>
    </div>

    <script>
        async function transcribe() {
            const fileInput = document.getElementById('audioFile');
            const resultDiv = document.getElementById('result');
            
            if (!fileInput.files[0]) {
                alert('Selecione um arquivo primeiro!');
                return;
            }
            
            const formData = new FormData();
            formData.append('audio', fileInput.files[0]);
            
            resultDiv.innerHTML = '<div class="result">🔄 Transcrevendo... Aguarde...</div>';
            
            try {
                const response = await fetch('/api/transcribe', {
                    method: 'POST',
                    body: formData
                });
                
                const data = await response.json();
                
                if (response.ok) {
                    resultDiv.innerHTML = `
                        <div class="result success">
                            <h3>✅ Transcrição Concluída</h3>
                            <p><strong>Idioma:</strong> ${data.language}</p>
                            <div class="transcription">${data.text}</div>
                        </div>
                    `;
                } else {
                    resultDiv.innerHTML = `
                        <div class="result error">
                            <h3>❌ Erro</h3>
                            <p>${data.error}</p>
                        </div>
                    `;
                }
            } catch (error) {
                resultDiv.innerHTML = `
                    <div class="result error">
                        <h3>❌ Erro de Conexão</h3>
                        <p>${error.message}</p>
                    </div>
                `;
            }
        }
    </script>
</body>
</html>
EOF

# Atualizar requirements.txt
pip freeze > requirements.txt

log_success "Aplicação criada com sucesso!"

# Configurar firewall (se ufw estiver instalado)
if command -v ufw &> /dev/null; then
    log_info "Configurando firewall..."
    sudo ufw allow 5000/tcp
    log_success "Porta 5000 liberada no firewall!"
fi

# Criar script de inicialização
cat > start_api.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
echo "🎤 Iniciando WhisperX API..."
echo "Acesse: http://$(hostname -I | awk '{print $1}'):5000"
python src/main.py
EOF

chmod +x start_api.sh

# Criar script de inicialização como serviço
cat > whisperx-api.service << EOF
[Unit]
Description=WhisperX Transcription API
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PWD
Environment=PATH=$PWD/venv/bin
ExecStart=$PWD/venv/bin/python src/main.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

log_info "Criando serviço systemd..."
sudo cp whisperx-api.service /etc/systemd/system/
sudo systemctl daemon-reload

# Testar a instalação
log_info "Testando a instalação..."
python -c "import whisperx; print('WhisperX importado com sucesso!')"

# Mostrar informações finais
echo ""
echo "=================================================="
log_success "🎉 Instalação concluída com sucesso!"
echo "=================================================="
echo ""
echo "📁 Localização da aplicação: $PWD"
echo "🚀 Para iniciar a API:"
echo "   cd $PWD"
echo "   ./start_api.sh"
echo ""
echo "🌐 Para acessar a interface web:"
echo "   http://$(hostname -I | awk '{print $1}'):5000"
echo ""
echo "🔧 Para iniciar como serviço:"
echo "   sudo systemctl enable whisperx-api"
echo "   sudo systemctl start whisperx-api"
echo ""
echo "📊 Para verificar status do serviço:"
echo "   sudo systemctl status whisperx-api"
echo ""
echo "📝 Logs do serviço:"
echo "   sudo journalctl -u whisperx-api -f"
echo ""
echo "🔥 Para parar o serviço:"
echo "   sudo systemctl stop whisperx-api"
echo ""
echo "=================================================="
log_warning "IMPORTANTE:"
echo "- Certifique-se de que a porta 5000 está aberta no seu firewall"
echo "- Para produção, considere usar um proxy reverso (nginx)"
echo "- Altere a SECRET_KEY em src/main.py para produção"
echo "=================================================="

deactivate
log_success "Instalação finalizada! 🎤"

