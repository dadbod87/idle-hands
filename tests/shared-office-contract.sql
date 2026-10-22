-- Isolated PostgreSQL only. Applies the actual additive migration to synthetic players.
BEGIN;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS name text DEFAULT 'Fixture';
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS signed_at timestamptz DEFAULT now();
INSERT INTO public.players(id,name,signed_at) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Fixture A',now()),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Fixture B',now()),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','Fixture C',now())
ON CONFLICT(id) DO UPDATE SET name=excluded.name,signed_at=excluded.signed_at;
CREATE TEMP TABLE comedy_players_before AS SELECT to_jsonb(p) snapshot FROM public.players p;
\i supabase/migrations/20261022135640_shared_office_stories.sql
SELECT set_config('test.employee_id','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false);
DO $test$
DECLARE s jsonb; rejected boolean; bad text; i integer;
BEGIN
 s:=public.office_play_state();
 IF (s#>>'{poll,total}')::int<>0 OR s#>'{poll,counts}'<>'[0,0,0]'::jsonb OR s->>'week'<>public.week_key() THEN RAISE EXCEPTION 'initial shared state incorrect'; END IF;
 IF (s->>'ends_at')::timestamptz<>((public.week_started() AT TIME ZONE 'America/Los_Angeles')+interval '7 days') AT TIME ZONE 'America/Los_Angeles' THEN RAISE EXCEPTION 'Pacific deadline mismatch'; END IF;
 PERFORM public.office_vote(0,public.week_key());s:=public.office_vote(2,public.week_key());
 IF (s#>>'{poll,total}')::int<>1 OR s#>>'{poll,mine}'<>'2' OR s#>'{poll,counts}'<>'[0,0,1]'::jsonb THEN RAISE EXCEPTION 'vote change duplicated ballot'; END IF;
 FOREACH bad IN ARRAY ARRAY['select public.office_vote(0,''old-week'')','select public.office_vote(-1,public.week_key())','select public.office_vote(null,public.week_key())','select public.office_vote(3,public.week_key())',
 'select public.office_perform(''invented'')','select public.office_perform(null)',
 'select public.office_nominate(''glue'',''aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'',public.week_key())',
 'select public.office_nominate(''glue'',''dddddddd-dddd-4ddd-8ddd-dddddddddddd'',public.week_key())',
 'select public.office_nominate(''glue'',''bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'',''old-week'')','select public.office_nominate(''fake'',''bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'',public.week_key())'] LOOP
 rejected:=false;BEGIN EXECUTE bad;EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'invalid input accepted: %',bad; END IF;
 END LOOP;
 PERFORM public.office_nominate('glue','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',public.week_key());s:=public.office_nominate('glue','cccccccc-cccc-4ccc-8ccc-cccccccccccc',public.week_key());
 IF jsonb_array_length(s->'nominations')<>1 OR s#>>'{my_nominations,glue}'<>'cccccccc-cccc-4ccc-8ccc-cccccccccccc' THEN RAISE EXCEPTION 'nomination update duplicated';END IF;
 PERFORM public.office_perform('plant');s:=public.office_perform('plant');
 IF s#>>'{actions,plant}'<>'1' THEN RAISE EXCEPTION 'immediate replay counted';END IF;
 FOR i IN 1..10 LOOP
 UPDATE public.office_play_actions SET updated_at=now()-interval '16 seconds' WHERE actor=auth.uid() AND kind='plant';
 s:=public.office_perform('plant');
 END LOOP;
 IF s#>>'{actions,plant}'<>'6' OR s#>>'{hydrators,0,name}'<>'Fixture A' THEN RAISE EXCEPTION 'bounded real activity tally incorrect';END IF;
 PERFORM set_config('test.employee_id','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',false);
 s:=public.office_vote(0,public.week_key());PERFORM public.office_nominate('glue','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',public.week_key());s:=public.office_perform('bench');
 IF s#>>'{poll,total}'<>'2' OR s#>>'{poll,mine}'<>'0' OR jsonb_array_length(s->'nominations')<>2 OR s->>'contributors'<>'2' THEN RAISE EXCEPTION 'cross-player state missing';END IF;
 -- Previous-cycle results are real separate rows, never the current ballot.
 INSERT INTO public.office_play_votes(week,voter,choice) VALUES(public.week_key(public.week_started()-interval '1 second'),auth.uid(),1);
 INSERT INTO public.office_play_nominations(week,voter,category,recipient) VALUES(public.week_key(public.week_started()-interval '1 second'),auth.uid(),'escape','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
 s:=public.office_play_state();IF jsonb_array_length(s->'previous_nominations')<>1 OR jsonb_array_length(s->'nominations')<>2 THEN RAISE EXCEPTION 'past commendations mixed into current';END IF;IF s#>>'{previous_poll,total}'<>'1' OR s#>'{previous_poll,counts}'<>'[0,1,0]'::jsonb OR s#>>'{poll,total}'<>'2' THEN RAISE EXCEPTION 'prior cycle mixed into current';END IF;
 PERFORM set_config('test.employee_id','',false);rejected:=false;BEGIN PERFORM public.office_play_state();EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'anonymous state accepted';END IF;
 IF has_function_privilege('anon','public.office_vote(integer,text)','EXECUTE') OR has_function_privilege('authenticated','public.office_poll_summary(text)','EXECUTE') OR has_table_privilege('authenticated','public.office_play_votes','INSERT') OR has_table_privilege('authenticated','public.office_play_actions','SELECT') THEN RAISE EXCEPTION 'unsafe grants'; END IF;
 IF EXISTS(SELECT 1 FROM pg_class WHERE oid IN ('public.office_play_votes'::regclass,'public.office_play_nominations'::regclass,'public.office_play_actions'::regclass) AND NOT relrowsecurity) THEN RAISE EXCEPTION 'RLS missing';END IF;
 IF EXISTS((SELECT snapshot FROM comedy_players_before EXCEPT SELECT to_jsonb(p) FROM public.players p) UNION ALL (SELECT to_jsonb(p) FROM public.players p EXCEPT SELECT snapshot FROM comedy_players_before)) THEN RAISE EXCEPTION 'existing player data modified'; END IF;
END $test$;
ROLLBACK;
