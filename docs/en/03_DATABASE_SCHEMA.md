# Introduction

This document is the reference for every table, view, column, constraint, index, trigger and function in the `gambut` database. It is generated from the live database catalogue (PostgreSQL 17.5, PostGIS 3.5.2, database size 6022 MB).

# Conventions

| Topic | Convention |
|---|---|
| Coordinate system | Every geometry is stored in EPSG:4326 (longitude, latitude). Distances in metres are computed on the geography type. |
| Primary keys | `bigint` or `int` identity column `id`, one geometry column per table, GiST index on every geometry. This keeps QGIS editing smooth. |
| Names | Indonesian domain names in snake case, matching the language of the analysts (see the DDD glossary). |
| Code lists | Small tables in `ref` referenced by foreign keys, not ENUM types. |
| Audit columns | Every `peta` layer has `khg_id`, `created_at`, `created_by`, `updated_at`, `updated_by`, `updated_via` (qgis, web, api, sync or import) and `rev` (optimistic lock counter). They are filled by triggers. |
| Codes | Human codes (`P-n`, `SK-n`, `K-n`) are unique per KHG and assigned by a trigger when empty. |
| Identity of the writer | `app.pengguna` and `app.via` session settings, falling back to the login role and its default channel. |

# Schemas

| Schema | Purpose | Tables | Views | Rows | Size |
|---|---|---:|---:|---:|---:|
| `ref` | Reference data and code lists | 15 | 0 | 9,131 | 71 MB |
| `peta` | Operational map layers, most of them editable | 16 | 4 | 2,146,860 | 1,269 MB |
| `analisis` | Large read-only analysis layers | 4 | 0 | 1,964,745 | 4,661 MB |
| `alur` | Plan versions, audit and poster exports | 6 | 3 | 866 | 0 MB |
| `api` | Public read model for the OGC API | 0 | 14 | 0 | 0 MB |

# Schema ref

Reference data and code lists.

## ref.desa

*table, 5,860 rows, 18.1 MB.* Village. The 2,004 target villages for 2026 carry a boundary polygon.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `integer identity` | no | primary key |
| `kecamatan_id` | `integer` | no | references `ref.kecamatan` |
| `nama` | `text` | no | - |
| `kode_bps` | `text` | yes | - |
| `target_pemulihan_2026` | `boolean` | no | default `false` |
| `geom` | `geometry(MultiPolygon,4326)` | yes | - |

Constraints:

- `UNIQUE (kecamatan_id, nama)`
- `UNIQUE (kode_bps)`

Indexes:

- `CREATE UNIQUE INDEX desa_kecamatan_id_nama_key USING btree (kecamatan_id, nama)`
- `CREATE UNIQUE INDEX desa_kode_bps_key USING btree (kode_bps)`
- `CREATE INDEX desa_geom_idx USING gist (geom)`

## ref.fungsi_kawasan

*table, 14 rows, 0.0 MB.* Code list: forest area function (for example HP, HL, APL).

| Column | Type | Null | Default or note |
|---|---|---|---|
| `kode` | `text` | no | primary key |
| `label` | `text` | no | - |

## ref.jenis_kanal

*table, 3 rows, 0.0 MB.* Code list: canal class (1 primary, 2 secondary, 3 tertiary).

| Column | Type | Null | Default or note |
|---|---|---|---|
| `kode` | `smallint` | no | primary key |
| `label` | `text` | no | - |

Constraints:

- `UNIQUE (label)`

Indexes:

- `CREATE UNIQUE INDEX jenis_kanal_label_key USING btree (label)`

## ref.kabupaten

*table, 142 rows, 0.0 MB.* Regency or city within a province.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `integer identity` | no | primary key |
| `provinsi_id` | `smallint` | no | references `ref.provinsi` |
| `nama` | `text` | no | - |

Constraints:

- `UNIQUE (provinsi_id, nama)`

Indexes:

- `CREATE UNIQUE INDEX kabupaten_provinsi_id_nama_key USING btree (provinsi_id, nama)`

## ref.kecamatan

*table, 892 rows, 0.2 MB.* District within a regency.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `integer identity` | no | primary key |
| `kabupaten_id` | `integer` | no | references `ref.kabupaten` |
| `nama` | `text` | no | - |

Constraints:

- `UNIQUE (kabupaten_id, nama)`

Indexes:

- `CREATE UNIQUE INDEX kecamatan_kabupaten_id_nama_key USING btree (kabupaten_id, nama)`

## ref.kerusakan_eg

*table, 5 rows, 0.0 MB.* Code list: peat ecosystem damage level 2024 with severity order.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `nama` | `text` | no | primary key |
| `urutan` | `smallint` | yes | - |

## ref.khg

*table, 866 rows, 52.5 MB.* Peat Hydrological Unit (KHG). Boundary dissolved from national analysis units.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `integer identity` | no | primary key |
| `kode` | `text` | yes | - |
| `nama` | `text` | no | - |
| `provinsi_utama_id` | `smallint` | no | references `ref.provinsi` |
| `target_2026` | `boolean` | no | default `false` |
| `luas_ha` | `numeric(12,2)` | yes | - |
| `geom` | `geometry(MultiPolygon,4326)` | yes | - |

Constraints:

- `UNIQUE (kode)`
- `UNIQUE (nama)`

Indexes:

- `CREATE UNIQUE INDEX khg_kode_key USING btree (kode)`
- `CREATE UNIQUE INDEX khg_nama_key USING btree (nama)`
- `CREATE INDEX khg_geom_idx USING gist (geom)`

## ref.kondisi_sumur

*table, 3 rows, 0.0 MB.* Code list: deep well condition (working, damaged, unverified).

| Column | Type | Null | Default or note |
|---|---|---|---|
| `kode` | `text` | no | primary key |
| `label` | `text` | no | - |
| `warna` | `text` | yes | - |

## ref.penutupan_lahan

*table, 26 rows, 0.0 MB.* Code list: land cover class 2022.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `nama` | `text` | no | primary key |

## ref.perusahaan

*table, 1,267 rows, 0.2 MB.* Company holding a plantation, forestry or mining permit.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `integer identity` | no | primary key |
| `nama` | `text` | no | - |
| `izin_usaha` | `text` | yes | - |

Constraints:

- `UNIQUE (nama)`

Indexes:

- `CREATE UNIQUE INDEX perusahaan_nama_key USING btree (nama)`

## ref.provinsi

*table, 38 rows, 0.0 MB.* Province (38 rows, official Ministry of Home Affairs codes as primary key).

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `smallint` | no | primary key |
| `nama` | `text` | no | - |
| `singkatan` | `text` | no | - |
| `pulau` | `text` | no | - |

Constraints:

- `UNIQUE (nama)`

Indexes:

- `CREATE UNIQUE INDEX provinsi_nama_key USING btree (nama)`

## ref.status_alur

*table, 5 rows, 0.0 MB.* Code list: plan version status with display order and colour.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `kode` | `text` | no | primary key |
| `label` | `text` | no | - |
| `urutan` | `smallint` | yes | - |
| `warna` | `text` | yes | - |

## ref.status_kanal

*table, 3 rows, 0.0 MB.* Code list: canal survey status (active, inactive, blocked).

| Column | Type | Null | Default or note |
|---|---|---|---|
| `kode` | `text` | no | primary key |
| `label` | `text` | no | - |
| `warna` | `text` | yes | - |

## ref.status_pompa

*table, 3 rows, 0.0 MB.* Code list: pump status (planned, installed, damaged).

| Column | Type | Null | Default or note |
|---|---|---|---|
| `kode` | `text` | no | primary key |
| `label` | `text` | no | - |
| `warna` | `text` | yes | - |

## ref.status_sekat

*table, 4 rows, 0.0 MB.* Code list: canal block status (planned, existing, damaged, removed).

