#!/bin/bash

# =============================================================================
# FIXCERTVPN - SSL Certificate Renewal Script for Telegram Bot Integration
# =============================================================================
# Deskripsi: Script untuk memperbaharui sertifikat SSL dengan integrasi bot Telegram
# Author: Converted for Bot Integration
# Version: 2.0 - Function Based
# =============================================================================

# ===========================
# KONFIGURASI WARNA & STYLING
# ===========================
DF='\e[39m'
Bold='\e[1m'
Blink='\e[5m'
yell='\e[33m'
red='\e[31m'
green='\e[32m'
blue='\e[34m'
PURPLE='\e[35m'
cyan='\e[36m'
Lred='\e[91m'
Lgreen='\e[92m'
yellow='\e[93m'
NC='\e[0m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
LIGHT='\033[0;37m'
grenbo="\e[92;1m"

# Fungsi warna untuk output
purple() { echo -e "\\033[35;1m${*}\\033[0m"; }
tyblue() { echo -e "\\033[36;1m${*}\\033[0m"; }
yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }

# ===========================
# VARIABEL GLOBAL & KONFIGURASI
# ===========================
CHATID=$(grep -E "^#bot# " "/etc/bot/.bot.db" | cut -d ' ' -f 3)
KEY=$(grep -E "^#bot# " "/etc/bot/.bot.db" | cut -d ' ' -f 2)
export TIME="10"
export URL="https://api.telegram.org/bot$KEY/sendMessage"

# Variabel untuk menyimpan hasil operasi
FIXCERTVPN_STATUS=""
FIXCERTVPN_MESSAGE=""
FIXCERTVPN_DOMAIN=""
FIXCERTVPN_TIMESTAMP=""

# ===========================
# FUNGSI UTILITAS
# ===========================

# Fungsi untuk logging dengan timestamp
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message"
}

# Fungsi untuk mendapatkan informasi domain
get_domain_info() {
    if [[ -f "/etc/xray/domain" ]]; then
        FIXCERTVPN_DOMAIN=$(cat /etc/xray/domain)
        return 0
    else
        FIXCERTVPN_DOMAIN="Unknown"
        return 1
    fi
}

# ===========================
# FUNGSI NOTIFIKASI TELEGRAM
# ===========================

# Fungsi untuk mengirim notifikasi ke Telegram
send_telegram_notification() {
    local status="$1"
    local domain="$2"
    local details="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Validasi parameter Telegram
    if [[ -z "$CHATID" || -z "$KEY" ]]; then
        log_message "ERROR" "Konfigurasi Telegram tidak lengkap"
        return 1
    fi
    
    # Tentukan status icon
    local status_icon="✅"
    local status_text="BERHASIL"
    if [[ "$status" != "SUCCESS" ]]; then
        status_icon="❌"
        status_text="GAGAL"
    fi
    
    # Format pesan Telegram
    local TEXT="
<code>━━━━━━━━━━━━━━━━━━━━</code>
<code>🔒 SSL CERTIFICATE RENEWAL</code>
<code>━━━━━━━━━━━━━━━━━━━━</code>
<code>Status    : $status_icon $status_text</code>
<code>Domain    : $domain</code>
<code>Waktu     : $timestamp</code>
<code>━━━━━━━━━━━━━━━━━━━━</code>
<code>Detail:</code>
<code>$details</code>
<code>━━━━━━━━━━━━━━━━━━━━</code>
"
    
    # Kirim ke Telegram
    local response=$(curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL)
    
    # Simpan pesan untuk pengambilan nanti
    FIXCERTVPN_MESSAGE="$TEXT"
    
    if [[ $? -eq 0 ]]; then
        log_message "INFO" "Notifikasi Telegram berhasil dikirim"
        return 0
    else
        log_message "ERROR" "Gagal mengirim notifikasi Telegram"
        return 1
    fi
}

# ===========================
# FUNGSI UTAMA SSL RENEWAL
# ===========================

