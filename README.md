# Mutasi Stok Antar Gudang

Aplikasi Android untuk pencatatan perpindahan profil dan aksesori UPVC antar gudang, dengan backend REST API JavaScript.

## Status

Express menyediakan koneksi MySQL, migration, seed UPVC, serta API baca gudang dan saldo. Flutter menampilkan status koneksi dan stok per gudang dengan pagination, loading, error, dan retry. CRUD master, input stok awal melalui UI, mutasi, dan kartu stok belum diimplementasikan.

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

Aktifkan MySQL 8.0.16 atau lebih baru (CHECK constraint harus ditegakkan) dan sediakan database aplikasi dengan charset `utf8mb4`. Environment lokal telah diuji pada MySQL 8.0.30 dengan database `practicaltest`. Akun root tanpa password hanya untuk development lokal; gunakan akun aplikasi dengan hak terbatas sebelum pemakaian di lingkungan lain. Kredensial aktual hanya disimpan di `.env`.

Isi `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, dan `DB_NAME` di `E:\Project\practicaltestv2\backend\.env` sesuai database lokal. Nilai dalam `.env.example` adalah contoh, bukan akun yang otomatis dibuat. Kredensial tidak dimasukkan ke Flutter atau Git.

```powershell
Set-Location 'E:\Project\practicaltestv2\backend'
npm run db:check
npm run db:migrate
npm run db:seed
```

`GET /api/v1/health` mengembalikan HTTP 200 dengan `{"data":{"status":"ok","database":"connected"}}` setelah query berhasil. Saat koneksi gagal, respons HTTP 503 memakai kode `DATABASE_UNAVAILABLE` dan request ID tanpa membocorkan kredensial atau SQL. Connection pool maksimal 5 koneksi, connect/query timeout 3 detik, dan koneksi health selalu dilepas. Health membuktikan konektivitas, bukan kelengkapan schema atau invariant stok.

Migration membuat tujuh tabel bisnis InnoDB: `items`, `warehouses`, `warehouse_stocks`, `stock_transfers`, `stock_transfer_items`, `opening_stocks`, dan `stock_movements`. Dua tabel teknis mencatat versi migration dan seed. SQL tersedia di `E:\Project\practicaltestv2\backend\migrations`. Foreign key menggunakan RESTRICT; saldo, sumber pergerakan, persamaan saldo, dan pasangan unik dilindungi constraint. Kewajiban tepat dua pergerakan mutasi serta konsistensi snapshot lintas dokumen tetap perlu dijaga service transaksi pada tahap berikutnya.

Migration memakai checksum dan database advisory lock. Menjalankan ulang migration yang sudah diterapkan tidak mengubah schema. DDL MySQL bukan transaksi lintas statement: jika gagal, status `running` dipertahankan dan eksekusi berikutnya ditolak sampai kondisi schema diperiksa. Jangan mengubah migration yang sudah diterapkan; tambahkan versi baru. Parser migration saat ini hanya mendukung statement SQL sederhana, bukan stored procedure.

Seed `upvc-v1` hanya menerima database aplikasi kosong. Seluruh master, dokumen stok awal, saldo, pergerakan, dan penanda seed ditulis dalam satu transaksi. Seed ulang yang sudah berhasil tidak mengubah data. Seed menolak database berisi data yang belum memiliki penanda tersebut. Jalankan setup/seed sebelum server digunakan; tidak tersedia reset destruktif otomatis.

Data demo: Utama berisi profil 25 batang, engsel 40 pcs, handle 12 pcs; Cabang berisi profil 3 batang dan engsel 5 pcs. Gudang Baru belum memiliki saldo; API tetap menampilkan barang aktif dengan quantity nol. Ada lima dokumen AWL dan lima pergerakan OPENING, tanpa mutasi historis. Profil adalah batang utuh 6 meter, bukan satuan meter.

API baca awal:
- `GET /api/v1/warehouses?page=1&limit=20`: gudang diurutkan berdasarkan ID.
- `GET /api/v1/stocks?warehouse_id=1&page=1&limit=20&search=UPVC`: saldo barang per gudang.
- Respons daftar memakai `data` dan `meta` (`page`, `limit`, `total`), limit maksimal 100. Filter aktif gudang, CRUD, serta dokumen/kartu stok menyusul.

Pengujian MySQL nyata: `npm run test:database`. Perintah ini membutuhkan izin membuat database sementara bernama `inventory_test_*`, kemudian menghapus hanya database yang dibuat proses pengujian. Database aplikasi tidak direset. Cakupan: migration/seed ulang, constraint dasar, rollback stok awal, rekonsiliasi, health, pagination, stok nol, dan validasi query. Pengujian konkurensi mutasi belum termasuk.

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
- `flutter test`: 12 test lulus, termasuk respons API, timeout, error, retry, stok UPVC, dan layar kecil dengan pembesaran teks.
- Build APK debug: berhasil. Gradle menampilkan peringatan native access dari JDK, tidak menggagalkan build.
- MySQL nyata: migration, seed, serta pengujian database terisolasi lulus.
- APK dipasang dan dijalankan di emulator Android. Health menunjukkan backend dan MySQL terhubung. Layar stok menampilkan data nyata Utama: 25 batang profil, 40 pcs engsel, dan 12 pcs handle.
- CRUD master, mutasi, kartu stok, dan pengujian konkurensi belum tersedia.