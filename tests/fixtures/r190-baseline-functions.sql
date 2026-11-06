-- Actual function snapshots for disposable regression tests only.
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
CREATE OR REPLACE FUNCTION public.office_state()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'total',  (select coalesce(sum(week_pp), 0) from players),
    'target', office_target(),
    'hit',    (select mhit from season_state where id = 1),
    'streak', (select streak from season_state where id = 1),
    'best',   (select best from season_state where id = 1),
    'goal',   (select data from catalog where key = 'office_goal'),
    'tiers',  fund_tier(),
    'tz',     (select tz from office_door where id = 1),
    'printer', jsonb_build_object(
        'window', printer_window(),
        'by', (select name from printer_claims where window_id = printer_window()),
        'mine', (select fixer = auth.uid() from printer_claims
                 where window_id = printer_window())),
    'chair', jsonb_build_object(
        'window', chair_window(),
        'by', (select name from chair_claims where window_id = chair_window()),
        'mine', (select taker = auth.uid() from chair_claims
                 where window_id = chair_window())),
    'meeting', jsonb_build_object(
        'window', meeting_window(),
        'who', coalesce((select jsonb_agg(name order by joined_at)
                         from meeting_claims where window_id = meeting_window()), '[]'::jsonb),
        'mine', coalesce((select true from meeting_claims
                          where window_id = meeting_window() and attendee = auth.uid()), false),
        'last', (select jsonb_build_object(
                    'window', mc.window_id,
                    'who', (select jsonb_agg(name order by joined_at)
                            from meeting_claims where window_id = mc.window_id))
                 from meeting_claims mc
                 where mc.attendee = auth.uid() and mc.paid
                 order by mc.window_id desc limit 1)))
$function$
;
CREATE OR REPLACE FUNCTION public.use_vending()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; price double precision; roll jsonb; e jsonb;
        total int; r int; acc int := 0; amt double precision;
begin
  p := accrue(auth.uid());
  if p.last_vend is not null and now() - p.last_vend < interval '10 minutes'
    then raise exception 'cooling off'; end if;
  price := greatest(60, calc_rate(p) * live_mult(p) * 45);
  if p.pp < price then raise exception 'cannot afford'; end if;

  select data into roll from catalog where key = 'vend_prizes';
  select sum((x ->> 'w')::int) into total from jsonb_array_elements(roll) x;
  r := floor(random() * total) + 1;
  for e in select * from jsonb_array_elements(roll) loop
    acc := acc + (e ->> 'w')::int;
    exit when acc >= r;
  end loop;

  update players set pp = pp - price, last_vend = now() where id = p.id;
  if e ->> 'kind' = 'pp' then
    amt := greatest((e ->> 'amount')::double precision, price * (e ->> 'amount')::double precision / 100);
    update players set pp = pp + amt, lifetime = lifetime + amt, cycle = cycle + amt,
      week_pp = week_pp + amt, day_pp = day_pp + amt where id = p.id;
  elsif e ? 'mult' then
    update players set buffs = buffs || jsonb_build_object(
      'kind','vending','mult',(e ->> 'mult')::double precision,'from_name','the machine',
      'until', now() + ((e ->> 'mins') || ' minutes')::interval) where id = p.id;
  end if;
  return e;
end $function$
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
