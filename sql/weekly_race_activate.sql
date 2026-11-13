-- HELD. Run only after verified normal Friday rollover and full backend verification.
-- This enables the scheduler; capture still refuses any time before Saturday.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
GRANT USAGE ON SCHEMA cron TO CURRENT_USER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cron TO CURRENT_USER;
DO $activate_race$
DECLARE clock timestamptz:=office_private.race_now();j bigint;actual text;
BEGIN
 IF clock<'2026-11-14 00:00:00Z' THEN RAISE EXCEPTION 'race activation is held until Friday 4 PM Pacific';END IF;
 SELECT current_week INTO actual FROM public.season_state WHERE id=1 FOR SHARE;
 IF actual IS DISTINCT FROM public.week_key(clock) THEN RAISE EXCEPTION 'normal rollover is incomplete';END IF;
 IF EXISTS(SELECT 1 FROM cron.job WHERE jobname='idle-hands-weekly-race' AND
  (command<>'SELECT office_private.capture_race();' OR schedule<>'*/5 * * * *' OR database<>current_database() OR username<>current_user)) THEN
  RAISE EXCEPTION 'race scheduler definition drift; investigate before activation';
 END IF;
 SELECT cron.schedule('idle-hands-weekly-race','*/5 * * * *','SELECT office_private.capture_race();') INTO j;
 UPDATE office_private.race_control SET enabled=true WHERE id=true;
 IF NOT FOUND THEN RAISE EXCEPTION 'race backend is missing';END IF;
END $activate_race$;
COMMIT;
