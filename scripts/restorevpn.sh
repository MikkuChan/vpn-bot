#!/bin/bash
# ━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━━
# 𓈃 System Request ➠ Debian 9+/Ubuntu 18.04+/20+
# 𓈃 Developer ➠ MikkuChan
# 𓈃 Email      ➠ fadztechs2@gmail.com
# 𓈃 Telegram   ➠ https://t.me/fadzdigital
# 𓈃 Bot Integration Version - Function Based
# ━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━━

# ═══════════════════════════════════════════════════════════
# KONFIGURASI GLOBAL DAN VARIABEL
# ═══════════════════════════════════════════════════════════

# Warna ANSI untuk tampilan terminal
RED='\033[1;91m'
GREEN='\033[1;92m'
YELLOW='\033[1;93m'
BLUE='\033[1;94m'
CYAN='\033[1;96m'
NC='\033[0m' # Reset warna

# Variabel global untuk menyimpan hasil operasi
RESTORE_STATUS=""
RESTORE_MESSAGE=""
RESTORE_DETAILS=""

# ═══════════════════════════════════════════════════════════
# FUNGSI KONFIGURASI TELEGRAM
# ═══════════════════════════════════════════════════════════

# Fungsi untuk mendapatkan konfigurasi bot Telegram
get_telegram_config() {
    if [[ -f "/etc/bot/.bot.db" ]]; then
        CHATID=$(grep -E "^#bot# " "/etc/bot/.bot.db" | cut -d ' ' -f 3)
        KEY=$(grep -E "^#bot# " "/etc/bot/.bot.db" | cut -d ' ' -f 2)
        export TIME="10"
        export URL="https://api.telegram.org/bot$KEY/sendMessage"
        
        if [[ -z "$CHATID" || -z "$KEY" ]]; then
            echo "ERROR: Konfigurasi Telegram bot tidak lengkap"
            return 1
        fi
        return 0
    else
        echo "ERROR: File konfigurasi bot tidak ditemukan"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════
# FUNGSI NOTIFIKASI TELEGRAM
# ═══════════════════════════════════════════════════════════

# Fungsi notifikasi sukses ke Telegram
send_success_notification() {
    local backup_url="$1"
    local timestamp=$(date '+%d/%m/%Y %H:%M:%S')
    
    TEXT="
━━━━━━━━━━※❆※━━━━━━━━━━
𓈃 RESTORE VPS BERHASIL 𓈃
━━━━━━━━━━※❆※━━━━━━━━━━
✅ Restore VPS Sukses!
📌 VPS telah dikembalikan seperti semula
🔗 Backup URL: $(echo "$backup_url" | cut -c1-50)...
⏰ Waktu: $timestamp
🖥️ Server: $(hostname)
━━━━━━━━━━※❆※━━━━━━━━━━
"
    
    if get_telegram_config; then
        curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL >/dev/null
        return $?
    fi
    return 1
}

# Fungsi notifikasi error ke Telegram
send_error_notification() {
    local error_msg="$1"
    local backup_url="$2"
    local timestamp=$(date '+%d/%m/%Y %H:%M:%S')
    
    TEXT="
━━━━━━━━━━※❆※━━━━━━━━━━
❌ RESTORE VPS GAGAL ❌
━━━━━━━━━━※❆※━━━━━━━━━━
🚫 Error: $error_msg
🔗 Backup URL: $(echo "$backup_url" | cut -c1-50)...
⏰ Waktu: $timestamp
🖥️ Server: $(hostname)
━━━━━━━━━━※❆※━━━━━━━━━━
"
    
    if get_telegram_config; then
        curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL >/dev/null
        return $?
    fi
    return 1
}

# ═══════════════════════════════════════════════════════════
# FUNGSI UTILITAS
# ═══════════════════════════════════════════════════════════

# Fungsi progress bar dengan animasi
show_progress() {
    local message="$1"
    local percentage="$2"
    local step="$3"
    
    local bar=""
    case $step in
        1) bar="■□□□□□□□□□" ;;
        2) bar="■■■■□□□□□□" ;;
        3) bar="■■■■■■■■□□" ;;
        4) bar="■■■■■■■■■■" ;;
        *) bar="■■■■■■■■■■" ;;
    esac
    
    echo -ne "\r📂 ${GREEN}$message${NC}   [$bar] $percentage%"
    sleep 1
}

