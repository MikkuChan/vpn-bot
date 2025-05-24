#!/bin/bash

# =====================================================
# TROJAN ACCOUNT MANAGER WITH TELEGRAM INTEGRATION
# =====================================================
# Script untuk mengelola akun Trojan dengan dukungan bot Telegram
# Mendukung delete dan check user dengan return terstruktur

# =====================================================
# KONFIGURASI WARNA DAN TELEGRAM
# =====================================================
RED="\033[31m"
YELLOW="\033[33m"
NC='\e[0m'
YELL='\033[0;33m'
BRED='\033[1;31m'
GREEN='\033[0;32m'
ORANGE='\033[33m'
BGWHITE='\e[0;100;37m'

# Konfigurasi Telegram Bot (sesuaikan dengan bot Anda)
TELEGRAM_BOT_TOKEN="7923489458:AAHYRKCmySlxbXgtbBaUlk7wgujYhBHG6aw"
TELEGRAM_CHAT_ID="6243379861"

# =====================================================
# VARIABEL GLOBAL UNTUK HASIL OPERASI
# =====================================================
RESULT_STATUS_DELETE=""
RESULT_MESSAGE_DELETE=""
RESULT_STATUS_CHECK=""
RESULT_MESSAGE_CHECK=""

# =====================================================
# FUNGSI UTILITY UNTUK TELEGRAM
# =====================================================

# Fungsi untuk mengirim pesan ke Telegram
send_telegram_message() {
    local message="$1"
    local parse_mode="${2:-HTML}"
    
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$message" \
            -d parse_mode="$parse_mode" > /dev/null 2>&1
    fi
}

# =====================================================
# FUNGSI CORE UNTUK MENGHAPUS USER TROJAN
# =====================================================

