#!/bin/bash
# ============================================================
# FASE 2 — Crawling e descoberta de endpoints
# Ferramentas: katana, waybackurls, gau
# Input:  output/active/urls_alive.txt
# Output: output/active/endpoints.txt
# ============================================================

source "$(dirname "$0")/../../config/common.sh"

TARGET="${1:-$TARGET_DOMAIN}"
OUT_DIR="$OUTPUT_DIR/active"
mkdir -p "$OUT_DIR"

INPUT="$OUT_DIR/urls_alive.txt"

if [ ! -f "$INPUT" ]; then
    echo "https://$TARGET" > "$INPUT"
fi

log "Crawling e descoberta de endpoints para: $TARGET"
START_TIME=$(date +%s)

TEMP=$(mktemp -d)

# --- katana: crawler moderno ---
info "katana crawling..."
katana -list "$INPUT" \
       -depth 3 \
       -js-crawl \
       -silent \
       -concurrency "$THREADS" \
       -timeout "$TIMEOUT" \
       -o "$TEMP/katana.txt" 2>/dev/null

# --- waybackurls ---
info "waybackurls..."
cat "$INPUT" | waybackurls 2>/dev/null > "$TEMP/wayback.txt"

# --- gau ---
info "gau..."
gau "$TARGET" --subs 2>/dev/null > "$TEMP/gau.txt"

# --- Consolidar ---
cat "$TEMP"/*.txt | sort -u | grep -v '^$' > "$OUT_DIR/endpoints_raw.txt"

# Filtrar extensões inúteis (imagens, fonts, etc.)
grep -vE '\.(png|jpg|jpeg|gif|svg|ico|woff|woff2|ttf|eot|css|mp4|mp3|pdf)(\?|$)' \
    "$OUT_DIR/endpoints_raw.txt" > "$OUT_DIR/endpoints.txt"

TOTAL=$(wc -l < "$OUT_DIR/endpoints.txt")
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

rm -rf "$TEMP"
log "Endpoints descobertos: $TOTAL (em ${ELAPSED}s)"

echo "{\"phase\":\"active\",\"step\":\"crawl\",\"target\":\"$TARGET\",\"endpoints\":$TOTAL,\"file\":\"$OUT_DIR/endpoints.txt\",\"elapsed\":$ELAPSED}"
