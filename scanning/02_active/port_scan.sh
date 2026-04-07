#!/bin/bash
# ============================================================
# FASE 2 — Port Scanning
# Ferramentas: naabu (rápido), nmap (detalhado)
# Input:  output/recon/subdomains_resolved.txt
# Output: output/active/ports.txt, ports_detail.xml
# ============================================================

source "$(dirname "$0")/../../config/common.sh"

TARGET="${1:-$TARGET_DOMAIN}"
OUT_DIR="$OUTPUT_DIR/active"
RECON_DIR="$OUTPUT_DIR/recon"
mkdir -p "$OUT_DIR"

INPUT="${2:-$RECON_DIR/subdomains_resolved.txt}"

if [ ! -f "$INPUT" ] && [ -z "$TARGET" ]; then
    error "Uso: $0 <dominio|lista_hosts>"
    exit 1
fi

log "Iniciando port scan..."
START_TIME=$(date +%s)

# --- Naabu: scan rápido de portas comuns ---
info "naabu: scan rápido de portas comuns..."
if [ -f "$INPUT" ]; then
    naabu -list "$INPUT" \
          -top-ports 1000 \
          -silent \
          -rate "$RATE_LIMIT" \
          -o "$OUT_DIR/ports_open.txt" 2>/dev/null
else
    naabu -host "$TARGET" \
          -top-ports 1000 \
          -silent \
          -rate "$RATE_LIMIT" \
          -o "$OUT_DIR/ports_open.txt" 2>/dev/null
fi

OPEN_PORTS=$(wc -l < "$OUT_DIR/ports_open.txt" 2>/dev/null || echo 0)
log "Portas abertas encontradas: $OPEN_PORTS"

# --- Nmap: fingerprint detalhado dos serviços abertos ---
info "nmap: detalhamento de serviços..."
if [ -f "$OUT_DIR/ports_open.txt" ] && [ "$OPEN_PORTS" -gt 0 ]; then
    # Extrair hosts únicos
    cut -d: -f1 "$OUT_DIR/ports_open.txt" | sort -u > "$OUT_DIR/hosts_with_ports.txt"

    nmap -iL "$OUT_DIR/hosts_with_ports.txt" \
         -sV -sC \
         --open \
         -T4 \
         --max-retries 2 \
         --host-timeout "${TIMEOUT}s" \
         -oX "$OUT_DIR/ports_detail.xml" \
         -oN "$OUT_DIR/ports_detail.txt" 2>/dev/null

    log "Detalhes nmap salvos em: $OUT_DIR/ports_detail.txt"
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

log "Port scan concluído em ${ELAPSED}s"

echo "{\"phase\":\"active\",\"step\":\"port_scan\",\"target\":\"$TARGET\",\"open_ports\":$OPEN_PORTS,\"elapsed\":$ELAPSED}"
