-- Private recorded race history. No player writes, accrual or reset.
CREATE TABLE office_private.race_control(
 id boolean PRIMARY KEY DEFAULT true CHECK(id),enabled boolean NOT NULL DEFAULT false,
 not_before timestamptz NOT NULL DEFAULT '2026-11-14 08:00:00Z' CHECK(not_before>='2026-11-14 08:00:00Z'::timestamptz),
 compacted_before timestamptz NOT NULL DEFAULT '-infinity'
);
INSERT INTO office_private.race_control(id) VALUES(true);
CREATE TABLE office_private.race_weeks(
 week text PRIMARY KEY,starts_at timestamptz NOT NULL,ends_at timestamptz NOT NULL,
 first_sample_at timestamptz NOT NULL,last_sample_at timestamptz NOT NULL,
 CHECK(ends_at>starts_at AND first_sample_at>=starts_at AND last_sample_at<ends_at)
);
CREATE TABLE office_private.race_batches(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 week text NOT NULL REFERENCES office_private.race_weeks(week),
 bucket timestamptz NOT NULL,recorded_at timestamptz NOT NULL,UNIQUE(week,bucket)
);
CREATE INDEX race_batches_week_time ON office_private.race_batches(week,recorded_at);
CREATE TABLE office_private.race_points(
 batch bigint NOT NULL REFERENCES office_private.race_batches(id) ON DELETE CASCADE,
 player uuid NOT NULL,name text NOT NULL,weekly_earnings float8 NOT NULL,
 balance float8 NOT NULL,place bigint NOT NULL CHECK(place>0),last_settled timestamptz,
 PRIMARY KEY(batch,player),
 CHECK(weekly_earnings>=0 AND weekly_earnings<'Infinity'::float8),
 CHECK(balance>'-Infinity'::float8 AND balance<'Infinity'::float8)
);
CREATE TABLE office_private.race_restructures(
 week text NOT NULL REFERENCES office_private.race_weeks(week),player uuid NOT NULL,
 happened_at timestamptz NOT NULL,name text NOT NULL,PRIMARY KEY(week,player,happened_at)
);
ALTER TABLE office_private.race_control ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.race_weeks ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.race_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.race_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.race_restructures ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON office_private.race_control,office_private.race_weeks,office_private.race_batches,office_private.race_points,office_private.race_restructures FROM PUBLIC,anon,authenticated;
REVOKE ALL ON SEQUENCE office_private.race_batches_id_seq FROM PUBLIC,anon,authenticated;
CREATE FUNCTION office_private.race_now() RETURNS timestamptz LANGUAGE sql STABLE SET search_path='' AS $$SELECT now()$$;
REVOKE ALL ON FUNCTION office_private.race_now() FROM PUBLIC,anon,authenticated;

