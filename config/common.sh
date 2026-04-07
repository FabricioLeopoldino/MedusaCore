#!/bin/bash
# ============================================================
# MEDUSA — Configurações comuns a todos os scripts
# ============================================================

# Carregar .env se existir
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    export $(grep -v '^#' "$SCRIPT_DIR/.env" | xargs)
fi

# Carregar settings
if [ -f "$SCRIPT_DIR/config/settings.yaml" ]; then
    THREADS=$(grep 'threads:' "$SCRIPT_DIR/config/settings.yaml" | awk '{print $2}')
    TIMEOUT=$(grep 'timeout:' "$SCRIPT_DIR/config/settings.yaml" | awk '{print $2}')
    RATE_LIMIT=$(grep 'rate_limit:' "$SCRIPT_DIR/config/settings.yaml" | awk '{print $2}')
fi

THREADS="${THREADS:-10}"
TIMEOUT="${TIMEOUT:-30}"
RATE_LIMIT="${RATE_LIMIT:-150}"
OUTPUT_DIR="${SCRIPT_DIR}/output"

# Carregar alvo do targets.yaml se não passado como argumento
if [ -z "$TARGET_DOMAIN" ] && [ -f "$SCRIPT_DIR/config/targets.yaml" ]; then
    TARGET_DOMAIN=$(grep 'domain:' "$SCRIPT_DIR/config/targets.yaml" | head -1 | awk '{print $2}')
fi

# Cores e logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[-]${NC} $1" >&2; }
info()  { echo -e "${BLUE}[*]${NC} $1"; }
