-- Disposable database only. Never point this contract at Production.
DO $$ BEGIN IF current_database()<>'ih_margarita_test' THEN RAISE EXCEPTION 'isolated Margarita database required'; END IF; END $$;
CREATE TABLE public.fake_week(week text);
INSERT INTO public.fake_week VALUES('2026-47');
CREATE FUNCTION public.week_key(ts timestamptz DEFAULT now()) RETURNS text LANGUAGE sql STABLE AS $$SELECT week FROM public.fake_week$$;
CREATE TABLE public.players(id integer PRIMARY KEY,rate double precision,pp double precision,buffs jsonb);
INSERT INTO public.players SELECT i,0,1000,'[{"kind":"margarita","mult":2}]'::jsonb FROM generate_series(1,7)i;
CREATE FUNCTION public.calc_rate(p public.players) RETURNS double precision LANGUAGE sql STABLE AS $$SELECT p.rate$$;
CREATE FUNCTION public.live_mult(p public.players) RETURNS double precision LANGUAGE sql STABLE AS $$SELECT 1::double precision$$;
CREATE TABLE public.catalog(key text PRIMARY KEY,data jsonb);
INSERT INTO public.catalog VALUES('office_goal','{"floor":4e27,"per_player":1.2e27,"max_jump":6,"vs_last_week":0.9,"won":"unchanged prize"}');
CREATE TABLE public.season_state(id integer PRIMARY KEY,current_week text,target_week text,target double precision,mhit boolean,streak integer,best integer);
INSERT INTO public.season_state VALUES(1,'2026-47','2026-47',2.4e28,true,4,4);
CREATE TABLE public.seasons(week_key text PRIMARY KEY,stats jsonb);
INSERT INTO public.seasons VALUES('2026-46','{"seasoned":true,"office_total":4e38}');
CREATE OR REPLACE FUNCTION public.set_week_target()
 RETURNS double precision
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_variable
declare v_t double precision; v_heads int; v_g jsonb; v_per_sec double precision;
        v_prev double precision; v_share double precision; v_cap double precision;
begin
  select data into v_g from catalog where key = 'office_goal';
  select count(*) into v_heads from players;
  select coalesce(sum(calc_rate(p) * live_mult(p)), 0) into v_per_sec from players p;
  v_share := coalesce((v_g ->> 'vs_last_week')::double precision, 0.9);

  -- only a season that was itself wiped is a fair yardstick for the next one
  select (stats ->> 'office_total')::double precision into v_prev
    from seasons
    where coalesce((stats ->> 'seasoned')::boolean, false)
    order by week_key desc limit 1;

  -- and never let one freak week make the next one impossible
  v_cap := (v_g ->> 'floor')::double precision * coalesce((v_g ->> 'max_jump')::double precision, 6);

  v_t := greatest(
    (v_g ->> 'floor')::double precision,
    v_heads * (v_g ->> 'per_player')::double precision,
    least(coalesce(v_prev * v_share, 0), v_cap),
    least(v_per_sec * 4 * 86400, v_cap));
  update season_state set target = v_t, target_week = week_key() where id = 1;
  return v_t;
end $function$;

CREATE TEMP TABLE before_install AS SELECT md5(row_to_json(s)::text) AS state_hash,(SELECT md5(jsonb_agg(p ORDER BY id)::text) FROM public.players p) AS player_hash,proowner,proacl FROM public.season_state s,pg_proc WHERE oid='public.set_week_target()'::regprocedure;
\ir ../sql/margarita_pacing.sql
\ir ../sql/margarita_pacing.sql
DO $$ DECLARE s text; p text; BEGIN
 SELECT md5(row_to_json(x)::text) INTO s FROM public.season_state x;
 SELECT md5(jsonb_agg(x ORDER BY id)::text) INTO p FROM public.players x;
 IF s<>(SELECT state_hash FROM before_install) OR p<>(SELECT player_hash FROM before_install) THEN RAISE EXCEPTION 'installation changed player/state/rewards'; END IF;
 IF EXISTS(SELECT 1 FROM pg_proc,before_install b WHERE oid='public.set_week_target()'::regprocedure AND (pg_proc.proowner<>b.proowner OR pg_proc.proacl IS DISTINCT FROM b.proacl)) THEN RAISE EXCEPTION 'ACL or owner changed'; END IF;
 IF public.set_week_target()<>2.4e28 THEN RAISE EXCEPTION 'current earned target was changed'; END IF;
 IF (SELECT data->>'won' FROM public.catalog WHERE key='office_goal')<>'unchanged prize' THEN RAISE EXCEPTION 'reward text changed'; END IF;
