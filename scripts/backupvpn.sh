#!/bin/bash
# ━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━━
# 𓈃 System Request ➠ Debian 9+/Ubuntu 18.04+/20+
# 𓈃 Developer ➠ MikkuChan
# 𓈃 Email      ➠ fadztechs2@gmail.com
# 𓈃 Telegram   ➠ https://t.me/fadzdigital
# 𓈃 Version    ➠ Bot Integration v2.0
# ━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━━

# ═══════════════════════════════════════════════════════════════
# KONFIGURASI GLOBAL DAN VARIABEL
# ═══════════════════════════════════════════════════════════════

# Variabel global untuk menyimpan hasil backup (digunakan oleh bot)
declare -g BACKUP_STATUS=""          # Status: "success" atau "failed"
declare -g BACKUP_MESSAGE=""         # Pesan lengkap hasil backup
declare -g BACKUP_LINK=""            # Link download backup
declare -g BACKUP_ERROR=""           # Pesan error jika gagal

# Konfigurasi bot Telegram (dibaca dari database)
CHATID=$(grep -E "^#bot# " "/etc/bot/.bot.db" | cut -d ' ' -f 3 2>/dev/null)
KEY=$(grep -E "^#bot# " "/etc/bot/.bot.db" | cut -d ' ' -f 2 2>/dev/null)
export TIME="10"
export URL="https://api.telegram.org/bot$KEY/sendMessage"

# Warna ANSI untuk output terminal yang menarik
CYAN='\033[1;96m'
GREEN='\033[1;92m'
YELLOW='\033[1;93m'
RED='\033[1;91m'
NC='\033[0m' # Reset warna

# ═══════════════════════════════════════════════════════════════
# FUNGSI UTILITAS DAN BANTUAN
# ═══════════════════════════════════════════════════════════════

# Fungsi untuk mendapatkan informasi sistem VPS
get_system_info() {
    local ip domain date_now
    
    # Dapatkan IP publik VPS
    ip=$(curl -sS ipv4.icanhazip.com 2>/dev/null || echo "Unknown")
    
    # Dapatkan domain dari konfigurasi Xray
    domain=$(cat /etc/xray/domain 2>/dev/null || echo "Unknown")
    
    # Dapatkan tanggal saat ini
    date_now=$(date +"%Y-%m-%d")
    
    # Return format: IP|DOMAIN|DATE
    echo "$ip|$domain|$date_now"
}

# Fungsi untuk mengelola email backup
manage_email() {
    local email_param="$1"
    local email
    
    # Jika parameter email diberikan, simpan dan gunakan
    if [[ -n "$email_param" ]]; then
        echo "$email_param" > /root/email
        echo "$email_param"
        return 0
    fi
    
    # Cek email yang sudah tersimpan sebelumnya
    email=$(cat /root/email 2>/dev/null)
    if [[ -z "$email" ]]; then
        BACKUP_ERROR="Email belum dikonfigurasi. Gunakan parameter email pada pemanggilan pertama."
        return 1
    fi
    
    echo "$email"
    return 0
}

# Fungsi untuk menampilkan progress bar saat backup
show_progress() {
    local message="$1"
    local percentage="$2"
    local bar=""
    
    # Buat progress bar berdasarkan persentase
    case $percentage in
        10) bar="■□□□□□□□□□" ;;
        25) bar="■■□□□□□□□□" ;;
        40) bar="■■■■□□□□□□" ;;
        50) bar="■■■■■□□□□□" ;;
        75) bar="■■■■■■■□□□" ;;
        90) bar="■■■■■■■■■□" ;;
        100) bar="■■■■■■■■■■" ;;
        *) bar="□□□□□□□□□□" ;;
    esac
    
    echo -ne "\r📂 ${GREEN}$message${NC}   [$bar] $percentage%"
    sleep 1
}

# ═══════════════════════════════════════════════════════════════
# FUNGSI BACKUP INTI
# ═══════════════════════════════════════════════════════════════

