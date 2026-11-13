\set ON_ERROR_STOP on
DO $$BEGIN IF current_database()<>'idle_hands_test' THEN RAISE EXCEPTION 'disposable database required';END IF;END$$;
BEGIN;
-- Test-only clock adapter. Production race_now is SELECT now() and has no GUC.
CREATE OR REPLACE FUNCTION office_private.race_now() RETURNS timestamptz LANGUAGE sql STABLE SET search_path='' AS $$SELECT coalesce(nullif(current_setting('test.race_now',true),'')::timestamptz,now())$$;
DO $race$
DECLARE a uuid:='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';b uuid:='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';c uuid:='cccccccc-cccc-4ccc-8ccc-cccccccccccc';r jsonb;before_rows jsonb;after_rows jsonb;n integer;rejected boolean;old_week text;
BEGIN
 PERFORM set_config('request.jwt.claim.sub',a::text,true);
 PERFORM set_config('test.race_now','2026-11-14 07:59:59Z',true);
 UPDATE public.season_state SET current_week=public.week_key(office_private.race_now());
 UPDATE public.players SET pp=CASE id WHEN a THEN 1000 WHEN b THEN 2000 ELSE 3000 END,week_pp=CASE id WHEN c THEN 30 ELSE 100 END,last_tick='2026-11-14 05:00Z',last_restructure=null;
 IF office_private.capture_race()<>0 OR EXISTS(SELECT 1 FROM office_private.race_batches) THEN RAISE EXCEPTION 'disabled recorder captured';END IF;
 rejected:=false;BEGIN UPDATE office_private.race_control SET not_before='2026-11-13 23:59Z';EXCEPTION WHEN check_violation THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'Saturday gate can be weakened by configuration';END IF;
 UPDATE office_private.race_control SET enabled=true;
 IF office_private.capture_race()<>0 THEN RAISE EXCEPTION 'recording began before Saturday Pacific';END IF;
 PERFORM set_config('test.race_now','2026-11-14 08:20Z',true);IF public.office_race()->>'health'<>'delayed' THEN RAISE EXCEPTION 'missing first snapshot was not flagged as delayed';END IF;
 PERFORM set_config('test.race_now','2026-11-14 08:00:00Z',true);
 SELECT jsonb_agg(to_jsonb(p) ORDER BY id) INTO before_rows FROM public.players p;
 IF office_private.capture_race()<>3 OR office_private.capture_race()<>0 THEN RAISE EXCEPTION 'capture/replay count incorrect';END IF;
 SELECT jsonb_agg(to_jsonb(p) ORDER BY id) INTO after_rows FROM public.players p;
 IF before_rows<>after_rows THEN RAISE EXCEPTION 'snapshot changed players or settled income';END IF;
 old_week:=public.week_key(office_private.race_now());r:=public.office_race();
 IF r#>>'{health}'<>'recording' OR jsonb_array_length(r->'points')<>3 OR (SELECT count(*) FROM jsonb_array_elements(r->'points')p WHERE p->>'place'='1')<>2 THEN RAISE EXCEPTION 'snapshot/ties missing';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(r->'points')p WHERE p->>'player'<>a::text AND p?'balance') OR (SELECT p->>'balance' FROM jsonb_array_elements(r->'points')p WHERE p->>'player'=a::text)<>'1000' THEN RAISE EXCEPTION 'wallet privacy failed';END IF;
 IF r->>'first_sample_at'=r->>'starts_at' THEN RAISE EXCEPTION 'partial initial coverage was fabricated';END IF;
 UPDATE public.players SET week_pp=200,pp=50,last_restructure='2026-11-14 08:02Z' WHERE id=b;
 INSERT INTO public.deeds(actor,target,kind,created_at,hush) VALUES(b,a,'coffee','2026-11-14 08:03Z',false),(a,b,'credit','2026-11-14 08:04Z',true);
 PERFORM set_config('test.race_now','2026-11-14 08:05Z',true);PERFORM office_private.capture_race();
 r:=public.office_race(old_week,'2026-11-14');
 IF jsonb_array_length(r->'points')<>6 OR EXISTS(SELECT 1 FROM jsonb_array_elements(r->'events')e WHERE e->>'kind'='credit') OR (SELECT count(*) FROM jsonb_array_elements(r->'events')e WHERE e->>'source'='restructure')<>1 THEN RAISE EXCEPTION 'events leak hush or lose restructure';END IF;
 PERFORM set_config('request.jwt.claim.sub',b::text,true);r:=public.office_race(old_week,'2026-11-14');
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(r->'points')p WHERE p->>'player'<>b::text AND p?'balance') OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(r->'points')p WHERE p->>'player'=b::text AND p->>'balance'='50') THEN RAISE EXCEPTION 'wallet did not follow authenticated caller';END IF;
 r:=public.office_race(old_week,'2026-11-13');IF jsonb_array_length(r->'points')<>0 THEN RAISE EXCEPTION 'pre-coverage day has invented points';END IF;
 rejected:=false;BEGIN PERFORM public.office_race('unknown');EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'unknown week accepted';END IF;
 rejected:=false;BEGIN PERFORM public.office_race(old_week,'2000-01-01');EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'invalid day accepted';END IF;
 PERFORM set_config('test.race_now','2026-11-14 08:10Z',true);UPDATE public.season_state SET current_week='old-unclosed-week';
 IF office_private.capture_race()<>0 OR public.office_race()->>'health'<>'awaiting_rollover' THEN RAISE EXCEPTION 'old scores attributed to new week';END IF;
 UPDATE public.season_state SET current_week=old_week;PERFORM office_private.capture_race();
 IF (SELECT count(*) FROM office_private.race_restructures)<>1 THEN RAISE EXCEPTION 'restructure marker duplicated';END IF;
 PERFORM set_config('test.race_now','2026-11-14 08:40Z',true);IF public.office_race()->>'health'<>'delayed' THEN RAISE EXCEPTION 'stale recorder displayed as healthy';END IF;
 -- Real hourly archival keeps the initial point and last sample, not averages.
 PERFORM set_config('test.race_now','2027-01-16 08:00Z',true);UPDATE public.season_state SET current_week=public.week_key(office_private.race_now());PERFORM office_private.capture_race();
 IF (SELECT count(*) FROM office_private.race_batches WHERE week=old_week)<>2 OR NOT EXISTS(SELECT 1 FROM office_private.race_batches WHERE week=old_week AND recorded_at='2026-11-14 08:00Z') OR NOT EXISTS(SELECT 1 FROM office_private.race_batches WHERE week=old_week AND recorded_at='2026-11-14 08:10Z') THEN RAISE EXCEPTION 'hourly archival lost endpoints or retained every raw sample';END IF;
 r:=public.office_race(old_week,'2026-11-14');IF r->>'resolution_minutes'<>'60' OR jsonb_array_length(r->'points')<>6 THEN RAISE EXCEPTION 'old resolution is mislabelled';END IF;
 SELECT count(*) INTO n FROM office_private.race_points;PERFORM public.season_wipe();IF (SELECT count(*) FROM office_private.race_points)<>n THEN RAISE EXCEPTION 'normal wipe erased race history';END IF;
 -- Calendar endpoints retain the actual 167/169-hour Pacific weeks.
 PERFORM set_config('test.race_now','2027-03-14 10:00Z',true);UPDATE public.season_state SET current_week=public.week_key(office_private.race_now());PERFORM office_private.capture_race();
 IF (SELECT extract(epoch FROM ends_at-starts_at)/3600 FROM office_private.race_weeks WHERE week=public.week_key(office_private.race_now()))<>167 THEN RAISE EXCEPTION 'spring DST week length wrong';END IF;
 PERFORM set_config('test.race_now','2027-11-07 10:00Z',true);UPDATE public.season_state SET current_week=public.week_key(office_private.race_now());PERFORM office_private.capture_race();
 IF (SELECT extract(epoch FROM ends_at-starts_at)/3600 FROM office_private.race_weeks WHERE week=public.week_key(office_private.race_now()))<>169 THEN RAISE EXCEPTION 'fall DST week length wrong';END IF;
 IF has_function_privilege('anon','public.office_race(text,date)','EXECUTE') OR has_function_privilege('authenticated','office_private.capture_race()','EXECUTE') OR has_function_privilege('authenticated','office_private.race_now()','EXECUTE') OR has_table_privilege('authenticated','office_private.race_points','SELECT,INSERT,UPDATE,DELETE') OR EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='office_private' AND c.relname LIKE 'race_%' AND c.relkind='r' AND NOT c.relrowsecurity) THEN RAISE EXCEPTION 'private race grants/RLS incorrect';END IF;
 PERFORM set_config('request.jwt.claim.sub','',true);rejected:=false;BEGIN PERFORM public.office_race();EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'anonymous chart read accepted';END IF;
 PERFORM set_config('request.jwt.claim.sub','ffffffff-ffff-4fff-8fff-ffffffffffff',true);rejected:=false;BEGIN PERFORM public.office_race();EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'deleted-user chart read accepted';END IF;
 RAISE NOTICE 'PASS weekly race: Saturday gate, no player writes, consistent snapshots, ties/replay, own-only wallets, hush/restructure markers, partial days, late rollover, stale status, archival, normal wipe, DST, grants and auth';
END $race$;
ROLLBACK;
