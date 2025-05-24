#!/bin/bash
# ───────────────※ ·❆· ※───────────────
# 𓈃 VLESS Bot Creator - Function Based
# 𓈃 Develovers ➠ MikkuChan  
# 𓈃 Email      ➠ fadztechs2@gmail.com
# 𓈃 telegram   ➠ https://t.me/fadzdigital
# 𓈃 whatsapp   ➠ wa.me/+6285727035336
# ───────────────※ ·❆· ※───────────────

# ════════════════════════════════════════════════════════════════════════════════
# KONFIGURASI WARNA DAN VARIABEL GLOBAL
# ════════════════════════════════════════════════════════════════════════════════

RED="\033[31m"
YELLOW="\033[33m"
NC='\e[0m'
YELL='\033[0;33m'
BRED='\033[1;31m'
GREEN='\033[0;32m'
ORANGE='\033[33m'
BGWHITE='\e[0;100;37m'
CYAN='\033[1;96m'
WHITE='\033[1;97m'

# Variabel global untuk menyimpan hasil
VLESS_STATUS=""
VLESS_MESSAGE=""
VLESS_DATA=""

# ════════════════════════════════════════════════════════════════════════════════
# FUNGSI UTILITAS
# ════════════════════════════════════════════════════════════════════════════════

# Fungsi untuk menampilkan loading animation
loading() {
    local message="$1"
    echo -e "⏳ ${YELLOW}$message...${NC}"
    sleep 1
    echo -e "✅ ${GREEN}$message Selesai!${NC}"
}

# Fungsi untuk mendapatkan informasi IP dan lokasi
get_system_info() {
    MYIP=$(curl -sS ipv4.icanhazip.com 2>/dev/null || echo "Unknown")
    
    # Ambil informasi lokasi
    local location=$(curl -s ipinfo.io/json 2>/dev/null)
    if [ -n "$location" ]; then
        CITY=$(echo "$location" | jq -r '.city' 2>/dev/null || echo "Unknown")
        ISP=$(echo "$location" | jq -r '.org' 2>/dev/null || echo "Unknown")
    else
        CITY="Unknown"
        ISP="Unknown"
    fi
    
    # Fallback jika kosong
    CITY=${CITY:-"Unknown"}
    ISP=${ISP:-"Unknown"}
}

# ════════════════════════════════════════════════════════════════════════════════
# POINT 1: VALIDASI SCRIPT
# ════════════════════════════════════════════════════════════════════════════════

validate_script() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
    echo -e "🔄 ${WHITE}MEMERIKSA PERMISSION VPS...${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
    
    loading "Mengambil IP VPS"
    local ipsaya=$(curl -sS ipv4.icanhazip.com 2>/dev/null)
    
    if [ -z "$ipsaya" ]; then
        echo -e "${RED}❌ Gagal mendapatkan IP VPS${NC}"
        return 1
    fi
    
    loading "Mengambil Data Server"
    local data_server=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
    local date_list=$(date +"%Y-%m-%d" -d "$data_server" 2>/dev/null || date +"%Y-%m-%d")
    local data_ip="https://raw.githubusercontent.com/MikkuChan/instalasi/main/register"
    
    # Cek permission dari remote server
    local useexp=$(wget -qO- $data_ip 2>/dev/null | grep $ipsaya | awk '{print $3}')
    
    if [[ $date_list < $useexp ]] 2>/dev/null; then
        echo -e "✅ ${GREEN}Permission Valid${NC}"
        return 0
    else
        echo -e "${RED}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
        echo -e "❌ ${WHITE}PERMISSION DENIED!${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
        echo -e "🚫 VPS Anda: $ipsaya"
        echo -e "💀 Status: ${RED}Diblokir${NC}"
        echo -e ""
        echo -e "📌 Hubungi admin untuk membeli akses."
        echo -e "${RED}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════════════════════
# POINT 2: FUNGSI CREATE VLESS
# ════════════════════════════════════════════════════════════════════════════════

