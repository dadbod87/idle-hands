-- Forward-only Margarita Friday pacing correction. No player/reset/reward changes.
-- Existing completed and in-progress weekly targets are preserved. Normal rollover computes the next target.
DO $guard$
DECLARE actual text;
BEGIN
 SELECT md5(prosrc) INTO actual FROM pg_proc WHERE oid='public.set_week_target()'::regprocedure;
 IF actual NOT IN ('093dc5319e3b44970a7a661f15fbce1d','221a7c09fd640600524e4de41c813cad') THEN
  RAISE EXCEPTION 'set_week_target source differs from the reviewed version';
 END IF;
END $guard$;
CREATE OR REPLACE FUNCTION public.set_week_target() RETURNS double precision
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
-- Margarita target policy v2: preserve a frozen week, scale future goals to real completed production.
DECLARE
 v_week text:=public.week_key(); v_existing double precision; v_target_week text; v_current text;
 v_goal jsonb; v_heads integer; v_prev double precision; v_rate double precision;
 v_base double precision; v_cap double precision; v_target double precision;
BEGIN
 SELECT target,target_week,current_week INTO v_existing,v_target_week,v_current
 FROM public.season_state WHERE id=1 FOR UPDATE;
 IF NOT FOUND OR v_current IS DISTINCT FROM v_week THEN
  RAISE EXCEPTION 'ordinary weekly rollover required before setting its target';
 END IF;
 IF v_target_week=v_week AND v_existing IS NOT NULL THEN RETURN v_existing; END IF;
 SELECT data INTO v_goal FROM public.catalog WHERE key='office_goal';
 IF v_goal IS NULL THEN RAISE EXCEPTION 'office goal configuration unavailable'; END IF;
 SELECT count(*),coalesce(sum(public.calc_rate(p)*public.live_mult(p)),0)
 INTO v_heads,v_rate FROM public.players p;
 SELECT (stats->>'office_total')::double precision INTO v_prev
 FROM public.seasons
 WHERE stats @> '{"seasoned":true}'::jsonb AND week_key<v_week
   AND jsonb_typeof(stats->'office_total')='number'
 ORDER BY week_key DESC LIMIT 1;
 v_base:=greatest((v_goal->>'floor')::double precision,
                  v_heads*(v_goal->>'per_player')::double precision,
                  coalesce(v_prev*greatest(1.5,coalesce((v_goal->>'vs_last_week')::double precision,1.5)),0));
 -- The production-estimate cap follows the benchmark, rather than an obsolete fixed floor.
 v_cap:=v_base*greatest(1,coalesce((v_goal->>'max_jump')::double precision,6));
 v_target:=greatest(v_base,least(v_rate*4*86400,v_cap));
 IF v_target<=0 OR v_target IN ('Infinity'::double precision,'NaN'::double precision) THEN
  RAISE EXCEPTION 'office target is not a finite positive amount';
 END IF;
 UPDATE public.season_state SET target=v_target,target_week=v_week WHERE id=1;
 RETURN v_target;
END
$function$;
UPDATE public.catalog SET data=data||jsonb_build_object(
 'vs_last_week',1.5,
 'target_policy_version',2,
 'target_policy','Future weekly goals use at least 150% of the previous completed season, without the old fixed ceiling. Already-set targets and earned rewards stay unchanged.')
WHERE key='office_goal';

