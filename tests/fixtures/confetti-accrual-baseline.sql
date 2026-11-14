CREATE OR REPLACE FUNCTION public.accrual_interval_gain(p players, since_ts timestamp with time zone, until_ts timestamp with time zone)
 RETURNS double precision
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
WITH ticks AS (
  SELECT g::bigint k FROM generate_series(floor(extract(epoch from since_ts)/3600)::bigint-1,floor(extract(epoch from until_ts)/3600)::bigint+1) g
), candidates AS (
 SELECT since_ts AS t UNION ALL SELECT until_ts
 UNION ALL SELECT to_timestamp(k*3600) FROM ticks
 UNION ALL SELECT to_timestamp(k*3600 + ((k*17)%45)*60) FROM ticks WHERE k%12<8
 UNION ALL SELECT to_timestamp(k*3600 + ((k*17)%45)*60 + 240) FROM ticks WHERE k%12<8
 UNION ALL SELECT to_timestamp(k*3600+3300) FROM ticks WHERE k%2=0
 UNION ALL SELECT to_timestamp(k*3600+3540) FROM ticks WHERE k%2=0
 UNION ALL SELECT p.frenzy_until WHERE p.frenzy_until IS NOT NULL
 UNION ALL SELECT (CASE WHEN b->>'start' ~ '^\\d{4}-\\d{2}-\\d{2}' THEN b->>'start' WHEN b->>'from' ~ '^\\d{4}-\\d{2}-\\d{2}' THEN b->>'from' END)::timestamptz FROM jsonb_array_elements(coalesce(p.buffs,'[]'::jsonb)) b
 UNION ALL SELECT (b->>'until')::timestamptz FROM jsonb_array_elements(coalesce(p.buffs,'[]'::jsonb)) b WHERE b->>'until' ~ '^\\d{4}-\\d{2}-\\d{2}'
), ordered AS (
 SELECT t, lead(t) OVER (ORDER BY t) nxt FROM (SELECT DISTINCT t FROM candidates WHERE t BETWEEN since_ts AND until_ts) q
)
SELECT coalesce(sum(extract(epoch from (nxt-t))*public.live_mult_at(p,t+(nxt-t)/2)),0)*public.calc_rate(p)
FROM ordered WHERE nxt IS NOT NULL
$function$
