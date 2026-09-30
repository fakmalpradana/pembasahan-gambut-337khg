-- Tahap 2: sekat rencana (GeoPackage bersih) -> peta.sekat + peta.sekat_konteks.
BEGIN;
SET LOCAL session_replication_role = replica;

INSERT INTO peta.sekat (kode, status, id_kontur_asal, jenis_kanal, panjang_kanal_m, elevasi_kontur_m,
                        sumber, fid_asal, qc_flag, geom, khg_id, created_by, updated_by, updated_via)
SELECT 'SK-' || row_number() OVER (PARTITION BY k.id ORDER BY s.fid_sekat),
       'rencana', s.id_kontur_asal, s.kode_kanal, round(s.panjang_kanal_m::numeric, 1),
       s.elevasi_kontur_m, 'BRGM_PPEG_2026', s.fid_sekat,
       concat_ws(';', s.qc_flag, CASE WHEN s.n_baris_lokasi > 1 THEN 'pertemuan_kanal' END),
       ST_GeometryN(s.geom, 1), k.id, 'import', 'import', 'import'
  FROM staging.sekat_kanal s JOIN ref.khg k ON k.nama = s.nama_khg;
UPDATE peta.sekat SET qc_flag = NULL WHERE qc_flag = '';

INSERT INTO peta.sekat_konteks
SELECT t.id, d.desa_id, pr.id, s.nama_kawasan_konservasi, s.fungsi_kawasan_kode, s.penutupan_lahan_2022,
       s.kerusakan_eg_2024, s.fungsi_eg_250k, s.fungsi_eg_ketebalan, s.tebal_gambut_kelas,
       s.tanah_gambut, s.sk_feg_50k, s.kedalaman_gambut_bbsdlp, s.kematangan_gambut, s.landform,
       s.gambut_bbsdlp::boolean, s.lahan_gambut::boolean, s.buffer,
       string_to_array(s.tahun_terbakar, ',')::smallint[], s.frekuensi_terbakar,
       s.terdampak_kanal::boolean, s.program_dmpg, s.prioritas_intervensi, s.luas_poligon_analisis_ha
  FROM staging.sekat_kanal s
  JOIN peta.sekat t ON t.fid_asal = s.fid_sekat
  JOIN staging.desa_key d ON (d.prov, d.kab, d.kec, d.desa) = (s.provinsi, s.kabupaten, s.kecamatan, s.desa)
  LEFT JOIN ref.perusahaan pr ON pr.nama = s.perusahaan;

COMMIT;
