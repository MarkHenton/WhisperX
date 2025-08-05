import os
import tempfile
import whisperx
from flask import Blueprint, request, jsonify
from werkzeug.utils import secure_filename
import torch

transcription_bp = Blueprint('transcription', __name__)

# Configurações para upload de arquivos
ALLOWED_EXTENSIONS = {'wav', 'mp3', 'mp4', 'avi', 'mov', 'flv', 'm4a', 'aac', 'ogg', 'wma'}
MAX_FILE_SIZE = 100 * 1024 * 1024  # 100MB

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@transcription_bp.route('/transcribe', methods=['POST'])
def transcribe_audio():
    try:
        # Verificar se um arquivo foi enviado
        if 'audio' not in request.files:
            return jsonify({'error': 'Nenhum arquivo de áudio foi enviado'}), 400
        
        file = request.files['audio']
        
        # Verificar se o arquivo tem um nome
        if file.filename == '':
            return jsonify({'error': 'Nenhum arquivo selecionado'}), 400
        
        # Verificar se o arquivo é permitido
        if not allowed_file(file.filename):
            return jsonify({'error': 'Tipo de arquivo não suportado'}), 400
        
        # Verificar o tamanho do arquivo
        file.seek(0, os.SEEK_END)
        file_size = file.tell()
        file.seek(0)
        
        if file_size > MAX_FILE_SIZE:
            return jsonify({'error': 'Arquivo muito grande. Máximo permitido: 100MB'}), 400
        
        # Salvar o arquivo temporariamente
        filename = secure_filename(file.filename)
        temp_dir = tempfile.mkdtemp()
        temp_path = os.path.join(temp_dir, filename)
        file.save(temp_path)
        
        try:
            # Configurar o dispositivo (CPU)
            device = "cpu"
            compute_type = "int8"  # Para CPU
            
            # Carregar o modelo WhisperX
            model = whisperx.load_model("base", device, compute_type=compute_type)
            
            # Carregar o áudio
            audio = whisperx.load_audio(temp_path)
            
            # Realizar a transcrição
            result = model.transcribe(audio, batch_size=16)
            
            # Alinhar o resultado (opcional, mas recomendado)
            model_a, metadata = whisperx.load_align_model(language_code=result["language"], device=device)
            result = whisperx.align(result["segments"], model_a, metadata, audio, device, return_char_alignments=False)
            
            # Preparar a resposta
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
            # Limpar arquivos temporários
            try:
                os.remove(temp_path)
                os.rmdir(temp_dir)
            except:
                pass
    
    except Exception as e:
        return jsonify({'error': f'Erro interno do servidor: {str(e)}'}), 500

@transcription_bp.route('/health', methods=['GET'])
def health_check():
    """Endpoint para verificar se a API está funcionando"""
    return jsonify({
        'status': 'healthy',
        'message': 'API de transcrição WhisperX está funcionando',
        'device': 'cpu',
        'compute_type': 'int8'
    }), 200

