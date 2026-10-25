# Mutasi Stok Antar Gudang

Aplikasi Android untuk pencatatan perpindahan profil dan aksesori UPVC antar gudang, dengan backend REST API JavaScript.

## Status

Fondasi Express dan Flutter Android sudah tersedia. Flutter menampilkan halaman awal; fitur master, stok awal, mutasi, kartu stok, dan koneksi database belum diimplementasikan. Belum ada integrasi Flutter ke API.

## Environment terverifikasi

- Node.js 24.3.0 dan npm 11.19.0.
- Express 5.3.0; dependency dikunci melalui `package-lock.json`.
- Flutter 3.47.8 stable dan Dart 3.13.7.
- Android SDK build-tools 36.0.0 dan JDK bawaan Android Studio 25.0.3.
- Target saat ini Android; belum ada konfigurasi aplikasi web atau desktop.

## Backend

Setup pertama melalui PowerShell:

```powershell
Set-Location 'E:\Project\practicaltestv2\backend'
npm ci
Copy-Item .env.example .env
npm start
```

Untuk menjalankan ulang, cukup `npm start`. Gunakan `npm run dev` untuk restart otomatis saat source berubah. File `.env` bersifat lokal dan tidak dikomit; jangan menimpa konfigurasi lokal saat setup ulang.

Default server adalah `127.0.0.1:3000`. `HOST` dan `PORT` dapat diatur melalui environment. Akses dibatasi lokal; jangan membuka server tanpa autentikasi ke internet.

Pemeriksaan proses:

```powershell
Invoke-RestMethod http://127.0.0.1:3000/api/v1/live
```

Respons: `{"data":{"status":"ok"}}`. Endpoint ini hanya memeriksa proses HTTP, bukan kesiapan database. Endpoint `/api/v1/health` akan ditambahkan bersama koneksi MySQL.

Pengujian:

```powershell
Set-Location 'E:\Project\practicaltestv2\backend'
npm run check
npm test
```

Pengujian menggunakan test runner Node.js dan HTTP server pada port sementara: konfigurasi port, liveness, respons 404, request ID, JSON tidak valid, serta payload terlalu besar (HTTP 413).

## Flutter Android

```powershell
Set-Location 'E:\Project\practicaltestv2\frontend'
flutter pub get
flutter devices
```

Nyalakan emulator Android atau sambungkan perangkat dengan USB debugging, lalu jalankan `flutter run -d ID_PERANGKAT` dengan ID Android dari `flutter devices`.

```powershell
Set-Location 'E:\Project\practicaltestv2\frontend'
flutter analyze
flutter test
flutter build apk --debug
```

APK debug: `E:\Project\practicaltestv2\frontend\build\app\outputs\flutter-apk\app-debug.apk`. APK dan keluaran build tidak dikomit. Build debug bukan artefak rilis produksi.

Saat integrasi API diterapkan, emulator Android standar mengakses host melalui `10.0.2.2`, bukan `localhost`. Konfigurasi URL API dan HTTP development belum ditambahkan pada tahap ini.

## Hasil verifikasi scaffolding

- Pemeriksaan sintaks backend: lulus.
- Pengujian backend: 2 test lulus.
- `flutter analyze`: tidak ada masalah.
- `flutter test`: 2 test lulus, termasuk layar kecil dengan pembesaran teks.
- Build APK debug: berhasil. Gradle menampilkan peringatan native access dari JDK, tidak menggagalkan build.
- Aplikasi belum dijalankan pada emulator/perangkat Android; belum ada perangkat Android tersambung saat pemeriksaan.
- MySQL, migration, seed, reset database, dan pengujian transaksi belum tersedia.