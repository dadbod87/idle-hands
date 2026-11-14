-- HELD. Prepare only after verified normal Friday rollover and full backend verification.
-- Recording remains disabled while the real scheduler is verified before publication.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
GRANT USAGE ON SCHEMA cron TO CURRENT_USER;
GRANT SELECT ON cron.job,cron.job_run_details TO CURRENT_USER;
DO $prepare_race$
DECLARE clock timestamptz:=office_private.race_now();j bigint;actual text;
BEGIN
 IF clock<'2026-11-14 00:00:00Z' THEN RAISE EXCEPTION 'race preparation is held until Friday 4 PM Pacific';END IF;
 SELECT current_week INTO actual FROM public.season_state WHERE id=1 FOR SHARE;
 IF actual IS DISTINCT FROM public.week_key(clock) THEN RAISE EXCEPTION 'normal rollover is incomplete';END IF;
 IF (SELECT enabled FROM office_private.race_control WHERE id=true) IS DISTINCT FROM false THEN
  RAISE EXCEPTION 'race backend must exist and remain disabled during preparation';
 END IF;
 IF EXISTS(SELECT 1 FROM cron.job WHERE jobname='idle-hands-weekly-race' AND
  (command<>'SELECT office_private.capture_race();' OR schedule<>'*/5 * * * *' OR database<>current_database() OR username<>current_user)) THEN
  RAISE EXCEPTION 'race scheduler definition drift; investigate before preparation';
 END IF;
 SELECT cron.schedule('idle-hands-weekly-race','*/5 * * * *','SELECT office_private.capture_race();') INTO j;
END $prepare_race$;
COMMIT;
