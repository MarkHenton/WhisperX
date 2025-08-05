# 🚀 Instruções de Deployment - WhisperX API

## 📋 Resumo da Solução

Sua API de transcrição WhisperX está pronta! Esta solução oferece:

✅ **API RESTful completa** para transcrição de áudio  
✅ **Funciona sem GPU** (otimizado para CPU)  
✅ **Interface web de teste** incluída  
✅ **Pronto para integração** com seu app Loveable  
✅ **Script de instalação automatizada**  
✅ **Documentação completa**  

## 🎯 Próximos Passos

### 1. Fazer Upload dos Arquivos para sua VPS

Transfira estes arquivos para sua VPS:

```bash
# Arquivos principais
- install_whisperx_api.sh          # Script de instalação automatizada
- DOCUMENTACAO_WHISPERX_API.md     # Documentação completa
- exemplo_integracao_loveable.js   # Exemplo de integração
- INSTRUCOES_DEPLOYMENT.md         # Este arquivo
```

### 2. Executar a Instalação Automatizada

Na sua VPS, execute:

```bash
# Fazer upload do script
scp install_whisperx_api.sh usuario@sua-vps:/home/usuario/

# Conectar na VPS
ssh usuario@sua-vps

# Executar instalação
chmod +x install_whisperx_api.sh
./install_whisperx_api.sh
```

O script irá:
- Instalar todas as dependências
- Configurar o WhisperX para CPU
- Criar a API Flask
- Configurar o firewall
- Criar serviços systemd

### 3. Iniciar a API

Após a instalação:

```bash
# Navegar para o diretório
cd ~/whisperx_transcription/whisperx_api

# Iniciar a API
./start_api.sh
```

Ou como serviço:

```bash
# Habilitar serviço
sudo systemctl enable whisperx-api
sudo systemctl start whisperx-api

# Verificar status
sudo systemctl status whisperx-api
```

### 4. Testar a API

Acesse no navegador:
```
http://SEU_IP_VPS:5000
```

Ou teste via curl:
```bash
curl http://SEU_IP_VPS:5000/api/health
```

### 5. Integrar com seu App Loveable

Use o arquivo `exemplo_integracao_loveable.js` como base:

1. Substitua `SEU_SERVIDOR_IP` pelo IP real da sua VPS
2. Copie a classe `WhisperXIntegration` para seu projeto
3. Use o componente `TranscriptionComponent` como exemplo
4. Adicione os estilos CSS incluídos

## 🔧 Configurações de Produção

### Firewall

```bash
# Liberar porta 5000
sudo ufw allow 5000/tcp
sudo ufw enable
```

### Proxy Reverso (Nginx) - Recomendado

```bash
# Instalar nginx
sudo apt install nginx

# Configurar proxy
sudo nano /etc/nginx/sites-available/whisperx-api
```

Conteúdo do arquivo nginx:
```nginx
server {
    listen 80;
    server_name seu-dominio.com;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
# Habilitar site
sudo ln -s /etc/nginx/sites-available/whisperx-api /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### SSL/HTTPS (Opcional)

```bash
# Instalar certbot
sudo apt install certbot python3-certbot-nginx

# Obter certificado
sudo certbot --nginx -d seu-dominio.com
```

## 📊 Monitoramento

### Verificar Logs

```bash
# Logs da aplicação
sudo journalctl -u whisperx-api -f

# Logs do nginx (se usando)
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Verificar Recursos

```bash
# CPU e memória
htop

# Espaço em disco
df -h

# Status dos serviços
sudo systemctl status whisperx-api
sudo systemctl status nginx
```

## 🔄 Manutenção

### Atualizar WhisperX

```bash
cd ~/whisperx_transcription/whisperX
git pull
cd ../whisperx_api
source venv/bin/activate
pip install ../whisperX --upgrade
sudo systemctl restart whisperx-api
```

### Backup

```bash
# Backup da aplicação
tar -czf whisperx_backup_$(date +%Y%m%d).tar.gz ~/whisperx_transcription/
```

### Reiniciar Serviços

```bash
# Reiniciar API
sudo systemctl restart whisperx-api

# Reiniciar nginx
sudo systemctl restart nginx
```

## 🐛 Solução de Problemas

### API não inicia

```bash
# Verificar logs
sudo journalctl -u whisperx-api -n 50

# Verificar dependências
cd ~/whisperx_transcription/whisperx_api
source venv/bin/activate
python -c "import whisperx; print('OK')"
```

### Transcrição lenta

- Normal no primeiro uso (download de modelos)
- Considere usar modelo "tiny" para velocidade
- Verifique recursos do servidor (RAM/CPU)

### Erro de conexão

```bash
# Verificar se a porta está aberta
sudo netstat -tlnp | grep 5000

# Verificar firewall
sudo ufw status

# Testar localmente
curl http://localhost:5000/api/health
```

## 📞 Suporte

### Arquivos de Referência

- `DOCUMENTACAO_WHISPERX_API.md` - Documentação técnica completa
- `exemplo_integracao_loveable.js` - Código de integração
- Logs em `/var/log/` e `journalctl`

### Comandos Úteis

```bash
# Status geral
sudo systemctl status whisperx-api
curl http://localhost:5000/api/health

# Recursos do sistema
free -h
df -h
top

# Rede
sudo netstat -tlnp | grep 5000
sudo ufw status
```

## ✅ Checklist Final

Antes de integrar com o Loveable:

- [ ] API instalada e funcionando
- [ ] Porta 5000 aberta no firewall
- [ ] Teste de transcrição realizado
- [ ] IP da VPS anotado
- [ ] Backup da configuração feito
- [ ] Monitoramento configurado

## 🎉 Conclusão

Sua API de transcrição WhisperX está pronta para uso! 

**Próximos passos:**
1. Execute o script de instalação na sua VPS
2. Teste a API com arquivos reais
3. Integre com seu app Loveable
4. Configure monitoramento e backup

**Lembre-se:**
- A primeira transcrição demora mais (download de modelos)
- Qualidade da transcrição depende da qualidade do áudio
- Para produção, use nginx como proxy reverso
- Monitore recursos do servidor regularmente

Boa sorte com seu projeto de transcrição de aulas! 🎓🎤

