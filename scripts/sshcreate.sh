#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SSH Bot Creator - Function Based
# Sistem Pembuatan Akun SSH/OpenVPN Terintegrasi Telegram Bot
# Developer: fadzdigital
# Email: fadztechs2@gmail.com
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ═══════════════════════════════════════════════════════════════════════════════
# KONFIGURASI WARNA DAN VARIABEL GLOBAL
# ═══════════════════════════════════════════════════════════════════════════════
RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT='\033[0;37m'
BGWHITE='\e[0;100;37m'

# Variabel global untuk hasil operasi
declare -g SSH_CREATE_STATUS=""
declare -g SSH_CREATE_MESSAGE=""
declare -g SSH_ACCOUNT_DATA=""

# ═══════════════════════════════════════════════════════════════════════════════
# POINT 1: VALIDASI SCRIPT
# Fungsi untuk memvalidasi apakah VPS memiliki izin menggunakan script
# ═══════════════════════════════════════════════════════════════════════════════
validate_script() {
    echo -e "${BLUE}[INFO]${NC} Memvalidasi izin script..."
    
    # Mendapatkan IP server
    local ipsaya=$(curl -sS ipv4.icanhazip.com 2>/dev/null)
    
    if [[ -z "$ipsaya" ]]; then
        echo -e "${RED}[ERROR]${NC} Gagal mendapatkan IP server"
        return 1
    fi
    
    # Mendapatkan tanggal server
    local data_server=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
    local date_list=$(date +"%Y-%m-%d" -d "$data_server" 2>/dev/null)
    
    if [[ -z "$date_list" ]]; then
        date_list=$(date +"%Y-%m-%d")
    fi
    
    # URL database IP yang diizinkan
    local data_ip="https://raw.githubusercontent.com/MikkuChan/instalasi/main/register"
    
    # Mengecek izin IP
    local useexp=$(wget -qO- $data_ip 2>/dev/null | grep $ipsaya | awk '{print $3}')
    
    if [[ -z "$useexp" ]]; then
        echo -e "${RED}[ERROR]${NC} IP $ipsaya tidak terdaftar dalam whitelist"
        return 1
    fi
    
    # Membandingkan tanggal
    if [[ $date_list < $useexp ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} Validasi script berhasil. IP: $ipsaya, Expired: $useexp"
        return 0
    else
        echo -e "${RED}[ERROR]${NC} Script sudah expired. IP: $ipsaya, Expired: $useexp"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# POINT 2: FUNGSI GENERATE PASSWORD RANDOM
# Membuat password acak jika tidak disediakan
# ═══════════════════════════════════════════════════════════════════════════════
generate_random_password() {
    local random_num=$(shuf -i 10000-99999 -n 1)
    echo "pass${random_num}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# POINT 3: FUNGSI VALIDASI INPUT
# Memvalidasi parameter input sebelum membuat akun
# ═══════════════════════════════════════════════════════════════════════════════
validate_input() {
    local username="$1"
    local days="$2"
    local quota="$3"
    local ip_limit="$4"
    
    # Validasi username
    if [[ -z "$username" ]]; then
        echo -e "${RED}[ERROR]${NC} Username tidak boleh kosong"
        return 1
    fi
    
    # Cek apakah username sudah ada
    if id "$username" &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Username '$username' sudah ada"
        return 1
    fi
    
    # Validasi days
    if ! [[ "$days" =~ ^[0-9]+$ ]] || [[ "$days" -le 0 ]]; then
        echo -e "${RED}[ERROR]${NC} Jumlah hari harus berupa angka positif"
        return 1
    fi
    
    # Validasi quota (opsional)
    if [[ -n "$quota" ]] && ! [[ "$quota" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}[ERROR]${NC} Quota harus berupa angka"
        return 1
    fi
    
    # Validasi ip_limit (opsional)
    if [[ -n "$ip_limit" ]] && ! [[ "$ip_limit" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}[ERROR]${NC} IP limit harus berupa angka"
        return 1
    fi
    
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# POINT 4: MANAGEMENT KUOTA & IP LIMIT
# Mengelola pembatasan kuota dan IP untuk akun
# ═══════════════════════════════════════════════════════════════════════════════
setup_quota_limit() {
    local username="$1"
    local quota="$2"
    
    if [[ -z "$quota" ]] || [[ "$quota" == "0" ]]; then
        echo -e "${BLUE}[INFO]${NC} Tidak ada pembatasan kuota untuk user: $username"
        return 0
    fi
    
    # Konversi GB ke bytes
    local quota_bytes=$((${quota} * 1024 * 1024 * 1024))
    
    # Buat direktori jika belum ada
    [[ ! -d "/etc/ssh" ]] && mkdir -p /etc/ssh
    
    # Simpan kuota
    echo "${quota_bytes}" > /etc/ssh/${username}
    
    echo -e "${GREEN}[SUCCESS]${NC} Setup kuota ${quota}GB untuk user: $username"
    return 0
}

setup_ip_limit() {
    local username="$1"
    local ip_limit="$2"
    
    if [[ -z "$ip_limit" ]] || [[ "$ip_limit" == "0" ]]; then
        echo -e "${BLUE}[INFO]${NC} Tidak ada pembatasan IP untuk user: $username"
        return 0
    fi
    
    # Buat direktori jika belum ada
    mkdir -p /etc/kyt/limit/ssh/ip
    
    # Simpan IP limit
    echo -e "$ip_limit" > /etc/kyt/limit/ssh/ip/$username
    
    echo -e "${GREEN}[SUCCESS]${NC} Setup IP limit ${ip_limit} untuk user: $username"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# POINT 5: DATABASE MANAGEMENT
# Mengelola database akun SSH
# ═══════════════════════════════════════════════════════════════════════════════
update_ssh_database() {
    local username="$1"
    local password="$2"
    local quota="$3"
    local ip_limit="$4"
    local expire_date="$5"
    
    # Buat direktori database jika belum ada
    [[ ! -d "/etc/ssh" ]] && mkdir -p /etc/ssh
    [[ ! -f "/etc/ssh/.ssh.db" ]] && touch /etc/ssh/.ssh.db
    
    # Hapus data lama jika ada
    local existing_data=$(cat /etc/ssh/.ssh.db | grep "^#ssh#" | grep -w "${username}" | awk '{print $2}')
    if [[ -n "$existing_data" ]]; then
        sed -i "/\b${username}\b/d" /etc/ssh/.ssh.db
        echo -e "${BLUE}[INFO]${NC} Data lama user $username telah dihapus"
    fi
    
    # Tambahkan data baru
    echo "#ssh# ${username} ${password} ${quota:-0} ${ip_limit:-0} ${expire_date}" >> /etc/ssh/.ssh.db
    
    echo -e "${GREEN}[SUCCESS]${NC} Database SSH telah diupdate untuk user: $username"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# POINT 6: FILE CONFIG GENERATION
# Membuat file konfigurasi akun untuk akses web
# ═══════════════════════════════════════════════════════════════════════════════
generate_config_file() {
    local username="$1"
    local password="$2"
    local days="$3"
    local ip="$4"
    local domain="$5"
    local city="$6"
    local isp="$7"
    local created_date="$8"
    local expire_date="$9"
    
    # Buat direktori web jika belum ada
    [[ ! -d "/var/www/html" ]] && mkdir -p /var/www/html
    
    # Generate file konfigurasi
    cat > /var/www/html/ssh-$username.txt <<-END
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Format SSH OVPN Account
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Username         : $username
Password         : $password
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
IP               : $ip
Host             : $domain
Port OpenSSH     : 443, 80, 22
Port Dropbear    : 443, 109
Port Dropbear WS : 443, 109
Port SSH UDP     : 1-65535
Port SSH WS      : 80, 8080, 8081-9999
Port SSH SSL WS  : 443
Port SSL/TLS     : 400-900
Port OVPN WS SSL : 443
Port OVPN SSL    : 443
Port OVPN TCP    : 1194
Port OVPN UDP    : 2200
BadVPN UDP       : 7100, 7300, 7300
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Aktif Selama     : $days Hari
Dibuat Pada      : $created_date
Berakhir Pada    : $expire_date
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Payload WSS   : GET wss://BUG.COM/ HTTP/1.1[crlf]Host: $domain[crlf]Upgrade: websocket[crlf][crlf] 
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OVPN Download : https://$domain:81/
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
END

    echo -e "${GREEN}[SUCCESS]${NC} File konfigurasi dibuat: /var/www/html/ssh-$username.txt"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# POINT 7: TELEGRAM NOTIFICATION
# Mengirim notifikasi ke Telegram dengan detail akun
# ═══════════════════════════════════════════════════════════════════════════════
send_telegram_notification() {
    local username="$1"
    local password="$2"
    local quota="$3"
    local ip_limit="$4"
    local days="$5"
    local ip="$6"
    local domain="$7"
    local city="$8"
    local isp="$9"
    local created_date="${10}"
    local expire_date="${11}"
    
    # Baca konfigurasi bot Telegram
    if [[ ! -f "/etc/bot/.bot.db" ]]; then
        echo -e "${ORANGE}[WARNING]${NC} File konfigurasi bot tidak ditemukan, skip notifikasi Telegram"
        return 1
    fi
    
    local chatid=$(grep -E "^#bot# " "/etc/bot/.bot.db" | cut -d ' ' -f 3)
    local key=$(grep -E "^#bot# " "/etc/bot/.bot.db" | cut -d ' ' -f 2)
    
    if [[ -z "$chatid" ]] || [[ -z "$key" ]]; then
        echo -e "${ORANGE}[WARNING]${NC} Konfigurasi bot tidak lengkap, skip notifikasi Telegram"
        return 1
    fi
    
    local time="10"
    local url="https://api.telegram.org/bot$key/sendMessage"
    
    # Format pesan untuk Telegram
    local text="
<code>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</code>
<code>CREATE SSH OPENVPN SUCCESS</code>
<code>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</code>
<code>CITY             : $city</code>
<code>ISP              : $isp</code>
<code>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</code>
<code>Username         : </code> <code>$username</code>
<code>Password         : </code> <code>$password</code>
<code>Limit Quota      : </code> <code>${quota:-Unlimited}</code>
<code>Limit IP         : </code> <code>${ip_limit:-Unlimited}</code>
<code>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</code>
<code>IP               : $ip</code>
<code>Host             : </code> <code>$domain</code>
<code>Port OpenSSH     : 443, 80, 22</code>
<code>Port Dropbear    : 443, 109</code>
<code>Port SSH WS      : 80, 8080, 8081-9999 </code>
<code>Port SSH UDP     : 1-65535 </code>
<code>Port SSH SSL WS  : 443</code>
<code>Port SSL/TLS     : 400-900</code>
<code>Port OVPN WS SSL : 443</code>
<code>Port OVPN SSL    : 443</code>
<code>Port OVPN TCP    : 443, 1194</code>
<code>Port OVPN UDP    : 2200</code>
<code>BadVPN UDP       : 7100, 7300, 7300</code>
<code>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</code>
<code>Payload WS       : </code><code>GET / HTTP/1.1[crlf]Host: [host][crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf]Upgrade: websocket[crlf][crlf]</code>
<code>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</code>
<code>Payload WSS      : </code><code>GET wss://BUG.COM/ HTTP/1.1[crlf]Host: $domain[crlf]Upgrade: websocket[crlf][crlf]</code>
<code>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</code>
<code>OVPN Download    : https://$domain:81/</code>
<code>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</code>
<code>Save Link Akun   : </code>https://$domain:81/ssh-$username.txt
<code>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</code>
<code>Aktif Selama     : $days Hari</code>
<code>Dibuat Pada      : $created_date</code>
<code>Berakhir Pada    : $expire_date</code>
<code>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</code>
"
    
    # Simpan pesan untuk penggunaan nanti
    SSH_CREATE_MESSAGE="$text"
    
    # Kirim ke Telegram
    local response=$(curl -s --max-time $time -d "chat_id=$chatid&disable_web_page_preview=1&text=$text&parse_mode=html" $url 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} Notifikasi Telegram berhasil dikirim"
        return 0
    else
        echo -e "${ORANGE}[WARNING]${NC} Gagal mengirim notifikasi Telegram"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# POINT 8: LOGGING SYSTEM
# Sistem logging untuk mencatat aktivitas pembuatan akun
# ═══════════════════════════════════════════════════════════════════════════════
log_account_creation() {
    local username="$1"
    local password="$2"
    local quota="$3"
    local ip_limit="$4"
    local days="$5"
    local ip="$6"
    local domain="$7"
    local city="$8"
    local isp="$9"
    local created_date="${10}"
    local expire_date="${11}"
    
    # Buat direktori log jika belum ada
    [[ ! -d "/etc/user-create" ]] && mkdir -p /etc/user-create
    
    # Log ke file
    {
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "CREATE SSH OPENVPN SUCCESS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Username         : $username"
        echo "Password         : $password"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Location         : $city"
        echo "ISP Server       : $isp"
        echo "IP Server        : $ip"
        echo "Host Server      : $domain"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Limit Quota      : ${quota:-Unlimited} GB"
        echo "Limit IP         : ${ip_limit:-Unlimited} User"
        echo "Port OpenSSH     : 443, 80, 22"
        echo "Port SSH UDP     : 1-65535"
        echo "Port Dropbear    : 443, 109"
        echo "Port SSH WS      : 80, 8080, 8880, 2082"
        echo "Port SSH SSL WS  : 443"
        echo "Port SSL/TLS     : 400-900"
        echo "BadVPN UDP       : 7100, 7300, 7300"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Payload WS       : GET / HTTP/1.1[crlf]Host: [host][crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf]Upgrade: websocket[crlf][crlf]"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Payload WSS      : GET wss://BUG.COM/ HTTP/1.1[crlf]Host: $domain[crlf]Upgrade: websocket[crlf][crlf]"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Aktif Selama     : $days Hari"
        echo "Dibuat Pada      : $created_date"
        echo "Expired On       : $expire_date"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    } >> /etc/user-create/user.log
    
    echo -e "${GREEN}[SUCCESS]${NC} Log aktivitas disimpan ke /etc/user-create/user.log"
}

# ═══════════════════════════════════════════════════════════════════════════════
# POINT 9: FUNGSI UTAMA PEMBUATAN AKUN SSH
# Fungsi utama untuk membuat akun SSH dengan semua parameter
# ═══════════════════════════════════════════════════════════════════════════════
create_ssh_bot() {
    local username="$1"
    local password="$2"
    local days="$3"
    local quota="$4"
    local ip_limit="$5"
    
    # Jika password kosong, generate random
    if [[ -z "$password" ]]; then
        password=$(generate_random_password)
        echo -e "${BLUE}[INFO]${NC} Password otomatis dibuat: $password"
    fi
    
    # Validasi input
    if ! validate_input "$username" "$days" "$quota" "$ip_limit"; then
        SSH_CREATE_STATUS="FAILED"
        SSH_CREATE_MESSAGE="Validasi input gagal"
        return 1
    fi
    
    echo -e "${BLUE}[INFO]${NC} Memulai pembuatan akun SSH untuk user: $username"
    
    # Dapatkan informasi server
    local ip=$(curl -sS ipv4.icanhazip.com 2>/dev/null)
    local domain=$(cat /etc/xray/domain 2>/dev/null || echo "unknown.domain")
    local city=$(cat /etc/xray/city 2>/dev/null || echo "Unknown City")
    local isp=$(cat /etc/xray/isp 2>/dev/null || echo "Unknown ISP")
    
    # Hitung tanggal kedaluwarsa
    local expire_date_formatted=$(date -d "$days days" +"%d %b, %Y")
    local expire_date_system=$(date -d "$days days" +"%Y-%m-%d")
    local created_date=$(date +"%d %b, %Y")
    
    # Buat user sistem
    if ! useradd -e "$expire_date_system" -s /bin/false -M "$username" 2>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Gagal membuat user sistem"
        SSH_CREATE_STATUS="FAILED"
        SSH_CREATE_MESSAGE="Gagal membuat user sistem"
        return 1
    fi
    
    # Set password
    if ! echo -e "$password\n$password\n" | passwd "$username" &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Gagal mengatur password"
        userdel -f "$username" 2>/dev/null
        SSH_CREATE_STATUS="FAILED"
        SSH_CREATE_MESSAGE="Gagal mengatur password"
        return 1
    fi
    
    # Setup kuota dan IP limit
    setup_quota_limit "$username" "$quota"
    setup_ip_limit "$username" "$ip_limit"
    
    # Update database
    update_ssh_database "$username" "$password" "$quota" "$ip_limit" "$expire_date_formatted"
    
    # Generate file konfigurasi
    generate_config_file "$username" "$password" "$days" "$ip" "$domain" "$city" "$isp" "$created_date" "$expire_date_formatted"
    
    # Log aktivitas
    log_account_creation "$username" "$password" "$quota" "$ip_limit" "$days" "$ip" "$domain" "$city" "$isp" "$created_date" "$expire_date_formatted"
    
    # Kirim notifikasi Telegram
    send_telegram_notification "$username" "$password" "$quota" "$ip_limit" "$days" "$ip" "$domain" "$city" "$isp" "$created_date" "$expire_date_formatted"
    
    # Set status berhasil
    SSH_CREATE_STATUS="SUCCESS"
    SSH_ACCOUNT_DATA="username:$username|password:$password|days:$days|quota:${quota:-0}|ip_limit:${ip_limit:-0}|expire:$expire_date_formatted|domain:$domain|ip:$ip"
    
    echo -e "${GREEN}[SUCCESS]${NC} Akun SSH berhasil dibuat untuk user: $username"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# POINT 10: FUNGSI ORKESTRATOR UTAMA
# Fungsi utama yang menggabungkan semua proses pembuatan akun
# ═══════════════════════════════════════════════════════════════════════════════
main_bot_create_ssh() {
    local username="$1"
    local param2="$2"
    local param3="$3"
    local param4="$4"
    local param5="$5"
    
    # Reset status global
    SSH_CREATE_STATUS=""
    SSH_CREATE_MESSAGE=""
    SSH_ACCOUNT_DATA=""
    
    echo -e "${CYAN}[PROCESS]${NC} Memulai proses pembuatan akun SSH..."
    
    # STEP 1: Validasi script
    if ! validate_script; then
        SSH_CREATE_STATUS="FAILED"
        SSH_CREATE_MESSAGE="Validasi script gagal - IP tidak memiliki izin"
        echo -e "${RED}[FAILED]${NC} Proses dibatalkan karena validasi script gagal"
        return 1
    fi
    
    # STEP 2: Parsing parameter (deteksi apakah ada custom password atau tidak)
    local password=""
    local days=""
    local quota=""
    local ip_limit=""
    
    # Jika param2 adalah angka, maka tidak ada custom password
    if [[ "$param2" =~ ^[0-9]+$ ]]; then
        # Format: username days quota ip_limit
        days="$param2"
        quota="$param3"
        ip_limit="$param4"
    else
        # Format: username password days quota ip_limit
        password="$param2"
        days="$param3"
        quota="$param4"
        ip_limit="$param5"
    fi
    
    # STEP 3: Buat akun SSH
    if create_ssh_bot "$username" "$password" "$days" "$quota" "$ip_limit"; then
        echo -e "${GREEN}[SUCCESS]${NC} Semua proses berhasil diselesaikan"
        return 0
    else
        echo -e "${RED}[FAILED]${NC} Proses pembuatan akun gagal"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# POINT 11: FUNGSI GETTER UNTUK HASIL
# Fungsi untuk mengambil hasil operasi pembuatan akun
# ═══════════════════════════════════════════════════════════════════════════════
get_result_statusssh() {
    echo "$SSH_CREATE_STATUS"
}

get_result_message_ssh() {
    echo "$SSH_CREATE_MESSAGE"
}

get_result_account_data() {
    echo "$SSH_ACCOUNT_DATA"
}

# ═══════════════════════════════════════════════════════════════════════════════
# POINT 12: CLI INTERFACE
# Interface baris perintah untuk penggunaan manual
# ═══════════════════════════════════════════════════════════════════════════════
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script dijalankan langsung (bukan di-source)
    
    case "$1" in
        "create")
            shift
            main_bot_create_ssh "$@"
            exit $?
            ;;
        "validate")
            validate_script
            exit $?
            ;;
        "help"|"--help"|"-h")
            echo -e "${CYAN}SSH Bot Creator - Function Based${NC}"
            echo -e "${CYAN}=================================${NC}"
            echo ""
            echo -e "${GREEN}Penggunaan:${NC}"
            echo -e "  $0 create <username> <days> [quota] [ip_limit]"
            echo -e "  $0 create <username> <password> <days> [quota] [ip_limit]"
            echo -e "  $0 validate"
            echo -e "  $0 help"
            echo ""
            echo -e "${GREEN}Contoh:${NC}"
            echo -e "  $0 create user123 30 10 2        # Username, 30 hari, 10GB, 2 IP"
            echo -e "  $0 create user123 mypass 30 10 2 # Username, password custom, 30 hari, 10GB, 2 IP"
            echo -e "  $0 create user123 7              # Username, 7 hari, unlimited"
            echo ""
            echo -e "${GREEN}Parameter:${NC}"
            echo -e "  username  : Nama pengguna (wajib)"
            echo -e "  password  : Password custom (opsional, akan di-generate jika kosong)"
            echo -e "  days      : Masa aktif dalam hari (wajib)"
            echo -e "  quota     : Batas kuota dalam GB (opsional, 0 = unlimited)"
            echo -e "  ip_limit  : Batas jumlah IP (opsional, 0 = unlimited)"
            exit 0
            ;;
        *)
            echo -e "${RED}[ERROR]${NC} Perintah tidak dikenal: $1"
            echo -e "Gunakan '$0 help' untuk melihat bantuan"
            exit 1
            ;;
    esac
fi

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORT FUNCTIONS UNTUK BOT
# Export semua fungsi agar bisa dipanggil dari script lain
# ═══════════════════════════════════════════════════════════════════════════════
export -f validate_script
export -f generate_random_password
export -f validate_input
export -f setup_quota_limit
export -f setup_ip_limit
export -f update_ssh_database
export -f generate_config_file
export -f send_telegram_notification
export -f log_account_creation
export -f create_ssh_bot
export -f main_bot_create_ssh
export -f get_result_statusssh
export -f get_result_message_ssh
export -f get_result_account_data

echo -e "${GREEN}[INFO]${NC} SSH Bot Creator functions loaded successfully"

# ═══════════════════════════════════════════════════════════════════════════════
# DOKUMENTASI PENGGUNAAN
# ═══════════════════════════════════════════════════════════════════════════════

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                          DOKUMENTASI PENGGUNAAN                            │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# 1. CLI INTERFACE:
# ─────────────────
# Jalankan script langsung dari command line:
#
# • Membuat akun dengan password otomatis:
#   ./ssh_bot.sh create username123 30 10 2
#   (username: username123, masa aktif: 30 hari, kuota: 10GB, IP limit: 2)
#
# • Membuat akun dengan password custom:
#   ./ssh_bot.sh create username123 mypassword 30 10 2
#   (username: username123, password: mypassword, masa aktif: 30 hari, kuota: 10GB, IP limit: 2)
#
# • Membuat akun unlimited:
#   ./ssh_bot.sh create username123 30
#   (username: username123, masa aktif: 30 hari, kuota: unlimited, IP: unlimited)
#
# • Validasi script saja:
#   ./ssh_bot.sh validate
#
# • Bantuan:
#   ./ssh_bot.sh help
#
# 2. IMPORT KE SCRIPT LAIN:
# ─────────────────────────
# Source script ini di script lain untuk menggunakan fungsi-fungsinya:
#
# #!/bin/bash
# source /path/to/ssh_bot.sh
#
# # Contoh penggunaan dalam script bot Telegram:
# main_bot_create_ssh "testuser" "30" "5" "1"
#
# # Ambil hasil
# status=$(get_result_statusssh)
# message=$(get_result_message_ssh)
# account_data=$(get_result_account_data)
#
# if [[ "$status" == "SUCCESS" ]]; then
#     echo "Akun berhasil dibuat!"
#     echo "Data akun: $account_data"
#     echo "Pesan Telegram: $message"
# else
#     echo "Gagal membuat akun: $message"
# fi
#
# 3. PARAMETER:
# ─────────────
# main_bot_create_ssh memiliki parameter fleksibel:
#
# • Format 1: main_bot_create_ssh username days [quota] [ip_limit]
#   - Password akan di-generate otomatis (format: pass12345)
#   - Contoh: main_bot_create_ssh "user1" "30" "10" "2"
#
# • Format 2: main_bot_create_ssh username password days [quota] [ip_limit]
#   - Password custom yang ditentukan user
#   - Contoh: main_bot_create_ssh "user1" "mypass" "30" "10" "2"
#
# Parameter yang tersedia:
# - username  : Nama pengguna (string, wajib)
# - password  : Password custom (string, opsional)
# - days      : Masa aktif dalam hari (integer, wajib)
# - quota     : Kuota dalam GB (integer, opsional, default: unlimited)
# - ip_limit  : Batas jumlah IP (integer, opsional, default: unlimited)
#
# 4. RETURN VALUE:
# ────────────────
# Setelah menjalankan main_bot_create_ssh, gunakan fungsi getter untuk hasil:
#
# • get_result_statusssh()
#   Return: "SUCCESS" atau "FAILED"
#   Fungsi: Mengetahui status pembuatan akun
#
# • get_result_message_ssh()
#   Return: String pesan (format HTML untuk Telegram)
#   Fungsi: Mengambil pesan lengkap yang dikirim ke Telegram
#
# • get_result_account_data()
#   Return: String data akun (format: key:value|key:value)
#   Fungsi: Data terstruktur akun untuk parsing lebih lanjut
#   Format: "username:xxx|password:xxx|days:xxx|quota:xxx|ip_limit:xxx|expire:xxx|domain:xxx|ip:xxx"
#
# 5. CONTOH INTEGRASI BOT TELEGRAM:
# ──────────────────────────────────
# #!/bin/bash
# source /path/to/ssh_bot.sh
#
# # Fungsi handler untuk perintah /createssh
# handle_create_ssh() {
#     local chat_id="$1"
#     local username="$2"
#     local days="$3"
#     local quota="$4"
#     local ip_limit="$5"
#
#     # Buat akun SSH
#     main_bot_create_ssh "$username" "$days" "$quota" "$ip_limit"
#
#     # Ambil hasil
#     local status=$(get_result_statusssh)
#     local message=$(get_result_message_ssh)
#
#     if [[ "$status" == "SUCCESS" ]]; then
#         # Kirim pesan sukses ke chat
#         send_telegram_message "$chat_id" "$message"
#     else
#         # Kirim pesan error
#         send_telegram_message "$chat_id" "❌ Gagal membuat akun: $message"
#     fi
# }
#
# 6. LOGGING DAN MONITORING:
# ──────────────────────────
# Script akan otomatis membuat log di:
# - /etc/user-create/user.log : Log aktivitas pembuatan akun
# - /etc/ssh/.ssh.db : Database akun SSH
# - /var/www/html/ssh-username.txt : File konfigurasi per akun
#
# 7. DEPENDENSI:
# ──────────────
# Script membutuhkan:
# - curl (untuk API dan validasi)
# - File konfigurasi bot: /etc/bot/.bot.db
# - File sistem: /etc/xray/domain, /etc/xray/city, /etc/xray/isp
# - Akses root untuk membuat user sistem
#
# 8. ERROR HANDLING:
# ──────────────────
# Script memiliki error handling untuk:
# - Validasi IP whitelist
# - Validasi parameter input
# - Duplikasi username
# - Kegagalan sistem (useradd, passwd)
# - Kegagalan jaringan (Telegram API)
#
# ═══════════════════════════════════════════════════════════════════════════════