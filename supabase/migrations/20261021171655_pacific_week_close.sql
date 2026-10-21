-- Weekly scoring uses Friday 16:00 Pacific, independently of office work-hour bonuses.
-- Refuse an installation that would immediately advance/rewind the active season.
DO $guard$
DECLARE loc timestamp := now() AT TIME ZONE 'America/Los_Angeles'; monday timestamp; expected text; active text;
BEGIN
 monday:=date_trunc('week',loc);
 expected:=to_char(monday + CASE WHEN loc >= monday + interval '4 days 16 hours' THEN interval '7 days' ELSE interval '0 days' END,'IYYY-IW');
 SELECT current_week INTO active FROM public.season_state WHERE id=1;
 IF active IS DISTINCT FROM expected THEN RAISE EXCEPTION 'Active scoring week mismatch; preserve progress and review transition before installing'; END IF;
END $guard$;

CREATE OR REPLACE FUNCTION public.week_key(ts timestamptz DEFAULT now())
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $key$
DECLARE loc timestamp; monday timestamp;
BEGIN
 loc:=ts AT TIME ZONE 'America/Los_Angeles'; monday:=date_trunc('week',loc);
 IF loc >= monday + interval '4 days 16 hours' THEN RETURN to_char(monday+interval '7 days','IYYY-IW'); END IF;
 RETURN to_char(monday,'IYYY-IW');
END $key$;

CREATE OR REPLACE FUNCTION public.week_started(ts timestamptz DEFAULT now())
RETURNS timestamptz LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $start$
DECLARE loc timestamp; cutoff timestamp;
BEGIN
 loc:=ts AT TIME ZONE 'America/Los_Angeles';
 cutoff:=date_trunc('week',loc)+interval '4 days 16 hours';
 IF loc<cutoff THEN cutoff:=cutoff-interval '7 days'; END IF;
 RETURN cutoff AT TIME ZONE 'America/Los_Angeles';
END $start$;

CREATE OR REPLACE FUNCTION public.weekly_schedule()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $schedule$
DECLARE v_tz constant text := 'America/Los_Angeles'; v_start timestamptz; v_end timestamptz;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 v_start:=public.week_started();
 v_end:=((v_start AT TIME ZONE v_tz)+interval '7 days') AT TIME ZONE v_tz;
 RETURN jsonb_build_object('server_now',now(),'starts_at',v_start,'ends_at',v_end,'timezone',v_tz);
END $schedule$;
REVOKE ALL ON FUNCTION public.weekly_schedule() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_schedule() TO authenticated;
-- No roll_week(), season wipe, timezone configuration or player-row updates here.
