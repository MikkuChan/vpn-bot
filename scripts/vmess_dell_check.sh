#!/bin/bash
# ─────────────※ ·❆· ※─────────────
# 𓈃 VMESS Bot Integration Functions
# 𓈃 Develovers ➠ MikkuChan
# 𓈃 Email      ➠ fadztechs2@gmail.com
# 𓈃 telegram   ➠ https://t.me/fadzdigital
# 𓈃 whatsapp   ➠ wa.me/+6285727035336
# ─────────────※ ·❆· ※─────────────

# ═══════════════════════════════════════════════════════════════
# KONFIGURASI GLOBAL
# ═══════════════════════════════════════════════════════════════

# Ambil tanggal dari server
dateFromServer=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
biji=`date +"%Y-%m-%d" -d "$dateFromServer"`

# Definisi warna untuk output
RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT='\033[0;37m'
red='\e[1;31m'
green='\e[0;32m'
BGWHITE='\e[0;100;37m'

# Fungsi untuk output berwarna
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }

# Konfigurasi Bot Telegram (Sesuaikan dengan bot Anda)
BOT_TOKEN="YOUR_BOT_TOKEN_HERE"
ADMIN_CHAT_ID="YOUR_ADMIN_CHAT_ID_HERE"

# ═══════════════════════════════════════════════════════════════
# VARIABEL GLOBAL UNTUK MENYIMPAN HASIL
# ═══════════════════════════════════════════════════════════════

# Variabel untuk menyimpan hasil operasi delete vmess
DELLUSER_STATUS=""
DELLUSER_MESSAGE=""

# Variabel untuk menyimpan hasil operasi cek user vmess
CEKUSER_STATUS=""
CEKUSER_MESSAGE=""

# ═══════════════════════════════════════════════════════════════
# FUNGSI UTILITAS UNTUK TELEGRAM
# ═══════════════════════════════════════════════════════════════

# Fungsi untuk mengirim pesan ke Telegram
send_telegram_message() {
    local chat_id="$1"
    local message="$2"
    local parse_mode="${3:-HTML}"
    
    if [[ -z "$BOT_TOKEN" || -z "$chat_id" ]]; then
        echo "Bot token atau chat ID tidak dikonfigurasi"
        return 1
    fi
    
    # Escape karakter khusus untuk HTML
    message=$(echo "$message" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"$chat_id\",
            \"text\": \"$message\",
            \"parse_mode\": \"$parse_mode\"
        }"
}

# ═══════════════════════════════════════════════════════════════
# FUNGSI UTAMA: DELETE USER VMESS
# ═══════════════════════════════════════════════════════════════

