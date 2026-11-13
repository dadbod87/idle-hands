\set ON_ERROR_STOP on
DO $$BEGIN IF current_database()<>'idle_hands_test' THEN RAISE EXCEPTION 'disposable database required';END IF;END$$;
BEGIN;
-- Test-only clock; the shipped private helper is SELECT now(), with no GUC.
CREATE OR REPLACE FUNCTION office_private.project_now() RETURNS timestamptz LANGUAGE sql STABLE SET search_path='' AS $$SELECT coalesce(nullif(current_setting('test.project_now',true),'')::timestamptz,now())$$;
DO $pacing$
DECLARE a uuid:='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';b uuid:='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';c uuid:='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
 people uuid[];actor uuid;category text;cfg office_private.projects;r jsonb;w text;first_w text;i int;j int;rejected boolean;before_players jsonb;now_players jsonb;start_time timestamptz;
BEGIN
 PERFORM set_config('request.jwt.claim.sub',a::text,true);
 DELETE FROM office_private.mementos;DELETE FROM office_private.project_completions;DELETE FROM office_private.daily_activity;DELETE FROM office_private.project_stamps;DELETE FROM office_private.projects;
 INSERT INTO public.players(id,name,pp) SELECT ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'Pacing fixture '||n,1000 FROM generate_series(4,7)n;
 SELECT array_agg(id ORDER BY id) INTO people FROM public.players;
 IF cardinality(people)<>7 THEN RAISE EXCEPTION 'seven synthetic participants required';END IF;
 SELECT jsonb_agg(to_jsonb(p) ORDER BY id) INTO before_players FROM public.players p;
 PERFORM set_config('test.project_now','2026-11-14 00:01Z',true);
 cfg:=office_private.ensure_project();first_w:=cfg.week;
 IF cfg.goal<>36 OR cfg.minimum_contributors<>3 OR cfg.minimum_days<>4 OR cfg.stretch_goal<>60 OR cfg.stretch_contributors<>5 OR cfg.stretch_days<>6 THEN RAISE EXCEPTION 'actual pacing defaults are wrong';END IF;
 -- Twenty bursts from seven coordinated players still produce just 21 credits.
 FOR j IN 1..20 LOOP
  FOREACH actor IN ARRAY people LOOP
   FOREACH category IN ARRAY ARRAY['work','facilities','care','playful'] LOOP PERFORM office_private.project_credit(actor,category);END LOOP;
  END LOOP;
 END LOOP;
 r:=public.office_week_status();
 IF r#>>'{project,total}'<>'21' OR r#>>'{project,active_days}'<>'1' OR r#>>'{project,completed}'<>'false' OR jsonb_array_length(r#>'{project,mine_today}')<>4 THEN RAISE EXCEPTION 'one-day spam bypassed daily uniqueness or UI accounting';END IF;
 -- Outside-window, future and older-week rows must not invent current progress.
 INSERT INTO office_private.daily_activity(actor,week,day,category) VALUES(a,first_w,'2026-11-12',cfg.categories[1]),(a,first_w,'2026-11-19',cfg.categories[1]),(a,'old-fixture','2026-11-13',cfg.categories[1]);
 IF public.office_week_status()#>>'{project,total}'<>'21' THEN RAISE EXCEPTION 'out-of-window progress leaked';END IF;
 -- A midnight crossing in the first 12 hours cannot finish the project either.
 PERFORM set_config('test.project_now','2026-11-14 12:01Z',true);
 FOREACH actor IN ARRAY people LOOP FOREACH category IN ARRAY cfg.categories LOOP PERFORM office_private.project_credit(actor,category);END LOOP;END LOOP;
 r:=public.office_week_status();IF r#>>'{project,total}'<>'42' OR r#>>'{project,active_days}'<>'2' OR r#>>'{project,completed}'<>'false' OR EXISTS(SELECT 1 FROM office_private.mementos WHERE week=first_w) THEN RAISE EXCEPTION 'seven players finished in twelve hours';END IF;
 FOR i IN 2..5 LOOP
  PERFORM set_config('test.project_now',('2026-11-14 08:01Z'::timestamptz+make_interval(days=>i-1))::text,true);
  FOREACH actor IN ARRAY people LOOP FOREACH category IN ARRAY cfg.categories LOOP PERFORM office_private.project_credit(actor,category);END LOOP;END LOOP;
  r:=public.office_week_status();
  IF i=2 AND r#>>'{project,completed}'<>'false' THEN RAISE EXCEPTION 'three dates completed four-date project';END IF;
  IF i=3 AND (r#>>'{project,completed}'<>'true' OR (SELECT count(*) FROM office_private.mementos WHERE week=first_w)<>7) THEN RAISE EXCEPTION 'four-date base completion or rewards failed';END IF;
  IF i<5 AND r#>>'{project,stretch_completed}'<>'false' THEN RAISE EXCEPTION 'stretch finished before six dates';END IF;
 END LOOP;
 IF public.office_week_status()#>>'{project,stretch_completed}'<>'true' OR (SELECT count(*) FROM office_private.mementos WHERE week=first_w AND stretch)<>7 THEN RAISE EXCEPTION 'six-date stretch/rewards missing';END IF;
 -- Two dominant players cannot replace the third contributor, even over six dates.
 PERFORM set_config('test.project_now','2026-11-21 00:01Z',true);cfg:=office_private.ensure_project();w:=cfg.week;
 FOR i IN 0..5 LOOP
  PERFORM set_config('test.project_now',('2026-11-21 00:01Z'::timestamptz+make_interval(days=>i))::text,true);
  FOREACH actor IN ARRAY ARRAY[a,b] LOOP FOREACH category IN ARRAY cfg.categories LOOP PERFORM office_private.project_credit(actor,category);END LOOP;END LOOP;
 END LOOP;
 r:=public.office_week_status();IF r#>>'{project,total}'<>'36' OR r#>>'{project,contributors}'<>'2' OR r#>>'{project,completed}'<>'false' THEN RAISE EXCEPTION 'two players bypassed contributor minimum';END IF;
 PERFORM office_private.project_credit(c,cfg.categories[1]);
 IF public.office_week_status()#>>'{project,completed}'<>'true' THEN RAISE EXCEPTION 'third eligible contributor did not unlock earned completion';END IF;
 -- Five people, two categories each day, reach exactly 60 on date six.
 PERFORM set_config('test.project_now','2026-11-28 00:01Z',true);cfg:=office_private.ensure_project();w:=cfg.week;
 FOR i IN 0..5 LOOP
  PERFORM set_config('test.project_now',('2026-11-28 00:01Z'::timestamptz+make_interval(days=>i))::text,true);
  FOR j IN 1..5 LOOP
   PERFORM office_private.project_credit(people[j],cfg.categories[1]);
   IF i=5 AND j=5 THEN CONTINUE;END IF;
   PERFORM office_private.project_credit(people[j],cfg.categories[2]);
  END LOOP;
 END LOOP;
 r:=public.office_week_status();IF r#>>'{project,total}'<>'59' OR r#>>'{project,stretch_completed}'<>'false' THEN RAISE EXCEPTION 'stretch ignored exact contribution threshold';END IF;
 PERFORM office_private.project_credit(people[5],cfg.categories[2]);
 r:=public.office_week_status();IF r#>>'{project,total}'<>'60' OR r#>>'{project,stretch_completed}'<>'true' THEN RAISE EXCEPTION 'exact sixty-credit stretch failed';END IF;
 -- A fresh Friday has no project progress; archived rewards remain intact.
 PERFORM set_config('test.project_now','2026-12-05 00:01Z',true);r:=public.office_week_status();
 IF r#>>'{project,total}'<>'0' OR r#>>'{project,active_days}'<>'0' OR (SELECT count(*) FROM office_private.mementos WHERE week=first_w)<>7 THEN RAISE EXCEPTION 'weekly isolation or archived rewards failed';END IF;
 SELECT jsonb_agg(to_jsonb(p) ORDER BY id) INTO now_players FROM public.players p;
 IF now_players<>before_players THEN RAISE EXCEPTION 'project pacing changed player money/inventory/progress';END IF;
 IF has_function_privilege('authenticated','office_private.project_now()','EXECUTE') OR has_function_privilege('anon','office_private.project_progress(text,timestamptz)','EXECUTE') THEN RAISE EXCEPTION 'private pacing helper exposed';END IF;
 RAISE NOTICE 'PASS project pacing: actual 36/3/4 and 60/5/6 defaults, one-day spam and twelve-hour rush refusal, time-window isolation, two-leader refusal, exact sixty-credit stretch, real completion/rewards, weekly isolation and unchanged players';
END $pacing$;
ROLLBACK;
