# Introduction

This document shows the entities of the Peat Rewetting Planning database and how they relate. The diagrams are generated from the live database catalogue, so they match the implementation exactly. The snapshot covers 41 tables, 21 views and 55 foreign keys on PostgreSQL 17.5 with PostGIS 3.5.2.

## How to read the diagrams

| Notation | Meaning |
|---|---|
| `\|\|--o{` | One parent row has zero or many child rows; the child must have a parent |
| `o\|--o{` | Optional parent: the foreign key may be empty |
| PK, FK | Primary key, foreign key |
| Point, MultiPolygon, MultiLineString | PostGIS geometry type, always EPSG:4326 (longitude, latitude) |
| Entity with only `id` | Entity from another context, shown for context |

To keep the diagrams readable, two groups of columns are left out:

- **Audit columns** present on every operational layer: `created_at`, `created_by`, `updated_at`, `updated_by`, `updated_via`, `rev`.
- **Lookup references** to code lists. They are listed in the section *Code lists*.

The full column list of every table is in the *Database Schema* document.

# Overview

```{.mermaid}
flowchart LR
  C0["Reference<br/>6 entities"]
  C1["Infrastructure Planning<br/>7 entities"]
  C2["Risk<br/>4 entities"]
  C3["Field Monitoring<br/>5 entities"]
  C4["Spatial Analysis<br/>4 entities"]
  C5["Plan Review<br/>6 entities"]
  C0 --> C1
  C0 --> C2
  C0 --> C3
  C0 --> C4
  C0 --> C5
  C4 -. dissolve .-> C0
  C4 -. dissolve .-> C2
  C1 -. change records .-> C5
  C3 -. change records .-> C5
```
<p class="figure-note">Figure 1. Contexts and their dependencies. Solid lines are foreign keys, dotted lines are data flows (dissolve during load, change records written by triggers).</p>

| Context | Entities | Rows |
|---|---|---:|
| Reference | `provinsi`, `kabupaten`, `kecamatan`, `desa`, `khg`, `perusahaan` | 9,065 |
| Infrastructure Planning | `kanal`, `sekat`, `sekat_konteks`, `sekat_bangunan`, `pompa`, `pintu_air`, `sungai` | 1,390,411 |
| Risk | `hotspot`, `areal_terbakar`, `ketebalan_gambut`, `konsesi` | 756,449 |
| Field Monitoring | `logger_tmat`, `tmat_bacaan`, `sumur_bor`, `sumur_debit`, `posko_karhutla` | 0 |
| Spatial Analysis | `unit_nasional`, `unit_target_2026`, `kontur`, `kontur_lidar` | 1,964,745 |
| Plan Review | `khg_versi`, `perubahan`, `komentar`, `pengguna`, `template_poster`, `ekspor_poster` | 866 |

# Reference

Administrative regions, KHG and companies. Shared by every other context.

```{.mermaid}
erDiagram
  provinsi ||--o{ kabupaten : provinsi_id
  kabupaten ||--o{ kecamatan : kabupaten_id
  kecamatan ||--o{ desa : kecamatan_id
  provinsi ||--o{ khg : provinsi_utama_id
  provinsi {
    smallint id PK
    text nama
    text singkatan
    text pulau
  }
  kabupaten {
    integer id PK
    smallint provinsi_id FK
    text nama
  }
  kecamatan {
    integer id PK
    integer kabupaten_id FK
    text nama
  }
  desa {
    integer id PK
    integer kecamatan_id FK
    text nama
    MultiPolygon geom
    text kode_bps
    boolean target_pemulihan_2026
  }
  khg {
    integer id PK
    text kode
    text nama
    smallint provinsi_utama_id FK
    MultiPolygon geom
    boolean target_2026
    numeric luas_ha
  }
  perusahaan {
    integer id PK
    text nama
    text izin_usaha
  }
```
<p class="figure-note">Figure 2. Reference entities.</p>

