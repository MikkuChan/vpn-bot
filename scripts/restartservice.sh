#!/bin/bash

# =============================================================================
# RESTART SERVICE BOT INTEGRATION SCRIPT
# =============================================================================
# Script untuk restart semua service dengan integrasi Telegram Bot
# Dibuat dengan function-based approach untuk kemudahan integrasi
# Author: fadzdigital
# Version: 2.0
# =============================================================================

# Konfigurasi warna output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0;37m'

# =============================================================================
# GLOBAL VARIABLES - Menyimpan hasil operasi untuk akses eksternal
# =============================================================================
RESTART_STATUS=""           # Status keseluruhan operasi (SUCCESS/FAILED)
RESTART_MESSAGE=""          # Pesan detail untuk Telegram
RESTART_LOG=""             # Log detail semua operasi
FAILED_SERVICES=""         # Daftar service yang gagal restart

# =============================================================================
# FUNCTION: Restart Single Service
# Fungsi untuk restart service tunggal dengan error handling
# =============================================================================
restart_single_service() {
    local service_name="$1"
    local restart_command="$2"
    local service_display_name="${3:-$service_name}"
    
    echo -e "🔄 Restarting ${service_display_name}..."
    
    if eval "$restart_command" &>/dev/null; then
        echo -e "✅ ${service_display_name} berhasil direstart"
        RESTART_LOG="${RESTART_LOG}✅ ${service_display_name}: SUCCESS\n"
        return 0
    else
        echo -e "❌ ${service_display_name} gagal direstart"
        RESTART_LOG="${RESTART_LOG}❌ ${service_display_name}: FAILED\n"
        FAILED_SERVICES="${FAILED_SERVICES}${service_display_name}, "
        return 1
    fi
}

# =============================================================================
# FUNCTION: Core Restart All Services
# Fungsi utama untuk restart semua service sistem
# =============================================================================
core_restart_all_services() {
    local email="$1"
    local failed_count=0
    local total_services=0
    
    # Reset global variables
    RESTART_STATUS=""
    RESTART_MESSAGE=""
    RESTART_LOG=""
    FAILED_SERVICES=""
    
    echo -e "${GREEN}🚀 Starting Restart All Services${NC}"
    echo -e "📧 User: ${email:-'Manual'}"
    echo -e "⏰ Waktu: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "============================================"
    
    # Daftar semua service yang akan direstart
    declare -A services=(
        ["ws"]="systemctl restart ws"
        ["haproxy"]="systemctl restart haproxy"
        ["xray"]="systemctl restart xray"
        ["openvpn-systemd"]="systemctl restart openvpn"
        ["ssh-systemd"]="systemctl restart ssh"
        ["ssh-init"]="/etc/init.d/ssh restart"
        ["dropbear"]="/etc/init.d/dropbear restart"
        ["openvpn-init"]="/etc/init.d/openvpn restart"
        ["fail2ban"]="/etc/init.d/fail2ban restart"
        ["nginx"]="/etc/init.d/nginx restart"
    )
    
    # Restart service reguler
    for service in "${!services[@]}"; do
        total_services=$((total_services + 1))
        if ! restart_single_service "$service" "${services[$service]}"; then
            failed_count=$((failed_count + 1))
        fi
        sleep 0.5
    done
    
    # Restart UDP Mini services dengan disable/enable cycle
    echo -e "\n🔄 Managing UDP Mini Services..."
    for i in {1..3}; do
        total_services=$((total_services + 1))
        service_name="udp-mini-$i"
        
        echo -e "🔄 Processing ${service_name}..."
        
        # Disable, stop, enable, start sequence
        if systemctl disable "$service_name" &>/dev/null && \
           systemctl stop "$service_name" &>/dev/null && \
           systemctl enable "$service_name" &>/dev/null && \
           systemctl start "$service_name" &>/dev/null; then
            echo -e "✅ ${service_name} berhasil direstart dengan cycle"
            RESTART_LOG="${RESTART_LOG}✅ ${service_name}: SUCCESS (with cycle)\n"
        else
            echo -e "❌ ${service_name} gagal direstart"
            RESTART_LOG="${RESTART_LOG}❌ ${service_name}: FAILED\n"
            FAILED_SERVICES="${FAILED_SERVICES}${service_name}, "
            failed_count=$((failed_count + 1))
        fi
        sleep 0.5
    done
    
    # Tentukan status keseluruhan
    if [ "$failed_count" -eq 0 ]; then
        RESTART_STATUS="SUCCESS"
        RESTART_MESSAGE="🎉 *RESTART SERVICE BERHASIL*\n\n"
        RESTART_MESSAGE="${RESTART_MESSAGE}📊 *Status:* Semua service berhasil direstart\n"
        RESTART_MESSAGE="${RESTART_MESSAGE}📧 *User:* ${email:-'Manual'}\n"
        RESTART_MESSAGE="${RESTART_MESSAGE}⏰ *Waktu:* $(date '+%Y-%m-%d %H:%M:%S')\n"
        RESTART_MESSAGE="${RESTART_MESSAGE}🔢 *Total Services:* ${total_services}\n"
        RESTART_MESSAGE="${RESTART_MESSAGE}✅ *Berhasil:* $((total_services - failed_count))\n"
        RESTART_MESSAGE="${RESTART_MESSAGE}❌ *Gagal:* ${failed_count}"
    else
        RESTART_STATUS="FAILED"
        # Hapus koma terakhir dari failed services
        FAILED_SERVICES="${FAILED_SERVICES%, }"
        RESTART_MESSAGE="⚠️ *RESTART SERVICE SELESAI DENGAN ERROR*\n\n"
        RESTART_MESSAGE="${RESTART_MESSAGE}📊 *Status:* Ada service yang gagal direstart\n"
        RESTART_MESSAGE="${RESTART_MESSAGE}📧 *User:* ${email:-'Manual'}\n"
        RESTART_MESSAGE="${RESTART_MESSAGE}⏰ *Waktu:* $(date '+%Y-%m-%d %H:%M:%S')\n"
        RESTART_MESSAGE="${RESTART_MESSAGE}🔢 *Total Services:* ${total_services}\n"
        RESTART_MESSAGE="${RESTART_MESSAGE}✅ *Berhasil:* $((total_services - failed_count))\n"
        RESTART_MESSAGE="${RESTART_MESSAGE}❌ *Gagal:* ${failed_count}\n"
        RESTART_MESSAGE="${RESTART_MESSAGE}🚨 *Failed Services:* ${FAILED_SERVICES}"
    fi
    
    echo -e "\n============================================"
    echo -e "${GREEN}📊 RINGKASAN OPERASI${NC}"
    echo -e "Total Services: ${total_services}"
    echo -e "Berhasil: $((total_services - failed_count))"
    echo -e "Gagal: ${failed_count}"
    
    if [ "$failed_count" -gt 0 ]; then
        echo -e "${RED}Failed Services: ${FAILED_SERVICES}${NC}"
    fi
    
    return $failed_count
}

