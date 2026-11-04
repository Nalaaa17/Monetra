# Monetra 🪙

<p align="center">
  <img src="assets/images/logo.png" alt="Monetra Logo" width="140" height="140" />
</p>

<p align="center">
  <b>Aplikasi Pencatatan Keuangan Pribadi (Multi-Wallet & Offline-First)</b><br />
  <i>Sederhana, Cepat (< 10 detik), dan Menggantikan Catatan Keuangan Manual di Notes HP 100%.</i>
</p>

---

## 🚀 Fitur Utama

- **⚡ Fast Numeric Keypad**: Form pencatatan transaksi super instan tanpa keyboard bawaan HP yang ribet, lengkap dengan pintasan `000`.
- **💼 Multi-Wallet System**: Pemisahan jelas antara **Uang Harian** (Mandiri & Cash) dan **Tabungan** (Seabank).
- **🔄 Transfer Antar Akun**: Rotasi uang harian (misal tarik tunai Mandiri $\leftrightarrow$ Cash atau menyisihkan ke Seabank) tanpa mengubah total kekayaan.
- **📝 Riwayat Harian ala Notes HP**: Transaksi otomatis dikelompokkan per tanggal dengan rekap total pemasukan & pengeluaran hari tersebut.
- **🎯 Goal & Tabungan Bergaransi**:
  - Target tabungan/tagihan rutin (misal *"Bayar Ressa tiap tgl 23"*, *"Liquid + Coil"*).
  - Progres animasi terisi otomatis saat cicilan ditambahkan.
  - Pengingat notifikasi lokal **H-3** sebelum jatuh tempo (`flutter_local_notifications`).
  - Preview target mendesak langsung di Home Screen.
- **📊 Laporan & Evaluasi Bulanan**:
  - Total Masuk vs Total Keluar.
  - Donut Chart pos pengeluaran (`fl_chart`) untuk evaluasi pos paling boros.
  - Bar Chart alokasi pengeluaran per dompet.
  - Navigasi geser bulan sebelumnya/berikutnya.
- **🔒 100% Offline & Keamanan Data**:
  - Data tersimpan lokal di HP menggunakan SQLite (`sqflite`).
  - Ekspor & Impor file cadangan JSON lokal serta opsi salin ke Clipboard.
- **🎨 Visual Polish & Dark Mode**:
  - Animasi angka saldo *count-up* halus.
  - Efek mini *confetti* saat mencatat transaksi.
  - Dukungan tema Gelap (Dark Mode) dan Terang (Light Mode).
  - Kelola akun & kategori kustom.

---

## 🛠️ Tech Stack & Arsitektur

- **Framework**: Flutter 3.47+ (Dart 3.13+)
- **Arsitektur**: Feature-First (Domain, Data, Presentation)
- **State Management**: [flutter_riverpod 2.x](https://pub.dev/packages/flutter_riverpod)
- **Routing**: [go_router](https://pub.dev/packages/go_router)
- **Local Database**: [sqflite](https://pub.dev/packages/sqflite) + [sqflite_common_ffi](https://pub.dev/packages/sqflite_common_ffi)
- **Charts**: [fl_chart](https://pub.dev/packages/fl_chart)
- **Notifications**: [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
- **Effects**: [confetti](https://pub.dev/packages/confetti)

---

## 🏃 Menjalankan Aplikasi

### 1. Prasyarat
- Flutter SDK 3.x terpasang
- Android Studio / VS Code / Flutter CLI

### 2. Instalasi Dependensi
```bash
flutter pub get
```

### 3. Menjalankan Unit & Widget Test
```bash
flutter test
```

### 4. Menjalankan Aplikasi
```bash
flutter run
```

---

## 📄 Lisensi
Hak Cipta © 2026 Monetra. Dibuat untuk pemakaian personal & produktivitas finansial harian.
