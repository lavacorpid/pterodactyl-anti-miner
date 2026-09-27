#!/bin/bash
#
# install-remote.sh — Pasang xmrig-guard langsung dari GitHub, tanpa git clone
#
# Cara pakai (di node target, sebagai root):
#   curl -fsSL https://raw.githubusercontent.com/lavacorpid/pterodactyl-anti-miner/main/install-remote.sh | sudo bash
#
# GANTI "<user-atau-org>" di baris REPO_RAW_BASE di bawah ini dengan
# username/org GitHub kamu yang sebenarnya SEBELUM file ini di-upload ke repo.
#
set -euo pipefail

REPO_RAW_BASE="https://raw.githubusercontent.com/lavacorpid/pterodactyl-anti-miner/main"

INSTALL_DIR="/opt/xmrig-guard"
LOG_FILE="/var/log/xmrig-guard.log"
CRON_MARKER="${INSTALL_DIR}/xmrig-guard.sh"
CRON_LINE="* * * * * ${INSTALL_DIR}/xmrig-guard.sh"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: jalankan sebagai root, contoh: curl ... | sudo bash" >&2
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "Error: 'curl' tidak ditemukan, install dulu (apt-get install -y curl)." >&2
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "PERINGATAN: 'docker' tidak ditemukan di PATH."
    echo "Script tetap dipasang, tapi verifikasi cgroup Docker akan selalu gagal —"
    echo "artinya semua proses akan di-SKIP (tidak ada yang di-kill/dihapus)."
    echo ""
fi

mkdir -p "$INSTALL_DIR"

echo "Mengunduh xmrig-guard.sh ..."
curl -fsSL "${REPO_RAW_BASE}/xmrig-guard.sh" -o "${INSTALL_DIR}/xmrig-guard.sh"
chmod +x "${INSTALL_DIR}/xmrig-guard.sh"

echo "Mengunduh xmrig-guard.logrotate ..."
if curl -fsSL "${REPO_RAW_BASE}/xmrig-guard.logrotate" -o /etc/logrotate.d/xmrig-guard 2>/dev/null; then
    echo "Logrotate dipasang: /etc/logrotate.d/xmrig-guard"
else
    echo "Lewati logrotate (file tidak ditemukan di repo, tidak masalah)."
    rm -f /etc/logrotate.d/xmrig-guard
fi

touch "$LOG_FILE"

# Pasang cron secara idempotent — hapus dulu baris lama (kalau ada) biar tidak dobel
( crontab -l 2>/dev/null | grep -vF "$CRON_MARKER" ; echo "$CRON_LINE" ) | crontab -

echo ""
echo "=== Instalasi selesai ==="
echo "Script : ${INSTALL_DIR}/xmrig-guard.sh"
echo "Log    : $LOG_FILE"
echo "Cron   : $CRON_LINE  (jalan tiap menit)"
echo ""
echo "PENTING: cek/edit konfigurasi (alert Zabbix, pola deteksi tambahan) di:"
echo "  ${INSTALL_DIR}/xmrig-guard.sh"
echo ""
echo "Disarankan tes manual dulu:"
echo "  ${INSTALL_DIR}/xmrig-guard.sh"
echo "  tail -20 $LOG_FILE"
