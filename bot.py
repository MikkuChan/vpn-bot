import os
import sys
import json
import subprocess
import random
import datetime
from functools import wraps
from telegram import (
    Update, InlineKeyboardButton, InlineKeyboardMarkup, InputFile
)
from telegram.ext import (
    Application, CommandHandler, MessageHandler,
    filters, CallbackContext, CallbackQueryHandler, ConversationHandler
)

# ===================== KONFIGURASI & DATA =======================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.join(BASE_DIR, "scripts")
USERS_JSON = os.path.join(BASE_DIR, "users.json")
CONFIG_JSON = os.path.join(BASE_DIR, "config.json")
QRIS_JSON = os.path.join(BASE_DIR, "qris.json")

def load_json(f, default):
    if not os.path.exists(f):
        with open(f, "w") as fh: json.dump(default, fh)
    with open(f) as fh: return json.load(fh)

def save_json(f, data):
    tmp = f + ".tmp"
    with open(tmp, "w") as fh: json.dump(data, fh, indent=2)
    os.replace(tmp, f)

config = load_json(CONFIG_JSON, {})
qris = load_json(QRIS_JSON, {})
users = load_json(USERS_JSON, {})

OWNER_ID = config.get("owner_id", 6243379861)
ADMIN_IDS = config.get("admin_ids", [OWNER_ID])
HARGA = config.get("harga", {"HP": 10000, "OPENWRT": 15000})
LIMIT = config.get("limit", {
    "HP": {"quota": 500, "ip": 10, "days": 30},
    "OPENWRT": {"quota": 700, "ip": 20, "days": 30}
})

def get_user(uid):
    uid = str(uid)
    if uid not in users:
        users[uid] = {
            "id": int(uid),
            "username": "",
            "first_name": "",
            "saldo": 0 if int(uid) != OWNER_ID else float("inf"),
            "trial_count": 0,
            "last_trial": "1970-01-01",
            "status": "member"
        }
        save_json(USERS_JSON, users)
    return users[uid]

def update_user(uid, **kwargs):
    u = get_user(uid)
    for k,v in kwargs.items():
        u[k] = v
    users[str(uid)] = u
    save_json(USERS_JSON, users)

def admin_only(func):
    @wraps(func)
    async def wrapper(update: Update, context: CallbackContext):
        uid = update.effective_user.id
        if uid != OWNER_ID and uid not in ADMIN_IDS:
            await update.message.reply_text("❌ Hanya admin/owner yang bisa akses menu ini.")
            return
        return await func(update, context)
    return wrapper

# ===================== UTILITIES ==========================
def get_active_user_count():
    return len([u for u in users.values() if u.get("status","") != "kicked"])

def is_owner(uid):
    return int(uid) == OWNER_ID

def is_admin(uid):
    return int(uid) == OWNER_ID or int(uid) in ADMIN_IDS

def saldo_cukup(uid, tipe):
    if is_owner(uid): return True
    user = get_user(uid)
    return user.get("saldo", 0) >= HARGA[tipe]

def kurangi_saldo(uid, tipe):
    if is_owner(uid): return
    user = get_user(uid)
    user["saldo"] -= HARGA[tipe]
    update_user(uid, saldo=user["saldo"])

def tambah_saldo(uid, jumlah):
    user = get_user(uid)
    if is_owner(uid):
        user["saldo"] = float("inf")
    else:
        user["saldo"] += jumlah
    update_user(uid, saldo=user["saldo"])

def get_menu_keyboard():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("📋 Menu", callback_data="menu"),
         InlineKeyboardButton("📝 Daftar", callback_data="daftar"),
         InlineKeyboardButton("❌ Kickme", callback_data="kickme")],
        [InlineKeyboardButton("💳 Cek Saldo", callback_data="saldo"),
         InlineKeyboardButton("🛒 Order", callback_data="order"),
         InlineKeyboardButton("🔥 Trial", callback_data="trial")]
    ])
    
# ========== USER FEATURE HANDLERS ==========
async def start(update: Update, context: CallbackContext):
    u = update.effective_user
    get_user(u.id)
    msg = (
        f"*Welcome ke VPN Bot!*\n"
        f"Nama: {u.first_name}\nUsername: @{u.username}\nUser ID: `{u.id}`\n"
        f"_Selamat bergabung, silakan gunakan menu di bawah._"
    )
    await update.message.reply_text(msg, parse_mode="Markdown", reply_markup=get_menu_keyboard())

