const { spawn } = require('child_process');
const path = require('path');

// Função para enviar uma requisição JSON-RPC para o processo MCP
function sendRequest(process, request) {
  const requestStr = JSON.stringify(request) + '\n';
  process.stdin.write(requestStr);
  console.log(`Enviando requisição: ${requestStr.trim()}`);
}

// Iniciar o processo MCP
console.log('Iniciando o servidor MCP simplificado...');
const mcpProcess = spawn('node', ['simple_mcp_server.js']);

// Capturar a saída do processo MCP
let buffer = '';
mcpProcess.stdout.on('data', (data) => {
  const chunk = data.toString();
  buffer += chunk;
  
  // Processar linhas completas
  const lines = buffer.split('\n');
  buffer = lines.pop(); // Manter o que sobrou para a próxima vez
  
  for (const line of lines) {
    if (line.trim()) {
      try {
        const response = JSON.parse(line);
        console.log('Resposta do MCP:', JSON.stringify(response, null, 2));
      } catch (e) {
        console.log('Saída do MCP (não é JSON):', line);
      }
    }
  }
});

// Capturar erros
mcpProcess.stderr.on('data', (data) => {
  console.error('Log do MCP:', data.toString());
});

// Quando o processo terminar
mcpProcess.on('close', (code) => {
  console.log(`Processo MCP encerrado com código ${code}`);
  process.exit(0);
});

// Esperar um pouco antes de enviar a primeira requisição
setTimeout(() => {
  console.log('Enviando requisição para listar ferramentas...');
  
  // Simular uma requisição para listar ferramentas
  const listToolsRequest = {
    jsonrpc: "2.0",
    id: "1",
    method: "listTools",
    params: {}
  };
  
  sendRequest(mcpProcess, listToolsRequest);
  
  // Esperar um pouco antes de enviar a próxima requisição
  setTimeout(() => {
    console.log('Enviando requisição para testar a ferramenta send_dm...');
    
    // Simular uma chamada da ferramenta send_dm
    const callToolRequest = {
      jsonrpc: "2.0",
      id: "2",
      method: "callTool",
      params: {
        name: "send_dm",
        arguments: {
          recipientId: "123456789",
          text: "Olá, esta é uma mensagem de teste!"
        }
      }
    };
    
    sendRequest(mcpProcess, callToolRequest);
    
    // Esperar um pouco antes de enviar a próxima requisição
    setTimeout(() => {
      console.log('Enviando requisição para testar a ferramenta send_image...');
      
      // Simular uma chamada da ferramenta send_image
      const callImageRequest = {
        jsonrpc: "2.0",
        id: "3",
        method: "callTool",
        params: {
          name: "send_image",
          arguments: {
            recipientId: "123456789",
            imageUrl: "https://example.com/image.jpg",
            caption: "Esta é uma imagem de teste"
          }
        }
      };
      
      sendRequest(mcpProcess, callImageRequest);
      
      // Encerrar o teste após 5 segundos
      setTimeout(() => {
        console.log('Encerrando teste...');
        mcpProcess.kill();
      }, 5000);
    }, 2000);
  }, 2000);
}, 2000);
