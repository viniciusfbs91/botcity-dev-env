#!/bin/bash
# Script para iniciar o ambiente de desenvolvimento

echo "🚀 Iniciando ambiente de desenvolvimento BotCity..."

# Criar diretórios necessários
mkdir -p workspace config ssh-keys

# Verificar se .env existe
if [ ! -f .env ]; then
    echo "⚠️  Arquivo .env não encontrado. Criando a partir do exemplo..."
    cp .env.example .env
    echo "✅ Arquivo .env criado. Edite-o conforme necessário antes de continuar."
    exit 1
fi

# Construir e iniciar
docker-compose up --build -d

echo "✅ Ambiente iniciado com sucesso!"
echo ""
echo "📋 Acesse os serviços em:"
echo "   🖥️  VNC: localhost:5910"
echo "   🔑 SSH: ssh root@localhost -p 2222"
echo "   💻 VSCode: http://localhost:8080"
echo ""
echo "📁 Diretório de trabalho: ./workspace (mapeado para /workspace no container)"