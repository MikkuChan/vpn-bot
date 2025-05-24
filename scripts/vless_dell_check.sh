#!/bin/bash
# ─────────────※ ·❆· ※─────────────
# 𓈃 Develovers ➠ MikkuChan
# 𓈃 Email      ➠ fadztechs2@gmail.com
# 𓈃 telegram   ➠ https://t.me/fadzdigital
# 𓈃 whatsapp   ➠ wa.me/+6285727035336
# ─────────────※ ·❆· ※─────────────


# ==================== KONFIGURASI WARNA ====================
RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT='\033[0;37m'
BGWHITE='\e[0;100;37m'

# ==================== VARIABEL GLOBAL ====================
# Variabel untuk menyimpan hasil operasi agar bisa diambil oleh script lain
RESULT_STATUS=""
RESULT_MESSAGE=""
RESULT_DATA=""

# Konfigurasi Telegram Bot (isi sesuai dengan bot Anda)
TELEGRAM_BOT_TOKEN="7923489458:AAHYRKCmySlxbXgtbBaUlk7wgujYhBHG6aw"
TELEGRAM_CHAT_ID="6243379861"

# ==================== FUNGSI UTILITAS ====================

# Fungsi untuk mengirim pesan ke Telegram
send_telegram_message() {
    local message="$1"
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
             -d chat_id="$TELEGRAM_CHAT_ID" \
             -d text="$message" \
             -d parse_mode="HTML" > /dev/null 2>&1
    fi
}

# Fungsi untuk format pesan dengan timestamp
format_message() {
    local title="$1"
    local content="$2"
    local timestamp=$(date '+%d/%m/%Y %H:%M:%S')
    
    echo -e "🤖 <b>$title</b>
⏰ <i>$timestamp</i>

$content"
}

# ==================== FUNGSI CEK USER VLESS ====================

# Fungsi utama untuk mengecek semua user VLess yang terdaftar
check_vless_users() {
    local config_file="/etc/xray/config.json"
    
    # Reset variabel global
    RESULT_STATUS=""
    RESULT_MESSAGE=""
    RESULT_DATA=""
    
    # Cek apakah file konfigurasi ada
    if [[ ! -f "$config_file" ]]; then
        RESULT_STATUS="ERROR"
        RESULT_MESSAGE="❌ File konfigurasi XRay tidak ditemukan!"
        RESULT_DATA=""
        return 1
    fi
    
    # Hitung jumlah user VLess
    local user_count=$(grep -c -E "^#& " "$config_file" 2>/dev/null || echo "0")
    
    if [[ $user_count -eq 0 ]]; then
        RESULT_STATUS="EMPTY"
        RESULT_MESSAGE="ℹ️ Tidak ada akun VLess yang terdaftar."
        RESULT_DATA=""
        return 0
    fi
    
    # Ambil data semua user VLess
    local user_list=""
    local counter=1
    
    user_list="📋 <b>DAFTAR AKUN VLESS TERDAFTAR</b>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

"
    
    while read -r line; do
        local username=$(echo "$line" | awk '{print $2}')
        local expiry=$(echo "$line" | awk '{print $3}')
        
        user_list+="$counter. <b>$username</b>
   📅 Expired: <code>$expiry</code>

"
        ((counter++))
    done < <(grep -E "^#& " "$config_file" | sort)
    
    user_list+="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Total: <b>$user_count akun</b>"
    
    RESULT_STATUS="SUCCESS"
    RESULT_MESSAGE="$user_list"
    RESULT_DATA="{\"total_users\":$user_count,\"users\":$(grep -E "^#& " "$config_file" | cut -d ' ' -f 2-3 | sed 's/^/{"username":"/' | sed 's/ /","expiry":"/' | sed 's/$/"}/' | paste -sd, | sed 's/^/[/' | sed 's/$/]/')}"
    
    return 0
}

# ==================== FUNGSI DELETE USER VLESS ====================

