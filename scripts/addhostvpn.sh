#!/bin/bash

# ━━━━━━━━━━━※ ·❆· ※━━━━━━━━━━━
# 𓈃 System Request ➠ Debian 9+/Ubuntu 18.04+/20+
# 𓈃 Developer ➠ MikkuChan (Modified for Bot Integration)
# 𓈃 Email      ➠ fadztechs2@gmail.com
# 𓈃 Telegram   ➠ https://t.me/fadzdigital
# ━━━━━━━━━━━※ ·❆· ※━━━━━━━━━━━

# ═══════════════════════════════════════════════════════════════
# BAGIAN 1: KONFIGURASI DAN VARIABEL GLOBAL
# ═══════════════════════════════════════════════════════════════

# Warna untuk output
RED="\033[31m"
YELLOW="\033[33m"
NC='\e[0m'
YELL='\033[0;33m'
BRED='\033[1;31m'
GREEN='\033[0;32m'
ORANGE='\033[33m'
BGWHITE='\e[0;100;37m'

# Variabel global untuk menyimpan hasil operasi
ADDHOST_STATUS=""
ADDHOST_MESSAGE=""
ADDHOST_DOMAIN=""
ADDHOST_IP=""

# ═══════════════════════════════════════════════════════════════
# BAGIAN 2: FUNGSI UTILITAS DAN HELPER
# ═══════════════════════════════════════════════════════════════

# Fungsi untuk mendapatkan konfigurasi bot Telegram
get_telegram_config() {
    local chatid=$(grep -E "^#bot# " "/etc/bot/.bot.db" 2>/dev/null | cut -d ' ' -f 3)
    local key=$(grep -E "^#bot# " "/etc/bot/.bot.db" 2>/dev/null | cut -d ' ' -f 2)
    
    if [[ -z "$chatid" || -z "$key" ]]; then
        echo "ERROR|Konfigurasi bot Telegram tidak ditemukan"
        return 1
    fi
    
    echo "$chatid|$key"
    return 0
}

# Fungsi untuk mendapatkan IP VPS
get_vps_ip() {
    local ip=$(curl -sS --connect-timeout 10 ipv4.icanhazip.com 2>/dev/null)
    if [[ -z "$ip" ]]; then
        ip=$(wget -qO- --timeout=10 ipv4.icanhazip.com 2>/dev/null)
    fi
    
    if [[ -z "$ip" ]]; then
        echo "ERROR"
        return 1
    fi
    
    echo "$ip"
    return 0
}

# Fungsi untuk validasi lisensi script
check_script_license() {
    local myip=$(get_vps_ip)
    if [[ "$myip" == "ERROR" ]]; then
        ADDHOST_STATUS="ERROR"
        ADDHOST_MESSAGE="Gagal mendapatkan IP VPS"
        return 1
    fi
    
    local data_server=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //' 2>/dev/null)
    local date_list=$(date +"%Y-%m-%d" -d "$data_server" 2>/dev/null)
    local data_ip="https://raw.githubusercontent.com/MikkuChan/instalasi/main/register"
    
    local useexp=$(wget -qO- --timeout=10 "$data_ip" 2>/dev/null | grep "$myip" | awk '{print $3}')
    
    if [[ -z "$useexp" ]]; then
        ADDHOST_STATUS="ERROR"
        ADDHOST_MESSAGE="IP VPS tidak terdaftar dalam lisensi"
        return 1
    fi
    
    if [[ "$date_list" > "$useexp" ]]; then
        ADDHOST_STATUS="ERROR"
        ADDHOST_MESSAGE="Lisensi script telah expired untuk IP: $myip"
        return 1
    fi
    
    ADDHOST_IP="$myip"
    return 0
}