# Fungsi utama untuk menghapus user Trojan
delete_trojan_user() {
    local username="$1"
    
    # Reset hasil operasi
    RESULT_STATUS_DELETE=""
    RESULT_MESSAGE_DELETE=""
    
    # Validasi input username
    if [[ -z "$username" ]]; then
        RESULT_STATUS_DELETE="FAILED"
        RESULT_MESSAGE_DELETE="❌ <b>ERROR DELETE TROJAN</b>\n\n• Username tidak boleh kosong!\n• Silakan masukkan username yang valid."
        return 1
    fi
    
    # Cek apakah ada user Trojan yang terdaftar
    local number_of_clients=$(grep -c -E "^#! " "/etc/xray/config.json" 2>/dev/null || echo "0")
    if [[ ${number_of_clients} == '0' ]]; then
        RESULT_STATUS_DELETE="FAILED"
        RESULT_MESSAGE_DELETE="❌ <b>ERROR DELETE TROJAN</b>\n\n• Tidak ada member Trojan yang terdaftar\n• Database kosong atau belum ada akun"
        return 1
    fi
    
    # Cek apakah user ada dalam database
    local user_exists=$(grep -wE "^#! $username" "/etc/xray/config.json" 2>/dev/null)
    if [[ -z "$user_exists" ]]; then
        RESULT_STATUS_DELETE="FAILED"
        RESULT_MESSAGE_DELETE="❌ <b>ERROR DELETE TROJAN</b>\n\n• Username: <code>$username</code>\n• User tidak ditemukan dalam database\n• Periksa kembali username yang dimasukkan"
        return 1
    fi
    
    # Ambil informasi expiry date
    local exp=$(grep -wE "^#! $username" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
    
    # Proses penghapusan user
    if sed -i "/^#! $username $exp/,/^},{/d" /etc/xray/config.json 2>/dev/null && \
       sed -i "/### $username $exp/,/^},{/d" /etc/trojan/.trojan.db 2>/dev/null; then
        
        # Hapus file dan direktori terkait
        rm -rf "/etc/trojan/$username" 2>/dev/null
        rm -rf "/etc/kyt/limit/trojan/ip/$username" 2>/dev/null
        
        # Restart service Xray
        if systemctl restart xray > /dev/null 2>&1; then
            RESULT_STATUS_DELETE="SUCCESS"
            RESULT_MESSAGE_DELETE="✅ <b>TROJAN USER DELETED</b>\n\n• Username: <code>$username</code>\n• Expired: <code>$exp</code>\n• Status: Berhasil dihapus\n• Service: Xray restarted\n\n🕐 Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
            
            # Kirim notifikasi ke Telegram
            send_telegram_message "$RESULT_MESSAGE_DELETE"
            return 0
        else
            RESULT_STATUS_DELETE="FAILED"
            RESULT_MESSAGE_DELETE="⚠️ <b>WARNING DELETE TROJAN</b>\n\n• Username: <code>$username</code>\n• User dihapus dari database\n• Gagal restart service Xray\n• Silakan restart manual"
            return 1
        fi
    else
        RESULT_STATUS_DELETE="FAILED"
        RESULT_MESSAGE_DELETE="❌ <b>ERROR DELETE TROJAN</b>\n\n• Username: <code>$username</code>\n• Gagal menghapus dari database\n• Periksa permission file atau status service"
        return 1
    fi
}

# =====================================================
# FUNGSI CORE UNTUK CEK USER TROJAN
# =====================================================

# Fungsi untuk mengecek semua user Trojan yang terdaftar
check_trojan_users() {
    # Reset hasil operasi
    RESULT_STATUS_CHECK=""
    RESULT_MESSAGE_CHECK=""
    
    # Cek jumlah user yang terdaftar
    local number_of_clients=$(grep -c -E "^#! " "/etc/xray/config.json" 2>/dev/null || echo "0")
    
    if [[ ${number_of_clients} == '0' ]]; then
        RESULT_STATUS_CHECK="EMPTY"
        RESULT_MESSAGE_CHECK="📋 <b>TROJAN USER LIST</b>\n\n• Status: Database kosong\n• Total User: 0 akun\n• Info: Belum ada user Trojan yang terdaftar\n\n🕐 Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    else
        # Ambil daftar user dan format untuk Telegram
        local user_list=""
        local counter=1
        
        while IFS= read -r line; do
            local username=$(echo "$line" | cut -d ' ' -f 1)
            local expired=$(echo "$line" | cut -d ' ' -f 2)
            
            # Cek status expired
            local current_date=$(date +%Y-%m-%d)
            local status_icon="🟢"
            local status_text="Active"
            
            if [[ "$expired" < "$current_date" ]]; then
                status_icon="🔴"
                status_text="Expired"
            elif [[ "$expired" == "$current_date" ]]; then
                status_icon="🟡"
                status_text="Today"
            fi
            
            user_list+="$counter. $status_icon <code>$username</code>\n   📅 $expired ($status_text)\n\n"
            ((counter++))
        done < <(grep -e "^#! " "/etc/xray/config.json" | cut -d ' ' -f 2-3 | sort)
        
        RESULT_STATUS_CHECK="SUCCESS"
        RESULT_MESSAGE_CHECK="📋 <b>TROJAN USER LIST</b>\n\n• Total User: <b>$number_of_clients akun</b>\n• Status: Database aktif\n\n<b>DAFTAR USER:</b>\n$user_list🕐 Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    fi
    
    # Kirim notifikasi ke Telegram
    send_telegram_message "$RESULT_MESSAGE_CHECK"
    
    if [[ "$RESULT_STATUS_CHECK" == "SUCCESS" || "$RESULT_STATUS_CHECK" == "EMPTY" ]]; then
        return 0
    else
        return 1
    fi
}

# =====================================================
# FUNGSI ORKESTRATOR UTAMA UNTUK BOT
# =====================================================

# Fungsi orkestrator untuk delete user (dipanggil oleh bot)
main_bot_delluser_trojan() {
    local username="$1"
    delete_trojan_user "$username"
    return $?
}

# Fungsi orkestrator untuk check users (dipanggil oleh bot)
main_bot_cekuser_trojan() {
    check_trojan_users
    return $?
}

# =====================================================
# FUNGSI GETTER UNTUK MENGAMBIL HASIL OPERASI
# =====================================================

# Fungsi untuk mendapatkan status hasil delete user
get_result_delluser_trojan() {
    echo "$RESULT_STATUS_DELETE"
}

# Fungsi untuk mendapatkan pesan hasil delete user
get_result_message_trojandell() {
    echo "$RESULT_MESSAGE_DELETE"
}

# Fungsi untuk mendapatkan status hasil check users
get_result_cekuser_trojan() {
    echo "$RESULT_STATUS_CHECK"
}

# Fungsi untuk mendapatkan pesan hasil check users
get_result_message_trojancek() {
    echo "$RESULT_MESSAGE_CHECK"
}

# =====================================================
# FUNGSI CLI INTERFACE
# =====================================================

# Fungsi untuk menampilkan bantuan penggunaan
show_help() {
    local script_name=$(basename "$0")
    echo -e "${GREEN}TROJAN ACCOUNT MANAGER${NC}"
    echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Usage:"
    echo -e "  ${YELLOW}./$script_name delete <username>${NC}  - Hapus user trojan"
    echo -e "  ${YELLOW}./$script_name check${NC}              - Cek semua user trojan"
    echo -e "  ${YELLOW}./$script_name help${NC}               - Tampilkan bantuan ini"
    echo -e ""
    echo -e "Examples:"
    echo -e "  ./$script_name delete john123"
    echo -e "  ./$script_name check"
    echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# =====================================================
# FUNGSI UTAMA UNTUK CLI
# =====================================================

# Fungsi utama yang menangani CLI interface
main() {
    local command="$1"
    local username="$2"
    
    case "$command" in
        "delete"|"del"|"remove"|"rm")
            if [[ -z "$username" ]]; then
                echo -e "${RED}Error: Username diperlukan untuk operasi delete${NC}"
                echo -e "Usage: $(basename $0) delete <username>"
                exit 1
            fi
            
            echo -e "${YELLOW}Menghapus user Trojan: $username${NC}"
            main_bot_delluser_trojan "$username"
            
            # Tampilkan hasil
            local status=$(get_result_delluser_trojan)
            local message=$(get_result_message_trojandell)
            
            if [[ "$status" == "SUCCESS" ]]; then
                echo -e "${GREEN}✅ Berhasil menghapus user!${NC}"
            else
                echo -e "${RED}❌ Gagal menghapus user!${NC}"
            fi
            
            # Tampilkan pesan (tanpa HTML tags untuk CLI)
            echo -e "\n${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "$message" | sed 's/<[^>]*>//g' | sed 's/&lt;/</g' | sed 's/&gt;/>/g'
            echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            ;;
            
        "check"|"list"|"show")
            echo -e "${YELLOW}Mengecek daftar user Trojan...${NC}"
            main_bot_cekuser_trojan
            
            # Tampilkan hasil
            local status=$(get_result_cekuser_trojan)
            local message=$(get_result_message_trojancek)
            
            echo -e "\n${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "$message" | sed 's/<[^>]*>//g' | sed 's/&lt;/</g' | sed 's/&gt;/>/g'
            echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            ;;
            
        "help"|"-h"|"--help"|"")
            show_help
            ;;
            
        *)
            echo -e "${RED}Error: Perintah tidak dikenal: $command${NC}"
            echo -e "Gunakan '$(basename $0) help' untuk melihat bantuan"
            exit 1
            ;;
    esac
}