# Fungsi validasi URL
validate_url() {
    local url="$1"
    
    if [[ -z "$url" ]]; then
        return 1
    fi
    
    # Cek format URL dasar
    if [[ ! "$url" =~ ^https?:// ]]; then
        return 1
    fi
    
    return 0
}

# ═══════════════════════════════════════════════════════════
# FUNGSI UTAMA RESTORE
# ═══════════════════════════════════════════════════════════

# Fungsi download backup file
download_backup() {
    local url="$1"
    local temp_dir="/tmp/restore_$(date +%s)"
    
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    echo "Mengunduh backup dari: $url"
    show_progress "Mengunduh file backup" 10 1
    
    if wget -q --timeout=30 -O backup.zip "$url"; then
        if [[ -f "backup.zip" && -s "backup.zip" ]]; then
            echo -e "\n✅ Download berhasil"
            return 0
        else
            echo -e "\n❌ File backup kosong atau rusak"
            return 1
        fi
    else
        echo -e "\n❌ Gagal mengunduh backup"
        return 1
    fi
}

# Fungsi ekstrak backup
extract_backup() {
    show_progress "Mengekstrak file backup" 40 2
    
    if unzip -q backup.zip; then
        if [[ -d "backup" ]]; then
            echo -e "\n✅ Ekstrak berhasil"
            return 0
        else
            echo -e "\n❌ Struktur backup tidak valid"
            return 1
        fi
    else
        echo -e "\n❌ Gagal mengekstrak backup"
        return 1
    fi
}

# Fungsi restore konfigurasi sistem
restore_system_config() {
    show_progress "Memulihkan konfigurasi sistem" 60 3
    
    cd backup
    
    # Backup konfigurasi lama sebelum restore
    local backup_old="/tmp/backup_old_$(date +%s)"
    mkdir -p "$backup_old"
    
    # Daftar file dan direktori yang akan di-restore
    local files_to_restore=(
        "passwd:/etc/"
        "group:/etc/"
        "shadow:/etc/"
        "gshadow:/etc/"
        "crontab:/etc/"
    )
    
    local dirs_to_restore=(
        "kyt:/etc/"
        "xray:/etc/"
        "vmess:/etc/"
        "vless:/etc/"
        "trojan:/etc/"
        "shodowshocks:/etc/"
        "html:/var/www/"
    )
    
    # Restore files
    for item in "${files_to_restore[@]}"; do
        local file=$(echo "$item" | cut -d':' -f1)
        local dest=$(echo "$item" | cut -d':' -f2)
        
        if [[ -f "$file" ]]; then
            # Backup file lama jika ada
            if [[ -f "$dest$file" ]]; then
                cp "$dest$file" "$backup_old/"
            fi
            cp "$file" "$dest" && echo "✅ Restored: $file"
        fi
    done
    
    # Restore directories
    for item in "${dirs_to_restore[@]}"; do
        local dir=$(echo "$item" | cut -d':' -f1)
        local dest=$(echo "$item" | cut -d':' -f2)
        
        if [[ -d "$dir" ]]; then
            # Backup direktori lama jika ada
            if [[ -d "$dest$dir" ]]; then
                cp -r "$dest$dir" "$backup_old/"
            fi
            cp -r "$dir" "$dest" && echo "✅ Restored: $dir"
        fi
    done
    
    echo -e "\n✅ Konfigurasi sistem berhasil dipulihkan"
    return 0
}

# Fungsi cleanup temporary files
cleanup_temp_files() {
    show_progress "Membersihkan file sementara" 90 4
    
    # Hapus file backup dan direktori temporary
    rm -f backup.zip
    cd /
    rm -rf /tmp/restore_*
    
    echo -e "\n✅ Cleanup selesai"
}

# ═══════════════════════════════════════════════════════════
# FUNGSI UTAMA RESTORE VPN
# ═══════════════════════════════════════════════════════════

# Fungsi utama untuk restore VPN
restore_vpn_main() {
    local backup_url="$1"
    local silent_mode="${2:-false}"
    
    # Reset variabel global
    RESTORE_STATUS=""
    RESTORE_MESSAGE=""
    RESTORE_DETAILS=""
    
    local start_time=$(date +%s)
    local timestamp=$(date '+%d/%m/%Y %H:%M:%S')
    
    # Validasi input
    if ! validate_url "$backup_url"; then
        RESTORE_STATUS="ERROR"
        RESTORE_MESSAGE="URL backup tidak valid atau kosong"
        RESTORE_DETAILS="URL: $backup_url | Status: Invalid URL Format"
        
        if [[ "$silent_mode" != "true" ]]; then
            echo -e "${RED}❌ Error: $RESTORE_MESSAGE${NC}"
            send_error_notification "$RESTORE_MESSAGE" "$backup_url"
        fi
        return 1
    fi
    
    if [[ "$silent_mode" != "true" ]]; then
        clear
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
        echo -e "🔄 ${CYAN}MEMULAI PROSES RESTORE...${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
        echo -e "🔗 Backup URL: $backup_url"
        echo -e "⏰ Waktu Mulai: $timestamp"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
    fi
    
    # Proses restore step by step
    if ! download_backup "$backup_url"; then
        RESTORE_STATUS="ERROR"
        RESTORE_MESSAGE="Gagal mengunduh file backup"
        RESTORE_DETAILS="URL: $backup_url | Error: Download failed"
        
        if [[ "$silent_mode" != "true" ]]; then
            send_error_notification "$RESTORE_MESSAGE" "$backup_url"
        fi
        return 1
    fi
    
    if ! extract_backup; then
        RESTORE_STATUS="ERROR"
        RESTORE_MESSAGE="Gagal mengekstrak file backup"
        RESTORE_DETAILS="URL: $backup_url | Error: Extract failed"
        
        cleanup_temp_files >/dev/null 2>&1
        if [[ "$silent_mode" != "true" ]]; then
            send_error_notification "$RESTORE_MESSAGE" "$backup_url"
        fi
        return 1
    fi
    
    if ! restore_system_config; then
        RESTORE_STATUS="ERROR"
        RESTORE_MESSAGE="Gagal memulihkan konfigurasi sistem"
        RESTORE_DETAILS="URL: $backup_url | Error: System restore failed"
        
        cleanup_temp_files >/dev/null 2>&1
        if [[ "$silent_mode" != "true" ]]; then
            send_error_notification "$RESTORE_MESSAGE" "$backup_url"
        fi
        return 1
    fi
    
    cleanup_temp_files
    
    # Hitung durasi proses
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Set hasil sukses
    RESTORE_STATUS="SUCCESS"
    RESTORE_MESSAGE="Restore VPS berhasil diselesaikan dalam ${duration} detik"
    RESTORE_DETAILS="URL: $backup_url | Duration: ${duration}s | Status: Completed Successfully"
    
    if [[ "$silent_mode" != "true" ]]; then
        show_progress "Finalisasi proses restore" 100 4
        echo -e "\n"
        
        # Kirim notifikasi sukses
        send_success_notification "$backup_url"
        
        # Tampilkan hasil
        clear
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
        echo -e "✅ ${GREEN}RESTORE VPS SELESAI${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
        echo -e "🔄 ${CYAN}VPS telah dikembalikan seperti semula${NC}"
        echo -e "⏱️  ${GREEN}Durasi: ${duration} detik${NC}"
        echo -e "🔗 ${BLUE}Backup: $(echo "$backup_url" | cut -c1-50)...${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━${NC}"
    fi
    
    return 0
}

# ═══════════════════════════════════════════════════════════
# FUNGSI ORKESTRATOR UTAMA
# ═══════════════════════════════════════════════════════════

# Fungsi utama untuk dipanggil dari bot Telegram
main_bot_restorevpn() {
    local backup_url="$1"
    local notify="${2:-true}"
    
    # Panggil fungsi restore dengan mode silent jika tidak perlu notifikasi
    if [[ "$notify" == "false" ]]; then
        restore_vpn_main "$backup_url" "true"
    else
        restore_vpn_main "$backup_url" "false"
    fi
    
    return $?
}

# ═══════════════════════════════════════════════════════════
# FUNGSI GETTER UNTUK HASIL
# ═══════════════════════════════════════════════════════════

# Fungsi untuk mendapatkan status hasil restore
get_result_restorevpn() {
    echo "$RESTORE_STATUS"
}

# Fungsi untuk mendapatkan pesan hasil restore
get_result_message_restorevpn() {
    echo "$RESTORE_MESSAGE"
}

# Fungsi untuk mendapatkan detail lengkap hasil restore
get_result_details_restorevpn() {
    echo "$RESTORE_DETAILS"
}

# Fungsi untuk mendapatkan semua hasil dalam format JSON
get_result_json_restorevpn() {
    cat << EOF
{
    "status": "$RESTORE_STATUS",
    "message": "$RESTORE_MESSAGE", 
    "details": "$RESTORE_DETAILS",
    "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF
}

# ═══════════════════════════════════════════════════════════
# CLI INTERFACE
# ═══════════════════════════════════════════════════════════

# Fungsi CLI interface
cli_interface() {
    if [[ $# -eq 0 ]]; then
        echo -e "${CYAN}Masukkan Link Backup VPS:${NC}"
        echo -e "━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━"
        read -rp "🔗 Link File: " -e backup_url
        echo -e "━━━━━━━━━━━━━━━━※❆※━━━━━━━━━━━━━━━━"
    else
        backup_url="$1"
    fi
    
    # Panggil fungsi restore
    restore_vpn_main "$backup_url"
    exit $?
}

# ═══════════════════════════════════════════════════════════
# EXPORT FUNCTIONS UNTUK BOT
# ═══════════════════════════════════════════════════════════

# Export semua fungsi yang diperlukan untuk integrasi bot
export -f main_bot_restorevpn
export -f get_result_restorevpn  
export -f get_result_message_restorevpn
export -f get_result_details_restorevpn
export -f get_result_json_restorevpn
export -f restore_vpn_main
export -f send_success_notification
export -f send_error_notification

# ═══════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════

# Jika script dipanggil langsung (bukan di-source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cli_interface "$@"
fi

# ═══════════════════════════════════════════════════════════
# DOKUMENTASI PENGGUNAAN
# ═══════════════════════════════════════════════════════════

: << 'DOCUMENTATION'

=== DOKUMENTASI PENGGUNAAN RESTOREVPN BOT INTEGRATION ===

1. CLI Interface:
   ┌─────────────────────────────────────────────────────────┐
   │ # Jalankan interaktif (akan diminta input URL)         │
   │ ./restorevpn.sh                                         │
   │                                                         │
   │ # Jalankan dengan parameter langsung                    │  
   │ ./restorevpn.sh "https://example.com/backup.zip"       │
   └─────────────────────────────────────────────────────────┘

2. Import ke script lain:
   ┌─────────────────────────────────────────────────────────┐
   │ #!/bin/bash                                             │
   │ source /path/to/restorevpn.sh                           │
   │                                                         │
   │ # Panggil fungsi utama untuk bot                        │
   │ main_bot_restorevpn "https://backup-url.com/file.zip"  │
   │                                                         │
   │ # Ambil hasil                                           │
   │ status=$(get_result_restorevpn)                         │
   │ message=$(get_result_message_restorevpn)                │
   │ details=$(get_result_details_restorevpn)                │
   │ json_result=$(get_result_json_restorevpn)               │
   │                                                         │
   │ # Cek status                                            │
   │ if [[ "$status" == "SUCCESS" ]]; then                   │
   │     echo "Restore berhasil: $message"                   │
   │ else                                                    │
   │     echo "Restore gagal: $message"                      │
   │ fi                                                      │
   └─────────────────────────────────────────────────────────┘

3. Parameter:
   ┌─────────────────────────────────────────────────────────┐
   │ main_bot_restorevpn <backup_url> [notify]               │
   │                                                         │
   │ backup_url : URL file backup (wajib)                    │
   │ notify     : true/false (opsional, default: true)      │
   │              - true  = kirim notifikasi Telegram       │
   │              - false = mode silent tanpa notifikasi    │
   └─────────────────────────────────────────────────────────┘

4. Return Value:
   ┌─────────────────────────────────────────────────────────┐
   │ get_result_restorevpn()         : SUCCESS/ERROR        │
   │ get_result_message_restorevpn() : Detail pesan hasil   │
   │ get_result_details_restorevpn() : Info lengkap proses  │
   │ get_result_json_restorevpn()    : Format JSON lengkap  │
   │                                                         │
   │ Return Code Function:                                   │
   │ - 0 : Sukses                                            │
   │ - 1 : Error/Gagal                                       │
   └─────────────────────────────────────────────────────────┘

5. Contoh Integrasi Bot Telegram:
   ┌─────────────────────────────────────────────────────────┐
   │ # Di script bot Telegram                                │
   │ source /path/to/restorevpn.sh                           │
   │                                                         │
   │ # Proses restore                                        │
   │ if main_bot_restorevpn "$backup_url"; then              │
   │     statusrestorevpn=$(get_result_restorevpn)           │
   │     messagerestorevpn=$(get_result_message_restorevpn)  │
   │     echo "Status: $statusrestorevpn"                    │
   │     echo "Message: $messagerestorevpn"                  │
   │ else                                                    │
   │     echo "Restore gagal"                                │
   │ fi                                                      │
   └─────────────────────────────────────────────────────────┘

DOCUMENTATION