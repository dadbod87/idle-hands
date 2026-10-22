CREATE OR REPLACE FUNCTION public.cow_try()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_variable
declare v_p players; v_c cow_state; v_loot text;
begin
  v_p := accrue(auth.uid());
  v_c := cow_arm();
  if v_c.taken_by is not null then return null; end if;
  if now() < v_c.unlock_at then return null; end if;
  v_loot := cow_roll(v_p.id);
  update cow_state set taken_by = v_p.id, taken_at = now(),
    orbs = 24, secs_per_orb = 75, loot = v_loot, finished = false
  where id = 1;
  return jsonb_build_object('orbs', 24, 'secs', 75, 'loot', v_loot);
end $function$

