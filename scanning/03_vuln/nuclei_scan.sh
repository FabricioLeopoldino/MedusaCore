#!/bin/bash
# ============================================================
# FASE 3 — Nuclei Vulnerability Scan
# Cobre: CVEs, misconfigs, exposures, takeovers, tech-detect
# Input:  output/active/urls_alive.txt
# Output: output/vuln/nuclei_results.json
# ============================================================

source "$(dirname "$0")/../../config/common.sh"

TARGET="${1:-$TARGET_DOMAIN}"
OUT_DIR="$OUTPUT_DIR/vuln"
ACTIVE_DIR="$OUTPUT_DIR/active"
mkdir -p "$OUT_DIR"

INPUT="${ACTIVE_DIR}/urls_alive.txt"
if [ ! -f "$INPUT" ]; then
    echo "https://$TARGET" > /tmp/medusa_nuclei_input.txt
    INPUT="/tmp/medusa_nuclei_input.txt"
fi

log "Iniciando Nuclei scan em: $TARGET"
START_TIME=$(date +%s)

# Atualizar templates
info "Atualizando templates Nuclei..."
nuclei -update-templates -silent 2>/dev/null

# --- Scan principal por severidade ---
info "Executando scan completo (critical/high/medium)..."
nuclei -l "$INPUT" \
       -severity critical,high,medium \
       -tags cve,exposed,misconfiguration,takeover,default-login,exposure \
       -rate-limit "$RATE_LIMIT" \
       -concurrency "$THREADS" \
       -timeout "$TIMEOUT" \
       -silent \
       -jsonl \
       -o "$OUT_DIR/nuclei_results.json" 2>/dev/null

# --- Scan de tecnologias ---
info "Detectando tecnologias..."
nuclei -l "$INPUT" \
       -tags tech \
       -silent \
       -jsonl \
       -o "$OUT_DIR/nuclei_tech.json" 2>/dev/null

# --- Scan de subdomain takeover ---
info "Verificando subdomain takeover..."
nuclei -l "$INPUT" \
       -tags takeover \
       -silent \
       -jsonl \
       -o "$OUT_DIR/nuclei_takeover.json" 2>/dev/null

# Contar findings
CRITICAL=$(grep -c '"severity":"critical"' "$OUT_DIR/nuclei_results.json" 2>/dev/null || echo 0)
HIGH=$(grep -c '"severity":"high"' "$OUT_DIR/nuclei_results.json" 2>/dev/null || echo 0)
MEDIUM=$(grep -c '"severity":"medium"' "$OUT_DIR/nuclei_results.json" 2>/dev/null || echo 0)
TOTAL=$((CRITICAL + HIGH + MEDIUM))

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

log "Nuclei findings: critical=$CRITICAL high=$HIGH medium=$MEDIUM total=$TOTAL (em ${ELAPSED}s)"

echo "{\"phase\":\"vuln\",\"step\":\"nuclei\",\"target\":\"$TARGET\",\"critical\":$CRITICAL,\"high\":$HIGH,\"medium\":$MEDIUM,\"total\":$TOTAL,\"file\":\"$OUT_DIR/nuclei_results.json\",\"elapsed\":$ELAPSED}"
