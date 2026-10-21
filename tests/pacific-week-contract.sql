-- Isolated only, after weekly-deadline-contract.sql. No production player tests.
CREATE TABLE public.season_state(id integer PRIMARY KEY,current_week text);
INSERT INTO public.season_state SELECT 1,to_char(date_trunc('week',now() AT TIME ZONE 'America/Los_Angeles') + CASE WHEN (now() AT TIME ZONE 'America/Los_Angeles') >= date_trunc('week',now() AT TIME ZONE 'America/Los_Angeles')+interval '4 days 16 hours' THEN interval '7 days' ELSE interval '0 days' END,'IYYY-IW');
CREATE TEMP TABLE preserved_players AS SELECT to_jsonb(p) AS snapshot FROM public.players p;
\i supabase/migrations/20261021171655_pacific_week_close.sql
DO $tests$
DECLARE test_case record; s jsonb; finish timestamptz;
BEGIN
 FOR test_case IN SELECT * FROM (VALUES
  ('2026-10-23T21:00:00Z','2026-10-16T23:00:00Z','2026-43'), -- old Eastern cutoff no longer rolls
  ('2026-10-23T22:59:59Z','2026-10-16T23:00:00Z','2026-43'),
  ('2026-10-23T23:00:00Z','2026-10-23T23:00:00Z','2026-44'),
  ('2026-10-24T12:00:00Z','2026-10-23T23:00:00Z','2026-44'),
  ('2026-11-06T23:59:59Z','2026-10-30T23:00:00Z','2026-45'),
  ('2026-11-07T00:00:00Z','2026-11-07T00:00:00Z','2026-46'),
  ('2026-03-13T22:59:59Z','2026-03-07T00:00:00Z','2026-11'),
  ('2026-03-13T23:00:00Z','2026-03-13T23:00:00Z','2026-12'),
  ('2027-01-01T23:59:59Z','2026-12-26T00:00:00Z','2026-53'),
  ('2027-01-02T00:00:00Z','2027-01-02T00:00:00Z','2027-01')
 ) AS cases(clock,expected_start,expected_key) LOOP
  IF public.week_started(test_case.clock::timestamptz)<>test_case.expected_start::timestamptz OR public.week_key(test_case.clock::timestamptz)<>test_case.expected_key THEN RAISE EXCEPTION 'Wrong Pacific boundary/key at %',test_case.clock; END IF;
  finish:=((public.week_started(test_case.clock::timestamptz) AT TIME ZONE 'America/Los_Angeles')+interval '7 days') AT TIME ZONE 'America/Los_Angeles';
  IF finish<=test_case.clock::timestamptz OR to_char(finish AT TIME ZONE 'America/Los_Angeles','Dy HH24:MI')<>'Fri 16:00' THEN RAISE EXCEPTION 'Wrong next Pacific cutoff at %',test_case.clock; END IF;
 END LOOP;
 s:=public.weekly_schedule();
 IF s->>'timezone'<>'America/Los_Angeles' OR (s->>'starts_at')::timestamptz<>public.week_started() OR (s->>'ends_at')::timestamptz<=now() THEN RAISE EXCEPTION 'Schedule RPC disagrees with scoring boundary'; END IF;
 IF has_function_privilege('anon','public.weekly_schedule()','EXECUTE') THEN RAISE EXCEPTION 'Schedule grants widened'; END IF;
 IF EXISTS((SELECT to_jsonb(p) FROM public.players p EXCEPT SELECT snapshot FROM preserved_players) UNION ALL (SELECT snapshot FROM preserved_players EXCEPT SELECT to_jsonb(p) FROM public.players p)) THEN RAISE EXCEPTION 'Pacific migration changed players'; END IF;
 IF (SELECT tz FROM public.office_door WHERE id=1)<>'America/New_York' THEN RAISE EXCEPTION 'Unrelated work-hour timezone changed'; END IF;
 IF (SELECT current_week FROM public.season_state WHERE id=1)<>public.week_key() THEN RAISE EXCEPTION 'Installation advanced/rewound active season'; END IF;
 RAISE NOTICE 'PASS: Friday 16:00 Pacific, old cutoff ignored, DST, ISO year, schedule consistency, unchanged full player rows and work-hour timezone';
END $tests$;
