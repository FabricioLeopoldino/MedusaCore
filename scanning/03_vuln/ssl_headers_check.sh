#!/bin/bash
# ============================================================
# FASE 3 — SSL/TLS e Security Headers
# Ferramentas: testssl.sh, curl (headers)
# Output: output/vuln/ssl_results.txt, headers_results.txt
# ============================================================

source "$(dirname "$0")/../../config/common.sh"

TARGET="${1:-$TARGET_DOMAIN}"
OUT_DIR="$OUTPUT_DIR/vuln"
ACTIVE_DIR="$OUTPUT_DIR/active"
mkdir -p "$OUT_DIR"

log "Verificando SSL/TLS e Security Headers para: $TARGET"
START_TIME=$(date +%s)

# --- testssl.sh ---
info "testssl.sh scan..."
if command -v testssl.sh &>/dev/null; then
    testssl.sh --quiet \
               --color 0 \
               --jsonfile "$OUT_DIR/ssl_results.json" \
               --severity MEDIUM \
               "https://$TARGET" 2>/dev/null
    log "SSL results: $OUT_DIR/ssl_results.json"
fi

# --- Security Headers ---
info "Verificando Security Headers..."
{
    echo "=== Security Headers Analysis ==="
    echo "Target: $TARGET"
    echo "Date: $(date)"
    echo ""

    URLS=("https://$TARGET")
    if [ -f "$ACTIVE_DIR/urls_alive.txt" ]; then
        # Pegar as primeiras 20 URLs
        mapfile -t URLS < <(head -20 "$ACTIVE_DIR/urls_alive.txt")
    fi

    for URL in "${URLS[@]}"; do
        echo "--- $URL ---"
        HEADERS=$(curl -s -I --max-time "$TIMEOUT" -L "$URL" 2>/dev/null)

        check_header() {
            local HEADER="$1"
            local VALUE=$(echo "$HEADERS" | grep -i "^$HEADER:" | head -1)
            if [ -n "$VALUE" ]; then
                echo "  [OK] $VALUE"
            else
                echo "  [MISSING] $HEADER"
            fi
        }

        check_header "Strict-Transport-Security"
        check_header "Content-Security-Policy"
        check_header "X-Frame-Options"
        check_header "X-Content-Type-Options"
        check_header "Referrer-Policy"
        check_header "Permissions-Policy"
        check_header "X-XSS-Protection"

        # Verificar headers que NÃO deveriam estar expostos
        SERVER=$(echo "$HEADERS" | grep -i "^Server:" | head -1)
        XPOWERED=$(echo "$HEADERS" | grep -i "^X-Powered-By:" | head -1)
        [ -n "$SERVER" ]   && echo "  [INFO] $SERVER"
        [ -n "$XPOWERED" ] && echo "  [WARN] $XPOWERED (exposed tech stack)"

        echo ""
    done
} > "$OUT_DIR/headers_results.txt"

# --- CORS check básico ---
info "Verificando CORS misconfigurations..."
{
    echo "=== CORS Analysis ==="
    for URL in "${URLS[@]:0:10}"; do
        CORS=$(curl -s -I --max-time "$TIMEOUT" \
               -H "Origin: https://evil.com" \
               -H "Access-Control-Request-Method: GET" \
               "$URL" 2>/dev/null | grep -i "Access-Control")

        if echo "$CORS" | grep -qi "evil.com"; then
            echo "[VULNERABLE] $URL — CORS allows evil.com"
            echo "$CORS"
        elif [ -n "$CORS" ]; then
            echo "[INFO] $URL — $CORS"
        fi
    done
} > "$OUT_DIR/cors_results.txt"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

MISSING_HEADERS=$(grep -c "\[MISSING\]" "$OUT_DIR/headers_results.txt" 2>/dev/null || echo 0)
CORS_VULN=$(grep -c "\[VULNERABLE\]" "$OUT_DIR/cors_results.txt" 2>/dev/null || echo 0)

log "Headers faltando: $MISSING_HEADERS | CORS vulneráveis: $CORS_VULN (em ${ELAPSED}s)"

echo "{\"phase\":\"vuln\",\"step\":\"ssl_headers\",\"target\":\"$TARGET\",\"missing_headers\":$MISSING_HEADERS,\"cors_vulnerable\":$CORS_VULN,\"elapsed\":$ELAPSED}"
