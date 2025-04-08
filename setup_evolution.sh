#!/bin/bash

# Cores para output
verde="\e[32m"
vermelho="\e[31m"
amarelo="\e[33m"
azul="\e[34m"
roxo="\e[35m"
reset="\e[0m"

# Verificar sistema operacional
if [ -f /etc/debian_version ]; then
    echo -e "${azul}Sistema Debian/Ubuntu detectado${reset}"
else
    echo -e "${vermelho}Sistema operacional não suportado${reset}"
    exit 1
fi

# Acessar diretório /opt
cd /opt || {
    echo -e "${vermelho}Erro ao acessar o diretório /opt${reset}"
    exit 1
}

# Criar diretório mcp_evo
mkdir -p mcp_evo
cd mcp_evo || {
    echo -e "${vermelho}Erro ao acessar o diretório mcp_evo${reset}"
    exit 1
}

# Instalar/atualizar dependências
echo -e "${azul}Instalando/atualizando dependências...${reset}"
sudo apt update
sudo apt install -y nodejs
sudo npm install -g typescript
sudo apt install -y npm

# Inicializar projeto npm
echo -e "${azul}Inicializando projeto npm...${reset}"
npm init -y

# Instalar dependências do projeto
echo -e "${azul}Instalando dependências do projeto...${reset}"
npm install dotenv axios zod @modelcontextprotocol/sdk

# Criar arquivo index.js
echo -e "${azul}Criando arquivo index.js...${reset}"
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
    enviaMensagem: z.object({      
      number: z.string(),
      mensagem: z.string(),
    }),
    enviaMedia: z.object({      
      number: z.string(),
      mediatype: z.string(),
      mimetype: z.string(),
      caption: z.string().optional(),
      media: z.string(),
      fileName: z.string(),
    }),
    enviaAudio: z.object({      
      number: z.string(),
      audio: z.string(),
    }),
    enviaEnquete: z.object({      
      number: z.string(),
      name: z.string(),
      selectableCount: z.number(),
      values: z.array(z.string()),
    }),
    enviaLista: z.object({      
      number: z.string(),
      title: z.string(),
      description: z.string(),
      buttonText: z.string(),
      footerText: z.string(),
      sections: z.array(z.object({
        title: z.string(),
        rows: z.array(z.object({
          title: z.string(),
          description: z.string(),
          rowId: z.string()
        }))
      }))
    }),
    atualizaFotoGrupo: z.object({      
      groupJid: z.string(),
      image: z.string(),
    }),
    enviaConviteGrupo: z.object({      
      groupJid: z.string(),
      description: z.string(),
      numbers: z.array(z.string()),
    }),
    atualizaParticipantesGrupo: z.object({      
      groupJid: z.string(),
      action: z.enum(["add", "remove"]),
      participants: z.array(z.string()),
    }),
    criaGrupo: z.object({      
      subject: z.string(),
      description: z.string().optional(),
      participants: z.array(z.string()),
    }),
    buscaGrupos: z.object({      
      getParticipants: z.boolean().optional().default(false)
    }),
    buscaParticipantesGrupo: z.object({      
      groupJid: z.string()
    })
  },
};

