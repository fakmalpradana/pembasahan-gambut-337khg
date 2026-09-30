-- Smoke test CRUD + audit + alur versi. Semua di dalam transaksi, di-ROLLBACK di akhir.
--   psql -f db/tests.sql
-- ON_ERROR_STOP dipasang di sini: tanpa itu, error pada BEGIN membuat sisa skrip ter-commit.
\set ON_ERROR_STOP on
\set QUIET on
BEGIN;
CREATE TEMP TABLE t AS
SELECT k.id AS khg, v.id AS v1,
       ST_Multi(ST_ConvexHull(ST_Collect(s.geom)))::geometry(MultiPolygon,4326) AS hull
  FROM ref.khg k JOIN alur.khg_versi v ON v.khg_id = k.id JOIN peta.sekat s ON s.khg_id = k.id
 WHERE k.nama = 'KHG Sungai Matan - Sungai Rantaupanjang' GROUP BY k.id, v.id;
DO $$ BEGIN ASSERT (SELECT count(*) FROM t) = 1, 'KHG uji tidak ditemukan'; END $$;
UPDATE ref.khg SET geom = (SELECT hull FROM t) WHERE id = (SELECT khg FROM t);

-- ============ edit sebagai Web
SET LOCAL app.via = 'web';
SET LOCAL app.pengguna = 'd.putri';
-- data pendukung (khg_id sengaja kosong -> harus terisi otomatis dari geometri)
INSERT INTO peta.sungai (nama, geom)
SELECT 'Sungai Uji', ST_Multi(ST_MakeLine(ST_PointN(ST_ExteriorRing(ST_GeometryN(hull,1)),1),
                                          ST_Centroid(hull))) FROM t;
INSERT INTO peta.kanal (kode, jenis_kanal, status, geom)
SELECT 'K-01', 1, 'aktif', ST_Multi(ST_MakeLine(ST_Centroid(hull),
        ST_PointN(ST_ExteriorRing(ST_GeometryN(hull,1)),1))) FROM t;
INSERT INTO peta.kanal (jenis_kanal, status, keterangan, geom)   -- tanpa kode & status
SELECT 3, NULL, 'uji', ST_Multi(ST_MakeLine(ST_Centroid(hull), ST_Translate(ST_Centroid(hull), 0.01, 0))) FROM t;
INSERT INTO peta.ketebalan_gambut (kelas, tebal_min_m, tebal_max_m, geom) SELECT '4-5 m', 4, 5, hull FROM t;
INSERT INTO peta.areal_terbakar (tahun_terbakar, geom) SELECT '{2019}', hull FROM t;
INSERT INTO peta.pompa (geom)                                   -- kode & khg_id otomatis
SELECT ST_Centroid(hull) FROM t;

DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM peta.pompa WHERE khg_id = (SELECT khg FROM t);
  ASSERT r.kode = 'P-1', format('kode otomatis salah: %s', r.kode);
  ASSERT r.updated_via = 'web' AND r.created_by = 'd.putri', 'meta web salah';
  -- kode melanjutkan nomor kanal OSM yang sudah ada di KHG ini
  ASSERT (SELECT kode FROM peta.kanal WHERE keterangan = 'uji') =
         'K-' || ((SELECT count(*) FROM peta.kanal WHERE khg_id = r.khg_id AND sumber = 'OSM_2025') + 1),
         'kode kanal otomatis';
END $$;

UPDATE peta.kanal SET status = 'aktif', keterangan = 'survei lapangan Sep 2026'
 WHERE keterangan = 'uji';
UPDATE peta.sekat SET geom = ST_Translate(geom, 0, 0.0016)          -- geser ±180 m ke utara
 WHERE id = (SELECT min(id) FROM peta.sekat WHERE khg_id = (SELECT khg FROM t));
UPDATE peta.sekat SET status = status                               -- no-op: tidak boleh tercatat
 WHERE id = (SELECT max(id) FROM peta.sekat WHERE khg_id = (SELECT khg FROM t));
DELETE FROM peta.sekat WHERE id = (SELECT max(id) FROM peta.sekat WHERE khg_id = (SELECT khg FROM t));

DO $$
DECLARE n int; bad int; rev int;
BEGIN
  SELECT count(*), count(*) FILTER (WHERE versi_id <> (SELECT v1 FROM t) OR via <> 'web' OR pengguna <> 'd.putri')
    INTO n, bad FROM alur.perubahan WHERE khg_id = (SELECT khg FROM t);
  -- sungai, kanal x2, pompa (I) + kanal (U) + sekat geser (U) + sekat hapus (D) = 7; ketebalan/terbakar tidak diaudit
  ASSERT n = 7, format('jumlah perubahan %s, harap 7', n);
  ASSERT bad = 0, 'ada perubahan dengan versi/via/pengguna salah';
  SELECT s.rev INTO rev FROM peta.sekat s WHERE id = (SELECT min(id) FROM peta.sekat WHERE khg_id = (SELECT khg FROM t));
  ASSERT rev = 2, format('rev harus 2, dapat %s', rev);
