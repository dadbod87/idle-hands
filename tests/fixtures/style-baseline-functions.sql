-- Read-only production function snapshot for isolated reset/progression tests. Never apply to Production.
CREATE OR REPLACE FUNCTION public.buy_fitting(p_key text, p_id text)
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; it jsonb; slot text; tier int; have text; have_tier int;
        col text; price double precision;
begin
  if p_key not in ('vanity', 'office_kit') then raise exception 'no such catalogue'; end if;
  p := accrue(auth.uid());
  select value into it from catalog, jsonb_array_elements(data) v(value)
   where key = p_key and value ->> 'id' = p_id;
  if it is null then raise exception 'no such thing'; end if;

  slot := it ->> 'slot'; tier := (it ->> 'tier')::int;
  col := case when p_key = 'vanity' then 'vanity' else 'kit' end;
  if col = 'vanity' then have := p.vanity ->> slot; else have := p.kit ->> slot; end if;
  if have is not null then
    select (value ->> 'tier')::int into have_tier from catalog, jsonb_array_elements(data) v(value)
     where key = p_key and value ->> 'id' = have;
  else have_tier := 0; end if;

  if tier <= have_tier then raise exception 'already have that'; end if;
  if tier > have_tier + 1 then raise exception 'buy them in order'; end if;
  price := greatest(1000, coalesce((it ->> 'min_cost')::double precision, 0), calc_rate(p) * live_mult(p) * (it ->> 'secs')::double precision);
  if p.pp < price then raise exception 'cannot afford'; end if;

  if col = 'vanity' then
    update players set pp = pp - price, spent = spent + price,
      vanity = vanity || jsonb_build_object(slot, p_id) where id = p.id returning * into p;
  else
    update players set pp = pp - price, spent = spent + price,
      kit = kit || jsonb_build_object(slot, p_id) where id = p.id returning * into p;
  end if;
  return p;
end $function$
;
CREATE OR REPLACE FUNCTION public.restructure()
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; gain int; waited interval;
begin
 p := accrue(auth.uid());
 if p.last_restructure is not null then
  waited := now()-p.last_restructure;
  if waited < interval '4 hours' then
   raise exception 'the paperwork takes % more',to_char(interval '4 hours'-waited,'HH24h MIm');
  end if;
 end if;
 gain := case when p.cycle <= 1e9 then 0 else floor(1.6*log(10::numeric,(p.cycle/1e9)::numeric))::int end;
 if gain<1 then raise exception 'not enough this cycle'; end if;
 update players set equity=equity+gain,quits=quits+1,last_restructure=now(),
 pp=0,cycle=0,owned='{}'::jsonb,upgrades='[]'::jsonb,buffs='[]'::jsonb,
 frenzy_until=null,heat=0,last_tick=now()
 where id=p.id returning * into p;
 return p;
end $function$
;
CREATE OR REPLACE FUNCTION public.season_wipe()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_variable
DECLARE v_n int;
BEGIN
 UPDATE players SET
  pp=0,cycle=0,week_pp=0,day_pp=0,
  owned='{}'::jsonb,upgrades='[]'::jsonb,buffs='[]'::jsonb,
  equity=0,perks='{}'::jsonb,raises=0,frenzy_until=null,
  heat=0,busted=0,goodwill=0,notoriety=0,hush=0,quits=0,
  grabs=0,kind_received=0,rivalries=0,hits='{}'::jsonb,tally='{}'::jsonb,
  today='{}'::jsonb,contracts=null,mail=null,streak=0,last_checkin=null,
  nickname=null,outfit=null,ooo=null,
  last_restructure=null,last_deed=null,last_nick=null,last_vend=null,
  last_break=null,last_work=null,last_tick=now()
 WHERE id IS NOT NULL;
 GET DIAGNOSTICS v_n=ROW_COUNT;
 DELETE FROM deeds WHERE id IS NOT NULL;
 DELETE FROM chair_claims WHERE window_id IS NOT NULL;
 DELETE FROM printer_claims WHERE window_id IS NOT NULL;
 DELETE FROM meeting_claims WHERE window_id IS NOT NULL;
 DELETE FROM birthday_card WHERE week_key IS NOT NULL;
 RETURN v_n;
END $function$
;
