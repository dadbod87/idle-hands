CREATE OR REPLACE FUNCTION public.cow_arm()
 RETURNS cow_state
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare c cow_state; k text; off bigint; want timestamptz;
begin
  k := week_key();
  off := mod(abs(hashtext('cow-level:' || k)::bigint), 604800);
  select * into c from cow_state where id = 1 for update;
  if c.id is null then
    insert into cow_state (id, week_key, unlock_at)
      values (1, k, week_started() + (off || ' seconds')::interval)
      returning * into c;
  elsif c.week_key is distinct from k then
    want := coalesce(c.pin_next, week_started() + (off || ' seconds')::interval);
    update cow_state set week_key = k, unlock_at = want, pin_next = null,
      taken_by = null, taken_at = null, orbs = null, secs_per_orb = null,
      loot = null, finished = false
    where id = 1 returning * into c;
  end if;
  return c;
end $function$

