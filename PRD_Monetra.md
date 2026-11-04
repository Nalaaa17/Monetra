# 📱 PRD — Aplikasi Pencatatan Keuangan Pribadi (Multi-Wallet)

| | |
|---|---|
| **Nama proyek** | Monetra |
| **Platform** | Android & iOS (Flutter, satu codebase) |
| **Pengguna** | 1 orang (pemakaian pribadi) |
| **Mode** | Offline-first, data tersimpan lokal di HP |
| **Versi dokumen** | 1.0 |
| **Tanggal** | 4 November 2026 |
| **Status** | Siap untuk development |

---

## 1. Ringkasan Produk (Executive Summary)

### 1.1 Latar Belakang
Saat ini pengguna mencatat keuangan di aplikasi Notes HP secara manual (teks bebas), dengan format:

```
Uang Di tanggal 21 : Rp 1.550.000
Pengeluaran tanggal 21 :
  Bensin Rp 50.000
  Bahan masakan Rp 38.000
Total : Rp 88.000
Uang tersisa : Rp 1.462.000
```

Masalahnya:
- Tidak tahu **sisa uang valid** secara otomatis — harus dihitung manual tiap transaksi
- Uang tersebar di **3 sumber berbeda dengan tujuan berbeda** (Cash, Seabank, Mandiri) tapi dicampur dalam satu catatan teks
- Tidak ada rekapitulasi: pengeluaran terbesar di kategori apa, tabungan berapa, dll
- Rentan salah ketik & tidak ada histori terstruktur

### 1.2 Tujuan Produk
Aplikasi mobile Flutter yang menggantikan catatan Notes dengan sistem **multi-wallet otomatis**:
1. Saldo tiap sumber uang (akun) terhitung otomatis dan selalu valid
2. Setiap akun punya **tujuan/fungsi jelas** — tidak tercampur
3. Pengeluaran tercatat per hari, per kategori, per akun (otomatis, bukan diketik manual)
4. Ada fitur **Goal/Tabungan bergaransi** dengan pengingat jatuh tempo
5. Antarmuka **cerah, enak dilihat, dan hidup** berkat animasi yang halus

### 1.3 Target Pengguna
- Pengguna tunggal (pribadi), bukan multi-user
- Perangkat: 1 HP Android/iOS
- Pola pemakaian: mencatat 3–10 transaksi per hari, pengecekan saldo beberapa kali sehari

---

## 2. Ruang Lingkup (Scope)

### 2.1 In Scope (versi 1.0 — MVP + Goal)
| Fitur | Keterangan |
|---|---|
| Multi-wallet (akun) | Minimal 3 akun default: Cash, Seabank, Mandiri. Bisa tambah/ubah/hapus akun |
| Transaksi pemasukan & pengeluaran | Terikat ke satu akun, pilih kategori, tanggal otomatis |
| Saldo otomatis per akun | Saldo = saldo awal + pemasukan − pengeluaran ± transfer |
| Transfer antar akun | Pindah uang antar akun tanpa mengubah total keseluruhan |
| Riwayat harian | Format per tanggal (mirip kebiasaan di Notes), tapi otomatis dengan total harian |
| Kategori pengeluaran | Default: Bensin, Makan, Jajan, Belanja Dapur, Hiburan, Tagihan, Lainnya. Bisa tambah sendiri |
| Laporan bulanan | Total masuk vs keluar, per akun, per kategori, grafik batang & donat |
| Goal / Target | Target uang dengan nominal, tenggat, progres, dan pengingat H-3 |
| Pengingat jatuh tempo | Notifikasi lokal (tanpa internet) |
| Dark mode | Opsional, tapi **default tema cerah** |

### 2.2 Out of Scope (tidak dikerjakan di v1.0)
- Sinkronisasi cloud / multi-perangkat
- Login akun / keamanan PIN
- Multi-user / berbagi data
- Multi-mata-uang
- Integrasi dengan SMS/M-banking
- Ekspor ke PDF/Excel (masuk backlog)
- Scan struk / OCR

---

## 3. Definisi Akun (Wallet)

