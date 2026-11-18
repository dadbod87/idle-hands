\set ON_ERROR_STOP on
DO $$BEGIN
  IF current_database() <> 'ih_busywork_test' THEN RAISE EXCEPTION 'disposable Busywork database required'; END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon; END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated; END IF;
END$$;

CREATE SCHEMA office_private;
CREATE TABLE public.players(
  id uuid PRIMARY KEY, name text, dept text, perks jsonb DEFAULT '{}', rate float8 DEFAULT 0,
  pp float8 DEFAULT 0, lifetime float8 DEFAULT 0, cycle float8 DEFAULT 0,
  week_pp float8 DEFAULT 0, day_pp float8 DEFAULT 0, trophies integer DEFAULT 0,
  last_tick timestamptz, last_seen timestamptz,
  owned jsonb, upgrades jsonb, buffs jsonb, equity int, seniority_earned int, raises int,
  frenzy_until timestamptz, heat int, busted int, goodwill int, notoriety int, hush int, quits int,
  grabs int, kind_received int, rivalries int, hits jsonb, tally jsonb, today jsonb, contracts jsonb,
  mail jsonb, streak int, last_checkin date, nickname jsonb, outfit jsonb, ooo text,
  office_confetti jsonb, last_restructure timestamptz, last_deed timestamptz, last_nick timestamptz,
  last_vend timestamptz, last_break timestamptz, last_work timestamptz
);
CREATE TABLE public.season_state(id int PRIMARY KEY, current_week text, mw text, mhit boolean, streak int);
CREATE TABLE public.seasons(
  week_key text PRIMARY KEY, winner uuid, winner_name text, top float8, stats jsonb
);
CREATE TABLE public.catalog(key text PRIMARY KEY, data jsonb);
CREATE TABLE public.deeds(id bigint, actor uuid, target uuid, kind text, amount float8, hush boolean, created_at timestamptz);
CREATE TABLE public.chair_claims(window_id bigint);
CREATE TABLE public.printer_claims(window_id bigint);
CREATE TABLE public.meeting_claims(window_id bigint, paid boolean);
CREATE TABLE public.birthday_card(week_key text);
CREATE TABLE office_private.fixture_standings(week_key text, player uuid, earnings float8);
CREATE FUNCTION office_private.fixture_capture() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO office_private.fixture_standings SELECT NEW.week_key, id, week_pp FROM public.players;
  RETURN NEW;
END$$;
CREATE TRIGGER fixture_capture AFTER INSERT ON public.seasons FOR EACH ROW EXECUTE FUNCTION office_private.fixture_capture();

CREATE FUNCTION public.week_key(ts timestamptz DEFAULT now()) RETURNS text LANGUAGE plpgsql STABLE AS $$
DECLARE loc timestamp; monday timestamp;
        fixture_week text := nullif(current_setting('test.busywork_week',true),'');
BEGIN
  IF fixture_week IS NOT NULL AND ts=now() THEN RETURN fixture_week; END IF;
  loc:=ts AT TIME ZONE 'America/Los_Angeles'; monday:=date_trunc('week',loc);
  IF loc >= monday + interval '4 days 16 hours' THEN RETURN to_char(monday+interval '7 days','IYYY-IW'); END IF;
  RETURN to_char(monday,'IYYY-IW');
END $$;
CREATE FUNCTION public.perk_of(p public.players, k text) RETURNS int LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN jsonb_typeof(p.perks) = 'object' THEN coalesce((p.perks ->> k)::int, 0) ELSE 0 END
$$;
-- A constant rate keeps the assertions focused on the actual settlement bounds and routing.
CREATE FUNCTION public.accrual_interval_gain(p public.players, start_at timestamptz, end_at timestamptz)
RETURNS float8 LANGUAGE sql STABLE AS $$
  SELECT p.rate * extract(epoch FROM end_at - start_at)
$$;
CREATE FUNCTION public.check_margarita() RETURNS void LANGUAGE sql AS $$ SELECT $$;
CREATE FUNCTION public.settle_meetings() RETURNS void LANGUAGE sql AS $$ SELECT $$;
CREATE FUNCTION public.set_week_target() RETURNS void LANGUAGE sql AS $$ SELECT $$;


\ir fixtures/weekly-busywork-baseline.sql

INSERT INTO public.season_state
SELECT 1, week_key(week_started() - interval '1 microsecond'), week_key(week_started() - interval '1 microsecond'), true, 4;
INSERT INTO public.catalog VALUES ('season', '{"wipe":true,"from_week":"2026-35"}');
INSERT INTO public.players(id,name,dept,perks,rate,pp,lifetime,cycle,week_pp,day_pp,last_tick,last_seen)
VALUES
  ('00000000-0000-4000-8000-000000000001','Visible leader',NULL,'{}',0,1000,1000,1000,1000,1000,week_started(),'2000-01-01Z'),
  ('00000000-0000-4000-8000-000000000002','Away at close','operations','{}',2,10,10,10,10,10,week_started()-interval '10 minutes','2000-01-01Z'),
  ('00000000-0000-4000-8000-000000000003','Offline cap','property','{"deep_pockets":1}',0.01,0,0,0,0,0,week_started()-interval '48 hours','2000-01-01Z'),
  ('00000000-0000-4000-8000-000000000004','No prior settlement',NULL,'{}',8,0,0,0,0,0,NULL,'2000-01-01Z');