| Column | Type | Null | Default or note |
|---|---|---|---|
| `kode` | `text` | no | primary key |
| `label` | `text` | no | - |
| `warna` | `text` | yes | - |

# Schema peta

Operational map layers, most of them editable.

## peta.areal_terbakar

*table, 584,723 rows, 564.0 MB.* Burned area polygon with the list of burn years 2015 to 2026.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint identity` | no | primary key |
| `tahun_terbakar` | `smallint[]` | no | - |
| `frekuensi` | `smallint generated` | yes | `cardinality(tahun_terbakar)` |
| `geom` | `geometry(MultiPolygon,4326)` | no | - |
| `khg_id` | `integer` | yes | references `ref.khg` |
| `created_at` | `timestamp with time zone` | no | default `now()` |
| `created_by` | `text` | yes | - |
| `updated_at` | `timestamp with time zone` | no | default `now()` |
| `updated_by` | `text` | yes | - |
| `updated_via` | `text` | yes | - |
| `rev` | `integer` | no | default `1` |

Constraints:

- `CHECK ((updated_via = ANY (ARRAY['qgis'::text, 'web'::text, 'api'::text, 'sync'::text, 'import'::text])))`

Indexes:

- `CREATE INDEX areal_terbakar_geom_idx USING gist (geom)`
- `CREATE INDEX areal_terbakar_khg_id_idx USING btree (khg_id)`
- `CREATE INDEX areal_terbakar_tahun_terbakar_idx USING gin (tahun_terbakar)`

Triggers:

- `a_meta`: `BEFORE INSERT OR UPDATE` executes `alur.isi_meta()`

## peta.hotspot

*table, 167,718 rows, 49.6 MB.* Satellite fire hotspot (MODIS or VIIRS), January to September 2026.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint identity` | no | primary key |
| `waktu` | `timestamp with time zone` | no | - |
| `satelit` | `text` | yes | - |
| `instrumen` | `text` | yes | - |
| `kepercayaan` | `text` | yes | - |
| `kepercayaan_nilai` | `smallint` | yes | - |
| `frp_mw` | `numeric(8,2)` | yes | - |
| `brightness_k` | `numeric(6,2)` | yes | - |
| `siang_malam` | `character(1)` | yes | - |
| `provinsi` | `text` | yes | - |
| `kabupaten` | `text` | yes | - |
| `kecamatan` | `text` | yes | - |
| `desa` | `text` | yes | - |
| `format_sumber` | `text` | no | - |
| `berkas_sumber` | `text` | yes | - |
| `geom` | `geometry(Point,4326)` | no | - |
| `khg_id` | `integer` | yes | references `ref.khg` |
| `created_at` | `timestamp with time zone` | no | default `now()` |
| `created_by` | `text` | yes | - |
| `updated_at` | `timestamp with time zone` | no | default `now()` |
| `updated_by` | `text` | yes | - |
| `updated_via` | `text` | yes | - |
| `rev` | `integer` | no | default `1` |

Constraints:

- `CHECK ((kepercayaan = ANY (ARRAY['tinggi'::text, 'sedang'::text, 'rendah'::text])))`
- `CHECK ((updated_via = ANY (ARRAY['qgis'::text, 'web'::text, 'api'::text, 'sync'::text, 'import'::text])))`

Indexes:

- `CREATE INDEX hotspot_geom_idx USING gist (geom)`
- `CREATE INDEX hotspot_khg_id_idx USING btree (khg_id)`
- `CREATE INDEX hotspot_waktu_idx USING btree (waktu)`

Triggers:

- `a_meta`: `BEFORE INSERT OR UPDATE` executes `alur.isi_meta()`

## peta.kanal

*table, 657,621 rows, 266.9 MB.* Canal segment from the 2025 OpenStreetMap seamless canal layer. Editable.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint identity` | no | primary key |
| `kode` | `text` | yes | - |
| `jenis_kanal` | `smallint` | yes | references `ref.jenis_kanal` |
| `status` | `text` | yes | references `ref.status_kanal` |
| `keterangan` | `text` | yes | - |
| `sumber` | `text` | yes | - |
| `id_asal` | `bigint` | yes | - |
| `geom` | `geometry(MultiLineString,4326)` | no | - |
| `panjang_m` | `numeric generated` | yes | `round((st_length((geom)::geography))::numeric, 1)` |
| `khg_id` | `integer` | yes | references `ref.khg` |
| `created_at` | `timestamp with time zone` | no | default `now()` |
| `created_by` | `text` | yes | - |
| `updated_at` | `timestamp with time zone` | no | default `now()` |
| `updated_by` | `text` | yes | - |
| `updated_via` | `text` | yes | - |
| `rev` | `integer` | no | default `1` |

Constraints:

- `CHECK ((updated_via = ANY (ARRAY['qgis'::text, 'web'::text, 'api'::text, 'sync'::text, 'import'::text])))`

Indexes:

- `CREATE INDEX kanal_geom_idx USING gist (geom)`
- `CREATE INDEX kanal_khg_id_idx USING btree (khg_id)`
- `CREATE UNIQUE INDEX kanal_khg_id_kode_idx USING btree (khg_id, kode)`
- `CREATE INDEX kanal_sumber_id_asal_idx USING btree (sumber, id_asal)`

Triggers:

- `a_meta`: `BEFORE INSERT OR UPDATE` executes `alur.isi_meta()`
- `b_kode`: `BEFORE INSERT` executes `alur.isi_kode('K')`
- `z_audit`: `AFTER INSERT OR DELETE OR UPDATE` executes `alur.catat_perubahan()`

## peta.ketebalan_gambut

*table, 2,938 rows, 128.2 MB.* Peat thickness class polygon per KHG.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint identity` | no | primary key |
| `kelas` | `text` | yes | - |
| `tebal_min_m` | `numeric(4,1)` | yes | - |
| `tebal_max_m` | `numeric(4,1)` | yes | - |
| `geom` | `geometry(MultiPolygon,4326)` | no | - |
| `khg_id` | `integer` | yes | references `ref.khg` |
| `created_at` | `timestamp with time zone` | no | default `now()` |
| `created_by` | `text` | yes | - |
| `updated_at` | `timestamp with time zone` | no | default `now()` |
| `updated_by` | `text` | yes | - |
| `updated_via` | `text` | yes | - |
| `rev` | `integer` | no | default `1` |

Constraints:

- `CHECK ((updated_via = ANY (ARRAY['qgis'::text, 'web'::text, 'api'::text, 'sync'::text, 'import'::text])))`

Indexes:

- `CREATE INDEX ketebalan_gambut_geom_idx USING gist (geom)`
- `CREATE INDEX ketebalan_gambut_khg_id_idx USING btree (khg_id)`

Triggers:

- `a_meta`: `BEFORE INSERT OR UPDATE` executes `alur.isi_meta()`

## peta.konsesi

*table, 1,070 rows, 16.7 MB.* Concession polygon per company, dissolved from analysis units.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint identity` | no | primary key |
| `perusahaan_id` | `integer` | yes | references `ref.perusahaan` |
| `jenis` | `text` | yes | - |
| `sumber` | `text` | yes | - |
| `geom` | `geometry(MultiPolygon,4326)` | no | - |
| `khg_id` | `integer` | yes | references `ref.khg` |
| `created_at` | `timestamp with time zone` | no | default `now()` |
| `created_by` | `text` | yes | - |
| `updated_at` | `timestamp with time zone` | no | default `now()` |
| `updated_by` | `text` | yes | - |
| `updated_via` | `text` | yes | - |
| `rev` | `integer` | no | default `1` |

Constraints:

- `CHECK ((updated_via = ANY (ARRAY['qgis'::text, 'web'::text, 'api'::text, 'sync'::text, 'import'::text])))`

Indexes:

- `CREATE INDEX konsesi_geom_idx USING gist (geom)`
- `CREATE INDEX konsesi_khg_id_idx USING btree (khg_id)`

Triggers:

- `a_meta`: `BEFORE INSERT OR UPDATE` executes `alur.isi_meta()`
- `z_audit`: `AFTER INSERT OR DELETE OR UPDATE` executes `alur.catat_perubahan()`

## peta.logger_tmat

*table, 0 rows, 0.0 MB.* Groundwater level logger location. Editable.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint identity` | no | primary key |
| `kode` | `text` | yes | - |
| `ext_id` | `text` | yes | - |
| `geom` | `geometry(Point,4326)` | no | - |
| `khg_id` | `integer` | yes | references `ref.khg` |
| `created_at` | `timestamp with time zone` | no | default `now()` |
| `created_by` | `text` | yes | - |
| `updated_at` | `timestamp with time zone` | no | default `now()` |
| `updated_by` | `text` | yes | - |
| `updated_via` | `text` | yes | - |
| `rev` | `integer` | no | default `1` |

