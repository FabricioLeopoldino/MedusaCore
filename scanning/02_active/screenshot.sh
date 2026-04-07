#!/bin/bash
# ============================================================
# FASE 2 — Screenshots das aplicações web vivas
# Ferramentas: gowitness
# Input:  output/active/urls_alive.txt
# Output: output/active/screenshots/
# ============================================================

source "$(dirname "$0")/../../config/common.sh"

TARGET="${1:-$TARGET_DOMAIN}"
OUT_DIR="$OUTPUT_DIR/active"
SHOT_DIR="$OUT_DIR/screenshots"
mkdir -p "$SHOT_DIR"

INPUT="$OUT_DIR/urls_alive.txt"

if [ ! -f "$INPUT" ]; then
    error "Execute http_probe.sh primeiro"
    exit 1
fi

log "Capturando screenshots das aplicações web..."
START_TIME=$(date +%s)

gowitness file \
    -f "$INPUT" \
    --screenshot-path "$SHOT_DIR" \
    --no-db \
    --threads "$THREADS" \
    --timeout "$TIMEOUT" 2>/dev/null

SHOTS=$(ls "$SHOT_DIR"/*.png 2>/dev/null | wc -l)

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

log "Screenshots capturados: $SHOTS (em ${ELAPSED}s)"
log "Salvos em: $SHOT_DIR"

echo "{\"phase\":\"active\",\"step\":\"screenshot\",\"target\":\"$TARGET\",\"screenshots\":$SHOTS,\"dir\":\"$SHOT_DIR\",\"elapsed\":$ELAPSED}"