async def menu(update: Update, context: CallbackContext):
    u = update.effective_user
    msg = (
        f"📍 *MENU UTAMA*\n\n"
        f"Halo, {u.first_name}!\nSilahkan pilih layanan di bawah ini:"
    )
    kb = [
        [InlineKeyboardButton("Cek Harga", callback_data="cekharga"),
         InlineKeyboardButton("Cek Saldo", callback_data="saldo")],
        [InlineKeyboardButton("Topup", callback_data="topup"),
         InlineKeyboardButton("Order VPN", callback_data="order")],
        [InlineKeyboardButton("Trial Akun VPN", callback_data="trial")],
        [InlineKeyboardButton("Chat Owner", url="https://t.me/fadzdigital")]
    ]
    if update.message:
        await update.message.reply_text(msg, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(kb))
    else:
        await update.callback_query.message.reply_text(msg, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(kb))

async def daftar(update: Update, context: CallbackContext):
    u = update.effective_user
    update_user(u.id, username=u.username, first_name=u.first_name, status="member")
    msg = (
        f"Selamat datang, {u.first_name}!\nAkun Anda berhasil terdaftar di sistem.\n\n"
        f"Berikut informasi akun Anda:\n"
        f"• Username Telegram: @{u.username}\n"
        f"• ID Pengguna: {u.id}\n"
        f"• Status: Member Baru\n\n"
        f"Gunakan perintah /menu untuk melihat fitur yang tersedia.\n"
        f"Jika butuh bantuan, hubungi admin: @fadzdigital"
    )
    await update.message.reply_text(msg)

async def kickme(update: Update, context: CallbackContext):
    u = update.effective_user
    update_user(u.id, status="kicked")
    await update.message.reply_text(
        "❌ Anda telah keluar dari sistem.\n\n"
        "Jika ingin kembali menggunakan layanan, silakan kirim perintah:\n"
        "/daftar untuk registrasi ulang.\n\n"
        "Terima kasih telah menggunakan bot ini!"
    )

async def ceksaldo(update: Update, context: CallbackContext):
    u = update.effective_user
    saldo = get_user(u.id).get("saldo", 0)
    if is_owner(u.id):
        saldo = "Unlimited (Owner)"
    await update.message.reply_text(f"💰 Saldo Anda: *{saldo}*", parse_mode="Markdown")

async def cekharga(update: Update, context: CallbackContext):
    limit_hp = LIMIT.get("HP", {"quota":500,"ip":10,"days":30})
    limit_openwrt = LIMIT.get("OPENWRT", {"quota":700,"ip":20,"days":30})
    await update.message.reply_text(
        f"*Harga VPN:*\n\n"
        f"HP: Rp {HARGA['HP']:,} (Limit: {limit_hp['quota']}GB/{limit_hp['ip']} IP/{limit_hp['days']} hari)\n"
        f"OPENWRT: Rp {HARGA['OPENWRT']:,} (Limit: {limit_openwrt['quota']}GB/{limit_openwrt['ip']} IP/{limit_openwrt['days']} hari)",
        parse_mode="Markdown"
    )

# ========== QRIS TOPUP ==========
async def topup(update: Update, context: CallbackContext):
    kb = [
        [InlineKeyboardButton("25.000", callback_data="qris_25000"),
         InlineKeyboardButton("50.000", callback_data="qris_50000"),
         InlineKeyboardButton("100.000", callback_data="qris_100000")]
    ]
    await update.message.reply_text("Pilih nominal topup:", reply_markup=InlineKeyboardMarkup(kb))

async def qris_callback(update: Update, context: CallbackContext):
    query = update.callback_query
    jumlah = query.data.split("_")[1]
    url = qris.get(jumlah)
    if not url:
        await query.answer("QRIS tidak ditemukan.")
        return
    await query.message.reply_photo(
        photo=url,
        caption=f"Silakan transfer Rp {int(jumlah):,} ke QRIS di atas.\n"
                f"Upload bukti transfer (foto) ke chat ini.\n\nSetelah upload, admin akan menerima notifikasi dan saldo Anda akan di-approve manual.",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("Upload Bukti", callback_data=f"bukti_{jumlah}")]
        ])
    )
    await query.answer()

