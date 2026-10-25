# Software Requirements Specification (SRS)
# Aplikasi Mutasi Stok Antar Gudang Perusahaan UPVC

| Atribut | Keterangan |
|---|---|
| Versi | 1.3 |
| Status | Baseline kebutuhan sebelum implementasi |
| Studi kasus | Nomor 2 — Mutasi Stok Antar Gudang |
| Platform utama | Flutter untuk Android |
| Backend | Node.js dan Express.js, menggunakan JavaScript |
| Database | MySQL dengan InnoDB |
| Komunikasi | REST API dan JSON |
| Version control | Git; penyerahan source code melalui GitHub |
| Workspace | `E:\Project\practicaltestv2` |
| Konteks bisnis | Persediaan profil dan aksesori pintu/jendela UPVC |


## 1. Tujuan dan dasar kebutuhan

### Revisi 1.3 — navigasi, dashboard, dan balancing

Ketentuan revisi ini mengungguli pembatasan versi sebelumnya mengenai penyesuaian stok dan dashboard. Persetujuan lingkup tidak berarti fitur telah diimplementasikan atau diuji.

- Nama aplikasi pada sidebar: **mutasi stock**. Sidebar kiri dapat dibuka dengan swipe dari tepi kiri ke kanan dan tombol menu; tersedia Dashboard, Mutasi, Master, dan Pengaturan.
- Dashboard menampilkan ringkasan persediaan dan aktivitas terbaru. Jumlah batang dan pcs tidak dijumlahkan menjadi satu total quantity.
- Mutasi menyediakan stok awal, transfer multi-item, balancing, riwayat terpaginasi, serta detail dokumen. Aktivitas dashboard dan riwayat mengacu pada dokumen yang sama.
- Master menyediakan CRUD barang dan gudang. Pengaturan menempatkan pemeriksaan backend dan database melalui API; Flutter tidak menyimpan kredensial atau membuka koneksi MySQL langsung.
- Balancing adalah penyesuaian satu barang pada satu gudang aktif: tambah atau kurang sejumlah integer 1–1.000.000, bukan penggantian saldo akhir. Keterangan wajib 1–500 karakter setelah trim.
- Balancing tambah dicatat sebagai `ADJUSTMENT_IN`, balancing kurang sebagai `ADJUSTMENT_OUT`. Penyesuaian masuk bukan stok awal. Reject yang dikeluarkan dari persediaan merupakan penyesuaian keluar; perpindahan ke gudang reject tetap transfer jika barang masih menjadi persediaan.
- Preview menampilkan saldo sebelum, perubahan, dan setelah. Pengurangan tidak boleh menghasilkan saldo negatif; penambahan tidak boleh melampaui kapasitas integer saldo. Preview bukan reservasi; backend memeriksa ulang saat commit.
- Dokumen balancing, saldo, dan pergerakan disimpan atomik. Gunakan idempotency key dan fingerprint payload; retry identik mengembalikan dokumen sama, payload berbeda ditolak. Dokumen sukses tidak dapat diubah/dihapus; koreksi melalui dokumen baru dengan alasan.
- Master dengan referensi balancing tidak dapat dihapus permanen. Histori tetap terbaca saat master nonaktif. Balancing yang sudah mencatat pergerakan menutup kemungkinan stok awal pada pasangan yang sama.
- Lock penulis stok konsisten: gudang berdasarkan ID naik, barang berdasarkan ID naik, lalu saldo pasangan berdasarkan gudang/barang. Seluruh perubahan multi-item berhasil bersama atau rollback bersama.
- Dashboard, riwayat gabungan, detail transaksi, dan kartu stok mencakup stok awal, transfer, serta balancing. Kartu stok memakai urutan pergerakan yang stabil dan saldo tersimpan, bukan penjumlahan halaman aktif.
- Verifikasi tambahan: balancing tambah/kurang, alasan kosong, stok negatif, overflow, retry identik/berbeda, rollback, proteksi histori, dan konkurensi dengan transfer serta perubahan master pada database terisolasi. Uji drawer, form, preview basi, hasil tulis belum diketahui, layar kecil/teks besar, build APK, dan alur tulis emulator.

Fitur balancing tidak menambahkan pembelian, penerimaan supplier, pemotongan profil, produksi, atau konversi satuan. Aplikasi tetap demo lokal tanpa autentikasi; penyesuaian belum memiliki alur persetujuan pengguna.

Dokumen ini menjadi acuan implementasi, pengujian, demonstrasi, dan penentuan batas lingkup aplikasi. Dokumen ini bukan pernyataan bahwa fitur sudah diimplementasikan atau diuji.

Aplikasi membantu operator perusahaan UPVC memindahkan profil dan aksesori pintu/jendela dari satu gudang ke gudang lain, melihat perkiraan dampaknya terhadap stok, dan menelusuri bukti transaksi yang sudah berhasil. Aplikasi mencatat perpindahan barang yang sama, bukan pemotongan profil atau perakitan produk.

### 1.1 Sumber

1. `C:\Users\MSI\Downloads\deskripsi pekerjaan.pdf`.
2. `C:\Users\MSI\Downloads\Practical_Test_Fullstack_Developer.pdf`.
3. Baseline kebutuhan mutasi stok dan konteks persediaan perusahaan UPVC. Detail katalog dan gudang merupakan asumsi demo, bukan data operasional perusahaan yang telah diverifikasi.

### 1.2 Ketentuan eksplisit tes

- Memilih satu studi kasus; pilihan proyek ini adalah nomor 2.
- Menyediakan master barang, master gudang, stok per gudang, transaksi mutasi, dan riwayat mutasi.
- Menggunakan teknologi Flutter (diutamakan), JavaScript, MySQL, dan Git.
- Komunikasi frontend–backend melalui REST API.
- Menerapkan validasi form, validasi backend, serta relasi database yang sesuai.
- Menyertakan README, struktur database, dan petunjuk menjalankan aplikasi.
- Menyediakan tautan repository GitHub untuk penyerahan source code.
- Dokumentasi API merupakan nilai tambah.

Penilaian menekankan ketepatan alur bisnis dan relasi database, fundamental JavaScript dan Flutter, komunikasi REST API, validasi dan penanganan error, konsistensi stok, struktur kode, dan penggunaan Git.

### 1.3 Tambahan yang telah disetujui

1. **Mutasi multi-item:** satu dokumen memindahkan beberapa jenis barang dengan gudang asal dan tujuan yang sama.
2. **Pratinjau dampak stok:** pengguna melihat stok asal dan tujuan sebelum serta setelah rencana mutasi.
3. **Bukti transaksi:** detail mutasi bernomor unik yang dapat dibuka kembali melalui riwayat.

Ketiga tambahan ini adalah keputusan lingkup produk, bukan fitur tambahan yang diwajibkan recruiter. Ketentuan teknis dan batas input di bawah merupakan baseline implementasi yang dapat direvisi secara terdokumentasi bila ditemukan kendala.

Revisi 1.1 menambahkan keputusan yang disetujui: CRUD master dengan hapus bersyarat, pencatatan stok awal melalui UI, dan kartu stok per barang–gudang. Stok awal merupakan inisialisasi saldo, bukan penerimaan supplier. Mutasi masuk dan keluar merupakan dua sisi satu dokumen perpindahan, bukan dua transaksi independen.

Revisi 1.2 mempertahankan seluruh lingkup versi 1.1 dan menyesuaikan istilah bisnis, satuan contoh, data demo, serta skenario pengujian untuk perusahaan UPVC. Tidak ada modul produksi baru atau perubahan rumus stok. Pengerjaan dibagi menjadi tiga tahap: SRS dan perancangan, backend, lalu frontend Flutter.

