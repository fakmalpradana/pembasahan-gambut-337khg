-- Poligon konsesi = dissolve unit analisis nasional per perusahaan.
SET session_replication_role = replica;
INSERT INTO peta.konsesi (perusahaan_id, jenis, sumber, geom, created_by, updated_by, updated_via)
SELECT p.id, p.izin_usaha, 'ALL_Analysis_PPEG_2026 (dissolve)',
       staging.dissolve(format('SELECT geom FROM analisis.unit_nasional WHERE perusahaan_id = %s', p.id)),
       'import', 'import', 'import'
  FROM ref.perusahaan p
 WHERE EXISTS (SELECT 1 FROM analisis.unit_nasional u WHERE u.perusahaan_id = p.id);