CREATE FUNCTION office_private.capture_race() RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE clock timestamptz:=office_private.race_now();cfg office_private.race_control;w text;actual text;start_at timestamptz;end_at timestamptz;batch_id bigint;n integer;cutoff timestamptz;
BEGIN
 IF NOT pg_try_advisory_xact_lock(728194,4) THEN RETURN 0;END IF;
 SELECT * INTO cfg FROM office_private.race_control WHERE id=true;
 IF cfg.id IS DISTINCT FROM true OR NOT cfg.enabled OR clock<cfg.not_before THEN RETURN 0;END IF;
 -- The normal roller holds this row FOR UPDATE until its wipe is complete.
 SELECT current_week INTO actual FROM public.season_state WHERE id=1 FOR SHARE;
 w:=public.week_key(clock);
 IF actual IS DISTINCT FROM w THEN RETURN 0;END IF;
 start_at:=public.week_started(clock);
 end_at:=((start_at AT TIME ZONE 'America/Los_Angeles')+interval '7 days') AT TIME ZONE 'America/Los_Angeles';
 IF NOT EXISTS(SELECT 1 FROM public.players) THEN RETURN 0;END IF;
 INSERT INTO office_private.race_weeks(week,starts_at,ends_at,first_sample_at,last_sample_at)
 VALUES(w,start_at,end_at,clock,clock) ON CONFLICT DO NOTHING;
 IF clock<(SELECT last_sample_at FROM office_private.race_weeks WHERE week=w) THEN RETURN 0;END IF;
 INSERT INTO office_private.race_batches(week,bucket,recorded_at)
 VALUES(w,to_timestamp(floor(extract(epoch FROM clock)/300)*300),clock)
 ON CONFLICT DO NOTHING RETURNING id INTO batch_id;
 IF batch_id IS NULL THEN RETURN 0;END IF;
 INSERT INTO office_private.race_points(batch,player,name,weekly_earnings,balance,place,last_settled)
 SELECT batch_id,id,name,week_pp,pp,rank() OVER(ORDER BY week_pp DESC),last_tick FROM public.players;
 GET DIAGNOSTICS n=ROW_COUNT;
 INSERT INTO office_private.race_restructures(week,player,happened_at,name)
 SELECT w,p.id,p.last_restructure,p.name FROM public.players p
 WHERE p.last_restructure>=(SELECT first_sample_at FROM office_private.race_weeks WHERE week=w)
 AND p.last_restructure<=clock AND p.last_restructure>=start_at AND p.last_restructure<end_at
 ON CONFLICT DO NOTHING;
 UPDATE office_private.race_weeks SET last_sample_at=clock WHERE week=w;
 -- Compact newly expired complete UTC days once daily. Keep real hourly values
 -- and the first sample; never average ranks or interpolate past wallet values.
 cutoff:=(date_trunc('day',clock AT TIME ZONE 'UTC')-interval '56 days') AT TIME ZONE 'UTC';
 IF cutoff>cfg.compacted_before THEN
  WITH old AS(
   SELECT b.id,b.recorded_at,wk.first_sample_at,
    row_number() OVER(PARTITION BY b.week,date_trunc('hour',b.recorded_at AT TIME ZONE 'UTC') ORDER BY b.recorded_at DESC,b.id DESC) rn
   FROM office_private.race_batches b JOIN office_private.race_weeks wk USING(week)
   WHERE b.recorded_at>=cfg.compacted_before AND b.recorded_at<cutoff
  ) DELETE FROM office_private.race_batches b USING old x WHERE b.id=x.id AND x.rn>1 AND x.recorded_at<>x.first_sample_at;
  IF to_regclass('cron.job_run_details') IS NOT NULL THEN
   EXECUTE 'DELETE FROM cron.job_run_details WHERE jobid IN(SELECT jobid FROM cron.job WHERE jobname=$1) AND end_time<$2' USING 'idle-hands-weekly-race',clock-interval '14 days';
  END IF;
  UPDATE office_private.race_control SET compacted_before=cutoff WHERE id=true;
 END IF;
 RETURN n;