# Fungsi untuk menyiapkan direktori backup
prepare_backup_directory() {
    # Hapus direktori backup lama jika ada
    rm -rf /root/backup 2>/dev/null
    
    # Buat direktori backup baru
    mkdir -p /root/backup
    
    # Cek apakah direktori berhasil dibuat
    if [[ ! -d "/root/backup" ]]; then
        BACKUP_ERROR="Gagal membuat direktori backup di /root/backup"
        return 1
    fi
    
    return 0
}

# Fungsi untuk menyalin file sistem penting
copy_system_files() {
    local files=("/etc/passwd" "/etc/group" "/etc/shadow" "/etc/gshadow")
    
    # Salin setiap file sistem yang diperlukan
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            cp "$file" /root/backup/ || {
                BACKUP_ERROR="Gagal menyalin file sistem: $file"
                return 1
            }
        fi
    done
    
    return 0
}

# Fungsi untuk menyalin file konfigurasi VPN
copy_vpn_configs() {
    local configs=("xray" "kyt" "vmess" "vless" "trojan" "shadowsocks")
    
    # Salin setiap direktori konfigurasi VPN
    for config in "${configs[@]}"; do
        if [[ -d "/etc/$config" ]]; then
            cp -r "/etc/$config" "/root/backup/$config" || {
                BACKUP_ERROR="Gagal menyalin konfigurasi VPN: $config"
                return 1
            }
        fi
    done
    
    return 0
}

# Fungsi untuk mengkompresi file backup
compress_backup() {
    local ip="$1"
    local date="$2"
    local filename="$ip-$date.zip"
    
    # Pindah ke direktori root untuk kompresi
    cd /root || {
        BACKUP_ERROR="Gagal mengakses direktori /root"
        return 1
    }
    
    # Kompresi folder backup menjadi file ZIP
    zip -r "$filename" backup > /dev/null 2>&1 || {
        BACKUP_ERROR="Gagal mengkompresi file backup"
        return 1
    }
    
    # Cek apakah file ZIP berhasil dibuat
    if [[ ! -f "/root/$filename" ]]; then
        BACKUP_ERROR="File backup tidak ditemukan setelah kompresi"
        return 1
    fi
    
    echo "$filename"
    return 0
}

# Fungsi untuk upload backup ke Google Drive
upload_to_drive() {
    local filename="$1"
    local url id link
    
    # Upload file ke Google Drive menggunakan rclone
    rclone copy "/root/$filename" dr:backup/ || {
        BACKUP_ERROR="Gagal upload file ke Google Drive. Pastikan rclone sudah dikonfigurasi."
        return 1
    }
    
    # Dapatkan link shareable dari Google Drive
    url=$(rclone link "dr:backup/$filename" 2>/dev/null)
    if [[ -z "$url" ]]; then
        BACKUP_ERROR="Gagal mendapatkan link download dari Google Drive"
        return 1
    fi
    
    # Ekstrak ID file dan buat link direct download
    id=$(echo "$url" | grep -o 'id=[^&]*' | cut -d '=' -f2)
    link="https://drive.google.com/u/4/uc?id=${id}&export=download"
    
    echo "$link"
    return 0
}

# Fungsi untuk mengirim email notifikasi
send_email_notification() {
    local email="$1"
    local ip="$2"
    local domain="$3"
    local date="$4"
    local link="$5"
    
    # Template email dengan format yang menarik
    local email_content="
━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━
🔹 BACKUP VPS BERHASIL 🔹
━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━
📌 IP VPS       : $ip
🌐 DOMAIN       : $domain
📅 TANGGAL      : $date
━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━
📂 LINK BACKUP :  
$link
━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━
✅ Backup selesai!  
📌 Simpan link ini dan gunakan untuk restore di VPS baru.
"
    
    # Kirim email menggunakan command mail
    echo "$email_content" | mail -s "Backup Data VPS - $date" "$email" || {
        BACKUP_ERROR="Gagal mengirim email notifikasi ke $email"
        return 1
    }
    
    return 0
}

