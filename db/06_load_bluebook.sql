-- Tahap 3: data BlueBook PPEG, kanal OSM, infrastruktur, hotspot, areal terbakar, kontur.
-- khg_id untuk layer non-unit diisi di 08_finalisasi.sql (setelah batas KHG di-dissolve).
BEGIN;
SET LOCAL session_replication_role = replica;

CREATE OR REPLACE FUNCTION staging.valid(g geometry) RETURNS geometry(MultiPolygon,4326)
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN ST_IsValid(g) THEN ST_Multi(g)
              ELSE ST_Multi(ST_CollectionExtract(ST_MakeValid(g), 3)) END $$;

-- dissolve: ST_CoverageUnion (cepat) dengan fallback ST_Union bila gagal/tidak valid
CREATE OR REPLACE FUNCTION staging.dissolve(q text) RETURNS geometry(MultiPolygon,4326)
LANGUAGE plpgsql AS $$
DECLARE g geometry;
BEGIN
  BEGIN
    EXECUTE 'SELECT ST_CoverageUnion(geom) FROM (' || q || ') x' INTO g;
  EXCEPTION WHEN others THEN g := NULL;
  END;
  IF g IS NULL OR NOT ST_IsValid(g) THEN
    EXECUTE 'SELECT ST_Union(geom) FROM (' || q || ') x' INTO g;
  END IF;
  RETURN ST_Multi(ST_CollectionExtract(g, 3));
END $$;

-- kelas tebal gambut -> {min_m, max_m}; "4.0 - 4.5 meter", "100 - <200 cm", ">= 700 cm"
CREATE OR REPLACE FUNCTION staging.tebal(kelas text) RETURNS numeric[]
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN kelas ~ '^>=' THEN ARRAY[(regexp_match(kelas, '([\d.]+)'))[1]::numeric
                                  / CASE WHEN kelas ~ 'cm' THEN 100 ELSE 1 END, NULL]
    ELSE (SELECT ARRAY[m[1]::numeric / f, m[2]::numeric / f]
            FROM regexp_match(kelas, '([\d.]+)\s*-\s*<?\s*([\d.]+)') m,
                 (SELECT CASE WHEN kelas ~ 'cm' THEN 100 ELSE 1 END AS f) x)
  END $$;

-- ---------------------------------------------------------------- unit analisis (2 tabel)
DO $$
DECLARE p text[];
BEGIN
  FOREACH p SLICE 1 IN ARRAY ARRAY[['unit_nasional','unit_nasional'], ['unit_target','unit_target_2026']] LOOP
    EXECUTE format($f$
      INSERT INTO analisis.%2$I (khg_id, desa_id, perusahaan_id, jenis_kanal, nama_kawasan_konservasi,
        fungsi_kawasan, penutupan_lahan_2022, kerusakan_eg_2024, fungsi_eg_250k, fungsi_eg_ketebalan,
        tebal_gambut_kelas, tanah_gambut, sk_feg_50k, kedalaman_gambut_bbsdlp, kematangan_gambut, landform,
        gambut_bbsdlp, lahan_gambut, buffer, tahun_terbakar, frekuensi_terbakar, terdampak_kanal,
        program_dmpg, prioritas_intervensi, luas_ha, geom)
      SELECT k.id, d.desa_id, pr.id, j.kode, staging.b(s.namobj),
        staging.b(s.fungsi), staging.b(s.pl_2022), staging.b(s.skeg_2024), staging.b(s.feg_250k),
        staging.b(s.feg_peat_1),
        nullif(replace(staging.b(s.peat_thick), ',', '.'), 'NON KHG'), staging.b(s.tnh_gambut),
        staging.b(s.sk_feg_50k), staging.b(s.kdlmn_gbt), staging.b(s.kmtngn_gbt),
        upper(left(staging.b(s.landform), 1)) || lower(substr(staging.b(s.landform), 2)),
        s.gmbt_bbsdl = 'Gambut 50K, BBSDLP', s.lahan_gamb = 'LAHAN GAMBUT', staging.b(s.buffer),
        staging.tahun(2015, s.ba_2015, s.ba_2016, s.ba_2017, s.ba_2018, s.ba_2019, s.ba_2020,
                            s.ba_2021, s.ba_2022, s.ba_2023, s.ba_2024),
        staging.b(s.burn_period), s.cd_atk = 'Area Terdampak Kanal',
        staging.b(s.prog_dmpg_2025), staging.b(s.prog_intervensi), s.luas_ha, staging.valid(s.geom)
      FROM staging.%1$I s
      LEFT JOIN ref.khg k ON k.nama = s.nama_khg
      LEFT JOIN staging.desa_key d
        ON (d.prov, d.kab, d.kec, d.desa) = (btrim(s.prov_2023), btrim(s.kabko_2023), btrim(s.kec_2023), btrim(s.desa_2023))
      LEFT JOIN ref.perusahaan pr ON pr.nama = staging.b(s.perusahaan)
      LEFT JOIN ref.jenis_kanal j ON j.label = staging.b(s.ket_kanal)$f$, p[1], p[2]);
    EXECUTE format('CREATE INDEX ON analisis.%I USING gist (geom)', p[2]);
    EXECUTE format('CREATE INDEX ON analisis.%I (khg_id)', p[2]);
    EXECUTE format('CREATE INDEX ON analisis.%I (desa_id)', p[2]);
    EXECUTE format('CREATE INDEX ON analisis.%I (perusahaan_id)', p[2]);
  END LOOP;