## 2. Lingkup dan prioritas

| Prioritas | Cakupan |
|---|---|
| P0 — wajib rilis | CRUD master dengan hapus bersyarat, stok awal melalui UI, stok per gudang, kartu stok, mutasi multi-item, pratinjau, bukti transaksi, riwayat, validasi, konsistensi database, perlindungan request tulis stok ganda, seed, pengujian inti, README, struktur database, Git |
| P1 — setelah P0 stabil | Pencarian dan filter riwayat, dokumentasi API lengkap, alasan mutasi terstruktur, penyempurnaan UX |
| P2 — opsional | Ringkasan operasional, screenshot tambahan, video demo singkat |

Catatan transaksi sederhana termasuk P0. Alasan berupa pilihan kategori terstruktur termasuk P1; kategori tersebut hanya metadata dan tidak mengubah perhitungan stok.

### 2.1 Di luar lingkup

- Pembelian, penerimaan supplier, produksi, transformasi barang, atau proses rework.
- Khusus UPVC: pemotongan profil, pencatatan sisa potongan, bill of materials, perakitan kusen/pintu/jendela, ukuran pesanan proyek, serta konversi batang ke meter tidak termasuk lingkup.
- Approval, pengiriman terpisah dari penerimaan, stok dalam perjalanan, penerimaan parsial.
- Edit, hapus, pembatalan, atau pembalikan mutasi yang sudah berhasil.
- Penyesuaian saldo yang sudah berjalan, stock opname, pemusnahan, dan perhitungan nilai persediaan. Pencatatan stok awal yang memenuhi FR-12 termasuk lingkup, bukan penyesuaian bebas.
- Batch, serial number, tanggal kedaluwarsa, barcode scanner, dan konversi satuan.
- Multi-role, autentikasi produksi, notifikasi realtime, dan sinkronisasi offline.
- Ekspor PDF, tanda tangan, pencetakan, serta dashboard analitik kompleks.
- Frontend kedua menggunakan React/Vue dan deployment publik tanpa pengamanan tambahan.

### 2.2 Strategi implementasi

Urutan pengerjaan: validasi environment → database dan seed → API serta pengujian stok → Flutter end-to-end → pengujian integrasi/build → dokumentasi dan penyerahan. P1/P2 tidak boleh mengorbankan kelengkapan P0 atau verifikasi akhir.

## 3. Aktor, asumsi, dan istilah

### 3.1 Aktor

- **Operator demo:** mengelola master, melihat stok, membuat mutasi, dan menelusuri riwayat.
- **Reviewer/recruiter:** menjalankan aplikasi dari petunjuk dan memverifikasi skenario tes.

Tidak ada login pada baseline. Aplikasi ditujukan untuk demo lokal/lingkungan tepercaya. Riwayat menunjukkan transaksi, bukan bukti identitas pengguna. Tanpa autentikasi, aplikasi tidak boleh diklaim siap produksi atau dibuka ke internet.

### 3.2 Asumsi bisnis

- Kuantitas adalah bilangan bulat; setiap barang memiliki satu satuan dasar. Profil UPVC utuh memakai `batang`, sedangkan aksesori individual seperti engsel dan handle memakai `pcs`.
- Panjang standar profil dicantumkan dalam identitas barang, misalnya profil kusen putih panjang 6 meter. Quantity 1 berarti satu batang utuh 6 meter, bukan satu meter; panjang 6 meter adalah asumsi katalog demo, bukan standar universal perusahaan.
- Perbedaan jenis profil, ukuran/panjang, warna, atau spesifikasi aksesori yang memengaruhi identitas persediaan menggunakan SKU terpisah. Baseline menyimpan spesifikasi tersebut pada kode/nama barang tanpa menambah modul varian.
- Satu mutasi memiliki tepat satu gudang asal dan satu gudang tujuan.
- Mutasi langsung berstatus selesai setelah commit database; tidak ada status pengiriman.
- Stok yang ditampilkan adalah stok fisik, bukan stok tersedia untuk penjualan.
- Stok awal dicatat melalui UI atau seed yang memakai aturan serta jejak pencatatan setara; bukan modul penerimaan.
- Barang tanpa baris stok di gudang dianggap memiliki stok nol.
- Mutasi hanya memakai barang dan gudang aktif.
- Semua waktu disimpan dalam UTC; API mengirim ISO 8601 UTC, UI menampilkan waktu lokal dengan label yang jelas.

### 3.3 Istilah

| Istilah | Definisi |
|---|---|
| SKU/kode barang | Identitas bisnis unik untuk barang |
| UPVC | Unplasticized Polyvinyl Chloride; dalam demo berupa profil untuk kusen/pintu/jendela beserta aksesori pendukung |
| Batang | Satu profil utuh dengan panjang sesuai SKU; tidak dikonversi menjadi meter atau pecahan |
| Stok | Kuantitas satu barang pada satu gudang |
| Header mutasi | Identitas transaksi, asal, tujuan, waktu, dan catatan |
| Detail mutasi | Barang dan kuantitas yang dipindahkan dalam satu header |
| Pratinjau | Perhitungan sementara dari stok saat data dibaca; bukan reservasi |
| Atomik | Semua perubahan dalam mutasi berhasil bersama atau batal seluruhnya |
| Idempotency key | Identitas unik satu pengiriman logis agar retry tidak menggandakan mutasi |

## 4. Kebutuhan fungsional

### FR-01 — Master barang (P0)

- Menampilkan daftar dengan pencarian kode/nama dan pagination.
- Menambah serta mengubah nama barang dan status aktif.
- Kode: 1–30 karakter ASCII huruf, angka, tanda hubung, atau underscore; trim lalu normalisasi uppercase.
- Nama: 1–100 karakter setelah trim. Satuan: 1–20 karakter setelah trim.
- Kode unik secara case-insensitive. Kode dan satuan tidak dapat diubah setelah barang dibuat untuk menjaga identitas dan interpretasi stok.
- Penghapusan permanen hanya untuk barang yang belum memiliki referensi stok awal, mutasi, atau pergerakan stok dan tidak memiliki stok positif. Baris saldo nol tanpa riwayat boleh dibersihkan secara atomik sebelum penghapusan. Jika sudah digunakan, tolak penghapusan dan gunakan penonaktifan sesuai aturan.
- Barang hanya boleh dinonaktifkan jika seluruh stoknya nol. Data historis tetap dapat dibaca.

### FR-02 — Master gudang (P0)

- Menampilkan daftar, menambah gudang, mengubah nama, dan mengubah status aktif.
- Kode mengikuti format/normalisasi/keunikan kode barang dan tidak dapat diubah setelah dibuat.
- Nama wajib, maksimal 100 karakter setelah trim.
- Penghapusan permanen hanya untuk gudang yang belum memiliki referensi stok awal, mutasi, atau pergerakan stok dan tidak memiliki stok positif. Baris saldo nol tanpa riwayat boleh dibersihkan secara atomik. Jika sudah digunakan, penghapusan ditolak. Gudang hanya boleh dinonaktifkan jika seluruh stok di dalamnya nol.
- Data gudang yang sudah digunakan tetap tersedia untuk pembacaan riwayat.

### FR-03 — Stok per gudang (P0)

- Pengguna memilih gudang dan melihat kode, nama, satuan, serta jumlah stok barang dengan pagination.
- Mendukung pencarian kode/nama barang.
- Barang aktif tanpa baris stok tampil sebagai nol, sehingga gudang baru tetap dapat dipahami pengguna.
- Stok positif pada data yang tidak aktif tidak boleh tersembunyi; invariant penonaktifan juga dijaga backend.
- Tidak menyediakan edit saldo langsung; aksi stok awal mengikuti FR-12 dan rincian pergerakan mengikuti FR-13.
- Setelah mutasi berhasil, data stok terkait dimuat ulang dari backend.
- Tidak menjumlahkan kuantitas lintas satuan menjadi satu angka ringkasan.

