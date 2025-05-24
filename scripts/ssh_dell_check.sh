#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# System Request : Debian 9+/Ubuntu 18.04+/20+
# Developers » Gemilangkinasih࿐
# Email      » gemilangkinasih@gmail.com
# telegram   » https://t.me/gemilangkinasih
# whatsapp   » wa.me/+628984880039
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Gemilangkinasih࿐ - SSH User Management Bot Integration

# ====== KONFIGURASI WARNA ======
RED="\033[31m"
YELLOW="\033[33m"
NC='\e[0m'
YELL='\033[0;33m'
BRED='\033[1;31m'
GREEN='\033[0;32m'
ORANGE='\033[33m'
BGWHITE='\e[0;100;37m'

# ====== VARIABEL GLOBAL UNTUK RESULT ======
RESULT_STATUS=""
RESULT_MESSAGE=""
SCRIPT_NAME=$(basename "$0" .sh)

# ====== FUNGSI UTILITAS ======
# Fungsi untuk mendapatkan nama script otomatis
get_script_name() {
    echo "$(basename "$0" .sh)"
}

# Fungsi untuk logging
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >&2
}

# ====== FUNGSI CEK USER SSH TERDAFTAR ======
# Fungsi untuk mengecek semua user SSH yang terdaftar
check_ssh_users() {
    log_message "INFO" "Memulai pengecekan user SSH terdaftar"
    
    local user_list=""
    local user_count=0
    local message_header=""
    
    # Header pesan
    message_header="🔍 *DAFTAR USER SSH TERDAFTAR*\n"
    message_header+="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    message_header+="USERNAME          EXP DATE\n"
    message_header+="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    
    # Baca file passwd dan proses setiap user
    while IFS=: read -r username password uid gid gecos home shell; do
        # Filter user dengan UID >= 1000 (user biasa, bukan system user)
        if [[ $uid -ge 1000 ]]; then
            # Dapatkan tanggal expired
            local exp_date=$(chage -l "$username" 2>/dev/null | grep "Account expires" | awk -F": " '{print $2}')
            
            # Cek status password (L = Locked, P = Password set, NP = No password)
            local status=$(passwd -S "$username" 2>/dev/null | awk '{print $2}')
            
            # Format tanggal jika kosong
            if [[ -z "$exp_date" || "$exp_date" == "never" ]]; then
                exp_date="Never"
            fi
            
            # Status indicator
            local status_icon=""
            case "$status" in
                "L") status_icon="🔒" ;;  # Locked
                "P") status_icon="✅" ;;  # Active
                "NP") status_icon="⚠️" ;; # No password
                *) status_icon="❓" ;;    # Unknown
            esac
            
            # Tambahkan ke list
            user_list+="\`$(printf "%-15s" "$username")\` $status_icon \`$exp_date\`\n"
            ((user_count++))
            
            log_message "DEBUG" "User ditemukan: $username (UID: $uid, Status: $status, Exp: $exp_date)"
        fi
    done < /etc/passwd
    
    # Susun pesan final
    local final_message="$message_header"
    if [[ $user_count -gt 0 ]]; then
        final_message+="$user_list"
        final_message+="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        final_message+="📊 *Total User SSH*: $user_count\n"
        final_message+="🕒 *Waktu Cek*: $(date '+%d/%m/%Y %H:%M:%S')\n"
        final_message+="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        RESULT_STATUS="success"
        log_message "SUCCESS" "Berhasil mengecek user SSH. Total: $user_count user"
    else
        final_message+="❌ *Tidak ada user SSH ditemukan*\n"
        final_message+="🕒 *Waktu Cek*: $(date '+%d/%m/%Y %H:%M:%S')\n"
        final_message+="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        RESULT_STATUS="empty"
        log_message "WARNING" "Tidak ada user SSH ditemukan"
    fi
    
    RESULT_MESSAGE="$final_message"
    return 0
}