const TOOL_DEFINITIONS = [
  {
    name: "envia_mensagem",
    description: "Envia mensagem de texto via API Evolution",
    inputSchema: {
      type: "object",
      properties: {       
        number: { type: "string", description: "Número do destinatário com DDI e DDD" },
        mensagem: { type: "string", description: "Texto da mensagem a ser enviada" },
      },
      required: ["number", "mensagem"],
    },
  },
  {
    name: "envia_media",
    description: "Envia mensagem com mídia via API Evolution",
    inputSchema: {
      type: "object",
      properties: {       
        number: { type: "string", description: "Número do destinatário com DDI e DDD" },
        mediatype: { type: "string", description: "Tipo de mídia (ex: image, video, document)" },
        mimetype: { type: "string", description: "Tipo MIME do arquivo (ex: image/png)" },
        caption: { type: "string", description: "Legenda da mídia (opcional)" },
        media: { type: "string", description: "URL da mídia" },
        fileName: { type: "string", description: "Nome do arquivo" },
      },
      required: ["number", "mediatype", "mimetype", "media", "fileName"],
    },
  },
  {
    name: "envia_audio",
    description: "Envia mensagem de áudio via API Evolution",
    inputSchema: {
      type: "object",
      properties: {       
        number: { type: "string", description: "Número do destinatário com DDI e DDD" },
        audio: { type: "string", description: "URL do arquivo de áudio" },
      },
      required: ["number", "audio"],
    },
  },
  {
    name: "envia_enquete",
    description: "Envia mensagem de enquete via API Evolution",
    inputSchema: {
      type: "object",
      properties: {       
        number: { type: "string", description: "Número do destinatário com DDI e DDD" },
        name: { type: "string", description: "Texto principal da enquete" },
        selectableCount: { type: "number", description: "Número de opções que podem ser selecionadas" },
        values: { 
          type: "array",
          items: { type: "string" },
          description: "Lista de opções da enquete"
        },
      },
      required: ["number", "name", "selectableCount", "values"],
    },
  },
  {
    name: "envia_lista",
    description: "Envia mensagem de lista interativa via API Evolution",
    inputSchema: {
      type: "object",
      properties: {       
        number: { type: "string", description: "Número do destinatário com DDI e DDD" },
        title: { type: "string", description: "Título da lista" },
        description: { type: "string", description: "Descrição da lista" },
        buttonText: { type: "string", description: "Texto do botão" },
        footerText: { type: "string", description: "Texto do rodapé" },
        sections: {
          type: "array",
          items: {
            type: "object",
            properties: {
              title: { type: "string", description: "Título da seção" },
              rows: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    title: { type: "string", description: "Título da linha" },
                    description: { type: "string", description: "Descrição da linha" },
                    rowId: { type: "string", description: "ID único da linha" }
                  },
                  required: ["title", "description", "rowId"]
                }
              }
            },
            required: ["title", "rows"]
          }
        }
      },
      required: ["number", "title", "description", "buttonText", "footerText", "sections"],
    },
  },
  {
    name: "atualiza_foto_grupo",
    description: "Atualiza a foto de perfil de um grupo via API Evolution",
    inputSchema: {
      type: "object",
      properties: {       
        groupJid: { type: "string", description: "Identificador do grupo (número@g.us)" },
        image: { type: "string", description: "URL da imagem para atualizar a foto do grupo" },
      },
      required: ["groupJid", "image"],
    },
  },
  {
    name: "envia_convite_grupo",
    description: "Envia convite para participar de um grupo via API Evolution",
    inputSchema: {
      type: "object",
      properties: {       
        groupJid: { type: "string", description: "Identificador do grupo (número@g.us)" },
        description: { type: "string", description: "Descrição do convite" },
        numbers: { 
          type: "array",
          items: { type: "string" },
          description: "Lista de números para enviar o convite"
        },
      },
      required: ["groupJid", "description", "numbers"],
    },
  },
  {
    name: "atualiza_participantes_grupo",
    description: "Adiciona ou remove participantes de um grupo via API Evolution",
    inputSchema: {
      type: "object",
      properties: {       
        groupJid: { type: "string", description: "Identificador do grupo (número@g.us)" },
        action: { type: "string", enum: ["add", "remove"], description: "Ação a ser executada (add: adicionar, remove: remover)" },
        participants: { 
          type: "array",
          items: { type: "string" },
          description: "Lista de números dos participantes"
        },
      },
      required: ["groupJid", "action", "participants"],
    },
  },
  {
    name: "cria_grupo",
    description: "Cria um grupo via API Evolution",
    inputSchema: {
      type: "object",
      properties: {        
        subject: { type: "string", description: "Nome do grupo" },
        description: { type: "string", description: "Descrição do grupo" },
        participants: {
          type: "array",
          items: { type: "string" },
          description: "Participantes do grupo (números com DDI/DDD)"
        },
      },
      required: ["subject", "participants"],
    },
  },
  {
    name: "busca_grupos",
    description: "Busca todos os grupos da instância com opção de listar participantes.",
    inputSchema: {
      type: "object",
      properties: {       
        getParticipants: { type: "boolean", description: "Listar participantes dos grupos?", default: false },
      },
      required: [],
    },
  },
  {
    name: "busca_participantes_grupo",
    description: "Busca participantes específicos de um grupo pela instância.",
    inputSchema: {
      type: "object",
      properties: {        
        groupJid: { type: "string", description: "Identificador do grupo" },
      },
      required: ["groupJid"],
    },
  },
];

