#!/bin/bash

# Variáveis
CYBERSTRIKE_DIR="/usr/local/cyberstrike_hexstrike/cyberstrike"
HEXSTRIKE_DIR="/usr/local/cyberstrike_hexstrike/hexstrike-ai"
AI_TARGET_DIR="$CYBERSTRIKE_DIR/mcp/ai"

# Verificar se os diretórios existem
if [ ! -d "$CYBERSTRIKE_DIR" ]; then
    echo "[-] Diretório do CyberStrike não encontrado em $CYBERSTRIKE_DIR."
    exit 1
fi

if [ ! -d "$HEXSTRIKE_DIR" ]; then
    echo "[-] Diretório do HexStrike-AI não encontrado em $HEXSTRIKE_DIR."
    exit 1
fi

# Criar diretório de integração no MCP
mkdir -p "$AI_TARGET_DIR"

# Copiar HexStrike AI para o MCP do CyberStrike
echo "[+] Integrando o HexStrike AI no MCP do CyberStrike..."
cp -r "$HEXSTRIKE_DIR/"* "$AI_TARGET_DIR/"

echo "[+] Integração concluída!"
echo "HexStrike AI foi adicionado ao MCP do CyberStrike."