| Entity | Description | Rows |
|---|---|---:|
| `ref.provinsi` | Province (38 rows, official Ministry of Home Affairs codes as primary key). | 38 |
| `ref.kabupaten` | Regency or city within a province. | 142 |
| `ref.kecamatan` | District within a regency. | 892 |
| `ref.desa` | Village. The 2,004 target villages for 2026 carry a boundary polygon. | 5,860 |
| `ref.khg` | Peat Hydrological Unit (KHG). Boundary dissolved from national analysis units. | 866 |
| `ref.perusahaan` | Company holding a plantation, forestry or mining permit. | 1,267 |

| Parent | Child | Foreign key | Cardinality |
|---|---|---|---|
| `ref.provinsi` | `ref.kabupaten` | `provinsi_id` | 1 to many (required) |
| `ref.kabupaten` | `ref.kecamatan` | `kabupaten_id` | 1 to many (required) |
| `ref.kecamatan` | `ref.desa` | `kecamatan_id` | 1 to many (required) |
| `ref.provinsi` | `ref.khg` | `provinsi_utama_id` | 1 to many (required) |

# Infrastructure Planning

Canals, canal blocks, pumps, gates and rivers that form a KHG plan.

```{.mermaid}
erDiagram
  khg o|--o{ kanal : khg_id
  kanal o|--o{ sekat : kanal_id
  khg o|--o{ sekat : khg_id
  desa o|--o{ sekat_konteks : desa_id
  perusahaan o|--o{ sekat_konteks : perusahaan_id
  sekat ||--o{ sekat_konteks : sekat_id
  perusahaan o|--o{ sekat_bangunan : perusahaan_id
  sekat ||--o{ sekat_bangunan : sekat_id
  kanal o|--o{ pompa : kanal_id
  khg o|--o{ pompa : khg_id
  sungai o|--o{ pompa : sungai_id
  khg o|--o{ pintu_air : khg_id
  perusahaan o|--o{ pintu_air : perusahaan_id
  khg o|--o{ sungai : khg_id
  kanal {
    bigint id PK
    text kode
    smallint jenis_kanal FK
    text status FK
    MultiLineString geom
    integer khg_id FK
    text keterangan
    text sumber
    bigint id_asal
  }
  sekat {
    bigint id PK
    text kode
    text status FK
    bigint kanal_id FK
    smallint jenis_kanal FK
    Point geom
    integer khg_id FK
    bigint id_kontur_asal
    numeric panjang_kanal_m
  }
  sekat_konteks {
    bigint sekat_id PK,FK
    integer desa_id FK
    integer perusahaan_id FK
    text fungsi_kawasan FK
    text penutupan_lahan_2022 FK
    text kerusakan_eg_2024 FK
    smallint_array tahun_terbakar
    text nama_kawasan_konservasi
    text fungsi_eg_250k
  }
  sekat_bangunan {
    bigint sekat_id PK,FK
    integer perusahaan_id FK
    text kodefikasi
    text kode_rencana
    text khg_nama_asal
    text tipe
    text jenis_bangunan
    text bahan
    smallint tahun_bangun
  }
  pompa {
    bigint id PK
    text kode
    text status FK
    bigint sungai_id FK
    bigint kanal_id FK
    Point geom
    integer khg_id FK
    numeric kapasitas_m3_menit
    numeric jarak_sungai_m
  }
  pintu_air {
    bigint id PK
    text kode
    integer perusahaan_id FK
    Point geom
    integer khg_id FK
    text keterangan
    smallint tahun_bangun
    text bahan
    text pelaksana
  }
  sungai {
    bigint id PK
    text nama
    MultiLineString geom
    integer khg_id FK
  }
  desa {
    int id PK
  }
  khg {
    int id PK
  }
  perusahaan {
    int id PK
  }
```
<p class="figure-note">Figure 3. Infrastructure Planning entities.</p>

