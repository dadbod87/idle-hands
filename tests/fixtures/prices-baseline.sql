CREATE OR REPLACE FUNCTION public.all_prices()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; out jsonb := '{}'::jsonb; k text; c jsonb; eff double precision;
begin
  select * into p from players where id = auth.uid();
  if p.id is null then return '{}'::jsonb; end if;
  eff := calc_rate(p) * live_mult(p);
  for k in select jsonb_object_keys(data) from catalog where key = 'deeds' loop
    out := out || jsonb_build_object('deed_' || k, deed_price(p, k));
  end loop;
  for c in select value from catalog, jsonb_array_elements(data) v(value) where key = 'costumes' loop
    out := out || jsonb_build_object('cos_' || (c ->> 'id'),
             costume_price(p, (c ->> 'cost')::double precision));
  end loop;
  return out || jsonb_build_object(
    'nickname',  greatest(100,  eff * 300),
    'vending',   greatest(60,   eff * 45),
    'pineapple', greatest(200,  eff * 900),
    'change',    greatest(200,  eff * 600),
    'meeting',   greatest(500,  eff * 1200),
    'raise',     greatest(1000, eff * 3600),
    'steal_cap', steal_cap(p));
end $function$
;

CREATE OR REPLACE FUNCTION public.costume_price(p players, p_cost double precision)
 RETURNS double precision
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select greatest(120, calc_rate(p) * live_mult(p) * 2400 * p_cost)
$function$
;

CREATE OR REPLACE FUNCTION public.deed_price(p players, p_kind text)
 RETURNS double precision
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare d jsonb; secs double precision; eff double precision;
begin
  select (data -> p_kind) into d from catalog where key = 'deeds';
  if d is null then return null; end if;
  eff := calc_rate(p) * live_mult(p);
  -- a deed costs roughly 45-180 seconds of your own work, by weight
  secs := 1500 * (d ->> 'cost')::double precision;
  return greatest(60, eff * secs) * case when p.dept = 'contracts' then 0.7 else 1 end;
end $function$
;

CREATE OR REPLACE FUNCTION public.steal_cap(p players)
 RETURNS double precision
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select greatest(500, calc_rate(p) * live_mult(p) * 1800)
$function$
;

