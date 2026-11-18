-- Audited pre-migration function definitions for disposable tests.
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
end $function$;

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
                where kind in ('coffee','hype','cover','rescue') group by actor_name order by count(*) desc limit 1),
    'menace', (select jsonb_build_object('name',actor_name,'n',count(*)) from d
               where kind not in ('coffee','hype','cover','rescue') group by actor_name order by count(*) desc limit 1),
    'feud', (select jsonb_build_object('a',least(actor_name,target_name),
                                       'b',greatest(actor_name,target_name),'n',count(*))
             from d where kind not in ('coffee','hype','cover','rescue')
             group by least(actor_name,target_name), greatest(actor_name,target_name)
             order by count(*) desc limit 1),
    'hushed', (select count(*) from d where hush),
    'punchbag', (select jsonb_build_object('name',target_name,'n',count(*)) from d
                 where kind not in ('coffee','hype','cover','rescue') group by target_name
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
end $function$;

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
  equity=0,seniority_earned=0,perks='{}'::jsonb,raises=0,frenzy_until=null,
  heat=0,busted=0,goodwill=0,notoriety=0,hush=0,quits=0,
  grabs=0,kind_received=0,rivalries=0,hits='{}'::jsonb,tally='{}'::jsonb,
  today='{}'::jsonb,contracts=null,mail=null,streak=0,last_checkin=null,
  nickname=null,outfit=null,ooo=null,office_confetti=null,
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
END $function$;

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
END $function$;