| Entity | Description | Rows |
|---|---|---:|
| `peta.kanal` | Canal segment from the 2025 OpenStreetMap seamless canal layer. Editable. | 657,621 |
| `peta.sekat` | Canal block, planned or existing. Editable. Aggregate root. | 366,371 |
| `peta.sekat_konteks` | One to one overlay context of a planned canal block (village, permit, land cover, peat, burn history). | 319,458 |
| `peta.sekat_bangunan` | One to one construction details of an existing canal block (budget, contractor, material, year). | 46,913 |
| `peta.pompa` | Planned or installed pump with suitability scores. Editable. | 0 |
| `peta.pintu_air` | Water gate. Editable. | 48 |
| `peta.sungai` | River line used as a water source for pumps. Editable. | 0 |

| Parent | Child | Foreign key | Cardinality |
|---|---|---|---|
| `ref.khg` | `peta.kanal` | `khg_id` | 0..1 to many (optional) |
| `peta.kanal` | `peta.sekat` | `kanal_id` | 0..1 to many (optional) |
| `ref.khg` | `peta.sekat` | `khg_id` | 0..1 to many (optional) |
| `ref.desa` | `peta.sekat_konteks` | `desa_id` | 0..1 to many (optional) |
| `ref.perusahaan` | `peta.sekat_konteks` | `perusahaan_id` | 0..1 to many (optional) |
| `peta.sekat` | `peta.sekat_konteks` | `sekat_id` | 1 to many (required) |
| `ref.perusahaan` | `peta.sekat_bangunan` | `perusahaan_id` | 0..1 to many (optional) |
| `peta.sekat` | `peta.sekat_bangunan` | `sekat_id` | 1 to many (required) |
| `peta.kanal` | `peta.pompa` | `kanal_id` | 0..1 to many (optional) |
| `ref.khg` | `peta.pompa` | `khg_id` | 0..1 to many (optional) |
| `peta.sungai` | `peta.pompa` | `sungai_id` | 0..1 to many (optional) |
| `ref.khg` | `peta.pintu_air` | `khg_id` | 0..1 to many (optional) |
| `ref.perusahaan` | `peta.pintu_air` | `perusahaan_id` | 0..1 to many (optional) |
| `ref.khg` | `peta.sungai` | `khg_id` | 0..1 to many (optional) |

# Risk

Fire hotspots, burned areas, peat thickness and concessions.

```{.mermaid}
erDiagram
  khg o|--o{ hotspot : khg_id
  khg o|--o{ areal_terbakar : khg_id
  khg o|--o{ ketebalan_gambut : khg_id
  khg o|--o{ konsesi : khg_id
  perusahaan o|--o{ konsesi : perusahaan_id
  hotspot {
    bigint id PK
    timestamptz waktu
    Point geom
    integer khg_id FK
    text satelit
    text instrumen
    text kepercayaan
    smallint kepercayaan_nilai
    numeric frp_mw
  }
  areal_terbakar {
    bigint id PK
    smallint_array tahun_terbakar
    MultiPolygon geom
    integer khg_id FK
    smallint frekuensi
  }
  ketebalan_gambut {
    bigint id PK
    MultiPolygon geom
    integer khg_id FK
    text kelas
    numeric tebal_min_m
    numeric tebal_max_m
  }
  konsesi {
    bigint id PK
    integer perusahaan_id FK
    MultiPolygon geom
    integer khg_id FK
    text jenis
    text sumber
  }
  khg {
    int id PK
  }
  perusahaan {
    int id PK
  }
```
<p class="figure-note">Figure 4. Risk entities.</p>

| Entity | Description | Rows |
|---|---|---:|
| `peta.hotspot` | Satellite fire hotspot (MODIS or VIIRS), January to September 2026. | 167,718 |
| `peta.areal_terbakar` | Burned area polygon with the list of burn years 2015 to 2026. | 584,723 |
| `peta.ketebalan_gambut` | Peat thickness class polygon per KHG. | 2,938 |
| `peta.konsesi` | Concession polygon per company, dissolved from analysis units. | 1,070 |

