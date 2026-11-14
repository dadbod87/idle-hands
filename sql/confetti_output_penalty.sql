-- Confetti output penalty. Guarded forward-only patch; no existing player rows are changed on installation.
BEGIN;
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.accrual_interval_gain(public.players,timestamptz,timestamptz)'::regprocedure))<>'8346e7d8278aee824d5116f73bfebe10' THEN RAISE EXCEPTION 'Audited function drift: accrual_interval_gain';END IF;END $guard$;
DO $guard$ BEGIN IF md5(pg_get_functiondef('office_private.action_category(text,text)'::regprocedure))<>'deb908b87ee3f689a0c07dfe6a060d84' THEN RAISE EXCEPTION 'Audited function drift: office_private.action_category';END IF;END $guard$;
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.office_week_status()'::regprocedure))<>'b5ceb5cf5a44e10a9c3b36fe96f64e3f' THEN RAISE EXCEPTION 'Audited function drift: public.office_week_status';END IF;END $guard$;
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.office_interact(uuid,text,uuid)'::regprocedure))<>'de6da02058e5e79a3fe761c058a7570f' THEN RAISE EXCEPTION 'Audited function drift: public.office_interact';END IF;END $guard$;
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.office_clear_confetti()'::regprocedure))<>'3f30be6b3317247c080ba23110ad81ca' THEN RAISE EXCEPTION 'Audited function drift: public.office_clear_confetti';END IF;END $guard$;
DO $guard$ BEGIN IF md5(pg_get_functiondef('office_private.capture_deed()'::regprocedure))<>'bdcfa8d2945b9e4b4ba17390ebde8217' THEN RAISE EXCEPTION 'Audited function drift: office_private.capture_deed';END IF;END $guard$;
CREATE OR REPLACE FUNCTION office_private.action_category(k text,detail text DEFAULT NULL) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE WHEN detail='blocked:filter' THEN 'blocked'
 WHEN k='confetti' AND detail='sabotage:confetti' THEN 'sabotage'
 WHEN k IN('coffee','hype','cover','rescue') THEN 'help'
 WHEN k IN('dress','nickname','confetti') THEN 'playful'
 WHEN k IN('credit','mute','chair','meeting','replyall','blame') THEN 'sabotage' ELSE 'other' END
$$;

CREATE OR REPLACE FUNCTION office_private.capture_deed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE c text:=CASE WHEN NEW.detail='reflected:shield' THEN 'blocked' ELSE office_private.action_category(NEW.kind,NEW.detail) END;
BEGIN
 INSERT INTO office_private.action_history(source_deed,actor,target,kind,category,amount,hush,happened_at,week)
 VALUES(NEW.id,NEW.actor,NEW.target,NEW.kind,c,coalesce(NEW.amount,0),coalesce(NEW.hush,false),NEW.created_at,public.week_key(NEW.created_at))
 ON CONFLICT(source_deed) DO UPDATE SET hush=office_private.action_history.hush OR excluded.hush;
 IF TG_OP='INSERT' AND (c IN('help','playful') OR (NEW.kind='confetti' AND c='sabotage')) THEN PERFORM office_private.project_credit(NEW.actor,CASE WHEN c='help' THEN 'care' ELSE 'playful' END); END IF;
 RETURN NEW;
END $function$