Constraints:

- `CHECK ((updated_via = ANY (ARRAY['qgis'::text, 'web'::text, 'api'::text, 'sync'::text, 'import'::text])))`
- `UNIQUE (ext_id)`
- `UNIQUE (kode)`

Indexes:

- `CREATE UNIQUE INDEX logger_tmat_ext_id_key USING btree (ext_id)`
- `CREATE UNIQUE INDEX logger_tmat_kode_key USING btree (kode)`
- `CREATE INDEX logger_tmat_geom_idx USING gist (geom)`
- `CREATE INDEX logger_tmat_khg_id_idx USING btree (khg_id)`

Triggers:

- `a_meta`: `BEFORE INSERT OR UPDATE` executes `alur.isi_meta()`
- `z_audit`: `AFTER INSERT OR DELETE OR UPDATE` executes `alur.catat_perubahan()`

## peta.pintu_air

*table, 48 rows, 0.1 MB.* Water gate. Editable.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint identity` | no | primary key |
| `kode` | `text` | yes | - |
| `keterangan` | `text` | yes | - |
| `tahun_bangun` | `smallint` | yes | - |
| `bahan` | `text` | yes | - |
| `pelaksana` | `text` | yes | - |
| `perusahaan_id` | `integer` | yes | references `ref.perusahaan` |
| `sumber` | `text` | yes | - |
| `geom` | `geometry(Point,4326)` | no | - |
| `khg_id` | `integer` | yes | references `ref.khg` |
| `created_at` | `timestamp with time zone` | no | default `now()` |
| `created_by` | `text` | yes | - |
| `updated_at` | `timestamp with time zone` | no | default `now()` |
| `updated_by` | `text` | yes | - |
| `updated_via` | `text` | yes | - |
| `rev` | `integer` | no | default `1` |

Constraints:

- `CHECK ((updated_via = ANY (ARRAY['qgis'::text, 'web'::text, 'api'::text, 'sync'::text, 'import'::text])))`

Indexes:

- `CREATE INDEX pintu_air_geom_idx USING gist (geom)`
- `CREATE INDEX pintu_air_khg_id_idx USING btree (khg_id)`

Triggers:

- `a_meta`: `BEFORE INSERT OR UPDATE` executes `alur.isi_meta()`
- `z_audit`: `AFTER INSERT OR DELETE OR UPDATE` executes `alur.catat_perubahan()`

## peta.pompa

*table, 0 rows, 0.1 MB.* Planned or installed pump with suitability scores. Editable.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint identity` | no | primary key |
| `kode` | `text` | yes | - |
| `status` | `text` | no | references `ref.status_pompa`; default `'rencana'::text` |
| `kapasitas_m3_menit` | `numeric(8,2)` | yes | - |
| `sungai_id` | `bigint` | yes | references `peta.sungai` |
| `kanal_id` | `bigint` | yes | references `peta.kanal` |
| `jarak_sungai_m` | `numeric(8,1)` | yes | - |
| `estimasi_layanan_ha` | `numeric(10,1)` | yes | - |
| `skor` | `numeric(3,2)` | yes | - |
| `skor_sumber_air` | `numeric(3,2)` | yes | - |
| `skor_kanal` | `numeric(3,2)` | yes | - |
| `skor_gambut` | `numeric(3,2)` | yes | - |
| `skor_terbakar` | `numeric(3,2)` | yes | - |
| `geom` | `geometry(Point,4326)` | no | - |
| `khg_id` | `integer` | yes | references `ref.khg` |
| `created_at` | `timestamp with time zone` | no | default `now()` |
| `created_by` | `text` | yes | - |
| `updated_at` | `timestamp with time zone` | no | default `now()` |
| `updated_by` | `text` | yes | - |
| `updated_via` | `text` | yes | - |
| `rev` | `integer` | no | default `1` |

Constraints:

- `CHECK (((skor >= (0)::numeric) AND (skor <= (1)::numeric)))`
- `CHECK (((skor_gambut >= (0)::numeric) AND (skor_gambut <= (1)::numeric)))`
- `CHECK (((skor_kanal >= (0)::numeric) AND (skor_kanal <= (1)::numeric)))`
- `CHECK (((skor_sumber_air >= (0)::numeric) AND (skor_sumber_air <= (1)::numeric)))`
- `CHECK (((skor_terbakar >= (0)::numeric) AND (skor_terbakar <= (1)::numeric)))`
- `CHECK ((updated_via = ANY (ARRAY['qgis'::text, 'web'::text, 'api'::text, 'sync'::text, 'import'::text])))`

Indexes:

- `CREATE INDEX pompa_geom_idx USING gist (geom)`
- `CREATE INDEX pompa_khg_id_idx USING btree (khg_id)`
- `CREATE UNIQUE INDEX pompa_khg_id_kode_idx USING btree (khg_id, kode)`

Triggers:

- `a_meta`: `BEFORE INSERT OR UPDATE` executes `alur.isi_meta()`
- `b_kode`: `BEFORE INSERT` executes `alur.isi_kode('P')`
- `z_audit`: `AFTER INSERT OR DELETE OR UPDATE` executes `alur.catat_perubahan()`

## peta.posko_karhutla

*table, 0 rows, 0.0 MB.* Forest and land fire post. Editable.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint identity` | no | primary key |
| `nama` | `text` | yes | - |
| `keterangan` | `text` | yes | - |
| `geom` | `geometry(Point,4326)` | no | - |
| `khg_id` | `integer` | yes | references `ref.khg` |
| `created_at` | `timestamp with time zone` | no | default `now()` |
| `created_by` | `text` | yes | - |
| `updated_at` | `timestamp with time zone` | no | default `now()` |
| `updated_by` | `text` | yes | - |
| `updated_via` | `text` | yes | - |
| `rev` | `integer` | no | default `1` |

Constraints:

- `CHECK ((updated_via = ANY (ARRAY['qgis'::text, 'web'::text, 'api'::text, 'sync'::text, 'import'::text])))`

Indexes:

- `CREATE INDEX posko_karhutla_geom_idx USING gist (geom)`
- `CREATE INDEX posko_karhutla_khg_id_idx USING btree (khg_id)`

Triggers:

- `a_meta`: `BEFORE INSERT OR UPDATE` executes `alur.isi_meta()`
- `z_audit`: `AFTER INSERT OR DELETE OR UPDATE` executes `alur.catat_perubahan()`

## peta.sekat

*table, 366,371 rows, 122.1 MB.* Canal block, planned or existing. Editable. Aggregate root.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint identity` | no | primary key |
| `kode` | `text` | yes | - |
| `status` | `text` | no | references `ref.status_sekat`; default `'rencana'::text` |
| `kanal_id` | `bigint` | yes | references `peta.kanal` |
| `id_kontur_asal` | `bigint` | yes | - |
| `jenis_kanal` | `smallint` | yes | references `ref.jenis_kanal` |
| `panjang_kanal_m` | `numeric` | yes | - |
| `elevasi_kontur_m` | `numeric(8,2)` | yes | - |
| `sumber` | `text` | no | default `'manual'::text` |
| `fid_asal` | `bigint` | yes | - |
| `qc_flag` | `text` | yes | - |
| `geom` | `geometry(Point,4326)` | no | - |
| `khg_id` | `integer` | yes | references `ref.khg` |
| `created_at` | `timestamp with time zone` | no | default `now()` |
| `created_by` | `text` | yes | - |
| `updated_at` | `timestamp with time zone` | no | default `now()` |
| `updated_by` | `text` | yes | - |
| `updated_via` | `text` | yes | - |
| `rev` | `integer` | no | default `1` |

