#!/bin/bash

# =============================================================================
# BotCity Development Environment Startup Script
# =============================================================================
# Este script inicializa todos os serviços necessários para o ambiente de
# desenvolvimento: VNC, SSH, VSCode Server e configurações do sistema
# =============================================================================

set -e

# =============================================================================
# CONFIGURAÇÕES DE AMBIENTE
# =============================================================================
export XVFB_RES="${RESOLUTION:-1920x1080x24}"
export XVFB_ARGS="${XARGS}"
export DISPLAY=:10

# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================

# Função para logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Função de limpeza para encerramento gracioso
cleanup() {
    log "🛑 Recebido sinal de encerramento. Parando serviços..."
    
    # Parar VNC
    vncserver -kill $DISPLAY 2>/dev/null || true
    
    # Parar SSH
    service ssh stop 2>/dev/null || true
    
    # Parar code-server
    pkill -f code-server 2>/dev/null || true
    
    # Parar Xvfb
    pkill -f Xvfb 2>/dev/null || true
    
    log "✅ Limpeza concluída"
    exit 0
}

# Configurar trap para encerramento gracioso
trap cleanup SIGTERM SIGINT

# Função para verificar se um serviço está rodando
check_service() {
    local service_name=$1
    local check_command=$2
    
    if eval "$check_command" > /dev/null 2>&1; then
        log "✅ $service_name está rodando"
        return 0
    else
        log "❌ $service_name não está rodando"
        return 1
    fi
}

# =============================================================================
# LIMPEZA INICIAL
# =============================================================================
log "🚀 Iniciando ambiente de desenvolvimento BotCity..."

# Limpar arquivos de lock que podem impedir inicialização
log "🧹 Limpando arquivos de lock..."
rm -f /tmp/.X*-lock 2>/dev/null || true
rm -f /tmp/.X11-unix/X* 2>/dev/null || true
rm -f /root/.vnc/*.pid 2>/dev/null || true

# Parar processos conflitantes se existirem
log "🔄 Verificando processos existentes..."
pkill -f "Xtigervnc|Xvnc" 2>/dev/null || true
pkill -f "Xvfb" 2>/dev/null || true
pkill -f "code-server" 2>/dev/null || true

# Aguardar processos encerrarem completamente
sleep 2

# =============================================================================
# CONFIGURAÇÕES INICIAIS
# =============================================================================

# Configurar senhas se fornecidas via variáveis de ambiente
if [ -n "$ROOT_PASSWORD" ]; then
    echo "root:$ROOT_PASSWORD" | chpasswd
    log "✅ Senha do root configurada"
fi

if [ -n "$VNC_PASSWORD" ]; then
    mkdir -p /root/.vnc
    echo "$VNC_PASSWORD" | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
    log "✅ Senha do VNC configurada"
fi

# Configurações adicionais de ambiente
export NO_AT_BRIDGE=1

# =============================================================================
# INICIALIZAÇÃO DO XVFB
# =============================================================================
log "🖥️  Iniciando Xvfb (display virtual)..."

# Iniciar Xvfb no display :99 como fallback
Xvfb :99 -screen 0 $XVFB_RES -ac +extension GLX +render -noreset $XVFB_ARGS > /dev/null 2>&1 &
sleep 2

# Verificar se Xvfb iniciou
if ! pgrep -f "Xvfb" > /dev/null; then
    log "❌ Falha ao iniciar Xvfb"
else
    log "✅ Xvfb iniciado com sucesso"
fi

# =============================================================================
# CONFIGURAÇÃO E INICIALIZAÇÃO DO VNC
# =============================================================================
log "🖥️  Configurando ambiente gráfico VNC..."

# Configuração do VNC
mkdir -p /root/.vnc
cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
xrdb $HOME/.Xresources 2>/dev/null || true
startxfce4 &
EOF

chmod +x /root/.vnc/xstartup

# Iniciar servidor VNC
log "🔄 Iniciando servidor VNC na porta ${VNC_PORT:-5910}..."
vncserver $DISPLAY -geometry 1920x1080 -depth 24 -rfbport ${VNC_PORT:-5910} > /dev/null 2>&1

# Aguardar VNC inicializar
sleep 3

# =============================================================================
# CONFIGURAÇÃO DO SSH
# =============================================================================
log "🔑 Configurando e iniciando servidor SSH..."

# Gerar chaves SSH se não existirem
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N '' > /dev/null 2>&1
fi

if [ ! -f /etc/ssh/ssh_host_ecdsa_key ]; then
    ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N '' > /dev/null 2>&1
fi

if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N '' > /dev/null 2>&1
fi

# Configurar SSH para permitir login root
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null || true
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null || true

# Iniciar SSH
log "🔄 Iniciando servidor SSH na porta ${SSH_PORT:-22}..."
service ssh start > /dev/null 2>&1

# =============================================================================
# CONFIGURAÇÃO DO VSCODE SERVER
# =============================================================================
log "💻 Iniciando VSCode Server na porta ${VSCODE_PORT:-8080}..."
nohup code-server --bind-addr 0.0.0.0:${VSCODE_PORT:-8080} --auth none /workspace > /var/log/code-server.log 2>&1 &

# =============================================================================
# CONFIGURAÇÕES FINAIS
# =============================================================================
# Configurar autocutsel para clipboard
autocutsel -fork > /dev/null 2>&1 || true

# =============================================================================
# VERIFICAÇÃO DOS SERVIÇOS
# =============================================================================
log "🔍 Verificando status dos serviços..."

sleep 5

check_service "Xvfb" "pgrep -f 'Xvfb'"
check_service "VNC Server" "pgrep -f 'Xtigervnc|Xvnc'"
check_service "SSH Server" "pgrep -f sshd"
check_service "VSCode Server" "pgrep -f code-server"

# Verificação final de processos críticos
log "🔍 Verificando status final dos processos..."
pgrep -f "Xtigervnc|Xvnc" || log "⚠️  AVISO: Servidor VNC pode não ter iniciado corretamente"

# =============================================================================
# INFORMAÇÕES DE ACESSO
# =============================================================================
log "🎉 Ambiente inicializado com sucesso!"
log ""
log "📋 Informações de Acesso:"
log "   🖥️  VNC: localhost:${VNC_PORT:-5910} (senha: conforme configurado)"
log "   🔑 SSH: ssh root@localhost -p ${SSH_PORT:-22}"
log "   💻 VSCode: http://localhost:${VSCODE_PORT:-8080}"
log ""
log "📁 Diretório de trabalho: /workspace"
log ""

# =============================================================================
# EXECUÇÃO DO COMANDO PRINCIPAL
# =============================================================================
if [ $# -eq 0 ]; then
    log "🐚 Iniciando bash interativo..."
    exec /bin/bash
else
    log "▶️  Executando comando: $*"
    exec "$@"
fi