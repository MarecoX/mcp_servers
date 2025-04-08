# MarecoX MCP Servers

Script de instalação automatizada para servidores MCP.

## Estrutura do Projeto

O projeto é composto por três scripts principais:

1. `install.sh` - Script principal que exibe o menu e gerencia a instalação
2. `setup_google.sh` - Script para instalação do Google Calendar MCP
3. `setup_evolution.sh` - Script para instalação do Evolution API MCP
4. `setup_instagram.sh` - Script para instalação do Instagram MCP

## Uso

Você pode instalar de duas maneiras:

### Opção 1 - Comando em uma linha (Recomendado)
```bash
curl -fsSL https://raw.githubusercontent.com/MarecoX/mcp_servers/main/install.sh | sudo bash
```

### Opção 2 - Comandos separados
```bash
# 1. Baixar o script de instalação
curl -fsSL https://raw.githubusercontent.com/MarecoX/mcp_servers/main/install.sh > install.sh

# 2. Executar o script com privilégios de root
sudo bash install.sh
```

## Opções Disponíveis

1. Google Calendar MCP
   - Criação de eventos
   - Busca de eventos
   - Deleção de eventos
   - Requer credenciais do Google Calendar API

2. Evolution API MCP
   - Envio de mensagens
     - Envio de mensagens de texto
     - Envio de mídia (imagens, vídeos, documentos)
     - Envio de áudio
     - Envio de enquetes
     - Envio de listas interativas
   - Gerenciamento de Grupos
     - Criação de grupos
     - Atualização de foto do grupo
     - Envio de convites para grupos
     - Gerenciamento de participantes (adicionar/remover)
     - Busca de grupos
     - Busca de participantes de grupos
   - Requer credenciais da Evolution API (EVOLUTION_INSTANCIA, EVOLUTION_APIKEY, EVOLUTION_API_BASE)

3. Instagram MCP
   - Instala e configura o MCP para integração com Instagram
   - Requer credenciais da API do Instagram
   - Diretório de instalação: `/opt/mcp_instagram`
   - Funcionalidades:
     - **Media Management**
       - `create_media`: Create a new media post with image, caption, location, and hashtags
       - `publish_media`: Publish a created media post
       - `create_carousel`: Create a carousel post with multiple images
       - `create_reel`: Create an Instagram Reel with video and caption
       - `create_story`: Create an Instagram Story with image/video and optional stickers
       - `like_media`: Like a media post
       - `follow_user`: Follow or unfollow a user

     - **Comment Management**
       - `add_comment`: Add a comment to a media post
       - `reply_to_comment`: Reply to an existing comment

     - **Profile Management**
       - `update_profile`: Update user profile information including:
         - Username
         - Biography
         - Business account details
         - Contact information
         - Website

     - **Discovery & Search**
       - `get_hashtag_info`: Get information about a hashtag
       - `get_location_info`: Get information about a location
       - `search`: Search for users, hashtags, or locations

     - **Features**
       - Full Instagram Graph API integration
       - Support for all media types (posts, carousels, reels, stories)
       - Comprehensive error handling
       - Detailed logging
       - Input validation using Zod schemas
       - Environment-based configuration

4. Sair

## Requisitos

- Sistema operacional: Debian/Ubuntu
- Acesso root
- Credenciais específicas para cada tipo de MCP:
  - Google Calendar: GOOGLE_CALENDAR_ID, GOOGLE_CLIENT_EMAIL, GOOGLE_PRIVATE_KEY
  - Evolution API: EVOLUTION_INSTANCIA, EVOLUTION_APIKEY, EVOLUTION_API_BASE
  - Instagram API: INSTAGRAM_USER_ID, INSTAGRAM_ACCESS_TOKEN, INSTAGRAM_TOKEN

## Processo de Instalação

O script irá:

1. Verificar requisitos do sistema
2. Atualizar os pacotes do sistema
3. Instalar Node.js e dependências
4. Configurar o ambiente específico para cada tipo de MCP
5. Instalar dependências do projeto
6. Configurar arquivos necessários

## Suporte

Para suporte, abra uma issue no repositório: https://github.com/MarecoX/mcp_servers/issues 