| Akun | Jenis | Fungsi | Aturan |
|---|---|---|---|
| 🏦 Seabank | Bank digital | **Tabungan** | Uang yang masuk disini jangan keluar kecuali untuk goal/tujuan besar |
| 🏦 Mandiri | Bank | **Operasional harian** | Bayaran, cicilan, pengeluaran besar harian |
| 💵 Cash | Tunai | **Operasional harian** | Bensin, jajan, belanja kecil |

**Aturan agregasi:**
- "Uang Dipakai Sehari-hari" = Mandiri + Cash
- "Tabungan" = Seabank
- Home screen menampilkan keduanya terpisah, jadi pengguna bisa langsung menjawab:
  - *"Uang jalan saya sisa berapa?"* → lihat agregasi harian
  - *"Tabungan saya udah berapa?"* → lihat Seabank

Pengguna bisa menambah akun baru (misal: rekening lain, dompet digital) dengan nama, jenis (Bank/Tunai/Dompet Digital/E-wallet), warna, dan saldo awal.

---

## 4. Fitur Detail

### 4.1 Transaksi
**Atribut:**
- Jenis: `pemasukan` | `pengeluaran`
- Jumlah (Rupiah, integer, tanpa desimal)
- Akun (wajib)
- Kategori (wajib untuk pengeluaran; opsional untuk pemasukan)
- Catatan opsional (bebas, misal "Bayar Ressa")
- Tanggal & jam (default: sekarang)
- Tipe: `transaction` | `transfer`

**Aturan bisnis:**
- Pengeluaran tidak boleh membuat saldo akun minus — tampilkan warning konfirmasi jika saldo kurang (perbolehkan override dengan catatan "negatif sementara")
- Pemasukan menambah saldo akun yang dipilih
- Transfer memindahkan saldo dari akun A ke akun B (2 akun berubah, total keseluruhan tetap)
- Semua perubahan saldo otomatis terhitung; **tidak ada input "uang tersisa" manual**

### 4.2 Riwayat Harian
- Ditampilkan per tanggal (paling baru di atas), persis ala catatan Notes:
  ```
  Senin, 23 Nov 2026
    • Bayar Ressa — Pengeluaran — Mandiri — Rp 710.000
    • Makan di kampus — Pengeluaran — Cash — Rp 15.000
    • Tambahan uang — Pemasukan — Mandiri — +Rp 250.000
  Total keluar: Rp 735.000 · Total masuk: Rp 250.000
  ```
- Tiap item bisa di-tap untuk **edit / hapus** (dengan animasi bottom sheet)
- Filter: per akun, per kategori, per rentang tanggal, jenis (masuk/keluar)

### 4.3 Kategori
- Default: Bensin ⛽, Makan 🍚, Jajan 🍭, Belanja Dapur 🛒, Hiburan 🎮, Tagihan 🧾, Kesehatan 💊, Lainnya 📦
- Setiap kategori punya **ikon + warna**
- Bisa tambah, ubah nama, ubah ikon/warna, hapus (kategori yang sudah dipakai tidak bisa dihapus, hanya disembunyikan)
- Laporan mengelompokkan pengeluaran per kategori

### 4.4 Goal / Target Tabungan
**Atribut:**
- Nama goal (misal: "Bayar Ressa tiap tanggal 23")
- Target nominal (misal: Rp 710.000)
- Tanggal jatuh tempo / tenggat (bisa berulang bulanan)
- Akun sumber pengisian (misal: Mandiri)
- Progres terkumpul
- Status: `aktif` | `tercapai` | `lewat`

**Perilaku:**
- Pengguna bisa isi goal kapan saja (dari halaman Goal)
- Progres ditampilkan sebagai **progress bar animasi** + persen
- Notifikasi lokal **H-3** sebelum tenggat (bisa diatur on/off per goal)
- Goal bulanan berulang otomatis reset progres setelah tanggal jatuh tempo terlewati

**Contoh nyata dari kebutuhan pengguna:**
- "Bayar Ressa" — Rp 710.000 — tiap tanggal 23
- "Liquid + Coil" — Rp 180.000 — awal bulan
- Pengingat muncul H-3: *"Goal 'Bayar Ressa' jatuh tempo 3 hari lagi. Kurang Rp 460.000."*

