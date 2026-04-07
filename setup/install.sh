#!/bin/bash
# ============================================================
# MEDUSA - Script de Instalação
# Compatível com: Debian 64-bit
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${GREEN}[+]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
error()  { echo -e "${RED}[-]${NC} $1"; }
info()   { echo -e "${BLUE}[*]${NC} $1"; }

echo -e "${RED}"
cat << 'EOF'
  __  __ _____ ____  _   _ ____    _
 |  \/  | ____|  _ \| | | / ___|  / \
 | |\/| |  _| | | | | | | \___ \ / _ \
 | |  | | |___| |_| | |_| |___) / ___ \
 |_|  |_|_____|____/ \___/|____/_/   \_\

 Bug Bounty Automation Framework
 Setup Script - Debian Edition
EOF
echo -e "${NC}"

# Verificar root
if [ "$EUID" -ne 0 ]; then
    error "Execute como root: sudo bash install.sh"
    exit 1
fi

TOOLS_DIR="/opt/medusa/tools"
WORDLISTS_DIR="/opt/medusa/wordlists"
mkdir -p "$TOOLS_DIR" "$WORDLISTS_DIR"

# ============================================================
# DEPENDÊNCIAS BASE
# ============================================================
log "Atualizando sistema e instalando dependências base..."
apt-get update -qq
apt-get install -y -qq \
    curl wget git unzip jq \
    python3 python3-pip python3-venv pipx \
    nmap masscan \
    whois dnsutils \
    build-essential libssl-dev \
    libpcap-dev \
    chromium \
    testssl.sh \
    docker.io docker-compose \
    golang-go

# Adicionar Go ao PATH se necessário
export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin:/usr/local/go/bin"
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
echo 'export PATH=$PATH:$GOPATH/bin:/usr/local/go/bin' >> ~/.bashrc

# ============================================================
# FERRAMENTAS GO
# ============================================================
log "Instalando ferramentas Go..."

GO_TOOLS=(
    "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    "github.com/projectdiscovery/httpx/cmd/httpx@latest"
    "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
    "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
    "github.com/projectdiscovery/katana/cmd/katana@latest"
    "github.com/ffuf/ffuf/v2@latest"
    "github.com/OJ/gobuster/v3@latest"
    "github.com/hahwul/dalfox/v2@latest"
    "github.com/tomnomnom/assetfinder@latest"
    "github.com/tomnomnom/waybackurls@latest"
    "github.com/tomnomnom/anew@latest"
    "github.com/tomnomnom/httprobe@latest"
    "github.com/lc/gau/v2/cmd/gau@latest"
    "github.com/sensepost/gowitness@latest"
)

for tool in "${GO_TOOLS[@]}"; do
    name=$(basename "${tool%%@*}")
    info "Instalando $name..."
    go install "$tool" 2>/dev/null && log "$name instalado" || warn "Falha ao instalar $name"
done

# ============================================================
# NUCLEI TEMPLATES
# ============================================================
log "Atualizando Nuclei templates..."
nuclei -update-templates -silent 2>/dev/null || warn "Falha ao atualizar templates nuclei"

# ============================================================
# PYTHON TOOLS
# ============================================================
log "Instalando ferramentas Python..."
pip3 install -q --break-system-packages \
    arjun \
    requests \
    python-dotenv \
    anthropic \
    openai \
    rich \
    pyyaml

# ============================================================
# GITLEAKS
# ============================================================
log "Instalando gitleaks..."
GITLEAKS_VERSION=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest | jq -r '.tag_name')
wget -q "https://github.com/gitleaks/gitleaks/releases/download/${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION#v}_linux_x64.tar.gz" -O /tmp/gitleaks.tar.gz
tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin gitleaks
chmod +x /usr/local/bin/gitleaks
log "gitleaks instalado"

# ============================================================
# WORDLISTS
# ============================================================
log "Baixando wordlists essenciais..."
if [ ! -f "$WORDLISTS_DIR/SecLists" ]; then
    git clone --depth 1 https://github.com/danielmiessler/SecLists.git "$WORDLISTS_DIR/SecLists" 2>/dev/null
    log "SecLists baixado"
fi

# ============================================================
# DOCKER / N8N
# ============================================================
log "Configurando Docker..."
systemctl enable docker 2>/dev/null
systemctl start docker 2>/dev/null
usermod -aG docker "$SUDO_USER" 2>/dev/null || true

# ============================================================
# OLLAMA (IA LOCAL)
# ============================================================
log "Instalando Ollama (IA local)..."
curl -fsSL https://ollama.ai/install.sh | sh 2>/dev/null
log "Ollama instalado. Use 'ollama pull llama3' para baixar um modelo."

# ============================================================
# LINKFINDER
# ============================================================
log "Instalando LinkFinder..."
if [ ! -d "$TOOLS_DIR/LinkFinder" ]; then
    git clone --depth 1 https://github.com/GerbenJavado/LinkFinder.git "$TOOLS_DIR/LinkFinder" 2>/dev/null
fi
pip3 install -q --break-system-packages -r "$TOOLS_DIR/LinkFinder/requirements.txt"
ln -sf "$TOOLS_DIR/LinkFinder/linkfinder.py" /usr/local/bin/linkfinder
chmod +x "$TOOLS_DIR/LinkFinder/linkfinder.py"
log "LinkFinder instalado"

# ============================================================
# TORNAR FERRAMENTAS GO DISPONÍVEIS GLOBALMENTE
# ============================================================
log "Copiando binários Go para /usr/local/bin (acesso global)..."
if [ -d "/root/go/bin" ]; then
    cp -f /root/go/bin/* /usr/local/bin/ 2>/dev/null || true
    log "Binários Go copiados para /usr/local/bin"
fi

# ============================================================
# VERIFICAÇÃO FINAL
# ============================================================
echo ""
log "============================================"
log "Instalação concluída! Verificando ferramentas"
log "============================================"

TOOLS_CHECK=(subfinder httpx nuclei dnsx naabu ffuf gobuster dalfox assetfinder waybackurls gowitness gitleaks nmap arjun)

for tool in "${TOOLS_CHECK[@]}"; do
    if command -v "$tool" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $tool"
    else
        echo -e "  ${RED}✗${NC} $tool (não encontrado)"
    fi
done

echo ""
warn "Reinicie o terminal ou execute: source ~/.bashrc"
warn "Execute 'ollama pull llama3' para baixar o modelo de IA local"
warn "Copie .env.example para .env e configure suas chaves"
log "Medusa pronta para uso!"
