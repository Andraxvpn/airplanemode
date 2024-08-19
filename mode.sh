#!/bin/bash

# Konfigurasi Default
TARGET="google.com"
INTERVAL=30
AIRPLANE_MODE_DURATION=1
LOG_FILE="/sdcard/check_internet.log"

# Fungsi untuk menampilkan pesan bantuan
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -t  Target host untuk ping (default: $TARGET)"
    echo "  -i  Interval pemeriksaan dalam detik (default: $INTERVAL)"
    echo "  -d  Durasi mode pesawat dalam detik (default: $AIRPLANE_MODE_DURATION)"
    echo "  -l  Nama file log (default: $LOG_FILE)"
    echo "  -h  Tampilkan pesan bantuan"
    exit 1
}

# Fungsi untuk mencatat pesan ke file log
log_message() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level]: $message" >> "$LOG_FILE"
}

# Fungsi untuk memeriksa koneksi internet
check_internet() {
    if ping -c 1 $TARGET > /dev/null 2>&1; then
        log_message "INFO" "Koneksi internet baik."
    else
        log_message "ERROR" "Koneksi internet terputus! Mengaktifkan mode pesawat selama $AIRPLANE_MODE_DURATION detik..."
        su -c 'settings put global airplane_mode_on 1'
        su -c 'am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true'
        sleep $AIRPLANE_MODE_DURATION
        log_message "INFO" "Menonaktifkan mode pesawat..."
        su -c 'settings put global airplane_mode_on 0'
        su -c 'am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false'
    fi
}

# Memproses argumen
while getopts ":t:i:d:l:h" opt; do
    case ${opt} in
        t ) TARGET="$OPTARG" ;;
        i ) INTERVAL="$OPTARG" ;;
        d ) AIRPLANE_MODE_DURATION="$OPTARG" ;;
        l ) LOG_FILE="$OPTARG" ;;
        h ) usage ;;
        \? ) usage ;;
    esac
done

# Tampilan Awal
clear
echo "=================================================="
echo "       Skrip Pemantauan Koneksi Internet          "
echo "=================================================="
echo "Target Host: $TARGET"
echo "Interval Pemeriksaan: $INTERVAL detik"
echo "Durasi Mode Pesawat: $AIRPLANE_MODE_DURATION detik"
echo "File Log: $LOG_FILE"
echo "=================================================="

# Cek apakah skrip dijalankan dengan akses root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: Skrip harus dijalankan dengan akses root."
    exit 1
fi

# Loop utama
while true; do
    check_internet
    sleep $INTERVAL
done
