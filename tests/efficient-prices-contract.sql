-- Disposable database only. Actual baseline and optimized RPC bodies, synthetic state.
BEGIN;
DO $$ BEGIN IF current_database()<>'idle_hands_test' THEN RAISE EXCEPTION 'isolated database required'; END IF; END $$;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE TABLE IF NOT EXISTS public.players(id uuid PRIMARY KEY,pp numeric);
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS dept text, ADD COLUMN perf_rate float8 DEFAULT 0, ADD COLUMN perf_mult float8 DEFAULT 1;
CREATE TABLE IF NOT EXISTS public.catalog(key text PRIMARY KEY,data jsonb);
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('test.player',true),'')::uuid$$;
CREATE TEMP SEQUENCE rate_calls;
CREATE TEMP SEQUENCE mult_calls;
CREATE OR REPLACE FUNCTION public.calc_rate(p public.players) RETURNS double precision LANGUAGE plpgsql STABLE AS $$BEGIN PERFORM nextval('rate_calls'); RETURN p.perf_rate; END$$;
CREATE OR REPLACE FUNCTION public.live_mult(p public.players) RETURNS double precision LANGUAGE plpgsql STABLE AS $$BEGIN PERFORM nextval('mult_calls'); RETURN p.perf_mult; END$$;
\i tests/fixtures/prices-baseline.sql
CREATE TEMP TABLE expected_prices(dept text,rate float8,mult float8,value jsonb);
INSERT INTO public.catalog(key,data) VALUES
 ('deeds','{"note":{"cost":0.03},"steal":{"cost":0.12},"blank":{"cost":0},"odd":{"cost":0.333333333333}}'),
 ('costumes','[{"id":"party","cost":0.5},{"id":"bag","cost":1.2},{"id":"plain","cost":0}]')
 ON CONFLICT(key) DO UPDATE SET data=excluded.data;
DO $$ DECLARE d text; r float8; m float8; v_id uuid; BEGIN
 SELECT p.id INTO v_id FROM public.players p LIMIT 1;
 IF v_id IS NULL THEN v_id:='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';INSERT INTO public.players(id,pp)VALUES(v_id,0);END IF;
 PERFORM set_config('test.player',v_id::text,true);
 FOREACH d IN ARRAY ARRAY['finance','contracts','resale'] LOOP
 FOREACH r IN ARRAY ARRAY[0,0.00001,0.1,1,13.75,1e10,1e38]::float8[] LOOP
 FOREACH m IN ARRAY ARRAY[0,0.4,1,1.28,2,3.14159]::float8[] LOOP
 UPDATE public.players SET dept=d,perf_rate=r,perf_mult=m WHERE players.id=v_id;
 INSERT INTO expected_prices VALUES(d,r,m,public.all_prices());
 END LOOP;END LOOP;END LOOP;
END $$;
\i supabase/migrations/20261109180821_efficient_price_snapshot.sql
DO $$ DECLARE e record; got jsonb; a bigint; b bigint; v_id uuid:=auth.uid(); BEGIN
 FOR e IN SELECT * FROM expected_prices LOOP
 UPDATE public.players SET dept=e.dept,perf_rate=e.rate,perf_mult=e.mult WHERE players.id=v_id;
 SELECT last_value INTO a FROM rate_calls;SELECT last_value INTO b FROM mult_calls;
 got:=public.all_prices();
 IF got IS DISTINCT FROM e.value THEN RAISE EXCEPTION 'price mismatch: %, %, %, % != %',e.dept,e.rate,e.mult,got,e.value;END IF;
 IF (SELECT last_value FROM rate_calls)<>a+1 OR (SELECT last_value FROM mult_calls)<>b+1 THEN RAISE EXCEPTION 'rate/mult calculated more than once';END IF;
 END LOOP;
 PERFORM set_config('test.player','',true);
 IF public.all_prices()<>'{}'::jsonb THEN RAISE EXCEPTION 'missing user should get no prices';END IF;
 RAISE NOTICE 'PASS: 126 complete old/new price snapshots identical; one rate/mult calculation each; missing user';
END $$;
ROLLBACK;
