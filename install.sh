#!/bin/bash

# Cores para output
verde="\e[32m"
vermelho="\e[31m"
amarelo="\e[33m"
azul="\e[34m"
reset="\e[0m"

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${vermelho}Este script precisa ser executado como root${reset}"
    echo -e "${amarelo}Use: sudo bash install.sh${reset}"
    exit 1
fi

# Banner
echo -e "
██████╗ ██████╗  ██████╗    ███╗   ███╗ ██████╗██████╗ 
██╔══██╗██╔══██╗██╔════╝    ████╗ ████║██╔════╝██╔══██╗
██████║██████╔╝██║         ██╔████╔██║██║     ██████╔╝
██╔══██╗██╔══██╗██║         ██║╚██╔╝██║██║     ██╔═══╝
██║  ██║██████╔╝╚██████╗    ██║ ╚═╝ ██║╚██████╗██║  
╚═╝  ╚═╝╚═════╝  ╚═════╝    ╚═╝     ╚═╝ ╚═════╝╚═╝  
                                                                              
               Auto Instalador do ABC MCP
               Criado por Robson Milioli
"

# 1. Mostra as opções disponíveis
echo -e "${azul}Opções disponíveis:${reset}"
echo -e "${amarelo}1${reset} - Google Calendar MCP"
echo -e "${amarelo}2${reset} - Evolution API MCP"
echo -e "${amarelo}3${reset} - Instagram MCP"
echo -e "${amarelo}4${reset} - Sair"
echo ""

# 2. Faz a pausa e aguarda a escolha do usuário
echo -e "${amarelo}Digite a opção desejada (1, 2, 3 ou 4) e pressione ENTER${reset}"
echo -e "${vermelho}Exemplo: Digite 1 e pressione ENTER para instalar o Google Calendar MCP${reset}"
echo -e "${amarelo}Se você estiver vendo esta mensagem, o script está aguardando sua entrada${reset}"

# Tentar ler a entrada do usuário
if [ -t 0 ]; then
    # Se estiver rodando interativamente
    read -p "> " opcao
else
    # Se estiver rodando via pipe, tentar usar /dev/tty
    if [ -e /dev/tty ]; then
        read -p "> " opcao < /dev/tty
    else
        echo -e "${amarelo}Por favor, execute o script diretamente:${reset}"
        echo -e "${verde}curl -fsSL https://raw.githubusercontent.com/ABCMilioli/install-mcp/main/install.sh > install.sh${reset}"
        echo -e "${verde}sudo bash install.sh${reset}"
        exit 1
    fi
fi

# 3. Validação da entrada
if [[ ! "$opcao" =~ ^[1-4]$ ]]; then
    echo -e "${vermelho}Opção inválida!${reset}"
    echo -e "${amarelo}Por favor, execute o script novamente usando:${reset}"
    echo -e "${verde}curl -fsSL https://raw.githubusercontent.com/ABCMilioli/install-mcp/main/install.sh > install.sh${reset}"
    echo -e "${verde}sudo bash install.sh${reset}"
    exit 1
fi

# 4. Processamento da escolha
case $opcao in
    1)
        echo -e "${azul}Iniciando instalação do ABC MCP Google Calendar...${reset}"
        echo -e "${amarelo}Baixando script de configuração...${reset}"
        
        # Baixar o script setup.sh
        curl -fsSL https://raw.githubusercontent.com/ABCMilioli/install-mcp/main/setup_google.sh -o setup_google.sh
        
        if [ $? -eq 0 ]; then
            echo -e "${verde}Script baixado com sucesso!${reset}"
            chmod +x setup_google.sh
            sudo ./setup_google.sh
        else
            echo -e "${vermelho}Erro ao baixar o script. Verifique sua conexão com a internet e tente novamente.${reset}"
            exit 1
        fi
        ;;
    2)
        echo -e "${azul}Iniciando instalação do Evolution API MCP...${reset}"
        echo -e "${amarelo}Baixando script de configuração...${reset}"
        
        # Baixar o script setup.sh
        curl -fsSL https://raw.githubusercontent.com/ABCMilioli/install-mcp/main/setup_evolution.sh -o setup_evolution.sh
        
        if [ $? -eq 0 ]; then
            echo -e "${verde}Script baixado com sucesso!${reset}"
            chmod +x setup_evolution.sh
            sudo ./setup_evolution.sh
        else
            echo -e "${vermelho}Erro ao baixar o script. Verifique sua conexão com a internet e tente novamente.${reset}"
            exit 1
        fi
        ;;
    3)
        echo -e "${azul}Iniciando instalação do Instagram MCP...${reset}"
        echo -e "${amarelo}Baixando script de configuração...${reset}"
        
        # Baixar o script setup.sh
        curl -fsSL https://raw.githubusercontent.com/ABCMilioli/install-mcp/main/setup_instagram.sh -o setup_instagram.sh
        
        if [ $? -eq 0 ]; then
            echo -e "${verde}Script baixado com sucesso!${reset}"
            chmod +x setup_instagram.sh
            sudo ./setup_instagram.sh
        else
            echo -e "${vermelho}Erro ao baixar o script. Verifique sua conexão com a internet e tente novamente.${reset}"
            exit 1
        fi
        ;;
    4)
        echo -e "${amarelo}Saindo do instalador...${reset}"
        exit 0
        ;;
esac 