### FR-04 — Form mutasi multi-item (P0)

- Memilih gudang asal dan tujuan yang aktif serta berbeda.
- Menambah/menghapus baris barang, minimal 1 dan maksimal 50 jenis barang per transaksi.
- Memilih barang aktif, menampilkan stok asal terakhir yang diketahui, dan memasukkan kuantitas.
- Kuantitas harus integer 1–1.000.000 per baris. Batas stok tersimpan adalah 2.147.483.647 per pasangan barang–gudang; mutasi yang melampaui batas tujuan ditolak.
- Barang tidak boleh muncul dua kali. Backend menolak duplikasi, bukan diam-diam menjumlahkannya.
- Catatan opsional, maksimal 500 karakter setelah trim.
- Mengubah asal, tujuan, barang, atau jumlah membatalkan pratinjau sebelumnya.
- Perubahan gudang asal memicu pemuatan ulang stok dan validasi seluruh baris.
- Tidak menyimpan draft di server. Form yang belum dikonfirmasi belum memengaruhi stok.

### FR-05 — Pratinjau dampak stok (P0)

- Backend menghasilkan pratinjau dari payload form; tidak mempercayai hasil hitung dari frontend.
- Preview utama menampilkan gudang dan barang di kiri serta perubahan quantity bersatuan di kanan: tambah hijau dengan tanda plus, kurang merah dengan tanda minus. Rincian sebelum/sesudah tetap dihitung backend, tetapi tidak memenuhi kartu preview utama dengan informasi berulang.
- Alur tetap form → preview → tombol konfirmasi → persetujuan. Tidak ada paragraf reservasi pada preview; pemeriksaan ulang stok tetap dilakukan backend dan disebut pada dialog konfirmasi yang sudah tersedia.
- Rumus: `asal_sesudah = asal_sekarang - jumlah`; `tujuan_sesudah = tujuan_sekarang + jumlah`.
- Pratinjau tidak menulis stok, tidak membuat transaksi, dan tidak mengunci/reservasi stok selama pengguna meninjau layar.
- Tombol konfirmasi tersedia setelah pratinjau berhasil.
- Jika terjadi perubahan stok tetapi jumlah masih mencukupi, backend boleh memproses memakai stok terbaru. Bukti transaksi menampilkan hasil aktual, bukan angka pratinjau yang lama.
- Jika stok terbaru tidak mencukupi, seluruh mutasi ditolak dan pengguna diminta memperbarui pratinjau.

### FR-06 — Konfirmasi mutasi (P0)

- Backend memvalidasi ulang seluruh payload, keberadaan dan status master, batas stok, serta kuantitas.
- Pengurangan stok asal, penambahan stok tujuan, header, detail, dan identitas request tersimpan dalam satu transaksi database.
- Tidak ada hasil parsial. Satu item gagal berarti semua item batal.
- Nomor mutasi unik dibuat server, dengan format `MUT-YYYYMMDD-ID`; bagian angka berasal dari identitas unik database, bukan `MAX + 1` tanpa proteksi.
- Tanggal nomor menggunakan UTC dan nomor tidak wajib berurutan tanpa celah atau reset setiap hari.
- Respons sukses hanya dikirim setelah commit berhasil.
- Tombol konfirmasi dinonaktifkan selama request berjalan; tampilan loading tidak memblokir selamanya jika koneksi gagal.
- Setelah sukses, form selesai dan aplikasi membuka detail mutasi.

### FR-07 — Perlindungan pengiriman ganda (P0)

- Frontend membuat UUID idempotency key untuk satu payload konfirmasi dan mengirimkannya melalui header `Idempotency-Key`.
- Retry setelah timeout/koneksi terputus menggunakan key dan payload yang sama selama sesi form tersebut.
- Key yang sudah sukses dengan payload identik mengembalikan transaksi yang sama tanpa perubahan stok baru.
- Key yang sama dengan payload berbeda ditolak dengan HTTP 409.
- Payload dinormalisasi dan detail diurutkan berdasarkan ID barang sebelum fingerprint dihitung; perubahan urutan baris saja tidak menciptakan payload bisnis berbeda.
- Unique constraint database melindungi request bersamaan dengan key yang sama. Request yang kalah harus membaca hasil pemenang setelah rollback, atau mengembalikan error retryable jika hasil belum tersedia.
- Key dan fingerprint sukses disimpan bersama mutasi. Mutasi gagal tidak meninggalkan perubahan stok maupun key sukses.
- Jika pengguna mengubah payload setelah penolakan yang pasti, gunakan key baru dan lakukan pratinjau ulang. Jika hasil masih tidak diketahui karena timeout, selesaikan retry payload lama terlebih dahulu.
- Pemulihan otomatis setelah aplikasi ditutup paksa tidak termasuk baseline; pengguna dapat memeriksa riwayat sebelum membuat transaksi baru.

### FR-08 — Bukti/detail mutasi (P0)

- Menampilkan nomor, status `COMPLETED`, waktu, asal, tujuan, catatan, serta seluruh barang/satuan/jumlah.
- Menampilkan stok sebelum/sesudah aktual saat transaksi diproses untuk memudahkan verifikasi.
- Nilai sebelum/sesudah diberi label sebagai kondisi saat transaksi, bukan stok terkini.
- Nama/kode/satuan pada dokumen memakai snapshot saat transaksi sehingga perubahan nama master tidak menulis ulang bukti lama.
- Detail dapat dibuka langsung dari hasil sukses maupun riwayat.
- Tidak ada tombol edit, hapus, atau batalkan transaksi.
- Bukti berupa halaman aplikasi, bukan PDF atau dokumen legal bertanda tangan.

### FR-09 — Riwayat mutasi (P0/P1)

- P0: daftar terbaru dahulu, pagination, nomor, waktu, asal, tujuan, jumlah jenis barang, dan navigasi detail.
- Urutan stabil: waktu descending, lalu ID descending.
- P1: pencarian nomor, filter rentang tanggal, gudang asal, dan gudang tujuan.
- Filter tanggal UI dikonversi ke rentang UTC dengan awal inklusif dan akhir eksklusif agar batas hari tidak ambigu.
- Menampilkan empty state dan cara mencoba ulang jika gagal memuat.

### FR-10 — Alasan mutasi (P1)

- Pilihan opsional: transfer operasional, pemindahan karena reject QC, pemindahan untuk rework, pengembalian setelah rework, lainnya.
- Disimpan sebagai kode enum yang divalidasi backend; tidak memerlukan CRUD kategori.
- Alasan hanya menjelaskan perpindahan barang yang sama antar gudang. Tidak mengubah jenis barang, jumlah total, atau status kualitas.
- Tanpa fitur ini, catatan P0 tetap mencukupi.

### FR-11 — Ringkasan operasional (P2)

- Jumlah barang aktif, gudang aktif, transaksi hari ini, dan lima mutasi terbaru.
- Aksi cepat buat mutasi dan lihat stok.
- Hari ini mengikuti zona lokal pengguna yang dikonversi menjadi rentang UTC untuk query.
- Tidak menampilkan agregasi kuantitas berbeda satuan atau grafik dekoratif tanpa kebutuhan.

### FR-12 — Pencatatan stok awal melalui UI (P0)

