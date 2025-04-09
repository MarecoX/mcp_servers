const { Server } = require('@modelcontextprotocol/sdk').Server;
const { StdioServerTransport } = require('@modelcontextprotocol/sdk').StdioServerTransport;
const { z } = require('zod');

// Definir um servidor MCP simples
const server = new Server({
  name: "mcp-teste-server",
  version: "1.0.0",
}, {
  capabilities: {
    tools: {},
  },
});

// Definir uma ferramenta simples
const TOOL_DEFINITIONS = [
  {
    name: "hello_world",
    description: "Retorna uma saudação simples",
    inputSchema: {
      type: "object",
      properties: {
        name: { type: "string", description: "Nome para saudar" }
      },
      required: ["name"]
    }
  }
];

// Implementar o manipulador da ferramenta
const toolHandlers = {
  hello_world: async (args) => {
    const name = args.name || "Mundo";
    console.error(`Executando hello_world com nome: ${name}`);
    
    return {
      content: [{
        type: "text",
        text: `Olá, ${name}! Este é um teste do servidor MCP.`
      }]
    };
  }
};

// Registrar os manipuladores de requisições
server.setRequestHandler({ method: "listTools" }, async () => {
  console.error("Ferramentas requisitadas pelo cliente");
  return { tools: TOOL_DEFINITIONS };
});

server.setRequestHandler({ method: "callTool" }, async (request) => {
  const { name, arguments: args } = request.params;
  console.error(`Chamada para a ferramenta: ${name}`);
  
  try {
    const handler = toolHandlers[name];
    if (!handler) throw new Error(`Ferramenta desconhecida: ${name}`);
    return await handler(args);
  } catch (error) {
    console.error(`Erro executando a ferramenta ${name}:`, error);
    throw error;
  }
});

// Iniciar o servidor
async function main() {
  console.error("Iniciando servidor MCP de teste...");
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Servidor MCP de teste rodando no stdio");
}

main().catch(console.error);