const toolHandlers = {
  envia_mensagem: async (args) => {
    const parsed = schemas.toolInputs.enviaMensagem.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("EVOLUTION_INSTANCIA:", process.env.EVOLUTION_INSTANCIA);
   console.log("EVOLUTION_APIKEY:", process.env.EVOLUTION_APIKEY);
   console.log("EVOLUTION_API_BASE:", process.env.EVOLUTION_API_BASE);
    const instancia = process.env.EVOLUTION_INSTANCIA;
    const apikey = process.env.EVOLUTION_APIKEY;
    const apiBase = process.env.EVOLUTION_API_BASE || 'sua_url_evolution';

    const url = `https://${apiBase}/message/sendText/${instancia}`;
    const response = await axios.post(url, {
      number: parsed.number,
      text: parsed.mensagem,
    }, {
      headers: {
        'Content-Type': 'application/json',
        'apikey': apikey,
      },
    });
    return {
      content: [{
        type: "text",
        text: `Mensagem enviada com sucesso para ${parsed.number}.\nResposta: ${JSON.stringify(response.data)}`,
      }],
    };
  },

  envia_media: async (args) => {
    const parsed = schemas.toolInputs.enviaMedia.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("EVOLUTION_INSTANCIA:", process.env.EVOLUTION_INSTANCIA);
    console.log("EVOLUTION_APIKEY:", process.env.EVOLUTION_APIKEY);
    console.log("EVOLUTION_API_BASE:", process.env.EVOLUTION_API_BASE);
    const instancia = process.env.EVOLUTION_INSTANCIA;
    const apikey = process.env.EVOLUTION_APIKEY;
    const apiBase = process.env.EVOLUTION_API_BASE || 'sua_url_evolution';

    const url = `https://${apiBase}/message/sendMedia/${instancia}`;
    const response = await axios.post(url, {
      number: parsed.number,
      mediatype: parsed.mediatype,
      mimetype: parsed.mimetype,
      caption: parsed.caption,
      media: parsed.media,
      fileName: parsed.fileName,
    }, {
      headers: {
        'Content-Type': 'application/json',
        'apikey': apikey,
      },
    });
    return {
      content: [{
        type: "text",
        text: `Mídia enviada com sucesso para ${parsed.number}.\nResposta: ${JSON.stringify(response.data)}`,
      }],
    };
  },

  envia_audio: async (args) => {
    const parsed = schemas.toolInputs.enviaAudio.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("EVOLUTION_INSTANCIA:", process.env.EVOLUTION_INSTANCIA);
    console.log("EVOLUTION_APIKEY:", process.env.EVOLUTION_APIKEY);
    console.log("EVOLUTION_API_BASE:", process.env.EVOLUTION_API_BASE);
    const instancia = process.env.EVOLUTION_INSTANCIA;
    const apikey = process.env.EVOLUTION_APIKEY;
    const apiBase = process.env.EVOLUTION_API_BASE || 'sua_url_evolution';

    const url = `https://${apiBase}/message/sendWhatsAppAudio/${instancia}`;
    const response = await axios.post(url, {
      number: parsed.number,
      audio: parsed.audio,
    }, {
      headers: {
        'Content-Type': 'application/json',
        'apikey': apikey,
      },
    });
    return {
      content: [{
        type: "text",
        text: `Áudio enviado com sucesso para ${parsed.number}.\nResposta: ${JSON.stringify(response.data)}`,
      }],
    };
  },

  envia_enquete: async (args) => {
    const parsed = schemas.toolInputs.enviaEnquete.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("EVOLUTION_INSTANCIA:", process.env.EVOLUTION_INSTANCIA);
    console.log("EVOLUTION_APIKEY:", process.env.EVOLUTION_APIKEY);
    console.log("EVOLUTION_API_BASE:", process.env.EVOLUTION_API_BASE);
    const instancia = process.env.EVOLUTION_INSTANCIA;
    const apikey = process.env.EVOLUTION_APIKEY;
    const apiBase = process.env.EVOLUTION_API_BASE || 'sua_url_evolution';

    const url = `https://${apiBase}/message/sendPoll/${instancia}`;
    const response = await axios.post(url, {
      number: parsed.number,
      name: parsed.name,
      selectableCount: parsed.selectableCount,
      values: parsed.values,
    }, {
      headers: {
        'Content-Type': 'application/json',
        'apikey': apikey,
      },
    });
    return {
      content: [{
        type: "text",
        text: `Enquete enviada com sucesso para ${parsed.number}.\nResposta: ${JSON.stringify(response.data)}`,
      }],
    };
  },

  envia_lista: async (args) => {
    const parsed = schemas.toolInputs.enviaLista.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("EVOLUTION_INSTANCIA:", process.env.EVOLUTION_INSTANCIA);
    console.log("EVOLUTION_APIKEY:", process.env.EVOLUTION_APIKEY);
    console.log("EVOLUTION_API_BASE:", process.env.EVOLUTION_API_BASE);
    const instancia = process.env.EVOLUTION_INSTANCIA;
    const apikey = process.env.EVOLUTION_APIKEY;
    const apiBase = process.env.EVOLUTION_API_BASE || 'sua_url_evolution';

    const url = `https://${apiBase}/message/sendList/${instancia}`;
    const response = await axios.post(url, {
      number: parsed.number,
      title: parsed.title,
      description: parsed.description,
      buttonText: parsed.buttonText,
      footerText: parsed.footerText,
      sections: parsed.sections,
    }, {
      headers: {
        'Content-Type': 'application/json',
        'apikey': apikey,
      },
    });
    return {
      content: [{
        type: "text",
        text: `Lista enviada com sucesso para ${parsed.number}.\nResposta: ${JSON.stringify(response.data)}`,
      }],
    };
  },

  atualiza_foto_grupo: async (args) => {
    const parsed = schemas.toolInputs.atualizaFotoGrupo.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("EVOLUTION_INSTANCIA:", process.env.EVOLUTION_INSTANCIA);
    console.log("EVOLUTION_APIKEY:", process.env.EVOLUTION_APIKEY);
    console.log("EVOLUTION_API_BASE:", process.env.EVOLUTION_API_BASE);
    const instancia = process.env.EVOLUTION_INSTANCIA;
    const apikey = process.env.EVOLUTION_APIKEY;
    const apiBase = process.env.EVOLUTION_API_BASE || 'sua_url_evolution';

    const url = `https://${apiBase}/group/updateGroupPicture/${instancia}?groupJid=${encodeURIComponent(parsed.groupJid)}`;
    const response = await axios.post(url, {
      image: parsed.image,
    }, {
      headers: {
        'Content-Type': 'application/json',
        'apikey': apikey,
      },
    });
    return {
      content: [{
        type: "text",
        text: `Foto do grupo atualizada com sucesso!\nResposta: ${JSON.stringify(response.data)}`,
      }],
    };
  },

  envia_convite_grupo: async (args) => {
    const parsed = schemas.toolInputs.enviaConviteGrupo.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("EVOLUTION_INSTANCIA:", process.env.EVOLUTION_INSTANCIA);
    console.log("EVOLUTION_APIKEY:", process.env.EVOLUTION_APIKEY);
    console.log("EVOLUTION_API_BASE:", process.env.EVOLUTION_API_BASE);
    const instancia = process.env.EVOLUTION_INSTANCIA;
    const apikey = process.env.EVOLUTION_APIKEY;
    const apiBase = process.env.EVOLUTION_API_BASE || 'sua_url_evolution';

    const url = `https://${apiBase}/group/sendInvite/${instancia}`;
    const response = await axios.post(url, {
      groupJid: parsed.groupJid,
      description: parsed.description,
      numbers: parsed.numbers,
    }, {
      headers: {
        'Content-Type': 'application/json',
        'apikey': apikey,
      },
    });
    return {
      content: [{
        type: "text",
        text: `Convites do grupo enviados com sucesso!\nResposta: ${JSON.stringify(response.data)}`,
      }],
    };
  },

  atualiza_participantes_grupo: async (args) => {
    const parsed = schemas.toolInputs.atualizaParticipantesGrupo.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
    console.log("EVOLUTION_INSTANCIA:", process.env.EVOLUTION_INSTANCIA);
    console.log("EVOLUTION_APIKEY:", process.env.EVOLUTION_APIKEY);
    console.log("EVOLUTION_API_BASE:", process.env.EVOLUTION_API_BASE);
    const instancia = process.env.EVOLUTION_INSTANCIA;
    const apikey = process.env.EVOLUTION_APIKEY;
    const apiBase = process.env.EVOLUTION_API_BASE || 'sua_url_evolution';

    const url = `https://${apiBase}/group/updateParticipant/${instancia}?groupJid=${encodeURIComponent(parsed.groupJid)}`;
    const response = await axios.post(url, {
      action: parsed.action,
      participants: parsed.participants,
    }, {
      headers: {
        'Content-Type': 'application/json',
        'apikey': apikey,
      },
    });
    return {
      content: [{
        type: "text",
        text: `Participantes do grupo atualizados com sucesso!\nResposta: ${JSON.stringify(response.data)}`,
      }],
    };
  },

  cria_grupo: async (args) => {
    const parsed = schemas.toolInputs.criaGrupo.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
  console.log("EVOLUTION_INSTANCIA:", process.env.EVOLUTION_INSTANCIA);
  console.log("EVOLUTION_APIKEY:", process.env.EVOLUTION_APIKEY);
  console.log("EVOLUTION_API_BASE:", process.env.EVOLUTION_API_BASE);
    const instancia = process.env.EVOLUTION_INSTANCIA;
    const apikey = process.env.EVOLUTION_APIKEY;
    const apiBase = process.env.EVOLUTION_API_BASE || 'url_evolution';

    const url = `https://${apiBase}/group/create/${instancia}`;
    const response = await axios.post(url, {
      subject: parsed.subject,
      description: parsed.description,
      participants: parsed.participants,
    }, {
      headers: {
        'Content-Type': 'application/json',
        'apikey': apikey,
      },
    });
    return {
      content: [{
        type: "text",
        text: `Grupo criado com sucesso!\nResposta: ${JSON.stringify(response.data)}`,
      }],
    };
  },

  busca_grupos : async (args) => {
    const parsed = schemas.toolInputs.buscaGrupos.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
  console.log("EVOLUTION_INSTANCIA:", process.env.EVOLUTION_INSTANCIA);
  console.log("EVOLUTION_APIKEY:", process.env.EVOLUTION_APIKEY);
  console.log("EVOLUTION_API_BASE:", process.env.EVOLUTION_API_BASE);
    const instancia = process.env.EVOLUTION_INSTANCIA;
    const apikey = process.env.EVOLUTION_APIKEY;
    const apiBase = process.env.EVOLUTION_API_BASE || 'url_evolution';

    const url = `https://${apiBase}/group/fetchAllGroups/${instancia}?getParticipants=${parsed.getParticipants}`;

    try {
      const response = await axios.get(url, {
        headers: {
          'Content-Type': 'application/json',
          'apikey': apikey,
        },
      });

      return {
        content: [{
          type: "text",
          text: `Grupos obtidos com sucesso:\n${JSON.stringify(response.data, null, 2)}`,
        }],
      };

    } catch (error) {
      console.error("Erro na chamada API Evolution:", error);
      return {
        content: [{
          type: "text",
          text: `Erro ao obter grupos: ${error.message}`,
        }],
      };
    }
  },

  busca_participantes_grupo: async (args) => {
    const parsed = schemas.toolInputs.buscaParticipantesGrupo.parse(args);
    console.log("🔐 Variáveis de ambiente utilizadas:");
  console.log("EVOLUTION_INSTANCIA:", process.env.EVOLUTION_INSTANCIA);
  console.log("EVOLUTION_APIKEY:", process.env.EVOLUTION_APIKEY);
  console.log("EVOLUTION_API_BASE:", process.env.EVOLUTION_API_BASE);
    const instancia = process.env.EVOLUTION_INSTANCIA;
    const apikey = process.env.EVOLUTION_APIKEY;
    const apiBase = process.env.EVOLUTION_API_BASE || 'url_evolution';

    const url = `https://${apiBase}/group/participants/${instancia}?groupJid=${parsed.groupJid}`;

    try {
      const response = await axios.get(url, {
        headers: {
          'Content-Type': 'application/json',
          'apikey': apikey,
        },
      });

      return {
        content: [{
          type: "text",
          text: `Participantes obtidos com sucesso:\n${JSON.stringify(response.data, null, 2)}`,
        }],
      };

    } catch (error) {
      console.error("Erro na chamada API Evolution:", error);
      return {
        content: [{
          type: "text",
          text: `Erro ao obter participantes: ${error.message}`,
        }],
      };
    }
  },
};

