#!/bin/bash
set -euo pipefail

# ============================================================
# CyberStrike + HexStrike AI - Automated Installer (Hardened)
# ============================================================
# Uso: sudo bash setup-cyberstrike-hexstrike.sh
#
# Recursos:
#   - Instalação isolada no diretório do usuário (sem problemas de permissão)
#   - Merge seguro do arquivo de configuração MCP
#   - Configuração opcional de serviço systemd para o servidor HexStrike
#   - Wrapper de inicialização sob demanda do servidor
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[x]${NC} $1"; exit 1; }
info() { echo -e "${CYAN}[*]${NC} $1"; }

# ─── Obtém o usuário real que executou sudo ─────────────────
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")
[[ -z "$REAL_USER" || "$REAL_USER" == "root" ]] && err "Execute com sudo por um usuário não-root"

# ─── Verifica requisitos ────────────────────────────────────
info "Verificando requisitos..."
command -v node &>/dev/null || err "Node.js não encontrado. Instale com: apt install nodejs npm"
command -v npm &>/dev/null || err "npm não encontrado."
command -v python3 &>/dev/null || err "Python3 não encontrado."
command -v git &>/dev/null || err "Git não encontrado."
command -v curl &>/dev/null || err "curl não encontrado."

# ─── Define diretórios (instalação isolada no home do usuário) ──
INSTALL_BASE="$REAL_HOME/.local/share/hexstrike-ai"
mkdir -p "$INSTALL_BASE"

HEXSTRIKE_DIR="$INSTALL_BASE/hexstrike-ai"
HEXSTRIKE_ENV="$HEXSTRIKE_DIR/hexstrike-env"
MCP_SCRIPT="$HEXSTRIKE_DIR/hexstrike_mcp.py"
API_SERVER="$HEXSTRIKE_DIR/hexstrike_server.py"
SERVICE_FILE="/etc/systemd/system/hexstrike.service"

# ─── Clona/atualiza o repositório do HexStrike ─────────────
if [[ -d "$HEXSTRIKE_DIR/.git" ]]; then
    log "HexStrike já existe. Atualizando..."
    cd "$HEXSTRIKE_DIR" && git pull
else
    log "Clonando HexStrike AI..."
    git clone https://github.com/0x4m4/hexstrike-ai.git "$HEXSTRIKE_DIR"
fi

# ─── Cria venv e instala dependências como usuário ──────────
if [[ ! -d "$HEXSTRIKE_ENV" ]]; then
    log "Criando ambiente virtual Python..."
    python3 -m venv "$HEXSTRIKE_ENV"
fi

log "Instalando dependências Python..."
"$HEXSTRIKE_ENV/bin/pip" install --upgrade pip
"$HEXSTRIKE_ENV/bin/pip" install -r "$HEXSTRIKE_DIR/requirements.txt"

# ─── Ajusta permissões para o usuário real ─────────────────
chown -R "$REAL_USER:$REAL_USER" "$HEXSTRIKE_DIR"

# ─── Instala CyberStrike via npm (global) ───────────────────
log "Instalando CyberStrike..."
npm i -g @cyberstrike-io/cyberstrike@latest

# ─── Configuração do servidor HexStrike como serviço systemd (opcional) ──
read -p "Deseja configurar o HexStrike como um serviço systemd? (s/N): " setup_service
if [[ "$setup_service" =~ ^[Ss]$ ]]; then
    log "Criando serviço systemd..."
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=HexStrike AI MCP Server
After=network.target

[Service]
Type=simple
User=$REAL_USER
WorkingDirectory=$HEXSTRIKE_DIR
Environment="PATH=$HEXSTRIKE_ENV/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=$HEXSTRIKE_ENV/bin/python3 $API_SERVER
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable hexstrike.service
    systemctl start hexstrike.service
    log "Serviço HexStrike iniciado e habilitado para iniciar com o sistema."
else
    warn "Serviço systemd não configurado."
fi

# ─── Cria wrapper para inicialização sob demanda ────────────
ORIG_BIN="/usr/local/bin/cyberstrike-orig"
MAIN_BIN="/usr/local/bin/cyberstrike"

if [[ -L "$MAIN_BIN" ]]; then
    TARGET=$(readlink "$MAIN_BIN")
    if [[ "$TARGET" != "$ORIG_BIN" ]]; then
        mv "$MAIN_BIN" "$ORIG_BIN"
    fi
elif [[ -f "$MAIN_BIN" && ! -f "$ORIG_BIN" ]]; then
    mv "$MAIN_BIN" "$ORIG_BIN"
fi