# ========== TRIAL MENU ==========
async def trial_menu(update: Update, context: CallbackContext):
    kb = [
        [InlineKeyboardButton("SSH", callback_data="trial_ssh"),
         InlineKeyboardButton("VMESS", callback_data="trial_vmess"),
         InlineKeyboardButton("VLESS", callback_data="trial_vless"),
         InlineKeyboardButton("TROJAN", callback_data="trial_trojan")]
    ]
    await update.callback_query.message.reply_text(
        "Pilih protokol trial:",
        reply_markup=InlineKeyboardMarkup(kb)
    )

async def handle_trial(update: Update, context: CallbackContext, proto: str):
    u = update.effective_user
    user = get_user(u.id)
    today = datetime.date.today().isoformat()
    # Kuota trial: max 2x sehari, reset tiap 3 hari
    if user["trial_count"] >= 2 and user["last_trial"] == today:
        await update.callback_query.message.reply_text("Kuota trial hari ini sudah habis. Silakan coba lagi besok.")
        return
    username = f"trial{random.randint(10000,99999)}"
    if proto == "ssh":
        script = os.path.join(SCRIPTS, "sshcreate.sh")
        cmd = ["bash", script, "create", username, "3", "1", "10"]
    elif proto == "vmess":
        script = os.path.join(SCRIPTS, "vmesscreate.sh")
        cmd = ["bash", script, "create", username, "3", "1", "10"]
    elif proto == "vless":
        script = os.path.join(SCRIPTS, "vlesscreate.sh")
        cmd = ["bash", script, "create", username, "3", "1", "10"]
    elif proto == "trojan":
        script = os.path.join(SCRIPTS, "trojancreate.sh")
        cmd = ["bash", script, "create", username, "3", "1", "10"]
    else:
        await update.callback_query.message.reply_text("Protokol tidak dikenali.")
        return
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = proc.communicate()
    if proc.returncode == 0:
        await update.callback_query.message.reply_text(f"Berhasil membuat trial {proto.upper()} 3 hari:\n\n{out.decode()}")
        # Update trial count
        if user["last_trial"] != today:
            user["trial_count"] = 1
            user["last_trial"] = today
        else:
            user["trial_count"] += 1
        update_user(u.id, trial_count=user["trial_count"], last_trial=today)
    else:
        await update.callback_query.message.reply_text(f"Gagal trial {proto.upper()}:\n{err.decode()}")

# ========== ORDER MENU ==========
async def order_menu(update: Update, context: CallbackContext):
    kb = [
        [InlineKeyboardButton("HP", callback_data="order_HP"),
         InlineKeyboardButton("OPENWRT", callback_data="order_OPENWRT")],
    ]
    await update.callback_query.message.reply_text(
        "Pilih tipe order:",
        reply_markup=InlineKeyboardMarkup(kb)
    )

async def handle_order_step1(update: Update, context: CallbackContext, tipe: str):
    # Step 1: Pilih protokol
    kb = [
        [InlineKeyboardButton("SSH", callback_data=f"order2_{tipe}_ssh"),
         InlineKeyboardButton("TROJAN", callback_data=f"order2_{tipe}_trojan"),
         InlineKeyboardButton("VLESS", callback_data=f"order2_{tipe}_vless"),
         InlineKeyboardButton("VMESS", callback_data=f"order2_{tipe}_vmess")]
    ]
    await update.callback_query.message.reply_text(
        f"Pilih protokol order untuk {tipe}:",
        reply_markup=InlineKeyboardMarkup(kb)
    )

