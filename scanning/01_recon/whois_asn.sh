#!/bin/bash
# ============================================================
# FASE 1 — WHOIS e ASN
# Coleta informações de registrant, ASN, IP ranges
# Output: output/recon/whois.txt, output/recon/asn.txt
# ============================================================

source "$(dirname "$0")/../../config/common.sh"

TARGET="${1:-$TARGET_DOMAIN}"
OUT_DIR="$OUTPUT_DIR/recon"
mkdir -p "$OUT_DIR"

log "Coletando WHOIS e ASN para: $TARGET"

# --- WHOIS ---
info "Executando whois..."
whois "$TARGET" > "$OUT_DIR/whois.txt" 2>/dev/null
log "WHOIS salvo em: $OUT_DIR/whois.txt"

# Extrair campos relevantes do WHOIS
grep -iE "registrant|organization|email|name server|updated|created|expir" \
    "$OUT_DIR/whois.txt" > "$OUT_DIR/whois_summary.txt" 2>/dev/null

# --- IPs resolvidos ---
info "Resolvendo IPs principais..."
dig +short "$TARGET" A > "$OUT_DIR/ips_main.txt" 2>/dev/null
dig +short "www.$TARGET" A >> "$OUT_DIR/ips_main.txt" 2>/dev/null
sort -u "$OUT_DIR/ips_main.txt" -o "$OUT_DIR/ips_main.txt"

# --- ASN via API pública ---
info "Consultando ASN..."
MAIN_IP=$(head -1 "$OUT_DIR/ips_main.txt")
if [ -n "$MAIN_IP" ]; then
    curl -s "https://ipinfo.io/$MAIN_IP/json" > "$OUT_DIR/asn.txt" 2>/dev/null
    log "ASN info salva em: $OUT_DIR/asn.txt"
fi

# --- MX / SPF / DMARC ---
info "Consultando registros de email (MX/SPF/DMARC)..."
{
    echo "=== MX ==="
    dig +short "$TARGET" MX 2>/dev/null
    echo ""
    echo "=== SPF ==="
    dig +short "$TARGET" TXT 2>/dev/null | grep -i spf
    echo ""
    echo "=== DMARC ==="
    dig +short "_dmarc.$TARGET" TXT 2>/dev/null
} > "$OUT_DIR/email_records.txt"

log "Registros de email salvos em: $OUT_DIR/email_records.txt"

echo "{\"phase\":\"recon\",\"step\":\"whois_asn\",\"target\":\"$TARGET\",\"main_ip\":\"$MAIN_IP\",\"files\":[\"whois.txt\",\"asn.txt\",\"email_records.txt\"]}"