const server = new Server({
  name: "evolution-tools-server",
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
  console.error("Evolution API MPC Server rodando no stdio");
}

const args = process.argv.slice(2);
console.log("Inicializando chamada... buscando varíaveis");
if (args.length > 0) {
  const funcao = args[0];
  const input = args[1] ? JSON.parse(args[1]) : {};

  // Exibe as variáveis de ambiente no console
  console.log("🔐 Variáveis de ambiente utilizadas:");
  console.log("EVOLUTION_INSTANCIA:", process.env.EVOLUTION_INSTANCIA);
  console.log("EVOLUTION_APIKEY:", process.env.EVOLUTION_APIKEY);
  console.log("EVOLUTION_API_BASE:", process.env.EVOLUTION_API_BASE);

  if (toolHandlers[funcao]) {
    toolHandlers[funcao](input)
      .then((res) => {
        console.log(JSON.stringify(res, null, 2));
        process.exit(0);
      })
      .catch((err) => {
        console.error(`Erro ao executar ${funcao}:`, err);
        process.exit(1);
      });
  } else {
    console.error(`❌ Função desconhecida: ${funcao}`);
    process.exit(1);
  }
} else {
  main().catch((error) => {
    console.error("Erro Fatal:", error);
    process.exit(1);
  });
}

EOL

echo -e "${verde}Evolution API MCP instalado com sucesso!${reset}" 