# =====================================================
# EXPORT FUNCTIONS UNTUK SCRIPT LAIN
# =====================================================

# Export semua fungsi yang diperlukan untuk integrasi dengan script lain
export -f delete_trojan_user
export -f check_trojan_users
export -f main_bot_delluser_trojan
export -f main_bot_cekuser_trojan
export -f get_result_delluser_trojan
export -f get_result_message_trojandell
export -f get_result_cekuser_trojan
export -f get_result_message_trojancek
export -f send_telegram_message

# =====================================================
# EKSEKUSI UTAMA
# =====================================================

# Jalankan fungsi utama jika script dipanggil langsung
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# =====================================================
# DOKUMENTASI PENGGUNAAN
# =====================================================

# 1. CLI Interface:
#    ./nama_file.sh delete username    - Hapus user trojan
#    ./nama_file.sh check              - Cek semua user trojan
#    ./nama_file.sh help               - Tampilkan bantuan
#    
#    Contoh:
#    ./trojan_manager.sh delete john123
#    ./trojan_manager.sh check

# 2. Import ke script lain:
#    source /path/to/nama_file.sh
#    
#    # Panggil fungsi
#    main_bot_delluser_trojan "username"
#    main_bot_cekuser_trojan
#    
#    # Ambil hasil
#    status=$(get_result_delluser_trojan)
#    message=$(get_result_message_trojandell)
#    
#    Contoh penggunaan di script bot:
#    #!/bin/bash
#    source ./trojan_manager.sh
#    
#    # Delete user
#    main_bot_delluser_trojan "testuser"
#    if [[ "$(get_result_delluser_trojan)" == "SUCCESS" ]]; then
#        echo "User berhasil dihapus!"
#        bot_send_message "$(get_result_message_trojandell)"
#    fi

# 3. Parameter:
#    delete_trojan_user <username>     - Username yang akan dihapus
#    check_trojan_users                - Tidak ada parameter
#    
#    Return Value untuk delete:
#    - SUCCESS: User berhasil dihapus
#    - FAILED: Gagal menghapus user (username kosong, tidak ditemukan, error database)
#    
#    Return Value untuk check:
#    - SUCCESS: Ada user dalam database
#    - EMPTY: Database kosong (tidak ada user)

# 4. Return Value:
#    Status: SUCCESS/FAILED/EMPTY
#    Message: Pesan lengkap dalam format HTML untuk Telegram
#    
#    Fungsi getter:
#    - get_result_delluser_trojan()      - Status delete (SUCCESS/FAILED)
#    - get_result_message_trojandell()   - Pesan hasil delete
#    - get_result_cekuser_trojan()       - Status check (SUCCESS/EMPTY)
#    - get_result_message_trojancek()    - Pesan hasil check