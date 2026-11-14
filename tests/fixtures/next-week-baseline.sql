-- Read-only production function snapshot; execute only inside the isolated contract harness.
CREATE OR REPLACE FUNCTION public.roll_week()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare k text := week_key(); prev text; w players;
        wk_start timestamptz; wk_end timestamptz; st jsonb; was_hit boolean;
        do_wipe boolean; from_week text; seasoned boolean;
begin
  select current_week, mhit into prev, was_hit from season_state where id = 1 for update;
  if prev = k then return; end if;

  select coalesce((data ->> 'wipe')::boolean, false), coalesce(data ->> 'from_week', '')
    into do_wipe, from_week from catalog where key = 'season';
  seasoned := do_wipe and from_week <> '' and prev >= from_week;

  wk_end := week_started();
  wk_start := wk_end - interval '7 days';
  select * into w from players order by week_pp desc limit 1;

  with d as (
    select dd.*, pa.name as actor_name, pt.name as target_name
    from deeds dd join players pa on pa.id = dd.actor join players pt on pt.id = dd.target
    where dd.created_at >= wk_start and dd.created_at < wk_end)
  select jsonb_build_object(
    'total', (select count(*) from d),
    'heist', (select jsonb_build_object('actor',actor_name,'target',target_name,'amount',amount)
              from d where kind='credit' order by amount desc limit 1),
    'stylist', (select jsonb_build_object('name',actor_name,'n',count(*)) from d where kind='dress'
                group by actor_name order by count(*) desc limit 1),
    'kindest', (select jsonb_build_object('name',actor_name,'n',count(*)) from d
                where kind in ('coffee','hype','cover') group by actor_name order by count(*) desc limit 1),
    'menace', (select jsonb_build_object('name',actor_name,'n',count(*)) from d
               where kind not in ('coffee','hype','cover') group by actor_name order by count(*) desc limit 1),
    'feud', (select jsonb_build_object('a',least(actor_name,target_name),
                                       'b',greatest(actor_name,target_name),'n',count(*))
             from d where kind not in ('coffee','hype','cover')
             group by least(actor_name,target_name), greatest(actor_name,target_name)
             order by count(*) desc limit 1),
    'hushed', (select count(*) from d where hush),
    'punchbag', (select jsonb_build_object('name',target_name,'n',count(*)) from d
                 where kind not in ('coffee','hype','cover') group by target_name
                 order by count(*) desc limit 1),
    'margarita', coalesce(was_hit, false),
    'office_total', (select coalesce(sum(week_pp),0) from players),
    'seasoned', seasoned
  ) into st;

  if w.id is not null and w.week_pp > 0 then
    insert into seasons (week_key, winner, winner_name, top, stats)
      values (prev, w.id, w.name, w.week_pp, st)
      on conflict (week_key) do update set stats = excluded.stats;
    update players set trophies = trophies + 1 where id = w.id;
  else
    insert into seasons (week_key, winner_name, top, stats) values (prev, null, 0, st)
      on conflict (week_key) do update set stats = excluded.stats;
  end if;

  if not coalesce(was_hit, false) then
    update season_state set streak = 0 where id = 1;
  end if;

  if do_wipe then perform season_wipe();
  else update players set week_pp = 0 where week_pp <> 0; end if;

  update season_state set current_week = k, mw = k, mhit = false where id = 1;
  perform set_week_target();
end $function$
;
CREATE OR REPLACE FUNCTION public.accrue(p_id uuid)
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; secs double precision; cap_h double precision; gain double precision;
        need_check boolean; need_roll boolean; need_settle boolean;
