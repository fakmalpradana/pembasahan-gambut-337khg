# Desain Database — Pembasahan Gambut 337 KHG

PostgreSQL 17 + PostGIS 3.5. Semua geometri disimpan dalam **EPSG:4326** (lon/lat). Database: `gambut`.

## 1. Arsitektur
```mermaid
flowchart LR
  subgraph Sumber
    S1[Sekat Kanal BRGM<br/>5 shapefile]
    S2[GDB BlueBook PEG 2026<br/>7 layer]
    S3[Burnscar 2015-2026]
    S4[Hotspot Jan-Sep 2026]
  end
  S1 -->|build_gpkg.py| G1[(sekat_kanal.gpkg)]
  S4 -->|build_hotspot.py| G2[(hotspot_2026.gpkg)]
  G1 & G2 & S2 & S3 -->|stage.sh ogr2ogr| ST[staging]
  ST -->|04-08 *.sql| DB[(PostGIS: ref · peta · analisis · alur · api)]
  DB --- QGIS[QGIS editor<br/>koneksi PostGIS langsung]
  DB --- PY[pygeoapi<br/>OGC API Features/Tiles/Processes]
  PY --- CAD[Caddy<br/>GET publik · tulis Basic Auth]
  CAD --- APP[Web UI · QGIS · ArcGIS · Python · JS]
```

## 2. Lima schema
| Schema | Fungsi | Contoh tabel | Siapa yang menulis |
|---|---|---|---|
| `ref` | Referensi: wilayah (kode Kemendagri), KHG, perusahaan, tabel lookup | `provinsi`, `kabupaten`, `kecamatan`, `desa`, `khg`, `perusahaan`, `status_*` | loader / admin |
| `peta` | Layer operasional yang tampil di Workspace Peta; sebagian bisa diedit | `sekat`, `kanal`, `pompa`, `pintu_air`, `hotspot`, `areal_terbakar`, `konsesi`, `ketebalan_gambut`, `sumur_bor` | QGIS, Web, OGC API, loader |
| `analisis` | Layer analisis besar, baca-saja | `unit_nasional` (989 rb), `unit_target_2026` (789 rb), `kontur`, `kontur_lidar` | loader |
| `alur` | Alur kerja & audit: versi KHG, log perubahan, komentar, ekspor poster | `khg_versi`, `perubahan`, `komentar`, `ekspor_poster` | trigger & fungsi |
| `api` | View publik untuk OGC API (nama terbaca, bukan ID asing) + statistik materialized | `khg`, `sekat`, `hotspot`, `khg_statistik` | — (view) |