# Fungsi untuk melakukan renewal SSL certificate
perform_ssl_renewal() {
    local domain="$1"
    local start_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    log_message "INFO" "Memulai proses renewal SSL untuk domain: $domain"
    
    # Hapus sertifikat lama
    log_message "INFO" "Menghapus sertifikat lama..."
    rm -rf /etc/xray/xray.key 2>/dev/null
    rm -rf /etc/xray/xray.crt 2>/dev/null
    
    # Deteksi dan stop web server yang menggunakan port 80
    log_message "INFO" "Mendeteksi web server pada port 80..."
    local STOPWEBSERVER=$(lsof -i:80 | cut -d' ' -f1 | awk 'NR==2 {print $1}')
    
    # Bersihkan instalasi acme.sh sebelumnya
    log_message "INFO" "Membersihkan instalasi acme.sh sebelumnya..."
    rm -rf /root/.acme.sh
    mkdir -p /root/.acme.sh
    
    # Stop semua web server
    log_message "INFO" "Menghentikan web server..."
    [[ -n "$STOPWEBSERVER" ]] && systemctl stop $STOPWEBSERVER 2>/dev/null
    systemctl stop nginx 2>/dev/null
    systemctl stop haproxy 2>/dev/null
    
    # Download dan setup acme.sh
    log_message "INFO" "Mengunduh dan mengatur acme.sh..."
    if ! curl -s https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh; then
        log_message "ERROR" "Gagal mengunduh acme.sh"
        return 1
    fi
    
    chmod +x /root/.acme.sh/acme.sh
    
    # Update acme.sh
    log_message "INFO" "Memperbarui acme.sh..."
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    
    # Issue sertifikat baru
    log_message "INFO" "Mengeluarkan sertifikat SSL baru..."
    if ! /root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256; then
        log_message "ERROR" "Gagal mengeluarkan sertifikat SSL"
        return 1
    fi
    
    # Install sertifikat
    log_message "INFO" "Menginstall sertifikat SSL..."
    if ! ~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc; then
        log_message "ERROR" "Gagal menginstall sertifikat SSL"
        return 1
    fi
    
    # Set permission
    chmod 777 /etc/xray/xray.key
    
    # Restart services
    log_message "INFO" "Merestart layanan..."
    systemctl restart nginx 2>/dev/null
    systemctl restart xray 2>/dev/null
    systemctl restart haproxy 2>/dev/null
    
    # Verifikasi sertifikat
    if [[ -f "/etc/xray/xray.crt" && -f "/etc/xray/xray.key" ]]; then
        log_message "INFO" "Renewal SSL berhasil diselesaikan"
        return 0
    else
        log_message "ERROR" "Sertifikat tidak ditemukan setelah renewal"
        return 1
    fi
}

# ===========================
# FUNGSI ORKESTRATOR UTAMA
# ===========================

# Fungsi utama untuk bot (tanpa interaksi)
main_bot_fixcertvpn() {
    local custom_domain="$1"  # Optional: domain kustom
    
    # Reset variabel global
    FIXCERTVPN_STATUS=""
    FIXCERTVPN_MESSAGE=""
    FIXCERTVPN_DOMAIN=""
    FIXCERTVPN_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    log_message "INFO" "=== MEMULAI FIXCERTVPN BOT MODE ==="
    
    # Dapatkan informasi domain
    if [[ -n "$custom_domain" ]]; then
        FIXCERTVPN_DOMAIN="$custom_domain"
        log_message "INFO" "Menggunakan domain kustom: $custom_domain"
    else
        if ! get_domain_info; then
            FIXCERTVPN_STATUS="FAILED"
            local error_msg="Domain tidak ditemukan di /etc/xray/domain"
            log_message "ERROR" "$error_msg"
            send_telegram_notification "FAILED" "Unknown" "$error_msg"
            return 1
        fi
    fi
    
    log_message "INFO" "Domain yang akan diproses: $FIXCERTVPN_DOMAIN"
    
    # Lakukan renewal SSL
    if perform_ssl_renewal "$FIXCERTVPN_DOMAIN"; then
        FIXCERTVPN_STATUS="SUCCESS"
        local success_msg="Renewal SSL berhasil untuk domain $FIXCERTVPN_DOMAIN"
        log_message "INFO" "$success_msg"
        send_telegram_notification "SUCCESS" "$FIXCERTVPN_DOMAIN" "$success_msg"
        
        log_message "INFO" "=== FIXCERTVPN SELESAI - STATUS: BERHASIL ==="
        return 0
    else
        FIXCERTVPN_STATUS="FAILED"
        local error_msg="Renewal SSL gagal untuk domain $FIXCERTVPN_DOMAIN"
        log_message "ERROR" "$error_msg"
        send_telegram_notification "FAILED" "$FIXCERTVPN_DOMAIN" "$error_msg"
        
        log_message "ERROR" "=== FIXCERTVPN SELESAI - STATUS: GAGAL ==="
        return 1
    fi
}

# ===========================
# FUNGSI UNTUK MENGAMBIL HASIL
# ===========================

# Fungsi untuk mendapatkan status hasil fixcertvpn
get_result_fixcertvpn() {
    echo "$FIXCERTVPN_STATUS"
}

# Fungsi untuk mendapatkan pesan hasil fixcertvpn
get_result_message_fixcertvpn() {
    echo "$FIXCERTVPN_MESSAGE"
}

# Fungsi untuk mendapatkan informasi lengkap hasil
get_fixcertvpn_info() {
    local info="STATUS:$FIXCERTVPN_STATUS|DOMAIN:$FIXCERTVPN_DOMAIN|TIMESTAMP:$FIXCERTVPN_TIMESTAMP"
    echo "$info"
}