END $$;
-- Model a normal next rollover in this disposable fixture; no production reset function is called.
UPDATE public.fake_week SET week='2026-48';
UPDATE public.season_state SET current_week='2026-48',mhit=false;
INSERT INTO public.seasons VALUES('2026-47','{"seasoned":true,"office_total":1e38}'),('2026-48','{"seasoned":true,"office_total":1e80}'),('2026-49','{"seasoned":true,"office_total":1e90}');
DO $$ BEGIN
 IF abs(public.set_week_target()/1.5e38-1)>1e-12 THEN RAISE EXCEPTION 'last completed week benchmark or 150 percent failed'; END IF;
 IF (SELECT target FROM public.season_state)<=4e27*6 THEN RAISE EXCEPTION 'obsolete floor cap survived'; END IF;
END $$;
UPDATE public.players SET rate=1e90;
UPDATE public.seasons SET stats='{"seasoned":true,"office_total":1e90}' WHERE week_key='2026-47';
DO $$ BEGIN IF abs(public.set_week_target()/1.5e38-1)>1e-12 THEN RAISE EXCEPTION 'frozen week was recalculated'; END IF; END $$;
UPDATE public.fake_week SET week='2026-49';
UPDATE public.season_state SET current_week='2026-49';
DELETE FROM public.seasons;
UPDATE public.players SET rate=0;
DO $$ BEGIN IF abs(public.set_week_target()/8.4e27-1)>1e-12 THEN RAISE EXCEPTION 'no-history population fallback failed'; END IF; END $$;
UPDATE public.fake_week SET week='2026-50';
UPDATE public.season_state SET current_week='2026-50';
DELETE FROM public.players;
DO $$ BEGIN IF public.set_week_target()<>4e27 THEN RAISE EXCEPTION 'empty office floor fallback failed'; END IF; END $$;
UPDATE public.fake_week SET week='2026-51';
DO $$ DECLARE failed boolean:=false; BEGIN
 BEGIN PERFORM public.set_week_target(); EXCEPTION WHEN OTHERS THEN
  IF SQLERRM LIKE 'ordinary weekly rollover required%' THEN failed:=true; ELSE RAISE; END IF;
 END;
 IF NOT failed OR (SELECT current_week FROM public.season_state)<>'2026-50' THEN RAISE EXCEPTION 'rollover was forced or not guarded'; END IF;
END $$;
UPDATE public.season_state SET current_week='2026-51';
INSERT INTO public.players VALUES(1,1e90,1000,'[]');
INSERT INTO public.seasons VALUES('2026-50','{"seasoned":true,"office_total":1e38}');
DO $$ BEGIN IF abs(public.set_week_target()/9e38-1)>1e-12 THEN RAISE EXCEPTION 'production estimate cap is not benchmark-relative'; END IF; END $$;

-- Execute the exact live rollover body in this disposable DB. Only its unrelated full-player wipe is substituted.
ALTER TABLE public.players ADD COLUMN name text DEFAULT 'QA Player',ADD COLUMN week_pp double precision DEFAULT 0,ADD COLUMN trophies integer DEFAULT 0;
ALTER TABLE public.seasons ADD COLUMN winner integer,ADD COLUMN winner_name text,ADD COLUMN top double precision;
ALTER TABLE public.season_state ADD COLUMN mw text;
CREATE TABLE public.deeds(id integer,actor integer,target integer,kind text,amount double precision,hush boolean,created_at timestamptz);
CREATE FUNCTION public.week_started() RETURNS timestamptz LANGUAGE sql STABLE AS $$SELECT now()$$;
CREATE FUNCTION public.season_wipe() RETURNS void LANGUAGE plpgsql AS $$BEGIN UPDATE public.players SET pp=0,rate=0,week_pp=0,buffs='[]'::jsonb; END$$;
INSERT INTO public.catalog VALUES('season','{"wipe":true,"from_week":"2026-01"}');
CREATE OR REPLACE FUNCTION public.roll_week()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare k text := week_key(); prev text; w players;
        wk_start timestamptz; wk_end timestamptz; st jsonb; was_hit boolean;
        do_wipe boolean; from_week text; seasoned boolean;