# ========== ORDER USER PROSES LANJUTAN (custom/random/uuid/password) ==========
async def handle_order_step2(update: Update, context: CallbackContext, tipe, proto):
    # Step 2: Pilih random/custom
    if proto == "ssh":
        kb = [
            [InlineKeyboardButton("Password Random", callback_data=f"order3_{tipe}_{proto}_random"),
             InlineKeyboardButton("Password Custom", callback_data=f"order3_{tipe}_{proto}_custom")]
        ]
    elif proto in ["vmess", "vless", "trojan"]:
        kb = [
            [InlineKeyboardButton("UUID Random", callback_data=f"order3_{tipe}_{proto}_random"),
             InlineKeyboardButton("UUID Custom", callback_data=f"order3_{tipe}_{proto}_custom")]
        ]
    else:
        await update.callback_query.message.reply_text("Protokol tidak dikenali.")
        return
    await update.callback_query.message.reply_text(
        "Pilih tipe akun (random/custom):",
        reply_markup=InlineKeyboardMarkup(kb)
    )

async def button_handler(update: Update, context: CallbackContext):
    query = update.callback_query
    data = query.data

    if data == "menu":
        await menu(update, context)
    elif data == "daftar":
        await daftar(update, context)
    elif data == "saldo":
        await ceksaldo(update, context)
    elif data == "cekharga":
        await cekharga(update, context)
    elif data == "topup":
        await topup(update, context)
    elif data == "order":
        await order_menu(update, context)
    elif data == "trial":
        await trial_menu(update, context)
    elif data == "kickme":
        await kickme(update, context)
    elif data.startswith("qris_"):
        await qris_callback(update, context)
    elif data.startswith("trial_"):
        proto = data.split("_")[1]
        await handle_trial(update, context, proto)
    elif data.startswith("order_"):
        tipe = data.split("_")[1]
        await handle_order_step1(update, context, tipe)
    elif data.startswith("order2_"):
        _, tipe, proto = data.split("_")
        await handle_order_step2(update, context, tipe, proto)
    elif data.startswith("order3_"):
        # order3_HP_ssh_random / order3_OPENWRT_vmess_custom
        _, tipe, proto, tipeakun = data.split("_")
        context.user_data["order_pending"] = {"tipe":tipe, "proto":proto, "mode":tipeakun}
        await update.callback_query.message.reply_text("Kirim username yang diinginkan (tanpa spasi, huruf/angka):")
    elif data.startswith("bukti_"):
        await update.callback_query.message.reply_text("Silakan upload bukti transfer berupa foto ke chat ini.\nAdmin akan menerima notifikasi otomatis.")
    # Panel/admin handled below
    elif data == "panel":
        await panel(update, context)
    elif data.startswith("admin_"):
        await handle_admin_menu(update, context, data)
    # Tambah fitur lain sesuai kebutuhan

