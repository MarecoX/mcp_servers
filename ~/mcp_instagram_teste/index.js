const { Server } = require("@modelcontextprotocol/sdk/server/index.js");
const { StdioServerTransport } = require("@modelcontextprotocol/sdk/server/stdio.js");
const { CallToolRequestSchema, ListToolsRequestSchema } = require("@modelcontextprotocol/sdk/types.js");
const { z } = require("zod");
const axios = require("axios");
const dotenv = require("dotenv");

dotenv.config();

// Configurações da API
const igUserId = process.env.INSTAGRAM_USER_ID;
const accessToken = process.env.INSTAGRAM_ACCESS_TOKEN;
const apiVersion = process.env.API_VERSION || "v22.0";
const baseUrl = process.env.BASE_URL || "https://graph.instagram.com";

console.log("🔐 Variáveis de ambiente carregadas:");
console.log("INSTAGRAM_USER_ID:", process.env.INSTAGRAM_USER_ID ? "***" + process.env.INSTAGRAM_USER_ID.slice(-4) : "não definido");
console.log("INSTAGRAM_ACCESS_TOKEN:", process.env.INSTAGRAM_ACCESS_TOKEN ? "***" + process.env.INSTAGRAM_ACCESS_TOKEN.slice(-4) : "não definido");
console.log("API_VERSION:", apiVersion);
console.log("BASE_URL:", baseUrl);

const schemas = {
  toolInputs: {
    send_dm: z.object({
      recipientId: z.string(),
      text: z.string().optional(),
      mediaUrl: z.string().optional(),
      mediaType: z.enum(["image", "video", "audio"]).optional(),
      link: z.string().optional()
    }),
    send_image: z.object({
      recipientId: z.string(),
      imageUrl: z.string(),
      caption: z.string().optional()
    }),
    send_media: z.object({
      recipientId: z.string(),
      mediaUrl: z.string(),
      mediaType: z.enum(["audio", "video"]),
      caption: z.string().optional()
    }),
    send_sticker: z.object({
      recipientId: z.string()
    }),
    share_post: z.object({
      recipientId: z.string(),
      postId: z.string()
    }),
  }
};

// Definições das ferramentas disponíveis
const TOOL_DEFINITIONS = [
  {
    name: "send_dm",
    description: "Envia mensagem direta para usuário do Instagram",
    inputSchema: {
      type: "object",
      properties: {
        recipientId: { type: "string", description: "Instagram-scoped ID (IGSID) do destinatário" },
        text: { type: "string", description: "Texto da mensagem (opcional)" },
        mediaUrl: { type: "string", description: "URL da mídia a ser enviada (opcional)" },
        mediaType: { type: "string", enum: ["image", "video", "audio"], description: "Tipo de mídia (opcional)" },
        link: { type: "string", description: "Link para incluir na mensagem (opcional)" }
      },
      required: ["recipientId"]
    }
  },
  {
    name: "send_image",
    description: "Envia uma imagem ou GIF para um usuário do Instagram",
    inputSchema: {
      type: "object",
      properties: {
        recipientId: { type: "string", description: "Instagram-scoped ID (IGSID) do destinatário" },
        imageUrl: { type: "string", description: "URL da imagem ou GIF a ser enviada" },
        caption: { type: "string", description: "Texto opcional para acompanhar a imagem" }
      },
      required: ["recipientId", "imageUrl"]
    }
  },
  {
    name: "send_media",
    description: "Envia áudio ou vídeo para um usuário do Instagram",
    inputSchema: {
      type: "object",
      properties: {
        recipientId: { type: "string", description: "Instagram-scoped ID (IGSID) do destinatário" },
        mediaUrl: { type: "string", description: "URL do arquivo de áudio ou vídeo" },
        mediaType: { type: "string", enum: ["audio", "video"], description: "Tipo de mídia (audio ou video)" },
        caption: { type: "string", description: "Texto opcional para acompanhar a mídia" }
      },
      required: ["recipientId", "mediaUrl", "mediaType"]
    }
  },
  {
    name: "send_sticker",
    description: "Envia um sticker de coração para um usuário do Instagram",
    inputSchema: {
      type: "object",
      properties: {
        recipientId: { type: "string", description: "Instagram-scoped ID (IGSID) do destinatário" }
      },
      required: ["recipientId"]
    }
  },
  {
    name: "share_post",
    description: "Compartilha um post do Instagram com um usuário",
    inputSchema: {
      type: "object",
      properties: {
        recipientId: { type: "string", description: "Instagram-scoped ID (IGSID) do destinatário" },
        postId: { type: "string", description: "ID do post a ser compartilhado" }
      },
      required: ["recipientId", "postId"]
    }
  }
];

