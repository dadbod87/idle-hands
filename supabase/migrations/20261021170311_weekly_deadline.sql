-- Read-only scoring deadline from the existing server week boundary and office zone.
-- Calendar arithmetic intentionally happens in office time, so DST weeks are correct.
CREATE OR REPLACE FUNCTION public.weekly_schedule()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $schedule$
DECLARE v_tz text; v_start timestamptz; v_end timestamptz;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 SELECT coalesce(tz,'UTC') INTO v_tz FROM public.office_door WHERE id=1;
 IF v_tz IS NULL THEN RAISE EXCEPTION 'office timezone unavailable'; END IF;
 v_start := public.week_started();
 v_end := ((v_start AT TIME ZONE v_tz) + interval '7 days') AT TIME ZONE v_tz;
 RETURN jsonb_build_object('server_now',now(),'starts_at',v_start,'ends_at',v_end,'timezone',v_tz);
END
$schedule$;
REVOKE ALL ON FUNCTION public.weekly_schedule() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_schedule() TO authenticated;