# ═══════════════════════════════════════════════════════════════
# FUNGSI INTEGRASI TELEGRAM
# ═══════════════════════════════════════════════════════════════

# Fungsi untuk mengirim notifikasi ke Telegram
send_telegram_notification() {
    local ip="$1"
    local domain="$2"
    local date="$3"
    local link="$4"
    local status="$5"
    
    # Cek konfigurasi bot Telegram
    if [[ -z "$CHATID" || -z "$KEY" ]]; then
        BACKUP_ERROR="Konfigurasi bot Telegram tidak lengkap. Cek file /etc/bot/.bot.db"
        return 1
    fi
    
    local text
    # Format pesan berdasarkan status backup
    if [[ "$status" == "success" ]]; then
        text="
━━━━━━━━━━※ ·❆· ※━━━━━━━━━━
𓈃 BACKUP VPS BERHASIL 𓈃
━━━━━━━━━━※ ·❆· ※━━━━━━━━━━
📌 IP VPS       : $ip
🌐 DOMAIN       : $domain
📅 TANGGAL      : $date
━━━━━━━━━━※ ·❆· ※━━━━━━━━━━
📂 LINK BACKUP :  
$link
━━━━━━━━━━※ ·❆· ※━━━━━━━━━━
✅ Backup selesai!  
📌 Simpan link ini dan gunakan untuk restore di VPS baru, Onii-Chan.
"
    else
        text="
━━━━━━━━━━※ ·❆· ※━━━━━━━━━━
𓈃 BACKUP VPS GAGAL 𓈃
━━━━━━━━━━※ ·❆· ※━━━━━━━━━━
📌 IP VPS       : $ip
🌐 DOMAIN       : $domain
📅 TANGGAL      : $date
━━━━━━━━━━※ ·❆· ※━━━━━━━━━━
❌ ERROR: $link
━━━━━━━━━━※ ·❆· ※━━━━━━━━━━
🔄 Silakan coba lagi atau periksa konfigurasi sistem.
"
    fi
    
    # Kirim pesan ke Telegram menggunakan API
    curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$text&parse_mode=html" "$URL" >/dev/null || {
        BACKUP_ERROR="Gagal mengirim notifikasi ke Telegram"
        return 1
    }
    
    return 0
}

# ═══════════════════════════════════════════════════════════════
# FUNGSI BACKUP UTAMA
# ═══════════════════════════════════════════════════════════════

