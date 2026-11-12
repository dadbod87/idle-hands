-- RELEASE HOLD. Reviewed migration payload; NEVER run this file for a playtest.
-- Generate the deployment migration with `supabase migration new next_week_office`,
-- copy this exact payload, compare its hash, and apply only after verified rollover.
BEGIN;
CREATE SCHEMA IF NOT EXISTS office_private;
REVOKE ALL ON SCHEMA office_private FROM PUBLIC,anon,authenticated;
LOCK TABLE public.players,public.deeds IN SHARE ROW EXCLUSIVE MODE;
ALTER TABLE public.players ADD COLUMN seniority_earned integer NOT NULL DEFAULT 0 CHECK(seniority_earned>=0);
ALTER TABLE public.players ADD COLUMN cosmetic_rate_peak double precision NOT NULL DEFAULT 0 CHECK(cosmetic_rate_peak>=0 AND cosmetic_rate_peak<'Infinity'::float8);
ALTER TABLE public.players ADD COLUMN office_collectibles jsonb NOT NULL DEFAULT '[]';
ALTER TABLE public.players ADD COLUMN office_confetti jsonb;

CREATE TABLE office_private.action_history(
 source_deed bigint PRIMARY KEY, actor uuid NOT NULL,target uuid NOT NULL,
 kind text NOT NULL,category text NOT NULL CHECK(category IN('help','sabotage','playful','blocked','other')),
 amount double precision NOT NULL DEFAULT 0,hush boolean NOT NULL DEFAULT false,
 happened_at timestamptz NOT NULL,week text NOT NULL
);
CREATE INDEX action_history_actor_time ON office_private.action_history(actor,happened_at);
CREATE INDEX action_history_target_time ON office_private.action_history(target,happened_at);
CREATE INDEX action_history_week ON office_private.action_history(week);
CREATE TABLE office_private.project_stamps(
 week text NOT NULL,actor uuid NOT NULL,category text NOT NULL CHECK(category IN('work','facilities','care','playful')),
 happened_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(week,actor,category)
);
CREATE TABLE office_private.project_completions(week text PRIMARY KEY,completed_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE office_private.toolkits(
 actor uuid NOT NULL,week text NOT NULL,slots text[] NOT NULL DEFAULT ARRAY['rescue','confetti'],
 charges jsonb NOT NULL DEFAULT '{"rescue":2,"confetti":2,"filter":2}',PRIMARY KEY(actor,week)
);
CREATE TABLE office_private.action_receipts(actor uuid NOT NULL,request uuid NOT NULL,action text NOT NULL,target uuid NOT NULL,result jsonb NOT NULL,PRIMARY KEY(actor,request));
CREATE TABLE office_private.history_coverage(id boolean PRIMARY KEY DEFAULT true CHECK(id),started_at timestamptz NOT NULL);
INSERT INTO office_private.history_coverage(started_at) SELECT coalesce(min(created_at),now()) FROM public.deeds;
ALTER TABLE office_private.action_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.project_stamps ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.project_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.toolkits ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.action_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.history_coverage ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA office_private FROM PUBLIC,anon,authenticated;

CREATE FUNCTION office_private.action_category(k text,detail text DEFAULT NULL) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE WHEN detail='blocked:filter' THEN 'blocked'
 WHEN k IN('coffee','hype','cover','rescue') THEN 'help'
 WHEN k IN('dress','nickname','confetti') THEN 'playful'
 WHEN k IN('credit','mute','chair','meeting','replyall','blame') THEN 'sabotage' ELSE 'other' END
$$;
-- Backfill before attaching the live capture trigger: historical actions never earn project stamps.
INSERT INTO office_private.action_history(source_deed,actor,target,kind,category,amount,hush,happened_at,week)
 SELECT id,actor,target,kind,office_private.action_category(kind,detail),coalesce(amount,0),coalesce(hush,false),created_at,public.week_key(created_at) FROM public.deeds
 ON CONFLICT(source_deed) DO NOTHING;

CREATE FUNCTION office_private.project_credit(p_actor uuid,p_category text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE w text:=public.week_key();
BEGIN
 IF p_actor IS NULL OR p_category NOT IN('work','facilities','care','playful') THEN RETURN; END IF;
 -- One advisory lock per week makes completion detection atomic across contributors.
 PERFORM pg_advisory_xact_lock(hashtextextended('office-project:'||w,0));
 INSERT INTO office_private.project_stamps(week,actor,category) VALUES(w,p_actor,p_category) ON CONFLICT DO NOTHING;
 IF (SELECT count(*)>=12 AND count(DISTINCT actor)>=3 FROM office_private.project_stamps WHERE week=w) THEN
  INSERT INTO office_private.project_completions(week) VALUES(w) ON CONFLICT DO NOTHING;
 END IF;
END $$;
CREATE FUNCTION office_private.capture_deed() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c text:=office_private.action_category(NEW.kind,NEW.detail);
BEGIN
 INSERT INTO office_private.action_history(source_deed,actor,target,kind,category,amount,hush,happened_at,week)
 VALUES(NEW.id,NEW.actor,NEW.target,NEW.kind,c,coalesce(NEW.amount,0),coalesce(NEW.hush,false),NEW.created_at,public.week_key(NEW.created_at))
 ON CONFLICT(source_deed) DO UPDATE SET hush=office_private.action_history.hush OR excluded.hush;
 IF TG_OP='INSERT' AND c IN('help','playful') THEN PERFORM office_private.project_credit(NEW.actor,CASE WHEN c='help' THEN 'care' ELSE 'playful' END); END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER office_capture_deed AFTER INSERT OR UPDATE OF hush ON public.deeds FOR EACH ROW EXECUTE FUNCTION office_private.capture_deed();
CREATE FUNCTION office_private.production_peak() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r double precision;
BEGIN
 r:=public.calc_rate(NEW);
 IF r::text IN('NaN','Infinity','-Infinity') OR r<0 THEN RAISE EXCEPTION 'invalid production rate'; END IF;
 NEW.cosmetic_rate_peak:=greatest(NEW.cosmetic_rate_peak,CASE WHEN TG_OP='UPDATE' THEN OLD.cosmetic_rate_peak ELSE 0 END,r);
 RETURN NEW;
END $$;
CREATE TRIGGER office_production_peak BEFORE INSERT OR UPDATE OF owned,upgrades,cosmetic_rate_peak ON public.players FOR EACH ROW EXECUTE FUNCTION office_private.production_peak();
CREATE FUNCTION public.permanent_price_rate(p public.players) RETURNS double precision
LANGUAGE sql STABLE SET search_path='' AS $$ SELECT greatest(0.25,p.cosmetic_rate_peak,public.calc_rate(p)) $$;

CREATE FUNCTION office_private.work_credit() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.last_work IS DISTINCT FROM OLD.last_work AND NEW.last_work IS NOT NULL THEN PERFORM office_private.project_credit(NEW.id,'work'); END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER office_work_credit AFTER UPDATE OF last_work ON public.players FOR EACH ROW EXECUTE FUNCTION office_private.work_credit();
CREATE FUNCTION office_private.facility_credit() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.kind IN('plant','printer') AND (TG_OP='INSERT' OR NEW.n>OLD.n) THEN PERFORM office_private.project_credit(NEW.actor,'facilities'); END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER office_facility_credit AFTER INSERT OR UPDATE OF n ON public.office_play_actions FOR EACH ROW EXECUTE FUNCTION office_private.facility_credit();

CREATE FUNCTION office_private.filter_blocks(p_target uuid) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE blocked boolean:=false;
BEGIN
 UPDATE office_private.toolkits SET charges=jsonb_set(charges,'{filter}',to_jsonb((charges->>'filter')::int-1))
 WHERE actor=p_target AND week=public.week_key() AND 'filter'=ANY(slots) AND (charges->>'filter')::int>0 RETURNING true INTO blocked;
 RETURN coalesce(blocked,false);
END $$;

CREATE FUNCTION public.office_week_status() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();w text:=public.week_key();p public.players;k office_private.toolkits;result jsonb;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 SELECT * INTO p FROM public.players WHERE id=u;
 IF NOT FOUND THEN RAISE EXCEPTION 'no player'; END IF;
 SELECT * INTO k FROM office_private.toolkits WHERE actor=u AND week=w;
 SELECT jsonb_build_object('version',1,'week',w,'server_now',now(),'starts_at',public.week_started(),
 'project',jsonb_build_object('title','The Break Room Has Standards Now','goal',12,'minimum_contributors',3,'total',count(*),'contributors',count(DISTINCT actor),
 'mine',coalesce(jsonb_agg(category ORDER BY category) FILTER(WHERE actor=u),'[]'::jsonb),'completed',EXISTS(SELECT 1 FROM office_private.project_completions WHERE week=w)),
 'toolkit',jsonb_build_object('slots',coalesce(k.slots,ARRAY['rescue','confetti']),'charges',coalesce(k.charges,'{"rescue":2,"confetti":2,"filter":2}'::jsonb)),
 'collectibles',p.office_collectibles,'confetti',p.office_confetti,
 'history_since',(SELECT started_at FROM office_private.history_coverage WHERE id=true),
 'completed_weeks',coalesce((SELECT jsonb_agg(c.week ORDER BY c.week DESC) FROM office_private.project_completions c WHERE EXISTS(SELECT 1 FROM office_private.project_stamps s WHERE s.week=c.week AND s.actor=u)),'[]'::jsonb)) INTO result
 FROM office_private.project_stamps WHERE week=w;
 RETURN result;
END $$;

CREATE FUNCTION public.office_profile(p_player uuid,p_period text DEFAULT 'week',p_peer uuid DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE w text:=public.week_key();result jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM public.players WHERE id=auth.uid()) THEN RAISE EXCEPTION 'not signed in'; END IF;
 IF p_period IS NULL OR p_period NOT IN('week','lifetime') THEN RAISE EXCEPTION 'invalid period'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.players WHERE id=p_player) THEN RAISE EXCEPTION 'no player'; END IF;
 WITH visible AS(SELECT * FROM office_private.action_history h WHERE NOT hush AND (actor=p_player OR target=p_player)
 AND (p_period='lifetime' OR week=w) AND (p_peer IS NULL OR actor=p_peer OR target=p_peer)),
 kinds AS(SELECT kind,category,count(*) FILTER(WHERE actor=p_player) given,count(*) FILTER(WHERE target=p_player) received FROM visible GROUP BY kind,category),
 days AS(SELECT (happened_at AT TIME ZONE 'America/Los_Angeles')::date AS "day",count(*) FILTER(WHERE actor=p_player) given,count(*) FILTER(WHERE target=p_player) received FROM visible
 WHERE happened_at>=now()-interval '30 days' GROUP BY 1),
 peers AS(SELECT CASE WHEN actor=p_player THEN target ELSE actor END other,count(*) FILTER(WHERE actor=p_player) given,count(*) FILTER(WHERE target=p_player) received FROM visible GROUP BY 1)
 SELECT jsonb_build_object('player',jsonb_build_object('id',p_player,'name',(SELECT name FROM public.players WHERE id=p_player)),
 'period',p_period,'week',w,'since',(SELECT started_at FROM office_private.history_coverage WHERE id=true),'privacy','Hushed actions are excluded from public charts.',
 'by_kind',coalesce((SELECT jsonb_agg(to_jsonb(kinds) ORDER BY kind) FROM kinds),'[]'::jsonb),
 'daily',coalesce((SELECT jsonb_agg(to_jsonb(days) ORDER BY days."day") FROM days),'[]'::jsonb),
 'coworkers',coalesce((SELECT jsonb_agg(jsonb_build_object('id',other,'name',coalesce(p.name,'Former player'),'given',given,'received',received) ORDER BY given+received DESC)
 FROM peers LEFT JOIN public.players p ON p.id=other),'[]'::jsonb)) INTO result;
 RETURN result;
END $$;

CREATE FUNCTION public.office_equip_tools(p_slots text[]) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();
BEGIN
 IF u IS NULL OR NOT EXISTS(SELECT 1 FROM public.players WHERE id=u) THEN RAISE EXCEPTION 'not signed in'; END IF;
 PERFORM public.accrue(u);
 IF p_slots IS NULL OR (cardinality(p_slots)>0 AND array_ndims(p_slots)<>1) OR cardinality(p_slots)>2 OR cardinality(p_slots)<>(SELECT count(DISTINCT x) FROM unnest(p_slots) x)
 OR EXISTS(SELECT 1 FROM unnest(p_slots) x WHERE x NOT IN('rescue','confetti','filter') OR x IS NULL) THEN RAISE EXCEPTION 'choose at most two different tools'; END IF;
 INSERT INTO office_private.toolkits(actor,week,slots) VALUES(u,public.week_key(),p_slots)
 ON CONFLICT(actor,week) DO UPDATE SET slots=excluded.slots;
 RETURN public.office_week_status();
END $$;

CREATE FUNCTION public.office_interact(p_target uuid,p_action text,p_request uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();p public.players;t public.players;k office_private.toolkits;receipt office_private.action_receipts;remove_index bigint;outcome text;result jsonb;cd interval;
BEGIN
 IF u IS NULL OR p_request IS NULL OR p_target IS NULL OR p_target=u OR p_action NOT IN('rescue','confetti') OR p_action IS NULL THEN RAISE EXCEPTION 'choose a coworker and a valid action'; END IF;
 p:=public.accrue(u);
 SELECT * INTO receipt FROM office_private.action_receipts WHERE actor=u AND request=p_request;
 IF FOUND THEN
  IF receipt.target<>p_target OR receipt.action<>p_action THEN RAISE EXCEPTION 'request belongs to a different action'; END IF;
  RETURN receipt.result;
 END IF;
 SELECT * INTO t FROM public.players WHERE id=p_target FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'no such player'; END IF;
 -- Settle the old penalty before removing it; never retroactively reprice absence.
 t:=public.accrue(p_target);
 cd:=interval '5 minutes'-public.perk_of(p,'silver_tongue')*interval '1 minute';
 IF p.last_deed IS NOT NULL AND now()-p.last_deed<cd THEN RAISE EXCEPTION 'cooling off'; END IF;
 INSERT INTO office_private.toolkits(actor,week) VALUES(u,public.week_key()) ON CONFLICT DO NOTHING;
 SELECT * INTO k FROM office_private.toolkits WHERE actor=u AND week=public.week_key() FOR UPDATE;
 IF NOT p_action=ANY(k.slots) OR (k.charges->>p_action)::int<1 THEN RAISE EXCEPTION 'equip a charged tool first'; END IF;
 IF p_action='rescue' THEN
  SELECT ord INTO remove_index FROM jsonb_array_elements(t.buffs) WITH ORDINALITY e(b,ord)
  WHERE b->>'kind' IN('mute','chair','meeting','replyall') AND (b->>'mult')::float8<1 AND (b->>'until')::timestamptz>now()
  ORDER BY (b->>'until')::timestamptz,ord LIMIT 1;
  IF remove_index IS NULL THEN RAISE EXCEPTION 'no eligible negative effect to rescue'; END IF;
  UPDATE public.players SET buffs=coalesce((SELECT jsonb_agg(b ORDER BY ord) FROM jsonb_array_elements(t.buffs) WITH ORDINALITY e(b,ord) WHERE ord<>remove_index),'[]'::jsonb),kind_received=kind_received+1 WHERE id=p_target;
  outcome:='One coworker debuff cleared';
 ELSE
  IF t.office_confetti IS NOT NULL AND (t.office_confetti->>'until')::timestamptz>now() THEN RAISE EXCEPTION 'that desk already has confetti'; END IF;
  UPDATE public.players SET office_confetti=jsonb_build_object('until',now()+interval '10 minutes') WHERE id=p_target;
  outcome:='Confetti delivered. No income penalty.';
 END IF;
 UPDATE office_private.toolkits SET charges=jsonb_set(charges,ARRAY[p_action],to_jsonb((charges->>p_action)::int-1)) WHERE actor=u AND week=public.week_key();
 UPDATE public.players SET last_deed=now(),goodwill=goodwill+CASE WHEN p_action='rescue' THEN 1 ELSE 0 END WHERE id=u RETURNING * INTO p;
 INSERT INTO public.deeds(actor,target,kind,amount,detail) VALUES(u,p_target,p_action,0,outcome);
 result:=jsonb_build_object('outcome',outcome,'player',to_jsonb(p),'status',public.office_week_status());
 INSERT INTO office_private.action_receipts(actor,request,action,target,result) VALUES(u,p_request,p_action,p_target,result);
 RETURN result;
END $$;

CREATE FUNCTION public.office_clear_confetti() RETURNS public.players LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.players;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 UPDATE public.players SET office_confetti=NULL WHERE id=auth.uid() RETURNING * INTO p;
 IF NOT FOUND THEN RAISE EXCEPTION 'no player'; END IF;
 RETURN p;
END $$;

CREATE FUNCTION public.office_claim_collectible(p_item text,p_week text) RETURNS public.players LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();p public.players;n int;eligible boolean:=false;
BEGIN
 IF u IS NULL OR p_item IS NULL OR p_week IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 p:=public.accrue(u);
 IF p.office_collectibles ? p_item THEN RETURN p; END IF;
 SELECT count(*) INTO n FROM office_private.project_stamps WHERE week=p_week AND actor=u;
 IF p_item='nameplate' THEN eligible:=EXISTS(SELECT 1 FROM office_private.project_stamps WHERE week=p_week AND actor=u AND category='work') AND EXISTS(SELECT 1 FROM office_private.project_stamps WHERE week=p_week AND actor=u AND category='care');
 ELSIF p_item='corkboard' THEN eligible:=n>=3;
 ELSIF p_item='plaque' THEN eligible:=n>0 AND EXISTS(SELECT 1 FROM office_private.project_completions WHERE week=p_week);
 ELSE RAISE EXCEPTION 'unknown collectible'; END IF;
 IF NOT eligible THEN RAISE EXCEPTION 'milestone not complete'; END IF;
 UPDATE public.players SET office_collectibles=office_collectibles||to_jsonb(p_item) WHERE id=u RETURNING * INTO p;
 RETURN p;
END $$;

-- Everything below patches exact audited bodies; source drift aborts the whole transaction.
-- Filled by tools/build-next-week.py, not dynamic client-controlled SQL.
-- @PATCHES@
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.live_mult'::regproc))<>'5429d1b3f514ff57c0064018b0b278c8' THEN RAISE EXCEPTION 'Audited function drift: live_mult'; END IF; END $guard$;
CREATE OR REPLACE FUNCTION public.live_mult(p players)
 RETURNS double precision
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare m double precision; b jsonb; st text; door office_door; h int; dow int; sk int;
begin
  m := 1 + p.seniority_earned * 0.03 + least(p.goodwill, 30) * 0.01 + p.raises * 0.02;
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
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.live_mult_at'::regproc))<>'b58d9246df37ae24b1b6fed54c0e33ca' THEN RAISE EXCEPTION 'Audited function drift: live_mult_at'; END IF; END $guard$;
CREATE OR REPLACE FUNCTION public.live_mult_at(p players, ts timestamp with time zone)
 RETURNS double precision
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare m double precision; b jsonb; st text; door office_door; h int; dow int; sk int;
begin
  m := 1 + p.seniority_earned * 0.03 + least(p.goodwill, 30) * 0.01 + p.raises * 0.02;
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
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.restructure'::regproc))<>'8433908939bfd17f3ce870da881fa5d8' THEN RAISE EXCEPTION 'Audited function drift: restructure'; END IF; END $guard$;
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
 update players set equity=equity+gain,seniority_earned=seniority_earned+gain,quits=quits+1,last_restructure=now(),
 pp=0,cycle=0,owned='{}'::jsonb,upgrades='[]'::jsonb,buffs='[]'::jsonb,
 frenzy_until=null,heat=0,last_tick=now()
 where id=p.id returning * into p;
 return p;
end $function$
;
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.season_wipe'::regproc))<>'fac583c25071cc1bbf97db9fc79bc0b9' THEN RAISE EXCEPTION 'Audited function drift: season_wipe'; END IF; END $guard$;
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
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.buy_fitting'::regproc))<>'bcf9947dff258417a8a468f63cb9b3de' THEN RAISE EXCEPTION 'Audited function drift: buy_fitting'; END IF; END $guard$;
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
  price := greatest(1000, coalesce((it ->> 'min_cost')::double precision, 0), public.permanent_price_rate(p) * (it ->> 'secs')::double precision);
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
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.buy_pin'::regproc))<>'8348e090660d8a7fa5ff9166f5cde04f' THEN RAISE EXCEPTION 'Audited function drift: buy_pin'; END IF; END $guard$;
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
  price := greatest(1000, public.permanent_price_rate(p) * (it ->> 'secs')::double precision);
  if p.pp < price then raise exception 'cannot afford'; end if;
  update players set pp = pp - price, spent = spent + price,
    extras = extras || to_jsonb(p_id), pin = p_id
  where id = p.id returning * into p;
  return p;
end $function$
;
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.fitting_prices'::regproc))<>'95929213851f67836ac12c3d29f1a5e7' THEN RAISE EXCEPTION 'Audited function drift: fitting_prices'; END IF; END $guard$;
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
  eff := public.permanent_price_rate(p);
  for it in select value from catalog, jsonb_array_elements(data) v(value)
            where key in ('vanity', 'office_kit') loop
    out := out || jsonb_build_object(it ->> 'id',
             greatest(1000, coalesce((it ->> 'min_cost')::double precision, 0), eff * (it ->> 'secs')::double precision));
  end loop;
  return jsonb_build_object('rate', eff, 'prices', out);
end $function$
;
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.quote_style'::regproc))<>'96eb8e4199dad43a51a1ca8b1239f554' THEN RAISE EXCEPTION 'Audited function drift: quote_style'; END IF; END $guard$;
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
 r:=public.permanent_price_rate(p);
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
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.apply_style'::regproc))<>'fcaa94f37979f8234874ccb6a956151a' THEN RAISE EXCEPTION 'Audited function drift: apply_style'; END IF; END $guard$;
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
 r:=public.permanent_price_rate(p);
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
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.do_deed'::regproc))<>'3990db113fdb087cca7af01ed977496d' THEN RAISE EXCEPTION 'Audited function drift: do_deed'; END IF; END $guard$;
CREATE OR REPLACE FUNCTION public.do_deed(p_target uuid, p_kind text)
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; t players; d jsonb; price double precision; amt double precision := 0;
        soften double precision; eff double precision; cd interval; blocked_by_filter boolean:=false;
begin
  p := accrue(auth.uid());
  if p_target = p.id then raise exception 'not to yourself'; end if;
  cd := (interval '5 minutes') - (perk_of(p, 'silver_tongue') * interval '1 minute');
  if p.last_deed is not null and now() - p.last_deed < cd then raise exception 'cooling off'; end if;
  select (data -> p_kind) into d from catalog where key = 'deeds';
  if d is null then raise exception 'no such deed'; end if;
  if p_kind='cover' then d:='{"cost":0.05,"good":true,"mins":20,"mult":1.15}'::jsonb; end if;
  if d ? 'transfer' then raise exception 'cash transfer deeds are retired'; end if;
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
  if d ? 'mult' and (d->>'mult')::double precision<1 and office_private.filter_blocks(t.id) then
    blocked_by_filter:=true; d:=d-'mult';
  end if;
  if p_kind='cover' then
    update players set buffs=coalesce((select jsonb_agg(b) from jsonb_array_elements(t.buffs) b where b->>'kind'<>'cover'),'[]'::jsonb) where id=t.id;
  end if;
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

  insert into deeds (actor, target, kind, amount, detail) values (p.id, p_target, p_kind, amt,case when blocked_by_filter then 'blocked:filter' else null end);

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

-- @END_PATCHES@

UPDATE public.players p SET seniority_earned=equity+3*public.perk_of(p,'deep_pockets')+4*public.perk_of(p,'compound')+5*public.perk_of(p,'thick_skin')+4*public.perk_of(p,'silver_tongue')+3*public.perk_of(p,'good_hands'),cosmetic_rate_peak=greatest(cosmetic_rate_peak,public.calc_rate(p));
UPDATE public.catalog SET data=jsonb_set(data,'{cover}','{"cost":0.05,"good":true,"mins":20,"mult":1.15}') WHERE key='deeds';
-- Old, unaccepted style quotes used a different price basis; keep accepted receipts intact.
UPDATE public.style_quotes SET expires_at=least(expires_at,now()) WHERE NOT applied;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA office_private FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.permanent_price_rate(public.players) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.office_week_status(),public.office_profile(uuid,text,uuid),public.office_equip_tools(text[]),public.office_interact(uuid,text,uuid),public.office_clear_confetti(),public.office_claim_collectible(text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.office_week_status(),public.office_profile(uuid,text,uuid),public.office_equip_tools(text[]),public.office_interact(uuid,text,uuid),public.office_clear_confetti(),public.office_claim_collectible(text,text) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