| Parent | Child | Foreign key | Cardinality |
|---|---|---|---|
| `ref.khg` | `peta.hotspot` | `khg_id` | 0..1 to many (optional) |
| `ref.khg` | `peta.areal_terbakar` | `khg_id` | 0..1 to many (optional) |
| `ref.khg` | `peta.ketebalan_gambut` | `khg_id` | 0..1 to many (optional) |
| `ref.khg` | `peta.konsesi` | `khg_id` | 0..1 to many (optional) |
| `ref.perusahaan` | `peta.konsesi` | `perusahaan_id` | 0..1 to many (optional) |

# Field Monitoring

Groundwater loggers, deep wells, fire posts and their time series.

```{.mermaid}
erDiagram
  khg o|--o{ logger_tmat : khg_id
  logger_tmat ||--o{ tmat_bacaan : logger_id
  desa o|--o{ sumur_bor : desa_id
  khg o|--o{ sumur_bor : khg_id
  sumur_bor ||--o{ sumur_debit : sumur_id
  khg o|--o{ posko_karhutla : khg_id
  logger_tmat {
    bigint id PK
    text kode
    Point geom
    integer khg_id FK
    text ext_id
  }
  tmat_bacaan {
    bigint logger_id PK,FK
    timestamptz waktu PK
    numeric tmat_m
  }
  sumur_bor {
    bigint id PK
    text kode
    integer desa_id FK
    text kondisi FK
    Point geom
    integer khg_id FK
    numeric kedalaman_m
    smallint tahun_bangun
    text pelaksana
  }
  sumur_debit {
    bigint sumur_id PK,FK
    date tanggal PK
    numeric debit_lps
    text catatan
  }
  posko_karhutla {
    bigint id PK
    text nama
    Point geom
    integer khg_id FK
    text keterangan
  }
  desa {
    int id PK
  }
  khg {
    int id PK
  }
```
<p class="figure-note">Figure 5. Field Monitoring entities.</p>

| Entity | Description | Rows |
|---|---|---:|
| `peta.logger_tmat` | Groundwater level logger location. Editable. | 0 |
| `peta.tmat_bacaan` | Groundwater depth reading per logger and timestamp. | 0 |
| `peta.sumur_bor` | Deep well. Synchronised from the external Deep Well system. Editable. | 0 |
| `peta.sumur_debit` | Daily discharge of a deep well. | 0 |
| `peta.posko_karhutla` | Forest and land fire post. Editable. | 0 |

| Parent | Child | Foreign key | Cardinality |
|---|---|---|---|
| `ref.khg` | `peta.logger_tmat` | `khg_id` | 0..1 to many (optional) |
| `peta.logger_tmat` | `peta.tmat_bacaan` | `logger_id` | 1 to many (required) |
| `ref.desa` | `peta.sumur_bor` | `desa_id` | 0..1 to many (optional) |
| `ref.khg` | `peta.sumur_bor` | `khg_id` | 0..1 to many (optional) |
| `peta.sumur_bor` | `peta.sumur_debit` | `sumur_id` | 1 to many (required) |
| `ref.khg` | `peta.posko_karhutla` | `khg_id` | 0..1 to many (optional) |

# Spatial Analysis

Read-only analysis units and contour lines.

```{.mermaid}
erDiagram
  desa o|--o{ unit_target_2026 : desa_id
  khg o|--o{ unit_target_2026 : khg_id
  perusahaan o|--o{ unit_target_2026 : perusahaan_id
  khg o|--o{ kontur : khg_id
  khg o|--o{ kontur_lidar : khg_id
  unit_nasional {
    bigint id PK
    smallint_array tahun_terbakar
    MultiPolygon geom
    integer khg_id
    integer desa_id
    integer perusahaan_id
    smallint jenis_kanal
    text nama_kawasan_konservasi
    text fungsi_kawasan
  }
  unit_target_2026 {
    bigint id PK
    integer khg_id FK
    integer desa_id FK
    integer perusahaan_id FK
    smallint jenis_kanal FK
    text fungsi_kawasan FK
    text penutupan_lahan_2022 FK
    text kerusakan_eg_2024 FK
    smallint_array tahun_terbakar
  }
  kontur {
    bigint id PK
    integer khg_id FK
    MultiLineString geom
    numeric elevasi_m
  }
  kontur_lidar {
    bigint id PK
    integer khg_id FK
    MultiLineString geom
    numeric elevasi_m
  }
  desa {
    int id PK
  }
  khg {
    int id PK
  }
  perusahaan {
    int id PK
  }
```
<p class="figure-note">Figure 6. Spatial Analysis entities.</p>