// Implementação dos manipuladores das ferramentas
const toolHandlers = {
  send_dm: async (args) => {
    const parsed = schemas.toolInputs.send_dm.parse(args);
    
    try {
      // Verificar se temos o ID do destinatário
      if (!parsed.recipientId) {
        throw new Error("ID do destinatário (IGSID) é obrigatório");
      }
      
      // Construir o objeto de mensagem
      const messageObj = {};
      
      // Adicionar texto se fornecido
      if (parsed.text) {
        // Verificar tamanho do texto (máximo 1000 bytes)
        const textBytes = Buffer.from(parsed.text, 'utf8').length;
        if (textBytes > 1000) {
          throw new Error("Texto excede o limite de 1000 bytes");
        }
        messageObj.text = parsed.text;
      }
      
      // Adicionar link se fornecido
      if (parsed.link) {
        // Verificar se é uma URL válida
        try {
          new URL(parsed.link);
        } catch (e) {
          throw new Error("O link fornecido não é uma URL válida");
        }
        
        // Se já tiver texto, adiciona o link ao final
        if (messageObj.text) {
          messageObj.text += "\n" + parsed.link;
        } else {
          messageObj.text = parsed.link;
        }
      }
      
      // Adicionar mídia se fornecida
      if (parsed.mediaUrl) {
        if (!parsed.mediaType) {
          throw new Error("mediaType é obrigatório quando mediaUrl é fornecido");
        }
        
        // Verificar tipo de mídia e definir o formato correto
        let attachmentType;
        switch(parsed.mediaType) {
          case "image":
            attachmentType = "image";
            // Verificar formato da imagem (png, jpeg, gif)
            if (!parsed.mediaUrl.match(/\.(png|jpe?g|gif)$/i)) {
              console.warn("⚠️ Aviso: URL da imagem não parece ter um formato suportado (png, jpeg, gif)");
            }
            break;
          case "video":
            attachmentType = "video";
            // Verificar formato do vídeo (mp4, ogg, avi, mov, webm)
            if (!parsed.mediaUrl.match(/\.(mp4|ogg|avi|mov|webm)$/i)) {
              console.warn("⚠️ Aviso: URL do vídeo não parece ter um formato suportado (mp4, ogg, avi, mov, webm)");
            }
            break;
          case "audio":
            attachmentType = "audio";
            // Verificar formato do áudio (aac, m4a, wav, mp4)
            if (!parsed.mediaUrl.match(/\.(aac|m4a|wav|mp4)$/i)) {
              console.warn("⚠️ Aviso: URL do áudio não parece ter um formato suportado (aac, m4a, wav, mp4)");
            }
            break;
          default:
            throw new Error("mediaType deve ser 'image', 'video' ou 'audio'");
        }
        
        // Adicionar attachment conforme o tipo de mídia
        messageObj.attachment = {
          type: attachmentType,
          payload: {
            url: parsed.mediaUrl
          }
        };
      }
      
      // Verificar se há conteúdo para enviar
      if (Object.keys(messageObj).length === 0) {
        throw new Error("É necessário fornecer texto, link ou mídia para enviar");
      }
      
      // Construir payload completo conforme documentação
      const payload = {
        recipient: { id: parsed.recipientId },
        message: messageObj
      };
      
      console.log("📤 Enviando mensagem para:", parsed.recipientId);
      console.log("📝 Conteúdo:", JSON.stringify(messageObj, null, 2));
      
      // Em modo de teste, simular uma resposta bem-sucedida
      if (!igUserId || !accessToken) {
        console.log("🔔 Modo de teste: simulando resposta da API");
        
        return {
          content: [{
            type: "text",
            text: `[SIMULAÇÃO] Mensagem enviada com sucesso!\nID da mensagem: msg_${Date.now()}\nID do destinatário: ${parsed.recipientId}`
          }]
        };
      }
      
      // Fazer requisição à API do Instagram conforme documentação
      const url = `${baseUrl}/${apiVersion}/${igUserId}/messages`;
      console.log("🔗 URL da API:", url);
      
      const response = await axios({
        method: 'post',
        url: url,
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        },
        data: payload
      });
      
      console.log("✅ Mensagem enviada com sucesso!");
      console.log("📊 Resposta da API:", response.data);
      
      return {
        content: [{
          type: "text",
          text: `Mensagem enviada com sucesso!\nID da mensagem: ${response.data.message_id}\nID do destinatário: ${parsed.recipientId}`
        }]
      };
    } catch (error) {
      console.error("❌ Erro ao enviar mensagem:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status
      });
      
      return {
        content: [{
          type: "text",
          text: `Erro ao enviar mensagem: ${error.message}\nDetalhes: ${JSON.stringify(error.response?.data || {}, null, 2)}`
        }]
      };
    }
  },
  
  send_image: async (args) => {
    const parsed = schemas.toolInputs.send_image.parse(args);
    
    try {
      // Verificar se o URL da imagem é válido
      try {
        new URL(parsed.imageUrl);
      } catch (e) {
        throw new Error("URL da imagem inválido");
      }
      
      // Verificar formato da imagem
      if (!parsed.imageUrl.match(/\.(png|jpe?g|gif)$/i)) {
        console.warn("⚠️ Aviso: URL da imagem não parece ter um formato suportado (png, jpeg, gif)");
      }
      
      // Construir o payload da mensagem
      const messageObj = {
        attachment: {
          type: "image",
          payload: {
            url: parsed.imageUrl
          }
        }
      };
      
      // Adicionar caption se fornecido
      if (parsed.caption) {
        // Enviar em uma mensagem separada para garantir compatibilidade
        try {
          const captionPayload = {
            recipient: { id: parsed.recipientId },
            message: { text: parsed.caption }
          };
          
          // Em modo de teste, simular envio da legenda
          if (!igUserId || !accessToken) {
            console.log("🔔 Modo de teste: simulando envio de legenda");
          } else {
            await axios({
              method: 'post',
              url: `${baseUrl}/${apiVersion}/${igUserId}/messages`,
              headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Content-Type': 'application/json'
              },
              data: captionPayload
            });
          }
          
          console.log("✅ Legenda enviada com sucesso!");
        } catch (captionError) {
          console.warn("⚠️ Erro ao enviar legenda:", captionError.message);
        }
      }
      
      // Construir payload completo
      const payload = {
        recipient: { id: parsed.recipientId },
        message: messageObj
      };
      
      console.log("📤 Enviando imagem para:", parsed.recipientId);
      console.log("🖼️ URL da imagem:", parsed.imageUrl);
      
      // Em modo de teste, simular uma resposta bem-sucedida
      if (!igUserId || !accessToken) {
        console.log("🔔 Modo de teste: simulando resposta da API");
        
        return {
          content: [{
            type: "text",
            text: `[SIMULAÇÃO] Imagem enviada com sucesso!\nID da mensagem: msg_${Date.now()}\nID do destinatário: ${parsed.recipientId}`
          }]
        };
      }
      
      // Fazer requisição à API do Instagram
      const url = `${baseUrl}/${apiVersion}/${igUserId}/messages`;
      const response = await axios({
        method: 'post',
        url: url,
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        },
        data: payload
      });
      
      console.log("✅ Imagem enviada com sucesso!");
      return {
        content: [{
          type: "text",
          text: `Imagem enviada com sucesso!\nID da mensagem: ${response.data.message_id}\nID do destinatário: ${parsed.recipientId}`
        }]
      };
    } catch (error) {
      console.error("❌ Erro ao enviar imagem:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status
      });
      
      return {
        content: [{
          type: "text",
          text: `Erro ao enviar imagem: ${error.message}\nDetalhes: ${JSON.stringify(error.response?.data || {}, null, 2)}`
        }]
      };
    }
  },
  
  send_media: async (args) => {
    const parsed = schemas.toolInputs.send_media.parse(args);
    
    try {
      // Verificar se o URL da mídia é válido
      try {
        new URL(parsed.mediaUrl);
      } catch (e) {
        throw new Error("URL da mídia inválido");
      }
      
      // Verificar formato da mídia baseado no tipo
      if (parsed.mediaType === "video") {
        if (!parsed.mediaUrl.match(/\.(mp4|ogg|avi|mov|webm)$/i)) {
          console.warn("⚠️ Aviso: URL do vídeo não parece ter um formato suportado (mp4, ogg, avi, mov, webm)");
        }
      } else if (parsed.mediaType === "audio") {
        if (!parsed.mediaUrl.match(/\.(aac|m4a|wav|mp4)$/i)) {
          console.warn("⚠️ Aviso: URL do áudio não parece ter um formato suportado (aac, m4a, wav, mp4)");
        }
      }
      
      // Construir o payload da mensagem
      const messageObj = {
        attachment: {
          type: parsed.mediaType,
          payload: {
            url: parsed.mediaUrl
          }
        }
      };
      
      // Adicionar caption se fornecido
      if (parsed.caption) {
        // Enviar em uma mensagem separada para garantir compatibilidade
        try {
          const captionPayload = {
            recipient: { id: parsed.recipientId },
            message: { text: parsed.caption }
          };
          
          // Em modo de teste, simular envio da legenda
          if (!igUserId || !accessToken) {
            console.log("🔔 Modo de teste: simulando envio de legenda");
          } else {
            await axios({
              method: 'post',
              url: `${baseUrl}/${apiVersion}/${igUserId}/messages`,
              headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Content-Type': 'application/json'
              },
              data: captionPayload
            });
          }
          
          console.log("✅ Legenda enviada com sucesso!");
        } catch (captionError) {
          console.warn("⚠️ Erro ao enviar legenda:", captionError.message);
        }
      }
      
      // Construir payload completo
      const payload = {
        recipient: { id: parsed.recipientId },
        message: messageObj
      };
      
      console.log(`📤 Enviando ${parsed.mediaType === "audio" ? "áudio" : "vídeo"} para:`, parsed.recipientId);
      console.log("🔗 URL da mídia:", parsed.mediaUrl);
      
      // Em modo de teste, simular uma resposta bem-sucedida
      if (!igUserId || !accessToken) {
        console.log("🔔 Modo de teste: simulando resposta da API");
        
        return {
          content: [{
            type: "text",
            text: `[SIMULAÇÃO] ${parsed.mediaType === "audio" ? "Áudio" : "Vídeo"} enviado com sucesso!\nID da mensagem: msg_${Date.now()}\nID do destinatário: ${parsed.recipientId}`
          }]
        };
      }
      
      // Fazer requisição à API do Instagram
      const url = `${baseUrl}/${apiVersion}/${igUserId}/messages`;
      const response = await axios({
        method: 'post',
        url: url,
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        },
        data: payload
      });
      
      console.log(`✅ ${parsed.mediaType === "audio" ? "Áudio" : "Vídeo"} enviado com sucesso!`);
      return {
        content: [{
          type: "text",
          text: `${parsed.mediaType === "audio" ? "Áudio" : "Vídeo"} enviado com sucesso!\nID da mensagem: ${response.data.message_id}\nID do destinatário: ${parsed.recipientId}`
        }]
      };
    } catch (error) {
      console.error(`❌ Erro ao enviar ${parsed.mediaType === "audio" ? "áudio" : "vídeo"}:`, {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status
      });
      
      return {
        content: [{
          type: "text",
          text: `Erro ao enviar ${parsed.mediaType === "audio" ? "áudio" : "vídeo"}: ${error.message}\nDetalhes: ${JSON.stringify(error.response?.data || {}, null, 2)}`
        }]
      };
    }
  },
  
  send_sticker: async (args) => {
    const parsed = schemas.toolInputs.send_sticker.parse(args);
    
    try {
      // Construir o payload da mensagem com sticker de coração
      const messageObj = {
        attachment: {
          type: "like_heart"
        }
      };
      
      // Construir payload completo
      const payload = {
        recipient: { id: parsed.recipientId },
        message: messageObj
      };
      
      console.log("📤 Enviando sticker de coração para:", parsed.recipientId);
      
      // Em modo de teste, simular uma resposta bem-sucedida
      if (!igUserId || !accessToken) {
        console.log("🔔 Modo de teste: simulando resposta da API");
        
        return {
          content: [{
            type: "text",
            text: `[SIMULAÇÃO] Sticker enviado com sucesso!\nID da mensagem: msg_${Date.now()}\nID do destinatário: ${parsed.recipientId}`
          }]
        };
      }
      
      // Fazer requisição à API do Instagram
      const url = `${baseUrl}/${apiVersion}/${igUserId}/messages`;
      const response = await axios({
        method: 'post',
        url: url,
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        },
        data: payload
      });
      
      console.log("✅ Sticker enviado com sucesso!");
      return {
        content: [{
          type: "text",
          text: `Sticker enviado com sucesso!\nID da mensagem: ${response.data.message_id}\nID do destinatário: ${parsed.recipientId}`
        }]
      };
    } catch (error) {
      console.error("❌ Erro ao enviar sticker:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status
      });
      
      return {
        content: [{
          type: "text",
          text: `Erro ao enviar sticker: ${error.message}\nDetalhes: ${JSON.stringify(error.response?.data || {}, null, 2)}`
        }]
      };
    }
  },
  
  share_post: async (args) => {
    const parsed = schemas.toolInputs.share_post.parse(args);
    
    try {
      // Construir o payload da mensagem com o post compartilhado
      const messageObj = {
        attachment: {
          type: "MEDIA_SHARE",
          payload: {
            id: parsed.postId
          }
        }
      };
      
      // Construir payload completo
      const payload = {
        recipient: { id: parsed.recipientId },
        message: messageObj
      };
      
      console.log("📤 Compartilhando post com:", parsed.recipientId);
      console.log("🆔 ID do post:", parsed.postId);
      
      // Em modo de teste, simular uma resposta bem-sucedida
      if (!igUserId || !accessToken) {
        console.log("🔔 Modo de teste: simulando resposta da API");
        
        return {
          content: [{
            type: "text",
            text: `[SIMULAÇÃO] Post compartilhado com sucesso!\nID da mensagem: msg_${Date.now()}\nID do destinatário: ${parsed.recipientId}\nID do post: ${parsed.postId}`
          }]
        };
      }
      
      // Fazer requisição à API do Instagram
      const url = `${baseUrl}/${apiVersion}/${igUserId}/messages`;
      const response = await axios({
        method: 'post',
        url: url,
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        },
        data: payload
      });
      
      console.log("✅ Post compartilhado com sucesso!");
      return {
        content: [{
          type: "text",
          text: `Post compartilhado com sucesso!\nID da mensagem: ${response.data.message_id}\nID do destinatário: ${parsed.recipientId}\nID do post: ${parsed.postId}`
        }]
      };
    } catch (error) {
      console.error("❌ Erro ao compartilhar post:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status
      });
      
      return {
        content: [{
          type: "text",
          text: `Erro ao compartilhar post: ${error.message}\nDetalhes: ${JSON.stringify(error.response?.data || {}, null, 2)}`
        }]
      };
    }
  }
};

// Configurar o servidor MCP
const server = new Server({
  name: "instagram-tools-server",
  version: "1.0.0",
}, {
  capabilities: {
    tools: {},
  },
});

// Registrar os manipuladores de requisições
server.setRequestHandler(ListToolsRequestSchema, async () => {
  console.error("Ferramenta requisitada pelo cliente");
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

// Iniciar o servidor
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Instagram API MPC Server rodando no stdio");
}

main().catch(console.error);
