-- Poligon ketebalan gambut = dissolve unit analisis nasional per (KHG, kelas tebal).
SET session_replication_role = replica;
INSERT INTO peta.ketebalan_gambut (khg_id, kelas, tebal_min_m, tebal_max_m, geom, created_by, updated_by, updated_via)
SELECT khg_id, kelas, (staging.tebal(kelas))[1], (staging.tebal(kelas))[2],
       staging.dissolve(format('SELECT geom FROM analisis.unit_nasional WHERE khg_id = %s AND tebal_gambut_kelas = %L',
                               khg_id, kelas)),
       'import', 'import', 'import'
  FROM (SELECT DISTINCT khg_id, tebal_gambut_kelas AS kelas FROM analisis.unit_nasional
         WHERE khg_id IS NOT NULL AND tebal_gambut_kelas IS NOT NULL) g;
