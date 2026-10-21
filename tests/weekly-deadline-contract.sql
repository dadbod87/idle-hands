-- Isolated only, after office-awards-contract.sql. Never run this fixture on Production.
CREATE TABLE public.office_door(id integer PRIMARY KEY,tz text);
INSERT INTO public.office_door VALUES(1,'America/New_York');
-- Existing production boundary definition, with a fixture-only controllable input clock.
CREATE FUNCTION public.week_started(ts timestamptz DEFAULT now()) RETURNS timestamptz
LANGUAGE plpgsql STABLE AS $$
DECLARE v_tz text; loc timestamp; monday timestamp; cutoff timestamp;
BEGIN
 ts:=coalesce(nullif(current_setting('test.schedule_now',true),'')::timestamptz,ts);
 SELECT coalesce(tz,'UTC') INTO v_tz FROM public.office_door WHERE id=1;
 loc:=ts AT TIME ZONE v_tz; monday:=date_trunc('week',loc);
 cutoff:=monday+interval '4 days 17 hours';
 IF loc<cutoff THEN cutoff:=cutoff-interval '7 days'; END IF;
 RETURN cutoff AT TIME ZONE v_tz;
END $$;
\i supabase/migrations/20261021170311_weekly_deadline.sql
DO $tests$
DECLARE s jsonb; test_case record; denied boolean;
BEGIN
 IF has_function_privilege('anon','public.weekly_schedule()','EXECUTE') OR NOT has_function_privilege('authenticated','public.weekly_schedule()','EXECUTE') THEN RAISE EXCEPTION 'Wrong schedule grants'; END IF;
 denied:=false; BEGIN PERFORM public.weekly_schedule(); EXCEPTION WHEN others THEN denied:=true; END;
 IF NOT denied THEN RAISE EXCEPTION 'Unsigned schedule accepted'; END IF;
 PERFORM set_config('test.employee_id','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false);
 FOR test_case IN SELECT * FROM (VALUES
  ('2026-10-21T17:00:00Z','2026-10-23T21:00:00Z'),
  ('2026-10-23T20:59:59Z','2026-10-23T21:00:00Z'),
  ('2026-10-23T21:00:00Z','2026-10-30T21:00:00Z'),
  ('2026-10-24T12:00:00Z','2026-10-30T21:00:00Z'),
  ('2026-10-31T12:00:00Z','2026-11-06T22:00:00Z'),
  ('2026-03-07T12:00:00Z','2026-03-13T21:00:00Z'),
  ('2026-12-31T12:00:00Z','2027-01-01T22:00:00Z')
 ) AS cases(clock,expected_end) LOOP
  PERFORM set_config('test.schedule_now',test_case.clock,false);
  s:=public.weekly_schedule();
  IF (s->>'ends_at')::timestamptz<>test_case.expected_end::timestamptz OR s->>'timezone'<>'America/New_York' OR s->>'server_now' IS NULL THEN RAISE EXCEPTION 'Incorrect schedule at %: %',test_case.clock,s; END IF;
 END LOOP;
 IF (SELECT pp FROM public.players WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')<>1234 THEN RAISE EXCEPTION 'Schedule changed player progress'; END IF;
 RAISE NOTICE 'PASS: server schedule auth, Friday cutoff, weekend, DST transitions, year boundary and read-only progress';
END $tests$;