Constraints:

- `CHECK ((updated_via = ANY (ARRAY['qgis'::text, 'web'::text, 'api'::text, 'sync'::text, 'import'::text])))`
- `UNIQUE (fid_asal)`

Indexes:

- `CREATE UNIQUE INDEX sekat_fid_asal_key USING btree (fid_asal)`
- `CREATE INDEX sekat_geom_idx USING gist (geom)`
- `CREATE INDEX sekat_kanal_id_idx USING btree (kanal_id)`
- `CREATE INDEX sekat_khg_id_idx USING btree (khg_id)`
- `CREATE UNIQUE INDEX sekat_khg_id_kode_idx USING btree (khg_id, kode)`
- `CREATE INDEX sekat_status_idx USING btree (status)`

Triggers:

- `a_meta`: `BEFORE INSERT OR UPDATE` executes `alur.isi_meta()`
- `b_kode`: `BEFORE INSERT` executes `alur.isi_kode('SK')`
- `z_audit`: `AFTER INSERT OR DELETE OR UPDATE` executes `alur.catat_perubahan()`

## peta.sekat_bangunan

*table, 46,913 rows, 6.2 MB.* One to one construction details of an existing canal block (budget, contractor, material, year).

| Column | Type | Null | Default or note |
|---|---|---|---|
| `sekat_id` | `bigint` | no | primary key; references `peta.sekat` |
| `kodefikasi` | `text` | yes | - |
| `kode_rencana` | `text` | yes | - |
| `khg_nama_asal` | `text` | yes | - |
| `tipe` | `text` | yes | - |
| `jenis_bangunan` | `text` | yes | - |
| `bahan` | `text` | yes | - |
| `tahun_bangun` | `smallint` | yes | - |
| `anggaran` | `text` | yes | - |
| `kegiatan` | `text` | yes | - |
| `pekerjaan` | `text` | yes | - |
| `pelaksana` | `text` | yes | - |
| `perusahaan_id` | `integer` | yes | references `ref.perusahaan` |
| `perijinan` | `text` | yes | - |
| `kode_pt` | `text` | yes | - |
| `tahun_data` | `smallint` | yes | - |
| `keterangan` | `text` | yes | - |
| `sumber_data` | `text` | yes | - |
| `sisfo_id` | `text` | yes | - |
| `detail` | `text` | yes | - |

## peta.sekat_konteks

*table, 319,458 rows, 115.4 MB.* One to one overlay context of a planned canal block (village, permit, land cover, peat, burn history).

| Column | Type | Null | Default or note |
|---|---|---|---|
| `sekat_id` | `bigint` | no | primary key; references `peta.sekat` |
| `desa_id` | `integer` | yes | references `ref.desa` |
| `perusahaan_id` | `integer` | yes | references `ref.perusahaan` |
| `nama_kawasan_konservasi` | `text` | yes | - |
| `fungsi_kawasan` | `text` | yes | references `ref.fungsi_kawasan` |
| `penutupan_lahan_2022` | `text` | yes | references `ref.penutupan_lahan` |
| `kerusakan_eg_2024` | `text` | yes | references `ref.kerusakan_eg` |
| `fungsi_eg_250k` | `text` | yes | - |
| `fungsi_eg_ketebalan` | `text` | yes | - |
| `tebal_gambut_kelas` | `text` | yes | - |
| `tanah_gambut` | `text` | yes | - |
| `sk_feg_50k` | `text` | yes | - |
| `kedalaman_gambut_bbsdlp` | `text` | yes | - |
| `kematangan_gambut` | `text` | yes | - |
| `landform` | `text` | yes | - |
| `gambut_bbsdlp` | `boolean` | yes | - |
| `lahan_gambut` | `boolean` | yes | - |
| `buffer` | `text` | yes | - |
| `tahun_terbakar` | `smallint[]` | yes | - |
| `frekuensi_terbakar` | `text` | yes | - |
| `terdampak_kanal` | `boolean` | yes | - |
| `program_dmpg` | `text` | yes | - |
| `prioritas_intervensi` | `text` | yes | - |
| `luas_poligon_analisis_ha` | `numeric` | yes | - |

Indexes:

- `CREATE INDEX sekat_konteks_desa_id_idx USING btree (desa_id)`
- `CREATE INDEX sekat_konteks_perusahaan_id_idx USING btree (perusahaan_id)`

## peta.sumur_bor

*table, 0 rows, 0.0 MB.* Deep well. Synchronised from the external Deep Well system. Editable.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint identity` | no | primary key |
| `kode` | `text` | yes | - |
| `desa_id` | `integer` | yes | references `ref.desa` |
| `kedalaman_m` | `numeric(5,1)` | yes | - |
| `kondisi` | `text` | no | references `ref.kondisi_sumur`; default `'belum_verifikasi'::text` |
| `tahun_bangun` | `smallint` | yes | - |
| `pelaksana` | `text` | yes | - |
| `penanggung_jawab` | `text` | yes | - |
| `catatan` | `text` | yes | - |
| `ext_id` | `text` | yes | - |
| `synced_at` | `timestamp with time zone` | yes | - |
| `geom` | `geometry(Point,4326)` | no | - |
| `khg_id` | `integer` | yes | references `ref.khg` |
| `created_at` | `timestamp with time zone` | no | default `now()` |
| `created_by` | `text` | yes | - |
| `updated_at` | `timestamp with time zone` | no | default `now()` |
| `updated_by` | `text` | yes | - |
| `updated_via` | `text` | yes | - |
| `rev` | `integer` | no | default `1` |

Constraints:

- `CHECK ((updated_via = ANY (ARRAY['qgis'::text, 'web'::text, 'api'::text, 'sync'::text, 'import'::text])))`
- `UNIQUE (ext_id)`
- `UNIQUE (kode)`

Indexes:

- `CREATE UNIQUE INDEX sumur_bor_ext_id_key USING btree (ext_id)`
- `CREATE UNIQUE INDEX sumur_bor_kode_key USING btree (kode)`
- `CREATE INDEX sumur_bor_geom_idx USING gist (geom)`
- `CREATE INDEX sumur_bor_khg_id_idx USING btree (khg_id)`

Triggers:

- `a_meta`: `BEFORE INSERT OR UPDATE` executes `alur.isi_meta()`
- `z_audit`: `AFTER INSERT OR DELETE OR UPDATE` executes `alur.catat_perubahan()`

## peta.sumur_debit

*table, 0 rows, 0.0 MB.* Daily discharge of a deep well.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `sumur_id` | `bigint` | no | primary key; references `peta.sumur_bor` |
| `tanggal` | `date` | no | primary key |
| `debit_lps` | `numeric(6,2)` | yes | - |
| `catatan` | `text` | yes | - |

## peta.sungai

*table, 0 rows, 0.1 MB.* River line used as a water source for pumps. Editable.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint identity` | no | primary key |
| `nama` | `text` | yes | - |
| `geom` | `geometry(MultiLineString,4326)` | no | - |
| `khg_id` | `integer` | yes | references `ref.khg` |
| `created_at` | `timestamp with time zone` | no | default `now()` |
| `created_by` | `text` | yes | - |
| `updated_at` | `timestamp with time zone` | no | default `now()` |
| `updated_by` | `text` | yes | - |
| `updated_via` | `text` | yes | - |
| `rev` | `integer` | no | default `1` |