# ====== FUNGSI DELETE USER SSH ======
# Fungsi untuk menghapus user SSH
delete_ssh_user() {
    local username="$1"
    
    # Validasi parameter
    if [[ -z "$username" ]]; then
        RESULT_STATUS="error"
        RESULT_MESSAGE="❌ *ERROR DELETE SSH USER*\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n⚠️ Username tidak boleh kosong!\n🕒 *Waktu*: $(date '+%d/%m/%Y %H:%M:%S')"
        log_message "ERROR" "Username tidak boleh kosong"
        return 1
    fi
    
    log_message "INFO" "Memulai proses delete user SSH: $username"
    
    # Cek apakah user ada
    if ! getent passwd "$username" > /dev/null 2>&1; then
        RESULT_STATUS="not_found"
        RESULT_MESSAGE="❌ *USER SSH TIDAK DITEMUKAN*\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n👤 *Username*: \`$username\`\n⚠️ *Status*: User tidak terdaftar di sistem\n💡 *Saran*: Cek kembali username yang benar\n🕒 *Waktu*: $(date '+%d/%m/%Y %H:%M:%S')\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_message "WARNING" "User $username tidak ditemukan"
        return 1
    fi
    
    # Ambil info user sebelum dihapus
    local user_info=$(getent passwd "$username")
    local uid=$(echo "$user_info" | cut -d: -f3)
    local home_dir=$(echo "$user_info" | cut -d: -f6)
    
    # Cek apakah ini user SSH (UID >= 1000)
    if [[ $uid -lt 1000 ]]; then
        RESULT_STATUS="system_user"
        RESULT_MESSAGE="❌ *TIDAK DAPAT MENGHAPUS USER SISTEM*\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n👤 *Username*: \`$username\`\n🔢 *UID*: $uid\n⚠️ *Status*: User sistem (UID < 1000)\n🛑 *Alasan*: Demi keamanan sistem\n🕒 *Waktu*: $(date '+%d/%m/%Y %H:%M:%S')\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_message "ERROR" "Tidak dapat menghapus user sistem: $username (UID: $uid)"
        return 1
    fi
    
    # Proses penghapusan user
    log_message "INFO" "Menghapus user: $username (UID: $uid, Home: $home_dir)"
    
    # Kill semua proses yang berjalan dengan user tersebut
    pkill -u "$username" 2>/dev/null
    
    # Hapus user dan home directory
    if userdel -r "$username" > /dev/null 2>&1; then
        RESULT_STATUS="success"
        RESULT_MESSAGE="✅ *USER SSH BERHASIL DIHAPUS*\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n👤 *Username*: \`$username\`\n🔢 *UID*: $uid\n📁 *Home Directory*: $home_dir\n✨ *Status*: Berhasil dihapus dari sistem\n🗑️ *Aksi*: User dan data terkait telah dihapus\n🕒 *Waktu*: $(date '+%d/%m/%Y %H:%M:%S')\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_message "SUCCESS" "User $username berhasil dihapus"
        return 0
    else
        RESULT_STATUS="failed"
        RESULT_MESSAGE="❌ *GAGAL MENGHAPUS USER SSH*\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n👤 *Username*: \`$username\`\n⚠️ *Status*: Proses penghapusan gagal\n🔧 *Saran*: Cek permission atau coba lagi\n🕒 *Waktu*: $(date '+%d/%m/%Y %H:%M:%S')\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_message "ERROR" "Gagal menghapus user $username"
        return 1
    fi
}

# ====== FUNGSI TELEGRAM NOTIFICATION ======
# Fungsi untuk mengirim notifikasi ke Telegram
send_telegram_notification() {
    local message="$1"
    local chat_id="$2"
    local bot_token="$3"
    
    # Jika parameter telegram tidak lengkap, skip notifikasi
    if [[ -z "$chat_id" || -z "$bot_token" ]]; then
        log_message "WARNING" "Parameter Telegram tidak lengkap, skip notifikasi"
        return 0
    fi
    
    # Escape karakter khusus untuk Markdown
    local escaped_message=$(echo -e "$message" | sed 's/\*/\\*/g; s/_/\\_/g; s/\[/\\[/g; s/\]/\\]/g')
    
    # Kirim ke Telegram
    local response=$(curl -s -X POST "https://api.telegram.org/bot$bot_token/sendMessage" \
        -d "chat_id=$chat_id" \
        -d "text=$escaped_message" \
        -d "parse_mode=Markdown" \
        -d "disable_web_page_preview=true")
    
    if [[ $? -eq 0 ]]; then
        log_message "SUCCESS" "Notifikasi Telegram berhasil dikirim"
    else
        log_message "ERROR" "Gagal mengirim notifikasi Telegram"
    fi
}

# ====== FUNGSI ORKESTRATOR UTAMA ======
# Fungsi utama untuk bot - Delete User SSH
main_bot_delluser_ssh() {
    local username="$1"
    local chat_id="$2"
    local bot_token="$3"
    
    log_message "INFO" "Bot memulai proses delete user SSH: $username"
    
    # Reset result variables
    RESULT_STATUS=""
    RESULT_MESSAGE=""
    
    # Panggil fungsi delete
    delete_ssh_user "$username"
    
    # Kirim notifikasi ke Telegram jika parameter tersedia
    if [[ -n "$chat_id" && -n "$bot_token" ]]; then
        send_telegram_notification "$RESULT_MESSAGE" "$chat_id" "$bot_token"
    fi
    
    return 0
}

# Fungsi utama untuk bot - Check User SSH
main_bot_cekuser_ssh() {
    local chat_id="$1"
    local bot_token="$2"
    
    log_message "INFO" "Bot memulai proses cek user SSH"
    
    # Reset result variables
    RESULT_STATUS=""
    RESULT_MESSAGE=""
    
    # Panggil fungsi check
    check_ssh_users
    
    # Kirim notifikasi ke Telegram jika parameter tersedia
    if [[ -n "$chat_id" && -n "$bot_token" ]]; then
        send_telegram_notification "$RESULT_MESSAGE" "$chat_id" "$bot_token"
    fi
    
    return 0
}