create_vless_bot() {
    local username="$1"
    local uuid_or_days="$2"  # Bisa UUID custom atau hari
    local days="$3"          # Jika ada UUID custom, ini adalah hari
    local quota="$4"         # Kuota dalam GB
    local iplimit="$5"       # Batas IP
    
    # Deteksi apakah parameter kedua adalah UUID atau hari
    local uuid=""
    local masaaktif=""
    
    # Cek format UUID (36 karakter dengan dash)
    if [[ ${#uuid_or_days} -eq 36 && "$uuid_or_days" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        # Parameter kedua adalah UUID custom
        uuid="$uuid_or_days"
        masaaktif="$days"
        quota="$4"
        iplimit="$5"
    else
        # Parameter kedua adalah hari
        masaaktif="$uuid_or_days"
        quota="$days"
        iplimit="$4"
        # Generate UUID random
        uuid=$(cat /proc/sys/kernel/random/uuid)
    fi
    
    # Validasi parameter
    if [ -z "$username" ] || [ -z "$masaaktif" ]; then
        echo -e "${RED}❌ Parameter tidak lengkap${NC}"
        echo -e "Usage: create_vless_bot username days [quota] [iplimit]"
        echo -e "   atau: create_vless_bot username uuid days [quota] [iplimit]"
        VLESS_STATUS="error"
        VLESS_MESSAGE="Parameter tidak lengkap"
        return 1
    fi
    
    # Set default values
    quota=${quota:-0}
    iplimit=${iplimit:-0}
    
    # Baca domain dari konfigurasi
    local domain=$(cat /etc/xray/domain 2>/dev/null)
    if [ -z "$domain" ]; then
        echo -e "${RED}❌ Domain tidak ditemukan di /etc/xray/domain${NC}"
        VLESS_STATUS="error"
        VLESS_MESSAGE="Domain tidak ditemukan"
        return 1
    fi
    
    # Cek apakah user sudah ada
    local client_exists=$(grep -w $username /etc/xray/config.json | wc -l)
    if [[ ${client_exists} == '1' ]]; then
        echo -e "${RED}❌ Username '$username' sudah ada${NC}"
        VLESS_STATUS="error"
        VLESS_MESSAGE="Username sudah ada"
        return 1
    fi
    
    echo -e "${GREEN}✅ Membuat akun VLESS untuk: $username${NC}"
    return 0
}

# ════════════════════════════════════════════════════════════════════════════════
# POINT 3: UPDATE KONFIGURASI
# ════════════════════════════════════════════════════════════════════════════════

update_xray_config() {
    local username="$1"
    local uuid="$2"
    local exp="$3"
    
    echo -e "${CYAN}🔧 Memperbarui konfigurasi Xray...${NC}"
    
    # Backup konfigurasi
    cp /etc/xray/config.json /etc/xray/config.json.bak
    
    # Update konfigurasi VLESS WS
    sed -i '/#vless$/a\#& '"$username $exp"'\
},{"id": "'""$uuid""'","email" : "'""$username""'"' /etc/xray/config.json
    
    # Update konfigurasi VLESS gRPC
    sed -i '/#vlessgrpc$/a\#& '"$username $exp"'\
},{"id": "'""$uuid""'","email" : "'""$username""'"' /etc/xray/config.json
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Konfigurasi Xray berhasil diperbarui${NC}"
        return 0
    else
        echo -e "${RED}❌ Gagal memperbarui konfigurasi Xray${NC}"
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════════════════════
# POINT 4: GENERATE LINKS
# ════════════════════════════════════════════════════════════════════════════════

generate_vless_links() {
    local username="$1"
    local uuid="$2"
    local domain="$3"
    
    # Generate 3 jenis link VLESS
    local vlesslink1="vless://${uuid}@bugmu.com:443/?type=ws&encryption=none&host=${domain}&path=%2Fvless&security=tls&sni=${domain}&fp=randomized#${username}"
    local vlesslink2="vless://${uuid}@bugmu.com:80/?type=ws&encryption=none&host=${domain}&path=%2Fvless#${username}"
    local vlesslink3="vless://${uuid}@bugmu.com:443/?type=grpc&encryption=none&flow=&serviceName=vless-grpc&security=tls&sni=${domain}#${username}"
    
    # Export ke variabel global
    VLESS_LINK_TLS="$vlesslink1"
    VLESS_LINK_NTLS="$vlesslink2"
    VLESS_LINK_GRPC="$vlesslink3"
    
    echo -e "${GREEN}✅ Link VLESS berhasil di-generate${NC}"
}

# ════════════════════════════════════════════════════════════════════════════════
# POINT 5: MANAGEMENT KUOTA & IP
# ════════════════════════════════════════════════════════════════════════════════

setup_quota_limit() {
    local username="$1"
    local quota="$2"
    local iplimit="$3"
    
    echo -e "${CYAN}📊 Mengatur batas kuota dan IP...${NC}"
    
    # Setup IP Limit
    if [[ $iplimit -gt 0 ]]; then
        mkdir -p /etc/kyt/limit/vless/ip
        echo -e "$iplimit" > /etc/kyt/limit/vless/ip/$username
        echo -e "${GREEN}✅ IP Limit: $iplimit${NC}"
    fi
    
    # Setup Quota Limit
    if [ -z ${quota} ]; then
        quota="0"
    fi
    
    local c=$(echo "${quota}" | sed 's/[^0-9]*//g')
    local d=$((${c} * 1024 * 1024 * 1024))
    
    if [[ ${c} != "0" ]]; then
        mkdir -p /etc/vless
        echo "${d}" > /etc/vless/${username}
        echo -e "${GREEN}✅ Quota Limit: $quota GB${NC}"
    fi
}

# ════════════════════════════════════════════════════════════════════════════════
# POINT 6: DATABASE MANAGEMENT
# ════════════════════════════════════════════════════════════════════════════════

update_vless_database() {
    local username="$1"
    local exp="$2"
    local uuid="$3"
    local quota="$4"
    local iplimit="$5"
    
    echo -e "${CYAN}💾 Memperbarui database VLESS...${NC}"
    
    # Buat direktori jika belum ada
    mkdir -p /etc/vless
    
    # Buat file database jika belum ada
    if [ ! -f /etc/vless/.vless.db ]; then
        touch /etc/vless/.vless.db
    fi
    
    # Hapus entry lama jika ada
    local datadb=$(cat /etc/vless/.vless.db | grep "^###" | grep -w "${username}" | awk '{print $2}')
    if [[ "${datadb}" != '' ]]; then
        sed -i "/\b${username}\b/d" /etc/vless/.vless.db
    fi
    
    # Tambahkan entry baru
    echo "### ${username} ${exp} ${uuid} ${quota} ${iplimit}" >> /etc/vless/.vless.db
    
    echo -e "${GREEN}✅ Database VLESS berhasil diperbarui${NC}"
}

# ════════════════════════════════════════════════════════════════════════════════
# POINT 7: FILE CONFIG OPENCLASH
# ════════════════════════════════════════════════════════════════════════════════

create_openclash_config() {
    local username="$1"
    local uuid="$2"
    local domain="$3"
    
    echo -e "${CYAN}📝 Membuat konfigurasi OpenClash...${NC}"
    
    # Buat direktori web jika belum ada
    mkdir -p /var/www/html
    
    # Buat file konfigurasi OpenClash
    cat > /var/www/html/vless-$username.txt <<-END

       # FORMAT OpenClash #

   # FORMAT VLESS WS TLS #

- name: Vless-$username-WS TLS
  server: bugmu.com
  port: 443
  type: vless
  uuid: ${uuid}
  cipher: auto
  tls: true
  skip-cert-verify: true
  servername: ${domain}
  network: ws
  ws-opts:
    path: /vless
    headers:
      Host: ${domain}
  udp: true

# FORMAT VLESS WS NON TLS #

- name: Vless-$username-WS (CDN) Non TLS
  server: bugmu.com
  port: 80
  type: vless
  uuid: ${uuid}
  cipher: auto
  tls: false
  skip-cert-verify: false
  servername: ${domain}
  network: ws
  ws-opts:
    path: /vless
    headers:
      Host: ${domain}
  udp: true

     # FORMAT VLESS gRPC #

- name: Vless-$username-gRPC (SNI)
  server: ${domain}
  port: 443
  type: vless
  uuid: ${uuid}
  cipher: auto
  tls: true
  skip-cert-verify: true
  servername: ${domain}
  network: grpc
  grpc-opts:
    grpc-service-name: vless-grpc
  udp: true

           # VLESS WS TLS #
           
${VLESS_LINK_TLS}

      # VLESS WS NON TLS #

${VLESS_LINK_NTLS}

         # VLESS WS gRPC #

${VLESS_LINK_GRPC}

END

    echo -e "${GREEN}✅ Konfigurasi OpenClash berhasil dibuat${NC}"
    echo -e "${GREEN}📁 File: /var/www/html/vless-$username.txt${NC}"
}

# ════════════════════════════════════════════════════════════════════════════════
# POINT 8: RETURN DATA
# ════════════════════════════════════════════════════════════════════════════════

format_account_data() {
    local username="$1"
    local uuid="$2"
    local domain="$3"
    local quota="$4"
    local iplimit="$5"
    local masaaktif="$6"
    local tnggl="$7"
    local expe="$8"
    
    # Format data akun untuk return
    VLESS_DATA=$(cat <<EOF
{
    "username": "$username",
    "uuid": "$uuid",
    "domain": "$domain",
    "quota": "$quota",
    "iplimit": "$iplimit",
    "active_days": "$masaaktif",
    "created_date": "$tnggl",
    "expire_date": "$expe",
    "links": {
        "ws_tls": "$VLESS_LINK_TLS",
        "ws_ntls": "$VLESS_LINK_NTLS",
        "grpc": "$VLESS_LINK_GRPC"
    },
    "openclash_url": "https://${domain}:81/vless-$username.txt"
}
EOF
)
}

# ════════════════════════════════════════════════════════════════════════════════
# POINT 9: TELEGRAM NOTIFICATION
# ════════════════════════════════════════════════════════════════════════════════

send_telegram_notification() {
    local username="$1"
    local uuid="$2"
    local domain="$3"
    local quota="$4" 
    local iplimit="$5"
    local masaaktif="$6"
    local tnggl="$7"
    local expe="$8"
    
    echo -e "${CYAN}📱 Mengirim notifikasi Telegram...${NC}"
    
    # Ambil kredensial Telegram
    local bot_token=""
    local chat_id=""
    
    if [ -f "/etc/telegram_bot/bot_token" ]; then
        bot_token=$(cat /etc/telegram_bot/bot_token)
    fi
    
    if [ -f "/etc/telegram_bot/chat_id" ]; then
        chat_id=$(cat /etc/telegram_bot/chat_id)
    fi
    
    # Fallback ke konfigurasi lama jika ada
    if [ -z "$bot_token" ] || [ -z "$chat_id" ]; then
        if [ -f "/etc/bot/.bot.db" ]; then
            chat_id=$(grep -E "^#bot# " "/etc/bot/.bot.db" | cut -d ' ' -f 3)
            bot_token=$(grep -E "^#bot# " "/etc/bot/.bot.db" | cut -d ' ' -f 2)
        fi
    fi
    
    if [ -z "$bot_token" ] || [ -z "$chat_id" ]; then
        echo -e "${YELLOW}⚠️ Kredensial Telegram tidak ditemukan, melewati notifikasi${NC}"
        return 0
    fi
    
    # Ambil info sistem
    get_system_info
    
    # Format pesan Telegram
    local text="───────────※ ·❆· ※───────────
<b>𓈃 CITY</b>: <code>$CITY</code>
<b>𓈃 ISP</b>: <code>$ISP</code>
<b>𓈃 IP</b>: <code>$MYIP</code>
───────────※ ·❆· ※───────────
           <b>𓈃 DETAIL AKUN VLESS 𓈃</b>
───────────※ ·❆· ※───────────
➠ <b>Remarks</b>   : <code>${username}</code>
➠ <b>Domain</b>    : <code>${domain}</code>
➠ <b>Limit Quota</b>: <code>${quota} GB</code>
➠ <b>Limit IP</b>  : <code>${iplimit} IP</code>
➠ <b>Port TLS</b>  : 400-900
➠ <b>Port NTLS</b> : 80, 8080, 8081-9999
➠ <b>UUID</b>      : <code>${uuid}</code>
➠ <b>alterId</b>   : 0
➠ <b>Security</b>  : auto
➠ <b>network</b>   : ws or grpc
➠ <b>Path</b>      : /Multi-Path
➠ <b>Dynamic</b>   : https://bugmu.com/path
➠ <b>Name</b>      : vless-grpc
───────────※ ·❆· ※───────────
              <b>𓈃 VLESS WS TLS 𓈃</b>
───────────※ ·❆· ※───────────
<pre>${VLESS_LINK_TLS}</pre>
───────────※ ·❆· ※───────────
              <b>𓈃 VLESS WS NON TLS 𓈃</b>
───────────※ ·❆· ※───────────
<pre>${VLESS_LINK_NTLS}</pre>
───────────※ ·❆· ※───────────
              <b>𓈃 VLESS WS gRPC 𓈃</b>
───────────※ ·❆· ※───────────
<pre>${VLESS_LINK_GRPC}</pre>
───────────※ ·❆· ※───────────
           <b>𓈃 FORMAT OpenClash 𓈃</b>
───────────※ ·❆· ※───────────
➠ https://${domain}:81/vless-$username.txt
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
➠ <b>Aktif Selama</b> : $masaaktif Hari
➠ <b>Dibuat Pada</b>  : $tnggl
➠ <b>Berakhir Pada</b>: $expe
───────────※ ·❆· ※───────────
🤖 @085727035336"
    
    # Simpan pesan ke variabel global
    VLESS_MESSAGE="$text"
    
    # Encode text untuk URL
    local text_encoded=$(echo "$text" | jq -sRr @uri 2>/dev/null || python3 -c "import urllib.parse; print(urllib.parse.quote('''$text'''))" 2>/dev/null)
    
    # URL API Telegram
    local url="https://api.telegram.org/bot$bot_token/sendMessage"
    
    # Kirim pesan ke Telegram
    local response=$(curl -s -d "chat_id=$chat_id&disable_web_page_preview=1&text=$text_encoded&parse_mode=html" "$url" 2>/dev/null)
    
    # Cek respons
    if echo "$response" | grep -q '"ok":true'; then
        echo -e "${GREEN}✅ Notifikasi Telegram berhasil dikirim${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️ Gagal mengirim notifikasi Telegram${NC}"
        echo -e "${YELLOW}Response: $response${NC}"
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════════════════════
# POINT 10: FUNGSI ORKESTRATOR UTAMA
# ════════════════════════════════════════════════════════════════════════════════

main_bot_create_vless() {
    local username="$1"
    local uuid_or_days="$2"
    local days="$3"
    local quota="$4"
    local iplimit="$5"
    
    echo -e "${CYAN}🚀 Memulai pembuatan akun VLESS...${NC}"
    
    # Reset status global
    VLESS_STATUS=""
    VLESS_MESSAGE=""
    VLESS_DATA=""
    
    # STEP 1: Validasi Script
    if ! validate_script; then
        VLESS_STATUS="error"
        VLESS_MESSAGE="Validasi script gagal"
        return 1
    fi
    
    # STEP 2: Deteksi parameter UUID
    local uuid=""
    local masaaktif=""
    
    if [[ ${#uuid_or_days} -eq 36 && "$uuid_or_days" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        uuid="$uuid_or_days"
        masaaktif="$days"
        quota="$4"
        iplimit="$5"
    else
        masaaktif="$uuid_or_days"
        quota="$days"
        iplimit="$4"
        uuid=$(cat /proc/sys/kernel/random/uuid)
    fi
    
    # Set default values
    quota=${quota:-0}
    iplimit=${iplimit:-0}
    
    # STEP 3: Validasi dan buat akun
    if ! create_vless_bot "$username" "$uuid_or_days" "$days" "$quota" "$iplimit"; then
        return 1
    fi
    
    # STEP 4: Ambil domain
    local domain=$(cat /etc/xray/domain 2>/dev/null)
    if [ -z "$domain" ]; then
        VLESS_STATUS="error"
        VLESS_MESSAGE="Domain tidak ditemukan"
        return 1
    fi
    
    # STEP 5: Hitung tanggal
    local tgl=$(date -d "$masaaktif days" +"%d")
    local bln=$(date -d "$masaaktif days" +"%b")
    local thn=$(date -d "$masaaktif days" +"%Y")
    local expe="$tgl $bln, $thn"
    local tgl2=$(date +"%d")
    local bln2=$(date +"%b")
    local thn2=$(date +"%Y")
    local tnggl="$tgl2 $bln2, $thn2"
    local exp=$(date -d "$masaaktif days" +"%Y-%m-%d")
    
    # STEP 6: Update konfigurasi Xray
    if ! update_xray_config "$username" "$uuid" "$exp"; then
        VLESS_STATUS="error"
        VLESS_MESSAGE="Gagal memperbarui konfigurasi Xray"
        return 1
    fi
    
    # STEP 7: Generate links
    generate_vless_links "$username" "$uuid" "$domain"
    
    # STEP 8: Setup quota dan IP limit
    setup_quota_limit "$username" "$quota" "$iplimit"
    
    # STEP 9: Update database
    update_vless_database "$username" "$exp" "$uuid" "$quota" "$iplimit"
    
    # STEP 10: Buat konfigurasi OpenClash
    create_openclash_config "$username" "$uuid" "$domain"
    
    # STEP 11: Format data akun
    format_account_data "$username" "$uuid" "$domain" "$quota" "$iplimit" "$masaaktif" "$tnggl" "$expe"
    
    # STEP 12: Kirim notifikasi Telegram
    send_telegram_notification "$username" "$uuid" "$domain" "$quota" "$iplimit" "$masaaktif" "$tnggl" "$expe"
    
    # STEP 13: Restart services
    echo -e "${CYAN}🔄 Restart layanan...${NC}"
    systemctl restart xray >/dev/null 2>&1
    systemctl restart nginx >/dev/null 2>&1
    
    # Set status sukses
    VLESS_STATUS="success"
    
    echo -e "${GREEN}✅ Akun VLESS '$username' berhasil dibuat!${NC}"
    return 0
}

# ════════════════════════════════════════════════════════════════════════════════
# FUNGSI UNTUK MENGAMBIL HASIL
# ════════════════════════════════════════════════════════════════════════════════

# Fungsi untuk mendapatkan status pembuatan akun
get_result_statusvless() {
    echo "$VLESS_STATUS"
}

# Fungsi untuk mendapatkan pesan Telegram
get_result_message_vless() {
    echo "$VLESS_MESSAGE"
}

# Fungsi untuk mendapatkan data lengkap akun
get_result_data_vless() {
    echo "$VLESS_DATA"
}

# ════════════════════════════════════════════════════════════════════════════════
# EXPORT FUNCTIONS UNTUK BOT
# ════════════════════════════════════════════════════════════════════════════════

# Export semua fungsi agar bisa dipanggil dari script lain
export -f validate_script
export -f create_vless_bot
export -f update_xray_config
export -f generate_vless_links
export -f setup_quota_limit
export -f update_vless_database
export -f create_openclash_config
export -f format_account_data
export -f send_telegram_notification
export -f main_bot_create_vless
export -f get_result_statusvless
export -f get_result_message_vless
export -f get_result_data_vless
export -f get_system_info
export -f loading

# ════════════════════════════════════════════════════════════════════════════════
# POINT 11: CLI INTERFACE
# ════════════════════════════════════════════════════════════════════════════════

# Fungsi untuk menampilkan bantuan
show_help() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}🔧 VLESS Bot Creator - CLI Interface${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
    echo -e ""
    echo -e "${YELLOW}📋 PENGGUNAAN:${NC}"
    echo -e "  $0 create <username> <hari> [kuota_gb] [limit_ip]"
    echo -e "  $0 create <username> <uuid_custom> <hari> [kuota_gb] [limit_ip]"
    echo -e "  $0 validate    # Cek permission VPS"
    echo -e "  $0 help        # Tampilkan bantuan ini"
    echo -e ""
    echo -e "${YELLOW}📝 CONTOH:${NC}"
    echo -e "  $0 create user123 30 10 2"
    echo -e "  $0 create user123 12345678-1234-1234-1234-123456789012 30 10 2"
    echo -e ""
    echo -e "${YELLOW}📄 PARAMETER:${NC}"
    echo -e "  username    : Nama pengguna (wajib)"
    echo -e "  hari        : Masa aktif dalam hari (wajib)"
    echo -e "  uuid_custom : UUID custom (opsional, format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)"
    echo -e "  kuota_gb    : Kuota dalam GB (default: 0 = unlimited)"
    echo -e "  limit_ip    : Batas IP bersamaan (default: 0 = unlimited)"
    echo -e ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
}

# Fungsi untuk menampilkan hasil
show_result() {
    local status=$(get_result_statusvless)
    local message=$(get_result_message_vless)
    local data=$(get_result_data_vless)
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}📊 HASIL PEMBUATAN AKUN${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
    
    if [ "$status" = "success" ]; then
        echo -e "${GREEN}✅ Status: BERHASIL${NC}"
        echo -e ""
        echo -e "${WHITE}📱 Pesan Telegram:${NC}"
        echo -e "$message"
        echo -e ""
        echo -e "${WHITE}📊 Data JSON:${NC}"
        echo -e "$data"
    else
        echo -e "${RED}❌ Status: GAGAL${NC}"
        echo -e "${RED}💬 Pesan: $message${NC}"
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
}

# Handler untuk CLI
handle_cli() {
    case "$1" in
        "create")
            if [ $# -lt 3 ]; then
                echo -e "${RED}❌ Parameter tidak lengkap${NC}"
                show_help
                exit 1
            fi
            
            local username="$2"
            local param2="$3"
            local param3="$4"
            local param4="$5"
            local param5="$6"
            
            echo -e "${CYAN}🚀 Memulai pembuatan akun VLESS...${NC}"
            echo -e "${CYAN}👤 Username: $username${NC}"
            
            # Panggil fungsi utama
            if main_bot_create_vless "$username" "$param2" "$param3" "$param4" "$param5"; then
                show_result
                exit 0
            else
                show_result
                exit 1
            fi
            ;;
        "validate")
            echo -e "${CYAN}🔍 Memvalidasi permission VPS...${NC}"
            if validate_script; then
                echo -e "${GREEN}✅ VPS memiliki permission yang valid${NC}"
                exit 0
            else
                echo -e "${RED}❌ VPS tidak memiliki permission${NC}"
                exit 1
            fi
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
}

# ════════════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ════════════════════════════════════════════════════════════════════════════════

# Jika script dipanggil langsung (bukan di-source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Cek apakah ada argumen
    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi
    
    # Handle CLI
    handle_cli "$@"
fi

# ════════════════════════════════════════════════════════════════════════════════
# DOKUMENTASI PENGGUNAAN
# ════════════════════════════════════════════════════════════════════════════════

<<'DOCUMENTATION'

# ══════════════════════════════════════════════════════════════════════
# 📚 DOKUMENTASI PENGGUNAAN VLESS BOT CREATOR
# ══════════════════════════════════════════════════════════════════════

## 1. CLI INTERFACE:

### Membuat akun dengan UUID random:
./vless_bot.sh create username123 30 10 2
./vless_bot.sh create testuser 7 5 1

### Membuat akun dengan UUID custom:
./vless_bot.sh create username123 12345678-1234-1234-1234-123456789012 30 10 2

### Validasi permission VPS:
./vless_bot.sh validate

### Tampilkan bantuan:
./vless_bot.sh help

## 2. IMPORT KE SCRIPT LAIN:

```bash
#!/bin/bash
# Import fungsi dari vless_bot.sh
source /path/to/vless_bot.sh

# Buat akun VLESS
main_bot_create_vless "username123" "30" "10" "2"

# Ambil hasil
status=$(get_result_statusvless)
message=$(get_result_message_vless)
data=$(get_result_data_vless)

# Cek status
if [ "$status" = "success" ]; then
    echo "Akun berhasil dibuat!"
    echo "Pesan Telegram: $message"
    echo "Data JSON: $data"
else
    echo "Gagal membuat akun: $message"
fi
```

## 3. PARAMETER:

### Fungsi: main_bot_create_vless
- Parameter 1: username (string, wajib)
- Parameter 2: hari atau uuid_custom (string, wajib)
- Parameter 3: hari (jika param2 adalah uuid) atau kuota_gb (integer, opsional)
- Parameter 4: kuota_gb atau limit_ip (integer, opsional)
- Parameter 5: limit_ip (integer, opsional)

### UUID Custom Format:
- Harus 36 karakter
- Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
- Contoh: 12345678-1234-1234-1234-123456789012

### Default Values:
- kuota_gb: 0 (unlimited)
- limit_ip: 0 (unlimited)

## 4. RETURN VALUE:

### get_result_statusvless():
- "success": Akun berhasil dibuat
- "error": Akun gagal dibuat
- "": Belum ada proses yang dijalankan

### get_result_message_vless():
Mengembalikan pesan lengkap yang dikirim ke Telegram dalam format HTML.
Berisi informasi detail akun, link VLESS, dan konfigurasi.

### get_result_data_vless():
Mengembalikan data akun dalam format JSON dengan struktur:
```json
{
    "username": "string",
    "uuid": "string", 
    "domain": "string",
    "quota": "string",
    "iplimit": "string",
    "active_days": "string",
    "created_date": "string",
    "expire_date": "string",
    "links": {
        "ws_tls": "string",
        "ws_ntls": "string", 
        "grpc": "string"
    },
    "openclash_url": "string"
}
```

## 5. FILE YANG DIHASILKAN:

### Database:
- /etc/vless/.vless.db: Database akun VLESS
- /etc/vless/[username]: File kuota per user (jika ada)
- /etc/kyt/limit/vless/ip/[username]: File limit IP per user (jika ada)

### Konfigurasi:
- /etc/xray/config.json: Konfigurasi Xray (diupdate)
- /var/www/html/vless-[username].txt: File konfigurasi OpenClash

### Log:
- /var/log/telegram_debug.log: Log debug Telegram (jika ada)
- /etc/user-create/user.log: Log pembuatan user (jika ada)

## 6. PERSYARATAN SISTEM:

### File yang harus ada:
- /etc/xray/domain: File berisi domain
- /etc/xray/config.json: Konfigurasi Xray
- /etc/telegram_bot/bot_token: Token bot Telegram (opsional)
- /etc/telegram_bot/chat_id: Chat ID Telegram (opsional)

### Command yang diperlukan:
- curl: Untuk HTTP request
- jq: Untuk parsing JSON (opsional)
- systemctl: Untuk restart service
- date: Untuk kalkulasi tanggal

## 7. TROUBLESHOOTING:

### Error "Domain tidak ditemukan":
- Pastikan file /etc/xray/domain ada dan berisi domain yang valid

### Error "Permission denied":
- IP VPS tidak terdaftar di whitelist
- Hubungi admin untuk registrasi IP

### Error "Username sudah ada":
- Pilih username yang berbeda
- Atau hapus akun lama terlebih dahulu

### Telegram tidak terkirim:
- Periksa file kredensial Telegram
- Pastikan bot token dan chat ID valid
- Cek koneksi internet

## 8. CONTOH INTEGRASI BOT WHATSAPP/TELEGRAM:

```bash
#!/bin/bash
source /path/to/vless_bot.sh

# Handler pesan dari bot
handle_create_vless() {
    local chat_id="$1"
    local username="$2" 
    local days="$3"
    local quota="$4"
    local iplimit="$5"
    
    # Buat akun
    main_bot_create_vless "$username" "$days" "$quota" "$iplimit"
    
    # Ambil hasil
    local status=$(get_result_statusvless)
    local message=$(get_result_message_vless)
    
    if [ "$status" = "success" ]; then
        # Kirim pesan sukses ke chat
        send_message "$chat_id" "$message"
    else
        # Kirim pesan error
        send_message "$chat_id" "❌ Gagal membuat akun: $message"
    fi
}
```

DOCUMENTATION