Constraints:

- `CHECK ((updated_via = ANY (ARRAY['qgis'::text, 'web'::text, 'api'::text, 'sync'::text, 'import'::text])))`

Indexes:

- `CREATE INDEX sungai_geom_idx USING gist (geom)`
- `CREATE INDEX sungai_khg_id_idx USING btree (khg_id)`

Triggers:

- `a_meta`: `BEFORE INSERT OR UPDATE` executes `alur.isi_meta()`
- `z_audit`: `AFTER INSERT OR DELETE OR UPDATE` executes `alur.catat_perubahan()`

## peta.tmat_bacaan

*table, 0 rows, 0.0 MB.* Groundwater depth reading per logger and timestamp.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `logger_id` | `bigint` | no | primary key; references `peta.logger_tmat` |
| `waktu` | `timestamp with time zone` | no | primary key |
| `tmat_m` | `numeric(5,2)` | no | - |

## peta.v_khg_legenda

*view.* View: feature count per layer and KHG (map legend numbers).

| Column | Type | Null | Default or note |
|---|---|---|---|
| `khg_id` | `integer` | yes | - |
| `layer` | `text` | yes | - |
| `jumlah` | `bigint` | yes | - |

## peta.v_sekat

*view.* View: canal block with overlay context and region names.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint` | yes | - |
| `kode` | `text` | yes | - |
| `status` | `text` | yes | - |
| `jenis_kanal` | `smallint` | yes | - |
| `jenis_kanal_label` | `text` | yes | - |
| `elevasi_kontur_m` | `numeric(8,2)` | yes | - |
| `khg_id` | `integer` | yes | - |
| `nama_khg` | `text` | yes | - |
| `provinsi` | `text` | yes | - |
| `kabupaten` | `text` | yes | - |
| `kecamatan` | `text` | yes | - |
| `desa` | `text` | yes | - |
| `perusahaan` | `text` | yes | - |
| `izin_usaha` | `text` | yes | - |
| `fungsi_kawasan` | `text` | yes | - |
| `penutupan_lahan_2022` | `text` | yes | - |
| `kerusakan_eg_2024` | `text` | yes | - |
| `fungsi_eg_ketebalan` | `text` | yes | - |
| `tebal_gambut_kelas` | `text` | yes | - |
| `kedalaman_gambut_bbsdlp` | `text` | yes | - |
| `kematangan_gambut` | `text` | yes | - |
| `landform` | `text` | yes | - |
| `tahun_terbakar` | `smallint[]` | yes | - |
| `frekuensi_terbakar` | `text` | yes | - |
| `program_dmpg` | `text` | yes | - |
| `prioritas_intervensi` | `text` | yes | - |
| `qc_flag` | `text` | yes | - |
| `geom` | `geometry(Point,4326)` | yes | - |

## peta.v_sumur_bor

*view.* View: deep well with latest discharge.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint` | yes | - |
| `kode` | `text` | yes | - |
| `desa` | `text` | yes | - |
| `nama_khg` | `text` | yes | - |
| `khg_id` | `integer` | yes | - |
| `kedalaman_m` | `numeric(5,1)` | yes | - |
| `kondisi` | `text` | yes | - |
| `tahun_bangun` | `smallint` | yes | - |
| `pelaksana` | `text` | yes | - |
| `penanggung_jawab` | `text` | yes | - |
| `tanggal_debit` | `date` | yes | - |
| `debit_terakhir_lps` | `numeric(6,2)` | yes | - |
| `synced_at` | `timestamp with time zone` | yes | - |
| `geom` | `geometry(Point,4326)` | yes | - |

## peta.v_tmat_alert

*view.* View: loggers whose latest groundwater depth exceeds 0.4 m.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `logger_id` | `bigint` | yes | - |
| `kode` | `text` | yes | - |
| `khg_id` | `integer` | yes | - |
| `waktu` | `timestamp with time zone` | yes | - |
| `tmat_m` | `numeric(5,2)` | yes | - |
| `geom` | `geometry(Point,4326)` | yes | - |

# Schema analisis

Large read-only analysis layers.

## analisis.kontur

*table, 159,043 rows, 2,094.8 MB.* Contour line from WorldDEM for 108 BRGM target KHG.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint identity` | no | primary key |
| `khg_id` | `integer` | yes | references `ref.khg` |
| `elevasi_m` | `numeric(8,2)` | yes | - |
| `geom` | `geometry(MultiLineString,4326)` | no | - |

Indexes:

- `CREATE INDEX kontur_geom_idx USING gist (geom)`
- `CREATE INDEX kontur_khg_id_idx USING btree (khg_id)`

## analisis.kontur_lidar

*table, 26,968 rows, 196.0 MB.* Contour line at 50 cm interval from LiDAR (Riau, Jambi, South Sumatra).

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint identity` | no | primary key |
| `khg_id` | `integer` | yes | references `ref.khg` |
| `elevasi_m` | `numeric(8,2)` | yes | - |
| `geom` | `geometry(MultiLineString,4326)` | no | - |

Indexes:

- `CREATE INDEX kontur_lidar_geom_idx USING gist (geom)`
- `CREATE INDEX kontur_lidar_khg_id_idx USING btree (khg_id)`

## analisis.unit_nasional

*table, 989,398 rows, 1,399.5 MB.* National analysis unit (overlay of KHG, village, permit, forest function, peat and burn history).

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint identity` | no | primary key |
| `khg_id` | `integer` | yes | - |
| `desa_id` | `integer` | yes | - |
| `perusahaan_id` | `integer` | yes | - |
| `jenis_kanal` | `smallint` | yes | - |
| `nama_kawasan_konservasi` | `text` | yes | - |
| `fungsi_kawasan` | `text` | yes | - |
| `penutupan_lahan_2022` | `text` | yes | - |
| `kerusakan_eg_2024` | `text` | yes | - |
| `fungsi_eg_250k` | `text` | yes | - |
| `fungsi_eg_ketebalan` | `text` | yes | - |
| `tebal_gambut_kelas` | `text` | yes | - |
| `tanah_gambut` | `text` | yes | - |
| `sk_feg_50k` | `text` | yes | - |
| `kedalaman_gambut_bbsdlp` | `text` | yes | - |
| `kematangan_gambut` | `text` | yes | - |
| `landform` | `text` | yes | - |
| `gambut_bbsdlp` | `boolean` | yes | - |
| `lahan_gambut` | `boolean` | yes | - |
| `buffer` | `text` | yes | - |
| `tahun_terbakar` | `smallint[]` | yes | - |
| `frekuensi_terbakar` | `text` | yes | - |
| `terdampak_kanal` | `boolean` | yes | - |
| `program_dmpg` | `text` | yes | - |
| `prioritas_intervensi` | `text` | yes | - |
| `luas_ha` | `numeric` | yes | - |
| `geom` | `geometry(MultiPolygon,4326)` | no | - |

Indexes:

- `CREATE INDEX unit_nasional_desa_id_idx USING btree (desa_id)`
- `CREATE INDEX unit_nasional_geom_idx USING gist (geom)`
- `CREATE INDEX unit_nasional_khg_id_idx USING btree (khg_id)`
- `CREATE INDEX unit_nasional_perusahaan_id_idx USING btree (perusahaan_id)`

## analisis.unit_target_2026

*table, 789,336 rows, 970.3 MB.* Analysis unit inside the 2,004 target villages for 2026.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint identity` | no | primary key |
| `khg_id` | `integer` | yes | references `ref.khg` |
| `desa_id` | `integer` | yes | references `ref.desa` |
| `perusahaan_id` | `integer` | yes | references `ref.perusahaan` |
| `jenis_kanal` | `smallint` | yes | references `ref.jenis_kanal` |
| `nama_kawasan_konservasi` | `text` | yes | - |
| `fungsi_kawasan` | `text` | yes | references `ref.fungsi_kawasan` |
| `penutupan_lahan_2022` | `text` | yes | references `ref.penutupan_lahan` |
| `kerusakan_eg_2024` | `text` | yes | references `ref.kerusakan_eg` |
| `fungsi_eg_250k` | `text` | yes | - |
| `fungsi_eg_ketebalan` | `text` | yes | - |
| `tebal_gambut_kelas` | `text` | yes | - |
| `tanah_gambut` | `text` | yes | - |
| `sk_feg_50k` | `text` | yes | - |
| `kedalaman_gambut_bbsdlp` | `text` | yes | - |
| `kematangan_gambut` | `text` | yes | - |
| `landform` | `text` | yes | - |
| `gambut_bbsdlp` | `boolean` | yes | - |
| `lahan_gambut` | `boolean` | yes | - |
| `buffer` | `text` | yes | - |
| `tahun_terbakar` | `smallint[]` | yes | - |
| `frekuensi_terbakar` | `text` | yes | - |
| `terdampak_kanal` | `boolean` | yes | - |
| `program_dmpg` | `text` | yes | - |
| `prioritas_intervensi` | `text` | yes | - |
| `luas_ha` | `numeric` | yes | - |
| `geom` | `geometry(MultiPolygon,4326)` | no | - |