| Entity | Description | Rows |
|---|---|---:|
| `analisis.unit_nasional` | National analysis unit (overlay of KHG, village, permit, forest function, peat and burn history). | 989,398 |
| `analisis.unit_target_2026` | Analysis unit inside the 2,004 target villages for 2026. | 789,336 |
| `analisis.kontur` | Contour line from WorldDEM for 108 BRGM target KHG. | 159,043 |
| `analisis.kontur_lidar` | Contour line at 50 cm interval from LiDAR (Riau, Jambi, South Sumatra). | 26,968 |

| Parent | Child | Foreign key | Cardinality |
|---|---|---|---|
| `ref.desa` | `analisis.unit_target_2026` | `desa_id` | 0..1 to many (optional) |
| `ref.khg` | `analisis.unit_target_2026` | `khg_id` | 0..1 to many (optional) |
| `ref.perusahaan` | `analisis.unit_target_2026` | `perusahaan_id` | 0..1 to many (optional) |
| `ref.khg` | `analisis.kontur` | `khg_id` | 0..1 to many (optional) |
| `ref.khg` | `analisis.kontur_lidar` | `khg_id` | 0..1 to many (optional) |

# Plan Review

Plan versions, change records, comments and poster exports.

```{.mermaid}
erDiagram
  khg ||--o{ khg_versi : khg_id
  khg o|--o{ perubahan : khg_id
  khg_versi o|--o{ perubahan : versi_id
  komentar o|--o{ komentar : parent_id
  khg_versi ||--o{ komentar : versi_id
  template_poster ||--o{ ekspor_poster : template_id
  khg_versi ||--o{ ekspor_poster : versi_id
  khg_versi {
    bigint id PK
    integer khg_id FK
    text status FK
    integer nomor
    timestamptz dibuat_at
    text diajukan_oleh
    timestamptz diajukan_at
    text reviewer
    timestamptz diputuskan_at
  }
  perubahan {
    bigint id PK
    timestamptz waktu
    integer khg_id FK
    bigint versi_id FK
    text tabel
    bigint fitur_id
    character aksi
    text via
    text pengguna
  }
  komentar {
    bigint id PK
    bigint versi_id FK
    bigint parent_id FK
    text tabel
    bigint fitur_id
    text pengguna
    text isi
    boolean selesai
  }
  pengguna {
    integer id PK
    text nama
    text username
    text instansi
    text peran
  }
  template_poster {
    integer id PK
    text nama
    text versi
    text file_path
    boolean aktif
  }
  ekspor_poster {
    bigint id PK
    bigint versi_id FK
    integer template_id FK
    text status
    uuid batch_id
    text kertas
    text orientasi
    date periode_mulai
    date periode_selesai
  }
  khg {
    int id PK
  }
```
<p class="figure-note">Figure 7. Plan Review entities.</p>

| Entity | Description | Rows |
|---|---|---:|
| `alur.khg_versi` | Plan version of a KHG. Aggregate root of the review workflow. | 866 |
| `alur.perubahan` | Change record written by the audit trigger for every create, update and delete. | 0 |
| `alur.komentar` | Review comment on a version or on a single feature, with threaded replies. | 0 |
| `alur.pengguna` | Application user profile (name, agency, role). | 0 |
| `alur.template_poster` | Poster layout template (QGIS print layout file). | 0 |
| `alur.ekspor_poster` | Poster export job with paper size, progress and output file. | 0 |

