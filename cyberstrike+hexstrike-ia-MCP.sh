#!/bin/bash

# ============================================================
# Script: cyberstrike_hexstrike_manager.sh
# Descrição: Instalação e integração do CyberStrikeAI + HexStrike AI
# Autor: Gerado para uso no Kali Linux
# Uso: sudo ./cyberstrike_hexstrike_manager.sh
# ============================================================

# ---------------------------
# Banner personalizado (médio)
# ---------------------------
banner() {
    echo -e "\033[1;36m"
    echo " ╔══════════════════════════════════════════════════════════════╗"
    echo " ║                    CYBERSTRIKE + HEXSTRIKE                    ║"
    echo " ║                   Integração Automática v1.0                  ║"
    echo " ║                      🔒 Segurança Ofensiva 🔒                  ║"
    echo " ╚══════════════════════════════════════════════════════════════╝"
    echo -e "\033[0m"
    echo -e "\033[1;33m  -> Ferramentas para pentest e automação com IA <-\033[0m"
    echo ""
}

# ---------------------------
# Variáveis globais
# ---------------------------
BASE_DIR="/usr/local/cyberstrike_hexstrike"
CYBERSTRIKE_DIR="$BASE_DIR/cyberstrike"
HEXSTRIKE_DIR="$BASE_DIR/hexstrike-ai"
MCP_AI_DIR="$CYBERSTRIKE_DIR/mcp/hexstrike"
LOG_FILE="/var/log/cyberstrike_hexstrike.log"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ---------------------------
# Funções auxiliares
# ---------------------------
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[ERRO] Este script precisa ser executado como root (use sudo).${NC}"
        exit 1
    fi
}

press_enter() {
    echo ""
    read -p "Pressione [Enter] para continuar..."
}

instalar_dependencias() {
    echo -e "${BLUE}[*] Atualizando sistema e instalando dependências...${NC}"
    apt update && apt upgrade -y
    apt install -y git wget unzip default-jre python3 python3-pip python3-venv curl
    log "Dependências básicas instaladas."
}

clonar_cyberstrike() {
    echo -e "${BLUE}[*] Clonando CyberStrikeAI...${NC}"
    mkdir -p "$BASE_DIR"
    if [ -d "$CYBERSTRIKE_DIR" ]; then
        echo -e "${YELLOW}[!] Diretório já existe. Atualizando...${NC}"
        cd "$CYBERSTRIKE_DIR" && git pull
    else
        git clone https://github.com/CyberStrikeus/CyberStrike.git "$CYBERSTRIKE_DIR"
    fi
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}[✔] CyberStrikeAI instalado em $CYBERSTRIKE_DIR${NC}"
        log "CyberStrikeAI clonado com sucesso."
    else
        echo -e "${RED}[ERRO] Falha ao clonar CyberStrikeAI.${NC}"
        log "ERRO ao clonar CyberStrikeAI."
        exit 1
    fi
}

clonar_hexstrike() {
    echo -e "${BLUE}[*] Clonando HexStrike AI...${NC}"
    mkdir -p "$BASE_DIR"
    if [ -d "$HEXSTRIKE_DIR" ]; then
        echo -e "${YELLOW}[!] Diretório já existe. Atualizando...${NC}"
        cd "$HEXSTRIKE_DIR" && git pull
    else
        git clone https://github.com/0x4m4/hexstrike-ai.git "$HEXSTRIKE_DIR"
    fi
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}[✔] HexStrike AI instalado em $HEXSTRIKE_DIR${NC}"
        log "HexStrike AI clonado com sucesso."
    else
        echo -e "${RED}[ERRO] Falha ao clonar HexStrike AI.${NC}"
        log "ERRO ao clonar HexStrike AI."
        exit 1
    fi
}

integrar_hexstrike_mcp() {
    echo -e "${BLUE}[*] Integrando HexStrike AI como MCP no CyberStrike...${NC}"
    if [[ ! -d "$CYBERSTRIKE_DIR" ]] || [[ ! -d "$HEXSTRIKE_DIR" ]]; then
        echo -e "${RED}[ERRO] CyberStrike ou HexStrike não encontrados. Instale primeiro.${NC}"
        return 1
    fi
    mkdir -p "$MCP_AI_DIR"
    
    # Copiar arquivos principais do HexStrike para o MCP
    cp -r "$HEXSTRIKE_DIR/"* "$MCP_AI_DIR/" 2>/dev/null
    
    # Garantir permissão de execução para scripts principais
    chmod +x "$MCP_AI_DIR/hexstrike_mcp.py" 2>/dev/null
    chmod +x "$MCP_AI_DIR/run.py" 2>/dev/null
    
    # Instalar dependências Python dentro do diretório do MCP (opcional)
    if [ -f "$MCP_AI_DIR/requirements.txt" ]; then
        echo -e "${BLUE}[*] Instalando dependências Python do HexStrike...${NC}"
        pip3 install -r "$MCP_AI_DIR/requirements.txt" >> "$LOG_FILE" 2>&1
    fi
    
    echo -e "${GREEN}[✔] HexStrike AI integrado ao MCP do CyberStrike em: $MCP_AI_DIR${NC}"
    log "HexStrike integrado ao MCP."
    
    # Criar link simbólico global para iniciar o servidor HexStrike MCP
    ln -sf "$MCP_AI_DIR/hexstrike_mcp.py" /usr/local/bin/hexstrike-mcp
    echo -e "${GREEN}[✔] Comando 'hexstrike-mcp' criado para iniciar o servidor MCP.${NC}"
}