begin
  if p_id is null then raise exception 'not signed in'; end if;

  select (current_week is distinct from week_key()) into need_roll
    from season_state where id = 1;
  if coalesce(need_roll, false) then perform roll_week(); end if;

  select (not mhit) or (mw is distinct from week_key()) into need_check
    from season_state where id = 1;
  if coalesce(need_check, true) then perform check_margarita(); end if;

  select exists (select 1 from meeting_claims where not paid) into need_settle;
  if need_settle then perform settle_meetings(); end if;

  select * into p from players where id = p_id for update;
  if p.id is null then raise exception 'no player'; end if;

  cap_h := 8 + 4 * perk_of(p, 'deep_pockets');     -- was 'pockets': no such perk id
  if p.dept = 'property' then
    cap_h := greatest(cap_h, 12 + 4 * perk_of(p, 'deep_pockets'));
  end if;

  secs := extract(epoch from (now() - coalesce(p.last_tick, now())));
  if secs > 0 then
    -- Integrate earnings in bounded time slices, using the multiplier at each slice.
    -- Timestamp-sensitive server functions use now(), so evaluate time-specific
    -- windows separately rather than applying the current Jess bonus to all absence.
    gain := public.accrual_interval_gain(p, now()-make_interval(secs => least(secs,cap_h*3600)), now());
    update players set pp = pp + gain, lifetime = lifetime + gain, cycle = cycle + gain,
      week_pp = week_pp + gain, day_pp = day_pp + gain,
      last_tick = now(), last_seen = now()
    where id = p_id returning * into p;
  else
    update players set last_seen = now() where id = p_id returning * into p;
  end if;
  return p;
end $function$
;
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
end $function$
;
CREATE OR REPLACE FUNCTION public.apply_style(p_quote uuid)
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE p public.players; q public.style_quotes; r double precision; total double precision; unit double precision; saved_style jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 -- Follow the game's existing accrual/weekly lock order, then serialize on the player.
 p:=public.accrue(auth.uid());
 SELECT * INTO p FROM public.players WHERE id=auth.uid() FOR UPDATE;
 SELECT * INTO q FROM public.style_quotes WHERE player_id=p.id AND id=p_quote FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'quote replaced; review a fresh quote'; END IF;
 IF q.applied THEN RETURN p; END IF; -- Same accepted request is safe to retry.
 IF q.expires_at<=now() OR q.week<>public.week_key() OR q.revision<>p.cosmetic_revision THEN RAISE EXCEPTION 'quote expired; review a fresh quote'; END IF;
 PERFORM public.style_item_info(p,q.item);
 r:=public.calc_rate(p)*public.live_mult(p);
 IF r::text IN ('NaN','Infinity','-Infinity') OR abs(r-q.rate)>greatest(0.000000001,abs(q.rate)*0.000000001) THEN RAISE EXCEPTION 'output changed; review a fresh quote'; END IF;
 -- Reject even a late/in-flight quote produced by the former pricing function.
 unit:=greatest(1000,ceil(r*28800));
 saved_style:=coalesce(p.cosmetic_styles->q.item,'{"color":null,"design":"solid"}'::jsonb);
 IF q.color_fee IS DISTINCT FROM (CASE WHEN (saved_style->>'color') IS DISTINCT FROM q.color THEN unit ELSE 0 END)
 OR q.design_fee IS DISTINCT FROM (CASE WHEN coalesce(saved_style->>'design','solid')<>q.design AND q.design<>'solid' THEN unit ELSE 0 END)
 THEN RAISE EXCEPTION 'pricing changed; review a fresh quote'; END IF;
 total:=q.color_fee+q.design_fee;
 IF p.pp<total THEN RAISE EXCEPTION 'not enough Busywork for this style'; END IF;
 UPDATE public.players SET pp=pp-total,spent=coalesce(spent,0)+total,
 cosmetic_styles=cosmetic_styles||jsonb_build_object(q.item,jsonb_build_object('color',q.color,'design',q.design)),
 cosmetic_revision=cosmetic_revision+1 WHERE id=p.id RETURNING * INTO p;
 UPDATE public.style_quotes SET applied=true WHERE player_id=p.id AND id=q.id;
 RETURN p;
END $function$
;
CREATE OR REPLACE FUNCTION public.ask_raise()
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; price double precision;
begin
  p := accrue(auth.uid());
  if p.heat > 0 then raise exception 'clear your file first'; end if;
  if p.goodwill < 3 then raise exception 'not enough goodwill'; end if;
  if p.raises >= 10 then raise exception 'dave is out of yeses'; end if;
  price := greatest(1000, calc_rate(p) * live_mult(p) * 3600);  -- an hour of your work
  if p.pp < price then raise exception 'cannot afford'; end if;
  update players set pp = pp - price, raises = raises + 1 where id = p.id returning * into p;
  return p;
