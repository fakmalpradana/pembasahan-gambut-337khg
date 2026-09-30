# Kecocokan UI (`Pembasahan Gambut 337 KHG · Screens v1.png`) dengan Data

> File mockup UI tidak disertakan di repo; minta ke pemilik repo. Delapan layarnya: Dashboard Nasional, Daftar KHG, Workspace Peta (panel layer, detail pompa, mode tambah pompa), Review & Approval, Ekspor Poster, dan Monitoring Sumur Bor.

Legenda status:
- ✅ **Ada**: datanya sudah ada di DB dan bisa langsung ditampilkan.
- 🟡 **Sebagian**: struktur tabel/fungsi sudah siap dan datanya sebagian ada, atau angkanya berupa turunan/pendekatan.
- ❌ **Belum ada data**: tabel, API, dan CRUD sudah siap, tapi belum ada data sumbernya.

Sumber data yang sudah dimuat:
- **[S1]** Sekat Kanal BRGM PPEG (5 shapefile)
- **[S2]** Geodatabase *Target BlueBook PEG 2026* (7 layer)
- **[S3]** Burnscar Areas 2015–2026
- **[S4]** Hotspot Jan–Sep 2026

## Ringkasan
| Kategori | ✅ Ada | 🟡 Sebagian | ❌ Belum ada data | ➖ Di luar DB |
|---|---|---|---|---|
| Elemen UI (total 68 baris di bawah) | 38 | 12 | 16 | 2 |

Ada empat celah data utama. Masing-masing memengaruhi beberapa layar:
1. **Sungai (sumber air)** → jarak pompa ke air, saran lokasi pompa, validasi "pompa ≤ 500 m dari sumber air".
2. **Status kanal aktif/tidak aktif (hasil survei)** → "Kanal aktif km", legenda kanal, saran lokasi pompa.
3. **Pompa, logger TMAT, posko karhutla, sumur bor** → belum ada datanya sama sekali.
4. **Kode KHG resmi** (`KHG.14.12`) → kolom Kode di Daftar KHG masih kosong.

---

## 1. Dashboard Nasional
| Elemen UI | Sumber di DB / API | Data dari | Status | Catatan |
|---|---|---|---|---|
| Filter Periode / Provinsi | `api.khg.provinsi`, `peta.hotspot.waktu` | S2, S4 | ✅ | 38 provinsi di `ref.provinsi`, data mencakup 23 provinsi |
| KPI "KHG disetujui 128 / 337" | `alur.v_dashboard.khg_disetujui` / `khg_total` | — | 🟡 | Strukturnya siap. Saat ini semua KHG masih **draft v1**. Total yang tercatat 866 KHG, dengan **345 KHG target 2026** (`ref.khg.target_2026`); angka inilah padanan "337" di UI |
| KPI "Titik pompa direncanakan" | `peta.pompa` | — | ❌ | Tabel kosong; diisi lewat Workspace/QGIS/API |
| KPI "Kanal aktif 3.214 km dari 5.870 km" | `peta.kanal.panjang_m`, `status` | S2 (kanal OSM) | 🟡 | Panjang total sudah ada (**±362.700 km**, 657.621 segmen). Status aktif belum ada karena perlu survei |
| KPI "Hotspot 30 hari" | `alur.v_dashboard.hotspot_30h`, `api.khg.hotspot_30h` | S4 | ✅ | Data sampai 15 Sep 2026. Sumbernya **tidak seragam antar-bulan** (lihat catatan hotspot di bawah) |
| KPI "Alert TMAT > 0,4 m" | `peta.v_tmat_alert` | — | ❌ | Belum ada logger maupun bacaan TMAT |
| Peta Sebaran 337 KHG + tooltip (luas, status, hotspot, pompa) | koleksi OGC `khg` (+ tiles) | S2 (dissolve) | ✅ | Batas KHG = hasil dissolve 989 ribu unit analisis nasional |
| Status Alur Kerja (Printed/Approved/Review/Draft) | `alur.v_dashboard.status_alur` | — | 🟡 | Struktur siap; semua masih draft |
| Prioritas Tinggi (skor) | `api.khg.skor_prioritas` | S2, S4 | 🟡 | Rumusnya sementara: 0,4 × porsi luas pernah terbakar + 0,3 × porsi gambut ≥ 3 m + 0,3 × hotspot relatif. Perlu disesuaikan dengan SOP |
| Tombol "Ekspor Ringkasan" | proses `ringkasan-dashboard` | — | ✅ | Menghasilkan JSON; pembuatan PDF dilakukan di aplikasi |