configurar_cyberstrike_mcp() {
    echo -e "${BLUE}[*] Configurando CyberStrike para reconhecer o MCP externo...${NC}"
    CONFIG_FILE="$CYBERSTRIKE_DIR/config.yaml"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}[!] config.yaml não encontrado. Criando arquivo básico...${NC}"
        cat > "$CONFIG_FILE" <<EOF
# CyberStrikeAI Configuration
external_mcp:
  enable: true
  servers:
    hexstrike:
      transport: http
      url: "http://127.0.0.1:8888"
      description: "HexStrike AI - Ferramentas de segurança ofensiva"
      timeout: 300
EOF
    else
        # Verificar se a seção hexstrike já existe, se não adicionar
        if ! grep -q "hexstrike:" "$CONFIG_FILE"; then
            echo -e "\n# Integração HexStrike AI" >> "$CONFIG_FILE"
            echo "external_mcp:" >> "$CONFIG_FILE"
            echo "  enable: true" >> "$CONFIG_FILE"
            echo "  servers:" >> "$CONFIG_FILE"
            echo "    hexstrike:" >> "$CONFIG_FILE"
            echo "      transport: http" >> "$CONFIG_FILE"
            echo "      url: \"http://127.0.0.1:8888\"" >> "$CONFIG_FILE"
            echo "      description: \"HexStrike AI - Ferramentas de segurança ofensiva\"" >> "$CONFIG_FILE"
            echo "      timeout: 300" >> "$CONFIG_FILE"
        else
            echo -e "${GREEN}[✔] Configuração do HexStrike já presente no config.yaml.${NC}"
        fi
    fi
    echo -e "${GREEN}[✔] Configuração aplicada. Lembre-se de iniciar o servidor HexStrike MCP antes do CyberStrike.${NC}"
    log "Configuração MCP adicionada ao CyberStrike."
}

iniciar_hexstrike_server() {
    echo -e "${BLUE}[*] Iniciando servidor MCP do HexStrike...${NC}"
    if [ ! -f "$MCP_AI_DIR/hexstrike_mcp.py" ]; then
        echo -e "${RED}[ERRO] Script hexstrike_mcp.py não encontrado. Execute a integração primeiro.${NC}"
        return 1
    fi
    cd "$MCP_AI_DIR"
    python3 hexstrike_mcp.py &
    SERVER_PID=$!
    echo -e "${GREEN}[✔] Servidor HexStrike MCP iniciado com PID $SERVER_PID${NC}"
    echo -e "${YELLOW}   -> Acessível em http://127.0.0.1:8888${NC}"
    log "Servidor HexStrike MCP iniciado (PID $SERVER_PID)"
}

criar_atalhos_globais() {
    echo -e "${BLUE}[*] Criando atalhos globais...${NC}"
    ln -sf "$CYBERSTRIKE_DIR/run.py" /usr/local/bin/cyberstrike
    ln -sf "$HEXSTRIKE_DIR/run.py" /usr/local/bin/hexstrike
    chmod +x /usr/local/bin/cyberstrike /usr/local/bin/hexstrike
    echo -e "${GREEN}[✔] Comandos 'cyberstrike' e 'hexstrike' disponíveis globalmente.${NC}"
    log "Atalhos globais criados."
}

menu_principal() {
    while true; do
        clear
        banner
        echo -e "${YELLOW}==================== MENU PRINCIPAL ====================${NC}"
        echo " 1) Instalar todas as dependências"
        echo " 2) Instalar CyberStrikeAI"
        echo " 3) Instalar HexStrike AI"
        echo " 4) Integrar HexStrike AI como MCP no CyberStrike"
        echo " 5) Configurar CyberStrike para usar o MCP (config.yaml)"
        echo " 6) Iniciar servidor HexStrike MCP (background)"
        echo " 7) Criar atalhos globais (cyberstrike / hexstrike)"
        echo " 8) Executar INSTALAÇÃO COMPLETA (passos 1 a 7)"
        echo " 9) Sair"
        echo -e "${YELLOW}========================================================${NC}"
        read -p "Escolha uma opção [1-9]: " opcao
        
        case $opcao in
            1) instalar_dependencias; press_enter ;;
            2) clonar_cyberstrike; press_enter ;;
            3) clonar_hexstrike; press_enter ;;
            4) integrar_hexstrike_mcp; press_enter ;;
            5) configurar_cyberstrike_mcp; press_enter ;;
            6) iniciar_hexstrike_server; press_enter ;;
            7) criar_atalhos_globais; press_enter ;;
            8)
                echo -e "${BLUE}[*] Executando instalação completa...${NC}"
                instalar_dependencias
                clonar_cyberstrike
                clonar_hexstrike
                integrar_hexstrike_mcp
                configurar_cyberstrike_mcp
                criar_atalhos_globais
                echo -e "${GREEN}[✔] Instalação completa finalizada!${NC}"
                echo -e "${YELLOW}➡️ Para iniciar o servidor HexStrike MCP, use a opção 6 do menu.${NC}"
                log "Instalação completa executada."
                press_enter
                ;;
            9) 
                echo -e "${GREEN}Saindo...${NC}"
                exit 0
                ;;
            *) echo -e "${RED}Opção inválida.${NC}"; sleep 1 ;;
        esac
    done
}

# ---------------------------
# Execução principal
# ---------------------------
check_root
menu_principal