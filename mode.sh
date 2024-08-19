#!/bin/bash

# Skrip Pemantauan Koneksi Internet dan Pengelolaan Mode Pesawat

# Konfigurasi Default
TARGET=""
INTERVAL=30
AIRPLANE_MODE_DURATION=1
LOG_FILE="./check_internet.log"
MAX_LOG_SIZE=10485760  # 10 MB
LOG_RETENTION_DAYS=7

# Fungsi untuk menampilkan pesan bantuan
usage() {
    cat <<EOF
Usage: $0
Options:
  -h  Show this help message
EOF
    exit 1
}

# Fungsi untuk mencatat pesan ke file log
log_message() {
    local level="$1"
    local message="$2"
    local log_entry="$(date '+%Y-%m-%d %H:%M:%S') [$level]: $message"
    echo "$log_entry" >> "$LOG_FILE"
    echo "$log_entry"
}

# Fungsi untuk rotasi log
rotate_log() {
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -ge $MAX_LOG_SIZE ]; then
        local timestamp=$(date '+%Y%m%d%H%M%S')
        mv "$LOG_FILE" "${LOG_FILE}.${timestamp}.bak"
        log_message "INFO" "Log file dirotasi."
    fi
}

# Fungsi untuk menghapus log lama
cleanup_old_logs() {
    find "$(dirname "$LOG_FILE")" -name "check_internet.log.*.bak" -mtime +$LOG_RETENTION_DAYS -exec rm -f {} \;
}

# Fungsi untuk memeriksa koneksi internet
check_internet() {
    if ping -c 1 $TARGET > /dev/null 2>&1; then
        log_message "INFO" "Koneksi internet baik."
    else
        log_message "ERROR" "Koneksi internet terputus! Mengaktifkan mode pesawat selama $AIRPLANE_MODE_DURATION detik..."
        if ! su -c 'settings put global airplane_mode_on 1'; then
            log_message "ERROR" "Gagal mengaktifkan mode pesawat."
            exit 1
        fi
        if ! su -c 'am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true'; then
            log_message "ERROR" "Gagal mengaktifkan mode pesawat via broadcast."
            exit 1
        fi
        sleep $AIRPLANE_MODE_DURATION
        log_message "INFO" "Menonaktifkan mode pesawat..."
        if ! su -c 'settings put global airplane_mode_on 0'; then
            log_message "ERROR" "Gagal menonaktifkan mode pesawat."
            exit 1
        fi
        if ! su -c 'am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false'; then
            log_message "ERROR" "Gagal menonaktifkan mode pesawat via broadcast."
            exit 1
        fi
    fi
}

# Fungsi untuk menangani sinyal penghentian
handle_exit() {
    log_message "INFO" "Skrip dihentikan oleh pengguna."
    exit 0
}

# Memproses argumen
while getopts ":h" opt; do
    case ${opt} in
        h )
            usage
            ;;
        \? )
            usage
            ;;
    esac
done

# Minta pengguna untuk memasukkan target setiap kali skrip dijalankan
echo "Konfigurasi default:"
echo "Interval pemeriksaan: $INTERVAL detik"
echo "Durasi mode pesawat: $AIRPLANE_MODE_DURATION detik"
echo "File log: $LOG_FILE"
echo "Ukuran log maksimum: $MAX_LOG_SIZE byte"
echo "Retensi log: $LOG_RETENTION_DAYS hari"

read -p "Masukan bug yang kalian injex: " TARGET
if [ -z "$TARGET" ]; then
    echo "Target tidak dapat dikosongkan. Skrip dihentikan."
    exit 1
fi

# Cek apakah direktori log ada, jika tidak buat
if [ ! -d "$(dirname "$LOG_FILE")" ]; then
    mkdir -p "$(dirname "$LOG_FILE")"
fi

# Cek apakah skrip dijalankan dengan akses root
if [ "$(id -u)" -ne 0 ]; then
    log_message "ERROR" "Skrip harus dijalankan dengan akses root."
    echo "Error: Skrip harus dijalankan dengan akses root."
    exit 1
fi

# Rotasi dan bersihkan log sebelum memulai loop
rotate_log
cleanup_old_logs

# Menangani sinyal penghentian (Ctrl+C)
trap handle_exit INT

# Loop utama
log_message "INFO" "Skrip pemantauan koneksi dimulai dengan target: $TARGET."
while true; do
    check_internet
    sleep $INTERVAL
done