# Fungsi utama untuk menghapus user VLess
delete_vless_user() {
    local username="$1"
    local config_file="/etc/xray/config.json"
    
    # Reset variabel global
    RESULT_STATUS=""
    RESULT_MESSAGE=""
    RESULT_DATA=""
    
    # Validasi input username
    if [[ -z "$username" ]]; then
        RESULT_STATUS="ERROR"
        RESULT_MESSAGE="❌ Username tidak boleh kosong!"
        RESULT_DATA=""
        return 1
    fi
    
    # Cek apakah file konfigurasi ada
    if [[ ! -f "$config_file" ]]; then
        RESULT_STATUS="ERROR"
        RESULT_MESSAGE="❌ File konfigurasi XRay tidak ditemukan!"
        RESULT_DATA=""
        return 1
    fi
    
    # Cek apakah user ada
    local user_exists=$(grep -wE "^#& $username" "$config_file" | head -n1)
    if [[ -z "$user_exists" ]]; then
        RESULT_STATUS="NOT_FOUND"
        RESULT_MESSAGE="❌ User <b>$username</b> tidak ditemukan dalam database VLess!"
        RESULT_DATA=""
        return 1
    fi
    
    # Ambil data expiry sebelum dihapus
    local expiry=$(echo "$user_exists" | awk '{print $3}')
    
    # Proses penghapusan
    local backup_file="/tmp/xray_backup_$(date +%s).json"
    cp "$config_file" "$backup_file"
    
    # Hapus dari file konfigurasi utama
    sed -i "/^#& $username $expiry/,/^},{/d" "$config_file"
    
    # Hapus dari database VLess jika ada
    if [[ -f "/etc/vless/.vless.db" ]]; then
        sed -i "/^#& $username $expiry/,/^},{/d" "/etc/vless/.vless.db"
    fi
    
    # Hapus file user spesifik
    [[ -d "/etc/vless/$username" ]] && rm -rf "/etc/vless/$username"
    [[ -f "/etc/kyt/limit/vless/ip/$username" ]] && rm -rf "/etc/kyt/limit/vless/ip/$username"
    
    # Restart layanan XRay
    if systemctl restart xray > /dev/null 2>&1; then
        RESULT_STATUS="SUCCESS"
        RESULT_MESSAGE="✅ <b>AKUN VLESS BERHASIL DIHAPUS</b>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

👤 <b>Username:</b> <code>$username</code>
📅 <b>Expired:</b> <code>$expiry</code>
🔄 <b>Status:</b> XRay service restarted

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        RESULT_DATA="{\"username\":\"$username\",\"expiry\":\"$expiry\",\"status\":\"deleted\",\"backup_file\":\"$backup_file\"}"
    else
        # Jika restart gagal, kembalikan backup
        cp "$backup_file" "$config_file"
        RESULT_STATUS="ERROR"
        RESULT_MESSAGE="❌ Gagal restart layanan XRay! Perubahan dibatalkan."
        RESULT_DATA=""
        return 1
    fi
    
    return 0
}

# ==================== FUNGSI ORKESTRATOR BOT ====================

# Fungsi orkestrator untuk bot Telegram - Delete User
main_bot_delluser_vless() {
    local username="$1"
    
    # Jalankan fungsi delete
    delete_vless_user "$username"
    local exit_code=$?
    
    # Kirim notifikasi ke Telegram jika berhasil atau ada error penting
    if [[ "$RESULT_STATUS" == "SUCCESS" ]]; then
        local telegram_message=$(format_message "VLess User Deleted" "$RESULT_MESSAGE")
        send_telegram_message "$telegram_message"
    elif [[ "$RESULT_STATUS" == "ERROR" ]]; then
        local telegram_message=$(format_message "VLess Delete Error" "$RESULT_MESSAGE")
        send_telegram_message "$telegram_message"
    fi
    
    return $exit_code
}

# Fungsi orkestrator untuk bot Telegram - Check Users
main_bot_cekuser_vless() {
    # Jalankan fungsi check users
    check_vless_users
    local exit_code=$?
    
    # Kirim notifikasi ke Telegram
    if [[ "$RESULT_STATUS" == "SUCCESS" || "$RESULT_STATUS" == "EMPTY" ]]; then
        local telegram_message=$(format_message "VLess User List" "$RESULT_MESSAGE")
        send_telegram_message "$telegram_message"
    elif [[ "$RESULT_STATUS" == "ERROR" ]]; then
        local telegram_message=$(format_message "VLess Check Error" "$RESULT_MESSAGE")
        send_telegram_message "$telegram_message"
    fi
    
    return $exit_code
}

# ==================== FUNGSI GETTER UNTUK SCRIPT LAIN ====================

# Fungsi untuk mengambil status hasil operasi delete user
get_result_delluser_vless() {
    echo "$RESULT_STATUS"
}

# Fungsi untuk mengambil pesan hasil operasi delete user
get_result_message_vlessdell() {
    echo "$RESULT_MESSAGE"
}

# Fungsi untuk mengambil status hasil operasi check user
get_result_cekuser_vless() {
    echo "$RESULT_STATUS"
}