end $function$
;
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
CREATE OR REPLACE FUNCTION public.buy_item(p_item text)
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; it jsonb; have int; price double precision;
begin
  p := accrue(auth.uid());
  select e into it from catalog c, jsonb_array_elements(c.data) e
    where c.key = 'items' and e ->> 'id' = p_item;
  if it is null then raise exception 'no such item'; end if;
  have  := coalesce((p.owned ->> p_item)::int, 0);
  price := ceil((it ->> 'cost')::double precision * power(item_growth(), have)
                * case when p.dept = 'resale' then 0.9 else 1 end);
  if p.pp < price then raise exception 'cannot afford'; end if;
  update players set pp = pp - price,
    owned = jsonb_set(owned, array[p_item], to_jsonb(have + 1), true)
  where id = p.id returning * into p;
  perform bump_today(p.id, 'hires', 1);
  return p;
end $function$
;
CREATE OR REPLACE FUNCTION public.buy_perk(p_id text)
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_variable
declare v_p players; v_k jsonb; v_have int; v_perks jsonb;
begin
  v_p := accrue(auth.uid());
  select e into v_k from catalog c, jsonb_array_elements(c.data) e
    where c.key = 'perks' and e ->> 'id' = p_id;
  if v_k is null then raise exception 'no such perk'; end if;

  v_perks := case when jsonb_typeof(v_p.perks) = 'object' then v_p.perks else '{}'::jsonb end;
  v_have := coalesce((v_perks ->> p_id)::int, 0);

  if v_have >= (v_k ->> 'max')::int then raise exception 'you already have all of those'; end if;
  if v_p.equity < (v_k ->> 'cost')::int then raise exception 'not enough equity'; end if;

  update players set
    equity = equity - (v_k ->> 'cost')::int,
    perks  = jsonb_set(v_perks, array[p_id], to_jsonb(v_have + 1), true)
  where id = v_p.id returning * into v_p;
  return v_p;
end $function$
;
CREATE OR REPLACE FUNCTION public.buy_pin(p_id text)
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; it jsonb; price double precision;
begin
  p := accrue(auth.uid());
  select value into it from jsonb_array_elements(weekly_pins() -> 'list') v(value)
   where value ->> 'id' = p_id;
  if it is null then raise exception 'not stocked this week'; end if;
  if p.extras ? p_id then raise exception 'already have that'; end if;
  price := greatest(1000, calc_rate(p) * live_mult(p) * (it ->> 'secs')::double precision);
  if p.pp < price then raise exception 'cannot afford'; end if;
  update players set pp = pp - price, spent = spent + price,
    extras = extras || to_jsonb(p_id), pin = p_id
  where id = p.id returning * into p;
  return p;
end $function$
;
CREATE OR REPLACE FUNCTION public.check_in()
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; door office_door; v_day date; v_bonus double precision := 0;
        v_picks jsonb; v_roll jsonb; v_total int; v_r int; v_acc int := 0; v_prize jsonb;
begin
  select * into door from office_door where id = 1;
  v_day := (now() at time zone door.tz)::date;
  p := accrue(auth.uid());
  if p.last_checkin is not null and p.last_checkin >= v_day then return p; end if;

  select jsonb_agg(q.item) into v_picks from (
    select item from catalog c, jsonb_array_elements(c.data) as item
    where c.key = 'contracts' order by random() limit 3) q;

  select data into v_roll from catalog where key = 'mail';
  select sum((x ->> 'w')::int) into v_total from jsonb_array_elements(v_roll) x;
  v_r := floor(random() * v_total) + 1;
  for v_prize in select * from jsonb_array_elements(v_roll) loop
    v_acc := v_acc + (v_prize ->> 'w')::int;
    exit when v_acc >= v_r;
  end loop;

  update players set
    streak = case when p.last_checkin is not null and p.last_checkin >= v_day - 3
                  then p.streak + 1 else 1 end,
    last_checkin = v_day,
    today = '{}'::jsonb,
    day_pp = 0,
    contracts = jsonb_build_object('day', v_day::text, 'list', v_picks, 'claimed', '[]'::jsonb),
    mail = jsonb_build_object('day', v_day::text, 'item', v_prize, 'opened', false)
  where id = p.id returning * into p;

  v_bonus := greatest(250, calc_rate(p) * live_mult(p) * 60 * least(p.streak, 10));
  update players set pp = pp + v_bonus, lifetime = lifetime + v_bonus,
    cycle = cycle + v_bonus, week_pp = week_pp + v_bonus
  where id = p.id returning * into p;
  return p;