END $$;
REVOKE ALL ON FUNCTION office_private.capture_race() FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.office_race(p_week text DEFAULT NULL,p_day date DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();clock timestamptz:=office_private.race_now();cfg office_private.race_control;
 chosen text;current_w text:=public.week_key(clock);r office_private.race_weeks;from_at timestamptz;to_at timestamptz;points jsonb;people jsonb;events jsonb;event_count integer;days jsonb;weeks jsonb;health text;
BEGIN
 IF u IS NULL OR NOT EXISTS(SELECT 1 FROM public.players WHERE id=u) THEN RAISE EXCEPTION 'not signed in';END IF;
 SELECT * INTO cfg FROM office_private.race_control WHERE id=true;
 chosen:=coalesce(p_week,current_w);
 SELECT * INTO r FROM office_private.race_weeks WHERE week=chosen;
 IF r.week IS NULL AND chosen<>current_w THEN RAISE EXCEPTION 'choose a recorded week';END IF;
 IF r.week IS NULL THEN
  r.week:=current_w;r.starts_at:=public.week_started(clock);
  r.ends_at:=((r.starts_at AT TIME ZONE 'America/Los_Angeles')+interval '7 days') AT TIME ZONE 'America/Los_Angeles';
 END IF;
 from_at:=r.starts_at;to_at:=r.ends_at;
 IF p_day IS NOT NULL THEN
  IF p_day<(r.starts_at AT TIME ZONE 'America/Los_Angeles')::date OR p_day>(r.ends_at AT TIME ZONE 'America/Los_Angeles')::date THEN RAISE EXCEPTION 'choose a date inside this week';END IF;
  from_at:=greatest(from_at,p_day::timestamp AT TIME ZONE 'America/Los_Angeles');
  to_at:=least(to_at,(p_day+1)::timestamp AT TIME ZONE 'America/Los_Angeles');
  IF from_at>=to_at THEN RAISE EXCEPTION 'choose a date inside this week';END IF;
 END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('week',s.week,'starts_at',s.starts_at,'first_sample_at',s.first_sample_at,'last_sample_at',s.last_sample_at) ORDER BY s.starts_at DESC),'[]') INTO weeks
 FROM(SELECT week,starts_at,first_sample_at,last_sample_at FROM office_private.race_weeks ORDER BY starts_at DESC LIMIT 104)s;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(weeks) x WHERE x->>'week'=current_w) THEN
  weeks:=jsonb_build_array(jsonb_build_object('week',current_w,'starts_at',public.week_started(clock),'first_sample_at',null,'last_sample_at',null))||weeks;
 END IF;
 SELECT coalesce(jsonb_agg(d.sample_day ORDER BY d.sample_day),'[]') INTO days FROM(
  SELECT DISTINCT (recorded_at AT TIME ZONE 'America/Los_Angeles')::date AS sample_day FROM office_private.race_batches WHERE week=chosen)d;
 WITH batches AS(
  SELECT b.*,row_number() OVER(PARTITION BY date_trunc('hour',b.recorded_at AT TIME ZONE 'UTC') ORDER BY b.recorded_at DESC,b.id DESC) rn
  FROM office_private.race_batches b WHERE b.week=chosen AND b.recorded_at>=from_at AND b.recorded_at<to_at
 ), selected AS(SELECT * FROM batches WHERE p_day IS NOT NULL OR rn=1 OR recorded_at=r.first_sample_at)
 SELECT coalesce(jsonb_agg(jsonb_build_object('at',b.recorded_at,'player',p.player,'name',p.name,'weekly_earnings',p.weekly_earnings,'place',p.place,'last_settled',p.last_settled)
  ||CASE WHEN p.player=u THEN jsonb_build_object('balance',p.balance) ELSE '{}'::jsonb END ORDER BY b.recorded_at,p.place,p.player),'[]') INTO points
 FROM selected b JOIN office_private.race_points p ON p.batch=b.id;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) ORDER BY name,id),'[]') INTO people FROM(
  SELECT DISTINCT ON(p.player) p.player id,p.name FROM office_private.race_points p JOIN office_private.race_batches b ON b.id=p.batch WHERE b.week=chosen ORDER BY p.player,b.recorded_at DESC
 )s;
 IF jsonb_array_length(people)=0 THEN SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) ORDER BY name,id),'[]') INTO people FROM public.players;END IF;
 WITH visible AS(
  SELECT h.happened_at AS "at",h.actor player,h.target,h.kind,h.category,'public_action'::text source FROM office_private.action_history h
  WHERE h.week=chosen AND NOT h.hush AND h.happened_at>=greatest(from_at,r.first_sample_at) AND h.happened_at<to_at AND r.first_sample_at IS NOT NULL
  UNION ALL SELECT happened_at,player,null::uuid,'restructure','restructure','restructure' FROM office_private.race_restructures
  WHERE week=chosen AND happened_at>=from_at AND happened_at<to_at
 ), bounded AS(SELECT * FROM visible ORDER BY "at" DESC,player,kind LIMIT 200)
 SELECT coalesce((SELECT jsonb_agg(to_jsonb(bounded) ORDER BY "at",player,kind) FROM bounded),'[]'),(SELECT count(*) FROM visible) INTO events,event_count;
 health:=CASE WHEN NOT cfg.enabled THEN 'paused' WHEN clock<cfg.not_before THEN 'scheduled'
 WHEN (SELECT current_week FROM public.season_state WHERE id=1) IS DISTINCT FROM current_w THEN 'awaiting_rollover'
 WHEN chosen<>current_w THEN 'archived' WHEN r.last_sample_at IS NULL THEN CASE WHEN clock>=greatest(cfg.not_before,r.starts_at)+interval '15 minutes' THEN 'delayed' ELSE 'waiting' END
 WHEN r.last_sample_at<clock-interval '15 minutes' THEN 'delayed' ELSE 'recording' END;
 RETURN jsonb_build_object('version',1,'server_now',clock,'selected_week',chosen,'selected_day',p_day,'weeks',weeks,'days',days,'players',people,
 'starts_at',r.starts_at,'ends_at',r.ends_at,'range_start',from_at,'range_end',to_at,'first_sample_at',r.first_sample_at,'last_sample_at',r.last_sample_at,'not_before',cfg.not_before,'health',health,
 'resolution_minutes',CASE WHEN p_day IS NOT NULL AND coalesce(r.last_sample_at,clock)>=clock-interval '56 days' THEN 5 ELSE 60 END,
 'points',points,'events',events,'omitted_events',greatest(0,event_count-200),
 'note','Recorded totals, not projected offline income. Missing samples stay gaps. Recent detail is retained for eight weeks; older charts use actual hourly samples. Only you can see your spendable-balance history.');
END $$;
REVOKE ALL ON FUNCTION public.office_race(text,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.office_race(text,date) TO authenticated;
