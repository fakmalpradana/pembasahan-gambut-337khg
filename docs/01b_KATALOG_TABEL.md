# Katalog Tabel

Dibuat otomatis oleh `db/katalog.sh` pada 2026-09-30 20:25. Ukuran DB: **7009 MB**.

| Schema | Tabel | Jenis | Geometri | Baris | Ukuran (data+index) | Kolom |
|---|---|---|---|---:|---:|---:|
| ref | desa | tabel | MULTIPOLYGON 4326 | 5,860 | 18 MB | 6 |
| ref | fungsi_kawasan | tabel | — | 14 | 64 kB | 2 |
| ref | jenis_kanal | tabel | — | 3 | 80 kB | 2 |
| ref | kabupaten | tabel | — | 142 | 80 kB | 3 |
| ref | kecamatan | tabel | — | 892 | 176 kB | 3 |
| ref | kerusakan_eg | tabel | — | 5 | 64 kB | 2 |
| ref | khg | tabel | MULTIPOLYGON 4326 | 866 | 53 MB | 7 |
| ref | kondisi_sumur | tabel | — | 3 | 64 kB | 3 |
| ref | penutupan_lahan | tabel | — | 26 | 64 kB | 1 |
| ref | perusahaan | tabel | — | 1,267 | 256 kB | 3 |
| ref | provinsi | tabel | — | 38 | 80 kB | 4 |
| ref | status_alur | tabel | — | 5 | 64 kB | 4 |
| ref | status_kanal | tabel | — | 3 | 64 kB | 3 |
| ref | status_pompa | tabel | — | 3 | 64 kB | 3 |
| ref | status_sekat | tabel | — | 4 | 64 kB | 3 |
| peta | areal_terbakar | tabel | MULTIPOLYGON 4326 | 584,723 | 652 MB | 11 |
| peta | hotspot | tabel | POINT 4326 | 167,718 | 65 MB | 23 |
| peta | kanal | tabel | MULTILINESTRING 4326 | 657,621 | 709 MB | 16 |
| peta | ketebalan_gambut | tabel | MULTIPOLYGON 4326 | 2,938 | 128 MB | 12 |
| peta | konsesi | tabel | MULTIPOLYGON 4326 | 1,070 | 18 MB | 12 |
| peta | logger_tmat | tabel | POINT 4326 | 0 | 48 kB | 11 |
| peta | pintu_air | tabel | POINT 4326 | 48 | 96 kB | 16 |
| peta | pompa | tabel | POINT 4326 | 0 | 72 kB | 21 |
| peta | posko_karhutla | tabel | POINT 4326 | 0 | 32 kB | 11 |
| peta | sekat | tabel | POINT 4326 | 366,371 | 273 MB | 19 |
| peta | sekat_bangunan | tabel | — | 46,913 | 6400 kB | 20 |
| peta | sekat_konteks | tabel | — | 319,458 | 122 MB | 24 |
| peta | sumur_bor | tabel | POINT 4326 | 0 | 48 kB | 19 |
| peta | sumur_debit | tabel | — | 0 | 16 kB | 4 |
| peta | sungai | tabel | MULTILINESTRING 4326 | 0 | 56 kB | 10 |
| peta | tmat_bacaan | tabel | — | 0 | 8192 bytes | 3 |
| peta | v_khg_legenda | view | — | — | — | 3 |
| peta | v_sekat | view | POINT 4326 | — | — | 28 |
| peta | v_sumur_bor | view | POINT 4326 | — | — | 14 |
| peta | v_tmat_alert | view | POINT 4326 | — | — | 6 |
| analisis | kontur | tabel | MULTILINESTRING 4326 | 159,043 | 2338 MB | 4 |
| analisis | kontur_lidar | tabel | MULTILINESTRING 4326 | 26,968 | 231 MB | 4 |
| analisis | unit_nasional | tabel | MULTIPOLYGON 4326 | 989,398 | 1400 MB | 27 |
| analisis | unit_target_2026 | tabel | MULTIPOLYGON 4326 | 789,336 | 970 MB | 27 |
| alur | ekspor_poster | tabel | — | 0 | 64 kB | 17 |
| alur | khg_versi | tabel | — | 866 | 224 kB | 11 |
| alur | komentar | tabel | — | 0 | 32 kB | 9 |
| alur | pengguna | tabel | — | 0 | 24 kB | 5 |
| alur | perubahan | tabel | — | 0 | 80 kB | 11 |
| alur | template_poster | tabel | — | 0 | 32 kB | 5 |
| alur | v_dashboard | view | — | — | — | 14 |
| alur | v_khg_daftar | view | — | — | — | 20 |
| alur | v_khg_status | view | — | — | — | 9 |
| api | khg_statistik | mat. view | — | 866 | 184 kB | 9 |
| api | areal_terbakar | view | MULTIPOLYGON 4326 | — | — | 6 |
| api | desa | view | MULTIPOLYGON 4326 | — | — | 8 |
| api | hotspot | view | POINT 4326 | — | — | 12 |
| api | kanal | view | MULTILINESTRING 4326 | — | — | 8 |
| api | ketebalan_gambut | view | MULTIPOLYGON 4326 | — | — | 6 |
| api | khg | view | MULTIPOLYGON 4326 | — | — | 25 |
| api | konsesi | view | MULTIPOLYGON 4326 | — | — | 5 |
| api | kontur | view | MULTILINESTRING 4326 | — | — | 4 |
| api | kontur_lidar | view | MULTILINESTRING 4326 | — | — | 4 |
| api | sekat | view | POINT 4326 | — | — | 27 |
| api | sumur_bor | view | POINT 4326 | — | — | 14 |
| api | unit_nasional | view | MULTIPOLYGON 4326 | — | — | 24 |
| api | unit_target_2026 | view | MULTIPOLYGON 4326 | — | — | 24 |
