# Panduan Penggunaan Database & Kredensial

> Password asli **tidak ditulis di dokumen ini**. Semua password ada di `db/.env`, yang dibuat otomatis oleh `db/setup.sh`. Salinan lengkap yang siap dibagikan ke tim ada di [`KREDENSIAL.md`](KREDENSIAL.md), dibuat oleh `db/kredensial.sh`. Kedua file itu **rahasia**: jangan di-commit, jangan dikirim lewat chat publik.

## 1. Koneksi
| Parameter | Lokal (Docker) | Produksi (lihat 05_RENCANA_DEPLOY.md) |
|---|---|---|
| Host | `localhost` | `db.<domain>` (hanya lewat VPN/SSH tunnel/IP whitelist) |
| Port | `5433` | `5432` |
| Database | `gambut` | `gambut` |
| SSL | tidak | `sslmode=require` |
| OGC API | `http://localhost:8080` | `https://api.<domain>` |

String koneksi:
```
postgresql://<role>:<password>@localhost:5433/gambut
```

## 2. Role & hak akses
| Role | Login | Untuk siapa | Hak | `app.via` default |
|---|---|---|---|---|
| `postgres` | ✅ | DBA / migrasi | superuser | — |
| `gambut_baca` | ❌ (grup) | — | SELECT schema `ref`, `peta`, `analisis`, `api` + view alur publik | — |
| `gambut_edit` | ❌ (grup) | — | `gambut_baca` + INSERT/UPDATE/DELETE layer perencanaan, komentar, ekspor poster | — |
| `ogc_reader` | ✅ | pygeoapi (koleksi baca) | `gambut_baca`, read-only, timeout 30 detik, maks. 20 koneksi | — |
| `ogc_writer` | ✅ | pygeoapi (koleksi edit + proses tulis) | `gambut_edit` + `ajukan_review`/`putuskan`, maks. 10 koneksi | `api` |
| `web_app` | ✅ | backend aplikasi web | `gambut_edit` + fungsi alur kerja, maks. 20 koneksi | diset per transaksi |
| `editor_qgis` | ✅ | contoh akun editor QGIS | `gambut_edit` | `qgis` |

**Menambah editor QGIS baru.** Satu orang satu role, supaya namanya tercatat di log perubahan:
```sql
CREATE ROLE r_siregar LOGIN PASSWORD '...' IN ROLE gambut_edit;
ALTER ROLE r_siregar SET app.via = 'qgis';
INSERT INTO alur.pengguna (username, nama, instansi, peran) VALUES ('r_siregar', 'R. Siregar', 'Dit. PPEG', 'analis');
```

## 3. Koneksi dari QGIS
**A. PostGIS langsung (untuk mengedit)**
1. Buka *Layer → Data Source Manager → PostgreSQL → New*.
2. Isi Name `Gambut`, Host `localhost`, Port `5433`, Database `gambut`, lalu tab *Basic* dengan user `editor_qgis`/role pribadi dan password.
3. Centang *Also list tables with no geometry* (untuk `tmat_bacaan`, `sumur_debit`).
4. Tambahkan layer:
   - Untuk diedit: `peta.sekat`, `peta.kanal`, `peta.pompa`, `peta.pintu_air`, dan seterusnya.
   - Untuk dilihat dan distyling: `api.sekat`, `api.khg`, `api.hotspot`.
5. Untuk dropdown atribut, atur *Layer Properties → Attributes Form → Value Relation*. Contoh: kolom `status` di `peta.kanal` diambil dari `ref.status_kanal` (key `kode`, value `label`).
6. Kolom `kode`, `khg_id`, `created_*`, `updated_*`, dan `rev` terisi otomatis. Biarkan kosong.

**B. OGC API Features (tanpa kredensial DB, termasuk mengedit)**
1. Buka *Layer → Data Source Manager → WFS / OGC API - Features → New*.
2. Isi URL `http://localhost:8080`, lalu pilih versi **OGC API - Features**.
3. Untuk mengedit koleksi `sekat-edit`, `kanal`, `pompa`, dan sebagainya: isi *Authentication → Basic* dengan user/password API (`API_ADMIN_USER`/`API_ADMIN_PASSWORD`).

**C. Vector tiles (cepat untuk layer besar)**
1. Buka *Layer → Data Source Manager → Vector Tile → New → Generic*.
2. Isi URL `http://localhost:8080/collections/kanal/tiles/WebMercatorQuad/{z}/{y}/{x}?f=mvt`, Min zoom `9`, Max zoom `17`.

