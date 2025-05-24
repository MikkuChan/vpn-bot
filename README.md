# Telegram VPN Order Bot

Bot Telegram ini memungkinkan user untuk melakukan pemesanan akun VPN (SSH, VMESS, VLESS, TROJAN), melakukan trial, cek harga, cek saldo, topup via QRIS, dan panel admin untuk mengelola user, saldo, harga, backup/restore, dan layanan lainnya. Bot ini terintegrasi dengan script bash auto-create VPN.

---

## Fitur Utama

- **User:**
  - /start, /menu, /daftar, /cekharga, /saldo, /topup, /trial, /order, /kickme
  - Order akun SSH, VMESS, VLESS, TROJAN (custom/random username/uuid/password)
  - Trial 3 hari (limit harian)
  - Upload bukti transfer QRIS (notifikasi admin)
- **Admin/Owner:**
  - /panel menu admin
  - Tambah/kurangi saldo user
  - Lihat semua user & saldo
  - Ubah harga paket
  - Broadcast pesan ke semua user
  - Statistik user
  - Backup/restore VPN
  - Approve topup
  - Cek & hapus user (SSH/VMESS/VLESS/TROJAN)
  - Addhost, fixcert, restart service, dsb

---

## Struktur Folder/Files

```
vpn-bot/
├── bot.py
├── config.json
├── qris.json
├── users.json         # dibuat otomatis
├── requirements.txt
└── scripts/
    ├── sshcreate.sh
    ├── vmesscreate.sh
    ├── vlesscreate.sh
    ├── trojancreate.sh
    ├── ssh_dell_check.sh
    ├── vmess_dell_check.sh
    ├── vless_dell_check.sh
    ├── trojan_dell_check.sh
    ├── backupvpn.sh
    ├── restorevpn.sh
    ├── addhostvpn.sh
    ├── fixcertvpn.sh
    └── restartservice.sh
```

---

## Cara Install & Konfigurasi

### 1. **Siapkan VPS**

Pastikan sudah terinstall Python 3.8+ dan pip.

### 2. **Clone/Buat Folder Project**

```bash
mkdir vpn-bot
cd vpn-bot
```

### 3. **Copy Semua File**

- Copy kode `bot.py` ke file `bot.py`
- Copy isi `requirements.txt` (lihat bawah) ke file `requirements.txt`
- Copy contoh `config.json`, `qris.json` (di bawah) ke file sesuai
- Taruh semua script bash ke folder `scripts/` (chmod +x scripts/*.sh)

### 4. **Install Library Python**

```bash
pip3 install -r requirements.txt
```

### 5. **Edit config.json**

Isi seperti berikut dan sesuaikan:
```json
{
  "owner_id": XXXXXX,
  "admin_ids": [XXXXXXX],
  "harga": {
    "HP": XXXXXX,
    "OPENWRT": XXXXX
  },
  "limit": {
    "HP": {"quota": XXX, "ip": XXX, "days": XXX},
    "OPENWRT": {"quota": XXX, "ip": XXX, "days": XXX}
  }
}
```
- **owner_id**: ganti ke user ID Telegram owner bot
- **admin_ids**: tambahkan user ID admin lain jika ingin
- **harga/limit**: atur harga/limit sesuai kebutuhan

### 6. **Edit qris.json**

```json
{
  "25000": "https://raw.githubusercontent.com/MikkuChan/payments/main/qr25K.png",
  "50000": "https://raw.githubusercontent.com/MikkuChan/payments/main/qr50K.png",
  "100000": "https://raw.githubusercontent.com/MikkuChan/payments/main/qr100K.png"
}
```
- Ganti link QRIS dengan QRIS pembayaran kamu (upload di imgur/github/dll)

### 7. **Edit bot.py**

- Ganti di bagian:
  ```python
  TOKEN = "ISI_TOKEN_BOT_KAMU"
  ```
  dengan token bot Telegram kamu (dapat dari @BotFather).

### 8. **Jalankan Bot**

```bash
cd /path/ke/vpn-bot
python3 bot.py
```

---

## Agar Bot Jalan Terus (Auto Start Saat VPS Reboot)

### Pilihan 1: Pakai `screen`/`tmux`

```bash
screen -S vpn-bot
python3 bot.py
# tekan Ctrl+A lalu D untuk detach
```

### Pilihan 2: Systemd Service (direkomendasikan)

Buat file `/etc/systemd/system/vpn-bot.service`:

```
[Unit]
Description=Telegram VPN Bot
After=network.target

[Service]
User=root
WorkingDirectory=/path/ke/vpn-bot
ExecStart=/usr/bin/python3 bot.py
Restart=always

[Install]
WantedBy=multi-user.target
```

Aktifkan:
```bash
systemctl daemon-reload
systemctl enable vpn-bot
systemctl start vpn-bot
systemctl status vpn-bot
```

---

## Bagian yang Perlu Diedit

- **TOKEN** di `bot.py`
- **owner_id/admin_ids/harga/limit** di `config.json`
- **Link QRIS** di `qris.json`
- Pastikan script bash di folder `scripts/` sesuai/bisa dieksekusi
- (Opsional) Modifikasi pesan/menu sesuai branding kamu

---

## TroubleShooting

- Jika bot error, cek log di terminal atau `journalctl -u vpn-bot` (mode systemd)
- Jika script bash error, cek permission (`chmod +x scripts/*.sh`)
- Jika QRIS tidak muncul, pastikan linknya direct ke gambar
- Jika ingin fitur tambahan, modifikasi/lanjutkan handler di `bot.py`

---

## Requirements

Lihat file [requirements.txt]([requirements.txt](https://github.com/MikkuChan/vpn-bot/blob/main/requirements.txt)) berikut.

---

## Credits

- Script : [https://github.com/MikkuChan/vpn-bot.git]
- Bot Python: [@MikkuChan_bot]
- Telegran : [http://t.me/fadzdigital]
- Library: python-telegram-bot

---

## License

Bebas digunakan, modifikasi, dan dikembangkan untuk kebutuhan servermu.
