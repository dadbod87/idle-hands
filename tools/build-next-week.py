"""Build a guarded, reviewable SQL payload from audited function snapshots. No network/DB writes."""
from pathlib import Path
import re,hashlib,json
root=Path(__file__).resolve().parents[1]
baseline=(root/'tests/fixtures/next-week-baseline.sql').read_text()
functions={m.group(1):m.group(0) for m in re.finditer(r'CREATE OR REPLACE FUNCTION public\.(\w+)\([\s\S]*?\$function\$[\s\S]*?\$function\$\n',baseline)}
changed={}
def patch(name,a,b):
    source=changed.get(name,functions[name]); assert a in source,(name,a)
    changed[name]=source.replace(a,b)
for name in ['live_mult','live_mult_at']:
    patch(name,'p.equity * 0.03','p.seniority_earned * 0.03')
patch('restructure','equity=equity+gain,','equity=equity+gain,seniority_earned=seniority_earned+gain,')
patch('season_wipe','equity=0,','equity=0,seniority_earned=0,')
patch('roll_week',"('coffee','hype','cover')","('coffee','hype','cover','rescue')")
patch('season_wipe','nickname=null,outfit=null,ooo=null,','nickname=null,outfit=null,ooo=null,office_confetti=null,')
# Serialize targeted mutations before either player is locked. Opposite-direction
# actions must not each hold their actor while waiting for the other's row.
for name in ['do_deed','dress','give_nickname']:
    patch(name,'begin\n','begin\n  perform pg_advisory_xact_lock(728194, 1);\n')
for name in ['buy_fitting','buy_pin']:
    patch(name,'calc_rate(p) * live_mult(p)','public.permanent_price_rate(p)')
patch('fitting_prices','eff := calc_rate(p) * live_mult(p);','eff := public.permanent_price_rate(p);')
for name in ['quote_style','apply_style']:
    patch(name,'public.calc_rate(p)*public.live_mult(p)','public.permanent_price_rate(p)')
patch('do_deed','soften double precision; eff double precision; cd interval;','soften double precision; eff double precision; cd interval; blocked_by_filter boolean:=false;')
patch('do_deed',"if d is null then raise exception 'no such deed'; end if;", """if d is null then raise exception 'no such deed'; end if;
  if p_kind='cover' then d:='{"cost":0.05,"good":true,"mins":20,"mult":1.15}'::jsonb; end if;
  if d ? 'transfer' then raise exception 'cash transfer deeds are retired'; end if;""")
patch('do_deed',"  if d ? 'mult' then", """  if d ? 'mult' and (d->>'mult')::double precision<1 and office_private.filter_blocks(t.id) then
    blocked_by_filter:=true; d:=d-'mult';
  end if;
  if p_kind='cover' then
    update players set buffs=coalesce((select jsonb_agg(b) from jsonb_array_elements(t.buffs) b where b->>'kind'<>'cover'),'[]'::jsonb) where id=t.id;
  end if;
  if d ? 'mult' then""")
patch('do_deed','insert into deeds (actor, target, kind, amount) values (p.id, p_target, p_kind, amt);',"insert into deeds (actor, target, kind, amount, detail) values (p.id, p_target, p_kind, amt,case when blocked_by_filter then 'blocked:filter' else null end);")
blocks=[]
for name,source in changed.items():
    digest=hashlib.md5(functions[name].encode()).hexdigest()
    blocks.append("DO $guard$ BEGIN IF md5(pg_get_functiondef('public.%s'::regproc))<>'%s' THEN RAISE EXCEPTION 'Audited function drift: %s'; END IF; END $guard$;\n%s;"%(name,digest,name,source))