# ========== ORDER USER INPUT (custom/random/uuid/password) ==========
async def message_handler(update: Update, context: CallbackContext):
    u = update.effective_user
    # ORDER USER
    if "order_pending" in context.user_data:
        info = context.user_data.pop("order_pending")
        username = update.message.text.strip()
        if not username.isalnum() or len(username) < 3:
            await update.message.reply_text("Username harus minimal 3 karakter dan hanya huruf/angka.")
            return
        now = datetime.datetime.now()
        username_full = f"{username}{now.strftime('%d%m')}{random.randint(100,999)}"
        tipe = info["tipe"].upper()
        proto = info["proto"].lower()
        mode = info["mode"]
        days = str(LIMIT[tipe]["days"])
        quota = str(LIMIT[tipe]["quota"])
        ip = str(LIMIT[tipe]["ip"])
        if mode == "random":
            # SSH random password / VMESS,VLESS,TROJAN random UUID
            if proto == "ssh":
                script = os.path.join(SCRIPTS, "sshcreate.sh")
                cmd = ["bash", script, "create", username_full, days, quota, ip]
            else:
                script = os.path.join(SCRIPTS, f"{proto}create.sh")
                cmd = ["bash", script, "create", username_full, days, quota, ip]
        else:
            await update.message.reply_text("Kirim password custom (untuk SSH) / UUID custom (untuk VMESS/VLESS/TROJAN):\nFormat: username|passwordatauUUID")
            context.user_data["order_custom"] = {"tipe":tipe, "proto":proto, "username":username_full, "days":days, "quota":quota, "ip":ip}
            return
        # Cek saldo
        if not saldo_cukup(u.id, tipe):
            await update.message.reply_text("❌ Saldo Anda tidak cukup untuk order ini.")
            return
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = proc.communicate()
        if proc.returncode == 0:
            await update.message.reply_text(f"✅ Order {proto.upper()} {tipe} berhasil!\n\n{out.decode()}")
            kurangi_saldo(u.id, tipe)
        else:
            await update.message.reply_text(f"❌ Gagal order:\n{err.decode()}")
    elif "order_custom" in context.user_data:
        # Handle custom password/uuid
        info = context.user_data.pop("order_custom")
        val = update.message.text.strip()
        if "|" not in val:
            await update.message.reply_text("Format salah! Kirim: username|passwordatauUUID")
            return
        _username, pwd = val.split("|",1)
        script = os.path.join(SCRIPTS, f"{info['proto']}create.sh")
        cmd = ["bash", script, "create", info["username"], pwd, info["days"], info["quota"], info["ip"]]
        u = update.effective_user
        if not saldo_cukup(u.id, info["tipe"]):
            await update.message.reply_text("❌ Saldo Anda tidak cukup untuk order ini.")
            return
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = proc.communicate()
        if proc.returncode == 0:
            await update.message.reply_text(f"✅ Order {info['proto'].upper()} {info['tipe']} berhasil!\n\n{out.decode()}")
            kurangi_saldo(u.id, info["tipe"])
        else:
            await update.message.reply_text(f"❌ Gagal order:\n{err.decode()}")
    # UPLOAD BUKTI TOPUP
    elif update.message.photo:
        u = update.effective_user
        photo_file = await update.message.photo[-1].get_file()
        file_path = f"bukti_{u.id}_{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}.jpg"
        await photo_file.download_to_drive(file_path)
        # Kirim ke semua admin
        for admin_id in ADMIN_IDS:
            try:
                await context.bot.send_photo(
                    chat_id=admin_id,
                    photo=open(file_path, "rb"),
                    caption=f"[TOPUP]\nDari: @{u.username} (ID: {u.id})\nWaktu: {datetime.datetime.now()}\nFile: {file_path}"
                )
            except:
                pass
        await update.message.reply_text("Bukti transfer diterima. Tunggu approval admin.")
        os.remove(file_path)
    else:
        await update.message.reply_text("Perintah tidak dikenali. Gunakan /menu untuk melihat fitur.")

# ========== ADMIN PANEL & FITUR-FITUR ==========
@admin_only
async def panel(update: Update, context: CallbackContext):
    kb = [
        [InlineKeyboardButton("Tambah/Kurang Saldo", callback_data="admin_saldo"),
         InlineKeyboardButton("Lihat User & Saldo", callback_data="admin_listuser")],
        [InlineKeyboardButton("Ubah Harga VPN", callback_data="admin_harga"),
         InlineKeyboardButton("Backup & Restore", callback_data="admin_backuprestore")],
        [InlineKeyboardButton("Broadcast", callback_data="admin_broadcast"),
         InlineKeyboardButton("Statistik", callback_data="admin_statistik")],
        [InlineKeyboardButton("FixCertVPN", callback_data="admin_fixcertvpn"),
         InlineKeyboardButton("Restart Service", callback_data="admin_restartservice")],
        [InlineKeyboardButton("Cek User", callback_data="admin_cekuser"),
         InlineKeyboardButton("Delete User", callback_data="admin_deluser"),
         InlineKeyboardButton("Addhost", callback_data="admin_addhost")],
        [InlineKeyboardButton("Kembali ke Menu User", callback_data="menu")]
    ]
    await update.message.reply_text("🛠️ PANEL ADMIN", reply_markup=InlineKeyboardMarkup(kb))

# ========== ADMIN FITUR PANEL LANJUTAN: Tambah/Kurang Saldo, Lihat User, Ubah Harga, Statistik, Broadcast, Backup/Restore, Approve Topup, Cek/Del User ==========