## 3. ERD
### 3a. Referensi & layer operasional
```mermaid
erDiagram
  provinsi ||--o{ kabupaten : ""
  kabupaten ||--o{ kecamatan : ""
  kecamatan ||--o{ desa : ""
  provinsi ||--o{ khg : "provinsi_utama_id"
  khg ||--o{ sekat : khg_id
  khg ||--o{ kanal : khg_id
  khg ||--o{ pompa : khg_id
  khg ||--o{ pintu_air : khg_id
  khg ||--o{ sungai : khg_id
  khg ||--o{ hotspot : khg_id
  khg ||--o{ areal_terbakar : khg_id
  khg ||--o{ ketebalan_gambut : khg_id
  khg ||--o{ sumur_bor : khg_id
  khg ||--o{ logger_tmat : khg_id
  khg ||--o{ posko_karhutla : khg_id
  kanal ||--o{ sekat : kanal_id
  kanal ||--o{ pompa : "kanal target"
  sungai ||--o{ pompa : "sumber air"
  sekat ||--o| sekat_konteks : "overlay BRGM (rencana)"
  sekat ||--o| sekat_bangunan : "detail bangunan (existing)"
  desa ||--o{ sekat_konteks : desa_id
  perusahaan ||--o{ sekat_konteks : ""
  perusahaan ||--o{ sekat_bangunan : ""
  perusahaan ||--o{ konsesi : ""
  perusahaan ||--o{ pintu_air : ""
  desa ||--o{ sumur_bor : ""
  sumur_bor ||--o{ sumur_debit : "harian"
  logger_tmat ||--o{ tmat_bacaan : "time series"
  jenis_kanal ||--o{ kanal : ""
  status_kanal ||--o{ kanal : ""
  status_sekat ||--o{ sekat : ""
  status_pompa ||--o{ pompa : ""
  kondisi_sumur ||--o{ sumur_bor : ""

  khg {
    int id PK
    text kode UK "KHG.14.12 (belum ada)"
    text nama UK
    smallint provinsi_utama_id FK
    bool target_2026
    numeric luas_ha
    geometry geom "MultiPolygon"
  }
  sekat {
    bigint id PK
    text kode "SK-n unik per KHG"
    text status FK "rencana/existing/rusak/dibongkar"
    bigint kanal_id FK
    bigint id_kontur_asal
    smallint jenis_kanal FK
    numeric elevasi_kontur_m
    text sumber "BRGM_PPEG_2026 / BRGM_PPEG / PERUSAHAAN"
    text qc_flag
    geometry geom "Point"
  }
  kanal {
    bigint id PK
    text kode "K-n"
    smallint jenis_kanal FK
    text status FK "NULL = belum disurvei"
    numeric panjang_m "generated, geodesik"
    text sumber "OSM_2025"
    geometry geom "MultiLineString"
  }
  pompa {
    bigint id PK
    text kode "P-n"
    text status FK
    numeric kapasitas_m3_menit
    bigint sungai_id FK
    bigint kanal_id FK
    numeric skor "0-1 + 4 sub-skor"
    geometry geom "Point"
  }
  hotspot {
    bigint id PK
    timestamptz waktu
    text satelit
    text instrumen "MODIS/VIIRS"
    text kepercayaan "tinggi/sedang/rendah"
    numeric frp_mw
    geometry geom "Point"
  }
  areal_terbakar {
    bigint id PK
    smallint_arr tahun_terbakar
    smallint frekuensi "generated"
    geometry geom "MultiPolygon"
  }
```
Semua tabel spasial `peta.*` juga punya kolom meta: `khg_id`, `created_at/by`, `updated_at/by`, `updated_via` (`qgis|web|api|sync|import`), dan `rev` (nomor revisi untuk optimistic lock).

### 3b. Alur kerja & audit
```mermaid
erDiagram
  khg ||--o{ khg_versi : "v1, v2, ..."
  status_alur ||--o{ khg_versi : ""
  khg_versi ||--o{ perubahan : "diff per versi"
  khg_versi ||--o{ komentar : ""
  komentar ||--o{ komentar : "balasan"
  khg_versi ||--o{ ekspor_poster : ""
  template_poster ||--o{ ekspor_poster : ""

  khg_versi {
    bigint id PK
    int khg_id FK
    int nomor "unik per KHG"
    text status "draft/review/revisi/approved/printed"
    text diajukan_oleh
    text reviewer
    text catatan_reviewer
    jsonb validasi "snapshot validasi_khg"
  }
  perubahan {
    bigint id PK
    timestamptz waktu
    text tabel
    bigint fitur_id
    bigint versi_id FK
    char aksi "I/U/D"
    text via "qgis/web/api"
    text pengguna
    jsonb data_lama
    jsonb data_baru
  }
  ekspor_poster {
    bigint id PK
    bigint versi_id FK
    int template_id FK
    uuid batch_id
    text kertas "A0-A3"
    text status "menunggu/merender/selesai/gagal"
    smallint progres
    bigint ukuran_bytes
  }
```

### 3c. Analisis (baca-saja)
```mermaid
erDiagram
  khg ||--o{ unit_nasional : ""
  khg ||--o{ unit_target_2026 : ""
  desa ||--o{ unit_nasional : ""
  desa ||--o{ unit_target_2026 : ""
  perusahaan ||--o{ unit_nasional : ""
  khg ||--o{ kontur : ""
  khg ||--o{ kontur_lidar : ""
  unit_nasional {
    bigint id PK
    int khg_id FK
    int desa_id FK
    int perusahaan_id FK
    text fungsi_kawasan FK
    text penutupan_lahan_2022 FK
    text kerusakan_eg_2024 FK
    text tebal_gambut_kelas
    smallint_arr tahun_terbakar
    text prioritas_intervensi
    numeric luas_ha
    geometry geom "MultiPolygon"
  }
```
`unit_target_2026` memakai struktur yang identik (`CREATE TABLE … (LIKE unit_target_2026 INCLUDING ALL)`).

