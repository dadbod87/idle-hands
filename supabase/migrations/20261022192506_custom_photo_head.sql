-- Appearance-only additive validation. No stored player rows, bucket policies,
-- grants, prices, inventory or progress are changed by installation.
DO $migration$
DECLARE source_text text; definition text; expected text := '''classic'',''round'',''square'',''pear'',''alien'',''robot'',''cyclops'',''frog'',''bag''';
BEGIN
 SELECT prosrc,pg_get_functiondef(oid) INTO source_text,definition
 FROM pg_proc WHERE oid='public.set_look(jsonb)'::regprocedure;
 IF md5(source_text)<>'f81c937fffce69308cbba3b2c21f5d1f' THEN
  RAISE EXCEPTION 'set_look changed since review; stop and reconcile';
 END IF;
 IF strpos(definition,expected)=0 THEN RAISE EXCEPTION 'head allowlist not found'; END IF;
 EXECUTE replace(definition,expected,expected||',''photo''');
END $migration$;