- Form memilih satu gudang aktif, satu barang aktif, quantity integer 1–1.000.000, dan catatan opsional maksimal 500 karakter. Satu dokumen stok awal mencatat satu pasangan barang–gudang untuk membatasi lingkup.
- Hanya diperbolehkan jika pasangan tersebut belum pernah memiliki pergerakan stok, belum memiliki pencatatan stok awal, dan saldo saat ini nol. Baris saldo yang belum ada diperlakukan nol.
- Saldo nol setelah pernah dipakai bukan alasan untuk mengizinkan stok awal baru. Barang yang sudah masuk melalui mutasi tidak boleh kemudian diberi stok awal pada pasangan yang sama.
- Server memeriksa syarat dalam transaksi dengan protokol lock yang sama seperti mutasi; pemeriksaan UI saja tidak cukup.
- Sistem membuat referensi unik `AWL-YYYYMMDD-ID`, waktu server UTC, snapshot barang/satuan/gudang, saldo sebelum nol, dan saldo setelah sesuai quantity.
- Dokumen, saldo, dan satu pergerakan `OPENING` tersimpan atomik. Stok awal menambah total stok barang sebagai inisialisasi; invariant total tetap berlaku khusus untuk mutasi antar gudang.
- Menggunakan `Idempotency-Key` dengan perilaku retry FR-07. Namespace key terpisah per jenis operasi; key sukses yang sama pada endpoint stok awal dengan payload berbeda ditolak.
- Tidak mendukung edit/hapus dokumen, tanggal mundur, atau pengisian berulang. Dokumen dapat dibuka kembali dari kartu stok.
- UI menyediakan konfirmasi ringkas sebelum simpan, serta loading/error/retry. Seed tidak menjadi satu-satunya cara mengisi stok.

### FR-13 — Kartu stok per barang dan gudang (P0)

- Pengguna memilih satu gudang dan satu barang untuk melihat pergerakan `OPENING` (Stok awal), `TRANSFER_IN` (Mutasi masuk), dan `TRANSFER_OUT` (Mutasi keluar).
- Tampilkan waktu, referensi dokumen, jenis, masuk, keluar, saldo sesudah, serta tautan bukti transaksi terkait. Saldo sebelum dapat ditampilkan dalam detail.
- Satu detail mutasi menghasilkan tepat dua pergerakan dengan quantity sama: keluar di asal dan masuk di tujuan, keduanya mengacu pada detail/dokumen yang sama.
- Rumus setiap pergerakan: `saldo_sesudah = saldo_sebelum + masuk - keluar`; saldo terakhir harus sama dengan saldo tersimpan untuk pasangan tersebut.
- Pergerakan tidak bisa diinput, diedit, atau dihapus secara independen. Pergerakan hanya ditulis oleh transaksi stok awal atau mutasi.
- Daftar dipaginasi dan diurutkan berdasarkan urutan pencatatan per pasangan (ID pergerakan); UI default terbaru dahulu. Waktu saja tidak cukup untuk menentukan urutan jika timestamp sama.
- Saldo historis dibaca dari snapshot pergerakan yang ditulis saat lock saldo dipegang, bukan dihitung dari hanya baris pada halaman aktif. Respons menyertakan saldo terkini secara konsisten dengan snapshot pembacaan daftar.
- P0 tidak memerlukan filter tanggal kartu stok atau agregasi lintas barang/gudang. Riwayat mutasi tetap merupakan daftar dokumen, berbeda dari kartu stok.

## 5. Aturan bisnis dan invariant

| ID | Aturan |
|---|---|
| BR-01 | Asal dan tujuan berbeda serta aktif saat commit |
| BR-02 | Item unik dalam satu mutasi; kuantitas integer positif |
| BR-03 | Stok tidak pernah negatif atau melebihi batas penyimpanan |
| BR-04 | Untuk setiap barang, total stok seluruh gudang sebelum dan sesudah mutasi sama |
| BR-05 | Seluruh item, perubahan stok, header, dan detail atomik |
| BR-06 | Pasangan barang–gudang memiliki paling banyak satu baris stok |
| BR-07 | Transaksi sukses immutable; perubahan master tidak mengubah snapshot bukti |
| BR-08 | Request sukses yang diulang dengan key sama tidak membuat mutasi tambahan |
| BR-09 | Pratinjau tidak memengaruhi stok dan tidak menggantikan validasi saat commit |
| BR-10 | Penonaktifan master hanya saat stok nol dan harus aman terhadap mutasi bersamaan |
| BR-11 | Mutasi menjaga total per barang, bukan total gabungan barang/satuan berbeda |
| BR-12 | Stok awal hanya sekali dan sebelum pergerakan pertama untuk pasangan barang–gudang; saldo nol tidak menghapus riwayat |
| BR-13 | Setiap stok awal memiliki satu pergerakan; setiap detail mutasi memiliki tepat dua pergerakan yang seimbang |
| BR-14 | Saldo tersimpan sama dengan saldo terakhir kartu stok; seluruh dokumen, saldo, dan pergerakan ditulis atomik |
| BR-15 | Master yang sudah dipakai tidak boleh dihapus; hapus, penonaktifan, stok awal, dan mutasi memakai protokol lock yang konsisten |

## 6. Alur pengguna dan layar

### 6.1 Layar minimum

1. Daftar/form barang.
2. Daftar/form gudang.
3. Stok per gudang.
4. Form mutasi multi-item.
5. Pratinjau dan konfirmasi.
6. Riwayat mutasi.
7. Detail/bukti mutasi.
8. Form konfirmasi dan detail stok awal.
9. Kartu stok per barang–gudang.

Ringkasan operasional opsional. Navigasi utama tetap sederhana: stok, mutasi, dan master. Tidak diperlukan sistem desain atau library UI baru sebelum mengevaluasi komponen bawaan Flutter.

### 6.2 Alur sukses

Pilih asal/tujuan → tambah item → isi jumlah → pratinjau → tinjau dampak → konfirmasi → backend commit → detail transaksi → stok/riwayat dimuat ulang.

Alur dari data kosong: buat barang dan gudang → catat stok awal → lihat kartu stok → buat mutasi → lihat dua sisi pergerakan dan bukti transaksi. Gudang tujuan boleh belum memiliki stok awal; penerimaan melalui mutasi menjadi pergerakan pertamanya.

### 6.3 Alur kegagalan

- Input tidak valid: tampilkan pesan dekat field, pertahankan isian.
- Stok tidak cukup: tampilkan item bermasalah dan stok aktual; tidak ada perubahan parsial.
- Koneksi gagal saat membaca: tampilkan retry, jangan menampilkan data lama sebagai data terbaru tanpa penanda.
- Timeout saat konfirmasi: jelaskan hasil belum diketahui; retry memakai key yang sama, bukan membuat transaksi baru.
- Error internal: tampilkan pesan aman dan request ID; detail teknis dicatat di server, bukan dibocorkan ke UI.

## 7. Rancangan data awal

Rancangan ini mengarahkan implementasi; DDL/migration final akan dibuat dan diuji pada tahap kode. Semua tabel memakai InnoDB, foreign key, dan charset utf8mb4. ID menggunakan integer positif; kuantitas memakai integer dengan constraint rentang.

### 7.1 Entitas