END $$;

-- ============ validasi + review
\echo '--- validasi_khg'
SELECT cek, tingkat, lolos, pesan FROM alur.validasi_khg((SELECT v1 FROM t));
DO $$ BEGIN
  ASSERT NOT (SELECT lolos FROM alur.validasi_khg((SELECT v1 FROM t)) WHERE cek = 'pompa_kapasitas'), 'kapasitas harus gagal';
  -- kanal OSM hasil impor belum punya status survei -> cek ini memang harus gagal
  ASSERT NOT (SELECT lolos FROM alur.validasi_khg((SELECT v1 FROM t)) WHERE cek = 'kanal_berstatus'), 'kanal OSM belum berstatus';
  ASSERT (SELECT lolos FROM alur.validasi_khg((SELECT v1 FROM t)) WHERE cek = 'pompa_dekat_air'), 'pompa dekat air';
END $$;

\echo '--- saran_lokasi_pompa'
SELECT peringkat, skor, skor_sumber_air, skor_kanal, skor_gambut, skor_terbakar, jarak_sungai_m, kanal_id
  FROM peta.saran_lokasi_pompa((SELECT khg FROM t));
DO $$ BEGIN
  ASSERT (SELECT count(*) FROM peta.saran_lokasi_pompa((SELECT khg FROM t))) >= 1, 'saran lokasi kosong';
END $$;

SELECT alur.ajukan_review((SELECT v1 FROM t));
SET LOCAL app.pengguna = 'reviewer.klh';
SELECT alur.putuskan((SELECT v1 FROM t), 'approved', 'Lengkapi kapasitas P-1 sebelum dicetak.');

-- ============ edit sebagai QGIS setelah approved -> versi baru v2 otomatis
RESET app.via;
RESET app.pengguna;
UPDATE peta.pompa SET kapasitas_m3_menit = 100 WHERE khg_id = (SELECT khg FROM t);
DO $$
DECLARE r record;
BEGIN
  SELECT v.nomor, v.status, p.via INTO r
    FROM alur.perubahan p JOIN alur.khg_versi v ON v.id = p.versi_id
   WHERE p.tabel = 'pompa' AND p.aksi = 'U' AND p.khg_id = (SELECT khg FROM t);
  ASSERT r.nomor = 2 AND r.status = 'draft' AND r.via = 'qgis', format('versi baru salah: %s', r);
  ASSERT (SELECT validasi IS NOT NULL FROM alur.khg_versi WHERE id = (SELECT v1 FROM t)), 'snapshot validasi';
END $$;

-- ============ ekspor poster selesai -> v1 printed
INSERT INTO alur.template_poster (nama, versi, file_path) VALUES ('Poster Pembasahan', 'v3', 'templates/poster_v3.qpt');
INSERT INTO alur.ekspor_poster (versi_id, template_id, kertas, orientasi)
SELECT v1, currval(pg_get_serial_sequence('alur.template_poster','id')), 'A0', 'lanskap' FROM t;
UPDATE alur.ekspor_poster SET status = 'selesai', progres = 100, ukuran_bytes = 184549376
 WHERE versi_id = (SELECT v1 FROM t);
DO $$ BEGIN
  ASSERT (SELECT status FROM alur.khg_versi WHERE id = (SELECT v1 FROM t)) = 'printed', 'harus printed';
END $$;

-- ============ view UI
\echo '--- v_khg_daftar (KHG uji)'
SELECT kode, nama, provinsi, luas_ha, hotspot_30h, pompa, kanal_aktif_km, sekat, versi, status,
       diubah_via, skor_prioritas
  FROM alur.v_khg_daftar WHERE id = (SELECT khg FROM t);
\echo '--- v_khg_legenda (KHG uji)'
SELECT layer, jumlah FROM peta.v_khg_legenda WHERE khg_id = (SELECT khg FROM t) ORDER BY layer;
\echo '--- v_dashboard'
\x on
SELECT * FROM alur.v_dashboard;
\x off
DO $$ BEGIN ASSERT (SELECT khg_disetujui FROM alur.v_dashboard) = 1, 'KHG disetujui harus 1'; END $$;
\echo 'SEMUA TES LOLOS'
ROLLBACK;
