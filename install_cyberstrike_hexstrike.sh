#!/bin/bash

# Cores para destacar a saída
GREEN="\033[0;32m"
RED="\033[0;31m"
NO_COLOR="\033[0m"

echo -e "${GREEN}[+] Atualizando o sistema e instalando dependências globais...${NO_COLOR}"

# Atualizar pacotes e instalar dependências necessárias
sudo apt update && sudo apt upgrade -y
sudo apt install -y default-jre default-jdk python3 python3-pip git wget unzip

# Preparando diretórios globais
GLOBAL_DIR="/usr/local/cyberstrike_hexstrike"
BIN_DIR="/usr/local/bin"
sudo mkdir -p "$GLOBAL_DIR"

# Instalando CyberStrike
echo -e "${GREEN}[+] Baixando e instalando o CyberStrike...${NO_COLOR}"
CYBERSTRIKE_URL="https://github.com/CyberStrikeus/CyberStrike"  # Substitua pela URL correta
CYBERSTRIKE_DIR="$GLOBAL_DIR/cyberstrike"

if [ ! -d "$CYBERSTRIKE_DIR" ]; then
    git clone "$CYBERSTRIKE_URL" "$CYBERSTRIKE_DIR"
else
    echo -e "${RED}[-] CyberStrike já está instalado globalmente.${NO_COLOR}"
fi

# Adicionando CyberStrike globalmente
sudo ln -s "$CYBERSTRIKE_DIR/start.sh" "$BIN_DIR/cyberstrike"

# Instalando HexStrike AI
echo -e "${GREEN}[+] Baixando e instalando o HexStrike...${NO_COLOR}"
HEXSTRIKE_URL="https://github.com/0x4m4/hexstrike-ai"  # Substitua pela URL correta
HEXSTRIKE_DIR="$GLOBAL_DIR/hexstrike-ai"

if [ ! -d "$HEXSTRIKE_DIR" ]; then
    git clone "$HEXSTRIKE_URL" "$HEXSTRIKE_DIR"
else
    echo -e "${RED}[-] HexStrike já está instalado globalmente.${NO_COLOR}"
fi

# Adicionando HexStrike globalmente
sudo ln -s "$HEXSTRIKE_DIR/start.sh" "$BIN_DIR/hexstrike"

# Finalização
echo -e "${GREEN}[+] Instalação e configuração global concluídas!${NO_COLOR}"
echo -e "CyberStrike pode ser executado com: ${GREEN}cyberstrike${NO_COLOR}"
echo -e "HexStrike pode ser executado com: ${GREEN}hexstrike${NO_COLOR}"