## 2. Daftar KHG
| Elemen UI | Sumber | Data | Status | Catatan |
|---|---|---|---|---|
| Kode (`KHG.14.03`) | `ref.khg.kode` | — | ❌ | Tidak ada di sumber mana pun. Perlu daftar kode resmi (SK KHG) |
| Nama KHG | `ref.khg.nama` | S2 | ✅ | 866 KHG |
| Provinsi | `api.khg.provinsi_singkat` | S2 | ✅ | Provinsi dengan porsi luas terbesar |
| Luas (ha) | `ref.khg.luas_ha` | S2 | ✅ | Dihitung dari geometri hasil dissolve (geodesik) |
| Hotspot 30h | `api.khg.hotspot_30h` | S4 | ✅ | Dihitung relatif terhadap tanggal hotspot terakhir; diperbarui lewat `refresh-statistik` |
| Pompa | `api.khg.pompa` | — | ❌ | 0 |
| Kanal aktif (km) | `api.khg.kanal_aktif_km` | S2 | 🟡 | Menunggu status survei; total km sudah ada di `kanal_km` |
| Status | `api.khg.status` | — | 🟡 | Semua draft |
| Terakhir diubah + via (QGIS/Web) | `alur.perubahan` (waktu, via) | — | ✅ | Terisi otomatis oleh trigger begitu ada edit |
| Filter Provinsi / Status / Prioritas / Diubah via | parameter query koleksi `khg` | — | ✅ | Contoh: `?provinsi_singkat=Riau&status=draft` |
| Pencarian nama/kode/kabupaten | `?q=` atau CQL `nama LIKE '%Kampar%'` | — | ✅ | |
| Pilih banyak → Ekspor A3/A0, Kirim ke Review | `alur.ekspor_poster`, proses `ajukan-review` | — | ✅ | |
| Impor Data | `ogr2ogr` ke PostGIS / `POST` OGC API | — | ✅ | |

## 3. Workspace Peta — panel Layer
| Layer di UI | Tabel / koleksi | Data | Jumlah | Status |
|---|---|---|---|---|
| Sungai (sumber air) | `peta.sungai` / `sungai` | — | 0 | ❌ Perlu layer sungai (misalnya RBI 1:50K atau OSM waterways) |
| Kanal aktif / Kanal tidak aktif | `peta.kanal` / `kanal` | S2 | 657.621 | 🟡 Geometri ada, status belum ada |
| Pompa air (rencana) | `peta.pompa` / `pompa` | — | 0 | ❌ |
| Pintu air | `peta.pintu_air` / `pintu-air` | S2 | 48 | ✅ |
| Sekat kanal (existing) | `peta.sekat` status `existing` / `sekat` | S2 | 46.204 | ✅ Sekat BRGM (8.512 titik) + sekat perusahaan (37.692, REALISASI) |
| Sekat kanal (rencana) | `peta.sekat` status `rencana` | S1 + S2 | 320.167 | ✅ 319.458 hasil potong kontur × kanal + 709 rencana perusahaan. 99,85% tertaut ke kanal OSM dengan panjang cocok |
| Sumur bor | `peta.sumur_bor` / `sumur-bor` | — | 0 | ❌ |
| Hotspot Jan–Sep 2026 | `peta.hotspot` / `hotspot` | S4 | 167.718 | ✅ |
| Areal terbakar 2015–2025 | `peta.areal_terbakar` / `areal-terbakar` | S3 | 584.723 | ✅ Tersedia 2015–**2026** |
| Ketebalan gambut | `peta.ketebalan_gambut` / `ketebalan-gambut` | S2 | 2.938 | ✅ Dissolve dari unit analisis |
| Logger AP-TMAT | `peta.logger_tmat` | — | 0 | ❌ |
| Posko Karhutla | `peta.posko_karhutla` | — | 0 | ❌ |
| Konsesi PBPH / HGU | `peta.konsesi` / `konsesi` | S2 | 1.070 | 🟡 Dari atribut unit analisis. Jenis HGU tidak dibedakan (tercatat sebagai "Perkebunan Kelapa Sawit") |
| Batas KHG | `ref.khg.geom` / `khg` | S2 | 866 | ✅ |
| Basemap Citra Sentinel-2 | layanan tile eksternal | — | — | ➖ Tidak disimpan di DB |
| Tambahan: kontur, kontur LiDAR 50 cm, unit analisis | `analisis.*` / `kontur`, `kontur-lidar`, `unit-*` | S2 | 159 rb / 27 rb / 1,78 jt | ✅ Tidak ada di UI, tapi berguna untuk analisis |