# Fungsi untuk validasi domain
validate_domain() {
    local domain="$1"
    
    # Cek apakah domain kosong
    if [[ -z "$domain" ]]; then
        ADDHOST_STATUS="ERROR"
        ADDHOST_MESSAGE="Domain tidak boleh kosong"
        return 1
    fi
    
    # Cek format domain dasar
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        ADDHOST_STATUS="ERROR"
        ADDHOST_MESSAGE="Format domain tidak valid: $domain"
        return 1
    fi
    
    # Ping test domain
    if ! ping -c 1 -W 5 "$domain" &>/dev/null; then
        ADDHOST_STATUS="ERROR"
        ADDHOST_MESSAGE="Domain tidak dapat dijangkau atau belum dipointing: $domain"
        return 1
    fi
    
    return 0
}

# ═══════════════════════════════════════════════════════════════
# BAGIAN 3: FUNGSI UTAMA OPERASI DOMAIN DAN SSL
# ═══════════════════════════════════════════════════════════════

# Fungsi untuk mengganti domain
change_domain() {
    local new_domain="$1"
    
    # Validasi domain terlebih dahulu
    if ! validate_domain "$new_domain"; then
        return 1
    fi
    
    # Simpan domain ke file konfigurasi
    echo "$new_domain" > /etc/xray/domain 2>/dev/null
    echo "$new_domain" > /root/domain 2>/dev/null
    echo "IP=$new_domain" > /var/lib/kyt/ipvps.conf 2>/dev/null
    
    # Cek apakah penyimpanan berhasil
    if [[ ! -f "/etc/xray/domain" ]] || [[ "$(cat /etc/xray/domain 2>/dev/null)" != "$new_domain" ]]; then
        ADDHOST_STATUS="ERROR"
        ADDHOST_MESSAGE="Gagal menyimpan konfigurasi domain"
        return 1
    fi
    
    ADDHOST_DOMAIN="$new_domain"
    return 0
}

# Fungsi untuk memasang SSL
install_ssl() {
    local domain="$1"
    
    # Hentikan layanan web server
    local stopwebserver=$(lsof -i:80 2>/dev/null | cut -d' ' -f1 | awk 'NR==2 {print $1}')
    [[ -n "$stopwebserver" ]] && systemctl stop "$stopwebserver" 2>/dev/null
    systemctl stop nginx 2>/dev/null
    systemctl stop haproxy 2>/dev/null
    
    # Hapus SSL lama
    rm -rf /etc/xray/xray.key /etc/xray/xray.crt 2>/dev/null
    rm -rf /root/.acme.sh 2>/dev/null
    mkdir -p /root/.acme.sh
    
    # Download dan setup ACME.sh
    if ! curl -s --connect-timeout 30 https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh; then
        ADDHOST_STATUS="ERROR"
        ADDHOST_MESSAGE="Gagal mengunduh ACME.sh"
        return 1
    fi
    
    chmod +x /root/.acme.sh/acme.sh
    
    # Setup ACME
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade 2>/dev/null
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt 2>/dev/null
    
    # Generate SSL certificate
    if ! /root/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256 2>/dev/null; then
        ADDHOST_STATUS="ERROR"
        ADDHOST_MESSAGE="Gagal generate SSL certificate untuk domain: $domain"
        return 1
    fi
    
    # Install certificate
    if ! ~/.acme.sh/acme.sh --installcert -d "$domain" --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc 2>/dev/null; then
        ADDHOST_STATUS="ERROR"
        ADDHOST_MESSAGE="Gagal install SSL certificate"
        return 1
    fi
    
    # Set permissions
    chmod 777 /etc/xray/xray.key 2>/dev/null
    
    # Restart services
    systemctl restart nginx 2>/dev/null
    systemctl restart xray 2>/dev/null
    systemctl restart haproxy 2>/dev/null
    
    return 0
}

# ═══════════════════════════════════════════════════════════════
# BAGIAN 4: FUNGSI NOTIFIKASI TELEGRAM
# ═══════════════════════════════════════════════════════════════