end $function$
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
CREATE OR REPLACE FUNCTION public.do_deed(p_target uuid, p_kind text)
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; t players; d jsonb; price double precision; amt double precision := 0;
        soften double precision; eff double precision; cd interval;
begin
  p := accrue(auth.uid());
  if p_target = p.id then raise exception 'not to yourself'; end if;
  cd := (interval '5 minutes') - (perk_of(p, 'silver_tongue') * interval '1 minute');
  if p.last_deed is not null and now() - p.last_deed < cd then raise exception 'cooling off'; end if;
  select (data -> p_kind) into d from catalog where key = 'deeds';
  if d is null then raise exception 'no such deed'; end if;
  t := accrue(p_target);
  if t is null then raise exception 'no such player'; end if;
  price := deed_price(p, p_kind);
  if p.pp < price then raise exception 'cannot afford'; end if;

  soften := case when t.dept = 'systems' then 0.6 else 1 end
            * (1 - 0.25 * perk_of(t, 'thick_skin'));
  if soften < 0.2 then soften := 0.2; end if;

  if d ? 'transfer' then amt := price * (d ->> 'transfer')::double precision; end if;
  if d ? 'steal' then
    amt := least(greatest(20, t.pp * (d ->> 'steal')::double precision * soften), steal_cap(p));
    update players set pp = greatest(0, pp - amt) where id = t.id;
    update players set pp = pp + amt where id = p.id;
  end if;
  if d ? 'transfer' then update players set pp = pp + amt where id = t.id; end if;
  if d ? 'mult' then
    eff := (d ->> 'mult')::double precision;
    if eff < 1 then eff := 1 - (1 - eff) * soften; end if;
    update players set buffs = buffs || jsonb_build_object(
      'kind', p_kind, 'mult', eff, 'from_name', p.name,
      'until', now() + ((d ->> 'mins') || ' minutes')::interval)
    where id = t.id;
  end if;
  if d ? 'heat_to' then update players set heat = heat + (d ->> 'heat_to')::int where id = t.id; end if;
  if (d ->> 'good')::boolean then
    update players set kind_received = kind_received + 1 where id = t.id;
  end if;

  insert into deeds (actor, target, kind, amount) values (p.id, p_target, p_kind, amt);

  update players set
    pp = pp - price, last_deed = now(),
    goodwill  = goodwill  + case when (d ->> 'good')::boolean then 1 else 0 end,
    notoriety = notoriety + case when (d ->> 'good')::boolean then 0 else 1 end,
    heat = case when p_kind = 'blame' then 0
                when (d ->> 'good')::boolean then heat else heat + 1 end,
    busted = case when p_kind <> 'blame' and not (d ->> 'good')::boolean
                    and heat + 1 = 5 then busted + 1 else busted end,
    tally = jsonb_set(tally, array[p_kind],
              to_jsonb(coalesce((tally ->> p_kind)::int, 0) + 1), true)
  where id = p.id returning * into p;

  perform bump_today(p.id, case when (d ->> 'good')::boolean then 'kind' else 'mean' end, 1);
  if not (d ->> 'good')::boolean then
    perform check_rivalry(p.id, p_target);
    select * into p from players where id = p.id;
  end if;
  return p;
end $function$
;
CREATE OR REPLACE FUNCTION public.do_work(p_clicks integer)
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; n int; r double precision; cm double precision := 1;
        u jsonb; upg jsonb; gain double precision;