Indexes:

- `CREATE INDEX unit_target_2026_desa_id_idx USING btree (desa_id)`
- `CREATE INDEX unit_target_2026_geom_idx USING gist (geom)`
- `CREATE INDEX unit_target_2026_khg_id_idx USING btree (khg_id)`
- `CREATE INDEX unit_target_2026_perusahaan_id_idx USING btree (perusahaan_id)`

# Schema alur

Plan versions, audit and poster exports.

## alur.ekspor_poster

*table, 0 rows, 0.1 MB.* Poster export job with paper size, progress and output file.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint identity` | no | primary key |
| `versi_id` | `bigint` | no | references `alur.khg_versi` |
| `template_id` | `integer` | no | references `alur.template_poster` |
| `batch_id` | `uuid` | yes | - |
| `kertas` | `text` | no | - |
| `orientasi` | `text` | no | - |
| `periode_mulai` | `date` | yes | - |
| `periode_selesai` | `date` | yes | - |
| `dpi` | `smallint` | no | default `300` |
| `status` | `text` | no | default `'menunggu'::text` |
| `progres` | `smallint` | no | default `0` |
| `file_path` | `text` | yes | - |
| `ukuran_bytes` | `bigint` | yes | - |
| `pesan_error` | `text` | yes | - |
| `dibuat_oleh` | `text` | no | default `SESSION_USER` |
| `created_at` | `timestamp with time zone` | no | default `now()` |
| `selesai_at` | `timestamp with time zone` | yes | - |

Constraints:

- `CHECK ((kertas = ANY (ARRAY['A0'::text, 'A1'::text, 'A2'::text, 'A3'::text])))`
- `CHECK ((orientasi = ANY (ARRAY['lanskap'::text, 'potret'::text])))`
- `CHECK (((progres >= 0) AND (progres <= 100)))`
- `CHECK ((status = ANY (ARRAY['menunggu'::text, 'merender'::text, 'selesai'::text, 'gagal'::text, 'dibatalkan'::text])))`

Indexes:

- `CREATE INDEX ekspor_poster_batch_id_idx USING btree (batch_id)`
- `CREATE INDEX ekspor_poster_status_created_at_idx USING btree (status, created_at)`

Triggers:

- `ekspor_selesai`: `AFTER UPDATE OF status` executes `alur.tandai_dicetak()`

## alur.khg_versi

*table, 866 rows, 0.2 MB.* Plan version of a KHG. Aggregate root of the review workflow.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint identity` | no | primary key |
| `khg_id` | `integer` | no | references `ref.khg` |
| `nomor` | `integer` | no | - |
| `status` | `text` | no | references `ref.status_alur`; default `'draft'::text` |
| `dibuat_at` | `timestamp with time zone` | no | default `now()` |
| `diajukan_oleh` | `text` | yes | - |
| `diajukan_at` | `timestamp with time zone` | yes | - |
| `reviewer` | `text` | yes | - |
| `diputuskan_at` | `timestamp with time zone` | yes | - |
| `catatan_reviewer` | `text` | yes | - |
| `validasi` | `jsonb` | yes | - |

Constraints:

- `UNIQUE (khg_id, nomor)`

Indexes:

- `CREATE UNIQUE INDEX khg_versi_khg_id_nomor_key USING btree (khg_id, nomor)`
- `CREATE UNIQUE INDEX khg_versi_satu_terbuka USING btree (khg_id) WHERE (status = ANY (ARRAY['draft'::text, 'review'::text, 'revisi'::text]))`

## alur.komentar

*table, 0 rows, 0.0 MB.* Review comment on a version or on a single feature, with threaded replies.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint identity` | no | primary key |
| `versi_id` | `bigint` | no | references `alur.khg_versi` |
| `tabel` | `text` | yes | - |
| `fitur_id` | `bigint` | yes | - |
| `parent_id` | `bigint` | yes | references `alur.komentar` |
| `pengguna` | `text` | no | - |
| `isi` | `text` | no | - |
| `selesai` | `boolean` | no | default `false` |
| `created_at` | `timestamp with time zone` | no | default `now()` |

Constraints:

- `CHECK (((tabel IS NULL) = (fitur_id IS NULL)))`

Indexes:

- `CREATE INDEX komentar_tabel_fitur_id_idx USING btree (tabel, fitur_id)`
- `CREATE INDEX komentar_versi_id_idx USING btree (versi_id)`

## alur.pengguna

*table, 0 rows, 0.0 MB.* Application user profile (name, agency, role).

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `integer identity` | no | primary key |
| `username` | `text` | no | - |
| `nama` | `text` | no | - |
| `instansi` | `text` | yes | - |
| `peran` | `text` | no | - |

Constraints:

- `CHECK ((peran = ANY (ARRAY['analis'::text, 'reviewer'::text, 'admin'::text])))`
- `UNIQUE (username)`

Indexes:

- `CREATE UNIQUE INDEX pengguna_username_key USING btree (username)`

## alur.perubahan

*table, 0 rows, 0.1 MB.* Change record written by the audit trigger for every create, update and delete.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint identity` | no | primary key |
| `waktu` | `timestamp with time zone` | no | default `now()` |
| `tabel` | `text` | no | - |
| `fitur_id` | `bigint` | no | - |
| `khg_id` | `integer` | yes | references `ref.khg` |
| `versi_id` | `bigint` | yes | references `alur.khg_versi` |
| `aksi` | `character(1)` | no | - |
| `via` | `text` | no | - |
| `pengguna` | `text` | no | - |
| `data_lama` | `jsonb` | yes | - |
| `data_baru` | `jsonb` | yes | - |

Constraints:

- `CHECK ((aksi = ANY (ARRAY['I'::bpchar, 'U'::bpchar, 'D'::bpchar])))`

Indexes:

- `CREATE INDEX perubahan_khg_id_waktu_idx USING btree (khg_id, waktu DESC)`
- `CREATE INDEX perubahan_tabel_fitur_id_idx USING btree (tabel, fitur_id)`
- `CREATE INDEX perubahan_versi_id_idx USING btree (versi_id)`

## alur.template_poster

*table, 0 rows, 0.0 MB.* Poster layout template (QGIS print layout file).

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `integer identity` | no | primary key |
| `nama` | `text` | no | - |
| `versi` | `text` | yes | - |
| `file_path` | `text` | no | - |
| `aktif` | `boolean` | no | default `true` |

## alur.v_dashboard