| Tabel | Kolom utama dan constraint |
|---|---|
| `items` | `id` PK, `code` unique, `name`, `unit`, `is_active`, `created_at`, `updated_at` |
| `warehouses` | `id` PK, `code` unique, `name`, `is_active`, `created_at`, `updated_at` |
| `warehouse_stocks` | `warehouse_id` FK, `item_id` FK, `quantity` default 0, `updated_at`; PK komposit `(warehouse_id, item_id)`; CHECK quantity >= 0 |
| `stock_transfers` | `id` PK, `transfer_number` unique, `source_warehouse_id` FK, `destination_warehouse_id` FK, snapshot kode/nama kedua gudang, `status`, `notes`, `idempotency_key` unique, `request_fingerprint`, `created_at` |
| `stock_transfer_items` | `id` PK, `transfer_id` FK, `item_id` FK, snapshot kode/nama/satuan barang, `quantity`, `source_stock_before`, `source_stock_after`, `destination_stock_before`, `destination_stock_after`; unique `(transfer_id, item_id)` |
| `opening_stocks` | `id` PK, `opening_number` unique, `warehouse_id` FK, `item_id` FK, `quantity`, snapshot kode/nama gudang dan barang/satuan, `notes`, `idempotency_key` unique, `request_fingerprint`, `created_at`; unique `(warehouse_id, item_id)` |
| `stock_movements` | `id` PK, `warehouse_id` FK, `item_id` FK, `movement_type`, `quantity_in`, `quantity_out`, `balance_before`, `balance_after`, `opening_stock_id` nullable FK, `transfer_item_id` nullable FK, `created_at` |

Jika P1 alasan diterapkan, tambahkan `reason_code` nullable pada header dan kontrak API secara konsisten. Jangan membuat kolom wajib untuk fitur opsional yang belum dikerjakan.

### 7.2 Relasi dan constraint

- Barang 1:N stok; gudang 1:N stok.
- Header mutasi 1:N detail; barang 1:N detail.
- Gudang 1:N mutasi sebagai asal dan sebagai tujuan melalui dua FK berbeda.
- FK riwayat menggunakan RESTRICT untuk penghapusan master. Endpoint DELETE hanya menghapus master yang belum digunakan setelah pemeriksaan dan lock; tidak ada cascade yang menghapus histori.
- CHECK asal tidak sama dengan tujuan; CHECK quantity detail > 0; CHECK snapshot stok tidak negatif.
- `status` hanya `COMPLETED` pada baseline, bukan workflow draft/pending.
- Index untuk waktu/ID riwayat, FK, serta kombinasi gudang-waktu sesuai query filter. Optimasi lanjutan didasarkan pada query nyata, bukan menambahkan index tanpa evaluasi.
- Snapshot pada detail adalah salinan historis yang disengaja; stok terkini tetap bersumber dari `warehouse_stocks`.
- `opening_stocks` berelasi ke satu barang dan satu gudang; quantity positif. Unique pasangan mencegah pengisian awal kedua tetapi tidak menggantikan pemeriksaan riwayat mutasi.
- `stock_movements` memakai tepat satu sumber: `opening_stock_id` atau `transfer_item_id`, tidak keduanya dan tidak keduanya kosong. Gunakan FK eksplisit, bukan reference ID generik tanpa integritas relasi.
- Unique `opening_stock_id` memastikan satu pergerakan per stok awal. Unique `(transfer_item_id, movement_type)` mencegah dua entri masuk/keluar sejenis untuk detail yang sama.
- CHECK jenis `OPENING`/`TRANSFER_IN` memiliki masuk > 0 dan keluar = 0; `TRANSFER_OUT` memiliki keluar > 0 dan masuk = 0. CHECK saldo nonnegatif dan persamaan saldo. Jenis harus cocok dengan sumber dokumennya.
- Kesesuaian barang/gudang/quantity pergerakan dengan dokumen sumber dijaga service transaksi dan diuji. Index `(warehouse_id, item_id, id)` mendukung kartu stok. Jangan menganggap constraint jumlah baris menjamin sendiri keberadaan tepat dua pergerakan mutasi.
- Kartu stok menjadi jejak perubahan saldo yang dapat direkonsiliasi; bukan modul event sourcing atau saldo yang boleh diedit terpisah.

### 7.3 Strategi transaksi dan konkurensi

1. Validasi bentuk request sebelum membuka transaksi.
2. Mulai transaksi dan tangani idempotency key dengan unique constraint; tidak hanya pemeriksaan di memori.
3. Kunci baris master gudang dan barang yang digunakan dalam urutan konsisten, lalu periksa status aktif. Jalur stok awal, hapus, dan penonaktifan menggunakan urutan/protokol lock yang sama.
4. Pastikan baris stok yang dibutuhkan tersedia secara aman menggunakan unique key/upsert; baris baru dibuat dengan nol di dalam transaksi.
5. Kunci semua pasangan stok yang terlibat dengan urutan deterministik `(warehouse_id, item_id)` dan baca nilai aktual.
6. Validasi seluruh item sebelum menyelesaikan perubahan; hitung batas tujuan dan stok asal.
7. Simpan header/snapshot/detail, dua pergerakan per detail, serta ubah stok di transaksi yang sama.
8. Commit, baru respons sukses. Setiap kegagalan memicu rollback.
9. Deadlock/lock timeout tetap mungkin; lakukan retry seluruh transaksi secara terbatas atau kembalikan error retryable yang aman. Jangan retry sebagian update.

Urutan rinci SQL perlu dibuktikan melalui pengujian integrasi, termasuk dua mutasi yang saling berlawanan, tujuan yang belum memiliki stok, penonaktifan bersamaan, dan request dengan key sama. Strategi ini mengutamakan kebenaran demo, bukan klaim throughput skala besar.

Untuk stok awal, gunakan urutan lock master/pasangan yang sama, lalu periksa tidak ada pergerakan atau dokumen stok awal dan saldo nol sebelum menulis dokumen, satu pergerakan, dan saldo. Ini mencegah perlombaan antara stok awal dan mutasi pertama. Penghapusan master juga harus memegang lock yang sama sebelum memeriksa referensi; konflik ditolak tanpa menghapus histori. Pengujian rollback mencakup tabel pergerakan, bukan hanya saldo dan dokumen.

## 8. Kontrak REST API awal

Base path: `/api/v1`. JSON untuk request/response. Detail field final harus konsisten antara kode, dokumentasi, dan Flutter.

| Method | Path | Kegunaan |
|---|---|---|
| GET | `/health` | Pemeriksaan aplikasi dan koneksi database tanpa mengekspos konfigurasi |
| GET | `/items` | Daftar barang, `search`, `page`, `limit`, `active` |
| POST | `/items` | Tambah barang |
| PATCH | `/items/:id` | Ubah nama/status aktif sesuai aturan |
| DELETE | `/items/:id` | Hapus barang yang belum digunakan; selain itu konflik |
| GET | `/warehouses` | Daftar gudang, pagination dan filter aktif |
| POST | `/warehouses` | Tambah gudang |
| PATCH | `/warehouses/:id` | Ubah nama/status aktif sesuai aturan |
| DELETE | `/warehouses/:id` | Hapus gudang yang belum digunakan; selain itu konflik |
| GET | `/stocks` | `warehouse_id` wajib; `search`, `page`, `limit` |
| POST | `/opening-stocks` | Catat stok awal dengan `Idempotency-Key` |
| GET | `/opening-stocks/:id` | Detail/bukti stok awal |
| GET | `/stock-movements` | Kartu stok: `warehouse_id` dan `item_id` wajib; `page`, `limit` |
| POST | `/transfers/preview` | Validasi dan perhitungan tanpa perubahan data |
| POST | `/transfers` | Konfirmasi dengan header `Idempotency-Key` |
| GET | `/transfers` | Riwayat; P1: `search`, `source_warehouse_id`, `destination_warehouse_id`, `from`, `to` |
| GET | `/transfers/:id` | Header, snapshot, dan seluruh detail transaksi |

Tidak ada endpoint edit/hapus mutasi atau update stok langsung. Daftar default 20 baris, maksimal 100; `page` dan `limit` harus integer positif. ID yang tidak valid ditolak, bukan diteruskan mentah ke query.

