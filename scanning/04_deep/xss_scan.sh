#!/bin/bash
# ============================================================
# FASE 4 — XSS Detection
# Ferramentas: dalfox
# Input:  output/active/endpoints.txt (com parâmetros)
# Output: output/deep/xss_found.txt
# NOTA: Executar SOMENTE em alvos autorizados no bug bounty
# ============================================================

source "$(dirname "$0")/../../config/common.sh"

TARGET="${1:-$TARGET_DOMAIN}"
OUT_DIR="$OUTPUT_DIR/deep"
ACTIVE_DIR="$OUTPUT_DIR/active"
VULN_DIR="$OUTPUT_DIR/vuln"
mkdir -p "$OUT_DIR"

log "XSS scan em: $TARGET"
warn "Executando apenas em endpoints com parâmetros (GET)"
START_TIME=$(date +%s)

OUT_FILE="$OUT_DIR/xss_found.txt"
> "$OUT_FILE"

# Filtrar endpoints com parâmetros
ENDPOINTS_WITH_PARAMS="$OUT_DIR/endpoints_with_params.txt"
grep '?' "${ACTIVE_DIR}/endpoints.txt" 2>/dev/null | head -50 > "$ENDPOINTS_WITH_PARAMS"

TOTAL_URLS=$(wc -l < "$ENDPOINTS_WITH_PARAMS" 2>/dev/null || echo 0)
log "Endpoints com parâmetros para testar: $TOTAL_URLS"

if [ "$TOTAL_URLS" -gt 0 ]; then
    # dalfox pipe mode
    info "dalfox XSS scan..."
    cat "$ENDPOINTS_WITH_PARAMS" | dalfox pipe \
        --silence \
        --no-color \
        --timeout "$TIMEOUT" \
        --delay 100 \
        --output "$OUT_FILE" 2>/dev/null
fi

FOUND=$(wc -l < "$OUT_FILE" 2>/dev/null || echo 0)
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

log "XSS findings: $FOUND (em ${ELAPSED}s)"

echo "{\"phase\":\"deep\",\"step\":\"xss_scan\",\"target\":\"$TARGET\",\"tested\":$TOTAL_URLS,\"found\":$FOUND,\"file\":\"$OUT_FILE\",\"elapsed\":$ELAPSED}"