### 4.5 Laporan
- Pilih bulan → tampil:
  - Total pemasukan vs pengeluaran (kartu besar)
  - Per akun (bar chart)
  - Per kategori (donut chart) — kategori terbesar di-highlight
  - Rata-rata pengeluaran harian
  - Hari dengan pengeluaran terbesar
- Bisa geser ke bulan sebelumnya (swipe kiri/kanan dengan animasi)

---

## 5. Struktur Data

### 5.1 ERD (logis)
```
Account 1 ───< Transaction
Account 1 ───< Transfer (as from_account)
Account 1 ───< Transfer (as to_account)
Category 1 ───< Transaction
Goal 1 ───< GoalContribution (pengisian goal)
```

### 5.2 Skema Tabel (Isar / sqflite)

**Table: accounts**
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | int (PK, autoincrement) | |
| name | String | "Cash", "Seabank", "Mandiri" |
| type | String | `cash` / `bank` / `ewallet` |
| colorHex | String | warna kartu akun |
| iconCodePoint | int | ikon Flutter |
| initialBalance | int | saldo awal saat akun dibuat |
| isArchived | bool | akun nonaktif tanpa hapus data |
| createdAt | DateTime | |

**Table: categories**
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | int PK | |
| name | String | |
| iconCodePoint | int | |
| colorHex | String | |
| type | String | `expense` / `income` |
| isActive | bool | |

**Table: transactions**
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | int PK | |
| type | String | `income` / `expense` |
| amount | int | selalu positif |
| accountId | int FK | |
| categoryId | int FK (nullable utk income) | |
| note | String | |
| date | DateTime | tanggal transaksi |
| createdAt | DateTime | |

**Table: transfers**
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | int PK | |
| fromAccountId | int FK | |
| toAccountId | int FK | |
| amount | int | |
| note | String | |
| date | DateTime | |

**Table: goals**
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | int PK | |
| name | String | |
| targetAmount | int | |
| collectedAmount | int | |
| deadline | DateTime | |
| repeatMonthly | bool | reset tiap bulan |
| sourceAccountId | int FK | akun pengisian |
| reminderEnabled | bool | |
| status | String | `active` / `done` / `missed` |
| createdAt | DateTime | |

**Table: goal_contributions**
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | int PK | |
| goalId | int FK | |
| amount | int | |
| date | DateTime | |
| note | String | |

### 5.3 Perhitungan Saldo (server-side logic, jalan lokal)
```
saldo_akun = initialBalance
           + Σ income (akun itu)
           − Σ expense (akun itu)
           + Σ transfer masuk
           − Σ transfer keluar

uang_harian     = saldo(Mandiri) + saldo(Cash)
tabungan        = saldo(Seabank)
total_kekayaan  = uang_harian + tabungan
```

---

## 6. Desain UI/UX — Tema Cerah & Animasi

> **Filosofi desain:** "Cerah, hidup, tapi tetap tenang di mata." Aplikasi uang sering bikin stres, jadi UI harus bikin betah membuka & mencatat.

### 6.1 Palet Warna (Light Theme — default)

| Token | Warna | Hex | Pemakaian |
|---|---|---|---|
| Primary | ☀️ Kuning emas cerah | `#FFB800` | Aksi utama, tombol FAB, highlight |
| Primary Dark | Oranye madu | `#F59E0B` | State pressed, gradient partner |
| Secondary | 🌊 Biru laut muda | `#38BDF8` | Info, akun bank, aksen positif |
| Tertiary | 🍀 Hijau mint | `#34D399` | Pemasukan, saldo bertambah, success |
| Danger | 🍓 Merah strawberry | `#F87171` | Pengeluaran, hapus, saldo berkurang |
| Surface | Putih hangat | `#FFFDF7` | Background utama (bukan putih menyilaukan) |
| Surface Card | Putih bersih | `#FFFFFF` | Kartu konten |
| Text Primary | Abu gelap lembut | `#1F2937` | Judul & angka |
| Text Secondary | Abu kebiruan | `#6B7280` | Label, tanggal |
| Divider | Krem tipis | `#F3F4F6` | Pemisah |

**Dark mode (opsional):** surface `#121826`, card `#1E293B`, teks `#F9FAFB` — warna aksen tetap sama supaya tidak murung.

