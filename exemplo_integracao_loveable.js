// 🎤 Exemplo de Integração WhisperX API com Loveable
// Este arquivo mostra como integrar a API de transcrição em seu projeto Loveable

// ===== CONFIGURAÇÃO =====
const WHISPERX_API_URL = 'http://SEU_SERVIDOR_IP:5000'; // Substitua pelo IP da sua VPS

// ===== CLASSE DE INTEGRAÇÃO =====
class WhisperXIntegration {
    constructor(apiUrl = WHISPERX_API_URL) {
        this.apiUrl = apiUrl;
    }

    // Verificar se a API está funcionando
    async checkHealth() {
        try {
            const response = await fetch(`${this.apiUrl}/api/health`);
            const data = await response.json();
            return {
                success: response.ok,
                data: data
            };
        } catch (error) {
            return {
                success: false,
                error: error.message
            };
        }
    }

    // Transcrever arquivo de áudio
    async transcribeAudio(audioFile, onProgress = null) {
        try {
            // Validar arquivo
            if (!this.isValidAudioFile(audioFile)) {
                throw new Error('Formato de arquivo não suportado');
            }

            if (audioFile.size > 100 * 1024 * 1024) { // 100MB
                throw new Error('Arquivo muito grande. Máximo: 100MB');
            }

            // Preparar FormData
            const formData = new FormData();
            formData.append('audio', audioFile);

            // Callback de progresso
            if (onProgress) {
                onProgress('Enviando arquivo...');
            }

            // Fazer requisição
            const response = await fetch(`${this.apiUrl}/api/transcribe`, {
                method: 'POST',
                body: formData
            });

            const result = await response.json();

            if (response.ok) {
                if (onProgress) {
                    onProgress('Transcrição concluída!');
                }
                return {
                    success: true,
                    data: result
                };
            } else {
                throw new Error(result.error || 'Erro na transcrição');
            }

        } catch (error) {
            return {
                success: false,
                error: error.message
            };
        }
    }

    // Validar se o arquivo é de áudio suportado
    isValidAudioFile(file) {
        const allowedTypes = [
            'audio/wav', 'audio/mp3', 'audio/mpeg', 'audio/mp4',
            'audio/x-m4a', 'audio/aac', 'audio/ogg', 'audio/wma',
            'video/mp4', 'video/avi', 'video/mov', 'video/x-flv'
        ];
        
        const allowedExtensions = [
            'wav', 'mp3', 'mp4', 'avi', 'mov', 'flv', 'm4a', 'aac', 'ogg', 'wma'
        ];

        // Verificar tipo MIME
        if (allowedTypes.includes(file.type)) {
            return true;
        }

        // Verificar extensão como fallback
        const extension = file.name.split('.').pop().toLowerCase();
        return allowedExtensions.includes(extension);
    }

    // Formatar tempo em segundos para MM:SS
    formatTime(seconds) {
        const minutes = Math.floor(seconds / 60);
        const remainingSeconds = Math.floor(seconds % 60);
        return `${minutes.toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}`;
    }

    // Processar segmentos para exibição
    formatSegments(segments) {
        return segments.map(segment => ({
            text: segment.text.trim(),
            startTime: this.formatTime(segment.start),
            endTime: this.formatTime(segment.end),
            duration: segment.end - segment.start,
            words: segment.words || []
        }));
    }
}

