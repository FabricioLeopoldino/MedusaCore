#!/bin/bash
# ============================================================
# FASE 3 — Parameter Discovery
# Ferramentas: arjun
# Input:  output/active/urls_alive.txt
# Output: output/vuln/params_found.json
# ============================================================

source "$(dirname "$0")/../../config/common.sh"

TARGET="${1:-$TARGET_DOMAIN}"
OUT_DIR="$OUTPUT_DIR/vuln"
ACTIVE_DIR="$OUTPUT_DIR/active"
mkdir -p "$OUT_DIR"

log "Descoberta de parâmetros em: $TARGET"
START_TIME=$(date +%s)

URLS=("https://$TARGET")
if [ -f "$ACTIVE_DIR/urls_alive.txt" ]; then
    mapfile -t URLS < <(head -15 "$ACTIVE_DIR/urls_alive.txt")
fi

ALL_PARAMS="$OUT_DIR/params_found.json"
echo "[]" > "$ALL_PARAMS"

for URL in "${URL[@]}"; do
    info "arjun em: $URL"
    RESULT=$(arjun -u "$URL" \
                   --stable \
                   -t "$THREADS" \
                   --json 2>/dev/null)

    if [ -n "$RESULT" ]; then
        echo "$RESULT" >> "$OUT_DIR/params_raw.txt"
    fi
done

FOUND=$(grep -c '"params"' "$OUT_DIR/params_raw.txt" 2>/dev/null || echo 0)
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

log "Endpoints com parâmetros descobertos: $FOUND (em ${ELAPSED}s)"

echo "{\"phase\":\"vuln\",\"step\":\"param_discovery\",\"target\":\"$TARGET\",\"found\":$FOUND,\"elapsed\":$ELAPSED}"
