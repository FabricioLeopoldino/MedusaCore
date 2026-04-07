#!/bin/bash
# ============================================================
# FASE 1 — Resolução DNS e Filtragem de Ativos Vivos
# Ferramentas: dnsx
# Input:  output/recon/subdomains_raw.txt
# Output: output/recon/subdomains_alive.txt
# ============================================================

source "$(dirname "$0")/../../config/common.sh"

TARGET="${1:-$TARGET_DOMAIN}"
OUT_DIR="$OUTPUT_DIR/recon"
INPUT="$OUT_DIR/subdomains_raw.txt"

if [ ! -f "$INPUT" ]; then
    error "Arquivo não encontrado: $INPUT"
    error "Execute subdomain_enum.sh primeiro"
    exit 1
fi

log "Resolvendo DNS para subdomínios de: $TARGET"
START_TIME=$(date +%s)

# Resolver e manter apenas os que têm resposta DNS válida
dnsx -l "$INPUT" \
     -resp \
     -a -cname \
     -silent \
     -threads "$THREADS" \
     -o "$OUT_DIR/subdomains_alive.txt" 2>/dev/null

# Extrair só os nomes (sem IPs)
dnsx -l "$INPUT" -silent -threads "$THREADS" 2>/dev/null > "$OUT_DIR/subdomains_resolved.txt"

TOTAL=$(wc -l < "$OUT_DIR/subdomains_resolved.txt" 2>/dev/null || echo 0)
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

log "Subdomínios resolvidos: $TOTAL (em ${ELAPSED}s)"
log "Salvo em: $OUT_DIR/subdomains_resolved.txt"

echo "{\"phase\":\"recon\",\"step\":\"dns_resolve\",\"target\":\"$TARGET\",\"alive\":$TOTAL,\"file\":\"$OUT_DIR/subdomains_resolved.txt\",\"elapsed\":$ELAPSED}"