# ===========================
# CLI INTERFACE
# ===========================

# Fungsi untuk CLI mode (dengan interaksi)
main_cli_fixcertvpn() {
    clear
    green "========================================="
    green "    🔒 FIXCERTVPN - SSL RENEWAL TOOL"
    green "========================================="
    echo ""
    
    # Tampilkan informasi domain saat ini
    if get_domain_info; then
        tyblue "Domain saat ini: $FIXCERTVPN_DOMAIN"
    else
        red "⚠️  Domain tidak ditemukan!"
    fi
    
    echo ""
    yellow "Pilihan:"
    echo "1. Renewal SSL untuk domain saat ini"
    echo "2. Renewal SSL untuk domain kustom"
    echo "3. Keluar"
    echo ""
    
    read -p "Masukkan pilihan [1-3]: " choice
    
    case $choice in
        1)
            echo ""
            green "🔄 Memulai renewal SSL untuk domain: $FIXCERTVPN_DOMAIN"
            echo ""
            main_bot_fixcertvpn
            ;;
        2)
            echo ""
            read -p "Masukkan domain kustom: " custom_domain
            if [[ -n "$custom_domain" ]]; then
                echo ""
                green "🔄 Memulai renewal SSL untuk domain: $custom_domain"
                echo ""
                main_bot_fixcertvpn "$custom_domain"
            else
                red "❌ Domain tidak boleh kosong!"
                exit 1
            fi
            ;;
        3)
            echo ""
            yellow "👋 Terima kasih!"
            exit 0
            ;;
        *)
            echo ""
            red "❌ Pilihan tidak valid!"
            exit 1
            ;;
    esac
    
    # Tampilkan hasil
    echo ""
    if [[ "$FIXCERTVPN_STATUS" == "SUCCESS" ]]; then
        green "✅ RENEWAL SSL BERHASIL!"
        green "Domain: $FIXCERTVPN_DOMAIN"
        green "Waktu: $FIXCERTVPN_TIMESTAMP"
    else
        red "❌ RENEWAL SSL GAGAL!"
        red "Domain: $FIXCERTVPN_DOMAIN"
        red "Waktu: $FIXCERTVPN_TIMESTAMP"
    fi
    echo ""
}

# ===========================
# EXPORT FUNCTIONS
# ===========================

# Export fungsi untuk digunakan oleh script lain
export -f main_bot_fixcertvpn
export -f get_result_fixcertvpn
export -f get_result_message_fixcertvpn
export -f get_fixcertvpn_info
export -f send_telegram_notification

# ===========================
# MAIN EXECUTION
# ===========================

# Jalankan sesuai mode
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script dijalankan langsung
    if [[ "$1" == "--bot" ]]; then
        # Mode bot (tanpa interaksi)
        main_bot_fixcertvpn "$2"
    else
        # Mode CLI (dengan interaksi)
        main_cli_fixcertvpn
    fi
fi

# =============================================================================
# DOKUMENTASI PENGGUNAAN
# =============================================================================

# 1. CLI Interface:
#    ./fixcertvpn.sh                    # Mode interaktif
#    ./fixcertvpn.sh --bot              # Mode bot dengan domain dari file
#    ./fixcertvpn.sh --bot example.com  # Mode bot dengan domain kustom

# 2. Import ke script lain:
#    source /path/to/fixcertvpn.sh
#    main_bot_fixcertvpn "example.com"
#    status=$(get_result_fixcertvpn)
#    message=$(get_result_message_fixcertvpn)

# 3. Parameter:
#    main_bot_fixcertvpn [domain]       # domain opsional, jika kosong ambil dari file
#    get_result_fixcertvpn              # mengembalikan SUCCESS/FAILED
#    get_result_message_fixcertvpn      # mengembalikan pesan Telegram
#    get_fixcertvpn_info                # mengembalikan info lengkap

# 4. Return Value:
#    0 = Sukses
#    1 = Gagal
#    Status tersimpan dalam variabel global yang bisa diakses via fungsi get_*

# 5. Contoh penggunaan dalam script bot:
#    #!/bin/bash
#    source /path/to/fixcertvpn.sh
#    
#    # Jalankan fixcertvpn
#    main_bot_fixcertvpn "mydomain.com"
#    
#    # Ambil hasil
#    statusfixcertvpn=$(get_result_fixcertvpn)
#    messagefixcertvpn=$(get_result_message_fixcertvpn)
#    
#    # Cek status
#    if [[ "$statusfixcertvpn" == "SUCCESS" ]]; then
#        echo "SSL renewal berhasil!"
#    else
#        echo "SSL renewal gagal!"
#    fi
#    
#    # Gunakan pesan untuk keperluan lain
#    echo "$messagefixcertvpn"