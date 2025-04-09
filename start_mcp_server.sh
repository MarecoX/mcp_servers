#!/bin/bash

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Iniciando servidor MCP do Instagram em modo de teste...${NC}"
echo -e "${GREEN}Este servidor simulará as respostas da API do Instagram${NC}"
echo -e "${GREEN}Pressione Ctrl+C para encerrar${NC}"

# Executar o servidor MCP
node simple_mcp_server.js