# Fungsi untuk menghapus user vmess
delete_vmess_user() {
    local username="$1"
    
    # Validasi input
    if [[ -z "$username" ]]; then
        DELLUSER_STATUS="ERROR"
        DELLUSER_MESSAGE="❌ <b>Error Delete VMESS</b>\n\n• Username tidak boleh kosong!"
        return 1
    fi
    
    # Cek apakah ada user vmess yang terdaftar
    local number_of_clients=$(grep -c -E "^### " "/etc/xray/config.json" 2>/dev/null || echo "0")
    
    if [[ ${number_of_clients} == '0' ]]; then
        DELLUSER_STATUS="ERROR"
        DELLUSER_MESSAGE="❌ <b>Error Delete VMESS</b>\n\n• Tidak ada member VMESS yang terdaftar!"
        return 1
    fi
    
    # Cek apakah user ada dalam database
    local user_exists=$(grep -wE "^### $username" "/etc/xray/config.json" 2>/dev/null | wc -l)
    
    if [[ $user_exists -eq 0 ]]; then
        DELLUSER_STATUS="ERROR"
        DELLUSER_MESSAGE="❌ <b>Error Delete VMESS</b>\n\n• Username <code>$username</code> tidak ditemukan!"
        return 1
    fi
    
    # Ambil informasi expired dari user
    local exp=$(grep -wE "^### $username" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
    
    # Hapus konfigurasi user dari file config
    sed -i "/^### $username $exp/,/^},{/d" /etc/xray/config.json
    sed -i "/^### $username $exp/,/^},{/d" /etc/vmess/.vmess.db
    
    # Hapus file dan direktori terkait user
    rm -rf /etc/vmess/$username
    rm -rf /etc/kyt/limit/vmess/ip/$username
    
    # Restart service xray
    systemctl restart xray > /dev/null 2>&1
    
    # Set status berhasil dan pesan
    DELLUSER_STATUS="SUCCESS"
    DELLUSER_MESSAGE="✅ <b>VMESS Account Deleted</b>\n\n"
    DELLUSER_MESSAGE+="• <b>Username:</b> <code>$username</code>\n"
    DELLUSER_MESSAGE+="• <b>Expired:</b> <code>$exp</code>\n"
    DELLUSER_MESSAGE+="• <b>Status:</b> Berhasil dihapus\n"
    DELLUSER_MESSAGE+="• <b>Waktu:</b> $(date '+%Y-%m-%d %H:%M:%S')"
    
    return 0
}

# ═══════════════════════════════════════════════════════════════
# FUNGSI UTAMA: CEK USER VMESS
# ═══════════════════════════════════════════════════════════════

# Fungsi untuk mengecek semua user vmess yang terdaftar
check_vmess_users() {
    local number_of_clients=$(grep -c -E "^### " "/etc/xray/config.json" 2>/dev/null || echo "0")
    
    if [[ ${number_of_clients} == '0' ]]; then
        CEKUSER_STATUS="EMPTY"
        CEKUSER_MESSAGE="ℹ️ <b>Daftar User VMESS</b>\n\n• Tidak ada member VMESS yang terdaftar!"
        return 1
    fi
    
    # Ambil daftar user dan expired date
    local user_list=$(grep -e "^### " "/etc/xray/config.json" | cut -d ' ' -f 2-3 | sort | uniq)
    
    # Format pesan untuk Telegram
    CEKUSER_MESSAGE="📋 <b>Daftar User VMESS</b>\n\n"
    CEKUSER_MESSAGE+="• <b>Total User:</b> $number_of_clients\n"
    CEKUSER_MESSAGE+="• <b>Tanggal Cek:</b> $(date '+%Y-%m-%d %H:%M:%S')\n\n"
    
    local counter=1
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local username=$(echo "$line" | awk '{print $1}')
            local expired=$(echo "$line" | awk '{print $2}')
            
            # Cek status expired
            local current_date=$(date +%Y-%m-%d)
            local status_icon="🟢"
            local status_text="Aktif"
            
            if [[ "$expired" < "$current_date" ]]; then
                status_icon="🔴"
                status_text="Expired"
            elif [[ "$expired" == "$current_date" ]]; then
                status_icon="🟡"
                status_text="Hari Ini"
            fi
            
            CEKUSER_MESSAGE+="<b>$counter.</b> $status_icon <code>$username</code>\n"
            CEKUSER_MESSAGE+="   • Expired: <code>$expired</code> ($status_text)\n\n"
            
            ((counter++))
        fi
    done <<< "$user_list"
    
    CEKUSER_STATUS="SUCCESS"
    return 0
}

# ═══════════════════════════════════════════════════════════════
# FUNGSI ORKESTRATOR UTAMA UNTUK BOT
# ═══════════════════════════════════════════════════════════════

# Fungsi utama untuk bot - Delete User VMESS
main_bot_delluser_vmess() {
    local username="$1"
    local send_to_telegram="${2:-true}"
    
    # Reset variabel global
    DELLUSER_STATUS=""
    DELLUSER_MESSAGE=""
    
    # Panggil fungsi delete
    delete_vmess_user "$username"
    local result=$?
    
    # Kirim notifikasi ke Telegram jika diminta
    if [[ "$send_to_telegram" == "true" && -n "$ADMIN_CHAT_ID" ]]; then
        send_telegram_message "$ADMIN_CHAT_ID" "$DELLUSER_MESSAGE"
    fi
    
    return $result
}

# Fungsi utama untuk bot - Cek User VMESS
main_bot_cekuser_vmess() {
    local send_to_telegram="${1:-true}"
    
    # Reset variabel global
    CEKUSER_STATUS=""
    CEKUSER_MESSAGE=""
    
    # Panggil fungsi cek user
    check_vmess_users
    local result=$?
    
    # Kirim notifikasi ke Telegram jika diminta
    if [[ "$send_to_telegram" == "true" && -n "$ADMIN_CHAT_ID" ]]; then
        send_telegram_message "$ADMIN_CHAT_ID" "$CEKUSER_MESSAGE"
    fi
    
    return $result
}

# ═══════════════════════════════════════════════════════════════
# FUNGSI GETTER UNTUK MENGAMBIL HASIL
# ═══════════════════════════════════════════════════════════════

# Fungsi untuk mengambil status delete user vmess
get_result_delluser_vmess() {
    echo "$DELLUSER_STATUS"
}

# Fungsi untuk mengambil pesan delete user vmess
get_result_message_vmessdell() {
    echo "$DELLUSER_MESSAGE"
}

# Fungsi untuk mengambil status cek user vmess
get_result_cekuser_vmess() {
    echo "$CEKUSER_STATUS"  
}

# Fungsi untuk mengambil pesan cek user vmess
get_result_message_vmesscek() {
    echo "$CEKUSER_MESSAGE"
}

# ═══════════════════════════════════════════════════════════════
# INTERFACE COMMAND LINE
# ═══════════════════════════════════════════════════════════════

# Fungsi CLI untuk delete user
cli_delete_vmess() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        echo -e "${RED}Error: Username tidak boleh kosong!${NC}"
        echo -e "Usage: $0 delete <username>"
        exit 1
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BGWHITE}        Delete Vmess Account       ${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    main_bot_delluser_vmess "$username" "false"
    
    if [[ "$DELLUSER_STATUS" == "SUCCESS" ]]; then
        echo -e "${GREEN}✅ Berhasil menghapus user VMESS${NC}"
        echo -e "Username: $username"
    else
        echo -e "${RED}❌ Gagal menghapus user VMESS${NC}"
        echo -e "Error: $(echo "$DELLUSER_MESSAGE" | sed 's/<[^>]*>//g')"
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Fungsi CLI untuk cek user
cli_check_vmess() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BGWHITE}        Daftar User VMESS         ${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    main_bot_cekuser_vmess "false"
    
    if [[ "$CEKUSER_STATUS" == "SUCCESS" ]]; then
        # Tampilkan daftar user dalam format tabel
        echo -e "${GREEN}USER${NC}          ${GREEN}EXPIRED${NC}     ${GREEN}STATUS${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        grep -e "^### " "/etc/xray/config.json" | cut -d ' ' -f 2-3 | while read -r line; do
            if [[ -n "$line" ]]; then
                local username=$(echo "$line" | awk '{print $1}')
                local expired=$(echo "$line" | awk '{print $2}')
                local current_date=$(date +%Y-%m-%d)
                local status="Aktif"
                local color="${GREEN}"
                
                if [[ "$expired" < "$current_date" ]]; then
                    status="Expired"
                    color="${RED}"
                elif [[ "$expired" == "$current_date" ]]; then
                    status="Hari Ini"
                    color="${ORANGE}"
                fi
                
                printf "%-12s %-10s ${color}%-8s${NC}\n" "$username" "$expired" "$status"
            fi
        done
        
    elif [[ "$CEKUSER_STATUS" == "EMPTY" ]]; then
        echo -e "${ORANGE}ℹ️  Tidak ada member VMESS yang terdaftar!${NC}"
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ═══════════════════════════════════════════════════════════════
# MAIN SCRIPT HANDLER
# ═══════════════════════════════════════════════════════════════

# Handler untuk menjalankan script langsung dari command line
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        "delete"|"dell")
            cli_delete_vmess "$2"
            ;;
        "check"|"cek"|"list")
            cli_check_vmess
            ;;
        *)
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${BGWHITE}    VMESS Management Script      ${NC}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}Usage:${NC}"
            echo -e "  $0 delete <username>  - Hapus user VMESS"
            echo -e "  $0 check              - Lihat daftar user VMESS"
            echo -e ""
            echo -e "${GREEN}Contoh:${NC}"
            echo -e "  $0 delete john_doe"
            echo -e "  $0 check"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            exit 1
            ;;
    esac