async def handle_admin_menu(update: Update, context: CallbackContext, data):
    query = update.callback_query
    if data == "admin_saldo":
        await query.message.reply_text("Kirim perintah:\n/tambahsaldo user_id jumlah\natau\n/kurangisaldo user_id jumlah")
    elif data == "admin_listuser":
        msg = "Daftar user:\n"
        for u in users.values():
            msg += f"- {u['first_name']} (@{u['username']}) | ID: {u['id']} | Saldo: {u.get('saldo',0)} | Status: {u.get('status','')}\n"
        await query.message.reply_text(msg)
    elif data == "admin_harga":
        await query.message.reply_text(f"Harga saat ini: HP: {HARGA['HP']}, OPENWRT: {HARGA['OPENWRT']}\nKirim /setharga hp openwrt (contoh: /setharga 10000 15000)")
    elif data == "admin_backuprestore":
        await query.message.reply_text("Kirim /backupvpn untuk backup, /restorevpn <url> untuk restore.")
    elif data == "admin_broadcast":
        await query.message.reply_text("Kirim /broadcast pesan_anda")
    elif data == "admin_statistik":
        msg = f"Jumlah user aktif : {get_active_user_count()}\n"
        msg += f"Total user       : {len(users)}\n"
        await query.message.reply_text(msg)
    elif data == "admin_fixcertvpn":
        script = os.path.join(SCRIPTS, "fixcertvpn.sh")
        cmd = ["bash", script]
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = proc.communicate()
        if proc.returncode == 0:
            await query.message.reply_text("✅ Fix SSL selesai:\n"+out.decode())
        else:
            await query.message.reply_text("❌ Gagal fix SSL:\n"+err.decode())
    elif data == "admin_restartservice":
        script = os.path.join(SCRIPTS, "restartservice.sh")
        cmd = ["bash", script]
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = proc.communicate()
        if proc.returncode == 0:
            await query.message.reply_text("✅ Restart service selesai:\n"+out.decode())
        else:
            await query.message.reply_text("❌ Gagal restart:\n"+err.decode())
    elif data == "admin_cekuser":
        kb = [
            [InlineKeyboardButton("SSH", callback_data="admin_cekuser_ssh"),
             InlineKeyboardButton("VMESS", callback_data="admin_cekuser_vmess"),
             InlineKeyboardButton("VLESS", callback_data="admin_cekuser_vless"),
             InlineKeyboardButton("TROJAN", callback_data="admin_cekuser_trojan")]
        ]
        await query.message.reply_text("Cek user layanan apa?", reply_markup=InlineKeyboardMarkup(kb))
    elif data.startswith("admin_cekuser_"):
        layanan = data.split("_")[-1]
        script = os.path.join(SCRIPTS, f"{layanan}_dell_check.sh")
        cmd = ["bash", script, "check"]
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = proc.communicate()
        if proc.returncode == 0:
            await query.message.reply_text(out.decode()[:4096], parse_mode="Markdown")
        else:
            await query.message.reply_text("❌ Gagal cek user:\n"+err.decode())
    elif data == "admin_deluser":
        await query.message.reply_text("Kirim: /deluser jenis username\nContoh: /deluser ssh namauser")
    elif data == "admin_addhost":
        await query.message.reply_text("Kirim: /addhost domain.com")
    else:
        await query.message.reply_text("Menu admin tidak dikenali.")

# ========== ADMIN COMMANDS (SALDO, HARGA, BROADCAST, BACKUP, RESTORE, DELUSER, ADDHOST) ==========

@admin_only
async def tambahsaldo(update: Update, context: CallbackContext):
    args = context.args
    if len(args) != 2:
        await update.message.reply_text("Format: /tambahsaldo user_id jumlah")
        return
    uid, jumlah = args
    try:
        tambah_saldo(uid, int(jumlah))
        await update.message.reply_text("✅ Saldo berhasil ditambah.")
    except:
        await update.message.reply_text("❌ Gagal tambah saldo.")

@admin_only
async def kurangisaldo(update: Update, context: CallbackContext):
    args = context.args
    if len(args) != 2:
        await update.message.reply_text("Format: /kurangisaldo user_id jumlah")
        return
    uid, jumlah = args
    try:
        user = get_user(uid)
        user["saldo"] -= int(jumlah)
        update_user(uid, saldo=user["saldo"])
        await update.message.reply_text("✅ Saldo berhasil dikurangi.")
    except:
        await update.message.reply_text("❌ Gagal kurangi saldo.")

