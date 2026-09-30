#!/usr/bin/env bash
# Cron di server: dump harian (simpan 7 hari) + refresh statistik KHG.
set -euo pipefail
cd /srv/gambut/db
f=/srv/backup/gambut_$(date +%F).dump
docker compose exec -T db pg_dump -U postgres -Fc -Z 6 gambut > "$f.tmp" && mv "$f.tmp" "$f"
find /srv/backup -name 'gambut_*.dump' -mtime +7 -delete
docker compose exec -T db psql -U postgres -d gambut -qtAc "SELECT api.refresh_statistik()" >/dev/null
echo "$(date -Is) backup ok $(du -h "$f" | cut -f1)"