begin
  select current_week, mhit into prev, was_hit from season_state where id = 1 for update;
  if prev = k then return; end if;

  select coalesce((data ->> 'wipe')::boolean, false), coalesce(data ->> 'from_week', '')
    into do_wipe, from_week from catalog where key = 'season';
  seasoned := do_wipe and from_week <> '' and prev >= from_week;

  wk_end := week_started();
  wk_start := wk_end - interval '7 days';
  select * into w from players order by week_pp desc limit 1;

  with d as (
    select dd.*, pa.name as actor_name, pt.name as target_name
    from deeds dd join players pa on pa.id = dd.actor join players pt on pt.id = dd.target
    where dd.created_at >= wk_start and dd.created_at < wk_end)
  select jsonb_build_object(
    'total', (select count(*) from d),
    'heist', (select jsonb_build_object('actor',actor_name,'target',target_name,'amount',amount)
              from d where kind='credit' order by amount desc limit 1),
    'stylist', (select jsonb_build_object('name',actor_name,'n',count(*)) from d where kind='dress'
                group by actor_name order by count(*) desc limit 1),
    'kindest', (select jsonb_build_object('name',actor_name,'n',count(*)) from d
                where kind in ('coffee','hype','cover','rescue') group by actor_name order by count(*) desc limit 1),
    'menace', (select jsonb_build_object('name',actor_name,'n',count(*)) from d
               where kind not in ('coffee','hype','cover','rescue') group by actor_name order by count(*) desc limit 1),
    'feud', (select jsonb_build_object('a',least(actor_name,target_name),
                                       'b',greatest(actor_name,target_name),'n',count(*))
             from d where kind not in ('coffee','hype','cover','rescue')
             group by least(actor_name,target_name), greatest(actor_name,target_name)
             order by count(*) desc limit 1),
    'hushed', (select count(*) from d where hush),
    'punchbag', (select jsonb_build_object('name',target_name,'n',count(*)) from d
                 where kind not in ('coffee','hype','cover','rescue') group by target_name
                 order by count(*) desc limit 1),
    'margarita', coalesce(was_hit, false),
    'office_total', (select coalesce(sum(week_pp),0) from players),
    'seasoned', seasoned
  ) into st;

  if w.id is not null and w.week_pp > 0 then
    insert into seasons (week_key, winner, winner_name, top, stats)
      values (prev, w.id, w.name, w.week_pp, st)
      on conflict (week_key) do update set stats = excluded.stats;
    update players set trophies = trophies + 1 where id = w.id;
  else
    insert into seasons (week_key, winner_name, top, stats) values (prev, null, 0, st)
      on conflict (week_key) do update set stats = excluded.stats;
  end if;

  if not coalesce(was_hit, false) then
    update season_state set streak = 0 where id = 1;
  end if;

  if do_wipe then perform season_wipe();
  else update players set week_pp = 0 where week_pp <> 0; end if;

  update season_state set current_week = k, mw = k, mhit = false where id = 1;
  perform set_week_target();
end $function$;
UPDATE public.fake_week SET week='2026-52';
UPDATE public.season_state SET current_week='2026-51',mw='2026-51',mhit=true;
UPDATE public.players SET name='QA A',week_pp=1e38;
INSERT INTO public.players(id,name,rate,pp,buffs,week_pp) VALUES(2,'QA B',1e90,1000,'[]',2e38);
DO $$ DECLARE p text; s text; BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.roll_week()'::regprocedure)<>'07500c917bc2cfea0cf7ba596496b3c1' THEN RAISE EXCEPTION 'rollover is not the actual reviewed source'; END IF;
 PERFORM public.roll_week();
 IF (SELECT current_week FROM public.season_state)<>'2026-52' OR (SELECT target_week FROM public.season_state)<>'2026-52' THEN RAISE EXCEPTION 'normal rollover did not finish'; END IF;
 IF abs((SELECT (stats->>'office_total')::double precision FROM public.seasons WHERE week_key='2026-51')/3e38-1)>1e-12 THEN RAISE EXCEPTION 'closing standings were not archived before wiping'; END IF;
 IF abs((SELECT target FROM public.season_state)/4.5e38-1)>1e-12 THEN RAISE EXCEPTION 'normal rollover did not use the just-completed season'; END IF;
 IF (SELECT trophies FROM public.players WHERE id=2)<>1 OR (SELECT mhit FROM public.season_state) OR EXISTS(SELECT 1 FROM public.players WHERE week_pp<>0) THEN RAISE EXCEPTION 'normal weekly award/reset behavior changed'; END IF;
 SELECT md5(jsonb_agg(x ORDER BY id)::text) INTO p FROM public.players x;
 SELECT md5(row_to_json(x)::text) INTO s FROM public.season_state x;
 PERFORM public.roll_week();
 IF p<>(SELECT md5(jsonb_agg(x ORDER BY id)::text) FROM public.players x) OR s<>(SELECT md5(row_to_json(x)::text) FROM public.season_state x) THEN RAISE EXCEPTION 'repeat rollover was not a no-op'; END IF;
END $$;
SELECT 'PASS Margarita pacing: exact installed body, idempotent install, unchanged rewards/ACL/player state, frozen current target, actual rollover and archival order, 150 percent completed history, future exclusion, fallbacks and bounded estimate' AS result;