@admin_only
async def setharga(update: Update, context: CallbackContext):
    args = context.args
    if len(args) != 2:
        await update.message.reply_text("Format: /setharga hp openwrt")
        return
    hp, openwrt = args
    HARGA["HP"] = int(hp)
    HARGA["OPENWRT"] = int(openwrt)
    config["harga"] = HARGA
    save_json(CONFIG_JSON, config)
    await update.message.reply_text("✅ Harga berhasil diubah.")

@admin_only
async def broadcast(update: Update, context: CallbackContext):
    msg = " ".join(context.args)
    if not msg:
        await update.message.reply_text("Format: /broadcast isi_pesan")
        return
    cnt = 0
    for u in users.values():
        try:
            await context.bot.send_message(chat_id=u["id"], text=msg)
            cnt += 1
        except:
            pass
    await update.message.reply_text(f"Broadcast terkirim ke {cnt} user.")

@admin_only
async def backupvpn(update: Update, context: CallbackContext):
    script = os.path.join(SCRIPTS, "backupvpn.sh")
    cmd = ["bash", script]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = proc.communicate()
    if proc.returncode == 0:
        await update.message.reply_text("Backup selesai!\n" + out.decode())
    else:
        await update.message.reply_text("Backup gagal:\n" + err.decode())

@admin_only
async def restorevpn(update: Update, context: CallbackContext):
    args = context.args
    if not args:
        await update.message.reply_text("Format: /restorevpn url_backup")
        return
    url = args[0]
    script = os.path.join(SCRIPTS, "restorevpn.sh")
    cmd = ["bash", script, url]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = proc.communicate()
    if proc.returncode == 0:
        await update.message.reply_text("Restore selesai!\n" + out.decode())
    else:
        await update.message.reply_text("Restore gagal:\n" + err.decode())

@admin_only
async def deluser(update: Update, context: CallbackContext):
    args = context.args
    if len(args) != 2:
        await update.message.reply_text("Format: /deluser jenis username\nContoh: /deluser ssh namauser")
        return
    jenis, uname = args
    script = os.path.join(SCRIPTS, f"{jenis.lower()}_dell_check.sh")
    cmd = ["bash", script, "delete", uname]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = proc.communicate()
    if proc.returncode == 0:
        await update.message.reply_text(out.decode())
    else:
        await update.message.reply_text("Gagal hapus user:\n" + err.decode())

@admin_only
async def addhost(update: Update, context: CallbackContext):
    args = context.args
    if not args:
        await update.message.reply_text("Format: /addhost domain.com")
        return
    domain = args[0]
    script = os.path.join(SCRIPTS, "addhostvpn.sh")
    cmd = ["bash", script, domain]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = proc.communicate()
    if proc.returncode == 0:
        await update.message.reply_text(out.decode())
    else:
        await update.message.reply_text("Gagal addhost:\n" + err.decode())

# ========== MAIN LOOP ==========
def main():
    TOKEN = "7923489458:AAHYRKCmySlxbXgtbBaUlk7wgujYhBHG6aw"  # <-- Ganti token bot Telegram kamu
    app = Application.builder().token(TOKEN).build()
    # USER
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("menu", menu))
    app.add_handler(CommandHandler("daftar", daftar))
    app.add_handler(CommandHandler("kickme", kickme))
    app.add_handler(CommandHandler("saldo", ceksaldo))
    app.add_handler(CommandHandler("cekharga", cekharga))
    app.add_handler(CommandHandler("topup", topup))
    # ADMIN
    app.add_handler(CommandHandler("panel", panel))
    app.add_handler(CommandHandler("tambahsaldo", tambahsaldo))
    app.add_handler(CommandHandler("kurangisaldo", kurangisaldo))
    app.add_handler(CommandHandler("setharga", setharga))
    app.add_handler(CommandHandler("broadcast", broadcast))
    app.add_handler(CommandHandler("backupvpn", backupvpn))
    app.add_handler(CommandHandler("restorevpn", restorevpn))
    app.add_handler(CommandHandler("deluser", deluser))
    app.add_handler(CommandHandler("addhost", addhost))
    # CALLBACKS & MSG
    app.add_handler(CallbackQueryHandler(button_handler))
    app.add_handler(MessageHandler(filters.ALL, message_handler))
    app.run_polling()

if __name__ == "__main__":
    main()

