# Mutasi Stok Antar Gudang

Aplikasi Android untuk pencatatan perpindahan profil dan aksesori UPVC antar gudang, dengan backend REST API JavaScript.

## Status

Express menyediakan connection pool MySQL dan endpoint health. Flutter memeriksa backend/database melalui HTTP, dengan loading, timeout, error, dan retry. Fitur master, stok awal, mutasi, serta kartu stok belum diimplementasikan.

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
# Isi konfigurasi database lokal pada .env sebelum menjalankan server.
npm start
```

Untuk menjalankan ulang, cukup `npm start`. Gunakan `npm run dev` untuk restart otomatis saat source berubah. File `.env` bersifat lokal dan tidak dikomit; jangan menimpa konfigurasi lokal saat setup ulang.

Default server adalah `127.0.0.1:3000`. `HOST` dan `PORT` dapat diatur melalui environment. Akses dibatasi lokal; jangan membuka server tanpa autentikasi ke internet.

Pemeriksaan proses:

```powershell
Invoke-RestMethod http://127.0.0.1:3000/api/v1/live
```

Respons: `{"data":{"status":"ok"}}`. Endpoint ini hanya memeriksa proses HTTP, bukan kesiapan database.

### MySQL

Aktifkan MySQL 8 dan sediakan database aplikasi dengan charset `utf8mb4`. Gunakan akun aplikasi tersendiri, bukan akun administrator. Tahap health hanya menjalankan `SELECT 1`; migration dan pemberian hak akses operasi stok belum termasuk tahap ini.

Isi `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, dan `DB_NAME` di `E:\Project\practicaltestv2\backend\.env` sesuai database lokal. Nilai dalam `.env.example` adalah contoh, bukan akun yang otomatis dibuat. Kredensial tidak dimasukkan ke Flutter atau Git.

```powershell
Set-Location 'E:\Project\practicaltestv2\backend'
npm run db:check
```

`GET /api/v1/health` mengembalikan HTTP 200 dengan `{"data":{"status":"ok","database":"connected"}}` setelah query berhasil. Saat koneksi gagal, respons HTTP 503 memakai kode `DATABASE_UNAVAILABLE` dan request ID tanpa membocorkan kredensial atau SQL. Connection pool maksimal 5 koneksi, connect/query timeout 3 detik, dan koneksi health selalu dilepas. Health membuktikan konektivitas, bukan kelengkapan schema atau invariant stok.

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

URL default API untuk emulator Android standar adalah `http://10.0.2.2:3000/api/v1`. Backend harus dijalankan terlebih dahulu. URL dapat diganti saat run/build:

```powershell
Set-Location 'E:\Project\practicaltestv2\frontend'
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

ID emulator disesuaikan dengan hasil `flutter devices`. Untuk perangkat USB, gunakan `adb reverse tcp:3000 tcp:3000` lalu URL `http://127.0.0.1:3000/api/v1`. Jalur USB belum diuji. HTTP tanpa enkripsi hanya diizinkan pada build debug; gunakan HTTPS untuk konfigurasi release. Client memiliki timeout 8 detik dan tidak melakukan retry otomatis. Tombol retry dinonaktifkan selama request berlangsung.

## Hasil verifikasi konektivitas

- Pemeriksaan sintaks backend: lulus.
- Pengujian backend: 5 test lulus. Kasus health sukses dan gagal menggunakan dependency database uji, bukan bukti koneksi sukses ke MySQL nyata.
- `flutter analyze`: tidak ada masalah.
- `flutter test`: 10 test lulus, termasuk respons API, timeout, error, retry, dan layar kecil dengan pembesaran teks.
- Build APK debug: berhasil. Gradle menampilkan peringatan native access dari JDK, tidak menggagalkan build.
- APK dipasang dan dijalankan di emulator Android. Request ke backend melalui `10.0.2.2` berhasil; tampilan menunjukkan backend terhubung tetapi database belum tersedia.
- Pemeriksaan MySQL nyata terakhir menghasilkan `ER_ACCESS_DENIED_ERROR` untuk akun contoh. Koneksi sukses masih menunggu konfigurasi akun/database lokal yang valid; tidak ada database atau akun yang dibuat otomatis.
- Migration, seed, reset database, dan pengujian transaksi belum tersedia.