## 4. Resep SQL yang sering dipakai
```sql
-- Web: identitas penulis di awal setiap transaksi
BEGIN;
SET LOCAL app.pengguna = 'd.putri';
SET LOCAL app.via = 'web';
INSERT INTO peta.pompa (kapasitas_m3_menit, geom)
VALUES (100, ST_SetSRID(ST_MakePoint(102.9118, 0.4712), 4326));   -- kode P-n & khg_id otomatis
COMMIT;

-- Optimistic lock (Web): gagal = 0 baris -> fitur sudah diubah orang lain
UPDATE peta.kanal SET status = 'aktif' WHERE id = 123 AND rev = 4;

-- Daftar KHG (layar Daftar KHG), urut prioritas
SELECT nama, provinsi_singkat, luas_ha, hotspot_30h, pompa, kanal_km, status, skor_prioritas
  FROM api.khg WHERE target_2026 ORDER BY skor_prioritas DESC LIMIT 20;

-- Diff satu versi (tab "Perubahan" di Review)
SELECT waktu, tabel, fitur_id, aksi, via, pengguna, data_lama->>'status' AS lama, data_baru->>'status' AS baru
  FROM alur.perubahan WHERE versi_id = 42 ORDER BY waktu;

-- Alur kerja
SELECT * FROM alur.validasi_khg(42);           -- panel "Validasi otomatis"
SELECT alur.ajukan_review(42);                 -- draft/revisi -> review (+ snapshot validasi)
SELECT alur.putuskan(42, 'approved', 'OK');    -- atau 'revisi'

-- Saran lokasi pompa (Mode: Tambah Pompa)
SELECT * FROM peta.saran_lokasi_pompa(p_khg => 12, p_maks_jarak => 500, p_min_tebal => 3, p_buffer_konsesi => 100);

-- Hotspot per bulan per instrumen (hati-hati: sumber tidak seragam antar-bulan)
SELECT date_trunc('month', waktu AT TIME ZONE 'Asia/Jakarta') bulan, instrumen, count(*)
  FROM peta.hotspot GROUP BY 1, 2 ORDER BY 1, 2;

-- Sekat existing per KHG beserta tahun bangun
SELECT k.nama, count(*), min(b.tahun_bangun), max(b.tahun_bangun)
  FROM peta.sekat s JOIN peta.sekat_bangunan b ON b.sekat_id = s.id JOIN ref.khg k ON k.id = s.khg_id
 GROUP BY 1 ORDER BY 2 DESC;

-- Editor QGIS yang sedang aktif ("2 editor QGIS aktif")
SELECT usename, application_name, backend_start FROM pg_stat_activity WHERE application_name ILIKE 'QGIS%';
```

## 5. Pemeliharaan
| Tugas | Perintah | Jadwal |
|---|---|---|
| Refresh statistik KHG (hotspot 30 hari, km kanal, jumlah sekat) | `SELECT api.refresh_statistik();` atau proses OGC `refresh-statistik` | harian (cron) + setelah impor hotspot |
| Backup logis | `pg_dump -Fc -d gambut -f gambut_$(date +%F).dump` | harian |
| Restore | `pg_restore -d gambut --clean --if-exists gambut_YYYY-MM-DD.dump` | saat dibutuhkan |
| Bangun ulang dari nol (semua sumber) | `./db/setup.sh` | saat data sumber berubah |
| Tambah hotspot bulan baru | taruh .shp di folder hotspot → `python3 scripts/build_hotspot.py` → muat ulang tabel `peta.hotspot` (lihat `06_load_bluebook.sql`) → refresh statistik | bulanan |
| VACUUM/ANALYZE | autovacuum aktif; manual `VACUUM ANALYZE` setelah impor besar | setelah impor |

## 6. Urutan file build
| File | Isi |
|---|---|
| `scripts/build_gpkg.py`, `scripts/build_hotspot.py` | Membersihkan sekat & hotspot menjadi GeoPackage |
| `db/01_schema.sql` | Schema, tabel, lookup, index |
| `db/02_trigger_fungsi.sql` | Trigger audit/meta/kode, validasi, alur kerja, saran pompa |
| `db/03_views.sql` | View UI internal (`alur.v_*`, `peta.v_*`) |
| `db/stage.sh` | ogr2ogr semua sumber ke schema `staging` (paralel) |
| `db/04_load_ref.sql` … `db/06_load_bluebook.sql` | Wilayah, perusahaan, lookup, KHG, sekat, unit analisis, kanal, infrastruktur, hotspot, areal terbakar, kontur |
| `db/07_dissolve_*.sql` | Batas KHG, konsesi, ketebalan gambut (paralel) |
| `db/08_finalisasi.sql` | khg_id spasial, kode, sekat→kanal, versi v1, QC |
| `db/09_roles.sql` | Role & hak akses |
| `db/10_api_views.sql` | Schema `api` untuk OGC API |
| `db/tests.sql` | Smoke test CRUD + audit + alur kerja (di-ROLLBACK) |
| `api/pygeoapi-config.yml`, `api/gambut_processes.py`, `api/Caddyfile` | Layanan OGC API |
