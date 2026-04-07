#!/bin/bash
# ============================================================
# FASE 3 — Directory & Path Bruteforce
# Ferramentas: ffuf
# Input:  output/active/urls_alive.txt
# Output: output/vuln/dirs_found.txt
# ============================================================

source "$(dirname "$0")/../../config/common.sh"

TARGET="${1:-$TARGET_DOMAIN}"
OUT_DIR="$OUTPUT_DIR/vuln"
ACTIVE_DIR="$OUTPUT_DIR/active"
mkdir -p "$OUT_DIR"

# Wordlist
WORDLIST="${WORDLISTS_DIR:-/opt/medusa/wordlists}/SecLists/Discovery/Web-Content/raft-medium-directories.txt"
if [ ! -f "$WORDLIST" ]; then
    WORDLIST="/usr/share/wordlists/dirb/common.txt"
fi

if [ ! -f "$WORDLIST" ]; then
    error "Wordlist não encontrada. Execute setup/install.sh primeiro."
    exit 1
fi

log "Directory bruteforce em: $TARGET"
START_TIME=$(date +%s)

URLS=("https://$TARGET")
if [ -f "$ACTIVE_DIR/urls_alive.txt" ]; then
    mapfile -t URLS < <(head -10 "$ACTIVE_DIR/urls_alive.txt")
fi

ALL_FOUND="$OUT_DIR/dirs_found.txt"
> "$ALL_FOUND"

for URL in "${URLS[@]}"; do
    SAFE_NAME=$(echo "$URL" | sed 's|https\?://||;s|/|_|g')
    OUT_FILE="$OUT_DIR/ffuf_${SAFE_NAME}.json"

    info "ffuf em: $URL"
    ffuf -u "${URL}/FUZZ" \
         -w "$WORDLIST" \
         -t "$THREADS" \
         -timeout "$TIMEOUT" \
         -rate "$RATE_LIMIT" \
         -fc 404,403 \
         -mc 200,201,204,301,302,307,401 \
         -silent \
         -json \
         -o "$OUT_FILE" 2>/dev/null

    # Extrair resultados para arquivo consolidado
    if [ -f "$OUT_FILE" ]; then
        jq -r '.results[]? | "\(.status) \(.url)"' "$OUT_FILE" 2>/dev/null >> "$ALL_FOUND"
    fi
done

FOUND=$(wc -l < "$ALL_FOUND" 2>/dev/null || echo 0)
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

log "Diretórios/paths encontrados: $FOUND (em ${ELAPSED}s)"

echo "{\"phase\":\"vuln\",\"step\":\"dir_bruteforce\",\"target\":\"$TARGET\",\"found\":$FOUND,\"file\":\"$ALL_FOUND\",\"elapsed\":$ELAPSED}"
