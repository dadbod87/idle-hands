-- Preserve existing pricing, authority and self-costume exemption; align coworker cooldown with do_deed.
DO $$ BEGIN
IF md5(pg_get_functiondef('public.dress(uuid,text)'::regprocedure)) <> '002ca9e41ef31aa1a70e2cda0076c4fc' THEN RAISE EXCEPTION 'dress drifted; review before applying'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.dress(p_target uuid, p_outfit text)
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_variable
declare v_p players; v_t players; v_c jsonb; v_price double precision; v_mine boolean;
begin
  v_p := accrue(auth.uid());
  select e into v_c from catalog cat, jsonb_array_elements(cat.data) e
    where cat.key = 'costumes' and e ->> 'id' = p_outfit;
  if v_c is null then raise exception 'no such costume'; end if;

  v_mine := (p_target = v_p.id);
  if not v_mine then
    if v_p.last_deed is not null and now() - v_p.last_deed < (interval '5 minutes' - public.perk_of(v_p, 'silver_tongue') * interval '1 minute')
      then raise exception 'cooling off'; end if;
    v_t := accrue(p_target);
    if v_t is null then raise exception 'no such player'; end if;
    v_p := accrue(auth.uid());        -- re-read: accrue(target) may have moved the clock
  end if;

  -- the same function all_prices() quotes from
  v_price := costume_price(v_p, (v_c ->> 'cost')::double precision)
             * case when v_mine then 1 else 2 end
             * case when v_p.dept = 'contracts' then 0.7 else 1 end;

  if v_p.pp < v_price then
    raise exception 'that costs % and you have %', round(v_price::numeric), round(v_p.pp::numeric);
  end if;

  update players set outfit = jsonb_build_object(
      'id', p_outfit, 'by', v_p.id, 'by_name', case when v_mine then null else v_p.name end,
      'until', now() + ((v_c ->> 'mins') || ' minutes')::interval)
  where id = p_target;

  if v_mine then
    update players set pp = pp - v_price where id = v_p.id returning * into v_p;
  else
    insert into deeds (actor, target, kind, detail) values (v_p.id, p_target, 'dress', p_outfit);
    update players set pp = pp - v_price, last_deed = now(), notoriety = notoriety + 1,
      heat = heat + 1,
      busted = case when heat + 1 = 5 then busted + 1 else busted end,
      tally = jsonb_set(tally, array['dress'],
                to_jsonb(coalesce((tally ->> 'dress')::int, 0) + 1), true)
    where id = v_p.id returning * into v_p;
    perform bump_today(v_p.id, 'dress', 1);
  end if;
  return v_p;
end $function$
;
NOTIFY pgrst,'reload schema';

