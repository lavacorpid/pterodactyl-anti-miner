#!/bin/bash
#
# install.sh — Pasang xmrig-guard di node ini
#
# Jalankan sebagai root, dari dalam folder repo (yang sudah di-clone/di-download):
#   sudo ./install.sh
#
set -euo pipefail

INSTALL_DIR="/opt/xmrig-guard"
LOG_FILE="/var/log/xmrig-guard.log"
CRON_MARKER="${INSTALL_DIR}/xmrig-guard.sh"
CRON_LINE="* * * * * ${INSTALL_DIR}/xmrig-guard.sh"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: jalankan sebagai root (sudo ./install.sh)" >&2
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "PERINGATAN: 'docker' tidak ditemukan di PATH."
    echo "Script tetap dipasang, tapi verifikasi cgroup Docker akan selalu gagal —"
    echo "artinya semua proses akan di-SKIP (tidak ada yang di-kill/dihapus)."
    echo ""
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$SCRIPT_DIR/xmrig-guard.sh" ]; then
    echo "Error: xmrig-guard.sh tidak ditemukan di $SCRIPT_DIR" >&2
    echo "Pastikan install.sh dijalankan dari dalam folder repo yang lengkap." >&2
    exit 1
fi

mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/xmrig-guard.sh" "$INSTALL_DIR/xmrig-guard.sh"
chmod +x "$INSTALL_DIR/xmrig-guard.sh"

touch "$LOG_FILE"

if [ -f "$SCRIPT_DIR/xmrig-guard.logrotate" ]; then
    cp "$SCRIPT_DIR/xmrig-guard.logrotate" /etc/logrotate.d/xmrig-guard
    echo "Logrotate dipasang: /etc/logrotate.d/xmrig-guard"
fi

# Pasang cron secara idempotent — hapus dulu baris lama (kalau ada) biar tidak dobel
( crontab -l 2>/dev/null | grep -vF "$CRON_MARKER" ; echo "$CRON_LINE" ) | crontab -

echo ""
echo "=== Instalasi selesai ==="
echo "Script : $INSTALL_DIR/xmrig-guard.sh"
echo "Log    : $LOG_FILE"
echo "Cron   : $CRON_LINE  (jalan tiap menit)"
echo ""
echo "PENTING: cek/edit konfigurasi (alert Zabbix, pola deteksi tambahan) di:"
echo "  $INSTALL_DIR/xmrig-guard.sh"
echo ""
echo "Disarankan tes manual dulu sebelum benar-benar diandalkan:"
echo "  $INSTALL_DIR/xmrig-guard.sh"
echo "  tail -20 $LOG_FILE"