# Fungsi utama untuk melakukan proses backup lengkap
perform_backup() {
    local email_param="$1"
    local system_info ip domain date_now email filename backup_link
    
    # Reset semua variabel global
    BACKUP_STATUS=""
    BACKUP_MESSAGE=""
    BACKUP_LINK=""
    BACKUP_ERROR=""
    
    # Dapatkan informasi sistem VPS
    system_info=$(get_system_info)
    IFS='|' read -r ip domain date_now <<< "$system_info"
    
    # Kelola konfigurasi email
    email=$(manage_email "$email_param")
    if [[ $? -ne 0 ]]; then
        BACKUP_STATUS="failed"
        BACKUP_MESSAGE="$BACKUP_ERROR"
        return 1
    fi
    
    # Tampilkan header proses backup
    echo -e "${YELLOW}━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
    echo -e "🔹 ${CYAN}MEMULAI PROSES BACKUP VPS...${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
    
    # Langkah 1: Persiapan direktori backup
    show_progress "Menyiapkan direktori backup" 10
    if ! prepare_backup_directory; then
        BACKUP_STATUS="failed"
        BACKUP_MESSAGE="$BACKUP_ERROR"
        send_telegram_notification "$ip" "$domain" "$date_now" "$BACKUP_ERROR" "failed"
        return 1
    fi
    
    # Langkah 2: Menyalin file sistem penting
    show_progress "Menyalin file sistem" 25
    if ! copy_system_files; then
        BACKUP_STATUS="failed"
        BACKUP_MESSAGE="$BACKUP_ERROR"
        send_telegram_notification "$ip" "$domain" "$date_now" "$BACKUP_ERROR" "failed"
        return 1
    fi
    
    # Langkah 3: Menyalin konfigurasi VPN
    show_progress "Menyalin konfigurasi VPN" 50
    if ! copy_vpn_configs; then
        BACKUP_STATUS="failed"
        BACKUP_MESSAGE="$BACKUP_ERROR"
        send_telegram_notification "$ip" "$domain" "$date_now" "$BACKUP_ERROR" "failed"
        return 1
    fi
    
    # Langkah 4: Kompresi file backup
    show_progress "Mengkompresi file backup" 75
    filename=$(compress_backup "$ip" "$date_now")
    if [[ $? -ne 0 ]]; then
        BACKUP_STATUS="failed"
        BACKUP_MESSAGE="$BACKUP_ERROR"
        send_telegram_notification "$ip" "$domain" "$date_now" "$BACKUP_ERROR" "failed"
        return 1
    fi
    
    # Langkah 5: Upload ke Google Drive
    show_progress "Mengunggah ke Google Drive" 90
    backup_link=$(upload_to_drive "$filename")
    if [[ $? -ne 0 ]]; then
        BACKUP_STATUS="failed"
        BACKUP_MESSAGE="$BACKUP_ERROR"
        send_telegram_notification "$ip" "$domain" "$date_now" "$BACKUP_ERROR" "failed"
        return 1
    fi
    
    # Langkah 6: Kirim email notifikasi
    show_progress "Mengirim notifikasi email" 95
    if ! send_email_notification "$email" "$ip" "$domain" "$date_now" "$backup_link"; then
        # Email gagal tidak menggagalkan backup, hanya warning
        echo -e "\n⚠️  ${YELLOW}Warning: Gagal mengirim email notifikasi${NC}"
    fi
    
    # Langkah 7: Bersihkan file sementara
    show_progress "Membersihkan file sementara" 100
    rm -rf /root/backup
    rm -f "/root/$filename"
    
    echo -e "\n✅ ${GREEN}Backup berhasil diselesaikan!${NC}"
    
    # Set hasil ke variabel global untuk akses bot
    BACKUP_STATUS="success"
    BACKUP_LINK="$backup_link"
    BACKUP_MESSAGE="
━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━
🔹 BACKUP VPS BERHASIL 🔹
━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━
📌 IP VPS       : $ip
🌐 DOMAIN       : $domain
📅 TANGGAL      : $date_now
📂 LINK BACKUP  : $backup_link
━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━
✅ Backup selesai! Simpan link ini untuk restore di VPS baru.
"
    
    # Kirim notifikasi sukses ke Telegram
    send_telegram_notification "$ip" "$domain" "$date_now" "$backup_link" "success"
    
    # Tampilkan hasil di terminal
    echo -e "${YELLOW}━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
    echo -e "🔹 ${CYAN}BACKUP VPS BERHASIL${NC} 🔹"
    echo -e "${YELLOW}━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
    echo -e "📌 ${GREEN}IP VPS       : ${NC}$ip"
    echo -e "🌐 ${GREEN}DOMAIN       : ${NC}$domain"
    echo -e "📅 ${GREEN}TANGGAL      : ${NC}$date_now"
    echo -e "📂 ${GREEN}LINK BACKUP  : ${NC}$backup_link"
    echo -e "${YELLOW}━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
    echo -e "✅ ${GREEN}Backup selesai! Simpan link ini untuk restore di VPS baru.${NC}"
    
    return 0
}

# ═══════════════════════════════════════════════════════════════
# FUNGSI INTEGRASI BOT
# ═══════════════════════════════════════════════════════════════