| Parent | Child | Foreign key | Cardinality |
|---|---|---|---|
| `ref.khg` | `alur.khg_versi` | `khg_id` | 1 to many (required) |
| `ref.khg` | `alur.perubahan` | `khg_id` | 0..1 to many (optional) |
| `alur.khg_versi` | `alur.perubahan` | `versi_id` | 0..1 to many (optional) |
| `alur.komentar` | `alur.komentar` | `parent_id` | 0..1 to many (optional) |
| `alur.khg_versi` | `alur.komentar` | `versi_id` | 1 to many (required) |
| `alur.template_poster` | `alur.ekspor_poster` | `template_id` | 1 to many (required) |
| `alur.khg_versi` | `alur.ekspor_poster` | `versi_id` | 1 to many (required) |

# Code lists

Code lists are small reference tables. They are used as foreign keys instead of PostgreSQL ENUM types, so QGIS can show them as drop-down lists and new values need only an INSERT.

| Code list | Rows | Used by |
|---|---:|---|
| `ref.fungsi_kawasan` | 14 | `analisis.unit_target_2026.fungsi_kawasan`, `peta.sekat_konteks.fungsi_kawasan` |
| `ref.jenis_kanal` | 3 | `analisis.unit_target_2026.jenis_kanal`, `peta.kanal.jenis_kanal`, `peta.sekat.jenis_kanal` |
| `ref.kerusakan_eg` | 5 | `analisis.unit_target_2026.kerusakan_eg_2024`, `peta.sekat_konteks.kerusakan_eg_2024` |
| `ref.kondisi_sumur` | 3 | `peta.sumur_bor.kondisi` |
| `ref.penutupan_lahan` | 26 | `analisis.unit_target_2026.penutupan_lahan_2022`, `peta.sekat_konteks.penutupan_lahan_2022` |
| `ref.status_alur` | 5 | `alur.khg_versi.status` |
| `ref.status_kanal` | 3 | `peta.kanal.status` |
| `ref.status_pompa` | 3 | `peta.pompa.status` |
| `ref.status_sekat` | 4 | `peta.sekat.status` |

# Public read model

The `api` schema contains views over the entities above. They join names from the reference context so that API users see readable values instead of ids. They have no relationships of their own.

| View | Built from | Description |
|---|---|---|
| `api.khg_statistik` | hotspot, kanal, sekat, analysis units | Materialized view: expensive KHG statistics, refreshed daily. |
| `api.areal_terbakar` | peta or analisis table of the same name | Public view published as OGC API collection. Readable names instead of foreign keys. |
| `api.desa` | ref.desa and regions | Public view published as OGC API collection. Readable names instead of foreign keys. |
| `api.hotspot` | peta or analisis table of the same name | Public view published as OGC API collection. Readable names instead of foreign keys. |
| `api.kanal` | peta.kanal and code lists | Public view published as OGC API collection. Readable names instead of foreign keys. |
| `api.ketebalan_gambut` | peta or analisis table of the same name | Public view published as OGC API collection. Readable names instead of foreign keys. |
| `api.khg` | ref.khg, alur.v_khg_status, api.khg_statistik | Public view published as OGC API collection. Readable names instead of foreign keys. |
| `api.konsesi` | peta or analisis table of the same name | Public view published as OGC API collection. Readable names instead of foreign keys. |
| `api.kontur` | peta or analisis table of the same name | Public view published as OGC API collection. Readable names instead of foreign keys. |
| `api.kontur_lidar` | peta or analisis table of the same name | Public view published as OGC API collection. Readable names instead of foreign keys. |
| `api.sekat` | peta.sekat, sekat_konteks, sekat_bangunan | Public view published as OGC API collection. Readable names instead of foreign keys. |
| `api.sumur_bor` | peta or analisis table of the same name | Public view published as OGC API collection. Readable names instead of foreign keys. |
| `api.unit_nasional` | peta or analisis table of the same name | Public view published as OGC API collection. Readable names instead of foreign keys. |
| `api.unit_target_2026` | peta or analisis table of the same name | Public view published as OGC API collection. Readable names instead of foreign keys. |
