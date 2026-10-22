-- Isolated PostgreSQL only. Includes actual reviewed scheduler and claim RPC bodies.
BEGIN;
DO $$ BEGIN IF current_database()<>'idle_hands_test' THEN RAISE EXCEPTION 'isolated fixture database required'; END IF; END $$;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('test.secret_uid',true),'')::uuid $$;
CREATE TABLE public.players(id uuid PRIMARY KEY,cow jsonb,pp numeric);
INSERT INTO public.players VALUES('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','["moth"]',12345),('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','[]',67890);
CREATE FUNCTION public.accrue(p_id uuid) RETURNS public.players LANGUAGE plpgsql AS $$ DECLARE p public.players; BEGIN SELECT * INTO p FROM public.players WHERE id=p_id; IF p.id IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF; RETURN p; END $$;
CREATE FUNCTION public.cow_roll(p_id uuid) RETURNS text LANGUAGE sql AS $$ SELECT 'pig'::text $$;
CREATE TABLE public.cow_state(id int PRIMARY KEY,week_key text,unlock_at timestamptz,taken_by uuid,taken_at timestamptz,orbs int,secs_per_orb double precision,loot text,finished boolean DEFAULT false,pin_next timestamptz);
\i tests/fixtures/secret-week-clock.sql
\i tests/fixtures/cow_arm-baseline.sql
\i tests/fixtures/cow_try-baseline.sql
REVOKE ALL ON FUNCTION public.cow_arm() FROM public;
CREATE TEMP TABLE secret_before AS SELECT proacl,proowner,prosecdef,proconfig FROM pg_proc WHERE oid='public.cow_arm()'::regprocedure;
INSERT INTO public.cow_state VALUES(1,public.week_key(),now()-interval '1 day','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',now(),24,75,'pig',true,null);
CREATE TEMP TABLE saved_secret AS SELECT to_jsonb(c) AS snapshot FROM public.cow_state c;
CREATE TEMP TABLE saved_secret_players AS SELECT to_jsonb(p) AS snapshot FROM public.players p;
\i supabase/migrations/20261022204538_weekly_secret_schedule.sql
DO $tests$
DECLARE c public.cow_state; saved timestamptz; finish timestamptz; t timestamptz; draws timestamptz[]:='{}'; i int; result jsonb; rejected boolean:=false;
BEGIN
 IF (SELECT to_jsonb(x) FROM public.cow_state x) IS DISTINCT FROM (SELECT snapshot FROM saved_secret) THEN RAISE EXCEPTION 'install changed existing claim'; END IF;
 IF EXISTS(SELECT 1 FROM pg_proc f,secret_before b WHERE f.oid='public.cow_arm()'::regprocedure AND ROW(f.proacl,f.proowner,f.prosecdef,f.proconfig) IS DISTINCT FROM ROW(b.proacl,b.proowner,b.prosecdef,b.proconfig)) THEN RAISE EXCEPTION 'function attributes/grants changed'; END IF;
 c:=public.cow_arm();IF NOT c.finished OR c.taken_by IS NULL THEN RAISE EXCEPTION 'existing current-week claim lost'; END IF;
 DELETE FROM public.cow_state;
 FOR t IN SELECT unnest(ARRAY['2026-10-23T23:00:00Z','2026-10-30T23:00:00Z','2026-03-07T00:00:00Z','2027-01-02T00:00:00Z']::timestamptz[]) LOOP
  PERFORM set_config('test.secret_now',t::text,true);
  finish:=((t AT TIME ZONE 'America/Los_Angeles')+interval '7 days') AT TIME ZONE 'America/Los_Angeles';
  FOR i IN 1..250 LOOP
   UPDATE public.cow_state SET week_key='old-week',pin_next=t-interval '1 day',taken_by='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',finished=true;
   c:=public.cow_arm();
   IF c.unlock_at<t+interval '1 hour' OR c.unlock_at>=finish-interval '1 hour' OR c.taken_by IS NOT NULL OR c.finished OR c.pin_next IS NOT NULL THEN RAISE EXCEPTION 'weekly bounds/claim reset wrong at %',t; END IF;
   saved:=c.unlock_at;draws:=array_append(draws,saved);c:=public.cow_arm();IF c.unlock_at<>saved THEN RAISE EXCEPTION 'same week rerolled'; END IF;
  END LOOP;
 END LOOP;
 IF (SELECT count(DISTINCT value) FROM unnest(draws) AS value)<990 THEN RAISE EXCEPTION 'schedule is not randomized'; END IF;
 -- Actual cow_try body: before unlock, first claim, duplicate/other-player denial.
 PERFORM set_config('test.secret_now','',true);PERFORM set_config('test.secret_uid','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
 UPDATE public.cow_state SET week_key=public.week_key(),unlock_at=now()+interval '1 second',taken_by=null,taken_at=null,finished=false;
 IF public.cow_try() IS NOT NULL THEN RAISE EXCEPTION 'opened before unlock'; END IF;
 UPDATE public.cow_state SET unlock_at=now();result:=public.cow_try();
 IF result IS NULL OR result->>'orbs'<>'24' OR result->>'secs'<>'75' THEN RAISE EXCEPTION 'claim contract changed'; END IF;
 IF public.cow_try() IS NOT NULL THEN RAISE EXCEPTION 'duplicate claim granted'; END IF;
 PERFORM set_config('test.secret_uid','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
 IF public.cow_try() IS NOT NULL THEN RAISE EXCEPTION 'second player claimed the same week'; END IF;
 PERFORM set_config('test.secret_uid','',true);BEGIN PERFORM public.cow_try();EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'anonymous claim accepted'; END IF;
 IF EXISTS((SELECT to_jsonb(p) FROM public.players p EXCEPT SELECT snapshot FROM saved_secret_players) UNION ALL (SELECT snapshot FROM saved_secret_players EXCEPT SELECT to_jsonb(p) FROM public.players p)) THEN RAISE EXCEPTION 'scheduler changed player progress'; END IF;
END $tests$;
ROLLBACK;
