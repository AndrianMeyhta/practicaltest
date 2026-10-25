# Mutasi Stok Antar Gudang

Aplikasi Android untuk pencatatan perpindahan profil dan aksesori UPVC antar gudang, dengan backend REST API JavaScript.

## Status

Express menyediakan koneksi MySQL, migration, seed UPVC, CRUD master, stok awal, transfer multi-item, balancing, preview, riwayat, dashboard, dan kartu stok. Flutter menyediakan navigasi sidebar Dashboard/Mutasi/Master/Pengaturan dan layar fitur tersebut. Implementasi transaksi sudah diuji melalui HTTP dan MySQL terisolasi; verifikasi tulis penuh melalui emulator dan penyempurnaan tampilan masih diperlukan.

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
- Respons daftar memakai `data` dan `meta` (`page`, `limit`, `total`), limit maksimal 100. Filter aktif dan CRUD master tersedia; dokumen/kartu stok menyusul.

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
- Pengujian backend: 8 test lulus. Kasus health sukses dan gagal menggunakan dependency database uji, bukan bukti koneksi sukses ke MySQL nyata.
- `flutter analyze`: tidak ada masalah.
- `flutter test`: 16 test lulus, termasuk validasi/loading form master, error field dengan isian tetap tersimpan, retry daftar, create/edit/delete gudang melalui mock HTTP, timeout tulis, stok UPVC, dan layar kecil dengan pembesaran teks.
- Build APK debug: berhasil. Gradle menampilkan peringatan native access dari JDK, tidak menggagalkan build.
- MySQL nyata: migration, seed, serta pengujian database terisolasi lulus.
- APK dipasang dan dijalankan di emulator Android. Health menunjukkan backend dan MySQL terhubung. Layar stok menampilkan data nyata Utama: 25 batang profil, 40 pcs engsel, dan 12 pcs handle.
- Verifikasi tahap master: APK debug dipasang pada emulator `emulator-5554`; status menunjukkan backend/MySQL terhubung, daftar barang menampilkan tiga SKU nyata, dan daftar gudang menampilkan Utama, Cabang, serta Baru. Alur tulis CRUD pada emulator belum diverifikasi penuh; pengujian HTTP memakai MySQL terisolasi dan pengujian widget memakai mock HTTP.
- Hasil tahap transaksi dijelaskan pada bagian berikut; hasil tahap master di atas merupakan catatan verifikasi sebelumnya.

## Transaksi stok dan navigasi (SRS 1.3)

Penyempurnaan form transfer: gudang asal/tujuan saling dikecualikan pada dropdown, barang yang sudah dipilih tidak ditawarkan pada baris lain, dan saldo gudang asal dimuat melalui API dengan pagination. Badge saldo positif hijau, saldo nol putih; loading/gagal bukan saldo nol. Baris bawah kartu memuat saldo, input jumlah, serta ikon hapus ketika terdapat minimal dua barang. Layar sempit/teks besar menggunakan susunan adaptif. Field kode/satuan immutable pada edit master berlatar abu-abu dengan ikon kunci. Verifikasi pembaruan ini: analisis Flutter bersih, 18 test lulus, APK debug dibangun dan dipasang pada emulator; pemeriksaan visual manual penuh belum dilakukan.

- Sidebar kiri bernama `mutasi stock`, dibuka melalui tombol menu atau swipe dari tepi kiri. Cek koneksi dipindahkan ke Pengaturan.
- `POST /api/v1/opening-stocks`: `warehouse_id`, `item_id`, `quantity`, `notes` opsional.
- `POST /api/v1/transfers`: `source_warehouse_id`, `destination_warehouse_id`, `items` berisi 1–50 objek `item_id`/`quantity`, dan `notes` opsional.
- `POST /api/v1/adjustments`: `warehouse_id`, `item_id`, `quantity`, `direction` (`IN`/`OUT`), serta `notes` wajib. Balancing adalah selisih tambah/kurang, bukan saldo akhir.
- Masing-masing resource memiliki `POST /preview` tanpa penulisan saldo dan `GET /:id` untuk bukti. POST simpan wajib header UUID `Idempotency-Key`; sukses pertama 201, replay identik 200, payload berbeda dengan key sama 409 `IDEMPOTENCY_CONFLICT`.
- `GET /api/v1/history?page=1&limit=20&kind=transfers` menyediakan riwayat gabungan; filter kind opsional.
- `GET /api/v1/stock-card?warehouse_id=1&item_id=1&page=1` menampilkan pergerakan terbaru dahulu dan saldo terkini terpisah dari pagination.
- `GET /api/v1/dashboard` menyediakan jumlah master aktif dan saldo dikelompokkan menurut satuan.

Migration `003_adjustments.sql` menambahkan dokumen penyesuaian dan sumber pergerakan dengan FK RESTRICT. Jalankan `npm run db:migrate` sebelum server versi baru. Tidak diperlukan seed ulang. Migration telah diuji pada database terisolasi dan diterapkan ke database lokal tanpa reset.