# Fungsi untuk mengambil pesan hasil operasi check user
get_result_message_vlesscek() {
    echo "$RESULT_MESSAGE"
}

# Fungsi untuk mengambil data JSON hasil operasi
get_result_data_vless() {
    echo "$RESULT_DATA"
}

# ==================== EXPORT FUNCTIONS ====================
# Export semua fungsi agar bisa dipanggil dari script lain
export -f delete_vless_user
export -f check_vless_users
export -f main_bot_delluser_vless
export -f main_bot_cekuser_vless
export -f get_result_delluser_vless
export -f get_result_message_vlessdell
export -f get_result_cekuser_vless
export -f get_result_message_vlesscek
export -f get_result_data_vless
export -f send_telegram_message
export -f format_message

# ==================== CLI INTERFACE ====================

# Fungsi untuk menampilkan bantuan
show_help() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BGWHITE}           VLess Management Script Help            ${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e ""
    echo -e "${GREEN}Penggunaan:${NC}"
    echo -e "  $0 delete <username>     - Hapus user VLess"
    echo -e "  $0 check                 - Cek semua user VLess"
    echo -e "  $0 help                  - Tampilkan bantuan ini"
    echo -e ""
    echo -e "${GREEN}Contoh:${NC}"
    echo -e "  $0 delete john_doe"
    echo -e "  $0 check"
    echo -e ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Main CLI handler
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        "delete")
            if [[ -z "$2" ]]; then
                echo -e "${RED}❌ Error: Username diperlukan untuk perintah delete${NC}"
                echo -e "Penggunaan: $0 delete <username>"
                exit 1
            fi
            main_bot_delluser_vless "$2"
            exit_code=$?
            echo -e "\n${GREEN}Status:${NC} $(get_result_delluser_vless)"
            echo -e "${GREEN}Message:${NC}"
            echo -e "$(get_result_message_vlessdell)" | sed 's/<[^>]*>//g'
            exit $exit_code
            ;;
        "check")
            main_bot_cekuser_vless
            exit_code=$?
            echo -e "\n${GREEN}Status:${NC} $(get_result_cekuser_vless)"
            echo -e "${GREEN}Message:${NC}"
            echo -e "$(get_result_message_vlesscek)" | sed 's/<[^>]*>//g'
            exit $exit_code
            ;;
        "help"|"--help"|"-h")
            show_help
            exit 0
            ;;
        "")
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Error: Perintah '$1' tidak dikenal${NC}"
            show_help
            exit 1
            ;;
    esac
fi

# ==================== DOKUMENTASI PENGGUNAAN ====================

# DOKUMENTASI:
# 
# 1. CLI Interface:
#    - Hapus user: ./script.sh delete username
#    - Cek user:   ./script.sh check  
#    - Bantuan:    ./script.sh help
#
# 2. Import ke script lain:
#    source /path/to/script.sh
#    
#    # Untuk delete user
#    main_bot_delluser_vless "username"
#    status=$(get_result_delluser_vless)
#    message=$(get_result_message_vlessdell)
#    
#    # Untuk check user
#    main_bot_cekuser_vless
#    status=$(get_result_cekuser_vless) 
#    message=$(get_result_message_vlesscek)
#    data=$(get_result_data_vless)
#
# 3. Parameter:
#    - delete_vless_user: membutuhkan username (string)
#    - check_vless_users: tidak membutuhkan parameter
#    - main_bot_*: fungsi wrapper dengan notifikasi Telegram
#
# 4. Return Value:
#    Status yang mungkin:
#    - SUCCESS: operasi berhasil
#    - ERROR: terjadi kesalahan
#    - NOT_FOUND: user tidak ditemukan (untuk delete)
#    - EMPTY: tidak ada user terdaftar (untuk check)
#    
#    Data dikembalikan dalam format:
#    - RESULT_STATUS: status operasi
#    - RESULT_MESSAGE: pesan untuk user (HTML formatted)
#    - RESULT_DATA: data JSON untuk processing lebih lanjut
#
# 5. Konfigurasi Telegram:
#    Edit variabel TELEGRAM_BOT_TOKEN dan TELEGRAM_CHAT_ID
#    di bagian atas script sesuai dengan bot Telegram Anda
#
# 6. File yang digunakan:
#    - /etc/xray/config.json: konfigurasi utama XRay
#    - /etc/vless/.vless.db: database VLess (opsional)
#    - /etc/vless/[username]/: direktori user spesifik
#    - /etc/kyt/limit/vless/ip/[username]: file limit IP user