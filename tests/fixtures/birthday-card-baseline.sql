CREATE OR REPLACE FUNCTION public.card_state()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with k as (select to_char(now(), 'IYYY-IW') as wk)
  select jsonb_build_object(
    'week', (select wk from k),
    'signers', coalesce((select signers from birthday_card, k where week_key = wk), '[]'::jsonb),
    'pot', coalesce((select pot from birthday_card, k where week_key = wk), 0),
    'paid', coalesce((select paid from birthday_card, k where week_key = wk), false),
    'staff', (select count(*) from players),
    'mine', coalesce((select signers from birthday_card, k where week_key = wk), '[]'::jsonb)
             ? auth.uid()::text)
$function$
;
CREATE OR REPLACE FUNCTION public.sign_card()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; wk text := week_key(); c birthday_card;
        give double precision; staff int; share double precision;
begin
  p := accrue(auth.uid());
  insert into birthday_card (week_key) values (wk) on conflict (week_key) do nothing;
  select * into c from birthday_card where week_key = wk for update;
  if c.signers ? p.id::text then raise exception 'already signed'; end if;
  give := greatest(50, calc_rate(p) * live_mult(p) * 240);   -- four minutes each
  if p.pp < give then raise exception 'cannot afford'; end if;

  update players set pp = pp - give where id = p.id;
  update birthday_card set signers = signers || to_jsonb(p.id::text), pot = pot + give
  where week_key = wk returning * into c;

  select count(*) into staff from players;
  if jsonb_array_length(c.signers) >= staff and not c.paid then
    share := (c.pot * 2) / greatest(staff, 1);
    update players set pp = pp + share, lifetime = lifetime + share, cycle = cycle + share,
      week_pp = week_pp + share, day_pp = day_pp + share where id is not null;
    update birthday_card set paid = true where week_key = wk;
    update players set buffs = buffs || jsonb_build_object(
      'kind','cake','mult',1.2,'from_name','the cake','until', now() + interval '30 minutes')
    where id is not null;
  end if;
  return card_state();
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
