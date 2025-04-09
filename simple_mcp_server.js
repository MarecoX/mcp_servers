// Servidor MCP simplificado para testes
const readline = require('readline');

// Definir as ferramentas disponíveis
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
  }
];

// Configurar o leitor de linha para ler do stdin
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

// Processar cada linha de entrada como uma requisição JSON-RPC
rl.on('line', (line) => {
  try {
    const request = JSON.parse(line);
    console.error(`Requisição recebida: ${JSON.stringify(request)}`);
    
    // Processar a requisição
    if (request.method === "listTools") {
      // Responder com a lista de ferramentas
      const response = {
        jsonrpc: "2.0",
        id: request.id,
        result: { tools: TOOL_DEFINITIONS }
      };
      console.log(JSON.stringify(response));
    } else if (request.method === "callTool") {
      // Processar a chamada da ferramenta
      const { name, arguments: args } = request.params;
      
      if (name === "send_dm") {
        // Simular o envio de uma mensagem direta
        console.error(`Simulando envio de mensagem para: ${args.recipientId}`);
        console.error(`Texto: ${args.text || "(nenhum)"}`);
        
        // Responder com sucesso
        const response = {
          jsonrpc: "2.0",
          id: request.id,
          result: {
            content: [{
              type: "text",
              text: `[SIMULAÇÃO] Mensagem enviada com sucesso!\nID da mensagem: msg_${Date.now()}\nID do destinatário: ${args.recipientId}`
            }]
          }
        };
        console.log(JSON.stringify(response));
      } else if (name === "send_image") {
        // Simular o envio de uma imagem
        console.error(`Simulando envio de imagem para: ${args.recipientId}`);
        console.error(`URL da imagem: ${args.imageUrl}`);
        console.error(`Legenda: ${args.caption || "(nenhuma)"}`);
        
        // Responder com sucesso
        const response = {
          jsonrpc: "2.0",
          id: request.id,
          result: {
            content: [{
              type: "text",
              text: `[SIMULAÇÃO] Imagem enviada com sucesso!\nID da mensagem: msg_${Date.now()}\nID do destinatário: ${args.recipientId}`
            }]
          }
        };
        console.log(JSON.stringify(response));
      } else {
        // Ferramenta desconhecida
        const response = {
          jsonrpc: "2.0",
          id: request.id,
          error: {
            code: -32601,
            message: `Ferramenta desconhecida: ${name}`
          }
        };
        console.log(JSON.stringify(response));
      }
    } else {
      // Método desconhecido
      const response = {
        jsonrpc: "2.0",
        id: request.id,
        error: {
          code: -32601,
          message: `Método desconhecido: ${request.method}`
        }
      };
      console.log(JSON.stringify(response));
    }
  } catch (error) {
    // Erro ao processar a requisição
    console.error(`Erro ao processar requisição: ${error.message}`);
    const response = {
      jsonrpc: "2.0",
      id: null,
      error: {
        code: -32700,
        message: `Erro ao processar requisição: ${error.message}`
      }
    };
    console.log(JSON.stringify(response));
  }
});

// Iniciar o servidor
console.error("Servidor MCP simplificado para testes iniciado");
console.error("Aguardando requisições...");
console.error("Pressione Ctrl+C para encerrar");
