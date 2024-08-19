#!/bin/bash

# Skrip Pemantauan Koneksi Internet dan Pengelolaan Mode Pesawat untuk Android

# Konfigurasi Default
DEFAULT_TARGET="quiz.vidio.com"
DEFAULT_INTERVAL=30
DEFAULT_AIRPLANE_MODE_DURATION=1
DEFAULT_LOG_FILE="/sdcard/check_internet.log"
DEFAULT_MAX_LOG_SIZE=10485760  # 10 MB
DEFAULT_CONFIG_FILE="/sdcard/config.conf"

# Fungsi untuk menampilkan pesan bantuan
usage() {
    cat <<EOF
Usage: $0 [options]
Skrip ini memantau koneksi internet dan mengaktifkan mode pesawat jika koneksi terputus.

Options:
  -t  Target host untuk ping (default: $DEFAULT_TARGET)
  -i  Interval pemeriksaan dalam detik (default: $DEFAULT_INTERVAL)
  -d  Durasi mode pesawat dalam detik (default: $DEFAULT_AIRPLANE_MODE_DURATION)
  -l  Nama file log (default: $DEFAULT_LOG_FILE)
  -c  File konfigurasi (default: $DEFAULT_CONFIG_FILE)
  -h  Tampilkan pesan bantuan
EOF
    exit 1
}

# Fungsi untuk mencatat pesan ke file log dengan rotasi
log_message() {
    local level="$1"
    local message="$2"
    local log_entry="$(date '+%Y-%m-%d %H:%M:%S') [$level]: $message"
    
    # Cek ukuran file log dan rotasi jika perlu
    if [ -f "$LOG_FILE" ] && [ "$(stat -c%s "$LOG_FILE")" -ge "$DEFAULT_MAX_LOG_SIZE" ]; then
        mv "$LOG_FILE" "$LOG_FILE.old"
        echo "Log file telah dipindahkan ke $LOG_FILE.old" | tee -a "$LOG_FILE"
    fi
    
    echo "$log_entry" >> "$LOG_FILE"
    echo "$log_entry"
}

# Fungsi untuk memeriksa koneksi internet
check_internet() {
    local status
    status=$(ping -c 1 $TARGET > /dev/null 2>&1 && echo "connected" || echo "disconnected")
    if [ "$status" = "connected" ]; then
        log_message "INFO" "Koneksi internet baik."
    else
        log_message "ERROR" "Koneksi internet terputus! Mengaktifkan mode pesawat selama $AIRPLANE_MODE_DURATION detik..."
        
        # Mengaktifkan mode pesawat
        su -c 'settings put global airplane_mode_on 1'
        su -c 'am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true'
        
        # Cek status mode pesawat
        if [ "$?" -eq 0 ]; then
            log_message "INFO" "Mode pesawat diaktifkan."
        else
            log_message "ERROR" "Gagal mengaktifkan mode pesawat."
            exit 1
        fi
        
        sleep $AIRPLANE_MODE_DURATION
        
        log_message "INFO" "Menonaktifkan mode pesawat..."
        # Menonaktifkan mode pesawat
        su -c 'settings put global airplane_mode_on 0'
        su -c 'am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false'
        
        # Cek status mode pesawat
        if [ "$?" -eq 0 ]; then
            log_message "INFO" "Mode pesawat dinonaktifkan."
        else
            log_message "ERROR" "Gagal menonaktifkan mode pesawat."
            exit 1
        fi
    fi
}

# Fungsi untuk menangani sinyal penghentian
handle_exit() {
    log_message "INFO" "Skrip dihentikan oleh pengguna."
    exit 0
}

# Fungsi untuk memuat konfigurasi dari file
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        . "$CONFIG_FILE"
    fi
}

# Fungsi untuk menyimpan konfigurasi ke file
save_config() {
    echo "TARGET=\"$TARGET\"" > "$CONFIG_FILE"
    echo "INTERVAL=\"$INTERVAL\"" >> "$CONFIG_FILE"
    echo "AIRPLANE_MODE_DURATION=\"$AIRPLANE_MODE_DURATION\"" >> "$CONFIG_FILE"
    echo "LOG_FILE=\"$LOG_FILE\"" >> "$CONFIG_FILE"
}

# Memproses argumen
while getopts ":t:i:d:l:c:h" opt; do
    case ${opt} in
        t )
            TARGET="$OPTARG"
            ;;
        i )
            INTERVAL="$OPTARG"
            ;;
        d )
            AIRPLANE_MODE_DURATION="$OPTARG"
            ;;
        l )
            LOG_FILE="$OPTARG"
            ;;
        c )
            CONFIG_FILE="$OPTARG"
            ;;
        h )
            usage
            ;;
        \? )
            usage
            ;;
    esac
done

# Minta input pengguna jika tidak ada argumen yang diberikan
if [ -z "$TARGET" ]; then
    read -p "Masukkan target untuk ping (default: $DEFAULT_TARGET): " TARGET
    TARGET=${TARGET:-$DEFAULT_TARGET}
fi

if [ -z "$INTERVAL" ]; then
    read -p "Masukkan interval pemeriksaan dalam detik (default: $DEFAULT_INTERVAL): " INTERVAL
    INTERVAL=${INTERVAL:-$DEFAULT_INTERVAL}
fi

if [ -z "$AIRPLANE_MODE_DURATION" ]; then
    read -p "Masukkan durasi mode pesawat dalam detik (default: $DEFAULT_AIRPLANE_MODE_DURATION): " AIRPLANE_MODE_DURATION
    AIRPLANE_MODE_DURATION=${AIRPLANE_MODE_DURATION:-$DEFAULT_AIRPLANE_MODE_DURATION}
fi

if [ -z "$LOG_FILE" ]; then
    read -p "Masukkan nama file log (default: $DEFAULT_LOG_FILE): " LOG_FILE
    LOG_FILE=${LOG_FILE:-$DEFAULT_LOG_FILE}
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

# Muat konfigurasi dari file jika ada
load_config

# Simpan konfigurasi ke file
save_config

# Menangani sinyal penghentian (Ctrl+C)
trap handle_exit INT

# Loop utama
log_message "INFO" "Skrip pemantauan koneksi dimulai dengan target: $TARGET."
while true; do
    check_internet
    sleep $INTERVAL
done