## 4. Keputusan desain (dan alasannya)
| Keputusan | Alasan |
|---|---|
| **Audit & versi lewat trigger DB** (`a_meta` BEFORE, `b_kode` BEFORE INSERT, `z_audit` AFTER) | Editor QGIS menulis langsung ke PostGIS. Kalau pencatatan dilakukan di aplikasi, edit dari QGIS tidak tercatat. Fungsi trigger bersifat `SECURITY DEFINER`, jadi editor tidak bisa memalsukan log. |
| **Identitas penulis**: `app.pengguna`/`app.via` untuk Web; `session_user` + default role (`ALTER ROLE … SET app.via`) untuk QGIS/API | Satu mekanisme untuk tiga jenis klien tanpa kolom tambahan di tabel data. |
| **Versi terbuka otomatis** (satu draft/review/revisi per KHG; kalau KHG sudah approved lalu diedit, versi n+1 dibuat) | Sesuai UI "v13 → v14" dan tab Riwayat Versi. |
| **Tabel lookup, bukan ENUM** | Langsung bisa dipakai widget *Value Relation* QGIS dan dropdown Web; menambah nilai cukup dengan INSERT. |
| **`sekat` ramping + `sekat_konteks` + `sekat_bangunan` (1:1)** | Layer yang paling sering diedit dan dirender tetap ringan. Konteks overlay (rencana) dan detail bangunan (existing) punya atribut yang sangat berbeda. |
| **Batas KHG, konsesi, dan ketebalan gambut diturunkan dari unit analisis** (`ST_CoverageUnion` dengan fallback `ST_Union`) | Tidak ada layer batas resmi di data sumber; unit analisis nasional membentuk coverage lengkap untuk 866 KHG. |
| **`khg_id` pada layer non-unit diisi secara spasial** (titik wakil ∩ KHG yang dipecah dengan `ST_Subdivide`) | Nama KHG di sumber tidak konsisten. Subdivide mempercepat point-in-polygon ±100×. |
| **Relasi sekat → kanal secara spasial** (toleransi ±2 m untuk rencana, ±30 m untuk existing) | Kolom `Id` di data sekat ternyata ID kontur, bukan ID kanal. |
| **Schema `api` terpisah** (view + materialized `khg_statistik`) | Kontrak publik OGC API stabil walaupun tabel internal berubah. Statistik yang mahal dihitung tidak dijalankan di setiap request. |
| **PK `bigint identity`, satu kolom geometri bertipe tetap, index GIST** | Syarat editing yang mulus di QGIS dan pygeoapi. |

## 5. Trigger & fungsi
| Objek | Jenis | Kegunaan |
|---|---|---|
| `alur.isi_meta()` | BEFORE I/U semua `peta.*` | Mengisi `khg_id` dari geometri, `created_*`/`updated_*`/`updated_via`, dan menaikkan `rev` |
| `alur.isi_kode('P'/'SK'/'K')` | BEFORE INSERT pompa/sekat/kanal | Kode otomatis per KHG |
| `alur.catat_perubahan()` | AFTER I/U/D layer perencanaan | Menulis log ke `alur.perubahan` + versi terbuka. UPDATE tanpa perubahan diabaikan |
| `alur.versi_terbuka(khg)` | fungsi | Mengambil atau membuat versi draft (dengan advisory lock) |
| `alur.validasi_khg(versi, jarak)` | fungsi | 5 aturan "Validasi otomatis" |
| `alur.ajukan_review(versi)` / `alur.putuskan(versi, keputusan, catatan)` | fungsi | Transisi alur kerja |
| `alur.tandai_dicetak()` | trigger `ekspor_poster` | Kalau ekspor selesai: approved → printed |
| `peta.saran_lokasi_pompa(khg, …)` | fungsi | Kandidat lokasi pompa + skor |
| `api.refresh_statistik()` | fungsi | Refresh `api.khg_statistik` |

## 6. Katalog tabel
Lihat [01b_KATALOG_TABEL.md](01b_KATALOG_TABEL.md). File ini dibuat otomatis dari DB dan berisi jumlah baris, ukuran, dan deskripsi setiap tabel.
