#!/bin/bash
#
# xmrig-guard.sh — Deteksi, kill, dan hapus file cryptominer (xmrig dkk) di node Pterodactyl
#
# PENTING: script ini HANYA akan bertindak (kill + hapus file) terhadap proses yang
# terbukti berjalan DI DALAM container Docker (punya cgroup docker-<id>). Proses yang
# berjalan langsung di host (termasuk script ini sendiri) SELALU dilewati, hanya dicatat
# sebagai peringatan. Ini untuk mencegah insiden salah-tangkap proses host.
#
# Cara pakai:
#   1. Copy ke /opt/xmrig-guard/xmrig-guard.sh di setiap node
#   2. chmod +x /opt/xmrig-guard/xmrig-guard.sh
#   3. Isi bagian KONFIGURASI di bawah kalau mau kirim alert ke Zabbix (opsional)
#   4. Pasang di cron: */1 * * * * /opt/xmrig-guard/xmrig-guard.sh
#
# ============================ KONFIGURASI ============================

LOGFILE="/var/log/xmrig-guard.log"
STATEFILE="/var/run/xmrig-guard.count"

ZABBIX_SERVER=""       # IP/hostname Zabbix server, kosongkan untuk nonaktifkan
ZABBIX_HOST="node2"    # nama host persis seperti terdaftar di Zabbix
ZABBIX_KEY="xmrig.guard.detected"

PATTERNS='xmrig|xmr-stak|xmrstak|cpuminer|ccminer|cnrig|minerd|nheqminer|ethminer|kdevtmpfsi|stratum\+tcp|supportxmr|nanopool|minexmr|moneroocean|c3pool|hashvault|monero(hash)?|pool\.min(e|ing)xmr'

FILE_PATTERNS='xmrig|xmr-stak|xmrstak|cpuminer|ccminer|cnrig|minerd|config\.json|pools?\.(txt|json)|wallet\.txt'

# ======================================================================

mkdir -p "$(dirname "$LOGFILE")"
touch "$LOGFILE"

FOUND=0
ts_now() { date '+%Y-%m-%d %H:%M:%S'; }

SELF_PID=$$
SELF_PPID=$PPID
SELF_SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null)"

while read -r pid args; do
    [ -z "$pid" ] && continue

    # --- Pengaman 1: jangan pernah sentuh proses script ini sendiri / parent-nya ---
    if [ "$pid" = "$SELF_PID" ] || [ "$pid" = "$SELF_PPID" ]; then
        continue
    fi
    # jangan sentuh proses apapun yang command line-nya memuat path script ini sendiri
    if [ -n "$SELF_SCRIPT_PATH" ] && echo "$args" | grep -qF "$SELF_SCRIPT_PATH"; then
        continue
    fi

    ts=$(ts_now)

    # --- Pengaman 2: WAJIB proses ini terbukti jalan di dalam container Docker ---
    cgroup=$(cat "/proc/$pid/cgroup" 2>/dev/null | grep -o 'docker-[a-f0-9]\{64\}' | head -1)
    if [ -z "$cgroup" ]; then
        echo "[$ts] SKIP (bukan proses container / tidak bisa diverifikasi) pid=$pid cmd=$args" >> "$LOGFILE"
        continue
    fi

    FOUND=$((FOUND + 1))
    container_id=$(echo "$cgroup" | sed 's/^docker-//')
    server_uuid=$(docker inspect --format '{{.Name}}' "$container_id" 2>/dev/null | sed 's#^/##')

    echo "[$ts] MINER DETECTED pid=$pid server_uuid=${server_uuid:-unknown} cmd=$args" >> "$LOGFILE"

    exe_link=$(readlink "/proc/$pid/exe" 2>/dev/null)

    if [ -n "$exe_link" ]; then
        host_exe_path="/proc/$pid/root${exe_link}"
        host_exe_dir="/proc/$pid/root$(dirname "$exe_link")"

        if [ -f "$host_exe_path" ]; then
            rm -f "$host_exe_path" 2>/dev/null \
                && echo "[$ts] FILE DELETED $exe_link (pid=$pid, server_uuid=${server_uuid:-unknown})" >> "$LOGFILE" \
                || echo "[$ts] FILE DELETE FAILED $exe_link (pid=$pid)" >> "$LOGFILE"
        fi

        if [ -d "$host_exe_dir" ]; then
            find "$host_exe_dir" -maxdepth 1 -type f -iregex ".*\($FILE_PATTERNS\)" 2>/dev/null \
              | while read -r extra_file; do
                  rm -f "$extra_file" 2>/dev/null \
                    && echo "[$ts] FILE DELETED $extra_file (pid=$pid, server_uuid=${server_uuid:-unknown})" >> "$LOGFILE"
                done
        fi
    else
        echo "[$ts] WARNING: tidak bisa resolve path binary untuk pid=$pid" >> "$LOGFILE"
    fi

    kill -9 "$pid" 2>/dev/null
    echo "[$ts] KILLED pid=$pid server_uuid=${server_uuid:-unknown}" >> "$LOGFILE"

done < <(ps -eo pid,args --no-headers | grep -Ei "$PATTERNS" | grep -v grep)

echo "$FOUND" > "$STATEFILE"

if [ -n "$ZABBIX_SERVER" ] && command -v zabbix_sender >/dev/null 2>&1; then
    zabbix_sender -z "$ZABBIX_SERVER" -s "$ZABBIX_HOST" -k "$ZABBIX_KEY" -o "$FOUND" >/dev/null 2>&1
fi

exit 0
