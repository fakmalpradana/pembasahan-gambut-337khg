#!/usr/bin/env bash
# Salin semua data sumber mentah ke schema staging (ogr2ogr, paralel). Dipanggil oleh setup.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
PG="PG:host=${PGHOST} port=${PGPORT} dbname=${PGDATABASE} user=${PGUSER} password=${PGPASSWORD}"
GDB="Data Spasial Pemulihan Ekosistem Gambut (April, 2026)/Target_BlueBook_Pemulihan_Ekosistem_Gambut_2026.gdb"
psql -q -c "DROP SCHEMA IF EXISTS staging CASCADE; CREATE SCHEMA staging"

stage() {  # stage <sumber> <layer> <tabel>
  ogr2ogr -f PostgreSQL "$PG" "$1" "$2" -nln "staging.$3" -t_srs EPSG:4326 -dim XY \
    -lco GEOMETRY_NAME=geom -lco FID=ogc_fid -lco SPATIAL_INDEX=NONE -lco UNLOGGED=ON \
    -nlt PROMOTE_TO_MULTI -gt 100000 --config PG_USE_COPY YES
  echo "  staged $3"
}
stage output/sekat_kanal_brgm_ppeg_2026.gpkg sekat_kanal sekat_kanal &
stage output/hotspot_2026.gpkg hotspot hotspot &
stage "$GDB" AOI_2004_Desa__Target_Pemulihan_Ekosistem_Gambut__April_2026 aoi_desa &
stage "$GDB" Infrastruktur_Hidrologis_PPEG_BRGM_Indonesia infrastruktur &
wait
stage "$GDB" ALL_Analysis_Integrasi_Tematik__PPEG_Indonesia__April_2026 unit_nasional &
stage "$GDB" Analysis_2004_Desa__Target_Pemulihan_Ekosistem_Gambut__April_2026 unit_target &
stage "$GDB" SEAMLESS__Kanal_OSM_KHG__INDONESIA__2025 kanal_osm &
stage "__ Burnscare Areas (2015-2026)/ALL__BA_2015_2026__INDONESIA.shp" ALL__BA_2015_2026__INDONESIA burnscar &
wait
stage "$GDB" Kontur_108_KHG_Target_BRGM kontur &
stage "$GDB" LIDAR_Kontur_50cm__RIAU_JAMBI_SUMSEL kontur_lidar &
wait