# =============================================================================
# FUNCTION: Send Telegram Notification
# Fungsi untuk mengirim notifikasi ke Telegram Bot
# =============================================================================
send_telegram_notification() {
    local bot_token="$1"
    local chat_id="$2"
    local message="$3"
    
    if [ -z "$bot_token" ] || [ -z "$chat_id" ]; then
        echo -e "${YELLOW}⚠️ Telegram credentials tidak lengkap, skip notifikasi${NC}"
        return 1
    fi
    
    echo -e "📱 Mengirim notifikasi Telegram..."
    
    # Escape karakter khusus untuk Telegram API
    local escaped_message=$(echo -e "$message" | sed 's/[[\*_`]/\\&/g')
    
    # Kirim pesan via Telegram API
    local response=$(curl -s -X POST "https://api.telegram.org/bot${bot_token}/sendMessage" \
        -d "chat_id=${chat_id}" \
        -d "text=${escaped_message}" \
        -d "parse_mode=Markdown")
    
    if echo "$response" | grep -q '"ok":true'; then
        echo -e "✅ Notifikasi Telegram berhasil dikirim"
        return 0
    else
        echo -e "${RED}❌ Gagal mengirim notifikasi Telegram${NC}"
        echo -e "Response: $response"
        return 1
    fi
}

# =============================================================================
# FUNCTION: Main Bot Restart Service
# Fungsi utama yang dipanggil oleh bot dengan parameter lengkap
# =============================================================================
main_bot_restartservice() {
    local email="$1"
    local bot_token="$2"
    local chat_id="$3"
    local send_notification="${4:-true}"
    
    echo -e "${GREEN}🤖 BOT RESTART SERVICE INITIATED${NC}"
    echo -e "📧 Email: ${email:-'Not provided'}"
    echo -e "🔔 Send Notification: $send_notification"
    echo -e ""
    
    # Jalankan restart service
    core_restart_all_services "$email"
    local exit_code=$?
    
    # Kirim notifikasi Telegram jika diminta
    if [ "$send_notification" == "true" ]; then
        send_telegram_notification "$bot_token" "$chat_id" "$RESTART_MESSAGE"
    fi
    
    return $exit_code
}