path=root/'sql/next_week_office.sql'
sql=path.read_text()
journal=(root/'sql/office_action_journal.sql').read_text()
core=journal.split('-- @JOURNAL_CORE@\n',1)[1].split('-- @END_JOURNAL_CORE@',1)[0]
capture_body=re.search(r'AS \$journal_capture\$([\s\S]*?)\$journal_capture\$',core).group(1)
category_body=re.search(r'AS \$\$([\s\S]*?)\$\$',core).group(1)
reuse="""DO $journal_reuse$
BEGIN
 IF to_regclass('office_private.action_history') IS NULL AND to_regclass('office_private.history_coverage') IS NULL THEN
  EXECUTE $journal_core$@CORE@$journal_core$;
 ELSE
  IF to_regclass('office_private.action_history') IS NULL OR to_regclass('office_private.history_coverage') IS NULL
  THEN RAISE EXCEPTION 'incomplete prior journal installation'; END IF;
  IF obj_description('office_private.action_history'::regclass,'pg_class') IS DISTINCT FROM 'idle-hands:action-journal:v1'
  OR (SELECT array_agg(attname::text||':'||format_type(atttypid,atttypmod) ORDER BY attnum) FROM pg_attribute WHERE attrelid='office_private.action_history'::regclass AND attnum>0 AND NOT attisdropped)
   IS DISTINCT FROM ARRAY['source_deed:bigint','actor:uuid','target:uuid','kind:text','category:text','amount:double precision','hush:boolean','happened_at:timestamp with time zone','week:text']
  OR (SELECT array_agg(attname::text||':'||format_type(atttypid,atttypmod) ORDER BY attnum) FROM pg_attribute WHERE attrelid='office_private.history_coverage'::regclass AND attnum>0 AND NOT attisdropped)
   IS DISTINCT FROM ARRAY['id:boolean','started_at:timestamp with time zone','continuous_since:timestamp with time zone']
  THEN RAISE EXCEPTION 'prior journal schema drift; review before reuse'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='office_private.action_history'::regclass AND contype='p' AND conkey=ARRAY[1]::smallint[])
  OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='office_private.history_coverage'::regclass AND contype='p' AND conkey=ARRAY[1]::smallint[])
  OR (SELECT count(*) FROM office_private.history_coverage)<>1
  THEN RAISE EXCEPTION 'prior journal identity or coverage drift; review before reuse'; END IF;
  IF (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('office_private.capture_deed()')) IS DISTINCT FROM '@CAPTURE_HASH@'
  OR (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('office_private.action_category(text,text)')) IS DISTINCT FROM '@CATEGORY_HASH@'
  THEN RAISE EXCEPTION 'prior journal function drift; review before reuse'; END IF;
  IF EXISTS(SELECT 1 FROM pg_class WHERE oid IN('office_private.action_history'::regclass,'office_private.history_coverage'::regclass) AND NOT relrowsecurity)
  OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='office_capture_deed' AND tgrelid='public.deeds'::regclass AND tgfoid='office_private.capture_deed()'::regprocedure AND tgenabled='O' AND NOT tgisinternal)
  OR has_table_privilege('anon','office_private.action_history','SELECT,INSERT,UPDATE,DELETE')
  OR has_table_privilege('authenticated','office_private.action_history','SELECT,INSERT,UPDATE,DELETE')
  OR has_table_privilege('anon','office_private.history_coverage','SELECT,INSERT,UPDATE,DELETE')
  OR has_table_privilege('authenticated','office_private.history_coverage','SELECT,INSERT,UPDATE,DELETE')
  OR has_function_privilege('anon','office_private.capture_deed()','EXECUTE')
  OR has_function_privilege('authenticated','office_private.action_category(text,text)','EXECUTE')
  THEN RAISE EXCEPTION 'prior journal protection drift; review before reuse'; END IF;
 END IF;
END $journal_reuse$;
""".replace('@CORE@',core).replace('@CAPTURE_HASH@',hashlib.md5(capture_body.encode()).hexdigest()).replace('@CATEGORY_HASH@',hashlib.md5(category_body.encode()).hexdigest())
js='-- @JOURNAL_INSTALL@';je='-- @END_JOURNAL_INSTALL@'
sql=sql[:sql.index(js)+len(js)]+'\n'+reuse+sql[sql.index(je):]
start='-- @PATCHES@';end='-- @END_PATCHES@'
if end in sql: sql=sql[:sql.index(start)+len(start)]+ '\n'+sql[sql.index(end):]
sql=sql.replace(start,start+'\n'+'\n'.join(blocks)+'\n'+(end if end not in sql else ''),1)
path.write_text(sql)
schema=json.loads((root/'tests/fixtures/next-week-schema.json').read_text())
tables={}
for col in schema: tables.setdefault(col['table_name'],[]).append(col)
lines=['-- Dedicated disposable DB only. Synthetic schema, no player data.','CREATE SCHEMA IF NOT EXISTS auth;',"DO $$ BEGIN IF current_database()<>'idle_hands_test' THEN RAISE EXCEPTION 'isolated database required'; END IF; IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon; END IF; IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated; END IF; END $$;", "CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;"]
for name,cols in tables.items():
    fields=[]
    for col in cols:
        default=col['column_default']; decl='"'+col['column_name']+'" '+col['udt_name']
        if (default and default.startswith('nextval(')) or (name=='deeds' and col['column_name']=='id'):decl+=' GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY'
        else:
            if default:decl+=' DEFAULT '+("'fixture-only'::text" if col['column_name']=='code' else default)
            if col['is_nullable']=='NO':decl+=' NOT NULL'
        fields.append(decl)
    lines.append('CREATE TABLE public."'+name+'" ('+','.join(fields)+');')
# Actual helper snapshots depend on the tables above. No production credentials are used.
(root/'tests/fixtures/next-week-schema.sql').write_text('\n'.join(lines)+'\n')
print('Built guarded SQL payload:',len(changed),'function replacements;',hashlib.sha256(sql.encode()).hexdigest())
