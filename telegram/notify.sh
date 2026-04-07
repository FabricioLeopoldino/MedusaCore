#!/bin/bash
# ============================================================
# MEDUSA — Notificações Telegram
# Envia relatórios e alertas direto para o seu Telegram
# ============================================================

source "$(dirname "$0")/../config/common.sh"

BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
CHAT_ID="${TELEGRAM_CHAT_ID}"

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    error "Configure TELEGRAM_BOT_TOKEN e TELEGRAM_CHAT_ID no .env"
    exit 1
fi

API_URL="https://api.telegram.org/bot${BOT_TOKEN}"

# ============================================================
# FUNÇÕES
# ============================================================

send_message() {
    local TEXT="$1"
    local PARSE_MODE="${2:-Markdown}"

    curl -s -X POST "${API_URL}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "parse_mode=${PARSE_MODE}" \
        --data-urlencode "text=${TEXT}" \
        -o /dev/null 2>/dev/null
}

send_file() {
    local FILE_PATH="$1"
    local CAPTION="${2:-}"

    if [ ! -f "$FILE_PATH" ]; then
        error "Arquivo não encontrado: $FILE_PATH"
        return 1
    fi

    curl -s -X POST "${API_URL}/sendDocument" \
        -F "chat_id=${CHAT_ID}" \
        -F "document=@${FILE_PATH}" \
        -F "caption=${CAPTION}" \
        -o /dev/null 2>/dev/null
}

send_photo() {
    local PHOTO_PATH="$1"
    local CAPTION="${2:-}"

    curl -s -X POST "${API_URL}/sendPhoto" \
        -F "chat_id=${CHAT_ID}" \
        -F "photo=@${PHOTO_PATH}" \
        -F "caption=${CAPTION}" \
        -o /dev/null 2>/dev/null
}

# ============================================================
# TEMPLATES DE MENSAGEM
# ============================================================

notify_scan_start() {
    local TARGET="$1"
    local MESSAGE="🐍 *MEDUSA — Scan Iniciado*

🎯 Alvo: \`${TARGET}\`
🕐 Início: $(date '+%d/%m/%Y %H:%M')
📊 Fases: Recon → Active → Vuln → Deep → AI → Report

_Aguarde o relatório final..._"

    send_message "$MESSAGE"
    log "Notificação de início enviada"
}

notify_phase_complete() {
    local PHASE="$1"
    local FINDINGS="$2"
    local TARGET="$3"

    local EMOJI="✅"
    case "$PHASE" in
        "recon")   EMOJI="🔍" ;;
        "active")  EMOJI="🌐" ;;
        "vuln")    EMOJI="⚠️" ;;
        "deep")    EMOJI="🔬" ;;
        "ai")      EMOJI="🤖" ;;
        "report")  EMOJI="📋" ;;
    esac

    local MESSAGE="${EMOJI} *Fase concluída: ${PHASE}*
🎯 Alvo: \`${TARGET}\`
📊 Findings: ${FINDINGS}
🕐 $(date '+%H:%M')"

    send_message "$MESSAGE"
}

notify_critical_finding() {
    local TARGET="$1"
    local VULN_TITLE="$2"
    local VULN_URL="$3"
    local SEVERITY="$4"

    local EMOJI="🚨"
    [ "$SEVERITY" = "high" ] && EMOJI="🔴"
    [ "$SEVERITY" = "medium" ] && EMOJI="🟡"

    local MESSAGE="${EMOJI} *VULNERABILIDADE ENCONTRADA*

🎯 Alvo: \`${TARGET}\`
💀 Severidade: *${SEVERITY^^}*
🔎 Título: ${VULN_TITLE}
🌐 URL: \`${VULN_URL}\`
🕐 $(date '+%d/%m/%Y %H:%M')

_Verifique o relatório completo_"

    send_message "$MESSAGE"
}

notify_report_ready() {
    local TARGET="$1"
    local REPORT_FILE="$2"
    local CRITICAL="$3"
    local HIGH="$4"
    local MEDIUM="$5"

    local MESSAGE="📋 *MEDUSA — Relatório Final Pronto*

🎯 Alvo: \`${TARGET}\`
🚨 Critical: ${CRITICAL}
🔴 High: ${HIGH}
🟡 Medium: ${MEDIUM}
🕐 $(date '+%d/%m/%Y %H:%M')

_Enviando arquivo de relatório..._"

    send_message "$MESSAGE"

    if [ -f "$REPORT_FILE" ]; then
        send_file "$REPORT_FILE" "Relatório completo — ${TARGET}"
    fi
}

notify_scan_complete() {
    local TARGET="$1"
    local TOTAL_TIME="$2"

    local MESSAGE="✅ *MEDUSA — Scan Concluído*

🎯 Alvo: \`${TARGET}\`
⏱️ Tempo total: ${TOTAL_TIME}
🕐 Fim: $(date '+%d/%m/%Y %H:%M')

_Todos os arquivos salvos em output/_"

    send_message "$MESSAGE"
}

notify_error() {
    local PHASE="$1"
    local ERROR_MSG="$2"

    local MESSAGE="❌ *MEDUSA — Erro*

⚠️ Fase: ${PHASE}
💬 Erro: ${ERROR_MSG}
🕐 $(date '+%H:%M')"

    send_message "$MESSAGE"
}

# ============================================================
# EXECUÇÃO DIRETA
# ============================================================

# Uso: ./notify.sh <comando> [args...]
COMMAND="${1:-test}"

case "$COMMAND" in
    "test")
        send_message "🐍 *MEDUSA* — Conexão Telegram OK! Bot configurado corretamente."
        log "Mensagem de teste enviada"
        ;;
    "start")
        notify_scan_start "$2"
        ;;
    "phase")
        notify_phase_complete "$2" "$3" "$4"
        ;;
    "critical")
        notify_critical_finding "$2" "$3" "$4" "$5"
        ;;
    "report")
        notify_report_ready "$2" "$3" "$4" "$5" "$6"
        ;;
    "done")
        notify_scan_complete "$2" "$3"
        ;;
    "error")
        notify_error "$2" "$3"
        ;;
    *)
        error "Comando inválido. Use: test|start|phase|critical|report|done|error"
        exit 1
        ;;
esac