log "Criando wrapper em $MAIN_BIN..."
cat > "$MAIN_BIN" << 'WRAPPER'
#!/bin/bash
# CyberStrike wrapper - auto-starts HexStrike AI server

HEXSTRIKE_ENV="'"$HEXSTRIKE_ENV"'"
MCP_SCRIPT="'"$MCP_SCRIPT"'"
API_SERVER="'"$API_SERVER"'"

if ! pgrep -f "hexstrike_server.py" > /dev/null 2>&1; then
    if [[ -x "$MCP_SCRIPT" && -f "$API_SERVER" ]]; then
        cd "$(dirname "$API_SERVER")" 2>/dev/null || true
        if [[ -f "$HEXSTRIKE_ENV/bin/activate" ]]; then
            source "$HEXSTRIKE_ENV/bin/activate"
        fi
        nohup python3 "$API_SERVER" > /tmp/hexstrike_server.log 2>&1 &
        for i in {1..10}; do
            if curl -sf http://127.0.0.1:8888/health > /dev/null 2>&1; then
                break
            fi
            sleep 1
        done
    fi
fi

exec /usr/local/bin/cyberstrike-orig "$@"
WRAPPER
chmod +x "$MAIN_BIN"
log "Wrapper criado"

# ─── Configura MCP do HexStrike (merge seguro) ──────────────
setup_config() {
    local config_file="$1"
    local config_dir
    config_dir=$(dirname "$config_file")
    mkdir -p "$config_dir"

    local new_config_block='    "hexstrike-ai": {
      "type": "local",
      "command": [
        "'$HEXSTRIKE_ENV'/bin/python3",
        "'$MCP_SCRIPT'",
        "--server",
        "http://127.0.0.1:8888"
      ],
      "enabled": true,
      "timeout": 300000
    }'

    if [[ -f "$config_file" ]]; then
        if grep -q "hexstrike-ai" "$config_file" 2>/dev/null; then
            log "Config em $config_file já contém hexstrike-ai"
            return
        fi
        # Tenta fazer merge com sed (procura pelo final do objeto mcp)
        if grep -q '"mcp":' "$config_file" && grep -q '}' "$config_file"; then
            # Insere antes do fechamento do objeto mcp
            sed -i '/"mcp": {/a\'"$new_config_block"',' "$config_file"
            log "Configuração mesclada em $config_file"
            return
        else
            warn "Estrutura MCP não encontrada, fazendo backup e recriando..."
            cp "$config_file" "$config_file.bak"
        fi
    fi

    # Cria arquivo do zero se não existir ou se não foi possível mesclar
    cat > "$config_file" << EOF
{
  "\$schema": "https://cyberstrike.io/config.json",
  "provider": {
    "cyberstrike": {
      "options": {}
    }
  },
  "mcp": {
$new_config_block
  }
}
EOF
    log "Configuração criada em $config_file"
}

setup_config "$REAL_HOME/.config/cyberstrike/cyberstrike.jsonc"
log "Configuração MCP concluída."

# ─── Testa integração ───────────────────────────────────────
echo ""
info "Verificando integração..."

if systemctl is-active --quiet hexstrike.service 2>/dev/null; then
    server_status="rodando (systemd)"
elif pgrep -f "hexstrike_server.py" > /dev/null 2>&1; then
    server_status="rodando"
else
    server_status="parado (vai iniciar automaticamente)"
fi

if [[ -f "$MCP_SCRIPT" ]]; then
    mcp_tools=$(grep -c "@mcp.tool()" "$MCP_SCRIPT" 2>/dev/null || echo "N/A")
    mcp_status="$mcp_tools ferramentas registradas"
else
    mcp_status="MCP server não encontrado"
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Instalação concluída!                    ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC} CyberStrike:  $(cyberstrike --version 2>/dev/null || echo 'versão desconhecida')"
echo -e "${GREEN}║${NC} HexStrike:    $server_status"
echo -e "${GREEN}║${NC} Ferramentas:  $mcp_status"
echo -e "${GREEN}║${NC} Wrapper:      $MAIN_BIN"
echo -e "${GREEN}║${NC} Config:       $REAL_HOME/.config/cyberstrike/cyberstrike.jsonc"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "   ${CYAN}Comando:${NC} cyberstrike"
echo -e "   ${CYAN}Serviço (opcional):${NC} systemctl status hexstrike"
echo -e "   ${CYAN}Logs do servidor:${NC} /tmp/hexstrike_server.log"
echo ""

if [[ "$setup_service" =~ ^[Ss]$ ]]; then
    log "Serviço systemd configurado. Use 'systemctl status hexstrike' para verificar."
fi
