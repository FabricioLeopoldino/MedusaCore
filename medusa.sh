#!/bin/bash
# ============================================================
# MEDUSA — Pipeline Principal
# Executa todas as fases em sequência para um alvo
# Uso: ./medusa.sh <dominio>
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/common.sh"

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
    error "Uso: $0 <dominio>"
    error "Exemplo: $0 exemplo.com"
    exit 1
fi

TOTAL_START=$(date +%s)

echo ""
echo -e "${RED}"
cat << 'EOF'
  __  __ _____ ____  _   _ ____    _
 |  \/  | ____|  _ \| | | / ___|  / \
 | |\/| |  _| | | | | | | \___ \ / _ \
 | |  | | |___| |_| | |_| |___) / ___ \
 |_|  |_|_____|____/ \___/|____/_/   \_\
EOF
echo -e "${NC}"
log "Alvo: $TARGET"
log "Início: $(date '+%d/%m/%Y %H:%M:%S')"
echo ""

# Notificar início
bash "$SCRIPT_DIR/telegram/notify.sh" start "$TARGET" 2>/dev/null || true

run_phase() {
    local PHASE_NAME="$1"
    local SCRIPT="$2"
    shift 2
    local ARGS=("$@")

    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "FASE: $PHASE_NAME"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local RESULT
    RESULT=$(bash "$SCRIPT_DIR/$SCRIPT" "$TARGET" "${ARGS[@]:-}" 2>&1) || true
    echo "$RESULT"

    local FINDINGS=$(echo "$RESULT" | grep -oE '"total":[0-9]+|"found":[0-9]+|"alive":[0-9]+' | head -1 | grep -oE '[0-9]+' || echo "?")
    bash "$SCRIPT_DIR/telegram/notify.sh" phase "$PHASE_NAME" "$FINDINGS" "$TARGET" 2>/dev/null || true
    echo ""
}

# ============================================================
# FASE 1 — RECONHECIMENTO
# ============================================================
run_phase "Reconhecimento — Subdomínios"  "scanning/01_recon/subdomain_enum.sh"
run_phase "Reconhecimento — DNS"          "scanning/01_recon/dns_resolve.sh"
run_phase "Reconhecimento — WHOIS/ASN"   "scanning/01_recon/whois_asn.sh"

# ============================================================
# FASE 2 — SCANNING ATIVO
# ============================================================
run_phase "Active — HTTP Probe"    "scanning/02_active/http_probe.sh"
run_phase "Active — Port Scan"     "scanning/02_active/port_scan.sh"
run_phase "Active — Crawling"      "scanning/02_active/crawl.sh"
run_phase "Active — Screenshots"   "scanning/02_active/screenshot.sh"

# ============================================================
# FASE 3 — VULNERABILIDADES
# ============================================================
run_phase "Vuln — Nuclei"          "scanning/03_vuln/nuclei_scan.sh"
run_phase "Vuln — SSL/Headers"     "scanning/03_vuln/ssl_headers_check.sh"
run_phase "Vuln — Dir Bruteforce"  "scanning/03_vuln/dir_bruteforce.sh"
run_phase "Vuln — Parâmetros"      "scanning/03_vuln/param_discovery.sh"

# ============================================================
# FASE 4 — ANÁLISE PROFUNDA
# ============================================================
run_phase "Deep — Secrets/JS"  "scanning/04_deep/secret_scan.sh"
run_phase "Deep — XSS"         "scanning/04_deep/xss_scan.sh"
run_phase "Deep — SQLi"        "scanning/04_deep/sqli_scan.sh"

# ============================================================
# FASE 5 — ANÁLISE POR IA
# ============================================================
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "FASE: IA — Análise de Vulnerabilidades (Fase 1)"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
python3 "$SCRIPT_DIR/ai/scripts/analyze.py" "$TARGET" || warn "Erro na análise IA Fase 1"
bash "$SCRIPT_DIR/telegram/notify.sh" phase "AI-Análise" "?" "$TARGET" 2>/dev/null || true
echo ""

log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "FASE: IA — Verificação Legal (Fase 2)"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
python3 "$SCRIPT_DIR/ai/scripts/verify.py" "$TARGET" || warn "Erro na verificação IA Fase 2"
bash "$SCRIPT_DIR/telegram/notify.sh" phase "AI-Verificação" "?" "$TARGET" 2>/dev/null || true
echo ""

# ============================================================
# RELATÓRIO FINAL
# ============================================================
REPORT_FILE="$SCRIPT_DIR/output/reports/phase1_analysis.json"
CRITICAL=$(grep -c '"severity":"critical"' "$REPORT_FILE" 2>/dev/null || echo 0)
HIGH=$(grep -c '"severity":"high"' "$REPORT_FILE" 2>/dev/null || echo 0)
MEDIUM=$(grep -c '"severity":"medium"' "$REPORT_FILE" 2>/dev/null || echo 0)

TOTAL_END=$(date +%s)
ELAPSED=$(( (TOTAL_END - TOTAL_START) / 60 ))m$(( (TOTAL_END - TOTAL_START) % 60 ))s

bash "$SCRIPT_DIR/telegram/notify.sh" report "$TARGET" "$REPORT_FILE" "$CRITICAL" "$HIGH" "$MEDIUM" 2>/dev/null || true
bash "$SCRIPT_DIR/telegram/notify.sh" done "$TARGET" "$ELAPSED" 2>/dev/null || true

echo ""
log "════════════════════════════════════"
log "MEDUSA CONCLUÍDO"
log "Alvo:     $TARGET"
log "Tempo:    $ELAPSED"
log "Critical: $CRITICAL | High: $HIGH | Medium: $MEDIUM"
log "Output:   $SCRIPT_DIR/output/"
log "════════════════════════════════════"
