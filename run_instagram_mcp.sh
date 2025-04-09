#!/bin/bash

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Iniciando servidor MCP do Instagram em modo de teste...${NC}"
echo -e "${GREEN}Este servidor simulará as respostas da API do Instagram${NC}"
echo -e "${GREEN}Pressione Ctrl+C para encerrar${NC}"

# Criar arquivo .env temporário se não existir
if [ ! -f .env ]; then
  echo -e "${YELLOW}Criando arquivo .env temporário...${NC}"
  cat > .env << EOL
# Credenciais do Instagram (modo de teste - não são necessárias)
INSTAGRAM_USER_ID=
INSTAGRAM_ACCESS_TOKEN=

# Configurações da API
API_VERSION=v22.0
BASE_URL=https://graph.instagram.com
EOL
fi

# Executar o servidor MCP
node index.js
