# Integração WhisperX para Transcrição de Áudio (sem GPU)

## Visão Geral
Este documento detalha os passos para integrar o WhisperX como um serviço de transcrição de áudio em um aplicativo, com foco na execução em ambientes sem GPU.

## Requisitos e Instalação (sem GPU)

O WhisperX pode ser executado em CPU utilizando o parâmetro `--compute_type int8`. Além disso, é necessário instalar `ffmpeg` e `rust`.

### Instalação (Opção de Desenvolvedor):

```bash
git clone https://github.com/m-bain/whisperX.git
cd whisperX
uv sync --all-extras --dev
```

### Execução sem GPU:

```bash
whisperx path/to/audio.wav --compute_type int8
```

## Próximos Passos

1.  Configurar o ambiente e instalar o WhisperX.
2.  Desenvolver uma API Flask para gerenciar o upload de arquivos e a chamada do WhisperX.
3.  Testar a API localmente.
4.  Documentar a solução completa.