Penulis stok mengambil lock gudang berurutan, barang berurutan, lalu pasangan saldo. Seluruh header, detail, saldo, dan pergerakan commit bersama. Preview bukan reservasi. Error bisnis tambahan: `MASTER_INACTIVE`, `OPENING_NOT_ALLOWED`, `INSUFFICIENT_STOCK`, `STOCK_OVERFLOW`, dan `IDEMPOTENCY_CONFLICT` (409); header key salah `INVALID_IDEMPOTENCY_KEY` (400).

Frontend mempertahankan key/payload selama hasil request belum diketahui, mengunci perubahan form, dan menyediakan retry transaksi identik. Key belum dipersistenkan setelah aplikasi ditutup paksa. Preview saat ini dipicu tombol dan dibatalkan setiap perubahan input; preview otomatis dengan debounce belum tersedia.

Verifikasi tahap transaksi:
- `npm run check` dan 9 test Node lulus.
- MySQL terisolasi: preview multi-item, transfer, balancing masuk/keluar, stok awal, replay identik, konflik key, stok kurang, fault injection rollback, request key sama bersamaan, dua pengurangan bersaing, rekonsiliasi saldo, pagination histori/kartu stok lulus.
- `flutter analyze` tanpa masalah; 17 test Flutter lulus, termasuk drawer/Pengaturan dan invalidasi preview balancing.
- APK debug berhasil dibangun dan dipasang. Dashboard emulator menampilkan data MySQL nyata serta dokumen stok awal.
- Belum diverifikasi: seluruh alur tulis emulator, kesamaan visual penuh, seluruh ukuran layar baru, transfer berlawanan arah bersamaan, seluruh kombinasi konflik master/transfer/balancing, serta retry UI setelah timeout pada transaksi baru.
- Filter histori saat ini baru jenis transaksi; filter tanggal/gudang/pencarian dokumen dan pemilih master dengan pencarian masih perlu dilengkapi. Pemilih form memuat seluruh halaman master aktif.

## Kontrak master

Kedua resource `/api/v1/items` dan `/api/v1/warehouses` menyediakan GET daftar, POST, PATCH `/:id`, dan DELETE `/:id`. Sukses menggunakan `data`, daftar menyertakan `meta`, dan DELETE mengembalikan 204 tanpa body.

- POST: `code`, `name`, `is_active` opsional (boolean, default `true`); barang juga wajib `unit`.
- PATCH: hanya `name` dan/atau `is_active`. PATCH kosong, field tak dikenal, atau penyertaan kode/satuan immutable ditolak 422.
- Kode di-trim dan uppercase, 1–30 karakter ASCII huruf/angka/underscore/tanda hubung. Nama 1–100 dan satuan 1–20 karakter Unicode setelah trim.
- Query: `page` default 1 (maksimal 1.000.000), `limit` default 20 (maksimal 100), `active=true` atau `active=false`. Tanpa `active` menampilkan semua status. Barang mendukung `search` kode/nama maksimal 100 karakter setelah trim; pencarian kosong berarti tanpa filter dan wildcard diperlakukan literal. Parameter tidak dikenal/berulang ditolak.
- `is_active` respons master berupa boolean. Stok tetap dapat membaca gudang nonaktif; histori tidak dihapus.

Error selalu memiliki `code`, `message`, `details`, dan `request_id`. Detail field berbentuk `{"field":"name","message":"..."}`.

| HTTP | Kode |
|---|---|
| 400 | `INVALID_QUERY`, `INVALID_ID`, `INVALID_JSON` |
| 404 | `NOT_FOUND` |
| 409 | `DUPLICATE_CODE`, `MASTER_HAS_STOCK`, `MASTER_IN_USE` |
| 413 | `PAYLOAD_TOO_LARGE` |
| 422 | `VALIDATION_ERROR` |
| 500 | `INTERNAL_ERROR` |
| 503 | `DATABASE_UNAVAILABLE`, `TRANSACTION_RETRY_REQUIRED` |

Transaksi mengunci master target sebelum memeriksa saldo/referensi dengan locking read. Jalur barang tidak mengambil lock gudang setelah barang; helper stok awal tetap mengunci gudang → barang → saldo. Hapus memeriksa histori terlebih dahulu, kemudian saldo, membersihkan saldo nol dan menghapus master secara atomik. FK RESTRICT dan unique constraint tetap menjadi perlindungan akhir. Tidak ada migration lama yang diubah atau cascade histori. Koneksi selalu dilepas dan kegagalan di-rollback.

`npm run test:database` juga memeriksa CRUD, kode duplikat, filter, penolakan histori, saldo nol, fault injection melalui trigger database uji, create bersamaan, serta konflik hapus/nonaktif ketika helper stok awal memegang lock. Urutan master selesai dahulu diperiksa secara serial. Ini bukan bukti seluruh kemungkinan interleaving atau pengujian service mutasi.

Flutter tidak mengirim ulang operasi tulis secara otomatis. Timeout atau gangguan respons tulis dianggap hasil belum diketahui; pengguna harus memeriksa daftar terbaru sebelum mengirim ulang. Master belum memiliki idempotency key atau deteksi stale edit berbasis versi. Dua edit nama bersamaan mengikuti update terakhir yang berhasil.