fi

# ═══════════════════════════════════════════════════════════════
# EXPORT FUNCTIONS UNTUK BOT
# ═══════════════════════════════════════════════════════════════

# Export semua fungsi yang diperlukan untuk integrasi bot
export -f main_bot_delluser_vmess
export -f main_bot_cekuser_vmess
export -f get_result_delluser_vmess
export -f get_result_message_vmessdell
export -f get_result_cekuser_vmess
export -f get_result_message_vmesscek
export -f delete_vmess_user
export -f check_vmess_users
export -f send_telegram_message

# ═══════════════════════════════════════════════════════════════
# DOKUMENTASI PENGGUNAAN
# ═══════════════════════════════════════════════════════════════

: <<'DOCUMENTATION'

VMESS Bot Integration Functions
==============================

1. CLI Interface:
   ─────────────
   • Delete User: ./script.sh delete <username>
     Contoh: ./script.sh delete john_doe
   
   • Cek User: ./script.sh check
     Contoh: ./script.sh check

2. Import ke script lain:
   ──────────────────────
   #!/bin/bash
   source "/path/to/vmess_bot_functions.sh"
   
   # Hapus user
   main_bot_delluser_vmess "username"
   status=$(get_result_delluser_vmess)
   message=$(get_result_message_vmessdell)
   
   # Cek user
   main_bot_cekuser_vmess
   status=$(get_result_cekuser_vmess)
   message=$(get_result_message_vmesscek)

3. Parameter:
   ──────────
   • main_bot_delluser_vmess <username> [send_telegram]
     - username: nama user yang akan dihapus (required)
     - send_telegram: true/false untuk kirim ke telegram (optional, default: true)
   
   • main_bot_cekuser_vmess [send_telegram]
     - send_telegram: true/false untuk kirim ke telegram (optional, default: true)

4. Return Value:
   ─────────────
   • Status Delete: SUCCESS, ERROR
   • Status Cek: SUCCESS, EMPTY
   • Message: Formatted message untuk Telegram/WhatsApp
   
   Contoh penggunaan:
   main_bot_delluser_vmess "testuser"
   if [[ $(get_result_delluser_vmess) == "SUCCESS" ]]; then
       echo "User berhasil dihapus"
       echo "Pesan: $(get_result_message_vmessdell)"
   else
       echo "Gagal menghapus user"
   fi

5. Konfigurasi Bot:
   ─────────────────
   • Edit variabel BOT_TOKEN dan ADMIN_CHAT_ID di bagian atas script
   • BOT_TOKEN: Token bot Telegram Anda
   • ADMIN_CHAT_ID: Chat ID admin yang akan menerima notifikasi

DOCUMENTATION