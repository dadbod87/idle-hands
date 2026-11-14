-- HELD. Run only after the reviewed frontend is confirmed live in Production.
-- First activation opens recording at this transaction's time, never retroactively.
BEGIN;
DO $activate_race$
DECLARE clock timestamptz:=office_private.race_now();actual text;
BEGIN
 IF clock<'2026-11-14 00:00:00Z' THEN RAISE EXCEPTION 'race activation is held until Friday 4 PM Pacific';END IF;
 SELECT current_week INTO actual FROM public.season_state WHERE id=1 FOR SHARE;
 IF actual IS DISTINCT FROM public.week_key(clock) THEN RAISE EXCEPTION 'normal rollover is incomplete';END IF;
 IF (SELECT count(*) FROM cron.job WHERE jobname='idle-hands-weekly-race' AND active AND
  command='SELECT office_private.capture_race();' AND schedule='*/5 * * * *' AND database=current_database() AND username=current_user)<>1
 OR EXISTS(SELECT 1 FROM cron.job WHERE jobname='idle-hands-weekly-race' AND
  (command<>'SELECT office_private.capture_race();' OR schedule<>'*/5 * * * *' OR database<>current_database() OR username<>current_user)) THEN
  RAISE EXCEPTION 'race scheduler missing or definition drift; prepare and verify before activation';
 END IF;
 UPDATE office_private.race_control SET enabled=true,not_before=clock WHERE id=true AND NOT enabled;
 IF NOT EXISTS(SELECT 1 FROM office_private.race_control WHERE id=true AND enabled) THEN RAISE EXCEPTION 'race backend is missing';END IF;
END $activate_race$;
COMMIT;