**Aturan warna per konteks:**
- Angka pemasukan & saldo naik → hijau mint
- Angka pengeluaran → merah strawberry (tapi lembut, bukan alarm merah)
- Akun Seabank → hijau (khas SeaBank), Mandiri → kuning/emas (khas Mandiri), Cash → oranye
- Jangan lebih dari 1 warna aksen per layar; kartu akun boleh colorful, sisanya netral

### 6.2 Tipografi
- Font: **Plus Jakarta Sans** (gratis, Google Fonts, modern & ramah Indonesia)
- Angka saldo: bold 28–34sp, tabular figures
- Judul section: semi-bold 18–20sp
- Body/label: regular 13–15sp

### 6.3 Sistem Animasi (wajib halus, 60fps)

**Durasi & easing default:**
- Micro-interaction (tap, toggle): 150–200ms, `easeOut`
- Transisi antar layar: 300ms, `easeInOutCubic`
- Animasi angka/besar (chart masuk): 500–800ms, `easeOutCubic`
- Easing: pakai `Curves.easeOutCubic` & `Curves.easeInOutCubic` — hindari `linear` & `bounce` yang berlebihan

**Animasi per interaksi:**
| Moment | Animasi |
|---|---|
| Tap tombol/FAB | Scale 1.0 → 0.95 → 1.0 (spring ringan) + ripple |
| Transisi layar | Slide horizontal + fade (kiri→kanan sesuai arah back/forward) |
| Tambah transaksi sukses | ✨ Confetti mini (packages: `confetti`) + angka saldo **count-up** dari nilai lama ke nilai baru |
| Saldo berubah | Angka melakukan **count-up/count-down** 600ms, warna flash hijau (naik) / merah (turun) sekali |
| Buka/tutup bottom sheet | Slide dari bawah + backdrop fade |
| Hapus item | Item **swipe-to-dismiss** dengan ikon tempat sampah + shrink height |
| Progress goal | Progress bar **animasi fill** 800ms + angka persen count-up |
| Chart masuk layar | Bar chart tumbuh dari bawah (staggered per batang, 30ms delay tiap batang); donut chart sweep 90° |
| Swipe ganti bulan di laporan | Page slide + crossfade |
| Pull-to-refresh | Indicator warna primary berputar |
| Ganti akun di form | Chips akun dengan animasi scale + warna fill |

**Prinsip:** animasi memberi *feedback* (sadar ada perubahan), bukan hiasan. Semua animasi punya fungsi informatif.

### 6.4 Layout & Komponen

**Bottom Navigation (4 tab + FAB tengah):**
```
[🏠 Home]  [📜 Riwayat]  (＋)  [🎯 Goal]  [📊 Laporan]
```
FAB tengah menonjol, warna primary, ikon `+`, dengan animasi **morph jadi 2 pilihan** saat ditekan: 💸 Pengeluaran / 💰 Pemasukan / ↔️ Transfer (expand radial).

**Home:**
- Header: sapaan + tanggal hari ini + total kekayaan (angka besar, animasi count-up)
- 2 kartu besar: "Uang Harian" (Mandiri+Cash) & "Tabungan" (Seabank), masing-masing bisa di-tap → detail akun
- Baris kartu akun kecil (horizontal scroll): tiap akun warna khas
- Section "Goal mendekati jatuh tempo" (maks 2, progress bar mini)
- Section "Transaksi terakhir" (3 terakhir)

**Form Transaksi:**
- Input jumlah besar di atas (keypad khusus angka, bukan keyboard HP)
- Chips pilihan akun (warna khas akun)
- Grid kategori (ikon + nama)
- Field catatan + tanggal (date picker)
- Tombol "Simpan" sticky di bawah

---

## 7. Struktur Kode Flutter (Front-end Architecture)

