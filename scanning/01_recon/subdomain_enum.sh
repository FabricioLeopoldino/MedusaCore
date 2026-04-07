#!/bin/bash
# ============================================================
# FASE 1 — Enumeração de Subdomínios
# Ferramentas: subfinder, assetfinder, waybackurls, gau
# Output: output/recon/subdomains.txt (deduplicado)
# ============================================================

source "$(dirname "$0")/../../config/common.sh"

TARGET="${1:-$TARGET_DOMAIN}"
OUT_DIR="$OUTPUT_DIR/recon"
mkdir -p "$OUT_DIR"

if [ -z "$TARGET" ]; then
    error "Uso: $0 <dominio>"
    exit 1
fi

log "Iniciando enumeração de subdomínios para: $TARGET"
START_TIME=$(date +%s)

TEMP=$(mktemp -d)

# --- subfinder ---
info "subfinder..."
subfinder -d "$TARGET" -silent -all -o "$TEMP/subfinder.txt" 2>/dev/null
COUNT=$(wc -l < "$TEMP/subfinder.txt" 2>/dev/null || echo 0)
log "subfinder: $COUNT resultados"

# --- assetfinder ---
info "assetfinder..."
assetfinder --subs-only "$TARGET" > "$TEMP/assetfinder.txt" 2>/dev/null
COUNT=$(wc -l < "$TEMP/assetfinder.txt" 2>/dev/null || echo 0)
log "assetfinder: $COUNT resultados"

# --- waybackurls (extrair subdomínios) ---
info "waybackurls..."
echo "$TARGET" | waybackurls 2>/dev/null | grep -oE '[a-zA-Z0-9._-]+\.'$TARGET | sort -u > "$TEMP/wayback.txt"
COUNT=$(wc -l < "$TEMP/wayback.txt" 2>/dev/null || echo 0)
log "waybackurls: $COUNT subdomínios extraídos"

# --- gau (extrair subdomínios) ---
info "gau..."
gau --subs "$TARGET" 2>/dev/null | grep -oE '[a-zA-Z0-9._-]+\.'$TARGET | sort -u > "$TEMP/gau.txt"
COUNT=$(wc -l < "$TEMP/gau.txt" 2>/dev/null || echo 0)
log "gau: $COUNT subdomínios extraídos"

# --- Consolidar e deduplicar ---
cat "$TEMP"/*.txt | sort -u | grep -v '^$' > "$OUT_DIR/subdomains_raw.txt"
TOTAL=$(wc -l < "$OUT_DIR/subdomains_raw.txt")

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

log "Total único de subdomínios: $TOTAL (em ${ELAPSED}s)"
log "Salvo em: $OUT_DIR/subdomains_raw.txt"

rm -rf "$TEMP"

# Output para n8n (JSON)
echo "{\"phase\":\"recon\",\"step\":\"subdomain_enum\",\"target\":\"$TARGET\",\"total\":$TOTAL,\"file\":\"$OUT_DIR/subdomains_raw.txt\",\"elapsed\":$ELAPSED}"
