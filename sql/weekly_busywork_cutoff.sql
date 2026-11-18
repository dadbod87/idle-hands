-- Complete the old week's passive payouts at its Pacific cutoff before recording standings.
-- Installation replaces functions only. It does not invoke a rollover or update player rows.
BEGIN;

DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.accrue(uuid)'::regprocedure)) <> '90bc8c288c00993cb8363a9d943a08c1'
     OR md5(pg_get_functiondef('public.roll_week()'::regprocedure)) <> 'a7a2935c1b64c0144c6072b24b18cfb6' THEN
    RAISE EXCEPTION 'Busywork cutoff baseline changed; review the installed functions before applying';
  END IF;
END
$guard$;

CREATE FUNCTION office_private.busywork_start(p public.players, end_at timestamptz)
RETURNS timestamptz
LANGUAGE sql IMMUTABLE
SET search_path TO ''
AS $function$
  SELECT greatest(
    coalesce(p.last_tick, end_at),
    end_at - make_interval(hours => CASE WHEN p.dept = 'property' THEN 12 ELSE 8 END
                                    + 4 * public.perk_of(p, 'deep_pockets'))
  )
$function$;
REVOKE ALL ON FUNCTION office_private.busywork_start(public.players,timestamptz)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.accrue(p_id uuid)
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; gain double precision; interval_start timestamptz;
        need_check boolean; need_settle boolean;
        active_week text; expected_week text := week_key();
begin
  if p_id is null then raise exception 'not signed in'; end if;

  select current_week into active_week from season_state where id = 1;
  if active_week < expected_week then perform roll_week(); end if;

  -- Hold the week open through the enclosing action, including its score update.
  perform pg_advisory_xact_lock_shared(728194, 5);
  select current_week, (not mhit) or (mw is distinct from expected_week)
    into active_week, need_check from season_state where id = 1;
  if active_week is distinct from expected_week then
    raise exception 'The office week changed. Refresh and try again.' using errcode = '40001';
  end if;
  if coalesce(need_check, true) then perform check_margarita(); end if;

  select exists (select 1 from meeting_claims where not paid) into need_settle;
  if need_settle then perform settle_meetings(); end if;

  select * into p from players where id = p_id for update;
  if p.id is null then raise exception 'no player'; end if;

  interval_start := office_private.busywork_start(p, now());
  if interval_start < now() then
    gain := public.accrual_interval_gain(p, interval_start, now());
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
  select current_week into prev from season_state where id = 1;
  if prev is null or prev >= k then return; end if;

  -- Wait for old-week actions before reading and settling their final scores.
  perform pg_advisory_xact_lock(728194, 5);
  select current_week, mhit into prev, was_hit from season_state where id = 1 for update;
  if prev is null or prev >= k then return; end if;

  select coalesce((data ->> 'wipe')::boolean, false), coalesce(data ->> 'from_week', '')
    into do_wipe, from_week from catalog where key = 'season';
  seasoned := do_wipe and from_week <> '' and prev >= from_week;

  -- Resolve the stored week's own cutoff, even if the office stayed idle for weeks.
  wk_start := week_started(to_date(prev || '-1','IYYY-IW-ID')::timestamp AT TIME ZONE 'America/Los_Angeles');
  wk_end := ((wk_start AT TIME ZONE 'America/Los_Angeles') + interval '7 days') AT TIME ZONE 'America/Los_Angeles';

  with pending as materialized (
    select p.id, public.accrual_interval_gain(
      p, greatest(wk_start, office_private.busywork_start(p, wk_end)), wk_end
    ) as gain
    from players p
    where p.last_tick < wk_end
  )
  update players p set pp = p.pp + pending.gain,
    lifetime = p.lifetime + pending.gain, cycle = p.cycle + pending.gain,
    week_pp = p.week_pp + pending.gain, day_pp = p.day_pp + pending.gain,
    last_tick = wk_end
  from pending where p.id = pending.id;

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

  if do_wipe then
    perform season_wipe();
  else
    update players set week_pp = 0,
      last_tick = case when last_tick is not null then greatest(last_tick, week_started()) end
    where week_pp <> 0 or last_tick < week_started();
  end if;

  update season_state set current_week = k, mw = k, mhit = false where id = 1;
  perform set_week_target();
end $function$;

COMMIT;