### 7.1 Stack Teknologi
| Komponen | Pilihan | Alasan |
|---|---|---|
| Framework | Flutter 3.x (stable) | Satu codebase Android+iOS |
| Bahasa | Dart 3 | Null safety, pattern matching |
| State management | **Riverpod 2.x** | Deklaratif, testable, tidak boilerplate |
| Local DB | **Isar** | Cepat, NoSQL, reactive queries |
| Notifikasi lokal | `flutter_local_notifications` | Pengingat goal |
| Animasi angka | `flutter_animate` / `intl` + `TweenAnimationBuilder` | Count-up saldo |
| Chart | `fl_chart` | Bar & donut, animasi bawaan |
| Confetti | `confetti` | Feedback sukses |
| Date handling | `intl` + `DateFormat` | Format "Senin, 23 Nov 2026" |
| Navigation | `go_router` | URL-based, transisi custom |
| DI / layer | Repository pattern | DB bisa diganti tanpa ubah UI |

### 7.2 Struktur Folder
```
lib/
├── main.dart
├── app.dart                      # MaterialApp, tema, router
├── core/
│   ├── constants/                # warna, ukuran, teks default
│   │   ├── app_colors.dart
│   │   └── app_typography.dart
│   ├── router/                   # go_router config + transisi
│   │   └── app_router.dart
│   ├── theme/                    # light & dark theme
│   │   └── app_theme.dart
│   └── utils/
│       ├── currency_formatter.dart   # Rp 1.550.000
│       └── date_formatter.dart       # "Senin, 23 Nov 2026"
├── data/
│   ├── models/                   # mirror skema Isar
│   │   ├── account.dart
│   │   ├── category.dart
│   │   ├── transaction.dart
│   │   ├── transfer.dart
│   │   └── goal.dart
│   ├── repositories/             # semua query DB di sini
│   │   ├── account_repository.dart
│   │   ├── transaction_repository.dart
│   │   ├── transfer_repository.dart
│   │   └── goal_repository.dart
│   └── database/
│       └── isar_service.dart     # open DB, migration, seed data
├── features/                     # 1 folder = 1 fitur (feature-first)
│   ├── home/
│   │   ├── providers/            # riverpod providers
│   │   │   └── home_providers.dart
│   │   ├── screens/
│   │   │   └── home_screen.dart
│   │   └── widgets/
│   │       ├── total_balance_card.dart
│   │       ├── account_card.dart
│   │       ├── goal_preview_card.dart
│   │       └── recent_transactions_list.dart
│   ├── transaction/
│   │   ├── providers/
│   │   ├── screens/
│   │   │   ├── add_transaction_screen.dart
│   │   │   ├── transfer_screen.dart
│   │   │   └── edit_transaction_screen.dart
│   │   └── widgets/
│   │       ├── amount_input.dart
│   │       ├── account_chips.dart
│   │       └── category_grid.dart
│   ├── history/
│   │   ├── providers/
│   │   ├── screens/
│   │   │   └── history_screen.dart
│   │   └── widgets/
│   │       └── transaction_tile.dart
│   ├── goals/
│   │   ├── providers/
│   │   ├── screens/
│   │   │   ├── goals_screen.dart
│   │   │   └── add_goal_screen.dart
│   │   └── widgets/
│   │       └── goal_progress_card.dart
│   ├── reports/
│   │   ├── providers/
│   │   ├── screens/
│   │   │   └── reports_screen.dart
│   │   └── widgets/
│   │       ├── monthly_bar_chart.dart
│   │       └── category_donut_chart.dart
│   └── accounts/                 # kelola akun & kategori
│       ├── screens/
│       └── widgets/
└── shared/
    ├── widgets/                  # komponen reusable
    │   ├── animated_number.dart  # count-up widget
    │   ├── empty_state.dart
    │   └── bottom_sheet_scaffold.dart
    └── providers/
```

### 7.3 Pola State (Riverpod)
- `StateNotifierProvider` per layar/form (misal `AddTransactionState`: jumlah, akun, kategori, tanggal)
- `StreamProvider` untuk data reaktif dari Isar → saldo & riwayat auto-update saat ada perubahan data
- Provider reuse lintas fitur: `accountsProvider`, `categoriesProvider`, `balanceSummaryProvider`

**Contoh alur:** Simpan transaksi → `TransactionRepository.add()` → Isar notify → `StreamProvider` emit ulang → angka saldo count-up otomatis.