CREATE OR REPLACE FUNCTION public.office_week_status()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE u uuid:=auth.uid();clock timestamptz:=office_private.project_now();w text:=public.week_key(clock);today date:=(clock AT TIME ZONE 'America/Los_Angeles')::date;p public.players;k office_private.toolkits;c office_private.projects;result jsonb;progress jsonb;daily text[];n int;people int;dates int;used int;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 SELECT * INTO p FROM public.players WHERE id=u;
 IF NOT FOUND THEN RAISE EXCEPTION 'no player'; END IF;
 c:=office_private.ensure_project();progress:=office_private.collection_progress(u);
 SELECT * INTO k FROM office_private.toolkits WHERE actor=u AND week=w;
 SELECT total,contributors,active_days INTO n,people,dates FROM office_private.project_progress(w,clock);
 SELECT coalesce(array_agg(category ORDER BY category),ARRAY[]::text[]) INTO daily FROM office_private.daily_activity WHERE actor=u AND week=w AND day=today;
 SELECT count(*) INTO used FROM office_private.resupplies WHERE actor=u AND week=w;
 result:=jsonb_build_object('version',1,'depth_version',1,'week',w,'server_now',clock,'starts_at',c.starts_at,
 'project',jsonb_build_object('theme',c.theme,'title',c.title,'description',c.description,'categories',to_jsonb(c.categories),'goal',c.goal,'minimum_contributors',c.minimum_contributors,'total',n,'contributors',people,
 'credit_unit','daily_category','minimum_days',c.minimum_days,'active_days',dates,'stretch_days',c.stretch_days,'today',today,'mine_today',to_jsonb(daily),
 'stretch_goal',c.stretch_goal,'stretch_contributors',c.stretch_contributors,'stretch_completed',EXISTS(SELECT 1 FROM office_private.project_completions WHERE week=w AND stretch_at IS NOT NULL),
 'mine',coalesce((SELECT jsonb_agg(category ORDER BY category) FROM office_private.project_stamps WHERE week=w AND actor=u),'[]'::jsonb),'completed',EXISTS(SELECT 1 FROM office_private.project_completions WHERE week=w)),
 'toolkit',jsonb_build_object('slots',coalesce(k.slots,ARRAY['rescue','confetti']),'charges','{"rescue":2,"confetti":2,"filter":2,"clip":2}'::jsonb||coalesce(k.charges,'{}'::jsonb)),
 'collection',progress||jsonb_build_object('display',p.office_display),
 'scrapbook',coalesce((SELECT jsonb_agg(m.reward||jsonb_build_object('stretch',m.stretch,'selected',p.office_memento->>'week'=m.week) ORDER BY m.week DESC) FROM office_private.mementos m WHERE m.actor=u),'[]'::jsonb),
 'resupply',jsonb_build_object('day',today,'activity',to_jsonb(daily),'used_this_week',used,'weekly_limit',3,'claimed_today',EXISTS(SELECT 1 FROM office_private.resupplies WHERE actor=u AND day=today),'eligible',cardinality(daily)>=2 AND 'work'=ANY(daily) AND used<3 AND NOT EXISTS(SELECT 1 FROM office_private.resupplies WHERE actor=u AND day=today)),
 'shield',jsonb_build_object('armed',coalesce((SELECT armed FROM office_private.shields WHERE actor=u AND week=w),false),'price_hint',office_private.shield_price(p),'price_basis','Twice the highest base sabotage quote; this week''s retained production, no temporary boosts or department discount'),
 'cooldown_until',CASE WHEN p.last_deed IS NULL THEN NULL ELSE p.last_deed+interval '5 minutes'-public.perk_of(p,'silver_tongue')*interval '1 minute' END,
 'collectibles',p.office_collectibles,'confetti',p.office_confetti,'confetti_rules',jsonb_build_object('version',1,'mult',0.65,'minutes',10),
 'history_since',(SELECT started_at FROM office_private.history_coverage WHERE id=true),'continuous_since',(SELECT continuous_since FROM office_private.history_coverage WHERE id=true),
 'reward_weeks',coalesce((SELECT jsonb_agg(jsonb_build_object('week',r.week,'mine',r.mine,'categories',(SELECT to_jsonb(pc.categories) FROM office_private.projects pc WHERE pc.week=r.week),'completed',EXISTS(SELECT 1 FROM office_private.project_completions pc WHERE pc.week=r.week)) ORDER BY r.week DESC) FROM (SELECT s.week,jsonb_agg(s.category ORDER BY s.category) mine FROM office_private.project_stamps s WHERE s.actor=u GROUP BY s.week) r),'[]'::jsonb),
 'completed_weeks',coalesce((SELECT jsonb_agg(pc.week ORDER BY pc.week DESC) FROM office_private.project_completions pc WHERE EXISTS(SELECT 1 FROM office_private.project_stamps s WHERE s.week=pc.week AND s.actor=u)),'[]'::jsonb));
 RETURN result;
END $function$