// ===== COMPONENTE REACT PARA LOVEABLE =====
const TranscriptionComponent = () => {
    const [whisperX] = useState(new WhisperXIntegration());
    const [file, setFile] = useState(null);
    const [transcription, setTranscription] = useState(null);
    const [loading, setLoading] = useState(false);
    const [progress, setProgress] = useState('');
    const [apiStatus, setApiStatus] = useState('checking');

    // Verificar status da API ao carregar
    useEffect(() => {
        checkAPIStatus();
    }, []);

    const checkAPIStatus = async () => {
        const result = await whisperX.checkHealth();
        setApiStatus(result.success ? 'online' : 'offline');
    };

    const handleFileSelect = (event) => {
        const selectedFile = event.target.files[0];
        if (selectedFile) {
            if (whisperX.isValidAudioFile(selectedFile)) {
                setFile(selectedFile);
                setTranscription(null);
            } else {
                alert('Formato de arquivo não suportado!');
            }
        }
    };

    const handleTranscribe = async () => {
        if (!file) return;

        setLoading(true);
        setProgress('Iniciando transcrição...');

        const result = await whisperX.transcribeAudio(file, setProgress);

        if (result.success) {
            const formattedSegments = whisperX.formatSegments(result.data.segments);
            setTranscription({
                text: result.data.text,
                language: result.data.language,
                segments: formattedSegments,
                originalSegments: result.data.segments
            });
        } else {
            alert(`Erro na transcrição: ${result.error}`);
        }

        setLoading(false);
        setProgress('');
    };

    const downloadTranscription = () => {
        if (!transcription) return;

        const content = `Transcrição de Áudio
Arquivo: ${file.name}
Idioma: ${transcription.language}
Data: ${new Date().toLocaleString()}

=== TEXTO COMPLETO ===
${transcription.text}

=== SEGMENTOS COM TIMESTAMPS ===
${transcription.segments.map(segment => 
    `[${segment.startTime} - ${segment.endTime}] ${segment.text}`
).join('\n')}
`;

        const blob = new Blob([content], { type: 'text/plain' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `transcricao_${file.name.split('.')[0]}.txt`;
        a.click();
        URL.revokeObjectURL(url);
    };

    return (
        <div className="transcription-container">
            {/* Status da API */}
            <div className={`api-status ${apiStatus}`}>
                {apiStatus === 'checking' && '🔄 Verificando API...'}
                {apiStatus === 'online' && '✅ API Online'}
                {apiStatus === 'offline' && '❌ API Offline'}
            </div>

            {/* Upload de Arquivo */}
            <div className="upload-section">
                <h3>📁 Selecionar Arquivo de Áudio</h3>
                <input
                    type="file"
                    onChange={handleFileSelect}
                    accept=".wav,.mp3,.mp4,.avi,.mov,.flv,.m4a,.aac,.ogg,.wma"
                    disabled={loading}
                />
                
                {file && (
                    <div className="file-info">
                        <p><strong>Arquivo:</strong> {file.name}</p>
                        <p><strong>Tamanho:</strong> {(file.size / 1024 / 1024).toFixed(2)} MB</p>
                    </div>
                )}
            </div>

            {/* Botão de Transcrição */}
            <div className="transcribe-section">
                <button
                    onClick={handleTranscribe}
                    disabled={!file || loading || apiStatus !== 'online'}
                    className="transcribe-button"
                >
                    {loading ? '⏳ Transcrevendo...' : '🎯 Transcrever Áudio'}
                </button>
                
                {progress && (
                    <div className="progress">
                        {progress}
                    </div>
                )}
            </div>

            {/* Resultados */}
            {transcription && (
                <div className="results-section">
                    <h3>📝 Resultado da Transcrição</h3>
                    
                    <div className="transcription-info">
                        <p><strong>Idioma:</strong> {transcription.language}</p>
                        <p><strong>Segmentos:</strong> {transcription.segments.length}</p>
                        <button onClick={downloadTranscription} className="download-button">
                            💾 Baixar Transcrição
                        </button>
                    </div>

                    <div className="transcription-text">
                        <h4>Texto Completo:</h4>
                        <p>{transcription.text}</p>
                    </div>

                    <div className="transcription-segments">
                        <h4>Segmentos com Timestamps:</h4>
                        {transcription.segments.map((segment, index) => (
                            <div key={index} className="segment">
                                <span className="timestamp">
                                    [{segment.startTime} - {segment.endTime}]
                                </span>
                                <span className="text">{segment.text}</span>
                            </div>
                        ))}
                    </div>
                </div>
            )}
        </div>
    );
};

// ===== ESTILOS CSS PARA LOVEABLE =====
const transcriptionStyles = `
.transcription-container {
    max-width: 800px;
    margin: 0 auto;
    padding: 20px;
    font-family: Arial, sans-serif;
}

.api-status {
    padding: 10px;
    border-radius: 5px;
    margin-bottom: 20px;
    text-align: center;
    font-weight: bold;
}

.api-status.checking {
    background-color: #fff3cd;
    color: #856404;
}

.api-status.online {
    background-color: #d4edda;
    color: #155724;
}

.api-status.offline {
    background-color: #f8d7da;
    color: #721c24;
}

.upload-section {
    margin-bottom: 20px;
    padding: 20px;
    border: 2px dashed #ccc;
    border-radius: 10px;
}

.file-info {
    margin-top: 10px;
    padding: 10px;
    background-color: #f8f9fa;
    border-radius: 5px;
}

.transcribe-button {
    background-color: #007bff;
    color: white;
    padding: 12px 24px;
    border: none;
    border-radius: 5px;
    cursor: pointer;
    font-size: 16px;
    margin: 10px 0;
}

.transcribe-button:disabled {
    background-color: #ccc;
    cursor: not-allowed;
}

.progress {
    color: #007bff;
    font-weight: bold;
    margin: 10px 0;
}

.results-section {
    margin-top: 20px;
    padding: 20px;
    background-color: #f8f9fa;
    border-radius: 10px;
}

.transcription-info {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 15px;
}

.download-button {
    background-color: #28a745;
    color: white;
    padding: 8px 16px;
    border: none;
    border-radius: 5px;
    cursor: pointer;
}

.transcription-text {
    margin: 15px 0;
    padding: 15px;
    background-color: white;
    border-radius: 5px;
    border-left: 4px solid #007bff;
}

.transcription-segments {
    margin-top: 15px;
}

.segment {
    display: flex;
    margin: 5px 0;
    padding: 8px;
    background-color: white;
    border-radius: 3px;
}

.timestamp {
    color: #666;
    font-family: monospace;
    margin-right: 10px;
    min-width: 120px;
}

.text {
    flex: 1;
}
`;

// ===== INSTRUÇÕES DE USO =====
/*
COMO USAR NO LOVEABLE:

1. Copie a classe WhisperXIntegration para seu projeto
2. Substitua 'SEU_SERVIDOR_IP' pelo IP real da sua VPS
3. Copie o componente TranscriptionComponent
4. Adicione os estilos CSS ao seu projeto
5. Importe e use o componente em sua aplicação

EXEMPLO DE IMPORTAÇÃO:
import TranscriptionComponent from './TranscriptionComponent';

EXEMPLO DE USO:
<TranscriptionComponent />

CONFIGURAÇÕES ADICIONAIS:
- Certifique-se de que a porta 5000 está aberta na sua VPS
- Configure CORS se necessário
- Teste a conectividade antes do deploy

FUNCIONALIDADES INCLUÍDAS:
✅ Upload de arquivos de áudio
✅ Validação de formato e tamanho
✅ Verificação de status da API
✅ Transcrição com progress feedback
✅ Exibição de resultados com timestamps
✅ Download da transcrição em TXT
✅ Interface responsiva
✅ Tratamento de erros
*/

export { WhisperXIntegration, TranscriptionComponent, transcriptionStyles };