### 7.4 Routing
| Path | Layar |
|---|---|
| `/` | Home |
| `/add` | Form transaksi (via FAB) |
| `/transfer` | Form transfer |
| `/history` | Riwayat |
| `/goals` | Daftar goal |
| `/goals/add` | Tambah goal |
| `/reports` | Laporan |
| `/settings/accounts` | Kelola akun |
| `/settings/categories` | Kelola kategori |

---

## 8. User Flow Utama

### 8.1 Mencatat pengeluaran (harian, 5–10 detik)
Home → tap FAB (+) → pilih 💸 Pengeluaran → ketik jumlah (keypad) → pilih akun (chip) → pilih kategori → (opsional) catatan → Simpan → confetti mini + saldo akun count-down.

### 8.2 Mencatat pemasukan (gaji / tambahan uang)
Home → FAB → 💰 Pemasukan → jumlah → pilih akun → (opsional kategori "Gaji"/"Tambahan") → Simpan → saldo count-up hijau.

### 8.3 Transfer (narik tunai / top up)
Home → FAB → ↔️ Transfer → dari akun A → ke akun B → jumlah → Simpan → dua saldo berubah, total tetap.

### 8.4 Mengecek kondisi uang
Buka Home → lihat "Uang Harian" (Mandiri+Cash) & "Tabungan" (Seabank) → scroll lihat transaksi terakhir → perlu detail, tap kartu akun.

### 8.5 Mengelola goal
Goal tab → tambah goal → isi nama, target, tenggat, akun sumber, pengingat → isi goal dari waktu ke waktu → H-3 muncul notifikasi → tercapai → badge "Tercapai 🎉".

---

## 9. Non-Functional Requirements
- **Performance:** input transaksi < 2 detik dari buka app; scroll riwayat 1000+ item tanpa jank (pakai `ListView.builder`)
- **Reliability:** data lokal, auto-backup ke file JSON di folder dokumen HP tiap hari (bisa di-restore)
- **Privasi:** tanpa akun, tanpa internet permission wajib (notifikasi lokal saja)
- **Aksesibilitas:** kontras teks minimal 4.5:1, ukuran tap target minimal 48dp, support font scale HP
- **Ukuran app:** target < 30 MB

---

## 10. Backlog (v2.0+)
- Ekspor laporan ke PDF/Excel
- Budget per kategori per bulan + warning
- Grafik tren 6 bulan
- PIN/biometric lock
- Backup ke Google Drive
- Widget home screen (saldo kilat)
- Recurring transaction otomatis (misal pulsa tiap tanggal X)

---

## 11. Roadmap Pengerjaan

| Fase | Durasi | Deliverable |
|---|---|---|
| **F1 — Fondasi** | Hari 1–4 | Setup project, tema warna & tipografi, router, Isar + skema + seed 3 akun & kategori default |
| **F2 — Transaksi inti** | Hari 5–10 | CRUD transaksi, form + keypad jumlah, saldo otomatis, Home (kartu saldo + transaksi terakhir) |
| **F3 — Riwayat & edit** | Hari 11–14 | Riwayat per tanggal, filter, swipe-to-delete, edit via bottom sheet |
| **F4 — Transfer & laporan** | Hari 15–19 | Transfer antar akun, laporan bulanan + chart |
| **F5 — Goal & notifikasi** | Hari 20–24 | CRUD goal, pengisian progres, notifikasi lokal H-3 |
| **F6 — Polish animasi** | Hari 25–28 | Semua animasi di tabel §6.3, dark mode, empty states, testing |
| **F7 — Rilis** | Hari 29–30 | Build APK, install di HP sendiri, pakai harian, catat bug nyata |

---

## 12. Risiko & Mitigasi
| Risiko | Mitigasi |
|---|---|
| Isar tiba-tiba tidak maintain | Repository pattern memudahkan ganti ke sqflite/Drift |
| Kehilangan data HP rusak | Auto-backup JSON harian + tombol restore di pengaturan |
| Animasi bikin app berat | Batasi animasi berat hanya di moment penting; profile pakai `flutter run --profile` |
| Scope creep | Patuhi Out of Scope §2.2 — semua ide baru masuk backlog dulu |

---

*Dokumen ini siap dijadikan acuan coding. Selanjutnya: setup project Flutter + implementasi Fase 1.*
