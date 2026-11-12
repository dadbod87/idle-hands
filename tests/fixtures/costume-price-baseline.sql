-- Read-only production pricing helper; disposable tests only.
CREATE OR REPLACE FUNCTION public.costume_price(p players, p_cost double precision)
 RETURNS double precision
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select greatest(120, calc_rate(p) * live_mult(p) * 2400 * p_cost)
$function$
;