# =============================================================================
# FUNCTION: Get Result Status
# Fungsi untuk mendapatkan status hasil restart (SUCCESS/FAILED)
# =============================================================================
get_result_restartservice() {
    echo "$RESTART_STATUS"
}

# =============================================================================
# FUNCTION: Get Result Message
# Fungsi untuk mendapatkan pesan hasil restart untuk Telegram
# =============================================================================
get_result_message_restartservice() {
    echo -e "$RESTART_MESSAGE"
}

# =============================================================================
# FUNCTION: Get Detailed Log
# Fungsi untuk mendapatkan log detail semua operasi
# =============================================================================
get_detailed_log_restartservice() {
    echo -e "$RESTART_LOG"
}

# =============================================================================
# FUNCTION: CLI Interface
# Antarmuka baris perintah untuk penggunaan manual
# =============================================================================
cli_restartservice() {
    clear
    echo -e "${GREEN}===============================================${NC}"
    echo -e "${GREEN}       RESTART ALL SERVICES - CLI MODE        ${NC}"
    echo -e "${GREEN}===============================================${NC}"
    echo -e ""
    
    # Jalankan restart tanpa parameter bot
    main_bot_restartservice "CLI-Manual" "" "" "false"
    local exit_code=$?
    
    echo -e ""
    echo -e "${GREEN}Back to menu in 3 seconds...${NC}"
    sleep 3
    
    return $exit_code
}

# =============================================================================
# EXPORT FUNCTIONS - Untuk akses dari script lain
# =============================================================================
export -f main_bot_restartservice
export -f get_result_restartservice  
export -f get_result_message_restartservice
export -f get_detailed_log_restartservice
export -f core_restart_all_services
export -f send_telegram_notification

# =============================================================================
# MAIN EXECUTION - Deteksi mode eksekusi
# =============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script dijalankan langsung (bukan di-source)
    if [ $# -eq 0 ]; then
        # Mode CLI tanpa parameter
        cli_restartservice
    else
        # Mode dengan parameter
        main_bot_restartservice "$@"
    fi
fi

# =============================================================================
# DOKUMENTASI PENGGUNAAN
# =============================================================================

: '
===============================================================================
                            DOKUMENTASI PENGGUNAAN
===============================================================================

1. CLI Interface:
   ./restartservice.sh
   - Menjalankan restart service dalam mode CLI interaktif
   - Tidak mengirim notifikasi Telegram
   - Cocok untuk penggunaan manual administrator

2. Import ke script lain:
   source /path/to/restartservice.sh
   
   # Restart dengan notifikasi Telegram
   main_bot_restartservice "user@email.com" "BOT_TOKEN" "CHAT_ID" "true"
   
   # Restart tanpa notifikasi
   main_bot_restartservice "user@email.com" "" "" "false"
   
   # Ambil hasil setelah eksekusi
   status=$(get_result_restartservice)
   message=$(get_result_message_restartservice)
   detailed_log=$(get_detailed_log_restartservice)

3. Parameter main_bot_restartservice:
   $1 = email (string) - Email user yang meminta restart
   $2 = bot_token (string) - Token Telegram Bot (opsional)
   $3 = chat_id (string) - Chat ID Telegram (opsional)  
   $4 = send_notification (true/false) - Kirim notifikasi atau tidak

4. Return Value:
   - Return code 0: Semua service berhasil direstart
   - Return code >0: Ada service yang gagal (jumlah = jumlah service gagal)
   
   Global variables setelah eksekusi:
   - RESTART_STATUS: "SUCCESS" atau "FAILED"
   - RESTART_MESSAGE: Pesan formatted untuk Telegram
   - RESTART_LOG: Log detail semua operasi
   - FAILED_SERVICES: Daftar service yang gagal

5. Contoh Integrasi Bot:
   #!/bin/bash
   source /path/to/restartservice.sh
   
   # Jalankan restart service
   main_bot_restartservice "admin@domain.com" "$BOT_TOKEN" "$CHAT_ID" "true"
   
   # Cek hasil
   if [ "$(get_result_restartservice)" == "SUCCESS" ]; then
       echo "Semua service berhasil direstart"
   else
       echo "Ada service yang gagal: $(get_result_message_restartservice)"
   fi

===============================================================================
'