"""Build the preservation-only payload and guarded full-package reuse. No DB/network writes."""
from pathlib import Path
import re,hashlib
root=Path(__file__).resolve().parents[1]
core=(root/'tools/season-record-core.sql').read_text()
body=re.search(r'AS \$season_capture\$([\s\S]*?)\$season_capture\$',core).group(1)
standalone="""-- Idle Hands: private final standings capture; no gameplay release.
BEGIN;
DO $guard$ BEGIN
 IF md5(pg_get_functiondef('public.roll_week()'::regprocedure))<>'0ecb8583745bf195bdb2dc73cec7fff6' THEN RAISE EXCEPTION 'rollover definition drift; review standings capture timing';END IF;
 IF to_regclass('office_private.action_history') IS NULL THEN RAISE EXCEPTION 'install the reviewed action journal first'; END IF;
 IF to_regclass('office_private.season_records') IS NOT NULL OR to_regclass('office_private.season_results') IS NOT NULL THEN RAISE EXCEPTION 'season records already exist; validate and reuse, do not reapply'; END IF;
 IF to_regclass('office_private.projects') IS NOT NULL THEN RAISE EXCEPTION 'full package already installed; use its guarded forward path'; END IF;
END $guard$;
"""+core+'\nCOMMIT;\n'
(root/'sql/season_records_history_only.sql').write_text(standalone)
reuse="""DO $season_reuse$ BEGIN
 IF to_regclass('office_private.season_records') IS NULL AND to_regclass('office_private.season_results') IS NULL THEN
  EXECUTE $season_core$@CORE@$season_core$;
 ELSE
  IF to_regclass('office_private.season_records') IS NULL OR to_regclass('office_private.season_results') IS NULL THEN RAISE EXCEPTION 'incomplete season history'; END IF;
  IF obj_description('office_private.season_records'::regclass,'pg_class') IS DISTINCT FROM 'idle-hands:season-records:v1'
  OR (SELECT array_agg(attname::text||':'||format_type(atttypid,atttypmod) ORDER BY attnum) FROM pg_attribute WHERE attrelid='office_private.season_records'::regclass AND attnum>0 AND NOT attisdropped) IS DISTINCT FROM ARRAY['week:text','closed_at:timestamp with time zone','winner:uuid','winner_name:text','top:double precision','coverage:text','captured_at:timestamp with time zone']
  OR (SELECT array_agg(attname::text||':'||format_type(atttypid,atttypmod) ORDER BY attnum) FROM pg_attribute WHERE attrelid='office_private.season_results'::regclass AND attnum>0 AND NOT attisdropped) IS DISTINCT FROM ARRAY['week:text','player:uuid','name:text','earnings:double precision','place:bigint']
  OR (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('office_private.capture_season()')) IS DISTINCT FROM '@HASH@'
  OR EXISTS(SELECT 1 FROM pg_class WHERE oid IN('office_private.season_records'::regclass,'office_private.season_results'::regclass) AND NOT relrowsecurity)
  OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='office_capture_season' AND tgrelid='public.seasons'::regclass AND tgfoid='office_private.capture_season()'::regprocedure AND tgenabled='O' AND NOT tgisinternal)
  OR has_table_privilege('anon','office_private.season_records','SELECT,INSERT,UPDATE,DELETE') OR has_table_privilege('authenticated','office_private.season_records','SELECT,INSERT,UPDATE,DELETE')
  OR has_table_privilege('anon','office_private.season_results','SELECT,INSERT,UPDATE,DELETE') OR has_table_privilege('authenticated','office_private.season_results','SELECT,INSERT,UPDATE,DELETE')
  OR has_function_privilege('anon','office_private.capture_season()','EXECUTE') OR has_function_privilege('authenticated','office_private.capture_season()','EXECUTE')
  OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='office_private.season_records'::regclass AND contype='p' AND conkey=ARRAY[1]::smallint[])
  OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='office_private.season_results'::regclass AND contype='p' AND conkey=ARRAY[1,2]::smallint[])
  THEN RAISE EXCEPTION 'prior season history drift; review before reuse'; END IF;
 END IF;
END $season_reuse$;
""".replace('@CORE@',core).replace('@HASH@',hashlib.md5(body.encode()).hexdigest())
(root/'tools/season-record-reuse.sql').write_text(reuse)
print('Built private standings capture',hashlib.sha256(standalone.encode()).hexdigest())
