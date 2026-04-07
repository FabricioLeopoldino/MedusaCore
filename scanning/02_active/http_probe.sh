#!/bin/bash
# ============================================================
# FASE 2 — HTTP Probe (quais subdomínios respondem HTTP/S)
# Ferramentas: httpx
# Input:  output/recon/subdomains_resolved.txt
# Output: output/active/http_alive.txt (com metadados)
# ============================================================

source "$(dirname "$0")/../../config/common.sh"

TARGET="${1:-$TARGET_DOMAIN}"
OUT_DIR="$OUTPUT_DIR/active"
RECON_DIR="$OUTPUT_DIR/recon"
mkdir -p "$OUT_DIR"

INPUT="${RECON_DIR}/subdomains_resolved.txt"

if [ ! -f "$INPUT" ]; then
    # Fallback: testar o domínio principal
    echo "$TARGET" > /tmp/medusa_probe_input.txt
    INPUT="/tmp/medusa_probe_input.txt"
fi

log "HTTP probe em subdomínios de: $TARGET"
START_TIME=$(date +%s)

httpx -l "$INPUT" \
      -title \
      -status-code \
      -tech-detect \
      -content-length \
      -follow-redirects \
      -threads "$THREADS" \
      -timeout "$TIMEOUT" \
      -silent \
      -json \
      -o "$OUT_DIR/http_alive.json" 2>/dev/null

# Versão texto simples para leitura rápida
httpx -l "$INPUT" \
      -title \
      -status-code \
      -silent \
      -threads "$THREADS" \
      -timeout "$TIMEOUT" \
      -o "$OUT_DIR/http_alive.txt" 2>/dev/null

ALIVE=$(wc -l < "$OUT_DIR/http_alive.txt" 2>/dev/null || echo 0)

# Extrair só as URLs para próximas fases
jq -r '.url' "$OUT_DIR/http_alive.json" 2>/dev/null | sort -u > "$OUT_DIR/urls_alive.txt"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

log "Hosts HTTP ativos: $ALIVE (em ${ELAPSED}s)"
log "URLs salvas em: $OUT_DIR/urls_alive.txt"

echo "{\"phase\":\"active\",\"step\":\"http_probe\",\"target\":\"$TARGET\",\"alive\":$ALIVE,\"file\":\"$OUT_DIR/urls_alive.txt\",\"elapsed\":$ELAPSED}"