# Fungsi utama untuk dipanggil oleh bot Telegram
main_bot_backupvpn() {
    local email_param="$1"
    
    # Jalankan proses backup
    if perform_backup "$email_param"; then
        return 0  # Backup berhasil
    else
        return 1  # Backup gagal
    fi
}

# Fungsi untuk mengambil status hasil backup (untuk integrasi)
get_result_backupvpn() {
    echo "$BACKUP_STATUS"
}

# Fungsi untuk mengambil pesan hasil backup (untuk integrasi)
get_result_message_backupvpn() {
    echo "$BACKUP_MESSAGE"
}

# Fungsi untuk mengambil link backup (untuk integrasi)
get_backup_link() {
    echo "$BACKUP_LINK"
}

# Fungsi untuk mengambil pesan error (untuk integrasi)
get_backup_error() {
    echo "$BACKUP_ERROR"
}

# ═══════════════════════════════════════════════════════════════
# INTERFACE COMMAND LINE
# ═══════════════════════════════════════════════════════════════

# Fungsi untuk menampilkan bantuan penggunaan
show_help() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}🔹 BACKUP VPN BOT INTEGRATION SCRIPT 🔹${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}PENGGUNAAN:${NC}"
    echo -e "  ${YELLOW}CLI Interface:${NC}"
    echo -e "    ./backupvpn.sh [email]     # Backup dengan email baru"
    echo -e "    ./backupvpn.sh             # Backup dengan email tersimpan"
    echo -e "    ./backupvpn.sh --help      # Tampilkan bantuan ini"
    echo ""
    echo -e "  ${YELLOW}Import ke script lain:${NC}"
    echo -e "    source ./backupvpn.sh"
    echo -e "    main_bot_backupvpn \"email\"  # Backup dengan email baru"
    echo -e "    main_bot_backupvpn          # Backup dengan email tersimpan"
    echo ""
    echo -e "${GREEN}FUNGSI YANG TERSEDIA:${NC}"
    echo -e "  ${YELLOW}main_bot_backupvpn [email]${NC}     - Fungsi utama backup"
    echo -e "  ${YELLOW}get_result_backupvpn${NC}           - Dapatkan status (success/failed)"
    echo -e "  ${YELLOW}get_result_message_backupvpn${NC}   - Dapatkan pesan hasil"
    echo -e "  ${YELLOW}get_backup_link${NC}                - Dapatkan link download"
    echo -e "  ${YELLOW}get_backup_error${NC}               - Dapatkan pesan error"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ═══════════════════════════════════════════════════════════════
# EXPORT FUNCTIONS (UNTUK INTEGRASI BOT)
# ═══════════════════════════════════════════════════════════════

# Export fungsi-fungsi penting agar bisa dipanggil dari script lain
export -f main_bot_backupvpn
export -f get_result_backupvpn
export -f get_result_message_backupvpn
export -f get_backup_link
export -f get_backup_error

# ═══════════════════════════════════════════════════════════════
# MAIN EXECUTION (JIKA DIPANGGIL LANGSUNG)
# ═══════════════════════════════════════════════════════════════

# Jalankan hanya jika script dipanggil langsung (bukan di-source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Cek parameter bantuan
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        show_help
        exit 0
    fi
    
    # Bersihkan layar untuk tampilan yang rapi
    clear
    
    # Jalankan backup dengan parameter email (jika ada)
    main_bot_backupvpn "$1"
    
    # Exit dengan status sesuai hasil backup
    exit $?
fi

# ═══════════════════════════════════════════════════════════════
# DOKUMENTASI PENGGUNAAN
# ═══════════════════════════════════════════════════════════════

: <<'DOKUMENTASI'

╔══════════════════════════════════════════════════════════════════════════════╗
║                    DOKUMENTASI BACKUP VPN BOT SCRIPT                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

