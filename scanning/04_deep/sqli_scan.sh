#!/bin/bash
# ============================================================
# FASE 4 — SQL Injection Detection (Detecção apenas, sem exploit)
# Ferramentas: sqlmap (--level 1, --risk 1, sem dump)
# Input:  output/active/endpoints.txt
# Output: output/deep/sqli_found.txt
# NOTA: sqlmap com --batch --level 1 --risk 1 apenas detecta,
#       não extrai dados. Exploit na fase de verificação por IA.
# ============================================================

source "$(dirname "$0")/../../config/common.sh"

TARGET="${1:-$TARGET_DOMAIN}"
OUT_DIR="$OUTPUT_DIR/deep"
ACTIVE_DIR="$OUTPUT_DIR/active"
mkdir -p "$OUT_DIR"

log "SQLi detection em: $TARGET"
warn "Modo detecção apenas (sem extração de dados)"
START_TIME=$(date +%s)

OUT_FILE="$OUT_DIR/sqli_found.txt"
SQLI_DIR="$OUT_DIR/sqlmap_output"
mkdir -p "$SQLI_DIR"
> "$OUT_FILE"

# Filtrar endpoints com parâmetros
ENDPOINTS=$(grep '?' "${ACTIVE_DIR}/endpoints.txt" 2>/dev/null | head -20)

for URL in $ENDPOINTS; do
    info "Testando: $URL"

    # sqlmap modo detecção: sem dump, sem os, sem técnicas destrutivas
    sqlmap -u "$URL" \
           --batch \
           --level 1 \
           --risk 1 \
           --technique=BEUST \
           --no-cast \
           --output-dir "$SQLI_DIR" \
           --forms \
           --smart \
           --quiet 2>/dev/null | \
           grep -iE "(injectable|parameter|vulnerable)" | \
           while read -r line; do
               echo "[SQLI] $URL => $line" >> "$OUT_FILE"
           done
done

FOUND=$(wc -l < "$OUT_FILE" 2>/dev/null || echo 0)
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

log "SQLi findings: $FOUND (em ${ELAPSED}s)"

echo "{\"phase\":\"deep\",\"step\":\"sqli_scan\",\"target\":\"$TARGET\",\"found\":$FOUND,\"file\":\"$OUT_FILE\",\"elapsed\":$ELAPSED}"
