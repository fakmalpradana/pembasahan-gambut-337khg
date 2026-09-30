-- Tahap 5: isi khg_id secara spasial, kode per KHG, relasi sekat->kanal, versi awal, QC.
BEGIN;
SET LOCAL session_replication_role = replica;

-- batas KHG dipecah kecil agar point-in-polygon cepat
CREATE TABLE staging.khg_sub AS
SELECT id AS khg_id, ST_Subdivide(geom, 256) AS geom FROM ref.khg WHERE geom IS NOT NULL;
CREATE INDEX ON staging.khg_sub USING gist (geom);
ANALYZE staging.khg_sub;

-- titik wakil tiap fitur -> KHG yang memuatnya
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('peta.kanal',            'ST_LineInterpolatePoint(ST_GeometryN(t.geom, 1), 0.5)'),
      ('peta.hotspot',          't.geom'),
      ('peta.areal_terbakar',   'ST_PointOnSurface(t.geom)'),
      ('peta.sekat',            't.geom'),
      ('peta.pintu_air',        't.geom'),
      ('peta.konsesi',          'ST_PointOnSurface(t.geom)'),
      ('analisis.kontur',       'ST_LineInterpolatePoint(ST_GeometryN(t.geom, 1), 0.5)'),
      ('analisis.kontur_lidar', 'ST_LineInterpolatePoint(ST_GeometryN(t.geom, 1), 0.5)')
    ) v (tabel, titik)
  LOOP
    EXECUTE format('UPDATE %s t SET khg_id = s.khg_id FROM staging.khg_sub s
                     WHERE t.khg_id IS NULL AND ST_Intersects(s.geom, %s)', r.tabel, r.titik);
  END LOOP;
END $$;

-- kode kanal K-n per KHG
UPDATE peta.kanal k SET kode = 'K-' || r.n
  FROM (SELECT id, row_number() OVER (PARTITION BY khg_id ORDER BY id) n
          FROM peta.kanal WHERE khg_id IS NOT NULL) r
 WHERE k.id = r.id;

-- kode sekat existing melanjutkan nomor SK-n per KHG
UPDATE peta.sekat s SET kode = 'SK-' || (coalesce(b.m, 0) + r.n)
  FROM (SELECT id, khg_id, row_number() OVER (PARTITION BY khg_id ORDER BY id) n
          FROM peta.sekat WHERE kode IS NULL AND khg_id IS NOT NULL) r
  LEFT JOIN (SELECT khg_id, max(substring(kode FROM '\d+$')::int) m
               FROM peta.sekat WHERE kode IS NOT NULL GROUP BY 1) b ON b.khg_id = r.khg_id
 WHERE s.id = r.id;

-- sekat -> kanal terdekat (rencana: titik ada di garis kanal, toleransi ~2 m;
--                          existing: koordinat GPS, toleransi ~30 m)
UPDATE peta.sekat s SET kanal_id = (
  SELECT k.id FROM peta.kanal k
   WHERE ST_DWithin(k.geom, s.geom, CASE WHEN s.sumber = 'BRGM_PPEG_2026' THEN 0.00002 ELSE 0.0003 END)
   ORDER BY k.geom <-> s.geom LIMIT 1);

-- versi awal v1 (draft) untuk setiap KHG
INSERT INTO alur.khg_versi (khg_id, nomor) SELECT id, 1 FROM ref.khg;

COMMIT;

DROP SCHEMA staging CASCADE;
VACUUM ANALYZE;

-- ringkasan QC
SELECT 'khg' AS objek, count(*) AS n, count(*) FILTER (WHERE geom IS NOT NULL) AS dengan_geom FROM ref.khg
UNION ALL SELECT 'khg target 2026', count(*), NULL FROM ref.khg WHERE target_2026
UNION ALL SELECT 'desa', count(*), count(*) FILTER (WHERE geom IS NOT NULL) FROM ref.desa
UNION ALL SELECT 'sekat rencana', count(*), count(kanal_id) FROM peta.sekat WHERE sumber = 'BRGM_PPEG_2026'
UNION ALL SELECT 'sekat infrastruktur', count(*), count(kanal_id) FROM peta.sekat WHERE sumber <> 'BRGM_PPEG_2026'
UNION ALL SELECT 'kanal', count(*), count(khg_id) FROM peta.kanal
UNION ALL SELECT 'pintu air', count(*), count(khg_id) FROM peta.pintu_air
UNION ALL SELECT 'hotspot', count(*), count(khg_id) FROM peta.hotspot
UNION ALL SELECT 'areal terbakar', count(*), count(khg_id) FROM peta.areal_terbakar
UNION ALL SELECT 'konsesi', count(*), NULL FROM peta.konsesi
UNION ALL SELECT 'ketebalan gambut', count(*), NULL FROM peta.ketebalan_gambut
UNION ALL SELECT 'unit target 2026', count(*), count(khg_id) FROM analisis.unit_target_2026
UNION ALL SELECT 'unit nasional', count(*), count(khg_id) FROM analisis.unit_nasional
UNION ALL SELECT 'kontur', count(*), count(khg_id) FROM analisis.kontur
UNION ALL SELECT 'kontur lidar', count(*), count(khg_id) FROM analisis.kontur_lidar;