# Fungsi untuk mengirim notifikasi ke Telegram
send_telegram_notification() {
    local domain="$1"
    local ip="$2"
    local status="$3"
    
    local telegram_config=$(get_telegram_config)
    if [[ "$telegram_config" == ERROR* ]]; then
        return 1
    fi
    
    local chatid=$(echo "$telegram_config" | cut -d'|' -f1)
    local key=$(echo "$telegram_config" | cut -d'|' -f2)
    local url="https://api.telegram.org/bot$key/sendMessage"
    
    local text=""
    if [[ "$status" == "SUCCESS" ]]; then
        text="
<code>━━━━━━━━━━※ ·❆· ※━━━━━━━━━━</code>
<b>✅ GANTI DOMAIN BERHASIL</b>
<code>━━━━━━━━━━※ ·❆· ※━━━━━━━━━━</code>
<b>🌐 IP VPS:</b> <code>$ip</code>
<b>🔗 DOMAIN:</b> <code>$domain</code>
<b>🔒 SSL:</b> <code>Aktif</code>
<b>📅 Waktu:</b> <code>$(date '+%d/%m/%Y %H:%M:%S')</code>
<code>━━━━━━━━━━※ ·❆· ※━━━━━━━━━━</code>
<code>🤖 @fadzdigital</code>"
    else
        text="
<code>━━━━━━━━━━※ ·❆· ※━━━━━━━━━━</code>
<b>❌ GANTI DOMAIN GAGAL</b>
<code>━━━━━━━━━━※ ·❆· ※━━━━━━━━━━</code>
<b>🌐 IP VPS:</b> <code>$ip</code>
<b>🔗 DOMAIN:</b> <code>$domain</code>
<b>❗ Error:</b> <code>$ADDHOST_MESSAGE</code>
<b>📅 Waktu:</b> <code>$(date '+%d/%m/%Y %H:%M:%S')</code>
<code>━━━━━━━━━━※ ·❆· ※━━━━━━━━━━</code>
<code>🤖 @fadzdigital</code>"
    fi
    
    # Simpan pesan untuk fungsi get_result_message_addhostvpn
    ADDHOST_MESSAGE="$text"
    
    # Kirim ke Telegram
    curl -s --max-time 30 -d "chat_id=$chatid&disable_web_page_preview=1&text=$text&parse_mode=html" "$url" >/dev/null 2>&1
    
    return 0
}

# ═══════════════════════════════════════════════════════════════
# BAGIAN 5: FUNGSI UTAMA DAN ORKESTRATOR
# ═══════════════════════════════════════════════════════════════

# Fungsi utama untuk bot (non-interaktif)
main_bot_addhostvpn() {
    local domain="$1"
    
    # Reset status global
    ADDHOST_STATUS=""
    ADDHOST_MESSAGE=""
    ADDHOST_DOMAIN=""
    ADDHOST_IP=""
    
    # Validasi lisensi script
    if ! check_script_license; then
        send_telegram_notification "$domain" "$ADDHOST_IP" "ERROR"
        return 1
    fi
    
    # Proses ganti domain
    if ! change_domain "$domain"; then
        send_telegram_notification "$domain" "$ADDHOST_IP" "ERROR"
        return 1
    fi
    
    # Install SSL
    if ! install_ssl "$domain"; then
        send_telegram_notification "$domain" "$ADDHOST_IP" "ERROR"
        return 1
    fi
    
    # Jika semua berhasil
    ADDHOST_STATUS="SUCCESS"
    ADDHOST_MESSAGE="Domain berhasil diganti dan SSL telah dipasang"
    
    # Kirim notifikasi sukses
    send_telegram_notification "$domain" "$ADDHOST_IP" "SUCCESS"
    
    return 0
}

# ═══════════════════════════════════════════════════════════════
# BAGIAN 6: FUNGSI EXPORT UNTUK INTEGRASI SCRIPT LAIN
# ═══════════════════════════════════════════════════════════════

# Fungsi untuk mendapatkan status hasil addhostvpn
get_result_addhostvpn() {
    echo "$ADDHOST_STATUS"
}

# Fungsi untuk mendapatkan pesan hasil addhostvpn
get_result_message_addhostvpn() {
    echo "$ADDHOST_MESSAGE"
}