*view.* View: one row of national dashboard indicators.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `khg_disetujui` | `bigint` | yes | - |
| `khg_total` | `bigint` | yes | - |
| `khg_disetujui_minggu_ini` | `bigint` | yes | - |
| `pompa_rencana` | `bigint` | yes | - |
| `pompa_minggu_ini` | `bigint` | yes | - |
| `kanal_aktif_km` | `numeric` | yes | - |
| `kanal_total_km` | `numeric` | yes | - |
| `hotspot_30h` | `bigint` | yes | - |
| `hotspot_30h_sebelumnya` | `bigint` | yes | - |
| `logger_alert` | `bigint` | yes | - |
| `khg_alert` | `bigint` | yes | - |
| `sekat_total` | `bigint` | yes | - |
| `sekat_existing` | `bigint` | yes | - |
| `status_alur` | `jsonb` | yes | - |

## alur.v_khg_daftar

*view.* View: KHG list with counts and priority score (internal).

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `integer` | yes | - |
| `kode` | `text` | yes | - |
| `nama` | `text` | yes | - |
| `provinsi` | `text` | yes | - |
| `provinsi_id` | `smallint` | yes | - |
| `luas_ha` | `numeric` | yes | - |
| `hotspot_30h` | `bigint` | yes | - |
| `pompa` | `bigint` | yes | - |
| `kanal_aktif_km` | `numeric` | yes | - |
| `kanal_total_km` | `numeric` | yes | - |
| `sekat` | `bigint` | yes | - |
| `sekat_rencana` | `bigint` | yes | - |
| `sekat_existing` | `bigint` | yes | - |
| `versi_id` | `bigint` | yes | - |
| `versi` | `integer` | yes | - |
| `status` | `text` | yes | - |
| `terakhir_diubah` | `timestamp with time zone` | yes | - |
| `diubah_via` | `text` | yes | - |
| `diubah_oleh` | `text` | yes | - |
| `skor_prioritas` | `integer` | yes | - |

## alur.v_khg_status

*view.* View: latest version and status per KHG.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `khg_id` | `integer` | yes | - |
| `versi_id` | `bigint` | yes | - |
| `nomor` | `integer` | yes | - |
| `status` | `text` | yes | - |
| `diajukan_oleh` | `text` | yes | - |
| `diajukan_at` | `timestamp with time zone` | yes | - |
| `reviewer` | `text` | yes | - |
| `diputuskan_at` | `timestamp with time zone` | yes | - |
| `dibuat_at` | `timestamp with time zone` | yes | - |

# Schema api

Public read model for the OGC API.

## api.khg_statistik

*materialized view, 866 rows, 0.2 MB.* Materialized view: expensive KHG statistics, refreshed daily.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `khg_id` | `integer` | yes | - |
| `hotspot_30h` | `bigint` | yes | - |
| `hotspot_tahun_ini` | `bigint` | yes | - |
| `kanal_km` | `numeric` | yes | - |
| `sekat_rencana` | `bigint` | yes | - |
| `sekat_existing` | `bigint` | yes | - |
| `pintu_air` | `bigint` | yes | - |
| `porsi_pernah_terbakar` | `numeric` | yes | - |
| `porsi_gambut_dalam` | `numeric` | yes | - |

Indexes:

- `CREATE UNIQUE INDEX khg_statistik_khg_id_idx USING btree (khg_id)`

## api.areal_terbakar

*view.* Public view published as OGC API collection. Readable names instead of foreign keys.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint` | yes | - |
| `tahun_terbakar` | `text` | yes | - |
| `frekuensi` | `smallint` | yes | - |
| `tahun_terakhir` | `smallint` | yes | - |
| `khg` | `text` | yes | - |
| `geom` | `geometry(MultiPolygon,4326)` | yes | - |

## api.desa

*view.* Public view published as OGC API collection. Readable names instead of foreign keys.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `integer` | yes | - |
| `kode_bps` | `text` | yes | - |
| `desa` | `text` | yes | - |
| `kecamatan` | `text` | yes | - |
| `kabupaten` | `text` | yes | - |
| `provinsi` | `text` | yes | - |
| `target_pemulihan_2026` | `boolean` | yes | - |
| `geom` | `geometry(MultiPolygon,4326)` | yes | - |

## api.hotspot

*view.* Public view published as OGC API collection. Readable names instead of foreign keys.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint` | yes | - |
| `waktu` | `timestamp with time zone` | yes | - |
| `satelit` | `text` | yes | - |
| `instrumen` | `text` | yes | - |
| `kepercayaan` | `text` | yes | - |
| `frp_mw` | `numeric(8,2)` | yes | - |
| `provinsi` | `text` | yes | - |
| `kabupaten` | `text` | yes | - |
| `desa` | `text` | yes | - |
| `khg` | `text` | yes | - |
| `format_sumber` | `text` | yes | - |
| `geom` | `geometry(Point,4326)` | yes | - |

## api.kanal

*view.* Public view published as OGC API collection. Readable names instead of foreign keys.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint` | yes | - |
| `kode` | `text` | yes | - |
| `jenis_kanal` | `text` | yes | - |
| `status` | `text` | yes | - |
| `panjang_m` | `numeric` | yes | - |
| `khg` | `text` | yes | - |
| `sumber` | `text` | yes | - |
| `geom` | `geometry(MultiLineString,4326)` | yes | - |

## api.ketebalan_gambut

*view.* Public view published as OGC API collection. Readable names instead of foreign keys.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint` | yes | - |
| `khg` | `text` | yes | - |
| `kelas` | `text` | yes | - |
| `tebal_min_m` | `numeric(4,1)` | yes | - |
| `tebal_max_m` | `numeric(4,1)` | yes | - |
| `geom` | `geometry(MultiPolygon,4326)` | yes | - |

## api.khg

*view.* Public view published as OGC API collection. Readable names instead of foreign keys.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `integer` | yes | - |
| `kode` | `text` | yes | - |
| `nama` | `text` | yes | - |
| `provinsi` | `text` | yes | - |
| `provinsi_singkat` | `text` | yes | - |
| `target_2026` | `boolean` | yes | - |
| `luas_ha` | `numeric(12,2)` | yes | - |
| `versi` | `integer` | yes | - |
| `status` | `text` | yes | - |
| `diajukan_oleh` | `text` | yes | - |
| `diajukan_at` | `timestamp with time zone` | yes | - |
| `reviewer` | `text` | yes | - |
| `diputuskan_at` | `timestamp with time zone` | yes | - |
| `hotspot_30h` | `bigint` | yes | - |
| `hotspot_tahun_ini` | `bigint` | yes | - |
| `kanal_km` | `numeric` | yes | - |
| `sekat_rencana` | `bigint` | yes | - |
| `sekat_existing` | `bigint` | yes | - |
| `pintu_air` | `bigint` | yes | - |
| `pompa` | `bigint` | yes | - |
| `kanal_aktif_km` | `numeric` | yes | - |
| `porsi_pernah_terbakar` | `numeric` | yes | - |
| `porsi_gambut_dalam` | `numeric` | yes | - |
| `skor_prioritas` | `integer` | yes | - |
| `geom` | `geometry(MultiPolygon,4326)` | yes | - |

## api.konsesi

*view.* Public view published as OGC API collection. Readable names instead of foreign keys.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint` | yes | - |
| `perusahaan` | `text` | yes | - |
| `jenis` | `text` | yes | - |
| `sumber` | `text` | yes | - |
| `geom` | `geometry(MultiPolygon,4326)` | yes | - |

## api.kontur

*view.* Public view published as OGC API collection. Readable names instead of foreign keys.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint` | yes | - |
| `elevasi_m` | `numeric(8,2)` | yes | - |
| `khg` | `text` | yes | - |
| `geom` | `geometry(MultiLineString,4326)` | yes | - |

## api.kontur_lidar

