# xmrig-guard

Deteksi otomatis proses cryptominer (xmrig dan varian sejenis) yang berjalan di
dalam container Docker pada node hosting (dipakai untuk node Pterodactyl), lalu
kill prosesnya dan hapus file binary/config-nya.

## Cara kerja

Setiap kali dijalankan (lewat cron, default tiap menit), script:

1. Scan `ps -eo pid,args` di host, cari proses yang cocok pola nama/cmdline
   miner umum (xmrig, cpuminer, ccminer, koneksi ke pool seperti
   `supportxmr.com`, `nanopool`, dll — daftar lengkap ada di variabel
   `PATTERNS` dalam script).
2. **Wajib verifikasi** proses itu benar-benar berjalan **di dalam container
   Docker** (cek cgroup `/proc/<pid>/cgroup`). Kalau tidak terbukti berada di
   container, proses **dilewati** (`SKIP`) — tidak pernah disentuh, walau
   cmdline-nya cocok pola. Ini mencegah script salah tangkap proses milik host
   itu sendiri.
3. Untuk proses yang lolos verifikasi: resolve lokasi file binary-nya lewat
   `/proc/<pid>/exe` (masih bisa diakses dari host walau proses ada di
   namespace container), hapus binary tersebut beserta file pendukung di
   direktori yang sama (config.json, pools.txt, wallet.txt, dll — lihat
   `FILE_PATTERNS`), baru kemudian `kill -9` prosesnya.
4. Semua aksi (deteksi, file dihapus, kill, skip) dicatat ke
   `/var/log/xmrig-guard.log`.
5. Opsional: kirim jumlah deteksi ke Zabbix trapper item lewat `zabbix_sender`.

## Instalasi

### Cara tercepat — satu baris perintah (tanpa git)

```bash
curl -fsSL https://raw.githubusercontent.com/<user-atau-org>/xmrig-guard/main/install-remote.sh | sudo bash
```

Perintah ini langsung download `xmrig-guard.sh` + `xmrig-guard.logrotate` dari
repo, pasang ke `/opt/xmrig-guard/`, dan setup cron — semua dalam satu
eksekusi, tidak perlu `git clone` atau download manual.

> **Sebelum dipakai:** buka `install-remote.sh` di repo, ganti
> `<user-atau-org>` pada baris `REPO_RAW_BASE` dengan username/org GitHub
> kamu yang sebenarnya, baru upload ke repo. Kalau tidak diganti, download
> filenya akan gagal (404).

### Cara alternatif — clone repo dulu

```bash
git clone https://github.com/<user-atau-org>/xmrig-guard.git
cd xmrig-guard
sudo ./install.sh
```

Kedua cara di atas menghasilkan hasil akhir yang sama:
- Copy `xmrig-guard.sh` ke `/opt/xmrig-guard/`
- Pasang `xmrig-guard.logrotate` ke `/etc/logrotate.d/xmrig-guard`
- Pasang cron `* * * * * /opt/xmrig-guard/xmrig-guard.sh` (idempotent — aman dijalankan berkali-kali, tidak akan dobel)

### Multi-node

Untuk pasang ke banyak node sekaligus lewat SSH loop, pakai versi satu baris:

```bash
for host in node1 node2 node3; do
  ssh root@$host "curl -fsSL https://raw.githubusercontent.com/<user-atau-org>/xmrig-guard/main/install-remote.sh | sudo bash"
done
```

## Konfigurasi

Edit langsung bagian `KONFIGURASI` di `/opt/xmrig-guard/xmrig-guard.sh`
setelah instalasi:

| Variabel | Fungsi |
|---|---|
| `LOGFILE` | Lokasi file log |
| `ZABBIX_SERVER` | IP/hostname Zabbix server; kosongkan untuk nonaktifkan alert |
| `ZABBIX_HOST` | Nama host persis seperti terdaftar di Zabbix |
| `ZABBIX_KEY` | Key item trapper Zabbix |
| `PATTERNS` | Regex nama proses/cmdline yang dianggap mencurigakan |
| `FILE_PATTERNS` | Regex nama file di sekitar binary yang ikut dihapus |

## Uninstall

```bash
sudo ./uninstall.sh
```

## Batasan yang perlu dipahami

- **Ini reaktif, bukan pencegahan.** Kalau container jadi sumber (misal lewat
  plugin/mod yang di-exploit), miner bisa muncul lagi tiap kali proses
  restart sampai celah keamanannya ditutup manual.
- Deteksi berbasis pola nama proses/cmdline — miner yang menyamar dengan nama
  proses generik (`kworker`, dll dengan nama acak) bisa lolos. Tambah pola di
  `PATTERNS` kalau nemu varian baru.
- Script butuh akses `docker` di PATH untuk verifikasi cgroup. Tanpa itu,
  semua proses akan di-skip (fail-safe, bukan fail-open).
- Selalu tes manual (`/opt/xmrig-guard/xmrig-guard.sh` lalu cek log) sebelum
  mengandalkan cron di lingkungan produksi baru.

## Lisensi

MIT — pakai, modifikasi, dan distribusikan bebas.
