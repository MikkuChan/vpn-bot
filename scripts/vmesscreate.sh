#!/bin/bash
# ─────────────※ ·❆· ※─────────────
# 𓈃 VMESS Bot Integration Functions
# 𓈃 Develovers ➠ MikkuChan
# 𓈃 Email      ➠ fadztechs2@gmail.com
# 𓈃 telegram   ➠ https://t.me/fadzdigital
# 𓈃 whatsapp   ➠ wa.me/+6285727035336
# ─────────────※ ·❆· ※─────────────

# ========================
# GLOBAL VARIABLES & COLORS
# ========================
RRED="\033[31m"
YELLOW="\033[33m"
NC='\e[0m'
YELL='\033[0;33m'
BRED='\033[1;31m'
GREEN='\033[0;32m'
ORANGE='\033[33m'
BGWHITE='\e[0;100;37m'
RED='\033[1;91m'
CYAN='\033[1;96m'
WHITE='\033[1;97m'
BLUE='\033[1;94m'

# Global variables untuk result
VMESS_STATUS=""
VMESS_MESSAGE=""
VMESS_DATA=""

# ========================
# POINT 1: VALIDASI SCRIPT
# ========================
validate_script() {
    local ipsaya=$(curl -sS ipv4.icanhazip.com 2>/dev/null)
    local data_server=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
    local date_list=$(date +"%Y-%m-%d" -d "$data_server")
    local data_ip="https://raw.githubusercontent.com/MikkuChan/instalasi/main/register"
    
    echo "$(date): Memvalidasi akses VPS dengan IP: $ipsaya" >> /var/log/vmess_bot.log
    
    local useexp=$(wget -qO- $data_ip 2>/dev/null | grep $ipsaya | awk '{print $3}')
    
    if [[ -z "$useexp" ]]; then
        echo "ERROR: IP $ipsaya tidak terdaftar dalam whitelist" >> /var/log/vmess_bot.log
        return 1
    fi
    
    if [[ $date_list < $useexp ]]; then
        echo "SUCCESS: IP $ipsaya valid sampai $useexp" >> /var/log/vmess_bot.log
        return 0
    else
        echo "ERROR: IP $ipsaya sudah expired pada $useexp" >> /var/log/vmess_bot.log
        return 1
    fi
}