1. CLI Interface:
   ┌─────────────────────────────────────────────────────────────────────────┐
   │ ./backupvpn.sh user@gmail.com    # Backup pertama kali dengan email     │
   │ ./backupvpn.sh                   # Backup selanjutnya (email tersimpan) │
   │ ./backupvpn.sh --help            # Tampilkan bantuan                    │
   └─────────────────────────────────────────────────────────────────────────┘

2. Import ke script lain:
   ┌─────────────────────────────────────────────────────────────────────────┐
   │ #!/bin/bash                                                             │
   │ source /path/to/backupvpn.sh                                           │
   │                                                                         │
   │ # Panggil fungsi backup                                                 │
   │ main_bot_backupvpn "user@gmail.com"  # Dengan email baru               │
   │ main_bot_backupvpn                   # Dengan email tersimpan          │
   │                                                                         │
   │ # Ambil hasil backup                                                    │
   │ status=$(get_result_backupvpn)                                          │
   │ message=$(get_result_message_backupvpn)                                 │
   │ link=$(get_backup_link)                                                 │
   │ error=$(get_backup_error)                                               │
   │                                                                         │
   │ if [[ "$status" == "success" ]]; then                                  │
   │     echo "Backup berhasil: $link"                                       │
   │ else                                                                    │
   │     echo "Backup gagal: $error"                                         │
   │ fi                                                                      │
   └─────────────────────────────────────────────────────────────────────────┘

3. Parameter:
   ┌─────────────────────────────────────────────────────────────────────────┐
   │ email (opsional) : Email untuk menerima notifikasi backup              │
   │                   - Jika tidak diberikan, akan menggunakan email       │
   │                     yang tersimpan di /root/email                      │
   │                   - Jika belum ada email tersimpan dan tidak           │  
   │                     diberikan parameter, akan return error             │
   └─────────────────────────────────────────────────────────────────────────┘

4. Return Value:
   ┌─────────────────────────────────────────────────────────────────────────┐
   │ Fungsi main_bot_backupvpn():                                           │
   │   - Return 0 : Backup berhasil                                         │
   │   - Return 1 : Backup gagal                                            │
   │                                                                         │
   │ Fungsi get_result_backupvpn():                                         │
   │   - "success" : Backup berhasil                                        │
   │   - "failed"  : Backup gagal                                           │
   │   - ""        : Belum ada proses backup                               │
   │                                                                         │
   │ Fungsi get_result_message_backupvpn():                                 │
   │   - String berisi pesan lengkap hasil backup (format Telegram)        │
   │                                                                         │
   │ Fungsi get_backup_link():                                              │
   │   - URL link download backup dari Google Drive                         │
   │                                                                         │
   │ Fungsi get_backup_error():                                             │
   │   - Pesan error jika backup gagal                                      │
   └─────────────────────────────────────────────────────────────────────────┘

5. Persyaratan Sistem:
   ┌─────────────────────────────────────────────────────────────────────────┐
   │ - Debian 9+ / Ubuntu 18.04+                                           │
   │ - rclone sudah dikonfigurasi dengan remote "dr" (Google Drive)         │
   │ - mail command tersedia untuk notifikasi email                         │
   │ - Bot Telegram dikonfigurasi di /etc/bot/.bot.db                       │
   │ - Akses internet untuk upload dan notifikasi                          │
   └─────────────────────────────────────────────────────────────────────────┘

6. File yang Di-backup:
   ┌─────────────────────────────────────────────────────────────────────────┐
   │ Sistem:                                                                │
   │ - /etc/passwd, /etc/group, /etc/shadow, /etc/gshadow                  │
   │                                                                         │
   │ Konfigurasi VPN:                                                       │
   │ - /etc/xray/     - /etc/vmess/    - /etc/trojan/                      │
   │ - /etc/kyt/      - /etc/vless/    - /etc/shadowsocks/                 │
   └─────────────────────────────────────────────────────────────────────────┘

DOKUMENTASI