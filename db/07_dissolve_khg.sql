-- Batas 866 KHG = dissolve unit analisis nasional per KHG (dijalankan paralel dgn 07_*).
UPDATE ref.khg k
   SET geom = staging.dissolve(format('SELECT geom FROM analisis.unit_nasional WHERE khg_id = %s', k.id));
UPDATE ref.khg SET luas_ha = round((ST_Area(geom::geography) / 1e4)::numeric, 2);
