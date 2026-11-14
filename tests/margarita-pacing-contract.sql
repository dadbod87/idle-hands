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
end $function$

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
SELECT 'PASS Margarita pacing: exact installed body, idempotent install, unchanged rewards/ACL/player state, frozen current target, 150 percent completed history, future exclusion, fallbacks and bounded estimate' AS result;