CREATE OR REPLACE FUNCTION public.office_interact(p_target uuid,p_action text,p_request uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();p public.players;t public.players;victim public.players;k office_private.toolkits;receipt office_private.action_receipts;
 remove_index bigint;removed_kind text;outcome text;result jsonb;cd interval;soften float8;eff float8;reflected boolean:=false;blocked boolean:=false;detail text;deed_id bigint;
BEGIN
 IF u IS NULL OR p_request IS NULL OR p_target IS NULL OR p_target=u OR p_action NOT IN('rescue','confetti') OR p_action IS NULL THEN RAISE EXCEPTION 'choose a coworker and a valid action'; END IF;
 PERFORM pg_advisory_xact_lock(728194,1);
 p:=public.accrue(u);
 SELECT * INTO receipt FROM office_private.action_receipts WHERE actor=u AND request=p_request;
 IF FOUND THEN
  IF receipt.target<>p_target OR receipt.action<>p_action THEN RAISE EXCEPTION 'request belongs to a different action'; END IF;
  RETURN receipt.result;
 END IF;
 SELECT * INTO t FROM public.players WHERE id=p_target FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'no such player'; END IF;
 t:=public.accrue(p_target);
 cd:=interval '5 minutes'-public.perk_of(p,'silver_tongue')*interval '1 minute';
 IF p.last_deed IS NOT NULL AND now()-p.last_deed<cd THEN RAISE EXCEPTION 'cooling off'; END IF;
 INSERT INTO office_private.toolkits(actor,week) VALUES(u,public.week_key()) ON CONFLICT DO NOTHING;
 SELECT * INTO k FROM office_private.toolkits WHERE actor=u AND week=public.week_key() FOR UPDATE;
 IF NOT p_action=ANY(k.slots) OR (k.charges->>p_action)::int<1 THEN RAISE EXCEPTION 'equip a charged tool first'; END IF;
 IF p_action='rescue' THEN
  SELECT ord,b->>'kind' INTO remove_index,removed_kind FROM jsonb_array_elements(t.buffs) WITH ORDINALITY e(b,ord)
  WHERE b->>'kind' IN('mute','chair','meeting','replyall','confetti') AND (b->>'mult')::float8<1 AND (b->>'until')::timestamptz>now()
  AND coalesce(b->>'start',CASE WHEN (b->>'from') ~ '^\d{4}-\d{2}-\d{2}' THEN b->>'from' END,now()::text)::timestamptz<=now()
  ORDER BY (b->>'until')::timestamptz,ord LIMIT 1;
  IF remove_index IS NULL THEN RAISE EXCEPTION 'no eligible negative effect to rescue'; END IF;
  UPDATE public.players SET buffs=coalesce((SELECT jsonb_agg(b ORDER BY ord) FROM jsonb_array_elements(t.buffs) WITH ORDINALITY e(b,ord) WHERE ord<>remove_index),'[]'::jsonb),
   office_confetti=CASE WHEN removed_kind='confetti' THEN NULL ELSE office_confetti END,kind_received=kind_received+1 WHERE id=p_target;
  outcome:='One coworker debuff cleared';detail:=outcome;
 ELSE
  IF t.office_confetti IS NOT NULL AND (t.office_confetti->>'until')::timestamptz>now() THEN RAISE EXCEPTION 'that desk already has confetti'; END IF;
  reflected:=office_private.consume_shield(t.id);
  victim:=CASE WHEN reflected THEN p ELSE t END;
  IF reflected AND victim.office_confetti IS NOT NULL AND (victim.office_confetti->>'until')::timestamptz>now() THEN RAISE EXCEPTION 'the returned confetti already covers your desk'; END IF;
  IF NOT reflected THEN blocked:=office_private.filter_blocks(t.id);END IF;
  IF blocked THEN
   outcome:='Their Spam Filter blocked the confetti.';detail:='blocked:filter';
  ELSE
   soften:=greatest(0.2,CASE WHEN victim.dept='systems' THEN 0.6 ELSE 1 END*(1-0.25*public.perk_of(victim,'thick_skin')));
   eff:=1-0.35*soften;
   UPDATE public.players SET office_confetti=jsonb_build_object('until',now()+interval '10 minutes','mult',eff),
    buffs=buffs||jsonb_build_object('kind','confetti','mult',eff,'start',now(),'until',now()+interval '10 minutes',
     'from_name',CASE WHEN reflected THEN t.name||' · Return to Sender' ELSE p.name END) WHERE id=victim.id;
   detail:=CASE WHEN reflected THEN 'reflected:shield' ELSE 'sabotage:confetti' END;
   outcome:=CASE WHEN reflected THEN 'Return to Sender: the confetti bounced back onto your desk.' ELSE 'Confetti delivered. Output reduced until cleanup or expiry.' END;
  END IF;
 END IF;
 UPDATE office_private.toolkits SET charges=jsonb_set(charges,ARRAY[p_action],to_jsonb((charges->>p_action)::int-1)) WHERE actor=u AND week=public.week_key();
 UPDATE public.players SET last_deed=now(),goodwill=goodwill+CASE WHEN p_action='rescue' THEN 1 ELSE 0 END,
  notoriety=notoriety+CASE WHEN p_action='confetti' THEN 1 ELSE 0 END,
  heat=heat+CASE WHEN p_action='confetti' THEN 1 ELSE 0 END,
  busted=busted+CASE WHEN p_action='confetti' AND heat+1=5 THEN 1 ELSE 0 END
 WHERE id=u RETURNING * INTO p;
 INSERT INTO public.deeds(actor,target,kind,amount,detail) VALUES(u,p_target,p_action,0,detail) RETURNING id INTO deed_id;
 IF reflected THEN INSERT INTO office_private.reflections(source_deed,defender,sender,kind,amount) VALUES(deed_id,p_target,u,p_action,0);END IF;
 result:=jsonb_build_object('outcome',outcome,'player',to_jsonb(p),'status',public.office_week_status(),'reflected',reflected,'detail',detail);
 INSERT INTO office_private.action_receipts(actor,request,action,target,result) VALUES(u,p_request,p_action,p_target,result);
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.office_clear_confetti() RETURNS public.players LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.players;u uuid:=auth.uid();
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 PERFORM pg_advisory_xact_lock(728194,1);
 p:=public.accrue(u);
 UPDATE public.players SET office_confetti=NULL,
  buffs=coalesce((SELECT jsonb_agg(b ORDER BY ord) FROM jsonb_array_elements(p.buffs) WITH ORDINALITY e(b,ord) WHERE b->>'kind' IS DISTINCT FROM 'confetti'),'[]'::jsonb)
 WHERE id=u RETURNING * INTO p;
 IF NOT FOUND THEN RAISE EXCEPTION 'no player'; END IF;
 RETURN p;
END $$;
REVOKE ALL ON FUNCTION office_private.action_category(text,text),office_private.capture_deed() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.office_interact(uuid,text,uuid),public.office_clear_confetti(),public.office_week_status() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.office_interact(uuid,text,uuid),public.office_clear_confetti(),public.office_week_status() TO authenticated;
CREATE OR REPLACE FUNCTION public.accrual_interval_gain(p players, since_ts timestamp with time zone, until_ts timestamp with time zone)
 RETURNS double precision
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
WITH ticks AS (
  SELECT g::bigint k FROM generate_series(floor(extract(epoch from since_ts)/3600)::bigint-1,floor(extract(epoch from until_ts)/3600)::bigint+1) g
), candidates AS (
 SELECT since_ts AS t UNION ALL SELECT until_ts
 UNION ALL SELECT to_timestamp(k*3600) FROM ticks
 UNION ALL SELECT to_timestamp(k*3600 + ((k*17)%45)*60) FROM ticks WHERE k%12<8
 UNION ALL SELECT to_timestamp(k*3600 + ((k*17)%45)*60 + 240) FROM ticks WHERE k%12<8
 UNION ALL SELECT to_timestamp(k*3600+3300) FROM ticks WHERE k%2=0
 UNION ALL SELECT to_timestamp(k*3600+3540) FROM ticks WHERE k%2=0
 UNION ALL SELECT p.frenzy_until WHERE p.frenzy_until IS NOT NULL
 UNION ALL SELECT (CASE WHEN b->>'start' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' THEN b->>'start' WHEN b->>'from' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' THEN b->>'from' END)::timestamptz FROM jsonb_array_elements(coalesce(p.buffs,'[]'::jsonb)) b
 UNION ALL SELECT (b->>'until')::timestamptz FROM jsonb_array_elements(coalesce(p.buffs,'[]'::jsonb)) b WHERE b->>'until' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
), ordered AS (
 SELECT t, lead(t) OVER (ORDER BY t) nxt FROM (SELECT DISTINCT t FROM candidates WHERE t BETWEEN since_ts AND until_ts) q
)
SELECT coalesce(sum(extract(epoch from (nxt-t))*public.live_mult_at(p,t+(nxt-t)/2)),0)*public.calc_rate(p)
FROM ordered WHERE nxt IS NOT NULL
$function$

NOTIFY pgrst,'reload schema';
COMMIT;