CREATE TABLE office_private.fixture_before_install AS SELECT * FROM public.players;
\ir ../sql/weekly_busywork_cutoff.sql

DO $test$
DECLARE old_week text := (SELECT current_week FROM public.season_state);
        winner_id uuid := '00000000-0000-4000-8000-000000000002';
        offline_id uuid := '00000000-0000-4000-8000-000000000003';
        unset_id uuid := '00000000-0000-4000-8000-000000000004';
        week_cutoff timestamptz := public.week_started();
        old_cutoff timestamptz;
        p public.players;
        expected float8;
BEGIN
  IF EXISTS (TABLE public.players EXCEPT TABLE office_private.fixture_before_install)
     OR EXISTS (TABLE public.seasons)
     OR has_function_privilege('authenticated','office_private.busywork_start(public.players,timestamptz)','EXECUTE') THEN
    RAISE EXCEPTION 'installation changed game data or opened helper privileges';
  END IF;

  IF office_private.busywork_start((SELECT other FROM public.players other WHERE id=offline_id),week_cutoff) <> week_cutoff - interval '16 hours'
     OR office_private.busywork_start((SELECT other FROM public.players other WHERE id=unset_id),week_cutoff) <> week_cutoff THEN
    RAISE EXCEPTION 'offline cap or null tick changed';
  END IF;

  PERFORM public.roll_week();
  PERFORM public.roll_week();
  IF (SELECT count(*) FROM public.seasons) <> 1
     OR NOT EXISTS (SELECT FROM public.seasons WHERE week_key=old_week AND winner=winner_id AND top=1210
                    AND (stats->>'office_total')::float8=2786)
     OR NOT EXISTS (SELECT FROM office_private.fixture_standings WHERE week_key=old_week AND player=offline_id AND earnings=576)
     OR NOT EXISTS (SELECT FROM office_private.fixture_standings WHERE week_key=old_week AND player=unset_id AND earnings=0)
     OR NOT EXISTS (SELECT FROM public.players WHERE id=winner_id AND lifetime=1210 AND trophies=1
                    AND pp=0 AND week_pp=0 AND cycle=0 AND last_seen='2000-01-01Z') THEN
    RAISE EXCEPTION 'final payouts, archived results, reset, or retry incorrect';
  END IF;

  -- If the season is not a wipe, old earnings survive in the wallet while new accrual starts at the cutoff.
  UPDATE public.catalog SET data='{"wipe":false}' WHERE key='season';
  UPDATE public.players SET rate=0, week_pp=0, last_tick=week_cutoff;
  UPDATE public.players SET rate=2, pp=10, lifetime=10, cycle=10, week_pp=10, day_pp=10,
    last_tick=week_cutoff - interval '5 minutes' WHERE id=winner_id;
  UPDATE public.season_state SET current_week=old_week;
  DELETE FROM public.seasons;
  PERFORM public.roll_week();
  SELECT * INTO p FROM public.players WHERE id=winner_id;
  IF p.pp<>610 OR p.lifetime<>610 OR p.cycle<>610 OR p.day_pp<>610 OR p.week_pp<>0 OR p.last_tick<>week_cutoff THEN
    RAISE EXCEPTION 'no-wipe settlement routed old earnings incorrectly';
  END IF;
  expected := 2 * least(28800,extract(epoch FROM now()-week_cutoff));
  p := public.accrue(winner_id);
  IF abs(p.week_pp-expected)>0.001 OR abs(p.pp-expected-610)>0.001 THEN
    RAISE EXCEPTION 'new-week accrual double paid or lost the cutoff split';
  END IF;
  IF (public.accrue(winner_id)).week_pp <> p.week_pp THEN RAISE EXCEPTION 'same-transaction accrual replayed'; END IF;

  -- An office idle for an extra week must close the stored week at that week's own Pacific boundary.
  old_cutoff := ((week_cutoff AT TIME ZONE 'America/Los_Angeles') - interval '7 days') AT TIME ZONE 'America/Los_Angeles';
  old_week := week_key(old_cutoff - interval '1 microsecond');
  UPDATE public.players SET pp=0, week_pp=0, rate=0, last_tick=old_cutoff;
  UPDATE public.players SET rate=1, last_tick=old_cutoff - interval '2 minutes' WHERE id=winner_id;
  UPDATE public.season_state SET current_week=old_week;
  PERFORM public.roll_week();
  IF NOT EXISTS (SELECT FROM public.seasons WHERE week_key=old_week AND winner=winner_id AND top=120)
     OR NOT EXISTS (SELECT FROM public.players WHERE id=winner_id AND last_tick=week_cutoff AND pp=120 AND week_pp=0) THEN
    RAISE EXCEPTION 'late rollover drifted across weeks';
  END IF;
  RAISE NOTICE 'PASS Busywork cutoff: migration guards, offline caps, winner change, final standings, reset, retry, no-wipe split and late rollover';
END $test$;