# ====== FUNGSI GETTER UNTUK RESULT ======
# Fungsi untuk mengambil status result delete user
get_result_delluser_ssh() {
    echo "$RESULT_STATUS"
}

# Fungsi untuk mengambil message result delete user
get_result_message_sshdell() {
    echo -e "$RESULT_MESSAGE"
}

# Fungsi untuk mengambil status result check user
get_result_cekuser_ssh() {
    echo "$RESULT_STATUS"
}

# Fungsi untuk mengambil message result check user
get_result_message_sshcek() {
    echo -e "$RESULT_MESSAGE"
}

# ====== FUNGSI CLI INTERFACE ======
show_usage() {
    local script_name=$(get_script_name)
    echo -e "${ORANGE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${ORANGE}${BGWHITE}         SSH USER MANAGEMENT TOOL         ${NC}"
    echo -e "${ORANGE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Usage:${NC}"
    echo -e "  ${YELLOW}./$script_name.sh [command] [options]${NC}"
    echo ""
    echo -e "${GREEN}Commands:${NC}"
    echo -e "  ${YELLOW}check${NC}                    - Cek semua user SSH terdaftar"
    echo -e "  ${YELLOW}delete <username>${NC}       - Hapus user SSH"
    echo -e "  ${YELLOW}help${NC}                     - Tampilkan bantuan ini"
    echo ""
    echo -e "${GREEN}Examples:${NC}"
    echo -e "  ${YELLOW}./$script_name.sh check${NC}"
    echo -e "  ${YELLOW}./$script_name.sh delete usertest${NC}"
    echo -e "${ORANGE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ====== MAIN SCRIPT LOGIC ======
# Jika script dipanggil langsung (bukan di-source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        "check")
            main_bot_cekuser_ssh
            echo -e "$RESULT_MESSAGE"
            ;;
        "delete")
            if [[ -z "$2" ]]; then
                echo -e "${RED}Error: Username harus diisi!${NC}"
                echo -e "${YELLOW}Usage: $0 delete <username>${NC}"
                exit 1
            fi
            main_bot_delluser_ssh "$2"
            echo -e "$RESULT_MESSAGE"
            ;;
        "help"|"-h"|"--help"|"")
            show_usage
            ;;
        *)
            echo -e "${RED}Error: Command tidak dikenal: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
fi

# ====== EXPORT FUNCTIONS UNTUK BOT ======
# Export semua fungsi untuk bisa dipanggil dari script lain
export -f check_ssh_users
export -f delete_ssh_user
export -f main_bot_delluser_ssh
export -f main_bot_cekuser_ssh
export -f get_result_delluser_ssh
export -f get_result_message_sshdell
export -f get_result_cekuser_ssh
export -f get_result_message_sshcek
export -f send_telegram_notification

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DOKUMENTASI PENGGUNAAN
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# 1. CLI INTERFACE:
#    - Cek semua user SSH: ./nama_script.sh check
#    - Hapus user SSH: ./nama_script.sh delete username
#    - Bantuan: ./nama_script.sh help
#    
#    Contoh dengan nama file dell_check.sh:
#    - ./dell_check.sh check
#    - ./dell_check.sh delete usertest
#    - ./dell_check.sh help
#
# 2. IMPORT KE SCRIPT LAIN:
#    #!/bin/bash
#    source /path/to/script_ini.sh
#    
#    # Untuk delete user
#    main_bot_delluser_ssh "username" "chat_id" "bot_token"
#    statusdelluser=$(get_result_delluser_ssh)
#    messagedelluser=$(get_result_message_sshdell)
#    
#    # Untuk cek user
#    main_bot_cekuser_ssh "chat_id" "bot_token"
#    statuscekuser=$(get_result_cekuser_ssh)
#    messagecekuser=$(get_result_message_sshcek)
#
# 3. PARAMETER:
#    main_bot_delluser_ssh:
#    - $1: username (required)
#    - $2: chat_id telegram (optional)
#    - $3: bot_token telegram (optional)
#    
#    main_bot_cekuser_ssh:
#    - $1: chat_id telegram (optional)
#    - $2: bot_token telegram (optional)
#
# 4. RETURN VALUE:
#    Status (get_result_delluser_ssh / get_result_cekuser_ssh):
#    - "success": Berhasil
#    - "error": Error parameter
#    - "not_found": User tidak ditemukan
#    - "system_user": User sistem tidak bisa dihapus
#    - "failed": Gagal eksekusi
#    - "empty": Tidak ada user (khusus check)
#    
#    Message (get_result_message_sshdell / get_result_message_sshcek):
#    - String formatted untuk Telegram dengan Markdown
#    - Siap dikirim ke bot atau ditampilkan di CLI
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━