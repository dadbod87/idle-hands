-- Extend real weekly fund milestones; preserve every existing threshold and bonus.
-- No player updates, accrual calls, resets or reward backfills.
DO $guard$
BEGIN
 IF (SELECT data FROM public.catalog WHERE key='fund_tiers') IS DISTINCT FROM $old$[10000000000000000, 550000000000000000, 30000000000000000000, 1.7e+21, 9.5e+22, 5.2e+24, 2.9e+26, 1.6e+28]$old$::jsonb THEN RAISE EXCEPTION 'Fund tiers drifted; review before applying'; END IF;
 IF md5(pg_get_functiondef('public.office_state()'::regprocedure))<>'d3736c880ea00fd9801dca397a79dda5' THEN RAISE EXCEPTION 'Office state drifted; review before applying'; END IF;
 IF md5(pg_get_functiondef('public.quote_style(text,text,text)'::regprocedure))<>'d2c2a6b23455eba85941fe140a0db4e6' THEN RAISE EXCEPTION 'Style quote drifted; review before applying';END IF;
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.apply_style(uuid)'::regprocedure)<>'a2fa3dc6db8535cf27595d2a69131f67' THEN RAISE EXCEPTION 'Style payment drifted; review before applying';END IF;
END $guard$;
UPDATE public.catalog SET data=data||$extra$[1e+30, 5e+31, 2e+33, 1e+35, 5e+36, 2.5e+37, 1e+38, 5e+38, 2.5e+39, 1e+40, 5e+40, 2.5e+41]$extra$::jsonb WHERE key='fund_tiers';
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
    'fund_thresholds', (select data from catalog where key = 'fund_tiers'),
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

-- Read-only status: opening/refreshing a machine never pulls it or accrues money.
CREATE FUNCTION public.vending_state() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.players;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 SELECT * INTO p FROM public.players WHERE id=auth.uid();
 IF NOT FOUND THEN RAISE EXCEPTION 'no employee'; END IF;
 RETURN jsonb_build_object('server_now',now(),'last_vend',p.last_vend,
  'ready_at',CASE WHEN p.last_vend IS NOT NULL THEN p.last_vend+interval '10 minutes' ELSE NULL END,
  'price',greatest(60,public.calc_rate(p)*public.live_mult(p)*45),'balance',p.pp);
END $$;
REVOKE ALL ON FUNCTION public.vending_state() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.vending_state() TO authenticated;

-- Lower each paid component to eight hours. Keep ownership/payment/replay rules.
DO $style_guard$ BEGIN
 IF md5(pg_get_functiondef('public.quote_style(text,text,text)'::regprocedure))<>'d2c2a6b23455eba85941fe140a0db4e6' THEN RAISE EXCEPTION 'Style quote drifted; review before applying';END IF;
END $style_guard$;
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
 RETURN jsonb_build_object('id',q.id,'item',q.item,'color',q.color,'design',q.design,'color_fee',cf,'design_fee',df,'total',cf+df,'rate',r,'expires_at',q.expires_at,'balance',p.pp);
END $function$
;
DO $apply_guard$ BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.apply_style(uuid)'::regprocedure)<>'a2fa3dc6db8535cf27595d2a69131f67' THEN RAISE EXCEPTION 'Style payment drifted; review before applying';END IF;
END $apply_guard$;
CREATE OR REPLACE FUNCTION public.apply_style(p_quote uuid) RETURNS public.players
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
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
END $$;
-- Only unconfirmed quotes expire; accepted receipts remain safe to retry.
UPDATE public.style_quotes SET expires_at=least(expires_at,now()) WHERE NOT applied;
NOTIFY pgrst,'reload schema';