# Fungsi untuk mendapatkan domain yang dipasang
get_result_domain_addhostvpn() {
    echo "$ADDHOST_DOMAIN"
}

# Fungsi untuk mendapatkan IP VPS
get_result_ip_addhostvpn() {
    echo "$ADDHOST_IP"
}

# Export semua fungsi agar bisa dipanggil dari script lain
export -f main_bot_addhostvpn
export -f get_result_addhostvpn
export -f get_result_message_addhostvpn
export -f get_result_domain_addhostvpn
export -f get_result_ip_addhostvpn

# ═══════════════════════════════════════════════════════════════
# BAGIAN 7: CLI INTERFACE
# ═══════════════════════════════════════════════════════════════

# Fungsi CLI dengan interface user-friendly
cli_addhostvpn() {
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}           🌐 ADDHOST VPN - GANTI DOMAIN           ${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [[ -z "$1" ]]; then
        echo -e "${RED}❌ Error: Domain diperlukan!${NC}"
        echo -e "${YELLOW}📝 Penggunaan: $0 {domain}${NC}"
        echo -e "${YELLOW}📝 Contoh: $0 vpn.example.com${NC}"
        exit 1
    fi
    
    local domain="$1"
    echo -e "${YELLOW}🔄 Memproses domain: $domain${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Jalankan fungsi utama
    if main_bot_addhostvpn "$domain"; then
        echo -e "${GREEN}✅ Berhasil mengganti domain ke: $domain${NC}"
        echo -e "${GREEN}✅ SSL telah dipasang dan aktif${NC}"
        echo -e "${GREEN}✅ Notifikasi telah dikirim ke Telegram${NC}"
    else
        echo -e "${RED}❌ Gagal mengganti domain: $(get_result_message_addhostvpn)${NC}"
    fi
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ═══════════════════════════════════════════════════════════════
# BAGIAN 8: EKSEKUSI SCRIPT
# ═══════════════════════════════════════════════════════════════

# Jika script dijalankan langsung dari command line
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cli_addhostvpn "$1"
fi

# ═══════════════════════════════════════════════════════════════
# DOKUMENTASI PENGGUNAAN
# ═══════════════════════════════════════════════════════════════

# 1. CLI Interface:
#    Jalankan langsung dari terminal:
#    ./addhostvpn.sh vpn.example.com
#    
#    atau dengan bash:
#    bash addhostvpn.sh vpn.example.com

# 2. Import ke script lain:
#    #!/bin/bash
#    source /path/to/addhostvpn.sh
#    
#    # Panggil fungsi utama
#    main_bot_addhostvpn "vpn.example.com"
#    
#    # Ambil hasil
#    status=$(get_result_addhostvpn)
#    message=$(get_result_message_addhostvpn)
#    domain=$(get_result_domain_addhostvpn)
#    ip=$(get_result_ip_addhostvpn)
#    
#    if [[ "$status" == "SUCCESS" ]]; then
#        echo "Berhasil: $message"
#    else
#        echo "Error: $message"
#    fi

# 3. Parameter:
#    - domain: Domain atau subdomain yang akan dipasang (wajib)
#    - Domain harus sudah dipointing ke IP VPS
#    - Format domain harus valid (contoh: vpn.example.com)

# 4. Return Value:
#    - get_result_addhostvpn(): "SUCCESS" atau "ERROR"
#    - get_result_message_addhostvpn(): Pesan detail hasil operasi
#    - get_result_domain_addhostvpn(): Domain yang dipasang
#    - get_result_ip_addhostvpn(): IP VPS yang digunakan

# 5. Integrasi Bot Telegram:
#    Script ini siap diintegrasikan dengan bot Telegram.
#    Konfigurasi bot harus tersedia di /etc/bot/.bot.db
#    Format: #bot# {BOT_TOKEN} {CHAT_ID}

# 6. Persyaratan Sistem:
#    - Debian 9+ / Ubuntu 18.04+
#    - Akses root
#    - Internet connection
#    - Domain sudah dipointing ke IP VPS
#    - Lisensi script aktif