## 4. Workspace Peta — detail Pompa, Mode Tambah Pompa, Kanal
| Elemen | Sumber | Status | Catatan |
|---|---|---|---|
| Atribut Pompa (kode, kapasitas, sumber air, kanal target) | `peta.pompa` | ❌ | Tabel siap; kode `P-n` dibuat otomatis |
| Jarak ke sungai | `peta.pompa.jarak_sungai_m` | ❌ | Butuh data sungai |
| Tebal gambut | `peta.ketebalan_gambut` | ✅ | |
| Hotspot radius 2 km | `ST_DWithin` terhadap `peta.hotspot` | ✅ | |
| Estimasi luas layanan | `peta.pompa.estimasi_layanan_ha` | ❌ | Butuh model hidrologi; kolom sudah disediakan |
| Skor kesesuaian + 4 sub-skor | proses `saran-lokasi-pompa`, kolom `skor_*` | 🟡 | Fungsi siap; hasilnya kosong sampai ada data sungai + kanal berstatus aktif |
| Komentar review | `alur.komentar` | ✅ | Struktur siap |
| Tombol Hapus / Pindahkan / Simpan | `DELETE` / `PUT` OGC API, atau edit QGIS | ✅ | Setiap perubahan tercatat di `alur.perubahan` |
| Mode Tambah Pompa: parameter & Saran Lokasi (S1–S3) | proses `saran-lokasi-pompa` | 🟡 | Sama dengan skor kesesuaian di atas |
| "Perubahan belum disimpan" | buffer di client | ➖ | Disimpan dalam 1 transaksi |
| Popup Kanal: Aktif / Tidak aktif, "Sebelumnya: …" | `peta.kanal.status` + `alur.perubahan.data_lama` | 🟡 | Riwayat ✅, status awal ❌ |
| "Tersinkron PostGIS · 2 editor QGIS aktif" | `pg_stat_activity` (application_name QGIS) | ✅ | Bisa dibaca oleh role admin |
| Riwayat Versi | `alur.khg_versi` + `alur.perubahan` | ✅ | |
| Pratinjau Poster / Kirim ke Review | `alur.ekspor_poster` / proses `ajukan-review` | ✅ | |

## 5. Review & Approval
| Elemen | Sumber | Status |
|---|---|---|
| Tab Menunggu / Revisi / Selesai | `alur.khg_versi.status` | ✅ |
| Daftar KHG (v14 · pengaju · via) | `alur.khg_versi` + `alur.perubahan` | ✅ |
| Peta diff (Ditambah/Diubah/Status/Dihapus) | `alur.perubahan` (aksi I/U/D, `data_lama`/`data_baru` GeoJSON) | ✅ |
| Daftar Perubahan (5) + via + pengguna | `alur.perubahan WHERE versi_id = …` | ✅ |
| Komentar (4) | `alur.komentar` | ✅ |
| Validasi otomatis | proses `validasi-khg` / `alur.validasi_khg()` | 🟡 Aturan siap; hasil cek pompa-sungai baru bermakna setelah ada data sungai |
| Catatan reviewer, Minta Revisi, Setujui & Siapkan Poster | proses `putuskan-review` | ✅ |

## 6. Ekspor Poster
| Elemen | Sumber | Status | Catatan |
|---|---|---|---|
| KHG, Template, Ukuran kertas, Orientasi, Periode hotspot | `alur.ekspor_poster`, `alur.template_poster` | ✅ | |
| Info "Data v14 · disetujui D. Putri · 300 dpi" | `alur.khg_versi` + `ekspor_poster.dpi` | ✅ | |
| Antrian Ekspor Batch (progres, ukuran, unduh) | `alur.ekspor_poster` (status, progres, ukuran_bytes, file_path) | ✅ | Tabelnya siap. **Worker QGIS Atlas yang merender poster belum dibuat** |
| Legenda poster (sumber data) | koleksi OGC terkait | ✅ | |

## 7. Monitoring Sumur Bor
| Elemen | Sumber | Status |
|---|---|---|
| KPI total/berfungsi/perlu perbaikan/belum verifikasi/debit rata-rata | `peta.v_sumur_bor`, `peta.sumur_debit` | ❌ Belum ada data (modul integrasi Fase 4) |
| Peta sumur + tabel + detail (kedalaman, debit, pompa terdekat, penanggung jawab) | `peta.sumur_bor`, `ST_Distance` ke `peta.pompa` | ❌ |
| Grafik debit 30 hari | `peta.sumur_debit` | ❌ |
| Sinkron Sekarang | kolom `ext_id`/`synced_at` + upsert | ❌ Konektor ke sistem Sumur Bor belum dibuat |

---

## Catatan kualitas data yang memengaruhi UI
- **Hotspot tidak konsisten antar-bulan.** Jan, Apr, Agu, dan Sep hanya berisi MODIS (FIRMS). Feb, Mar, Mei, Jun, dan Jul berisi MODIS + VIIRS (SiPongi), dan VIIRS menghasilkan jauh lebih banyak titik. Akibatnya, tren bulanan dan KPI "18% vs bulan lalu" **bias**. Saran: tarik ulang semua bulan dari satu sumber, atau filter `instrumen = 'MODIS'` bila ingin membandingkan antar-bulan.
- **Data hotspot September baru sampai tanggal 15.**
- **Kolom `Id` di data sekat BRGM adalah ID garis kontur**, bukan ID kanal. Relasi sekat → kanal dibangun secara spasial (`sekat.kanal_id`).
- **Konsesi dan ketebalan gambut** adalah hasil dissolve dari unit analisis, bukan poligon izin resmi. Batasnya akurat sebatas cakupan analisis PPEG.
- **Nama KHG di layer infrastruktur tidak konsisten** (ejaan berbeda, 38 ribu kosong). KHG-nya ditentukan ulang secara spasial; nama aslinya disimpan di `sekat_bangunan.khg_nama_asal`.
