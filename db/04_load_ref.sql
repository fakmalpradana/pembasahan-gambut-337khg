-- Tahap 1: referensi (wilayah, perusahaan, lookup, KHG) dari semua tabel staging.
BEGIN;
SET LOCAL session_replication_role = replica;

-- pembersih nilai teks: '', '-', 'None' -> NULL
CREATE OR REPLACE FUNCTION staging.b(text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$ SELECT nullif(nullif(nullif(btrim($1), ''), '-'), 'None') $$;
-- kolom BA_2015..BA_20xx -> smallint[] tahun terbakar
CREATE OR REPLACE FUNCTION staging.tahun(mulai int, VARIADIC v text[]) RETURNS smallint[]
LANGUAGE sql IMMUTABLE AS $$
  SELECT array_agg((mulai + i - 1)::smallint ORDER BY i) FILTER (WHERE staging.b(v[i]) IS NOT NULL)
    FROM generate_subscripts(v, 1) i $$;

-- ---------------------------------------------------------------- wilayah
CREATE TEMP TABLE w AS
SELECT DISTINCT btrim(prov) prov, btrim(kab) kab, btrim(kec) kec, btrim(desa) desa FROM (
  SELECT prov_2023, kabko_2023, kec_2023, desa_2023 FROM staging.aoi_desa
  UNION SELECT prov_2023, kabko_2023, kec_2023, desa_2023 FROM staging.unit_nasional
  UNION SELECT prov_2023, kabko_2023, kec_2023, desa_2023 FROM staging.unit_target
  UNION SELECT prov_2023, kabko_2023, kec_2023, desa_2023 FROM staging.infrastruktur
  UNION SELECT provinsi, kabupaten, kecamatan, desa FROM staging.sekat_kanal
) x (prov, kab, kec, desa)
WHERE staging.b(prov) IS NOT NULL AND staging.b(desa) IS NOT NULL;

DO $$ DECLARE n int; BEGIN
  SELECT count(DISTINCT prov) INTO n FROM w WHERE prov NOT IN (SELECT nama FROM ref.provinsi);
  IF n > 0 THEN RAISE EXCEPTION 'Ada % nama provinsi tak dikenal', n; END IF;
END $$;

INSERT INTO ref.kabupaten (provinsi_id, nama)
SELECT DISTINCT p.id, w.kab FROM w JOIN ref.provinsi p ON p.nama = w.prov;
INSERT INTO ref.kecamatan (kabupaten_id, nama)
SELECT DISTINCT kb.id, w.kec FROM w
  JOIN ref.provinsi p ON p.nama = w.prov
  JOIN ref.kabupaten kb ON kb.provinsi_id = p.id AND kb.nama = w.kab;
INSERT INTO ref.desa (kecamatan_id, nama)
SELECT DISTINCT kc.id, w.desa FROM w
  JOIN ref.provinsi p ON p.nama = w.prov
  JOIN ref.kabupaten kb ON kb.provinsi_id = p.id AND kb.nama = w.kab
  JOIN ref.kecamatan kc ON kc.kabupaten_id = kb.id AND kc.nama = w.kec;

-- peta bantu nama -> desa_id, dipakai tahap berikutnya
CREATE TABLE staging.desa_key AS
SELECT p.nama prov, kb.nama kab, kc.nama kec, d.nama desa, d.id desa_id
  FROM ref.desa d JOIN ref.kecamatan kc ON kc.id = d.kecamatan_id
  JOIN ref.kabupaten kb ON kb.id = kc.kabupaten_id JOIN ref.provinsi p ON p.id = kb.provinsi_id;
CREATE UNIQUE INDEX ON staging.desa_key (prov, kab, kec, desa);

-- 2004 desa target: tandai + geometri AOI
UPDATE ref.desa d SET target_pemulihan_2026 = true, geom = ST_Multi(a.geom)
  FROM staging.aoi_desa a JOIN staging.desa_key k
    ON (k.prov, k.kab, k.kec, k.desa) = (btrim(a.prov_2023), btrim(a.kabko_2023), btrim(a.kec_2023), btrim(a.desa_2023))
 WHERE d.id = k.desa_id;

-- ---------------------------------------------------------------- perusahaan
INSERT INTO ref.perusahaan (nama, izin_usaha)
SELECT nama, mode() WITHIN GROUP (ORDER BY izin) FROM (
  SELECT staging.b(perusahaan), staging.b(izin_usaha) FROM staging.unit_nasional
  UNION ALL SELECT staging.b(perusahaan), staging.b(izin_usaha) FROM staging.unit_target
  UNION ALL SELECT staging.b(perusahaan), staging.b(izin_usaha) FROM staging.sekat_kanal
  UNION ALL SELECT staging.b(perusahaan), staging.b(perijinan) FROM staging.infrastruktur
) x (nama, izin)
WHERE nama IS NOT NULL AND nama NOT IN ('NON KONSESI/PERIZINAN', 'NON KONSESI')
GROUP BY nama;

-- ---------------------------------------------------------------- lookup dari data
INSERT INTO ref.fungsi_kawasan (kode, label)
SELECT DISTINCT ON (kode) kode, label FROM (
  SELECT staging.b(fungsi), staging.b(fungsi_kws) FROM staging.unit_nasional
  UNION SELECT staging.b(fungsi), staging.b(fungsi_kws) FROM staging.unit_target
  UNION SELECT staging.b(fungsi_kawasan_kode), staging.b(fungsi_kawasan) FROM staging.sekat_kanal
) x (kode, label) WHERE kode IS NOT NULL ORDER BY kode, label;

INSERT INTO ref.penutupan_lahan
SELECT DISTINCT n FROM (
  SELECT staging.b(pl_2022) FROM staging.unit_nasional
  UNION SELECT staging.b(pl_2022) FROM staging.unit_target
  UNION SELECT staging.b(penutupan_lahan_2022) FROM staging.sekat_kanal
) x (n) WHERE n IS NOT NULL;

INSERT INTO ref.kerusakan_eg VALUES
  ('Tidak Rusak',0),('Rusak Ringan',1),('Rusak Sedang',2),('Rusak Berat',3),('Rusak Sangat Berat',4);
INSERT INTO ref.kerusakan_eg (nama)
SELECT DISTINCT n FROM (
  SELECT staging.b(skeg_2024) FROM staging.unit_nasional
  UNION SELECT staging.b(skeg_2024) FROM staging.unit_target
) x (n) WHERE n IS NOT NULL
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------- KHG (866, tanpa geometri dulu)
WITH a AS (SELECT nama_khg, btrim(prov_2023) prov, sum(luas_ha) l FROM staging.unit_nasional
            WHERE staging.b(nama_khg) IS NOT NULL AND nama_khg <> 'NON KHG' GROUP BY 1, 2),
m AS (SELECT DISTINCT ON (nama_khg) nama_khg, prov FROM a ORDER BY nama_khg, l DESC NULLS LAST),
t AS (SELECT DISTINCT nama_khg FROM staging.unit_target)
INSERT INTO ref.khg (nama, provinsi_utama_id, target_2026)
SELECT m.nama_khg, p.id, m.nama_khg IN (SELECT nama_khg FROM t)
  FROM m JOIN ref.provinsi p ON p.nama = m.prov;

COMMIT;