### 8.1 Payload pratinjau dan konfirmasi

```json
{
  "source_warehouse_id": 1,
  "destination_warehouse_id": 2,
  "notes": "Pemindahan profil dan aksesori UPVC ke Gudang Cabang",
  "items": [
    { "item_id": 1, "quantity": 5 },
    { "item_id": 2, "quantity": 10 }
  ]
}
```

ID berupa integer positif. Client tidak boleh menentukan nomor transaksi, status, waktu commit, snapshot, atau saldo hasil. Field yang tidak dikenal ditolak agar kesalahan kontrak tidak tersembunyi.

### 8.2 Payload stok awal

```json
{
  "warehouse_id": 1,
  "item_id": 1,
  "quantity": 25,
  "notes": "Saldo awal saat mulai menggunakan aplikasi"
}
```

Header `Idempotency-Key` wajib. Respons detail berisi referensi, snapshot, waktu, quantity, dan saldo sebelum/sesudah. Error `OPENING_NOT_ALLOWED` (409) digunakan ketika pasangan sudah memiliki histori atau saldo; `MASTER_IN_USE` (409) untuk master yang tidak boleh dihapus. Kartu stok menampilkan ID sumber dokumen agar UI dapat membuka endpoint detail yang sesuai.

### 8.3 Format respons

Respons sukses: `{"data": ...}`. Respons daftar menyertakan `meta` berisi `page`, `limit`, dan `total`. Pratinjau menyertakan waktu pembacaan dan nilai sebelum/sesudah per item. Detail sukses menyertakan ID, nomor transaksi, waktu, status, serta snapshot aktual.

Contoh error:

```json
{
  "error": {
    "code": "INSUFFICIENT_STOCK",
    "message": "Stok asal tidak mencukupi.",
    "details": [
      { "item_id": 1, "available": 3, "requested": 5 }
    ],
    "request_id": "8d12c2f1-4af5-4ff7-915e-3b75fc8b5bb0"
  }
}
```

| HTTP | Penggunaan |
|---|---|
| 200 | Baca/pratinjau/ubah sukses atau replay transaksi sukses |
| 201 | Master, stok awal, atau mutasi baru berhasil dibuat |
| 204 | Master yang belum digunakan berhasil dihapus; tanpa body |
| 400 | JSON/header/query tidak valid atau idempotency key wajib tidak diberikan |
| 404 | Resource tidak ditemukan |
| 409 | Stok tidak cukup, konflik kode, master tidak aktif/masih memiliki stok, key berbeda payload, atau kapasitas stok terlampaui |
| 422 | Validasi semantik field: asal=tujuan, jumlah tidak valid, item duplikat |
| 500 | Kesalahan internal tidak terduga setelah rollback |
| 503 | Database tidak tersedia atau konflik sementara yang dapat dicoba ulang setelah batas retry |

## 9. Kebutuhan nonfungsional

### NFR-01 — Integritas dan keandalan

- Invariant BR-01 sampai BR-15 harus diuji pada database MySQL nyata untuk operasi stok, bukan hanya mock.
- Tidak menggunakan floating point untuk kuantitas.
- Server dan database menjadi sumber kebenaran; validasi UI hanya membantu pengguna.
- Koneksi database dilepas pada jalur sukses maupun gagal.

### NFR-02 — Keamanan dasar

- Gunakan parameterized query atau mekanisme setara, bukan konkatenasi input ke SQL.
- Validasi tipe, panjang, rentang, field yang diizinkan, dan batas jumlah item di backend.
- Kredensial database hanya di backend melalui environment; tidak ditanam di Flutter atau Git.
- `.env` asli tidak dikomit; `.env.example` tidak berisi rahasia.
- Error publik tidak memuat SQL, stack trace, password, atau connection string.
- Gunakan akun database aplikasi dengan hak minimum yang diperlukan.
- CORS, jika Flutter Web dipakai untuk pengujian, dibatasi sesuai origin demo dan bukan dianggap sebagai autentikasi.
- Akses HTTP lokal Android hanya dikonfigurasi untuk kebutuhan development; deployment publik membutuhkan HTTPS dan autentikasi di luar baseline.

### NFR-03 — UX dan aksesibilitas dasar

- UI berbahasa Indonesia, label konsisten, angka mudah dibaca, tanpa mengandalkan warna saja untuk error/status.
- Semua layar data memiliki loading, empty, error, dan retry state yang relevan.
- Input quantity memakai keyboard numerik, tetapi tetap divalidasi sebagai integer.
- Form tidak kehilangan isian akibat error server biasa.
- Form multi-item dapat digulir dan tetap dapat digunakan pada layar ponsel; tidak bergantung pada tabel desktop yang terlalu lebar.

### NFR-04 — Performa

- Semua daftar berpotensi besar memakai pagination; detail mutasi dibatasi maksimal 50 item.
- Hindari request per baris yang tidak perlu dan query N+1 untuk daftar/detail.
- Ukur respons lokal menggunakan seed dan catat kondisi pengukuran; tidak mengklaim SLA produksi atau angka performa tanpa pengukuran.

### NFR-05 — Maintainability

- Pisahkan routing/controller, validasi, logika bisnis, dan akses data secara proporsional; logika transaksi stok tidak disebar pada handler UI.
- Flutter memisahkan model, komunikasi API, state layar, dan widget; pilihan library state management tidak dikunci sebelum implementasi.
- Gunakan library yang memang dipilih, dipasang, dan didokumentasikan; jangan mengasumsikan dependency sudah tersedia pada workspace kosong.
- Commit Git bertahap dan bermakna hanya setelah perintah eksplisit pengguna; jangan melakukan commit otomatis atau merekayasa riwayat kerja. Push dan pengumpulan memerlukan persetujuan pengguna.

### NFR-06 — Reproducibility

- Versi runtime/dependency dikunci atau dicatat sesuai tooling.
- Migration/schema dan seed tersedia dengan langkah eksekusi jelas.
- README membedakan setup baru, menjalankan ulang, dan reset database demo yang destruktif.
- Build dan pengujian dicatat sesuai hasil nyata, termasuk keterbatasan yang belum terselesaikan.

## 10. Environment dan verifikasi

Environment harus diverifikasi melalui instalasi, pengujian koneksi, dan build nyata. Dokumen ini tidak menyatakan bahwa pemeriksaan tersebut telah lulus.

| Komponen | Kebutuhan verifikasi |
|---|---|
| Workspace | `E:\Project\practicaltestv2` |
| Node.js/npm | Versi runtime dan package manager kompatibel dengan dependency backend |
| Flutter/Dart | SDK tersedia dan kompatibel dengan dependency frontend |
| Android toolchain | Android SDK, JDK, dan lisensi siap untuk build |
| Perangkat Android | Emulator atau perangkat fisik dapat menjalankan aplikasi dan mengakses backend |
| MySQL | Koneksi, InnoDB, migration, seed, dan transaksi dapat diuji |
| Git | Repository dan aturan pengecualian file dikonfigurasi tanpa menyertakan rahasia |
Kelulusan Flutter Doctor tidak membuktikan build Gradle/aplikasi berhasil. Versi toolchain final harus dikonfirmasi melalui build nyata. Pada emulator Android standar, backend host biasanya diakses melalui `10.0.2.2`, bukan `localhost` perangkat; URL harus configurable dan diuji. Jangan mengubah konfigurasi global atau membuka firewall tanpa kebutuhan yang jelas.

## 11. Data demo

Seed minimal:

- Gudang Utama (`GDG-UTAMA`), Gudang Cabang (`GDG-CABANG`), dan Gudang Baru (`GDG-BARU`); seluruhnya lokasi penyimpanan, bukan tahapan produksi.
- Profil Kusen UPVC Putih 6 Meter (`UPVC-KSN-PTH-6M`), satuan `batang`; Engsel Jendela UPVC (`ACC-ENG-JDL`), satuan `pcs`; Handle Jendela UPVC Putih (`ACC-HDL-JDL-PTH`), satuan `pcs`.
- Penyebutan singkat Profil, Engsel, dan Handle pada skenario demo/pengujian mengacu tepat pada tiga SKU di atas. Spesifikasi contoh perlu disesuaikan bila katalog perusahaan tersedia.
- Utama: Profil 25 batang, Engsel 40 pcs, Handle 12 pcs.
- Cabang: Profil 3 batang, Engsel 5 pcs; belum ada baris stok Handle.
- Gudang Baru belum memiliki baris stok barang.
- Tidak ada mutasi historis awal. Setiap saldo positif seed memiliki dokumen stok awal dan pergerakan `OPENING`, sehingga saldo dapat direkonsiliasi dari kartu stok.

Seed tidak boleh menimpa stok yang sudah digunakan secara diam-diam. Pilih insert-only untuk setup awal atau reset eksplisit khusus database demo, lalu dokumentasikan perilakunya.

Seed mengikuti invariant dan penulisan atomik stok awal; tidak mengisi saldo langsung tanpa dokumen/pergerakan. Pengguna juga harus dapat membuat data baru dan mengisi stok awal dari UI tanpa menjalankan seed ulang.

## 12. Kriteria penerimaan dan pengujian

Setiap skenario memakai database terisolasi atau reset fixture yang eksplisit. Tabel berikut adalah rencana pengujian, bukan hasil lulus.

| ID | Skenario | Hasil yang harus terbukti |
|---|---|---|
| AC-01 | Buat barang/gudang valid lalu kode duplikat dengan beda case | Data pertama tersimpan; duplikat ditolak dengan pesan jelas |
| AC-02 | Lihat Gudang Baru | Barang aktif tampil dengan stok nol tanpa error |
| AC-03 | Utama → Cabang: Profil 5 batang, Engsel 10 pcs, Handle 2 pcs | Asal: Profil 20 batang, Engsel 30 pcs, Handle 10 pcs; tujuan: Profil 8 batang, Engsel 15 pcs, Handle 2 pcs; satu header, tiga detail; tidak menjumlahkan batang dan pcs |
| AC-04 | Pratinjau AC-03 sebelum konfirmasi | Nilai sebelum/sesudah benar; database belum berubah |
| AC-05 | Satu item melebihi stok dalam mutasi multi-item | Semua stok tetap; tidak ada header/detail sukses atau key sukses tertinggal |
| AC-06 | Gudang sama; quantity 0, negatif, pecahan, string, null; item duplikat | Ditolak frontend jika relevan dan selalu ditolak backend |
| AC-07 | Mutasi ke pasangan stok yang belum ada | Satu baris stok tujuan dibuat; tidak ada duplikasi pasangan |
| AC-08 | Dua key berbeda mencoba memindahkan 4+4 dari saldo 5 | Paling banyak satu sukses; saldo tidak negatif dan total tetap |
| AC-09 | Dua request bersamaan memakai key dan payload sama | Tepat satu mutasi; retry memperoleh ID/nomor yang sama |
| AC-10 | Key sukses dipakai dengan payload berbeda | HTTP 409; stok dan riwayat tidak berubah |
| AC-11 | Simulasikan kegagalan setelah sebagian update dalam transaksi melalui test harness | Rollback seluruh perubahan, header, dan detail |
| AC-12 | Stok berubah setelah pratinjau dan kini tidak cukup | Konfirmasi ditolak; UI mempertahankan input dan menawarkan pemuatan ulang |
| AC-13 | Stok berubah setelah pratinjau tetapi masih cukup | Mutasi memakai saldo aktual; bukti menunjukkan snapshot aktual |
| AC-14 | Rename barang/gudang setelah mutasi | Master memakai nama baru; bukti lama tetap memakai snapshot lama |
| AC-15 | Nonaktifkan master dengan stok positif; kemudian gunakan master nonaktif | Penonaktifan pertama ditolak; master nonaktif tidak dapat dipakai untuk mutasi |
| AC-16 | Mutasi dan penonaktifan berjalan bersamaan | Tidak ada mutasi memakai master yang sudah nonaktif atau master nonaktif berstok positif |
| AC-17 | Timeout UI setelah server commit lalu retry key sama | Tidak menggandakan transaksi atau stok |
| AC-18 | Dua mutasi berlawanan arah dengan banyak item | Tidak korup; deadlock ditangani dengan rollback/retry terbatas atau error aman |
| AC-19 | Payload melampaui 50 item/batas quantity atau kapasitas tujuan | Ditolak tanpa perubahan data |
| AC-20 | Riwayat lebih dari satu halaman dan buka detail | Urutan stabil, pagination benar, detail lengkap dan tidak dapat diedit |
| AC-21 | API tidak tersedia saat form/list digunakan | Loading berakhir, error/retry tampil, aplikasi tidak crash |
| AC-22 | Jalankan setup bersih mengikuti README dan build Android | Reviewer dapat menyiapkan database/backend/frontend; hasil build dicatat |
| AC-23 | P1 filter tanggal/gudang/nomor bila diterapkan | Hasil sesuai filter, termasuk batas hari dan pagination |
| AC-24 | Buat master baru, isi stok awal 25 melalui UI | Satu dokumen AWL, satu pergerakan OPENING 0→25, dan saldo 25; dapat dibuka kembali |
| AC-25 | Coba stok awal kedua atau pada pasangan yang pernah dimutasi lalu bersaldo nol | HTTP 409; tidak ada perubahan saldo/dokumen/pergerakan |
| AC-26 | Retry stok awal setelah timeout dengan key sama; lalu key sama payload berbeda | Retry identik mengembalikan dokumen yang sama; payload berbeda ditolak |
| AC-27 | Stok awal dan mutasi pertama berjalan bersamaan pada pasangan sama | Hasil mengikuti urutan lock yang sah; tidak menimpa saldo atau menyisipkan stok awal setelah pergerakan pertama |
| AC-28 | Buka kartu stok kedua gudang setelah AC-03 | Tiga pergerakan keluar dan tiga masuk mengacu pada detail mutasi yang tepat; saldo terakhir sama dengan stok |
| AC-29 | Hapus master baru yang belum dipakai; hapus master berhistori dengan saldo nol | Yang belum dipakai terhapus; yang berhistori ditolak tanpa menghapus referensi |
| AC-30 | Hapus master bersamaan dengan stok awal atau mutasi | Salah satu operasi ditolak sesuai urutan sah; tidak ada orphan, kehilangan histori, atau saldo tanpa master |
| AC-31 | Gagal saat menulis pergerakan stok awal atau mutasi melalui test harness | Dokumen, saldo, key sukses, dan semua pergerakan rollback bersama |
| AC-32 | Kartu stok lebih dari satu halaman, timestamp sama, dan seed | Urutan pencatatan stabil; saldo historis benar tanpa menjumlahkan hanya halaman aktif; saldo seed memiliki sumber |

### 12.1 Lapisan pengujian

- Unit: validasi, normalisasi/fingerprint, dan perhitungan dampak stok.
- Integrasi API + MySQL: constraint, transaksi, rollback, idempotency, dan konkurensi.
- Flutter: analisis statis, pengujian widget/form yang relevan, dan smoke test alur end-to-end.
- Manual: koneksi emulator ke backend, navigasi, input, loading/error/empty state, serta bukti transaksi.
- Build: build Android nyata; bila gagal, perbaiki atau dokumentasikan kegagalan secara jujur, jangan menyamakan Flutter Doctor dengan build sukses.

