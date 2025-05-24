#!/bin/bash
# ─────────────────※ ·❆· ※─────────────────
# 𓈃 System Request ➠ Debian 9+/Ubuntu 18.04+/20+
# 𓈃 Develovers ➠ MikkuChan (Modified for Bot Integration)
# 𓈃 Email      ➠ fadztechs2@gmail.com
# 𓈃 telegram   ➠ https://t.me/fadzdigital
# 𓈃 whatsapp   ➠ wa.me/+6285727035336
# ─────────────────※ ·❆· ※─────────────────

# ═══════════════════════════════════════════════════════════
# KONFIGURASI WARNA DAN VARIABEL GLOBAL
# ═══════════════════════════════════════════════════════════

# Warna ANSI untuk output terminal
RED='\033[1;91m'
GREEN='\033[1;92m'
YELLOW='\033[1;93m'
BLUE='\033[1;94m'
CYAN='\033[1;96m'
WHITE='\033[1;97m'
NC='\033[0m' # Reset warna

# Variabel global untuk menyimpan hasil operasi
GLOBAL_STATUS=""
GLOBAL_MESSAGE=""

# ═══════════════════════════════════════════════════════════
# POINT 1: VALIDASI SCRIPT - FUNGSI PENGECEKAN IZIN VPS
# ═══════════════════════════════════════════════════════════

