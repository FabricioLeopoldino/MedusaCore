#!/bin/bash
# ============================================================
# FASE 4 — Secret Scanning (JS, endpoints, respostas)
# Ferramentas: gitleaks, custom regex
# Input:  output/active/endpoints.txt
# Output: output/deep/secrets_found.json
# ============================================================

source "$(dirname "$0")/../../config/common.sh"

TARGET="${1:-$TARGET_DOMAIN}"
OUT_DIR="$OUTPUT_DIR/deep"
ACTIVE_DIR="$OUTPUT_DIR/active"
mkdir -p "$OUT_DIR/js_files"

log "Secret scanning em: $TARGET"
START_TIME=$(date +%s)

ENDPOINTS="${ACTIVE_DIR}/endpoints.txt"
SECRETS_OUT="$OUT_DIR/secrets_found.txt"
> "$SECRETS_OUT"

# --- Baixar arquivos JS e analisar ---
info "Baixando e analisando arquivos JavaScript..."
JS_URLS=$(grep -iE '\.js(\?|$)' "${ENDPOINTS:-/dev/null}" 2>/dev/null | head -100)

JS_COUNT=0
for JS_URL in $JS_URLS; do
    FILENAME=$(echo "$JS_URL" | md5sum | cut -d' ' -f1)
    curl -s --max-time "$TIMEOUT" -L "$JS_URL" -o "$OUT_DIR/js_files/${FILENAME}.js" 2>/dev/null
    ((JS_COUNT++))
done

log "Arquivos JS baixados: $JS_COUNT"

# --- gitleaks nos arquivos JS ---
if [ "$JS_COUNT" -gt 0 ]; then
    info "gitleaks analisando JS files..."
    gitleaks detect \
        --source "$OUT_DIR/js_files" \
        --no-git \
        --report-format json \
        --report-path "$OUT_DIR/gitleaks_js.json" \
        --redact \
        --quiet 2>/dev/null

    if [ -f "$OUT_DIR/gitleaks_js.json" ]; then
        LEAKS=$(jq length "$OUT_DIR/gitleaks_js.json" 2>/dev/null || echo 0)
        log "gitleaks findings em JS: $LEAKS"
        jq -r '.[] | "[LEAK] \(.RuleID) — \(.File) — \(.Secret)"' \
            "$OUT_DIR/gitleaks_js.json" 2>/dev/null >> "$SECRETS_OUT"
    fi
fi

# --- Regex custom para secrets comuns ---
info "Buscando secrets com regex..."
PATTERNS=(
    "api[_-]?key\s*[=:]\s*['\"][A-Za-z0-9_\-]{20,}"
    "secret[_-]?key\s*[=:]\s*['\"][A-Za-z0-9_\-]{20,}"
    "access[_-]?token\s*[=:]\s*['\"][A-Za-z0-9_\-]{20,}"
    "password\s*[=:]\s*['\"][^'\"]{8,}"
    "aws_access_key_id\s*[=:]\s*['\"]?AKIA[0-9A-Z]{16}"
    "private[_-]?key"
    "AKIA[0-9A-Z]{16}"
    "ghp_[A-Za-z0-9]{36}"
    "glpat-[A-Za-z0-9\-]{20}"
)

for PATTERN in "${PATTERNS[@]}"; do
    grep -rEi "$PATTERN" "$OUT_DIR/js_files/" 2>/dev/null | \
        sed 's/.*://;s/['"'"'"]//' | \
        while read -r line; do
            echo "[REGEX] $PATTERN => $line" >> "$SECRETS_OUT"
        done
done

TOTAL=$(wc -l < "$SECRETS_OUT" 2>/dev/null || echo 0)
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

log "Secrets/leaks encontrados: $TOTAL (em ${ELAPSED}s)"

echo "{\"phase\":\"deep\",\"step\":\"secret_scan\",\"target\":\"$TARGET\",\"js_files\":$JS_COUNT,\"secrets\":$TOTAL,\"file\":\"$SECRETS_OUT\",\"elapsed\":$ELAPSED}"