*view.* Public view published as OGC API collection. Readable names instead of foreign keys.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint` | yes | - |
| `elevasi_m` | `numeric(8,2)` | yes | - |
| `khg` | `text` | yes | - |
| `geom` | `geometry(MultiLineString,4326)` | yes | - |

## api.sekat

*view.* Public view published as OGC API collection. Readable names instead of foreign keys.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint` | yes | - |
| `kode` | `text` | yes | - |
| `status` | `text` | yes | - |
| `sumber` | `text` | yes | - |
| `jenis_kanal` | `text` | yes | - |
| `kanal_id` | `bigint` | yes | - |
| `elevasi_kontur_m` | `numeric(8,2)` | yes | - |
| `khg` | `text` | yes | - |
| `desa` | `text` | yes | - |
| `perusahaan` | `text` | yes | - |
| `kodefikasi` | `text` | yes | - |
| `tipe` | `text` | yes | - |
| `jenis_bangunan` | `text` | yes | - |
| `bahan` | `text` | yes | - |
| `tahun_bangun` | `smallint` | yes | - |
| `pelaksana` | `text` | yes | - |
| `anggaran` | `text` | yes | - |
| `penutupan_lahan_2022` | `text` | yes | - |
| `kerusakan_eg_2024` | `text` | yes | - |
| `tebal_gambut_kelas` | `text` | yes | - |
| `tahun_terbakar` | `smallint[]` | yes | - |
| `prioritas_intervensi` | `text` | yes | - |
| `program_dmpg` | `text` | yes | - |
| `qc_flag` | `text` | yes | - |
| `updated_at` | `timestamp with time zone` | yes | - |
| `updated_via` | `text` | yes | - |
| `geom` | `geometry(Point,4326)` | yes | - |

## api.sumur_bor

*view.* Public view published as OGC API collection. Readable names instead of foreign keys.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint` | yes | - |
| `kode` | `text` | yes | - |
| `desa` | `text` | yes | - |
| `nama_khg` | `text` | yes | - |
| `khg_id` | `integer` | yes | - |
| `kedalaman_m` | `numeric(5,1)` | yes | - |
| `kondisi` | `text` | yes | - |
| `tahun_bangun` | `smallint` | yes | - |
| `pelaksana` | `text` | yes | - |
| `penanggung_jawab` | `text` | yes | - |
| `tanggal_debit` | `date` | yes | - |
| `debit_terakhir_lps` | `numeric(6,2)` | yes | - |
| `synced_at` | `timestamp with time zone` | yes | - |
| `geom` | `geometry(Point,4326)` | yes | - |

## api.unit_nasional

*view.* Public view published as OGC API collection. Readable names instead of foreign keys.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint` | yes | - |
| `khg` | `text` | yes | - |
| `desa` | `text` | yes | - |
| `perusahaan` | `text` | yes | - |
| `izin_usaha` | `text` | yes | - |
| `jenis_kanal` | `text` | yes | - |
| `nama_kawasan_konservasi` | `text` | yes | - |
| `fungsi_kawasan` | `text` | yes | - |
| `penutupan_lahan_2022` | `text` | yes | - |
| `kerusakan_eg_2024` | `text` | yes | - |
| `fungsi_eg_ketebalan` | `text` | yes | - |
| `tebal_gambut_kelas` | `text` | yes | - |
| `kedalaman_gambut_bbsdlp` | `text` | yes | - |
| `kematangan_gambut` | `text` | yes | - |
| `landform` | `text` | yes | - |
| `lahan_gambut` | `boolean` | yes | - |
| `buffer` | `text` | yes | - |
| `tahun_terbakar` | `text` | yes | - |
| `frekuensi_terbakar` | `text` | yes | - |
| `terdampak_kanal` | `boolean` | yes | - |
| `program_dmpg` | `text` | yes | - |
| `prioritas_intervensi` | `text` | yes | - |
| `luas_ha` | `numeric` | yes | - |
| `geom` | `geometry(MultiPolygon,4326)` | yes | - |

## api.unit_target_2026

*view.* Public view published as OGC API collection. Readable names instead of foreign keys.

| Column | Type | Null | Default or note |
|---|---|---|---|
| `id` | `bigint` | yes | - |
| `khg` | `text` | yes | - |
| `desa` | `text` | yes | - |
| `perusahaan` | `text` | yes | - |
| `izin_usaha` | `text` | yes | - |
| `jenis_kanal` | `text` | yes | - |
| `nama_kawasan_konservasi` | `text` | yes | - |
| `fungsi_kawasan` | `text` | yes | - |
| `penutupan_lahan_2022` | `text` | yes | - |
| `kerusakan_eg_2024` | `text` | yes | - |
| `fungsi_eg_ketebalan` | `text` | yes | - |
| `tebal_gambut_kelas` | `text` | yes | - |
| `kedalaman_gambut_bbsdlp` | `text` | yes | - |
| `kematangan_gambut` | `text` | yes | - |
| `landform` | `text` | yes | - |
| `lahan_gambut` | `boolean` | yes | - |
| `buffer` | `text` | yes | - |
| `tahun_terbakar` | `text` | yes | - |
| `frekuensi_terbakar` | `text` | yes | - |
| `terdampak_kanal` | `boolean` | yes | - |
| `program_dmpg` | `text` | yes | - |
| `prioritas_intervensi` | `text` | yes | - |
| `luas_ha` | `numeric` | yes | - |
| `geom` | `geometry(MultiPolygon,4326)` | yes | - |

# Functions

| Function | Returns | Security | Purpose |
|---|---|---|---|
| `alur.ajukan_review(p_versi bigint)` | `void` | definer | Submits a draft or revision for review with a validation snapshot. |
| `alur.catat_perubahan()` | `trigger` | definer | Trigger: writes a change record linked to the open version. |
| `alur.daftar_singkat(a text[], n integer default 10)` | `text` | invoker | Formats a list of codes, shortened after ten items. |
| `alur.isi_kode()` | `trigger` | invoker | Trigger: next human code per KHG. |
| `alur.isi_meta()` | `trigger` | invoker | Trigger: KHG from geometry, audit columns, revision counter. |
| `alur.putuskan(p_versi bigint, p_keputusan text, p_catatan text default NULL::text)` | `void` | definer | Records the reviewer decision (approved or revisi). |
| `alur.tandai_dicetak()` | `trigger` | definer | Trigger: marks an approved version as printed after a poster export. |
| `alur.validasi_khg(p_versi bigint, p_maks_jarak_air numeric default 500)` | `TABLE(cek text, tingkat text, lolos boolean, pesan text)` | invoker | Runs the five automatic validation rules for a version. |
| `alur.versi_terbuka(p_khg integer)` | `bigint` | definer | Returns the open version of a KHG, creating version n+1 when needed. |
| `api.refresh_statistik()` | `timestamp with time zone` | definer | Refreshes the materialized KHG statistics. |
| `peta.saran_lokasi_pompa(p_khg integer, p_maks_jarak numeric default 500, p_min_tebal numeric default 3, p_buffer_konsesi numeric default 100, p_jarak_sampel numeric default 100, p_limit integer default 3)` | `TABLE(peringkat bigint, skor numeric, skor_sumber_air numeric, skor_kanal numeric, skor_gambut numeric, skor_terbakar numeric, jarak_sungai_m numeric, sungai_id bigint, kanal_id bigint, tebal_gambut_m numeric, jarak_konsesi_m numeric, geom geometry)` | invoker | Ranks candidate pump locations along active canals. |

# Roles and privileges

| Role | Login | Member of | Settings | Purpose |
|---|---|---|---|---|
| `editor_qgis` | yes | gambut_edit | `app.via=qgis` | Example QGIS editor account |
| `gambut_baca` | no | - | - | Read all layers and public views |
| `gambut_edit` | no | gambut_baca | - | Write planning layers, comments and exports |
| `ogc_reader` | yes | gambut_baca | `default_transaction_read_only=on`, `statement_timeout=30s` | pygeoapi read connection |
| `ogc_writer` | yes | gambut_edit | `app.via=api` | pygeoapi write connection |
| `web_app` | yes | gambut_edit | - | Web application backend |
