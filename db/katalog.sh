#!/usr/bin/env bash
# Tulis docs/01b_KATALOG_TABEL.md dari DB (jumlah baris, ukuran, komentar kolom geometri).
set -euo pipefail
cd "$(dirname "$0")"
set -a; . ./.env; set +a
export PGHOST=localhost PGPORT=5433 PGUSER=postgres PGDATABASE=gambut PGPASSWORD=$POSTGRES_PASSWORD
OUT=../docs/01b_KATALOG_TABEL.md
{
  echo "# Katalog Tabel"
  echo
  echo "Dibuat otomatis oleh \`db/katalog.sh\` pada $(date '+%Y-%m-%d %H:%M'). Ukuran DB: **$(psql -tAc "SELECT pg_size_pretty(pg_database_size('gambut'))")**."
  echo
  echo "| Schema | Tabel | Jenis | Geometri | Baris | Ukuran (data+index) | Kolom |"
  echo "|---|---|---|---|---:|---:|---:|"
  psql -tA -F ' | ' <<'SQL'
SELECT '| ' || n.nspname, c.relname,
       CASE c.relkind WHEN 'r' THEN 'tabel' WHEN 'v' THEN 'view' WHEN 'm' THEN 'mat. view' END,
       coalesce((SELECT type || ' ' || srid FROM geometry_columns g
                  WHERE g.f_table_schema = n.nspname AND g.f_table_name = c.relname LIMIT 1), '—'),
       CASE WHEN c.relkind IN ('r','m') THEN to_char((xpath('/row/n/text()', query_to_xml(
         format('SELECT count(*) AS n FROM %I.%I', n.nspname, c.relname), false, true, '')))[1]::text::bigint,
         'FM999G999G999') ELSE '—' END,   -- hitung pasti, bukan estimasi planner
       CASE WHEN c.relkind IN ('r','m') THEN pg_size_pretty(pg_total_relation_size(c.oid)) ELSE '—' END,
       (SELECT count(*) FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped) || ' |'
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname IN ('ref','peta','analisis','alur','api') AND c.relkind IN ('r','v','m')
 ORDER BY array_position(ARRAY['ref','peta','analisis','alur','api'], n.nspname::text), c.relkind, c.relname;
SQL
} > "$OUT"
echo "ditulis: $OUT"