validate_script() {
    local ipsaya=$(curl -sS ipv4.icanhazip.com 2>/dev/null)
    local data_server=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
    local date_list=$(date +"%Y-%m-%d" -d "$data_server" 2>/dev/null)
    local data_ip="https://raw.githubusercontent.com/MikkuChan/instalasi/main/register"
    
    # Cek apakah IP VPS terdaftar di whitelist
    local useexp=$(wget -qO- $data_ip 2>/dev/null | grep $ipsaya | awk '{print $3}')
    
    if [[ -z "$useexp" ]]; then
        GLOBAL_STATUS="ERROR"
        GLOBAL_MESSAGE="IP VPS tidak terdaftar dalam whitelist"
        return 1
    fi
    
    if [[ "$date_list" < "$useexp" ]]; then
        GLOBAL_STATUS="SUCCESS"
        GLOBAL_MESSAGE="Validasi VPS berhasil"
        return 0
    else
        GLOBAL_STATUS="ERROR"
        GLOBAL_MESSAGE="Permission denied - VPS diblokir atau expired"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════
# POINT 2: FUNGSI UTAMA CREATE TROJAN ACCOUNT
# ═══════════════════════════════════════════════════════════

create_trojan_bot() {
    local username="$1"
    local uuid_or_days="$2"
    local days="$3"
    local quota="$4"
    local iplimit="$5"
    local uuid=""
    
    # Validasi parameter input
    if [[ -z "$username" ]]; then
        GLOBAL_STATUS="ERROR"
        GLOBAL_MESSAGE="Username tidak boleh kosong"
        return 1
    fi
    
    # Deteksi apakah parameter kedua adalah UUID custom atau hari
    if [[ "$uuid_or_days" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        # Parameter kedua adalah UUID custom
        uuid="$uuid_or_days"
        days="$3"
        quota="$4"
        iplimit="$5"
    else
        # Parameter kedua adalah hari, generate UUID random
        uuid=$(cat /proc/sys/kernel/random/uuid)
        days="$uuid_or_days"
        quota="$3"
        iplimit="$4"
    fi
    
    # Set default values jika parameter kosong
    days=${days:-30}
    quota=${quota:-0}
    iplimit=${iplimit:-2}
    
    # Cek apakah username sudah ada
    local client_exists=$(grep -w "$username" /etc/xray/config.json 2>/dev/null | wc -l)
    if [[ ${client_exists} -gt 0 ]]; then
        GLOBAL_STATUS="ERROR"
        GLOBAL_MESSAGE="Username '$username' sudah ada, pilih nama lain"
        return 1
    fi
    
    # Perhitungan tanggal expired
    local exp=$(date -d "$days days" +"%Y-%m-%d")
    local tgl=$(date -d "$days days" +"%d")
    local bln=$(date -d "$days days" +"%b")
    local thn=$(date -d "$days days" +"%Y")
    local expe="$tgl $bln, $thn"
    local tgl2=$(date +"%d")
    local bln2=$(date +"%b")
    local thn2=$(date +"%Y")
    local tnggl="$tgl2 $bln2, $thn2"
    
    # Baca domain dari konfigurasi
    local domain=""
    if [[ -f "/var/lib/kyt/ipvps.conf" ]]; then
        source /var/lib/kyt/ipvps.conf
        if [[ "$IP" == "" ]]; then
            domain=$(cat /etc/xray/domain 2>/dev/null || echo "localhost")
        else
            domain=$IP
        fi
    else
        domain=$(cat /etc/xray/domain 2>/dev/null || echo "localhost")
    fi
    
    # Update konfigurasi Xray
    update_xray_config "$username" "$uuid" "$exp"
    
    # Generate links trojan
    generate_trojan_links "$username" "$uuid" "$domain"
    
    # Setup quota dan IP limit management
    setup_quota_ip_limit "$username" "$quota" "$iplimit"
    
    # Update database
    update_trojan_database "$username" "$exp" "$uuid" "$quota" "$iplimit"
    
    # Generate file config OpenClash
    generate_openclash_config "$username" "$uuid" "$domain"
    
    # Restart services
    systemctl reload xray >/dev/null 2>&1
    systemctl reload nginx >/dev/null 2>&1
    service cron restart >/dev/null 2>&1
    
    # Kirim notifikasi Telegram
    send_telegram_notification "$username" "$uuid" "$domain" "$quota" "$iplimit" "$days" "$tnggl" "$expe"
    
    GLOBAL_STATUS="SUCCESS"
    return 0
}

# ═══════════════════════════════════════════════════════════
# POINT 3: UPDATE KONFIGURASI XRAY
# ═══════════════════════════════════════════════════════════

update_xray_config() {
    local username="$1"
    local uuid="$2"
    local exp="$3"
    
    # Backup konfigurasi sebelum diubah
    cp /etc/xray/config.json /etc/xray/config.json.bak 2>/dev/null
    
    # Update konfigurasi Trojan WS
    sed -i '/#trojanws$/a\#! '"$username $exp"'\
},{"password": "'""$uuid""'","email": "'""$username""'"' /etc/xray/config.json
    
    # Update konfigurasi Trojan gRPC  
    sed -i '/#trojangrpc$/a\#! '"$username $exp"'\
},{"password": "'""$uuid""'","email": "'""$username""'"' /etc/xray/config.json
}

# ═══════════════════════════════════════════════════════════
# POINT 4: GENERATE TROJAN LINKS (WS TLS & gRPC)
# ═══════════════════════════════════════════════════════════

generate_trojan_links() {
    local username="$1"
    local uuid="$2"
    local domain="$3"
    
    # Generate Trojan WS TLS Link
    TROJAN_WS_LINK="trojan://${uuid}@${domain}:443?path=%2Ftrojan-ws&security=tls&host=${domain}&type=ws&sni=${domain}#${username}"
    
    # Generate Trojan gRPC Link
    TROJAN_GRPC_LINK="trojan://${uuid}@${domain}:443?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=${domain}#${username}"
}

# ═══════════════════════════════════════════════════════════
# POINT 5: MANAGEMENT KUOTA & IP LIMIT
# ═══════════════════════════════════════════════════════════

setup_quota_ip_limit() {
    local username="$1"
    local quota="$2"
    local iplimit="$3"
    
    # Setup IP Limit
    if [[ $iplimit -gt 0 ]]; then
        mkdir -p /etc/kyt/limit/trojan/ip
        echo -e "$iplimit" > /etc/kyt/limit/trojan/ip/$username
    fi
    
    # Setup Quota Limit
    if [[ -z ${quota} ]]; then
        quota="0"
    fi
    
    local quota_bytes=$(echo "${quota}" | sed 's/[^0-9]*//g')
    local quota_total=$((${quota_bytes} * 1024 * 1024 * 1024))
    
    if [[ ${quota_bytes} != "0" ]]; then
        mkdir -p /etc/trojan
        echo "${quota_total}" > /etc/trojan/${username}
    fi
}

# ═══════════════════════════════════════════════════════════
# POINT 6: DATABASE MANAGEMENT
# ═══════════════════════════════════════════════════════════

update_trojan_database() {
    local username="$1"
    local exp="$2"
    local uuid="$3"
    local quota="$4"
    local iplimit="$5"
    
    # Buat direktori database jika belum ada
    mkdir -p /etc/trojan
    
    # Hapus data lama jika ada
    local datadb=$(cat /etc/trojan/.trojan.db 2>/dev/null | grep "^###" | grep -w "${username}" | awk '{print $2}')
    if [[ "${datadb}" != '' ]]; then
        sed -i "/\b${username}\b/d" /etc/trojan/.trojan.db
    fi
    
    # Tambah data baru ke database
    echo "### ${username} ${exp} ${uuid} ${quota} ${iplimit}" >> /etc/trojan/.trojan.db
}

# ═══════════════════════════════════════════════════════════
# POINT 7: GENERATE FILE CONFIG OPENCLASH
# ═══════════════════════════════════════════════════════════

generate_openclash_config() {
    local username="$1"
    local uuid="$2"
    local domain="$3"
    
    # Buat direktori untuk file config
    mkdir -p /var/www/html
    
    # Generate file config OpenClash format YAML
    cat > /var/www/html/trojan-$username.txt <<-END

      # Format TROJAN For Clash #

# Format Trojan GO/WS

- name: Trojan-$username-GO/WS
  server: ${domain}
  port: 443
  type: trojan
  password: ${uuid}
  network: ws
  sni: ${domain}
  skip-cert-verify: true
  udp: true
  ws-opts:
    path: /trojan-ws
    headers:
        Host: ${domain}

# Format Trojan gRPC

- name: Trojan-$username-gRPC
  type: trojan
  server: ${domain}
  port: 443
  password: ${uuid}
  udp: true
  sni: ${domain}
  skip-cert-verify: true
  network: grpc
  grpc-opts:
    grpc-service-name: trojan-grpc
END
}

# ═══════════════════════════════════════════════════════════
# POINT 8: RETURN DATA TERSTRUKTUR
# ═══════════════════════════════════════════════════════════

get_result_statustrojan() {
    echo "$GLOBAL_STATUS"
}

get_result_message_trojan() {
    echo "$GLOBAL_MESSAGE"
}

get_trojan_account_data() {
    local username="$1"
    local uuid="$2"
    local domain="$3"
    local quota="$4"
    local iplimit="$5"
    local days="$6"
    local tnggl="$7"
    local expe="$8"
    
    # Return data dalam format JSON-like untuk parsing mudah
    cat <<EOF
USERNAME:${username}
UUID:${uuid}
DOMAIN:${domain}
QUOTA:${quota}
IPLIMIT:${iplimit}
DAYS:${days}
CREATED:${tnggl}
EXPIRED:${expe}
WS_LINK:${TROJAN_WS_LINK}
GRPC_LINK:${TROJAN_GRPC_LINK}
OPENCLASH_URL:https://${domain}:81/trojan-${username}.txt
EOF
}

# ═══════════════════════════════════════════════════════════
# POINT 9: TELEGRAM NOTIFICATION
# ═══════════════════════════════════════════════════════════

send_telegram_notification() {
    local username="$1"
    local uuid="$2"
    local domain="$3"
    local quota="$4"
    local iplimit="$5"
    local days="$6"
    local tnggl="$7"
    local expe="$8"
    
    # Ambil informasi lokasi dan ISP
    local location=$(curl -s ipinfo.io/json 2>/dev/null)
    local city=$(echo "$location" | jq -r '.city' 2>/dev/null || echo "Unknown")
    local isp=$(echo "$location" | jq -r '.org' 2>/dev/null || echo "Unknown")
    local myip=$(curl -s ifconfig.me 2>/dev/null || curl -sS ipv4.icanhazip.com 2>/dev/null)
    
    # Set default values jika gagal ambil data
    city=${city:-"Unknown"}
    isp=${isp:-"Unknown"}
    myip=${myip:-"Unknown"}
    
    # Baca token dan chat ID Telegram
    local bot_token=""
    local chat_id=""
    
    # Coba baca dari berbagai lokasi konfigurasi
    if [[ -f "/etc/telegram_bot/bot_token" ]] && [[ -f "/etc/telegram_bot/chat_id" ]]; then
        bot_token=$(cat /etc/telegram_bot/bot_token 2>/dev/null)
        chat_id=$(cat /etc/telegram_bot/chat_id 2>/dev/null)
    elif [[ -f "/etc/bot/.bot.db" ]]; then
        chat_id=$(grep -E "^#bot# " "/etc/bot/.bot.db" | cut -d ' ' -f 3)
        bot_token=$(grep -E "^#bot# " "/etc/bot/.bot.db" | cut -d ' ' -f 2)
    fi
    
    # Generate links
    generate_trojan_links "$username" "$uuid" "$domain"
    
    # Format pesan Telegram
    local text="───────────※ ·❆· ※───────────
<b>𓈃 CITY</b>: <code>$city</code>
<b>𓈃 ISP</b>: <code>$isp</code>
<b>𓈃 IP</b>: <code>$myip</code>
───────────※ ·❆· ※───────────
   <b>𓈃 DETAIL AKUN TROJAN 𓈃</b>
───────────※ ·❆· ※───────────
➠ <b>Remarks</b>     : <code>${username}</code>
➠ <b>Domain</b>      : <code>${domain}</code>
➠ <b>User Quota</b>  : <code>${quota} GB</code>
➠ <b>User IP</b>     : <code>${iplimit} IP</code>
➠ <b>Port</b>        : 400-900
➠ <b>Key</b>         : <code>${uuid}</code>
➠ <b>Path</b>        : /trojan-ws/multi-path
➠ <b>ServiceName</b> : trojan-grpc
───────────※ ·❆· ※───────────
        <b>𓈃 TROJAN WS TLS 𓈃</b>
───────────※ ·❆· ※───────────
<pre>${TROJAN_WS_LINK}</pre>
───────────※ ·❆· ※───────────
         <b>𓈃 TROJAN gRPC 𓈃</b>
───────────※ ·❆· ※───────────
<pre>${TROJAN_GRPC_LINK}</pre>
───────────※ ·❆· ※───────────
        <b>𓈃 FORMAT OpenClash 𓈃</b>
───────────※ ·❆· ※───────────
➠ https://${domain}:81/trojan-$username.txt
───────────※ ·❆· ※───────────
         <b>𓈃 CONVERTER YAML 𓈃</b>
───────────※ ·❆· ※───────────
➠ https://vpntech.my.id/converteryaml
───────────※ ·❆· ※───────────
      <b>𓈃 AUTO CONFIGURATION 𓈃</b>
───────────※ ·❆· ※───────────
➠ https://vpntech.my.id/auto-configuration
───────────※ ·❆· ※───────────
     <b>𓈃 START DATE END DATE 𓈃</b>
───────────※ ·❆· ※───────────
➠ <b>Aktif Selama</b>   : $days Hari
➠ <b>Dibuat Pada</b>    : $tnggl
➠ <b>Berakhir Pada</b>  : $expe
───────────※ ·❆· ※───────────
🤖 @085727035336"
    
    # Simpan pesan ke variabel global untuk diambil script lain
    GLOBAL_MESSAGE="$text"
    
    # Kirim ke Telegram jika token dan chat ID tersedia
    if [[ -n "$bot_token" ]] && [[ -n "$chat_id" ]]; then
        local url="https://api.telegram.org/bot$bot_token/sendMessage"
        local text_encoded=$(echo "$text" | jq -sRr @uri 2>/dev/null || echo "$text")
        
        # Log untuk debugging
        mkdir -p /var/log
        echo "$(date): Sending Telegram notification for user: $username" >> /var/log/telegram_debug.log
        
        # Kirim pesan
        local response=$(curl -s -d "chat_id=$chat_id&disable_web_page_preview=1&text=$text_encoded&parse_mode=html" "$url" 2>/dev/null)
        
        # Log response
        echo "Telegram API Response: $response" >> /var/log/telegram_debug.log
        
        return 0
    else
        echo "Warning: Telegram bot token atau chat ID tidak ditemukan" >> /var/log/telegram_debug.log
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════
# POINT 10: FUNGSI ORKESTRATOR UTAMA
# ═══════════════════════════════════════════════════════════

main_bot_create_trojan() {
    local username="$1"
    local param2="$2"
    local param3="$3"
    local param4="$4"
    local param5="$5"
    
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${WHITE}🚀 Memulai Proses Pembuatan Akun Trojan${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    
    # Step 1: Validasi Script
    echo -e "${YELLOW}⏳ Memvalidasi permission VPS...${NC}"
    if ! validate_script; then
        echo -e "${RED}❌ Validasi gagal: $(get_result_message_trojan)${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ Validasi VPS berhasil${NC}"
    
    # Step 2: Buat Akun Trojan
    echo -e "${YELLOW}⏳ Membuat akun trojan...${NC}"
    if ! create_trojan_bot "$username" "$param2" "$param3" "$param4" "$param5"; then
        echo -e "${RED}❌ Gagal membuat akun: $(get_result_message_trojan)${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Akun trojan berhasil dibuat${NC}"
    echo -e "${GREEN}✅ Notifikasi Telegram terkirim${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    
    return 0
}

# ═══════════════════════════════════════════════════════════
# POINT 11: CLI INTERFACE
# ═══════════════════════════════════════════════════════════

# Fungsi untuk menampilkan bantuan penggunaan
show_help() {
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${WHITE}🔧 TROJAN BOT SCRIPT HELP${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}Penggunaan:${NC}"
    echo -e "  $0 create <username> <hari> <kuota_gb> <ip_limit>"
    echo -e "  $0 create <username> <custom_uuid> <hari> <kuota_gb> <ip_limit>"
    echo -e ""
    echo -e "${YELLOW}Contoh:${NC}"
    echo -e "  $0 create user123 30 10 2"
    echo -e "  $0 create user123 550e8400-e29b-41d4-a716-446655440000 30 10 2"
    echo -e ""
    echo -e "${YELLOW}Parameter:${NC}"
    echo -e "  username    : Nama pengguna (wajib)"
    echo -e "  hari        : Masa aktif dalam hari (default: 30)"
    echo -e "  kuota_gb    : Kuota data dalam GB (default: 0 = unlimited)"
    echo -e "  ip_limit    : Batas IP pengguna (default: 2)"
    echo -e "  custom_uuid : UUID kustom (opsional, format UUID standar)"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
}

# Main CLI handler
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1}" in
        "create")
            if [[ -z "$2" ]]; then
                echo -e "${RED}❌ Error: Username diperlukan${NC}"
                show_help
                exit 1
            fi
            
            main_bot_create_trojan "$2" "$3" "$4" "$5" "$6"
            exit_code=$?
            
            # Tampilkan hasil
            echo -e "\n${YELLOW}📊 HASIL OPERASI:${NC}"
            echo -e "Status: $(get_result_statustrojan)"
            if [[ "$(get_result_statustrojan)" == "SUCCESS" ]]; then
                echo -e "${GREEN}✅ Akun berhasil dibuat${NC}"
            else
                echo -e "${RED}❌ $(get_result_message_trojan)${NC}"
            fi
            
            exit $exit_code
            ;;
        "help"|"-h"|"--help")
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Perintah tidak dikenal: $1${NC}"
            show_help
            exit 1
            ;;
    esac
fi

# ═══════════════════════════════════════════════════════════
# EXPORT FUNCTIONS UNTUK BOT INTEGRATION
# ═══════════════════════════════════════════════════════════

# Export semua fungsi penting agar bisa dipanggil dari script external
export -f validate_script
export -f create_trojan_bot
export -f main_bot_create_trojan
export -f get_result_statustrojan
export -f get_result_message_trojan
export -f get_trojan_account_data
export -f send_telegram_notification
export -f update_xray_config
export -f generate_trojan_links
export -f setup_quota_ip_limit
export -f update_trojan_database
export -f generate_openclash_config

# ═══════════════════════════════════════════════════════════
# DOKUMENTASI PENGGUNAAN
# ═══════════════════════════════════════════════════════════

# 1. CLI Interface:
#    Jalankan script langsung dari terminal:
#    ./trojan_bot.sh create username123 30 10 2
#    ./trojan_bot.sh create username123 550e8400-e29b-41d4-a716-446655440000 30 10 2
#
# 2. Import ke script lain:
#    #!/bin/bash
#    source /path/to/trojan_bot.sh
#    
#    # Panggil fungsi utama
#    main_bot_create_trojan "username123" "30" "10" "2"
#    
#    # Ambil hasil
#    status=$(get_result_statustrojan)
#    message=$(get_result_message_trojan)
#    
#    if [[ "$status" == "SUCCESS" ]]; then
#        echo "Berhasil: $message"
#    else
#        echo "Gagal: $message"  
#    fi
#
# 3. Parameter:
#    username     : Nama pengguna trojan (string, wajib)
#    hari/uuid    : Jika format UUID maka dianggap custom UUID, jika angka maka hari
#    hari         : Masa aktif dalam hari (integer, default: 30)
#    kuota_gb     : Kuota data dalam GB (integer, default: 0 unlimited)
#    ip_limit     : Batas maksimal IP yang bisa digunakan (integer, default: 2)
#
# 4. Return Value:
#    get_result_statustrojan() : "SUCCESS" atau "ERROR"
#    get_result_message_trojan() : Pesan detail hasil operasi
#    get_trojan_account_data() : Data lengkap akun dalam format key:value
#
# 5. Integrasi Telegram Bot:
#    Script akan otomatis mengirim notifikasi ke Telegram jika konfigurasi bot tersedia
#    Lokasi konfigurasi bot: /etc/telegram_bot/ atau /etc/bot/.bot.db
#
# 6. File yang Dimodifikasi:
#    - /etc/xray/config.json : Konfigurasi Xray
#    - /etc/trojan/.trojan.db : Database akun trojan
#    - /var/www/html/trojan-[username].txt : Config OpenClash
#    - /etc/kyt/limit/trojan/ip/[username] : IP limit
#    - /etc/trojan/[username] : Quota limit