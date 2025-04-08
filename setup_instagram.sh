#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Verificar sistema operacional
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VERSION=$VERSION_ID
else
    echo -e "${RED}Erro: Sistema operacional não suportado${NC}"
    exit 1
fi

# Verificar se é Debian/Ubuntu
if [[ ! "$OS" =~ "Debian" ]] && [[ ! "$OS" =~ "Ubuntu" ]]; then
    echo -e "${RED}Erro: Este script só funciona em sistemas Debian/Ubuntu${NC}"
    exit 1
fi

# Criar diretório
cd /opt
mkdir -p mcp_instagram
cd mcp_instagram

# Instalar dependências
echo -e "${YELLOW}Instalando dependências...${NC}"
apt-get update
apt-get install -y curl git build-essential

# Instalar Node.js e npm
echo -e "${YELLOW}Instalando Node.js e npm...${NC}"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Instalar TypeScript globalmente
echo -e "${YELLOW}Instalando TypeScript...${NC}"
npm install -g typescript

# Inicializar projeto npm
echo -e "${YELLOW}Inicializando projeto npm...${NC}"
npm init -y

# Instalar dependências do projeto
echo -e "${YELLOW}Instalando dependências do projeto...${NC}"
npm install dotenv axios zod @modelcontextprotocol/sdk

# Criar arquivo index.js
echo -e "${YELLOW}Criando arquivo index.js...${NC}"
cat > index.js << 'EOL'
const { Server } = require("@modelcontextprotocol/sdk/server/index.js");
const { StdioServerTransport } = require("@modelcontextprotocol/sdk/server/stdio.js");
const { CallToolRequestSchema, ListToolsRequestSchema } = require("@modelcontextprotocol/sdk/types.js");
const { z } = require("zod");
const axios = require("axios");
const dotenv = require("dotenv");

dotenv.config();

const schemas = {
  toolInputs: {
    media: z.object({      
      imageUrl: z.string().url(),
      caption: z.string(),
      altText: z.string().optional(),
    }),
    media_publish: z.object({      
      creation_id: z.string(),
    }),
    carousel_item: z.object({      
      imageUrl: z.string().url(),
      is_carousel_item: z.literal(true),
    }),
    carousel: z.object({      
      items: z.array(z.string().url()).min(1).max(10),
      caption: z.string(),
      collaborators: z.array(z.string()).optional(),
      location_id: z.string().optional(),
      product_tags: z.array(z.object({
        product_id: z.string(),
        x: z.number(),
        y: z.number()
      })).optional(),
    }),
    reel: z.object({      
      videoUrl: z.string().url(),
      caption: z.string(),
      coverUrl: z.string().url().optional(),
      shareToFeed: z.boolean().optional(),
    }),
    story: z.object({      
      mediaUrl: z.string().url(),
      mediaType: z.string().transform(val => val.toUpperCase()).pipe(z.enum(["IMAGE", "VIDEO"])),
      backgroundColor: z.string().optional(),
      sticker: z.object({
        type: z.string(),
        x: z.number(),
        y: z.number(),
        rotation: z.number().optional(),
        scale: z.number().optional(),
      }).optional(),
    }),
    media_status: z.object({      
      creation_id: z.string(),
    }),
    create_comment: z.object({
      media_id: z.string(),
      message: z.string(),
    }),
    get_comments: z.object({
      media_id: z.string(),
    }),
    create_reply: z.object({
      comment_id: z.string(),
      message: z.string(),
    }),
    get_replies: z.object({
      comment_id: z.string(),
    }),
    hide_comment: z.object({
      comment_id: z.string(),
    }),
    private_reply: z.object({
      comment_id: z.string(),
      message: z.string(),
    }),
    get_media_ids: z.object({
      limit: z.number().optional(),
    }),
    get_comment_ids: z.object({
      media_id: z.string(),
    }),
  },
};

const TOOL_DEFINITIONS = [
  {
    name: "media",
    description: "Cria um container de mídia para postagem no Instagram",
    inputSchema: {
      type: "object",
      properties: {       
        imageUrl: { type: "string", description: "URL da imagem a ser postada" },
        caption: { type: "string", description: "Legenda da foto" },
        altText: { type: "string", description: "Texto alternativo para acessibilidade (opcional)" },
      },
      required: ["imageUrl", "caption"],
    },
  },
  {
    name: "media_publish",
    description: "Publica um container de mídia no Instagram",
    inputSchema: {
      type: "object",
      properties: {       
        creation_id: { type: "string", description: "ID do container de mídia a ser publicado" },
      },
      required: ["creation_id"],
    },
  },
  {
    name: "carousel",
    description: "Cria e publica um carrossel no Instagram (até 10 imagens)",
    inputSchema: {
      type: "object",
      properties: {       
        items: { 
          type: "array",
          items: { type: "string" },
          description: "Lista de URLs das imagens (máximo 10)",
          minItems: 1,
          maxItems: 10
        },
        caption: { type: "string", description: "Legenda do carrossel" },
        collaborators: { 
          type: "array",
          items: { type: "string" },
          description: "Lista de usernames dos colaboradores"
        },
        location_id: { type: "string", description: "ID da localização" },
        product_tags: {
          type: "array",
          items: {
            type: "object",
            properties: {
              product_id: { type: "string" },
              x: { type: "number" },
              y: { type: "number" }
            }
          }
        }
      },
      required: ["items", "caption"],
    },
  },
  {
    name: "reel",
    description: "Cria e publica um Reel no Instagram (substitui a funcionalidade antiga de vídeo)",
    inputSchema: {
      type: "object",
      properties: {       
        videoUrl: { type: "string", description: "URL do vídeo" },
        caption: { type: "string", description: "Legenda do Reel" },
        coverUrl: { type: "string", description: "URL da imagem de capa (opcional)" },
        shareToFeed: { type: "boolean", description: "Compartilhar no feed?" }
      },
      required: ["videoUrl", "caption"],
    },
  },
  {
    name: "story",
    description: "Cria e publica um Story no Instagram (apenas contas empresariais)",
    inputSchema: {
      type: "object",
      properties: {       
        mediaUrl: { type: "string", description: "URL da mídia (imagem ou vídeo)" },
        mediaType: { 
          type: "string", 
          enum: ["IMAGE", "VIDEO"],
          description: "Tipo de mídia"
        },
        backgroundColor: { type: "string", description: "Cor de fundo (opcional)" },
        sticker: {
          type: "object",
          properties: {
            type: { type: "string" },
            x: { type: "number" },
            y: { type: "number" },
            rotation: { type: "number" },
            scale: { type: "number" }
          }
        }
      },
      required: ["mediaUrl", "mediaType"],
    },
  },
  {
    name: "media_status",
    description: "Verifica o status de uma mídia no Instagram",
    inputSchema: {
      type: "object",
      properties: {       
        creation_id: { type: "string", description: "ID do container de mídia" },
      },
      required: ["creation_id"],
    },
  },
  {
    name: "create_comment",
    description: "Cria um comentário em uma publicação do Instagram",
    inputSchema: {
      type: "object",
      properties: {
        media_id: { type: "string", description: "ID da publicação" },
        message: { type: "string", description: "Texto do comentário" },
      },
      required: ["media_id", "message"],
    },
  },
  {
    name: "get_comments",
    description: "Obtém os comentários de uma publicação do Instagram",
    inputSchema: {
      type: "object",
      properties: {
        media_id: { type: "string", description: "ID da publicação" },
      },
      required: ["media_id"],
    },
  },
  {
    name: "create_reply",
    description: "Cria uma resposta a um comentário do Instagram",
    inputSchema: {
      type: "object",
      properties: {
        comment_id: { type: "string", description: "ID do comentário original" },
        message: { type: "string", description: "Texto da resposta" },
      },
      required: ["comment_id", "message"],
    },
  },
  {
    name: "get_replies",
    description: "Obtém todas as respostas de um comentário do Instagram",
    inputSchema: {
      type: "object",
      properties: {
        comment_id: { type: "string", description: "ID do comentário original" },
      },
      required: ["comment_id"],
    },
  },
  {
    name: "hide_comment",
    description: "Oculta um comentário no Instagram",
    inputSchema: {
      type: "object",
      properties: {
        comment_id: { type: "string", description: "ID do comentário a ser ocultado" },
      },
      required: ["comment_id"],
    },
  },
  {
    name: "private_reply",
    description: "Envia uma resposta privada para um comentário no Instagram",
    inputSchema: {
      type: "object",
      properties: {
        comment_id: { type: "string", description: "ID do comentário original" },
        message: { type: "string", description: "Texto da resposta privada" },
      },
      required: ["comment_id", "message"],
    },
  },
  {
    name: "get_media_ids",
    description: "Obtém os IDs das publicações da sua conta do Instagram",
    inputSchema: {
      type: "object",
      properties: {
        limit: { type: "number", description: "Número máximo de IDs a retornar (opcional)" },
      },
      required: [],
    },
  },
  {
    name: "get_comment_ids",
    description: "Obtém os IDs dos comentários de uma publicação do Instagram",
    inputSchema: {
      type: "object",
      properties: {
        media_id: { type: "string", description: "ID da publicação" },
      },
      required: ["media_id"],
    },
  },
];