begin
  p := accrue(auth.uid());
  n := least(greatest(coalesce(p_clicks, 0), 0), 60);
  if n = 0 then return p; end if;
  if p.last_work is not null and now() - p.last_work < interval '1 second' then return p; end if;
  select data into upg from catalog where key = 'upgrades';
  for u in select * from jsonb_array_elements(upg) loop
    if p.upgrades ? (u ->> 'id') and u ->> 't' = 'click'
      then cm := cm * (u ->> 'mult')::double precision; end if;
  end loop;
  if p.dept = 'development' then cm := cm * 3; end if;
  r := calc_rate(p) * live_mult(p);

  -- Per click: the old term was (1 + r*0.1)*cm, which at 60 clicks/sec and a full click
  -- stack (3*3*2, x3 development = 54) paid 324 seconds of production per second of
  -- clicking. Clicking WAS the economy. Two changes:
  --   flat part unchanged  -> the opening game plays exactly as before
  --   ceiling cm + r*2/60  -> at 60 clicks/sec the rate-proportional part tops out at
  --                           2 seconds of production per second, whatever cm becomes later
  gain := n * least((1 + r * 0.003) * cm, cm + r * 2.0 / 60);

  update players set pp = pp + gain, lifetime = lifetime + gain, cycle = cycle + gain,
    week_pp = week_pp + gain, day_pp = day_pp + gain, last_work = now()
  where id = p.id returning * into p;
  return p;
end $function$
;
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
CREATE OR REPLACE FUNCTION public.fitting_prices()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; eff double precision; out jsonb := '{}'::jsonb; it jsonb;
begin
  select * into p from players where id = auth.uid();
  if p.id is null then return jsonb_build_object('rate', 0, 'prices', '{}'::jsonb); end if;
  eff := calc_rate(p) * live_mult(p);
  for it in select value from catalog, jsonb_array_elements(data) v(value)
            where key in ('vanity', 'office_kit') loop
    out := out || jsonb_build_object(it ->> 'id',
             greatest(1000, coalesce((it ->> 'min_cost')::double precision, 0), eff * (it ->> 'secs')::double precision));
  end loop;
  return jsonb_build_object('rate', eff, 'prices', out);
end $function$
;
CREATE OR REPLACE FUNCTION public.fix_printer()
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; w bigint; bonus double precision;
begin
  w := printer_window();
  if w is null then raise exception 'printer is fine'; end if;
  if exists (select 1 from printer_claims where window_id = w) then raise exception 'already fixed'; end if;
  p := accrue(auth.uid());
  insert into printer_claims (window_id, fixer, name) values (w, p.id, p.name);
  bonus := greatest(500, calc_rate(p) * live_mult(p) * 300);
  update players set pp = pp + bonus, lifetime = lifetime + bonus,
    cycle = cycle + bonus, week_pp = week_pp + bonus, day_pp = day_pp + bonus
  where id = p.id returning * into p;
  perform bump_today(p.id, 'printer', 1);
  return p;
end $function$
;
CREATE OR REPLACE FUNCTION public.fund_tier()
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select count(*)::int from jsonb_array_elements_text(
    (select data from catalog where key = 'fund_tiers')) t
  where (select coalesce(sum(week_pp), 0) from players) >= t::double precision
$function$
;
CREATE OR REPLACE FUNCTION public.give_nickname(p_target uuid, p_text text)
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; t players; price double precision; nm text;
begin
  p := accrue(auth.uid());
  if p_target = p.id then raise exception 'not to yourself'; end if;
  if p.last_nick is not null and now() - p.last_nick < interval '10 minutes'
    then raise exception 'cooling off'; end if;
  nm := btrim(regexp_replace(coalesce(p_text, ''), '\s+', ' ', 'g'));
  if char_length(nm) < 2 or char_length(nm) > 18 then raise exception 'bad nickname length'; end if;
  if nm !~ '^[A-Za-z0-9 ''\-\.]+$' then raise exception 'letters and numbers only'; end if;
  if not is_clean(nm) then raise exception 'keep it office-safe'; end if;
  t := accrue(p_target);
  if t is null then raise exception 'no such player'; end if;
  price := greatest(100, calc_rate(p) * live_mult(p) * 300);
  if p.pp < price then raise exception 'cannot afford'; end if;

  update players set nickname = jsonb_build_object(
    'text', nm, 'by', p.id, 'by_name', p.name, 'until', now() + interval '60 minutes')
  where id = t.id;
  insert into deeds (actor, target, kind, detail) values (p.id, p_target, 'nickname', nm);
  update players set pp = pp - price, last_nick = now(), notoriety = notoriety + 1,
    tally = jsonb_set(tally, array['nickname'],
              to_jsonb(coalesce((tally ->> 'nickname')::int, 0) + 1), true)
  where id = p.id returning * into p;
  return p;
