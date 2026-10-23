-- Read-only card projection. Preserve the signing formula, awards and all stored rows.
DO $guard$
BEGIN
 IF md5(pg_get_functiondef('public.card_state()'::regprocedure)) <> 'bd93245a9b6fb3b78073a1412beb8954' THEN
  RAISE EXCEPTION 'card_state drifted; review before applying';
 END IF;
 IF md5(pg_get_functiondef('public.sign_card()'::regprocedure)) <> '369d38e5cd3ee6498be2d130317a1b30' THEN
  RAISE EXCEPTION 'sign_card formula drifted; review quote before applying';
 END IF;
END $guard$;
CREATE OR REPLACE FUNCTION public.card_state()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with k as (select public.week_key() as wk)
  select jsonb_build_object(
    'week', (select wk from k),
    'signers', coalesce((select signers from public.birthday_card, k where week_key = wk), '[]'::jsonb),
    'pot', coalesce((select pot from public.birthday_card, k where week_key = wk), 0),
    'paid', coalesce((select paid from public.birthday_card, k where week_key = wk), false),
    'staff', (select count(*) from public.players),
    'mine', coalesce((select signers from public.birthday_card, k where week_key = wk), '[]'::jsonb)
             ? auth.uid()::text,
    'contribution', (select greatest(50, public.calc_rate(p) * public.live_mult(p) * 240)
                     from public.players p where p.id = auth.uid()))
$function$;