const toolHandlers = {
  media: async (args) => {
    const parsed = schemas.toolInputs.media.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("INSTAGRAM_USER_ID:", process.env.INSTAGRAM_USER_ID);
    console.log("INSTAGRAM_ACCESS_TOKEN:", process.env.INSTAGRAM_ACCESS_TOKEN);
    
    const igUserId = process.env.INSTAGRAM_USER_ID;
    const accessToken = process.env.INSTAGRAM_ACCESS_TOKEN;
    const apiVersion = "v21.0";
    const baseUrl = "https://graph.facebook.com";

    try {
      // Verificar se é um vídeo
      const isVideo = parsed.imageUrl.match(/\.(mp4|mov|avi|wmv|flv|mkv)$/i);
      if (isVideo) {
        // Se for vídeo, redirecionar para a função reel
        return await toolHandlers.reel({
          videoUrl: parsed.imageUrl,
          caption: parsed.caption,
          shareToFeed: true
        });
      }

      // ETAPA 1: Criar container de mídia
      const containerUrl = `${baseUrl}/${apiVersion}/${igUserId}/media`;
      console.log("\n📤 ETAPA 1: Criando container de mídia...");
      console.log("URL:", containerUrl);

      const containerData = {
        image_url: parsed.imageUrl,
        caption: parsed.caption,
        alt_text: parsed.altText,
        access_token: accessToken
      };

      console.log("Dados:", containerData);

      const containerResponse = await axios.post(containerUrl, containerData);

      console.log("✅ Container criado:", containerResponse.data);

      // Retornar o creation_id para ser usado na publicação
      return {
        content: [{
          type: "text",
          text: `Container de mídia criado com sucesso!\nID do container: ${containerResponse.data.id}`,
        }],
      };
    } catch (error) {
      console.error("❌ Erro detalhado na criação do container:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status,
        headers: error.response?.headers,
        config: {
          url: error.config?.url,
          method: error.config?.method,
          data: error.config?.data
        }
      });
      
      let errorMessage = `Erro ao criar container de mídia: ${error.message}`;
      
      // Tratamento específico para erro 400
      if (error.response?.status === 400) {
        const errorData = error.response.data?.error;
        if (errorData) {
          errorMessage = `Erro de validação (400): ${errorData.message}`;
          if (errorData.code) {
            errorMessage += `\nCódigo do erro: ${errorData.code}`;
          }
          if (errorData.error_subcode) {
            errorMessage += `\nSubcódigo do erro: ${errorData.error_subcode}`;
          }
        }
      }
      
      return {
        content: [{
          type: "text",
          text: errorMessage,
        }],
      };
    }
  },

  media_publish: async (args) => {
    const parsed = schemas.toolInputs.media_publish.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("INSTAGRAM_USER_ID:", process.env.INSTAGRAM_USER_ID);
    console.log("INSTAGRAM_ACCESS_TOKEN:", process.env.INSTAGRAM_ACCESS_TOKEN);
    
    const igUserId = process.env.INSTAGRAM_USER_ID;
    const accessToken = process.env.INSTAGRAM_ACCESS_TOKEN;
    const apiVersion = "v21.0";
    const baseUrl = "https://graph.facebook.com";

    try {
      // Publicar o container imediatamente
      const publishUrl = `${baseUrl}/${apiVersion}/${igUserId}/media_publish`;
      console.log("\n📤 Publicando mídia...");
      console.log("URL:", publishUrl);
      console.log("Dados:", {
        creation_id: parsed.creation_id,
        access_token: accessToken
      });

      const publishResponse = await axios.post(publishUrl, {
        creation_id: parsed.creation_id,
        access_token: accessToken
      });

      console.log("✅ Mídia publicada:", publishResponse.data);

      // Retornar apenas a mensagem de sucesso
      return {
        content: [{
          type: "text",
          text: `Mídia publicada com sucesso!\nID da publicação: ${publishResponse.data.id}`,
        }],
      };
    } catch (error) {
      console.error("❌ Erro detalhado na publicação:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status,
        headers: error.response?.headers,
        config: {
          url: error.config?.url,
          method: error.config?.method,
          data: error.config?.data
        }
      });
      
      let errorMessage = `Erro ao publicar mídia: ${error.message}`;
      
      // Tratamento específico para erro 400
      if (error.response?.status === 400) {
        const errorData = error.response.data?.error;
        if (errorData) {
          errorMessage = `Erro de validação (400): ${errorData.message}`;
          if (errorData.code) {
            errorMessage += `\nCódigo do erro: ${errorData.code}`;
          }
          if (errorData.error_subcode) {
            errorMessage += `\nSubcódigo do erro: ${errorData.error_subcode}`;
          }
        }
      }
      
      return {
        content: [{
          type: "text",
          text: errorMessage,
        }],
      };
    }
  },

  carousel: async (args) => {
    const parsed = schemas.toolInputs.carousel.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("INSTAGRAM_USER_ID:", process.env.INSTAGRAM_USER_ID);
    console.log("INSTAGRAM_ACCESS_TOKEN:", process.env.INSTAGRAM_ACCESS_TOKEN);
    
    const igUserId = process.env.INSTAGRAM_USER_ID;
    const accessToken = process.env.INSTAGRAM_ACCESS_TOKEN;
    const apiVersion = "v21.0";
    const baseUrl = "https://graph.facebook.com";

    try {
      // Etapa 1: Criar containers para cada item do carrossel
      const itemIds = [];
      const itemStatuses = [];
      let hasVideo = false;
      
      // Primeiro, verificar se há vídeos no carrossel
      for (const imageUrl of parsed.items) {
        const isVideo = imageUrl.match(/\.(mp4|mov|avi|wmv|flv|mkv)$/i);
        if (isVideo) {
          hasVideo = true;
          break;
        }
      }

      console.log("\n📊 Análise do carrossel:");
      console.log(`- Total de itens: ${parsed.items.length}`);
      console.log(`- Contém vídeo: ${hasVideo ? "Sim" : "Não"}`);

      for (const imageUrl of parsed.items) {
        const createItemUrl = `${baseUrl}/${apiVersion}/${igUserId}/media`;
        console.log("\n📤 Criando container para item:", imageUrl);
        
        try {
          // Determinar o tipo de mídia baseado na extensão do arquivo
          const isVideo = imageUrl.match(/\.(mp4|mov|avi|wmv|flv|mkv)$/i);
          const mediaType = isVideo ? "VIDEO" : "IMAGE";
          
          console.log("📝 Tipo de mídia detectado:", mediaType);

          const itemData = {
            is_carousel_item: true,
            media_type: mediaType,
            access_token: accessToken
          };

          // Usar video_url para vídeos e image_url para imagens
          if (isVideo) {
            itemData.video_url = imageUrl;
            console.log("🎥 Dados do vídeo:", {
              url: imageUrl,
              type: mediaType
            });
          } else {
            itemData.image_url = imageUrl;
            console.log("🖼️ Dados da imagem:", {
              url: imageUrl,
              type: mediaType
            });
          }

          console.log("📤 Enviando requisição para criar container...");
          console.log("URL:", createItemUrl);
          console.log("Dados:", itemData);

          const itemResponse = await axios.post(createItemUrl, itemData);

          if (!itemResponse.data.id) {
            throw new Error(`Falha ao criar container para item: ${imageUrl}`);
          }
          
          const itemId = itemResponse.data.id;
          itemIds.push(itemId);
          itemStatuses.push({ id: itemId, isVideo, status: "CREATED" });
          console.log("✅ Container criado com ID:", itemId);

          // Verificar status se for vídeo
          if (isVideo) {
            console.log("🎥 Detectado vídeo no carrossel, verificando status do container...");
            let itemStatus = "IN_PROGRESS";
            let itemAttempts = 0;
            const maxItemAttempts = 8; // Reduzido para 8 tentativas
            const itemInterval = 60000; // Aumentado para 60 segundos

            while (itemStatus === "IN_PROGRESS" && itemAttempts < maxItemAttempts) {
              const itemStatusUrl = `${baseUrl}/${apiVersion}/${itemId}`;
              console.log(`\n🔄 Verificação ${itemAttempts + 1}/${maxItemAttempts} do container do vídeo`);
              console.log("URL:", itemStatusUrl);
              
              try {
                const itemStatusResponse = await axios.get(itemStatusUrl, {
                  params: {
                    fields: "status_code",
                    access_token: accessToken
                  }
                });

                itemStatus = itemStatusResponse.data.status_code;
                console.log("📊 Status atual do container do vídeo:", itemStatus);
                console.log("Detalhes completos:", JSON.stringify(itemStatusResponse.data, null, 2));

                if (itemStatus === "IN_PROGRESS") {
                  console.log("⏳ Container do vídeo ainda em processamento...");
                  console.log(`⏱️ Aguardando ${itemInterval/1000} segundos antes da próxima verificação...`);
                  await new Promise(resolve => setTimeout(resolve, itemInterval));
                  itemAttempts++;
                } else if (itemStatus === "FINISHED") {
                  console.log("✅ Container do vídeo processado com sucesso!");
                  console.log("📊 Status final:", JSON.stringify(itemStatusResponse.data, null, 2));
                  itemStatuses[itemStatuses.length - 1].status = "FINISHED";
                  break;
                } else if (itemStatus === "ERROR") {
                  throw new Error(`Erro no processamento do container do vídeo: ${JSON.stringify(itemStatusResponse.data)}`);
                }
              } catch (itemStatusError) {
                console.error("❌ Erro ao verificar status do container do vídeo:", {
                  message: itemStatusError.message,
                  response: itemStatusError.response?.data,
                  status: itemStatusError.response?.status
                });
                throw new Error(`Falha ao verificar status do container do vídeo: ${itemStatusError.message}`);
              }
            }

            if (itemStatus !== "FINISHED") {
              throw new Error(`Falha no processamento do container do vídeo. Status final: ${itemStatus}`);
            }

            console.log("\n⏳ Aguardando 2 segundos adicionais para garantir que o container do vídeo esteja pronto...");
            await new Promise(resolve => setTimeout(resolve, 2000));
          } else {
            itemStatuses[itemStatuses.length - 1].status = "FINISHED";
          }
        } catch (itemError) {
          console.error("❌ Erro ao criar container do item:", {
            url: imageUrl,
            error: itemError.response?.data?.error || itemError.message
          });
          throw new Error(`Falha ao criar container para item: ${imageUrl}\nDetalhes: ${JSON.stringify(itemError.response?.data?.error || itemError.message, null, 2)}`);
        }
      }

      // Verificar se todos os itens foram processados com sucesso
      const failedItems = itemStatuses.filter(item => item.status !== "FINISHED");
      if (failedItems.length > 0) {
        throw new Error(`Alguns itens do carrossel não foram processados com sucesso: ${JSON.stringify(failedItems, null, 2)}`);
      }

      console.log("\n✅ Todos os itens do carrossel foram processados com sucesso!");
      console.log("📊 Status dos itens:", JSON.stringify(itemStatuses, null, 2));

      // Etapa 2: Criar container do carrossel
      const createCarouselUrl = `${baseUrl}/${apiVersion}/${igUserId}/media`;
      console.log("\n📤 Criando container do carrossel...");
      console.log("Items:", itemIds);
      
      try {
        const carouselData = {
          media_type: "CAROUSEL",
          children: itemIds.join(','),
          caption: parsed.caption,
          access_token: accessToken
        };

        // Adicionar parâmetros opcionais se fornecidos
        if (parsed.collaborators?.length > 0) {
          carouselData.collaborators = parsed.collaborators.join(',');
        }
        if (parsed.location_id) {
          carouselData.location_id = parsed.location_id;
        }
        if (parsed.product_tags?.length > 0) {
          carouselData.product_tags = JSON.stringify(parsed.product_tags);
        }

        console.log("Dados do carrossel:", carouselData);

        const carouselResponse = await axios.post(createCarouselUrl, carouselData);

        if (!carouselResponse.data.id) {
          throw new Error("Falha ao criar container do carrossel");
        }

        const containerId = carouselResponse.data.id;
        console.log("✅ Container do carrossel criado com ID:", containerId);

        // Verificar status do container do carrossel
        let status = "IN_PROGRESS";
        let attempts = 0;
        const maxAttempts = 2; // Reduzido para 2 tentativas
        const interval = 30000; // Reduzido para 30 segundos

        console.log("\n🔄 Iniciando verificação de status do carrossel...");
        console.log("⏱️ Configuração de tempo:");
        console.log(`- Intervalo entre verificações: ${interval/1000} segundos`);
        console.log(`- Número máximo de tentativas: ${maxAttempts}`);
        console.log(`- Tempo total máximo: ${(maxAttempts * interval)/1000} segundos`);

        while (status === "IN_PROGRESS" && attempts < maxAttempts) {
          const statusUrl = `${baseUrl}/${apiVersion}/${containerId}`;
          console.log(`\n🔄 Verificação ${attempts + 1}/${maxAttempts}`);
          console.log("URL:", statusUrl);
          
          try {
            const statusResponse = await axios.get(statusUrl, {
              params: {
                fields: "status_code",
                access_token: accessToken
              }
            });

            status = statusResponse.data.status_code;
            console.log("📊 Status atual:", status);
            console.log("Detalhes completos:", JSON.stringify(statusResponse.data, null, 2));

            if (status === "IN_PROGRESS") {
              console.log("⏳ Carrossel ainda em processamento...");
              console.log(`⏱️ Aguardando ${interval/1000} segundos antes da próxima verificação...`);
              await new Promise(resolve => setTimeout(resolve, interval));
              attempts++;
            } else if (status === "FINISHED") {
              console.log("✅ Carrossel processado com sucesso!");
              console.log("📊 Status final:", JSON.stringify(statusResponse.data, null, 2));
              break;
            } else if (status === "ERROR") {
              throw new Error(`Erro no processamento do carrossel: ${JSON.stringify(statusResponse.data)}`);
            }
          } catch (statusError) {
            console.error("❌ Erro ao verificar status:", {
              message: statusError.message,
              response: statusError.response?.data,
              status: statusError.response?.status
            });
            throw new Error(`Falha ao verificar status do carrossel: ${statusError.message}`);
          }
        }

        if (status !== "FINISHED") {
          throw new Error(`Falha no processamento do carrossel. Status final: ${status}`);
        }

        // Aguardar mais 1 segundo após o status FINISHED para garantir que o carrossel esteja pronto
        console.log("\n⏳ Aguardando 1 segundo adicional para garantir que o carrossel esteja pronto...");
        await new Promise(resolve => setTimeout(resolve, 1000));

        // Publicar o carrossel
        const publishUrl = `${baseUrl}/${apiVersion}/${igUserId}/media_publish`;
        console.log("\n📤 Iniciando processo de publicação do carrossel...");
        console.log("URL:", publishUrl);
        console.log("Dados:", {
          creation_id: containerId,
          access_token: accessToken
        });
        
        try {
          const publishResponse = await axios.post(publishUrl, {
            creation_id: containerId,
            access_token: accessToken
          });

          console.log("✅ Resposta da publicação:", publishResponse.data);

          if (publishResponse.data.id) {
            console.log("🎉 Carrossel publicado com sucesso!");
            console.log("📝 ID da publicação:", publishResponse.data.id);
            
            // Aguardar 1 segundo após a publicação
            console.log("⏳ Aguardando 1 segundo para garantir que a publicação seja processada...");
            await new Promise(resolve => setTimeout(resolve, 1000));

            return {
              content: [{
                type: "text",
                text: `Carrossel publicado com sucesso!\nID da publicação: ${publishResponse.data.id}`,
              }],
            };
          } else {
            console.log("⚠️ Resposta da publicação não contém ID:", publishResponse.data);
            return {
              content: [{
                type: "text",
                text: "Aviso: A publicação pode ter sido bem-sucedida, mas não foi possível confirmar o ID.",
              }],
            };
          }
        } catch (publishError) {
          console.error("❌ Erro detalhado na publicação:", {
            message: publishError.message,
            response: publishError.response?.data,
            status: publishError.response?.status,
            headers: publishError.response?.headers,
            config: {
              url: publishError.config?.url,
              method: publishError.config?.method,
              data: publishError.config?.data
            }
          });

          // Verificar se o container ainda existe e seu status
          try {
            const checkUrl = `${baseUrl}/${apiVersion}/${containerId}`;
            const checkResponse = await axios.get(checkUrl, {
              params: {
                fields: "status_code",
                access_token: accessToken
              }
            });
            console.log("📊 Status atual do container:", checkResponse.data);
          } catch (checkError) {
            console.error("❌ Erro ao verificar status do container:", checkError.message);
          }

          let errorMessage = `Erro ao publicar carrossel: ${publishError.message}`;
          if (publishError.response?.data?.error) {
            errorMessage += `\nDetalhes do erro: ${JSON.stringify(publishError.response.data.error, null, 2)}`;
          }
          
          // Se o erro for 400, pode ser que a publicação já tenha sido feita
          if (publishError.response?.status === 400) {
            console.log("⚠️ Erro 400 detectado - possível que a publicação já tenha sido feita");
            return {
              content: [{
                type: "text",
                text: "Aviso: A publicação pode ter sido bem-sucedida, mas houve um erro na confirmação.\n" + errorMessage,
              }],
            };
          }
          
          return {
            content: [{
              type: "text",
              text: errorMessage,
            }],
          };
        }
      } catch (carouselError) {
        console.error("❌ Erro ao criar container do carrossel:", {
          message: carouselError.message,
          response: carouselError.response?.data,
          status: carouselError.response?.status
        });
        throw new Error(`Falha ao criar container do carrossel: ${carouselError.message}`);
      }
    } catch (error) {
      console.error("❌ Erro na chamada API Instagram:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status,
        headers: error.response?.headers
      });
      
      let errorMessage = `Erro ao processar carrossel: ${error.message}`;
      if (error.response?.data?.error) {
        errorMessage += `\nDetalhes: ${JSON.stringify(error.response.data.error, null, 2)}`;
      }
      
      return {
        content: [{
          type: "text",
          text: errorMessage,
        }],
      };
    }
  },

  reel: async (args) => {
    const parsed = schemas.toolInputs.reel.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("INSTAGRAM_USER_ID:", process.env.INSTAGRAM_USER_ID);
    console.log("INSTAGRAM_ACCESS_TOKEN:", process.env.INSTAGRAM_ACCESS_TOKEN);
    
    const igUserId = process.env.INSTAGRAM_USER_ID;
    const accessToken = process.env.INSTAGRAM_ACCESS_TOKEN;
    const apiVersion = "v21.0";
    const baseUrl = "https://graph.facebook.com";

    try {
      // Verificar se o vídeo já está sendo processado
      const isVideo = parsed.videoUrl.match(/\.(mp4|mov|avi|wmv|flv|mkv)$/i);
      if (!isVideo) {
        throw new Error("URL fornecida não é um vídeo válido");
      }

      // 1. Criar container do Reel
      const createUrl = `${baseUrl}/${apiVersion}/${igUserId}/media`;
      console.log("\n📤 Enviando requisição para criar container do Reel:");
      console.log("URL:", createUrl);
      console.log("Dados:", {
        media_type: "REELS",
        video_url: parsed.videoUrl,
        caption: parsed.caption,
        cover_url: parsed.coverUrl,
        share_to_feed: parsed.shareToFeed
      });

      const createResponse = await axios.post(createUrl, {
        media_type: "REELS",
        video_url: parsed.videoUrl,
        caption: parsed.caption,
        cover_url: parsed.coverUrl,
        share_to_feed: parsed.shareToFeed,
        access_token: accessToken
      });

      if (!createResponse.data.id) {
        throw new Error("Falha ao criar container do Reel");
      }

      const containerId = createResponse.data.id;
      console.log("✅ Container criado com ID:", containerId);

      // 2. Verificar status do container
      let status = "IN_PROGRESS";
      let attempts = 0;
      const maxAttempts = 15; // 15 tentativas com 40 segundos de intervalo = 600 segundos (10 minutos) máximo

      console.log("\n🔄 Iniciando verificação de status do Reel...");
      console.log("⏱️ Configuração de tempo:");
      console.log("- Intervalo entre verificações: 40 segundos");
      console.log("- Número máximo de tentativas: 15");
      console.log("- Tempo total máximo: 10 minutos");

      while (status === "IN_PROGRESS" && attempts < maxAttempts) {
        const statusUrl = `${baseUrl}/${apiVersion}/${containerId}`;
        console.log(`\n🔄 Verificação ${attempts + 1}/${maxAttempts}`);
        console.log("URL:", statusUrl);
        
        try {
          const statusResponse = await axios.get(statusUrl, {
            params: {
              fields: "status_code",
              access_token: accessToken
            }
          });

          status = statusResponse.data.status_code;
          console.log("📊 Status atual:", status);
          console.log("Detalhes completos:", JSON.stringify(statusResponse.data, null, 2));

          if (status === "IN_PROGRESS") {
            console.log("⏳ Reel ainda em processamento...");
            console.log("⏱️ Aguardando 40 segundos antes da próxima verificação...");
            await new Promise(resolve => setTimeout(resolve, 40000));
            attempts++;
          } else if (status === "FINISHED") {
            console.log("✅ Reel processado com sucesso!");
            console.log("📊 Status final:", JSON.stringify(statusResponse.data, null, 2));
            break;
          } else if (status === "ERROR") {
            throw new Error(`Erro no processamento do Reel: ${JSON.stringify(statusResponse.data)}`);
          }
        } catch (statusError) {
          console.error("❌ Erro ao verificar status:", {
            message: statusError.message,
            response: statusError.response?.data,
            status: statusError.response?.status
          });
          throw new Error(`Falha ao verificar status do Reel: ${statusError.message}`);
        }
      }

      if (status !== "FINISHED") {
        throw new Error(`Falha no processamento do Reel. Status final: ${status}`);
      }

      // Aguardar mais 5 segundos após o status FINISHED para garantir que o Reel esteja pronto
      console.log("\n⏳ Aguardando 5 segundos adicionais para garantir que o Reel esteja pronto...");
      await new Promise(resolve => setTimeout(resolve, 5000));

      // 3. Publicar o Reel
      const publishUrl = `${baseUrl}/${apiVersion}/${igUserId}/media_publish`;
      console.log("\n📤 Iniciando processo de publicação do Reel...");
      console.log("URL:", publishUrl);
      console.log("Dados:", {
        creation_id: containerId,
        access_token: accessToken
      });
      
      try {
        const publishResponse = await axios.post(publishUrl, {
          creation_id: containerId,
          access_token: accessToken
        });

        console.log("✅ Resposta da publicação:", publishResponse.data);

        return {
          content: [{
            type: "text",
            text: `Reel publicado com sucesso!\nID da publicação: ${publishResponse.data.id}`,
          }],
        };
      } catch (publishError) {
        console.error("❌ Erro detalhado na publicação:", {
          message: publishError.message,
          response: publishError.response?.data,
          status: publishError.response?.status,
          headers: publishError.response?.headers,
          config: {
            url: publishError.config?.url,
            method: publishError.config?.method,
            data: publishError.config?.data
          }
        });

        // Verificar se o container ainda existe e seu status
        try {
          const checkUrl = `${baseUrl}/${apiVersion}/${containerId}`;
          const checkResponse = await axios.get(checkUrl, {
            params: {
              fields: "status_code",
              access_token: accessToken
            }
          });
          console.log("📊 Status atual do container:", checkResponse.data);
        } catch (checkError) {
          console.error("❌ Erro ao verificar status do container:", checkError.message);
        }

        let errorMessage = `Erro ao publicar Reel: ${publishError.message}`;
        if (publishError.response?.data?.error) {
          errorMessage += `\nDetalhes do erro: ${JSON.stringify(publishError.response.data.error, null, 2)}`;
        }
        
        return {
          content: [{
            type: "text",
            text: errorMessage,
          }],
        };
      }
    } catch (error) {
      console.error("❌ Erro na chamada API Instagram:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status,
        headers: error.response?.headers
      });
      
      let errorMessage = `Erro ao processar Reel: ${error.message}`;
      if (error.response?.data?.error) {
        errorMessage += `\nDetalhes: ${JSON.stringify(error.response.data.error, null, 2)}`;
      }
      
      return {
        content: [{
          type: "text",
          text: errorMessage,
        }],
      };
    }
  },

  story: async (args) => {
    const parsed = schemas.toolInputs.story.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("INSTAGRAM_USER_ID:", process.env.INSTAGRAM_USER_ID);
    console.log("INSTAGRAM_ACCESS_TOKEN:", process.env.INSTAGRAM_ACCESS_TOKEN);
    
    const igUserId = process.env.INSTAGRAM_USER_ID;
    const accessToken = process.env.INSTAGRAM_ACCESS_TOKEN;
    const apiVersion = "v21.0";
    const baseUrl = "https://graph.facebook.com";

    try {
      // 1. Criar container do Story
      const createUrl = `${baseUrl}/${apiVersion}/${igUserId}/media`;
      console.log("\n📤 Criando container do Story...");
      console.log("URL:", createUrl);
      
      const createData = {
        media_type: "STORIES",
        access_token: accessToken
      };

      // Adicionar URL da mídia baseado no tipo
      if (parsed.mediaType === "VIDEO") {
        createData.video_url = parsed.mediaUrl;
      } else {
        createData.image_url = parsed.mediaUrl;
      }

      // Adicionar campos opcionais
      if (parsed.backgroundColor) {
        createData.background_color = parsed.backgroundColor;
      }
      if (parsed.sticker) {
        createData.sticker = JSON.stringify(parsed.sticker);
      }

      console.log("Dados:", createData);

      const createResponse = await axios.post(createUrl, createData);

      if (!createResponse.data.id) {
        throw new Error("Falha ao criar container do Story");
      }

      const containerId = createResponse.data.id;
      console.log("✅ Container criado com ID:", containerId);

      // 2. Verificar status do container apenas para vídeos
      if (parsed.mediaType === "VIDEO") {
        let status = "IN_PROGRESS";
        let attempts = 0;
        const maxAttempts = 10;
        const interval = 10000;

        console.log("\n🔄 Iniciando verificação de status do Story (vídeo)...");
        console.log("⏱️ Configuração de tempo:");
        console.log("- Intervalo entre verificações: 10 segundos");
        console.log("- Número máximo de tentativas: 10");
        console.log("- Tempo total máximo: 100 segundos");

        while (status === "IN_PROGRESS" && attempts < maxAttempts) {
          const statusUrl = `${baseUrl}/${apiVersion}/${containerId}`;
          console.log(`\n🔄 Verificação ${attempts + 1}/${maxAttempts}`);
          console.log("URL:", statusUrl);
          
          try {
            const statusResponse = await axios.get(statusUrl, {
              params: {
                fields: "status_code",
                access_token: accessToken
              }
            });

            if (!statusResponse.data) {
              throw new Error("Resposta vazia ao verificar status");
            }

            status = statusResponse.data.status_code;
            console.log("📊 Status atual:", status);

            if (status === "IN_PROGRESS") {
              console.log("⏳ Story ainda em processamento...");
              console.log(`⏱️ Aguardando ${interval/1000} segundos antes da próxima verificação...`);
              await new Promise(resolve => setTimeout(resolve, interval));
              attempts++;
            } else if (status === "FINISHED") {
              console.log("✅ Story processado com sucesso!");
              break;
            } else if (status === "ERROR") {
              throw new Error(`Erro no processamento do Story: ${JSON.stringify(statusResponse.data)}`);
            } else {
              console.log("⚠️ Status desconhecido:", status);
              throw new Error(`Status desconhecido: ${status}`);
            }
          } catch (statusError) {
            console.error("❌ Erro ao verificar status:", {
              message: statusError.message,
              response: statusError.response?.data,
              status: statusError.response?.status
            });

            // Se for erro 400, tentar novamente após um delay
            if (statusError.response?.status === 400) {
              console.log("⚠️ Erro 400 detectado, tentando novamente após delay...");
              await new Promise(resolve => setTimeout(resolve, interval));
              attempts++;
              continue;
            }

            throw new Error(`Falha ao verificar status do Story: ${statusError.message}`);
          }
        }

        if (status !== "FINISHED") {
          throw new Error(`Falha no processamento do Story. Status final: ${status}\nTentativas realizadas: ${attempts}/${maxAttempts}`);
        }

        // Aguardar mais 2 segundos após o status FINISHED
        console.log("\n⏳ Aguardando 2 segundos adicionais para garantir que o Story esteja pronto...");
        await new Promise(resolve => setTimeout(resolve, 2000));
      } else {
        console.log("📸 Imagem detectada, pulando verificação de status...");
      }

      // 3. Publicar o Story
      const publishUrl = `${baseUrl}/${apiVersion}/${igUserId}/media_publish`;
      console.log("\n📤 Iniciando processo de publicação do Story...");
      console.log("URL:", publishUrl);
      console.log("Dados:", {
        creation_id: containerId,
        access_token: accessToken
      });
      
      try {
        const publishResponse = await axios.post(publishUrl, {
          creation_id: containerId,
          access_token: accessToken
        });

        console.log("✅ Resposta da publicação:", publishResponse.data);

        // Verificar o tipo de produto após a publicação
        const verifyUrl = `${baseUrl}/${apiVersion}/${publishResponse.data.id}`;
        const verifyResponse = await axios.get(verifyUrl, {
          params: {
            fields: "media_product_type",
            access_token: accessToken
          }
        });

        console.log("📊 Verificação pós-publicação:", verifyResponse.data);

        return {
          content: [{
            type: "text",
            text: `Story publicado com sucesso!\nID da publicação: ${publishResponse.data.id}\nTipo de produto: ${verifyResponse.data.media_product_type}`,
          }],
        };
      } catch (publishError) {
        console.error("❌ Erro detalhado na publicação:", {
          message: publishError.message,
          response: publishError.response?.data,
          status: publishError.response?.status,
          headers: publishError.response?.headers,
          config: {
            url: publishError.config?.url,
            method: publishError.config?.method,
            data: publishError.config?.data
          }
        });

        // Verificar se o container ainda existe e seu status
        try {
          const checkUrl = `${baseUrl}/${apiVersion}/${containerId}`;
          const checkResponse = await axios.get(checkUrl, {
            params: {
              fields: "status_code",
              access_token: accessToken
            }
          });
          console.log("📊 Status atual do container:", checkResponse.data);
        } catch (checkError) {
          console.error("❌ Erro ao verificar status do container:", checkError.message);
        }

        let errorMessage = `Erro ao publicar Story: ${publishError.message}`;
        if (publishError.response?.data?.error) {
          errorMessage += `\nDetalhes do erro: ${JSON.stringify(publishError.response.data.error, null, 2)}`;
        }
        
        return {
          content: [{
            type: "text",
            text: errorMessage,
          }],
        };
      }
    } catch (error) {
      console.error("❌ Erro na chamada API Instagram:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status,
        headers: error.response?.headers
      });
      
      let errorMessage = `Erro ao processar Story: ${error.message}`;
      if (error.response?.data?.error) {
        errorMessage += `\nDetalhes: ${JSON.stringify(error.response.data.error, null, 2)}`;
      }
      
      return {
        content: [{
          type: "text",
          text: errorMessage,
        }],
      };
    }
  },

  media_status: async (args) => {
    const parsed = schemas.toolInputs.media_status.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("INSTAGRAM_USER_ID:", process.env.INSTAGRAM_USER_ID);
    console.log("INSTAGRAM_ACCESS_TOKEN:", process.env.INSTAGRAM_ACCESS_TOKEN);
    
    const igUserId = process.env.INSTAGRAM_USER_ID;
    const accessToken = process.env.INSTAGRAM_ACCESS_TOKEN;
    const apiVersion = "v21.0";
    const baseUrl = "https://graph.facebook.com";

    try {
      const url = `${baseUrl}/${apiVersion}/${parsed.creation_id}`;
      console.log("\n🔄 Verificando status da mídia...");
      console.log("URL:", url);
      
      const response = await axios.get(url, {
        params: {
          fields: "status_code",
          access_token: accessToken
        }
      });

      console.log("📊 Status da mídia:", response.data);

      return {
        content: [{
          type: "text",
          text: `Status da mídia:\n${JSON.stringify(response.data, null, 2)}`,
        }],
      };
    } catch (error) {
      console.error("❌ Erro ao verificar status:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status
      });
      
      let errorMessage = `Erro ao verificar status: ${error.message}`;
      if (error.response?.data?.error) {
        errorMessage += `\nDetalhes: ${JSON.stringify(error.response.data.error, null, 2)}`;
      }
      
      return {
        content: [{
          type: "text",
          text: errorMessage,
        }],
      };
    }
  },

  create_comment: async (args) => {
    const parsed = schemas.toolInputs.create_comment.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("INSTAGRAM_USER_ID:", process.env.INSTAGRAM_USER_ID);
    console.log("INSTAGRAM_ACCESS_TOKEN:", process.env.INSTAGRAM_ACCESS_TOKEN);
    
    const igUserId = process.env.INSTAGRAM_USER_ID;
    const accessToken = process.env.INSTAGRAM_ACCESS_TOKEN;
    const apiVersion = "v21.0";
    const baseUrl = "https://graph.facebook.com";

    try {
      const url = `${baseUrl}/${apiVersion}/${parsed.media_id}/comments`;
      console.log("\n📝 Criando comentário...");
      console.log("URL:", url);
      console.log("Dados:", {
        message: parsed.message,
        access_token: accessToken
      });

      const response = await axios.post(url, {
        message: parsed.message,
        access_token: accessToken
      });

      console.log("✅ Resposta da criação do comentário:", response.data);

      return {
        content: [{
          type: "text",
          text: `Comentário criado com sucesso!\nID do comentário: ${response.data.id}`,
        }],
      };
    } catch (error) {
      console.error("❌ Erro ao criar comentário:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status
      });
      
      let errorMessage = `Erro ao criar comentário: ${error.message}`;
      if (error.response?.data?.error) {
        errorMessage += `\nDetalhes: ${JSON.stringify(error.response.data.error, null, 2)}`;
      }
      
      return {
        content: [{
          type: "text",
          text: errorMessage,
        }],
      };
    }
  },

  get_comments: async (args) => {
    const parsed = schemas.toolInputs.get_comments.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("INSTAGRAM_USER_ID:", process.env.INSTAGRAM_USER_ID);
    console.log("INSTAGRAM_ACCESS_TOKEN:", process.env.INSTAGRAM_ACCESS_TOKEN);
    
    const igUserId = process.env.INSTAGRAM_USER_ID;
    const accessToken = process.env.INSTAGRAM_ACCESS_TOKEN;
    const apiVersion = "v21.0";
    const baseUrl = "https://graph.facebook.com";

    try {
      const url = `${baseUrl}/${apiVersion}/${parsed.media_id}`;
      console.log("\n📖 Obtendo comentários da publicação...");
      console.log("URL:", url);
      
      const response = await axios.get(url, {
        params: {
          fields: "comments",
          access_token: accessToken
        }
      });

      console.log("📊 Comentários obtidos:", response.data);

      if (!response.data.comments || !response.data.comments.data || response.data.comments.data.length === 0) {
        return {
          content: [{
            type: "text",
            text: "Nenhum comentário encontrado para esta publicação.",
          }],
        };
      }

      const commentsText = response.data.comments.data.map(comment => 
        `- ${comment.text} (${new Date(comment.timestamp).toLocaleString()})`
      ).join('\n');

      return {
        content: [{
          type: "text",
          text: `Comentários encontrados:\n${commentsText}\n\nTotal: ${response.data.comments.data.length}`,
        }],
      };
    } catch (error) {
      console.error("❌ Erro ao obter comentários:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status
      });
      
      let errorMessage = `Erro ao obter comentários: ${error.message}`;
      if (error.response?.data?.error) {
        errorMessage += `\nDetalhes: ${JSON.stringify(error.response.data.error, null, 2)}`;
      }
      
      return {
        content: [{
          type: "text",
          text: errorMessage,
        }],
      };
    }
  },

  create_reply: async (args) => {
    const parsed = schemas.toolInputs.create_reply.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("INSTAGRAM_USER_ID:", process.env.INSTAGRAM_USER_ID);
    console.log("INSTAGRAM_ACCESS_TOKEN:", process.env.INSTAGRAM_ACCESS_TOKEN);
    
    const igUserId = process.env.INSTAGRAM_USER_ID;
    const accessToken = process.env.INSTAGRAM_ACCESS_TOKEN;
    const apiVersion = "v21.0";
    const baseUrl = "https://graph.facebook.com";

    try {
      const url = `${baseUrl}/${apiVersion}/${parsed.comment_id}/replies`;
      console.log("\n📝 Criando resposta ao comentário...");
      console.log("URL:", url);
      console.log("Dados:", {
        message: parsed.message,
        access_token: accessToken
      });

      const response = await axios.post(url, {
        message: parsed.message,
        access_token: accessToken
      });

      console.log("✅ Resposta criada com sucesso:", response.data);

      return {
        content: [{
          type: "text",
          text: `Resposta criada com sucesso!\nID da resposta: ${response.data.id}`,
        }],
      };
    } catch (error) {
      console.error("❌ Erro ao criar resposta:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status
      });
      
      let errorMessage = `Erro ao criar resposta: ${error.message}`;
      if (error.response?.data?.error) {
        errorMessage += `\nDetalhes: ${JSON.stringify(error.response.data.error, null, 2)}`;
      }
      
      return {
        content: [{
          type: "text",
          text: errorMessage,
        }],
      };
    }
  },

  get_replies: async (args) => {
    const parsed = schemas.toolInputs.get_replies.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("INSTAGRAM_USER_ID:", process.env.INSTAGRAM_USER_ID);
    console.log("INSTAGRAM_ACCESS_TOKEN:", process.env.INSTAGRAM_ACCESS_TOKEN);
    
    const igUserId = process.env.INSTAGRAM_USER_ID;
    const accessToken = process.env.INSTAGRAM_ACCESS_TOKEN;
    const apiVersion = "v21.0";
    const baseUrl = "https://graph.facebook.com";

    try {
      const url = `${baseUrl}/${apiVersion}/${parsed.comment_id}/replies`;
      console.log("\n📖 Obtendo respostas ao comentário...");
      console.log("URL:", url);
      
      const response = await axios.get(url, {
        params: {
          access_token: accessToken
        }
      });

      console.log("📊 Respostas obtidas:", response.data);

      if (!response.data.data || response.data.data.length === 0) {
        return {
          content: [{
            type: "text",
            text: "Nenhuma resposta encontrada para este comentário.",
          }],
        };
      }

      const repliesText = response.data.data.map(reply => 
        `- ${reply.text} (${new Date(reply.timestamp).toLocaleString()})`
      ).join('\n');

      return {
        content: [{
          type: "text",
          text: `Respostas encontradas:\n${repliesText}`,
        }],
      };
    } catch (error) {
      console.error("❌ Erro ao obter respostas:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status
      });
      
      let errorMessage = `Erro ao obter respostas: ${error.message}`;
      if (error.response?.data?.error) {
        errorMessage += `\nDetalhes: ${JSON.stringify(error.response.data.error, null, 2)}`;
      }
      
      return {
        content: [{
          type: "text",
          text: errorMessage,
        }],
      };
    }
  },

  hide_comment: async (args) => {
    const parsed = schemas.toolInputs.hide_comment.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("INSTAGRAM_USER_ID:", process.env.INSTAGRAM_USER_ID);
    console.log("INSTAGRAM_ACCESS_TOKEN:", process.env.INSTAGRAM_ACCESS_TOKEN);
    
    const igUserId = process.env.INSTAGRAM_USER_ID;
    const accessToken = process.env.INSTAGRAM_ACCESS_TOKEN;
    const apiVersion = "v21.0";
    const baseUrl = "https://graph.facebook.com";

    try {
      const url = `${baseUrl}/${apiVersion}/${parsed.comment_id}/hide`;
      console.log("\n📝 Ocultando comentário...");
      console.log("URL:", url);
      console.log("Dados:", {
        access_token: accessToken
      });

      const response = await axios.post(url, {
        access_token: accessToken
      });

      console.log("✅ Resposta da ocultação do comentário:", response.data);

      return {
        content: [{
          type: "text",
          text: `Comentário ocultado com sucesso!\nID do comentário: ${parsed.comment_id}`,
        }],
      };
    } catch (error) {
      console.error("❌ Erro ao ocultar comentário:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status
      });
      
      let errorMessage = `Erro ao ocultar comentário: ${error.message}`;
      if (error.response?.data?.error) {
        errorMessage += `\nDetalhes: ${JSON.stringify(error.response.data.error, null, 2)}`;
      }
      
      return {
        content: [{
          type: "text",
          text: errorMessage,
        }],
      };
    }
  },

  private_reply: async (args) => {
    const parsed = schemas.toolInputs.private_reply.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("INSTAGRAM_USER_ID:", process.env.INSTAGRAM_USER_ID);
    console.log("INSTAGRAM_TOKEN:", process.env.INSTAGRAM_TOKEN);
    
    const igUserId = process.env.INSTAGRAM_USER_ID;
    const accessToken = process.env.INSTAGRAM_TOKEN;
    const apiVersion = "v21.0";
    const baseUrl = "https://graph.instagram.com";

    try {
      const url = `${baseUrl}/${apiVersion}/${igUserId}/messages`;
      console.log("\n📝 Enviando resposta privada...");
      console.log("URL:", url);
      console.log("Dados:", {
        recipient: {
          comment_id: parsed.comment_id
        },
        message: {
          text: parsed.message
        },
        access_token: accessToken
      });

      const response = await axios.post(url, {
        recipient: {
          comment_id: parsed.comment_id
        },
        message: {
          text: parsed.message
        },
        access_token: accessToken
      });

      console.log("✅ Resposta privada enviada com sucesso:", response.data);

      return {
        content: [{
          type: "text",
          text: `Resposta privada enviada com sucesso!\nID do destinatário: ${response.data.recipient_id}\nID da mensagem: ${response.data.message_id}`,
        }],
      };
    } catch (error) {
      console.error("❌ Erro ao enviar resposta privada:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status
      });
      
      let errorMessage = `Erro ao enviar resposta privada: ${error.message}`;
      if (error.response?.data?.error) {
        errorMessage += `\nDetalhes: ${JSON.stringify(error.response.data.error, null, 2)}`;
      }
      
      return {
        content: [{
          type: "text",
          text: errorMessage,
        }],
      };
    }
  },

  get_media_ids: async (args) => {
    const parsed = schemas.toolInputs.get_media_ids.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("INSTAGRAM_USER_ID:", process.env.INSTAGRAM_USER_ID);
    console.log("INSTAGRAM_ACCESS_TOKEN:", process.env.INSTAGRAM_ACCESS_TOKEN);
    
    const igUserId = process.env.INSTAGRAM_USER_ID;
    const accessToken = process.env.INSTAGRAM_ACCESS_TOKEN;
    const apiVersion = "v21.0";
    const baseUrl = "https://graph.facebook.com";

    try {
      const url = `${baseUrl}/${apiVersion}/${igUserId}`;
      console.log("\n📖 Obtendo IDs das publicações...");
      console.log("URL:", url);
      
      const params = {
        fields: "media",
        access_token: accessToken
      };

      if (parsed.limit) {
        params.limit = parsed.limit;
      }

      const response = await axios.get(url, { params });

      console.log("📊 Resposta obtida:", response.data);

      if (!response.data.media || !response.data.media.data || response.data.media.data.length === 0) {
        return {
          content: [{
            type: "text",
            text: "Nenhuma publicação encontrada para esta conta.",
          }],
        };
      }

      const mediaIds = response.data.media.data.map(item => item.id);
      const mediaText = mediaIds.map(id => `- ${id}`).join('\n');

      return {
        content: [{
          type: "text",
          text: `IDs das publicações encontradas:\n${mediaText}\n\nTotal: ${mediaIds.length}`,
        }],
      };
    } catch (error) {
      console.error("❌ Erro ao obter IDs das publicações:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status
      });
      
      let errorMessage = `Erro ao obter IDs das publicações: ${error.message}`;
      if (error.response?.data?.error) {
        errorMessage += `\nDetalhes: ${JSON.stringify(error.response.data.error, null, 2)}`;
      }
      
      return {
        content: [{
          type: "text",
          text: errorMessage,
        }],
      };
    }
  },

  get_comment_ids: async (args) => {
    const parsed = schemas.toolInputs.get_comment_ids.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("INSTAGRAM_USER_ID:", process.env.INSTAGRAM_USER_ID);
    console.log("INSTAGRAM_ACCESS_TOKEN:", process.env.INSTAGRAM_ACCESS_TOKEN);
    
    const igUserId = process.env.INSTAGRAM_USER_ID;
    const accessToken = process.env.INSTAGRAM_ACCESS_TOKEN;
    const apiVersion = "v21.0";
    const baseUrl = "https://graph.facebook.com";

    try {
      const url = `${baseUrl}/${apiVersion}/${parsed.media_id}`;
      console.log("\n📖 Obtendo IDs dos comentários da publicação...");
      console.log("URL:", url);
      
      const response = await axios.get(url, {
        params: {
          fields: "comments{id}",
          access_token: accessToken
        }
      });

      console.log("📊 Resposta obtida:", response.data);

      if (!response.data.comments || !response.data.comments.data || response.data.comments.data.length === 0) {
        return {
          content: [{
            type: "text",
            text: "Nenhum comentário encontrado para esta publicação.",
          }],
        };
      }

      const commentIds = response.data.comments.data.map(comment => comment.id);
      const commentIdsText = commentIds.map(id => `- ${id}`).join('\n');

      return {
        content: [{
          type: "text",
          text: `IDs dos comentários encontrados:\n${commentIdsText}\n\nTotal: ${commentIds.length}`,
        }],
      };
    } catch (error) {
      console.error("❌ Erro ao obter IDs dos comentários:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status
      });
      
      let errorMessage = `Erro ao obter IDs dos comentários: ${error.message}`;
      if (error.response?.data?.error) {
        errorMessage += `\nDetalhes: ${JSON.stringify(error.response.data.error, null, 2)}`;
      }
      
      return {
        content: [{
          type: "text",
          text: errorMessage,
        }],
      };
    }
  },
};

const server = new Server({
  name: "instagram-tools-server",
  version: "1.0.0",
}, {
  capabilities: {
    tools: {},
  },
});

server.setRequestHandler(ListToolsRequestSchema, async () => {
  console.error("Ferramenta requesitada pelo cliente");
  return { tools: TOOL_DEFINITIONS };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  try {
    const handler = toolHandlers[name];
    if (!handler) throw new Error(`Tool Desconhecida: ${name}`);
    return await handler(args);
  } catch (error) {
    console.error(`Error executando a tool ${name}:`, error);
    throw error;
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Instagram API MPC Server rodando no stdio");
}

main().catch(console.error);
