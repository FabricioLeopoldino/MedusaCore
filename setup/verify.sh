#!/bin/bash
# ============================================================
# MEDUSA - Verificação de Ferramentas
# ============================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

OK=0
FAIL=0

check() {
    if command -v "$1" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $1"
        ((OK++))
    else
        echo -e "  ${RED}✗${NC} $1 — NÃO ENCONTRADO"
        ((FAIL++))
    fi
}

echo "=== MEDUSA — Verificação de Ferramentas ==="
echo ""

echo "[ Reconhecimento ]"
check subfinder
check assetfinder
check dnsx
check waybackurls
check gau
check whois

echo ""
echo "[ Scanning Ativo ]"
check nmap
check naabu
check httpx
check gowitness
check katana

echo ""
echo "[ Vulnerabilidades ]"
check nuclei
check ffuf
check gobuster
check testssl.sh
check arjun

echo ""
echo "[ Análise Profunda ]"
check dalfox
check gitleaks
check linkfinder

echo ""
echo "[ Infraestrutura ]"
check docker
check docker-compose
check ollama
check python3
check pip3

echo ""
echo "================================"
echo -e "  ${GREEN}OK:${NC}   $OK ferramentas"
echo -e "  ${RED}Faltam:${NC} $FAIL ferramentas"
echo "================================"

if [ "$FAIL" -gt 0 ]; then
    echo -e "${YELLOW}Execute: sudo bash setup/install.sh${NC}"
fi
