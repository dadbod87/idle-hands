-- Read-only quote optimization. Preserve the authoritative action RPCs and formulas.
DO $$ BEGIN
  IF md5(pg_get_functiondef('public.all_prices()'::regprocedure)) <> '3906803cf0c5f56e37d699234cc8ac2a'
    OR md5(pg_get_functiondef('public.deed_price(public.players,text)'::regprocedure)) <> '26f1bd76261ffc2c92806822523cf29e'
    OR md5(pg_get_functiondef('public.costume_price(public.players,double precision)'::regprocedure)) <> '98a305cc3e5f960deb996d24662919f4'
    OR md5(pg_get_functiondef('public.steal_cap(public.players)'::regprocedure)) <> '248435a6d2e70da9f48da522a5d8d97f'
  THEN RAISE EXCEPTION 'pricing functions drifted; review before applying'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.all_prices()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; out jsonb := '{}'::jsonb; k text; d jsonb; c jsonb; eff double precision; secs double precision;
begin
  select * into p from players where id = auth.uid();
  if p.id is null then return '{}'::jsonb; end if;
  -- The same player, catalog and transaction timestamp apply to every quote.
  -- Previously each deed, costume and steal_cap repeated both calculations.
  eff := calc_rate(p) * live_mult(p);
  for k, d in select e.key,e.value from catalog cat, jsonb_each(cat.data) e where cat.key = 'deeds' loop
    secs := 1500 * (d ->> 'cost')::double precision;
    out := out || jsonb_build_object('deed_' || k,
      greatest(60, eff * secs) * case when p.dept = 'contracts' then 0.7 else 1 end);
  end loop;
  for c in select value from catalog, jsonb_array_elements(data) v(value) where key = 'costumes' loop
    out := out || jsonb_build_object('cos_' || (c ->> 'id'),
      greatest(120, eff * 2400 * (c ->> 'cost')::double precision));
  end loop;
  return out || jsonb_build_object(
    'nickname',  greatest(100,  eff * 300),
    'vending',   greatest(60,   eff * 45),
    'pineapple', greatest(200,  eff * 900),
    'change',    greatest(200,  eff * 600),
    'meeting',   greatest(500,  eff * 1200),
    'raise',     greatest(1000, eff * 3600),
    'steal_cap', greatest(500,  eff * 1800));
end $function$;
NOTIFY pgrst,'reload schema';