end $function$
;
CREATE OR REPLACE FUNCTION public.item_growth()
 RETURNS double precision
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce((data ->> 'growth')::double precision, 1.15)
  from catalog where key = 'tuning'
$function$
;
CREATE OR REPLACE FUNCTION public.join_meeting()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_variable
declare v_p players; v_w bigint; v_n int;
begin
  v_w := meeting_window();
  if v_w is null then raise exception 'there is no meeting right now'; end if;
  v_p := accrue(auth.uid());
  insert into meeting_claims (window_id, attendee, name)
    values (v_w, v_p.id, v_p.name)
    on conflict (window_id, attendee) do nothing;
  select count(*) into v_n from meeting_claims where window_id = v_w;
  return jsonb_build_object('window', v_w, 'attendees', v_n);
end $function$
;
CREATE OR REPLACE FUNCTION public.live_mult(p players)
 RETURNS double precision
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare m double precision; b jsonb; st text; door office_door; h int; dow int; sk int;
begin
  m := 1 + p.equity * 0.03 + least(p.goodwill, 30) * 0.01 + p.raises * 0.02;
  m := m * (1 + 0.05 * perk_of(p, 'compound'));
  if p.dept = 'finance' then m := m * 1.12; end if;
  if p.heat >= 5 then m := m * 0.75; end if;
  for b in select * from jsonb_array_elements(p.buffs) loop
    st := b ->> 'start';
    if st is null and (b ->> 'from') ~ '^\d{4}-\d{2}-\d{2}' then st := b ->> 'from'; end if;
    if (b ->> 'until') ~ '^\d{4}-\d{2}-\d{2}'
       and (b ->> 'until')::timestamptz > now()
       and (st is null or st::timestamptz <= now()) then
      m := m * coalesce((b ->> 'mult')::double precision, 1);
    end if;
  end loop;
  if p.frenzy_until is not null and p.frenzy_until > now() then m := m * 7; end if;
  m := m * (1 + 0.03 * fund_tier());
  select streak into sk from season_state where id = 1;
  m := m * (1 + 0.02 * least(coalesce(sk, 0), 10));
  select * into door from office_door where id = 1;
  h := extract(hour from (now() at time zone door.tz));
  dow := extract(isodow from (now() at time zone door.tz));
  if h >= 18 or h < 7 or dow > 5 then m := m * 1.15; end if;
  return m * event_mult(now()) * public.jess_boost_mult(now());
end $function$
;
CREATE OR REPLACE FUNCTION public.live_mult_at(p players, ts timestamp with time zone)
 RETURNS double precision
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare m double precision; b jsonb; st text; door office_door; h int; dow int; sk int;
begin
  m := 1 + p.equity * 0.03 + least(p.goodwill, 30) * 0.01 + p.raises * 0.02;
  m := m * (1 + 0.05 * perk_of(p, 'compound'));
  if p.dept = 'finance' then m := m * 1.12; end if;
  if p.heat >= 5 then m := m * 0.75; end if;
  for b in select * from jsonb_array_elements(p.buffs) loop
    st := b ->> 'start';
    if st is null and (b ->> 'from') ~ '^\d{4}-\d{2}-\d{2}' then st := b ->> 'from'; end if;
    if (b ->> 'until') ~ '^\d{4}-\d{2}-\d{2}'
       and (b ->> 'until')::timestamptz > ts
       and (st is null or st::timestamptz <= ts) then
      m := m * coalesce((b ->> 'mult')::double precision, 1);
    end if;
  end loop;
  if p.frenzy_until is not null and ts >= p.frenzy_until - interval '77 seconds' and ts < p.frenzy_until then m := m * 7; end if;
  m := m * (1 + 0.03 * fund_tier());
  select streak into sk from season_state where id = 1;
  m := m * (1 + 0.02 * least(coalesce(sk, 0), 10));
  select * into door from office_door where id = 1;
  h := extract(hour from (ts at time zone door.tz));
  dow := extract(isodow from (ts at time zone door.tz));
  if h >= 18 or h < 7 or dow > 5 then m := m * 1.15; end if;
  return m * event_mult(ts) * public.jess_boost_mult(ts);
