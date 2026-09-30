-- Read-only snapshot of the schema as JSON (used to generate the Database Schema and ERD documents).
WITH s AS (SELECT unnest(ARRAY['ref','peta','analisis','alur','api']) AS nsp),
rel AS (
  SELECT c.oid, n.nspname AS schema, c.relname AS name,
         CASE c.relkind WHEN 'r' THEN 'table' WHEN 'v' THEN 'view' WHEN 'm' THEN 'materialized view' END AS kind,
         obj_description(c.oid) AS comment,
         CASE WHEN c.relkind IN ('r','m') THEN (xpath('/row/n/text()', query_to_xml(
              format('SELECT count(*) AS n FROM %I.%I', n.nspname, c.relname), false, true, '')))[1]::text::bigint END AS rows,
         CASE WHEN c.relkind IN ('r','m') THEN pg_total_relation_size(c.oid) END AS bytes
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname IN (SELECT nsp FROM s) AND c.relkind IN ('r','v','m'))
SELECT json_build_object(
 'tables', (SELECT json_agg(json_build_object(
    'schema', r.schema, 'name', r.name, 'kind', r.kind, 'comment', r.comment, 'rows', r.rows, 'bytes', r.bytes,
    'columns', (SELECT json_agg(json_build_object(
        'name', a.attname, 'type', format_type(a.atttypid, a.atttypmod), 'not_null', a.attnotnull,
        'default', pg_get_expr(d.adbin, d.adrelid), 'generated', a.attgenerated <> '',
        'identity', a.attidentity <> '', 'comment', col_description(a.attrelid, a.attnum)) ORDER BY a.attnum)
      FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
     WHERE a.attrelid = r.oid AND a.attnum > 0 AND NOT a.attisdropped),
    'constraints', (SELECT json_agg(json_build_object('name', co.conname, 'type', co.contype,
        'def', pg_get_constraintdef(co.oid),
        'ref_table', CASE WHEN co.contype = 'f' THEN co.confrelid::regclass::text END) ORDER BY co.contype, co.conname)
      FROM pg_constraint co WHERE co.conrelid = r.oid),
    'indexes', (SELECT json_agg(pg_get_indexdef(i.indexrelid) ORDER BY i.indexrelid)
      FROM pg_index i WHERE i.indrelid = r.oid),
    'triggers', (SELECT json_agg(json_build_object('name', t.tgname, 'def', pg_get_triggerdef(t.oid)) ORDER BY t.tgname)
      FROM pg_trigger t WHERE t.tgrelid = r.oid AND NOT t.tgisinternal)
  ) ORDER BY array_position(ARRAY['ref','peta','analisis','alur','api'], r.schema::text), r.kind, r.name) FROM rel r),
 'functions', (SELECT json_agg(json_build_object('schema', n.nspname, 'name', p.proname,
      'args', pg_get_function_arguments(p.oid), 'returns', pg_get_function_result(p.oid),
      'security_definer', p.prosecdef, 'language', l.lanname) ORDER BY n.nspname, p.proname)
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace JOIN pg_language l ON l.oid = p.prolang
   WHERE n.nspname IN ('alur','peta','api')),
 'roles', (SELECT json_agg(json_build_object('name', r.rolname, 'login', r.rolcanlogin,
      'member_of', (SELECT json_agg(g.rolname) FROM pg_auth_members m JOIN pg_roles g ON g.oid = m.roleid WHERE m.member = r.oid),
      'settings', (SELECT json_agg(x) FROM pg_db_role_setting s, unnest(s.setconfig) x WHERE s.setrole = r.oid)) ORDER BY r.rolname)
    FROM pg_roles r WHERE r.rolname IN ('gambut_baca','gambut_edit','ogc_reader','ogc_writer','web_app','editor_qgis')),
 'versions', json_build_object('postgres', current_setting('server_version'), 'postgis', postgis_lib_version()),
 'db_size', pg_size_pretty(pg_database_size(current_database()))
);