Fault injection hanya melalui test harness/database uji, bukan endpoint publik yang sengaja merusak transaksi.

## 13. Matriks ketertelusuran

| Kebutuhan sumber | Spesifikasi | Verifikasi utama |
|---|---|---|
| Master barang | FR-01 | AC-01, AC-14, AC-15, AC-29, AC-30 |
| Master gudang dan stok per gudang | FR-02, FR-03 | AC-01, AC-02, AC-07, AC-29, AC-30 |
| Transaksi mutasi | FR-04, FR-06, FR-07 | AC-03, AC-05–AC-19 |
| Riwayat mutasi | FR-08, FR-09 | AC-14, AC-20 |
| Validasi dan error | FR-01–FR-07, NFR-02/03 | AC-05, AC-06, AC-19, AC-21 |
| Konsistensi dan perhitungan stok | BR-01–BR-15, NFR-01 | AC-03–AC-19, AC-24–AC-32 |
| Flutter, JavaScript, REST API | Bagian 8–10 | Integrasi end-to-end dan AC-22 |
| Dokumentasi, database, GitHub | Bagian 14 | Pemeriksaan repository dan setup bersih |
| Tambahan multi-item | FR-04 | AC-03, AC-05 |
| Tambahan pratinjau | FR-05 | AC-04, AC-12, AC-13 |
| Tambahan bukti transaksi | FR-08 | AC-03, AC-14, AC-20 |
| Revisi stok awal melalui UI | FR-12 | AC-24–AC-27, AC-31 |
| Revisi kartu stok | FR-13 | AC-28, AC-31, AC-32 |

## 14. Deliverables dan Definition of Done

### 14.1 Deliverables

- Source code Flutter dan backend JavaScript.
- Schema/migration, relasi database, dan seed demo.
- README berisi prasyarat versi, konfigurasi environment, perintah instalasi/jalankan/test/build yang sudah diverifikasi, serta URL backend untuk emulator.
- `.env.example`, `.gitignore`, dan dependency lockfile sesuai package manager.
- Dokumentasi API minimal untuk menjalankan demo; dokumentasi lengkap sebagai P1.
- Ringkasan pengujian beserta hasil nyata, asumsi, dan keterbatasan.
- Repository GitHub yang dapat diakses recruiter dan tautannya untuk pengumpulan.
- SRS ini sebagai acuan; screenshot/video merupakan pelengkap opsional.

### 14.2 Definition of Done

- [ ] Seluruh fitur P0 berjalan end-to-end.
- [ ] Ketiga tambahan yang disetujui terimplementasi.
- [ ] CRUD dengan hapus bersyarat, stok awal melalui UI, dan kartu stok versi 1.1 berjalan dan diuji.
- [ ] Seluruh saldo, termasuk seed, dapat direkonsiliasi dengan pergerakan serta dokumen sumber.
- [ ] Semua pengujian P0 yang relevan lulus, terutama rollback dan konkurensi.
- [ ] Tidak ada stok negatif, perubahan parsial, atau duplikasi transaksi pada skenario uji.
- [ ] UI memiliki validasi dan state loading/error/empty yang memadai.
- [ ] Build Android telah dicoba dan hasilnya dicatat; aplikasi didemokan pada target Android bila berhasil.
- [ ] README, schema, seed, dan konfigurasi contoh konsisten dengan implementasi.
- [ ] Tidak ada rahasia, output build besar yang tidak diperlukan, atau database pribadi dalam repository.
- [ ] Keterbatasan autentikasi, koreksi transaksi, dan stok awal sekali sebelum pergerakan pertama dinyatakan jelas.
- [ ] Source code dipush dengan persetujuan dan akses repository diverifikasi.

## 15. Skenario demonstrasi dan risiko

### 15.1 Demo utama

1. Tampilkan stok Utama dan Cabang.
2. Buat mutasi Profil Kusen UPVC Putih 6 Meter sebanyak 5 batang, Engsel Jendela UPVC 10 pcs, dan Handle Jendela UPVC Putih 2 pcs.
3. Tinjau perubahan masing-masing stok di pratinjau.
4. Konfirmasi dan tunjukkan nomor serta detail bukti transaksi.
5. Buka kembali stok dan riwayat.
6. Buat mutasi multi-item dengan satu jumlah melebihi stok.
7. Tunjukkan penolakan dan bahwa semua stok tetap utuh.
8. Jelaskan singkat transaksi database, perlindungan request ganda, dan batas lingkup.

Demo pelengkap versi 1.1: buat barang baru, catat stok awal melalui UI, buka kartu stok, pindahkan sebagian ke gudang lain, dan tunjukkan sisi keluar/masuk. Tunjukkan bahwa stok awal tidak dapat diulang serta master berhistori tidak bisa dihapus. Master baru yang belum digunakan dapat dihapus.

### 15.2 Risiko dan mitigasi

| Risiko | Mitigasi |
|---|---|
| Prioritas tidak terjaga | Selesaikan irisan end-to-end P0; fitur P1/P2 tidak boleh mengurangi pengujian inti |
| Toolchain Android belum dibuild | Uji proyek minimal/build pada awal implementasi; tidak menunggu UI selesai |
| MySQL server belum terverifikasi | Uji koneksi dan transaksi sebelum mengembangkan fitur stok |
| Request timeout menimbulkan hasil ambigu | Key yang sama untuk retry, serta riwayat sebagai sarana pengecekan |
| Cakupan melebar ke proses lain | Stok awal hanya inisialisasi; mutasi menjaga total per barang; tidak menambah penerimaan eksternal atau proses rework |
| Reviewer sulit menjalankan | Seed deterministik, README teruji, konfigurasi emulator, dan contoh request |
| Solusi sulit dijelaskan kandidat | Struktur proporsional, alasan keputusan terdokumentasi, dan walkthrough alur kritis |

## 16. Pengendalian perubahan

Perubahan yang menambah modul, mengubah rumus stok, menambah workflow, atau menggeser prioritas harus dicatat dengan alasan dan dampaknya terhadap lingkup dan pengujian. Temuan implementasi boleh menyederhanakan P1/P2, tetapi tidak diam-diam menghapus kebutuhan tes atau tiga fitur yang sudah disetujui. Dokumen ini tidak mengotorisasi deployment publik, perubahan kredensial, commit, push, atau tindakan pengumpulan atas nama kandidat. Implementasi dibagi menjadi tahap backend lalu frontend Flutter setelah tahap SRS dan perancangan, mengikuti arahan pengguna.

### Riwayat revisi

| Versi | Perubahan | Dampak prioritas |
|---|---|---|
| 1.0 | Baseline mutasi multi-item, pratinjau, bukti transaksi, dan seed saldo awal | Lingkup awal |
| 1.1 | CRUD hapus bersyarat, stok awal melalui UI, kartu stok, penulisan atomik pergerakan, API dan pengujian terkait | Tambahan P0; prioritaskan di atas dashboard, kategori alasan, dan penyempurnaan visual opsional. Membutuhkan tabel, endpoint, layar, serta pengujian tambahan; bukan perubahan UI saja |
| 1.2 | Adaptasi perusahaan UPVC: profil utuh dalam batang, aksesori dalam pcs, SKU spesifik, data demo dan skenario konsisten; kebutuhan verifikasi environment dan kendali perubahan | Tidak mengubah prioritas atau fitur versi 1.1; pemotongan, produksi, dan konversi satuan tetap di luar lingkup |