end $function$
;
CREATE OR REPLACE FUNCTION public.office_perform(p_kind text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE uid uuid:=auth.uid(); wk text:=public.week_key(); d date:=(now() AT TIME ZONE 'America/Los_Angeles')::date;
BEGIN
 IF uid IS NULL OR NOT EXISTS(SELECT 1 FROM public.players WHERE id=uid AND signed_at IS NOT NULL) THEN RAISE EXCEPTION 'badge in first'; END IF;
 IF p_kind IS NULL OR p_kind NOT IN ('plant','bench','apology','calendar','shelf','notice','lounge','printer') THEN RAISE EXCEPTION 'unrecognized office activity'; END IF;
 -- Unique actor/day/kind and atomic update prevent retries/concurrency from farming the story.
 -- Repeats still perform locally; the shared story counts at most six per kind/day and one per 15 seconds.
 INSERT INTO public.office_play_actions(week,actor,day,kind) VALUES(wk,uid,d,p_kind)
 ON CONFLICT(week,actor,day,kind) DO UPDATE SET n=public.office_play_actions.n+1,updated_at=now()
 WHERE public.office_play_actions.n<6 AND public.office_play_actions.updated_at<=now()-interval '15 seconds';
 RETURN public.office_play_state();
END;
$function$
;
CREATE OR REPLACE FUNCTION public.perk_of(p players, k text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case when jsonb_typeof(p.perks) = 'object'
              then coalesce((p.perks ->> k)::int, 0) else 0 end
$function$
;
CREATE OR REPLACE FUNCTION public.quote_style(p_item text, p_color text, p_design text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE p public.players; old jsonb; q public.style_quotes; unit double precision; r double precision; cf double precision; df double precision;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 IF p_color IS NOT NULL AND p_color !~ '^#[0-9a-fA-F]{6}$' THEN RAISE EXCEPTION 'invalid color'; END IF;
 IF p_design IS NULL OR p_design NOT IN ('solid','stripe','check','dots','sparkle','confetti') THEN RAISE EXCEPTION 'invalid design'; END IF;
 SELECT * INTO p FROM public.players WHERE id=auth.uid() FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'no employee'; END IF;
 PERFORM public.style_item_info(p,p_item);
 old:=coalesce(p.cosmetic_styles->p_item,'{"color":null,"design":"solid"}'::jsonb);
 r:=public.calc_rate(p)*public.live_mult(p);
 IF r::text IN ('NaN','Infinity','-Infinity') OR r<0 THEN RAISE EXCEPTION 'output unavailable'; END IF;
 unit:=greatest(1000,ceil(r*28800));
 cf:=CASE WHEN (old->>'color') IS DISTINCT FROM lower(p_color) THEN unit ELSE 0 END;
 -- Removing a pattern is free; adding/changing one is a separate eight hours of output.
 df:=CASE WHEN coalesce(old->>'design','solid')<>p_design AND p_design<>'solid' THEN unit ELSE 0 END;
 INSERT INTO public.style_quotes(player_id,item,color,design,color_fee,design_fee,rate,revision,week,expires_at)
 VALUES(p.id,p_item,lower(p_color),p_design,cf,df,r,p.cosmetic_revision,public.week_key(),now()+interval '2 minutes')
 ON CONFLICT(player_id) DO UPDATE SET id=gen_random_uuid(),item=excluded.item,color=excluded.color,design=excluded.design,
 color_fee=excluded.color_fee,design_fee=excluded.design_fee,rate=excluded.rate,revision=excluded.revision,week=excluded.week,expires_at=excluded.expires_at,applied=false
 RETURNING * INTO q;
 RETURN jsonb_build_object('id',q.id,'item',q.item,'color',q.color,'design',q.design,'color_fee',cf,'design_fee',df,'total',cf+df,'rate',r,'seconds_per_change',28800,'expires_at',q.expires_at,'balance',p.pp);
END $function$
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
CREATE OR REPLACE FUNCTION public.take_break(p_drink text)
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; d jsonb; door office_door; local_hour int;
begin
  p := accrue(auth.uid());
  if p.last_break is not null and now() - p.last_break < interval '20 minutes'
    then raise exception 'still caffeinated'; end if;
  select e into d from catalog c, jsonb_array_elements(c.data) e
    where c.key = 'drinks' and e ->> 'id' = p_drink;
  if d is null then raise exception 'no such drink'; end if;
  if d ? 'after_hour' then
    select * into door from office_door where id = 1;
    local_hour := extract(hour from (now() at time zone door.tz));
    if local_hour < (d ->> 'after_hour')::int then raise exception 'too early'; end if;
  end if;
  if coalesce((d ->> 'clears')::boolean, false) then
    update players set last_break = now(),
      buffs = coalesce((select jsonb_agg(b) from jsonb_array_elements(p.buffs) b
                        where (b ->> 'mult')::double precision >= 1
                          and (b ->> 'until')::timestamptz > now()), '[]'::jsonb)
    where id = p.id returning * into p;
    perform bump_today(p.id, 'drink', 1);
    return p;
  end if;
  update players set last_break = now(),
    buffs = buffs || jsonb_build_object('kind', p_drink,
      'mult', (d ->> 'mult')::double precision, 'from_name', d ->> 'name',
      'until', now() + ((d ->> 'mins') || ' minutes')::interval)
  where id = p.id returning * into p;
  if d ? 'crash' then
    update players set buffs = buffs || jsonb_build_object(
      'kind','crash','mult',(d ->> 'crash')::double precision,'from_name','the beer',
      'start',(now() + ((d ->> 'mins') || ' minutes')::interval)::text,
      'until', now() + ((d ->> 'mins')::int + (d ->> 'crash_mins')::int || ' minutes')::interval)
    where id = p.id returning * into p;
  end if;
  perform bump_today(p.id, 'drink', 1);
  return p;
end $function$
;
CREATE OR REPLACE FUNCTION public.week_key(ts timestamp with time zone DEFAULT now())
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE loc timestamp; monday timestamp;
BEGIN
 loc:=ts AT TIME ZONE 'America/Los_Angeles'; monday:=date_trunc('week',loc);
 IF loc >= monday + interval '4 days 16 hours' THEN RETURN to_char(monday+interval '7 days','IYYY-IW'); END IF;
 RETURN to_char(monday,'IYYY-IW');
END $function$
;
CREATE OR REPLACE FUNCTION public.week_started(ts timestamp with time zone DEFAULT now())
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE loc timestamp; cutoff timestamp;
BEGIN
 loc:=ts AT TIME ZONE 'America/Los_Angeles';
 cutoff:=date_trunc('week',loc)+interval '4 days 16 hours';
 IF loc<cutoff THEN cutoff:=cutoff-interval '7 days'; END IF;
 RETURN cutoff AT TIME ZONE 'America/Los_Angeles';
END $function$
;

CREATE OR REPLACE FUNCTION public.calc_rate(p players)
 RETURNS double precision
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare items jsonb; upg jsonb; it jsonb; u jsonb;
        r double precision := 0; cnt int; m double precision;
begin
  select data into items from catalog where key = 'items';
  select data into upg   from catalog where key = 'upgrades';
  for it in select * from jsonb_array_elements(items) loop
    cnt := coalesce((p.owned ->> (it ->> 'id'))::int, 0);
    if cnt > 0 then
      m := 1;
      for u in select * from jsonb_array_elements(upg) loop
        if p.upgrades ? (u ->> 'id') then
          if u ->> 't' = 'item' and u ->> 'target' = it ->> 'id'
            then m := m * (u ->> 'mult')::double precision; end if;
          if u ->> 't' = 'all'
            then m := m * (u ->> 'mult')::double precision; end if;
        end if;
      end loop;
      r := r + cnt * (it ->> 'rate')::double precision * m;
    end if;
  end loop;
  return r;
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
