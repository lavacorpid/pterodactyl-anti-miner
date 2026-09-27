#!/bin/bash
#
# uninstall.sh — Copot xmrig-guard dari node ini
#
# Jalankan sebagai root:
#   sudo ./uninstall.sh
#
set -euo pipefail

INSTALL_DIR="/opt/xmrig-guard"
CRON_MARKER="${INSTALL_DIR}/xmrig-guard.sh"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: jalankan sebagai root (sudo ./uninstall.sh)" >&2
    exit 1
fi

crontab -l 2>/dev/null | grep -vF "$CRON_MARKER" | crontab - 2>/dev/null || true
rm -f /etc/logrotate.d/xmrig-guard
rm -rf "$INSTALL_DIR"

echo "xmrig-guard sudah di-uninstall (cron, script, dan logrotate config dihapus)."
echo "Log lama tetap ada di /var/log/xmrig-guard.log — hapus manual kalau tidak dibutuhkan:"
echo "  rm -f /var/log/xmrig-guard.log"