END $$;

-- ---------------------------------------------------------------- kanal OSM
INSERT INTO peta.kanal (jenis_kanal, sumber, id_asal, geom, created_by, updated_by, updated_via)
SELECT nullif(btrim(kode_kanal), '')::smallint, 'OSM_2025', objectid, ST_Multi(geom), 'import', 'import', 'import'
  FROM staging.kanal_osm;

-- ---------------------------------------------------------------- kontur
INSERT INTO analisis.kontur (elevasi_m, geom) SELECT contour, ST_Multi(geom) FROM staging.kontur;
INSERT INTO analisis.kontur_lidar (elevasi_m, geom) SELECT contour, ST_Multi(geom) FROM staging.kontur_lidar;
CREATE INDEX ON analisis.kontur USING gist (geom);
CREATE INDEX ON analisis.kontur_lidar USING gist (geom);
CREATE INDEX ON analisis.kontur (khg_id);
CREATE INDEX ON analisis.kontur_lidar (khg_id);

-- ---------------------------------------------------------------- hotspot
INSERT INTO peta.hotspot (waktu, satelit, instrumen, kepercayaan, kepercayaan_nilai, frp_mw, brightness_k,
                          siang_malam, provinsi, kabupaten, kecamatan, desa, format_sumber, berkas_sumber,
                          geom, created_by, updated_by, updated_via)
SELECT waktu, satelit, instrumen, kepercayaan, kepercayaan_nilai, frp_mw, brightness_k, siang_malam,
       provinsi, kabupaten, kecamatan, desa, format_sumber, berkas_sumber, ST_GeometryN(geom, 1),
       'import', 'import', 'import'
  FROM staging.hotspot;

-- ---------------------------------------------------------------- areal terbakar 2015-2026
INSERT INTO peta.areal_terbakar (tahun_terbakar, geom, created_by, updated_by, updated_via)
SELECT coalesce(staging.tahun(2015, ba_2015, ba_2016, ba_2017, ba_2018, ba_2019, ba_2020, ba_2021,
                              ba_2022, ba_2023, ba_2024, ba_2025, ba_2026), '{}'),
       staging.valid(geom), 'import', 'import', 'import'
  FROM staging.burnscar;

-- ---------------------------------------------------------------- infrastruktur hidrologis
-- Sekat (existing/rencana perusahaan) -> peta.sekat + peta.sekat_bangunan; pintu air -> peta.pintu_air
CREATE TEMP TABLE infra AS
SELECT s.*, ST_GeometryN(s.geom, 1) AS pt,
       CASE WHEN staging.b(s.anggaran) IS NOT NULL OR s.kodefikasi LIKE 'KSE%' THEN 'BRGM_PPEG' ELSE 'PERUSAHAAN' END AS sumber,
       count(*) OVER (PARTITION BY ST_AsBinary(s.geom)) > 1 AS dup
  FROM staging.infrastruktur s;

CREATE TEMP TABLE infra_sekat AS
SELECT i.*, (SELECT max(id) FROM peta.sekat) + row_number() OVER (ORDER BY ogc_fid) AS new_id
  FROM infra i WHERE lower(coalesce(jenis, '')) <> 'pintu air';

INSERT INTO peta.sekat (id, status, sumber, qc_flag, geom, created_by, updated_by, updated_via)
SELECT new_id, CASE WHEN keterangan = 'RENCANA' THEN 'rencana' ELSE 'existing' END, sumber,
       CASE WHEN dup THEN 'duplikat_lokasi' END, pt, 'import', 'import', 'import'
  FROM infra_sekat;
SELECT setval(pg_get_serial_sequence('peta.sekat', 'id'), (SELECT max(id) FROM peta.sekat));

INSERT INTO peta.sekat_bangunan
SELECT i.new_id, staging.b(kodefikasi), staging.b(kode_renca), staging.b(khg), staging.b(tipe),
       initcap(staging.b(jenis)), initcap(staging.b(bahan)), nullif(tahun, 0), staging.b(anggaran),
       staging.b(kegiatan), upper(staging.b(pekerjaan)), staging.b(pelaksana), pr.id, staging.b(perijinan),
       staging.b(kode_pt), nullif(staging.b(data), '')::smallint, staging.b(keterangan),
       staging.b(source), staging.b(sisfo), staging.b(detail)
  FROM infra_sekat i LEFT JOIN ref.perusahaan pr ON pr.nama = staging.b(i.perusahaan);

INSERT INTO peta.pintu_air (kode, keterangan, tahun_bangun, bahan, pelaksana, perusahaan_id, sumber,
                            geom, created_by, updated_by, updated_via)
SELECT staging.b(kodefikasi), staging.b(keterangan), nullif(tahun, 0), initcap(staging.b(bahan)),
       staging.b(pelaksana), pr.id, i.sumber, pt, 'import', 'import', 'import'
  FROM infra i LEFT JOIN ref.perusahaan pr ON pr.nama = staging.b(i.perusahaan)
 WHERE lower(coalesce(jenis, '')) = 'pintu air';

COMMIT;