# ========================
# POINT 2: FUNGSI CREATE VMESS
# ========================
create_vmess_bot() {
    local username="$1"
    local uuid_or_days="$2"
    local days_or_quota="$3"
    local quota_or_iplimit="$4"
    local iplimit_final="$5"
    
    # Deteksi parameter berdasarkan jumlah argument
    local uuid=""
    local days=""
    local quota=""
    local iplimit=""
    
    if [[ $# -eq 4 ]]; then
        # Format: username days quota iplimit (UUID random)
        uuid=$(cat /proc/sys/kernel/random/uuid)
        days="$uuid_or_days"
        quota="$days_or_quota"
        iplimit="$quota_or_iplimit"
    elif [[ $# -eq 5 ]]; then
        # Format: username uuid days quota iplimit (UUID custom)
        uuid="$uuid_or_days"
        days="$days_or_quota"
        quota="$quota_or_iplimit"
        iplimit="$iplimit_final"
    else
        echo "ERROR: Parameter tidak valid"
        return 1
    fi
    
    echo "$(date): Membuat akun VMESS - User: $username, Days: $days, Quota: ${quota}GB, IP Limit: $iplimit" >> /var/log/vmess_bot.log
    
    # Cek apakah user sudah ada
    local CLIENT_EXISTS=$(grep -w $username /etc/xray/config.json | wc -l)
    if [[ ${CLIENT_EXISTS} == '1' ]]; then
        echo "ERROR: Username $username sudah ada" >> /var/log/vmess_bot.log
        return 1
    fi
    
    # Dapatkan domain
    source /var/lib/kyt/ipvps.conf
    local domain=""
    if [[ "$IP" = "" ]]; then
        domain=$(cat /etc/xray/domain)
    else
        domain=$IP
    fi
    
    # Hitung tanggal expired
    local exp=$(date -d "$days days" +"%Y-%m-%d")
    local tgl=$(date -d "$days days" +"%d")
    local bln=$(date -d "$days days" +"%b")
    local thn=$(date -d "$days days" +"%Y")
    local expe="$tgl $bln, $thn"
    local tgl2=$(date +"%d")
    local bln2=$(date +"%b")
    local thn2=$(date +"%Y")
    local tnggl="$tgl2 $bln2, $thn2"
    
    # Update konfigurasi Xray
    update_xray_config "$username" "$uuid" "$exp"
    
    # Generate links VMESS
    local vmess_links=($(generate_vmess_links "$username" "$uuid" "$domain"))
    local vmesslink1="${vmess_links[0]}"
    local vmesslink2="${vmess_links[1]}"
    local vmesslink3="${vmess_links[2]}"
    
    # Management kuota dan IP limit
    manage_quota_and_ip "$username" "$quota" "$iplimit"
    
    # Update database
    update_database "$username" "$exp" "$uuid" "$quota" "$iplimit"
    
    # Buat file config OpenClash
    create_openclash_config "$username" "$uuid" "$domain" "$vmesslink1" "$vmesslink2" "$vmesslink3"
    
    # Restart services
    systemctl restart xray > /dev/null 2>&1
    systemctl restart nginx > /dev/null 2>&1
    
    # Set global variables untuk hasil
    VMESS_DATA=$(cat <<EOF
{
    "username": "$username",
    "uuid": "$uuid",
    "domain": "$domain",
    "expired_date": "$expe",
    "created_date": "$tnggl",
    "days": "$days",
    "quota": "$quota",
    "ip_limit": "$iplimit",
    "vmess_tls": "$vmesslink1",
    "vmess_ntls": "$vmesslink2",
    "vmess_grpc": "$vmesslink3",
    "openclash_url": "https://${domain}:81/vmess-$username.txt"
}
EOF
    )
    
    echo "SUCCESS: Akun VMESS $username berhasil dibuat" >> /var/log/vmess_bot.log
    return 0
}

# ========================
# POINT 3: UPDATE KONFIGURASI
# ========================
update_xray_config() {
    local username="$1"
    local uuid="$2"
    local exp="$3"
    
    echo "$(date): Mengupdate konfigurasi Xray untuk user $username" >> /var/log/vmess_bot.log
    
    # Update konfigurasi VMESS
    sed -i '/#vmess$/a\### '"$username $exp"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$username""'"' /etc/xray/config.json

    # Update konfigurasi VMESS gRPC
    sed -i '/#vmessgrpc$/a\### '"$username $exp"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$username""'"' /etc/xray/config.json
}

# ========================
# POINT 4: GENERATE LINKS
# ========================
generate_vmess_links() {
    local username="$1"
    local uuid="$2"
    local domain="$3"
    
    # VMESS WS TLS
    local asu=$(cat<<EOF
{
    "v": "2",
    "ps": "${username}",
    "add": "${domain}",
    "port": "443",
    "id": "${uuid}",
    "aid": "0",
    "net": "ws",
    "path": "/vmess",
    "type": "none",
    "host": "${domain}",
    "tls": "tls"
}
EOF
    )
    
    # VMESS WS Non-TLS
    local ask=$(cat<<EOF
{
    "v": "2",
    "ps": "${username}",
    "add": "${domain}",
    "port": "80",
    "id": "${uuid}",
    "aid": "0",
    "net": "ws",
    "path": "/vmess",
    "type": "none",
    "host": "${domain}",
    "tls": "none"
}
EOF
    )
    
    # VMESS gRPC
    local grpc=$(cat<<EOF
{
    "v": "2",
    "ps": "${username}",
    "add": "${domain}",
    "port": "443",
    "id": "${uuid}",
    "aid": "0",
    "net": "grpc",
    "path": "vmess-grpc",
    "type": "none",
    "host": "${domain}",
    "tls": "tls"
}
EOF
    )
    
    local vmesslink1="vmess://$(echo $asu | base64 -w 0)"
    local vmesslink2="vmess://$(echo $ask | base64 -w 0)"
    local vmesslink3="vmess://$(echo $grpc | base64 -w 0)"
    
    echo "$vmesslink1 $vmesslink2 $vmesslink3"
}

# ========================
# POINT 5: MANAGEMENT KUOTA & IP
# ========================
manage_quota_and_ip() {
    local username="$1"
    local quota="$2"
    local iplimit="$3"
    
    # Buat direktori jika belum ada
    if [ ! -e /etc/vmess ]; then
        mkdir -p /etc/vmess
    fi
    
    # Set IP limit
    if [[ $iplimit -gt 0 ]]; then
        mkdir -p /etc/kyt/limit/vmess/ip
        echo -e "$iplimit" > /etc/kyt/limit/vmess/ip/$username
        echo "$(date): Set IP limit $iplimit untuk user $username" >> /var/log/vmess_bot.log
    fi
    
    # Set kuota
    if [ -z ${quota} ]; then
        quota="0"
    fi
    
    local c=$(echo "${quota}" | sed 's/[^0-9]*//g')
    local d=$((${c} * 1024 * 1024 * 1024))
    
    if [[ ${c} != "0" ]]; then
        echo "${d}" >/etc/vmess/${username}
        echo "$(date): Set kuota ${quota}GB untuk user $username" >> /var/log/vmess_bot.log
    fi
}

# ========================
# POINT 6: DATABASE MANAGEMENT
# ========================
update_database() {
    local username="$1"
    local exp="$2"
    local uuid="$3"
    local quota="$4"
    local iplimit="$5"
    
    # Hapus entry lama jika ada
    local DATADB=$(cat /etc/vmess/.vmess.db | grep "^###" | grep -w "${username}" | awk '{print $2}')
    if [[ "${DATADB}" != '' ]]; then
        sed -i "/\b${username}\b/d" /etc/vmess/.vmess.db
    fi
    
    # Tambahkan entry baru
    echo "### ${username} ${exp} ${uuid} ${quota} ${iplimit}" >>/etc/vmess/.vmess.db
    echo "$(date): Database diupdate untuk user $username" >> /var/log/vmess_bot.log
}

# ========================
# POINT 7: FILE CONFIG OPENCLASH
# ========================
create_openclash_config() {
    local username="$1"
    local uuid="$2"
    local domain="$3"
    local vmesslink1="$4"
    local vmesslink2="$5"
    local vmesslink3="$6"
    
    cat >/var/www/html/vmess-$username.txt <<-END

           # FORMAT OpenClash #

# Format Vmess WS TLS

- name: Vmess-$username-WS TLS
  type: vmess
  server: ${domain}
  port: 443
  uuid: ${uuid}
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  skip-cert-verify: true
  servername: ${domain}
  network: ws
  ws-opts:
    path: /vmess
    headers:
      Host: ${domain}

# Format Vmess WS Non TLS

- name: Vmess-$username-WS Non TLS
  type: vmess
  server: ${domain}
  port: 80
  uuid: ${uuid}
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  skip-cert-verify: false
  servername: ${domain}
  network: ws
  ws-opts:
    path: /vmess
    headers:
      Host: ${domain}

# Format Vmess gRPC

- name: Vmess-$username-gRPC (SNI)
  server: ${domain}
  port: 443
  type: vmess
  uuid: ${uuid}
  alterId: 0
  cipher: auto
  network: grpc
  tls: true
  servername: ${domain}
  skip-cert-verify: true
  grpc-opts:
    grpc-service-name: vmess-grpc

              #  VMESS WS TLS #

${vmesslink1}

         # VMESS WS NON TLS #

${vmesslink2}

           # VMESS WS gRPC #

${vmesslink3}


END
    echo "$(date): File OpenClash dibuat untuk user $username" >> /var/log/vmess_bot.log
}

# ========================
# POINT 9: TELEGRAM NOTIFICATION
# ========================
send_telegram_notification() {
    local username="$1"
    local uuid="$2"
    local domain="$3"
    local quota="$4"
    local days="$5"
    local expe="$6"
    local tnggl="$7"
    local vmesslink1="$8"
    local vmesslink2="$9"
    local vmesslink3="${10}"
    
    # Ambil info sistem
    local location=$(curl -s ipinfo.io/json 2>/dev/null)
    local CITY=$(echo "$location" | jq -r '.city' 2>/dev/null)
    local ISP=$(echo "$location" | jq -r '.org' 2>/dev/null)
    local MYIP=$(curl -s ifconfig.me 2>/dev/null)
    
    # Set default values jika gagal ambil data
    CITY=${CITY:-"Tidak Diketahui"}
    ISP=${ISP:-"Tidak Diketahui"}
    MYIP=${MYIP:-"Tidak Diketahui"}
    
    # Ambil credentials Telegram
    local BOT_TOKEN=""
    local CHAT_ID=""
    
    if [[ -f /etc/telegram_bot/bot_token ]]; then
        BOT_TOKEN=$(cat /etc/telegram_bot/bot_token)
    fi
    
    if [[ -f /etc/telegram_bot/chat_id ]]; then
        CHAT_ID=$(cat /etc/telegram_bot/chat_id)
    fi
    
    # Fallback ke credential lama jika ada
    if [[ -z "$BOT_TOKEN" ]] || [[ -z "$CHAT_ID" ]]; then
        if [[ -f /etc/bot/.bot.db ]]; then
            CHAT_ID=$(grep -E "^#bot# " "/etc/bot/.bot.db" | cut -d ' ' -f 3)
            BOT_TOKEN=$(grep -E "^#bot# " "/etc/bot/.bot.db" | cut -d ' ' -f 2)
        fi
    fi
    
    if [[ -z "$BOT_TOKEN" ]] || [[ -z "$CHAT_ID" ]]; then
        echo "WARNING: Credentials Telegram tidak ditemukan" >> /var/log/vmess_bot.log
        return 1
    fi
    
    # Buat pesan
    local TEXT="───────────※ ·❆· ※───────────
<b>𓈃 CITY</b>: <code>$CITY</code>
<b>𓈃 ISP</b>: <code>$ISP</code>
<b>𓈃 IP</b>: <code>$MYIP</code>
───────────※ ·❆· ※───────────
   <b>𓈃 DETAIL AKUN VMESS 𓈃</b>
───────────※ ·❆· ※───────────
➠ <b>Remarks</b>   : <code>${username}</code>
➠ <b>Domain</b>    : <code>${domain}</code>
➠ <b>Limit Quota</b>: <code>${quota} GB</code>
➠ <b>Port TLS</b>  : 400-900
➠ <b>Port NTLS</b> : 80, 8080, 8081-9999
➠ <b>id</b>        : <code>${uuid}</code>
➠ <b>alterId</b>   : 0
➠ <b>Security</b>  : auto
➠ <b>network</b>   : ws or grpc
➠ <b>Path</b>      : /Multi-Path
➠ <b>Dynamic</b>   : https://bugmu.com/path
➠ <b>Name</b>      : vmess-grpc
───────────※ ·❆· ※───────────
      <b>𓈃 VMESS WS TLS 𓈃</b>
───────────※ ·❆· ※───────────
<pre>${vmesslink1}</pre>
───────────※ ·❆· ※───────────
   <b>𓈃 VMESS WS NON TLS 𓈃</b>
───────────※ ·❆· ※───────────
<pre>${vmesslink2}</pre>
───────────※ ·❆· ※───────────
      <b>𓈃 VMESS WS gRPC 𓈃</b>
───────────※ ·❆· ※───────────
<pre>${vmesslink3}</pre>
───────────※ ·❆· ※───────────
           <b>𓈃 FORMAT OpenClash 𓈃</b>
───────────※ ·❆· ※───────────
➠ https://${domain}:81/vmess-$username.txt
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
➠ <b>Aktif Selama</b> : $days Hari
➠ <b>Dibuat Pada</b>  : $tnggl
➠ <b>Berakhir Pada</b>: $expe
───────────※ ·❆· ※───────────
🤖 @085727035336"
    
    # Set global message untuk ambil hasil
    VMESS_MESSAGE="$TEXT"
    
    # URL API Telegram
    local URL="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"
    
    # Encode text untuk URL
    local TEXT_ENCODED=$(echo "$TEXT" | jq -sRr @uri 2>/dev/null)
    
    # Kirim pesan
    local RESPONSE=$(curl -s -d "chat_id=$CHAT_ID&disable_web_page_preview=1&text=$TEXT_ENCODED&parse_mode=html" "$URL" 2>/dev/null)
    
    echo "$(date): Pesan Telegram dikirim untuk user $username" >> /var/log/vmess_bot.log
    return 0
}

# ========================
# POINT 10: FUNGSI ORKESTRATOR UTAMA
# ========================
main_bot_create_vmess() {
    local username="$1"
    local param2="$2"
    local param3="$3"
    local param4="$4"
    local param5="$5"
    
    # Reset global variables
    VMESS_STATUS=""
    VMESS_MESSAGE=""
    VMESS_DATA=""
    
    echo "$(date): Memulai proses pembuatan akun VMESS..." >> /var/log/vmess_bot.log
    
    # Validasi script
    if ! validate_script; then
        VMESS_STATUS="FAILED"
        VMESS_MESSAGE="ERROR: VPS tidak memiliki izin akses. Hubungi administrator."
        echo "$(date): Validasi script gagal" >> /var/log/vmess_bot.log
        return 1
    fi
    
    # Buat akun VMESS
    if ! create_vmess_bot "$username" "$param2" "$param3" "$param4" "$param5"; then
        VMESS_STATUS="FAILED"
        VMESS_MESSAGE="ERROR: Gagal membuat akun VMESS. Periksa parameter atau username sudah ada."
        echo "$(date): Gagal membuat akun VMESS" >> /var/log/vmess_bot.log
        return 1
    fi
    
    # Parse data untuk notifikasi
    local uuid=$(echo "$VMESS_DATA" | grep '"uuid"' | cut -d'"' -f4)
    local domain=$(echo "$VMESS_DATA" | grep '"domain"' | cut -d'"' -f4)
    local expired_date=$(echo "$VMESS_DATA" | grep '"expired_date"' | cut -d'"' -f4)
    local created_date=$(echo "$VMESS_DATA" | grep '"created_date"' | cut -d'"' -f4)
    local days=$(echo "$VMESS_DATA" | grep '"days"' | cut -d'"' -f4)
    local quota=$(echo "$VMESS_DATA" | grep '"quota"' | cut -d'"' -f4)
    local vmess_tls=$(echo "$VMESS_DATA" | grep '"vmess_tls"' | cut -d'"' -f4)
    local vmess_ntls=$(echo "$VMESS_DATA" | grep '"vmess_ntls"' | cut -d'"' -f4)
    local vmess_grpc=$(echo "$VMESS_DATA" | grep '"vmess_grpc"' | cut -d'"' -f4)
    
    # Kirim notifikasi Telegram
    send_telegram_notification "$username" "$uuid" "$domain" "$quota" "$days" "$expired_date" "$created_date" "$vmess_tls" "$vmess_ntls" "$vmess_grpc"
    
    VMESS_STATUS="SUCCESS"
    echo "$(date): Akun VMESS berhasil dibuat dan notifikasi dikirim" >> /var/log/vmess_bot.log
    return 0
}

# ========================
# POINT 8: EXPORT FUNCTIONS UNTUK BOT
# ========================

# Fungsi untuk mengambil status hasil
get_result_statusvmess() {
    echo "$VMESS_STATUS"
}

# Fungsi untuk mengambil pesan hasil
get_result_message_vmess() {
    echo "$VMESS_MESSAGE"
}

# Fungsi untuk mengambil data lengkap hasil
get_result_data_vmess() {
    echo "$VMESS_DATA"
}

# Export functions agar bisa dipanggil dari script lain
export -f validate_script
export -f create_vmess_bot
export -f update_xray_config
export -f generate_vmess_links
export -f manage_quota_and_ip
export -f update_database
export -f create_openclash_config
export -f send_telegram_notification
export -f main_bot_create_vmess
export -f get_result_statusvmess
export -f get_result_message_vmess
export -f get_result_data_vmess

# ========================
# POINT 11: CLI INTERFACE
# ========================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script dipanggil langsung, bukan di-source
    case "$1" in
        "create")
            if [[ $# -eq 5 ]]; then
                # Format: ./vmess_bot.sh create username123 30 10 2
                main_bot_create_vmess "$2" "$3" "$4" "$5"
            elif [[ $# -eq 6 ]]; then
                # Format: ./vmess_bot.sh create username123 uuid-custom 30 10 2
                main_bot_create_vmess "$2" "$3" "$4" "$5" "$6"
            else
                echo "Usage:"
                echo "  $0 create <username> <days> <quota_gb> <ip_limit>"
                echo "  $0 create <username> <custom_uuid> <days> <quota_gb> <ip_limit>"
                echo ""
                echo "Contoh:"
                echo "  $0 create user123 30 10 2"
                echo "  $0 create user123 550e8400-e29b-41d4-a716-446655440000 30 10 2"
                exit 1
            fi
            
            # Tampilkan hasil
            echo "Status: $(get_result_statusvmess)"
            if [[ "$(get_result_statusvmess)" == "SUCCESS" ]]; then
                echo "Akun berhasil dibuat!"
                echo ""
                echo "Data akun:"
                get_result_data_vmess | jq .
            else
                echo "Error: $(get_result_message_vmess)"
            fi
            ;;
        *)
            echo "Usage: $0 create <parameters>"
            echo "Gunakan '$0 create' untuk melihat detail parameter"
            ;;
    esac
fi

# ========================
# DOKUMENTASI PENGGUNAAN
# ========================

# 1. CLI Interface:
#    Jalankan script langsung dari command line:
#    ./vmess_bot.sh create username123 30 10 2
#    ./vmess_bot.sh create username123 uuid-custom 30 10 2

# 2. Import ke script lain:
#    source /path/to/vmess_bot.sh
#    main_bot_create_vmess "username123" "30" "10" "2"
#    status=$(get_result_statusvmess)
#    message=$(get_result_message_vmess)
#    data=$(get_result_data_vmess)

# 3. Parameter:
#    Format 1 (UUID random): username days quota ip_limit
#    Format 2 (UUID custom): username uuid days quota ip_limit
#    - username: nama user (string)
#    - uuid: UUID custom (string, optional)
#    - days: masa aktif dalam hari (integer)
#    - quota: kuota data dalam GB (integer)
#    - ip_limit: batas jumlah IP (integer)

# 4. Return Value:
#    - get_result_statusvmess(): "SUCCESS" atau "FAILED"
#    - get_result_message_vmess(): pesan detail (string)
#    - get_result_data_vmess(): data akun dalam format JSON (string)

# Log file: /var/log/vmess_bot.log
# Config files: /etc/xray/config.json, /etc/vmess/.vmess.db
# Web files: /var/www/html/vmess-{username}.txt