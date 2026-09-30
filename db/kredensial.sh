#!/usr/bin/env bash
# Tulis docs/KREDENSIAL.md dari db/.env (RAHASIA — jangan di-commit / dibagikan publik).
set -euo pipefail
cd "$(dirname "$0")"
set -a; . ./.env; set +a
OUT=../docs/KREDENSIAL.md
umask 077
cat > "$OUT" <<MD
# KREDENSIAL — RAHASIA
Dibuat $(date '+%Y-%m-%d %H:%M') dari \`db/.env\`. Jangan di-commit, jangan dikirim lewat kanal publik.
Setelah deploy produksi, **ganti semua password** (jalankan ulang \`09_roles.sql\` dengan nilai baru).

## Database PostgreSQL (lokal)
Host \`localhost\` · Port \`5433\` · Database \`gambut\`

| Role | Password | Kegunaan | String koneksi |
|---|---|---|---|
| postgres | \`${POSTGRES_PASSWORD}\` | superuser/DBA | \`postgresql://postgres:${POSTGRES_PASSWORD}@localhost:5433/gambut\` |
| ogc_reader | \`${PW_OGC_READER}\` | baca-saja (pygeoapi, analis, BI) | \`postgresql://ogc_reader:${PW_OGC_READER}@localhost:5433/gambut\` |
| ogc_writer | \`${PW_OGC_WRITER}\` | pygeoapi transaksi | \`postgresql://ogc_writer:${PW_OGC_WRITER}@localhost:5433/gambut\` |
| web_app | \`${PW_WEB_APP}\` | backend aplikasi web | \`postgresql://web_app:${PW_WEB_APP}@localhost:5433/gambut\` |
| editor_qgis | \`${PW_EDITOR_QGIS}\` | editor QGIS (contoh) | \`postgresql://editor_qgis:${PW_EDITOR_QGIS}@localhost:5433/gambut\` |

## OGC API (pygeoapi di balik Caddy)
URL \`http://localhost:8080\` — GET publik tanpa login.

| Akun | Username | Password | Kegunaan |
|---|---|---|---|
| Basic Auth API | \`${API_ADMIN_USER}\` | \`${API_ADMIN_PASSWORD}\` | POST/PUT/PATCH/DELETE item & proses tulis |

Contoh: \`curl -u ${API_ADMIN_USER}:${API_ADMIN_PASSWORD} -X DELETE http://localhost:8080/collections/pompa/items/1\`
MD
echo "ditulis: $OUT"
