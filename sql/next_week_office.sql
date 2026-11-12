-- RELEASE HOLD. Reviewed migration payload; NEVER run this file for a playtest.
-- Generate the deployment migration with `supabase migration new next_week_office`,
-- copy this exact payload, compare its hash, and apply only after verified rollover.
BEGIN;
CREATE SCHEMA IF NOT EXISTS office_private;
REVOKE ALL ON SCHEMA office_private FROM PUBLIC,anon,authenticated;
LOCK TABLE public.players,public.deeds IN SHARE ROW EXCLUSIVE MODE;
-- @JOURNAL_INSTALL@
DO $journal_reuse$
BEGIN
 IF to_regclass('office_private.action_history') IS NULL AND to_regclass('office_private.history_coverage') IS NULL THEN
  EXECUTE $journal_core$CREATE TABLE office_private.action_history(
 source_deed bigint PRIMARY KEY, actor uuid NOT NULL,target uuid NOT NULL,
 kind text NOT NULL,category text NOT NULL CHECK(category IN('help','sabotage','playful','blocked','other')),
 amount double precision NOT NULL DEFAULT 0,hush boolean NOT NULL DEFAULT false,
 happened_at timestamptz NOT NULL,week text NOT NULL
);
CREATE INDEX action_history_actor_time ON office_private.action_history(actor,happened_at);
CREATE INDEX action_history_target_time ON office_private.action_history(target,happened_at);
CREATE INDEX action_history_week ON office_private.action_history(week);
CREATE TABLE office_private.history_coverage(id boolean PRIMARY KEY DEFAULT true CHECK(id),started_at timestamptz NOT NULL,continuous_since timestamptz NOT NULL DEFAULT now());
INSERT INTO office_private.history_coverage(started_at) SELECT coalesce(min(created_at),now()) FROM public.deeds;
CREATE FUNCTION office_private.action_category(k text,detail text DEFAULT NULL) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE WHEN detail='blocked:filter' THEN 'blocked'
 WHEN k IN('coffee','hype','cover','rescue') THEN 'help'
 WHEN k IN('dress','nickname','confetti') THEN 'playful'
 WHEN k IN('credit','mute','chair','meeting','replyall','blame') THEN 'sabotage' ELSE 'other' END
$$;
INSERT INTO office_private.action_history(source_deed,actor,target,kind,category,amount,hush,happened_at,week)
 SELECT id,actor,target,kind,office_private.action_category(kind,detail),coalesce(amount,0),coalesce(hush,false),created_at,public.week_key(created_at) FROM public.deeds
 ON CONFLICT(source_deed) DO NOTHING;

CREATE FUNCTION office_private.capture_deed() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $journal_capture$
BEGIN
 INSERT INTO office_private.action_history(source_deed,actor,target,kind,category,amount,hush,happened_at,week)
 VALUES(NEW.id,NEW.actor,NEW.target,NEW.kind,office_private.action_category(NEW.kind,NEW.detail),coalesce(NEW.amount,0),coalesce(NEW.hush,false),NEW.created_at,public.week_key(NEW.created_at))
 ON CONFLICT(source_deed) DO UPDATE SET hush=office_private.action_history.hush OR excluded.hush;
 RETURN NEW;
END $journal_capture$;
CREATE TRIGGER office_capture_deed AFTER INSERT OR UPDATE OF hush ON public.deeds FOR EACH ROW EXECUTE FUNCTION office_private.capture_deed();
ALTER TABLE office_private.action_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.history_coverage ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE office_private.action_history,office_private.history_coverage FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION office_private.action_category(text,text),office_private.capture_deed() FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE office_private.action_history IS 'idle-hands:action-journal:v1';
$journal_core$;
 ELSE
  IF to_regclass('office_private.action_history') IS NULL OR to_regclass('office_private.history_coverage') IS NULL
  THEN RAISE EXCEPTION 'incomplete prior journal installation'; END IF;
  IF obj_description('office_private.action_history'::regclass,'pg_class') IS DISTINCT FROM 'idle-hands:action-journal:v1'
  OR (SELECT array_agg(attname::text||':'||format_type(atttypid,atttypmod) ORDER BY attnum) FROM pg_attribute WHERE attrelid='office_private.action_history'::regclass AND attnum>0 AND NOT attisdropped)
   IS DISTINCT FROM ARRAY['source_deed:bigint','actor:uuid','target:uuid','kind:text','category:text','amount:double precision','hush:boolean','happened_at:timestamp with time zone','week:text']
  OR (SELECT array_agg(attname::text||':'||format_type(atttypid,atttypmod) ORDER BY attnum) FROM pg_attribute WHERE attrelid='office_private.history_coverage'::regclass AND attnum>0 AND NOT attisdropped)
   IS DISTINCT FROM ARRAY['id:boolean','started_at:timestamp with time zone','continuous_since:timestamp with time zone']
  THEN RAISE EXCEPTION 'prior journal schema drift; review before reuse'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='office_private.action_history'::regclass AND contype='p' AND conkey=ARRAY[1]::smallint[])
  OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='office_private.history_coverage'::regclass AND contype='p' AND conkey=ARRAY[1]::smallint[])
  OR (SELECT count(*) FROM office_private.history_coverage)<>1
  THEN RAISE EXCEPTION 'prior journal identity or coverage drift; review before reuse'; END IF;
  IF (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('office_private.capture_deed()')) IS DISTINCT FROM '751b1e6b8981022f0578e5c7aa099e19'
  OR (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('office_private.action_category(text,text)')) IS DISTINCT FROM '0ff82e1975eda680a9d61b49297388bd'
  THEN RAISE EXCEPTION 'prior journal function drift; review before reuse'; END IF;
  IF EXISTS(SELECT 1 FROM pg_class WHERE oid IN('office_private.action_history'::regclass,'office_private.history_coverage'::regclass) AND NOT relrowsecurity)
  OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='office_capture_deed' AND tgrelid='public.deeds'::regclass AND tgfoid='office_private.capture_deed()'::regprocedure AND tgenabled='O' AND NOT tgisinternal)
  OR has_table_privilege('anon','office_private.action_history','SELECT,INSERT,UPDATE,DELETE')
  OR has_table_privilege('authenticated','office_private.action_history','SELECT,INSERT,UPDATE,DELETE')
  OR has_table_privilege('anon','office_private.history_coverage','SELECT,INSERT,UPDATE,DELETE')
  OR has_table_privilege('authenticated','office_private.history_coverage','SELECT,INSERT,UPDATE,DELETE')
  OR has_function_privilege('anon','office_private.capture_deed()','EXECUTE')
  OR has_function_privilege('authenticated','office_private.action_category(text,text)','EXECUTE')
  THEN RAISE EXCEPTION 'prior journal protection drift; review before reuse'; END IF;
 END IF;
END $journal_reuse$;
-- @END_JOURNAL_INSTALL@
ALTER TABLE public.players ADD COLUMN seniority_earned integer NOT NULL DEFAULT 0 CHECK(seniority_earned>=0);
ALTER TABLE public.players ADD COLUMN cosmetic_rate_peak double precision NOT NULL DEFAULT 0 CHECK(cosmetic_rate_peak>=0 AND cosmetic_rate_peak<'Infinity'::float8);
ALTER TABLE public.players ADD COLUMN office_collectibles jsonb NOT NULL DEFAULT '[]';
ALTER TABLE public.players ADD COLUMN office_confetti jsonb;

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
ALTER TABLE office_private.project_stamps ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.project_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.toolkits ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.action_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA office_private FROM PUBLIC,anon,authenticated;

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
CREATE OR REPLACE FUNCTION office_private.capture_deed() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c text:=office_private.action_category(NEW.kind,NEW.detail);
BEGIN
 INSERT INTO office_private.action_history(source_deed,actor,target,kind,category,amount,hush,happened_at,week)
 VALUES(NEW.id,NEW.actor,NEW.target,NEW.kind,c,coalesce(NEW.amount,0),coalesce(NEW.hush,false),NEW.created_at,public.week_key(NEW.created_at))
 ON CONFLICT(source_deed) DO UPDATE SET hush=office_private.action_history.hush OR excluded.hush;
 IF TG_OP='INSERT' AND c IN('help','playful') THEN PERFORM office_private.project_credit(NEW.actor,CASE WHEN c='help' THEN 'care' ELSE 'playful' END); END IF;
 RETURN NEW;
END $$;
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
 'continuous_since',(SELECT continuous_since FROM office_private.history_coverage WHERE id=true),
 'reward_weeks',coalesce((SELECT jsonb_agg(jsonb_build_object('week',r.week,'mine',r.mine,'completed',EXISTS(SELECT 1 FROM office_private.project_completions c WHERE c.week=r.week)) ORDER BY r.week DESC) FROM (SELECT s.week,jsonb_agg(s.category ORDER BY s.category) mine FROM office_private.project_stamps s WHERE s.actor=u GROUP BY s.week) r),'[]'::jsonb),
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
 'period',p_period,'week',w,'since',(SELECT started_at FROM office_private.history_coverage WHERE id=true),'continuous_since',(SELECT continuous_since FROM office_private.history_coverage WHERE id=true),'privacy','Hushed actions are excluded from public charts.',
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
 PERFORM pg_advisory_xact_lock(728194, 1);
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
  AND coalesce(b->>'start',CASE WHEN (b->>'from') ~ '^\d{4}-\d{2}-\d{2}' THEN b->>'from' END,now()::text)::timestamptz<=now()
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

-- @OFFICE_DEPTH@
-- Embedded by build-next-week.py into the held full package, never the live journal.
ALTER TABLE public.players ADD COLUMN office_display jsonb NOT NULL DEFAULT '[]';
ALTER TABLE public.players ADD COLUMN office_memento jsonb;
ALTER TABLE office_private.toolkits ALTER COLUMN charges SET DEFAULT '{"rescue":2,"confetti":2,"filter":2,"clip":2}';
ALTER TABLE office_private.project_completions ADD COLUMN stretch_at timestamptz;
CREATE TABLE office_private.projects(
 week text PRIMARY KEY,theme text NOT NULL,title text NOT NULL,description text NOT NULL,
 categories text[] NOT NULL,goal int NOT NULL DEFAULT 9,minimum_contributors int NOT NULL DEFAULT 3,
 stretch_goal int NOT NULL DEFAULT 15,stretch_contributors int NOT NULL DEFAULT 5,
 starts_at timestamptz NOT NULL,created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE office_private.daily_activity(
 actor uuid NOT NULL,day date NOT NULL,week text NOT NULL,category text NOT NULL,
 PRIMARY KEY(actor,day,category),CHECK(category IN('work','facilities','care','playful'))
);
CREATE INDEX daily_activity_week_actor ON office_private.daily_activity(week,actor);
CREATE TABLE office_private.mementos(
 actor uuid NOT NULL,week text NOT NULL,reward jsonb NOT NULL,stretch boolean NOT NULL DEFAULT false,
 earned_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(actor,week)
);
CREATE TABLE office_private.resupplies(actor uuid NOT NULL,day date NOT NULL,week text NOT NULL,tool text NOT NULL,PRIMARY KEY(actor,day));
CREATE INDEX resupplies_actor_week ON office_private.resupplies(actor,week);
CREATE TABLE office_private.shields(actor uuid NOT NULL,week text NOT NULL,armed boolean NOT NULL DEFAULT false,armed_at timestamptz,PRIMARY KEY(actor,week));
CREATE TABLE office_private.shield_quotes(actor uuid PRIMARY KEY,quote uuid NOT NULL,week text NOT NULL,price float8 NOT NULL,rate float8 NOT NULL,expires_at timestamptz NOT NULL);
CREATE TABLE office_private.weekly_price_peaks(actor uuid NOT NULL,week text NOT NULL,rate float8 NOT NULL CHECK(rate>=0 AND rate<'Infinity'::float8),PRIMARY KEY(actor,week));
CREATE TABLE office_private.reflections(source_deed bigint PRIMARY KEY REFERENCES office_private.action_history(source_deed),defender uuid NOT NULL,sender uuid NOT NULL,kind text NOT NULL,amount float8 NOT NULL DEFAULT 0);
ALTER TABLE office_private.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.daily_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.mementos ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.resupplies ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.shields ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.shield_quotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.weekly_price_peaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.reflections ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA office_private FROM PUBLIC,anon,authenticated;

-- Permanent decor retains a lifetime peak; a weekly consumable retains only its week.
CREATE OR REPLACE FUNCTION office_private.production_peak() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r float8;
BEGIN
 r:=public.calc_rate(NEW);
 IF r::text IN('NaN','Infinity','-Infinity') OR r<0 THEN RAISE EXCEPTION 'invalid production rate'; END IF;
 NEW.cosmetic_rate_peak:=greatest(NEW.cosmetic_rate_peak,CASE WHEN TG_OP='UPDATE' THEN OLD.cosmetic_rate_peak ELSE 0 END,r);
 INSERT INTO office_private.weekly_price_peaks(actor,week,rate) VALUES(NEW.id,public.week_key(),r)
 ON CONFLICT(actor,week) DO UPDATE SET rate=greatest(office_private.weekly_price_peaks.rate,excluded.rate);
 RETURN NEW;
END $$;
CREATE FUNCTION office_private.weekly_price_rate(p public.players) RETURNS float8 LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT greatest(0.25,public.calc_rate(p),coalesce((SELECT rate FROM office_private.weekly_price_peaks WHERE actor=p.id AND week=public.week_key()),0))
$$;

CREATE FUNCTION office_private.ensure_project() RETURNS office_private.projects
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE w text:=public.week_key();c office_private.projects;n int;
BEGIN
 SELECT * INTO c FROM office_private.projects WHERE week=w;
 IF FOUND THEN RETURN c; END IF;
 n:=mod(('x'||substr(md5(w),1,7))::bit(28)::int,4);
 INSERT INTO office_private.projects(week,theme,title,description,categories,starts_at)
 VALUES(w,(ARRAY['breakroom','it','morale','facilities'])[n+1],
 (ARRAY['Break Room Revival','IT Has Opened a Ticket','The Morale Committee','Facilities Inspection'])[n+1],
 (ARRAY['Work, tend the office and help a coworker. The coffee pot has requested standards.','Work, tend the office and try a harmless prank. Ticket priority: inexplicable.','Work, help someone and make the office laugh. Participation is being mistaken for morale.','Tend the office, help someone and try a harmless prank. The clipboard is watching.'])[n+1],
 (CASE n WHEN 0 THEN ARRAY['work','facilities','care'] WHEN 1 THEN ARRAY['work','facilities','playful'] WHEN 2 THEN ARRAY['work','care','playful'] ELSE ARRAY['facilities','care','playful'] END),public.week_started())
 ON CONFLICT(week) DO NOTHING;
 SELECT * INTO c FROM office_private.projects WHERE week=w;
 RETURN c;
END $$;

CREATE OR REPLACE FUNCTION office_private.project_credit(p_actor uuid,p_category text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE w text:=public.week_key();c office_private.projects;n int;people int;done boolean;stretch_done boolean;
BEGIN
 IF p_actor IS NULL OR p_category NOT IN('work','facilities','care','playful') THEN RETURN; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('office-project:'||w,0));
 c:=office_private.ensure_project();
 INSERT INTO office_private.daily_activity(actor,day,week,category) VALUES(p_actor,(now() AT TIME ZONE 'America/Los_Angeles')::date,w,p_category) ON CONFLICT DO NOTHING;
 INSERT INTO office_private.project_stamps(week,actor,category) VALUES(w,p_actor,p_category) ON CONFLICT DO NOTHING;
 SELECT count(*),count(DISTINCT actor) INTO n,people FROM office_private.project_stamps WHERE week=w AND category=ANY(c.categories);
 IF n>=c.goal AND people>=c.minimum_contributors THEN
  INSERT INTO office_private.project_completions(week) VALUES(w) ON CONFLICT DO NOTHING;
 END IF;
 IF n>=c.stretch_goal AND people>=c.stretch_contributors THEN
  UPDATE office_private.project_completions SET stretch_at=coalesce(stretch_at,now()) WHERE week=w;
 END IF;
 SELECT EXISTS(SELECT 1 FROM office_private.project_completions WHERE week=w),EXISTS(SELECT 1 FROM office_private.project_completions WHERE week=w AND stretch_at IS NOT NULL) INTO done,stretch_done;
 IF done THEN
  INSERT INTO office_private.mementos(actor,week,reward,stretch)
  SELECT DISTINCT s.actor,w,jsonb_build_object('title',c.title,'theme',c.theme,'week',w,'starts_at',c.starts_at),stretch_done
  FROM office_private.project_stamps s WHERE s.week=w AND s.category=ANY(c.categories)
  ON CONFLICT(actor,week) DO NOTHING;
  IF stretch_done THEN UPDATE office_private.mementos SET stretch=true WHERE week=w; END IF;
 END IF;
END $$;

-- Only the full installer extends classification. The live journal payload is immutable.
CREATE OR REPLACE FUNCTION office_private.capture_deed() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c text:=CASE WHEN NEW.detail='reflected:shield' THEN 'blocked' ELSE office_private.action_category(NEW.kind,NEW.detail) END;
BEGIN
 INSERT INTO office_private.action_history(source_deed,actor,target,kind,category,amount,hush,happened_at,week)
 VALUES(NEW.id,NEW.actor,NEW.target,NEW.kind,c,coalesce(NEW.amount,0),coalesce(NEW.hush,false),NEW.created_at,public.week_key(NEW.created_at))
 ON CONFLICT(source_deed) DO UPDATE SET hush=office_private.action_history.hush OR excluded.hush;
 IF TG_OP='INSERT' AND c IN('help','playful') THEN PERFORM office_private.project_credit(NEW.actor,CASE WHEN c='help' THEN 'care' ELSE 'playful' END); END IF;
 RETURN NEW;
END $$;

CREATE FUNCTION office_private.collection_progress(p_actor uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 WITH qualified AS(SELECT week FROM office_private.daily_activity WHERE actor=p_actor GROUP BY week HAVING count(DISTINCT day)>=2 AND count(DISTINCT category)>=2 AND bool_or(category='work'))
 SELECT jsonb_build_object('qualified_weeks',count(*),'weeks',coalesce(jsonb_agg(week ORDER BY week),'[]'::jsonb),'requirements',jsonb_build_object('terrarium',2,'duck',4,'lamp',6)) FROM qualified
$$;

CREATE FUNCTION office_private.shield_price(p public.players) RETURNS float8
LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT ceil(2*greatest(60,office_private.weekly_price_rate(p)*1500*coalesce((SELECT max((e.value->>'cost')::float8) FROM public.catalog c,LATERAL jsonb_each(c.data) e WHERE c.key='deeds' AND NOT (e.value->>'good')::boolean AND (e.value?'steal' OR e.value?'heat_to' OR (e.value->>'mult')::float8<1)),1.2)))
$$;

CREATE OR REPLACE FUNCTION public.office_week_status() RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();w text:=public.week_key();today date:=(now() AT TIME ZONE 'America/Los_Angeles')::date;p public.players;k office_private.toolkits;c office_private.projects;result jsonb;progress jsonb;daily text[];n int;people int;used int;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 SELECT * INTO p FROM public.players WHERE id=u;
 IF NOT FOUND THEN RAISE EXCEPTION 'no player'; END IF;
 c:=office_private.ensure_project();progress:=office_private.collection_progress(u);
 SELECT * INTO k FROM office_private.toolkits WHERE actor=u AND week=w;
 SELECT count(*),count(DISTINCT actor) INTO n,people FROM office_private.project_stamps WHERE week=w AND category=ANY(c.categories);
 SELECT coalesce(array_agg(category ORDER BY category),ARRAY[]::text[]) INTO daily FROM office_private.daily_activity WHERE actor=u AND day=today;
 SELECT count(*) INTO used FROM office_private.resupplies WHERE actor=u AND week=w;
 result:=jsonb_build_object('version',1,'depth_version',1,'week',w,'server_now',now(),'starts_at',c.starts_at,
 'project',jsonb_build_object('theme',c.theme,'title',c.title,'description',c.description,'categories',to_jsonb(c.categories),'goal',c.goal,'minimum_contributors',c.minimum_contributors,'total',n,'contributors',people,
 'stretch_goal',c.stretch_goal,'stretch_contributors',c.stretch_contributors,'stretch_completed',EXISTS(SELECT 1 FROM office_private.project_completions WHERE week=w AND stretch_at IS NOT NULL),
 'mine',coalesce((SELECT jsonb_agg(category ORDER BY category) FROM office_private.project_stamps WHERE week=w AND actor=u),'[]'::jsonb),'completed',EXISTS(SELECT 1 FROM office_private.project_completions WHERE week=w)),
 'toolkit',jsonb_build_object('slots',coalesce(k.slots,ARRAY['rescue','confetti']),'charges','{"rescue":2,"confetti":2,"filter":2,"clip":2}'::jsonb||coalesce(k.charges,'{}'::jsonb)),
 'collection',progress||jsonb_build_object('display',p.office_display),
 'scrapbook',coalesce((SELECT jsonb_agg(m.reward||jsonb_build_object('stretch',m.stretch,'selected',p.office_memento->>'week'=m.week) ORDER BY m.week DESC) FROM office_private.mementos m WHERE m.actor=u),'[]'::jsonb),
 'resupply',jsonb_build_object('day',today,'activity',to_jsonb(daily),'used_this_week',used,'weekly_limit',3,'claimed_today',EXISTS(SELECT 1 FROM office_private.resupplies WHERE actor=u AND day=today),'eligible',cardinality(daily)>=2 AND 'work'=ANY(daily) AND used<3 AND NOT EXISTS(SELECT 1 FROM office_private.resupplies WHERE actor=u AND day=today)),
 'shield',jsonb_build_object('armed',coalesce((SELECT armed FROM office_private.shields WHERE actor=u AND week=w),false),'price_hint',office_private.shield_price(p),'price_basis','Twice the highest base sabotage quote; this week''s retained production, no temporary boosts or department discount'),
 'cooldown_until',CASE WHEN p.last_deed IS NULL THEN NULL ELSE p.last_deed+interval '5 minutes'-public.perk_of(p,'silver_tongue')*interval '1 minute' END,
 'collectibles',p.office_collectibles,'confetti',p.office_confetti,
 'history_since',(SELECT started_at FROM office_private.history_coverage WHERE id=true),'continuous_since',(SELECT continuous_since FROM office_private.history_coverage WHERE id=true),
 'reward_weeks',coalesce((SELECT jsonb_agg(jsonb_build_object('week',r.week,'mine',r.mine,'categories',(SELECT to_jsonb(pc.categories) FROM office_private.projects pc WHERE pc.week=r.week),'completed',EXISTS(SELECT 1 FROM office_private.project_completions pc WHERE pc.week=r.week)) ORDER BY r.week DESC) FROM (SELECT s.week,jsonb_agg(s.category ORDER BY s.category) mine FROM office_private.project_stamps s WHERE s.actor=u GROUP BY s.week) r),'[]'::jsonb),
 'completed_weeks',coalesce((SELECT jsonb_agg(pc.week ORDER BY pc.week DESC) FROM office_private.project_completions pc WHERE EXISTS(SELECT 1 FROM office_private.project_stamps s WHERE s.week=pc.week AND s.actor=u)),'[]'::jsonb));
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.office_claim_collectible(p_item text,p_week text) RETURNS public.players LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();p public.players;n int;eligible boolean:=false;required int;
BEGIN
 IF u IS NULL OR p_item IS NULL OR p_week IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 PERFORM pg_advisory_xact_lock(728194,1);
 p:=public.accrue(u);
 IF p IS NULL THEN RAISE EXCEPTION 'no player'; END IF;
 IF p.office_collectibles ? p_item THEN RETURN p; END IF;
 SELECT count(*) INTO n FROM office_private.project_stamps WHERE week=p_week AND actor=u;
 IF p_item='nameplate' THEN eligible:=EXISTS(SELECT 1 FROM office_private.project_stamps WHERE week=p_week AND actor=u AND category='work') AND EXISTS(SELECT 1 FROM office_private.project_stamps WHERE week=p_week AND actor=u AND category='care');
 ELSIF p_item='corkboard' THEN eligible:=n>=3;
 ELSIF p_item='plaque' THEN eligible:=EXISTS(SELECT 1 FROM office_private.project_stamps s JOIN office_private.projects c ON c.week=s.week WHERE s.week=p_week AND s.actor=u AND s.category=ANY(c.categories)) AND EXISTS(SELECT 1 FROM office_private.project_completions WHERE week=p_week);
 ELSIF p_item IN('terrarium','duck','lamp') THEN
  required:=CASE p_item WHEN 'terrarium' THEN 2 WHEN 'duck' THEN 4 ELSE 6 END;
  eligible:=(office_private.collection_progress(u)->>'qualified_weeks')::int>=required;
 ELSE RAISE EXCEPTION 'unknown collectible'; END IF;
 IF NOT eligible THEN RAISE EXCEPTION 'milestone not complete'; END IF;
 UPDATE public.players SET office_collectibles=office_collectibles||to_jsonb(p_item),office_display=CASE WHEN jsonb_array_length(office_display)<3 THEN office_display||to_jsonb(p_item) ELSE office_display END WHERE id=u RETURNING * INTO p;
 RETURN p;
END $$;

CREATE FUNCTION public.office_display_collectibles(p_items text[]) RETURNS public.players LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();p public.players;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 PERFORM pg_advisory_xact_lock(728194,1);
 SELECT * INTO p FROM public.players WHERE id=u FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'no player'; END IF;
 IF p_items IS NULL OR cardinality(p_items)>3 OR (cardinality(p_items)>0 AND array_ndims(p_items)<>1) OR cardinality(p_items)<>(SELECT count(DISTINCT x) FROM unnest(p_items) x) OR EXISTS(SELECT 1 FROM unnest(p_items) x WHERE x IS NULL OR NOT p.office_collectibles?x) THEN RAISE EXCEPTION 'choose up to three owned decorations'; END IF;
 UPDATE public.players SET office_display=to_jsonb(p_items) WHERE id=u RETURNING * INTO p;
 RETURN p;
END $$;

CREATE FUNCTION public.office_display_memento(p_week text) RETURNS public.players LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();p public.players;r jsonb;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 PERFORM pg_advisory_xact_lock(728194,1);
 IF p_week IS NOT NULL THEN
  SELECT reward||jsonb_build_object('stretch',stretch) INTO r FROM office_private.mementos WHERE actor=u AND week=p_week;
  IF NOT FOUND THEN RAISE EXCEPTION 'earn that memento first'; END IF;
 END IF;
 UPDATE public.players SET office_memento=r WHERE id=u RETURNING * INTO p;
 IF NOT FOUND THEN RAISE EXCEPTION 'no player'; END IF;
 RETURN p;
END $$;

CREATE OR REPLACE FUNCTION public.office_equip_tools(p_slots text[]) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();
BEGIN
 IF u IS NULL OR NOT EXISTS(SELECT 1 FROM public.players WHERE id=u) THEN RAISE EXCEPTION 'not signed in'; END IF;
 PERFORM pg_advisory_xact_lock(728194,1);PERFORM public.accrue(u);
 IF p_slots IS NULL OR (cardinality(p_slots)>0 AND array_ndims(p_slots)<>1) OR cardinality(p_slots)>2 OR cardinality(p_slots)<>(SELECT count(DISTINCT x) FROM unnest(p_slots) x)
 OR EXISTS(SELECT 1 FROM unnest(p_slots) x WHERE x NOT IN('rescue','confetti','filter','clip') OR x IS NULL) THEN RAISE EXCEPTION 'choose at most two different tools'; END IF;
 INSERT INTO office_private.toolkits(actor,week,slots) VALUES(u,public.week_key(),p_slots) ON CONFLICT(actor,week) DO UPDATE SET slots=excluded.slots;
 RETURN public.office_week_status();
END $$;

CREATE FUNCTION public.office_resupply(p_tool text,p_request uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();w text;today date:=(now() AT TIME ZONE 'America/Los_Angeles')::date;k office_private.toolkits;r office_private.action_receipts;result jsonb;
BEGIN
 IF u IS NULL OR p_request IS NULL OR p_tool IS NULL OR p_tool NOT IN('rescue','confetti','filter','clip') OR NOT EXISTS(SELECT 1 FROM public.players WHERE id=u) THEN RAISE EXCEPTION 'choose a valid tool'; END IF;
 PERFORM pg_advisory_xact_lock(728194,1);
 SELECT * INTO r FROM office_private.action_receipts WHERE actor=u AND request=p_request;
 IF FOUND THEN IF r.action<>'resupply:'||p_tool OR r.target<>u THEN RAISE EXCEPTION 'request belongs to a different action'; END IF;RETURN r.result; END IF;
 PERFORM public.accrue(u);w:=public.week_key();
 IF EXISTS(SELECT 1 FROM office_private.resupplies WHERE actor=u AND day=today) OR (SELECT count(*) FROM office_private.resupplies WHERE actor=u AND week=w)>=3 THEN RAISE EXCEPTION 'supply limit reached'; END IF;
 IF NOT (SELECT count(*)>=2 AND bool_or(category='work') FROM office_private.daily_activity WHERE actor=u AND day=today) THEN RAISE EXCEPTION 'work plus a different activity earns today''s resupply'; END IF;
 INSERT INTO office_private.toolkits(actor,week) VALUES(u,w) ON CONFLICT DO NOTHING;
 SELECT * INTO k FROM office_private.toolkits WHERE actor=u AND week=w FOR UPDATE;
 IF coalesce((k.charges->>p_tool)::int,2)>=2 THEN RAISE EXCEPTION 'that tool is already full'; END IF;
 UPDATE office_private.toolkits SET charges=jsonb_set(charges,ARRAY[p_tool],to_jsonb((charges->>p_tool)::int+1)) WHERE actor=u AND week=w;
 INSERT INTO office_private.resupplies(actor,day,week,tool) VALUES(u,today,w,p_tool);
 result:=jsonb_build_object('outcome','One charge restored. The supply cupboard approves.','status',public.office_week_status());
 INSERT INTO office_private.action_receipts(actor,request,action,target,result) VALUES(u,p_request,'resupply:'||p_tool,u,result);
 RETURN result;
END $$;

CREATE FUNCTION public.office_shield_quote() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();p public.players;q office_private.shield_quotes;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 SELECT * INTO p FROM public.players WHERE id=u;
 IF NOT FOUND THEN RAISE EXCEPTION 'no player'; END IF;
 q.actor:=u;q.quote:=gen_random_uuid();q.week:=public.week_key();q.price:=office_private.shield_price(p);q.rate:=office_private.weekly_price_rate(p);q.expires_at:=now()+interval '2 minutes';
 IF NOT (q.price>0 AND q.price<'Infinity'::float8) THEN RAISE EXCEPTION 'invalid shield price'; END IF;
 INSERT INTO office_private.shield_quotes(actor,quote,week,price,rate,expires_at) VALUES(q.actor,q.quote,q.week,q.price,q.rate,q.expires_at) ON CONFLICT(actor) DO UPDATE SET quote=excluded.quote,week=excluded.week,price=excluded.price,rate=excluded.rate,expires_at=excluded.expires_at;
 RETURN (to_jsonb(q)-'actor')||jsonb_build_object('server_now',now(),'attack_reference',q.price/2,'basis','This week''s retained base production; excludes temporary bonuses and department discounts');
END $$;

CREATE FUNCTION public.office_buy_shield(p_quote uuid,p_request uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();p public.players;q office_private.shield_quotes;r office_private.action_receipts;result jsonb;w text;
BEGIN
 IF u IS NULL OR p_quote IS NULL OR p_request IS NULL OR NOT EXISTS(SELECT 1 FROM public.players WHERE id=u) THEN RAISE EXCEPTION 'not signed in'; END IF;
 PERFORM pg_advisory_xact_lock(728194,1);
 SELECT * INTO r FROM office_private.action_receipts WHERE actor=u AND request=p_request;
 IF FOUND THEN IF r.action<>'shield:'||p_quote::text OR r.target<>u THEN RAISE EXCEPTION 'request belongs to a different action'; END IF;RETURN r.result; END IF;
 p:=public.accrue(u);w:=public.week_key();
 SELECT * INTO q FROM office_private.shield_quotes WHERE actor=u AND quote=p_quote FOR UPDATE;
 IF NOT FOUND OR q.week<>w OR q.expires_at<=now() OR q.rate<>office_private.weekly_price_rate(p) OR q.price<>office_private.shield_price(p) THEN RAISE EXCEPTION 'shield quote expired or changed; refresh it'; END IF;
 IF EXISTS(SELECT 1 FROM office_private.shields WHERE actor=u AND week=w AND armed) THEN RAISE EXCEPTION 'one shield is already armed'; END IF;
 IF p.pp<q.price THEN RAISE EXCEPTION 'cannot afford this shield'; END IF;
 INSERT INTO office_private.shields(actor,week,armed,armed_at) VALUES(u,w,true,now()) ON CONFLICT(actor,week) DO UPDATE SET armed=true,armed_at=excluded.armed_at;
 UPDATE public.players SET pp=pp-q.price WHERE id=u RETURNING * INTO p;
 result:=jsonb_build_object('outcome','Return to Sender armed. One hostile action will bounce back.','player',to_jsonb(p),'status',public.office_week_status());
 INSERT INTO office_private.action_receipts(actor,request,action,target,result) VALUES(u,p_request,'shield:'||p_quote::text,u,result);
 RETURN result;
END $$;

CREATE FUNCTION office_private.consume_shield(p_target uuid) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE used boolean:=false;
BEGIN
 UPDATE office_private.shields SET armed=false WHERE actor=p_target AND week=public.week_key() AND armed RETURNING true INTO used;
 RETURN coalesce(used,false);
END $$;
CREATE FUNCTION office_private.clip_blocks(p_target uuid) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE used boolean:=false;
BEGIN
 UPDATE office_private.toolkits SET charges=jsonb_set(charges,'{clip}',to_jsonb((charges->>'clip')::int-1)) WHERE actor=p_target AND week=public.week_key() AND 'clip'=ANY(slots) AND (charges->>'clip')::int>0 RETURNING true INTO used;
 RETURN coalesce(used,false);
END $$;

CREATE FUNCTION public.office_deed(p_target uuid,p_kind text,p_request uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();p public.players;r office_private.action_receipts;d public.deeds;result jsonb;before_id bigint;reflected_amount float8;
BEGIN
 IF u IS NULL OR p_request IS NULL OR p_target IS NULL OR p_kind IS NULL OR NOT EXISTS(SELECT 1 FROM public.players WHERE id=u) THEN RAISE EXCEPTION 'not signed in'; END IF;
 PERFORM pg_advisory_xact_lock(728194,1);
 SELECT * INTO r FROM office_private.action_receipts WHERE actor=u AND request=p_request;
 IF FOUND THEN IF r.action<>'deed:'||p_kind OR r.target<>p_target THEN RAISE EXCEPTION 'request belongs to a different action'; END IF;RETURN r.result; END IF;
 SELECT coalesce(max(id),0) INTO before_id FROM public.deeds WHERE actor=u;
 p:=public.do_deed(p_target,p_kind);
 SELECT * INTO d FROM public.deeds WHERE actor=u AND id>before_id ORDER BY id DESC LIMIT 1;
 SELECT amount INTO reflected_amount FROM office_private.reflections WHERE source_deed=d.id;
 result:=jsonb_build_object('player',to_jsonb(p),'reflected',coalesce(d.detail='reflected:shield',false),'detail',d.detail,'amount',coalesce(reflected_amount,d.amount),'outcome',CASE d.detail WHEN 'reflected:shield' THEN 'Return to Sender: your sabotage bounced back onto you.' WHEN 'blocked:filter' THEN 'Their Spam Filter blocked the output penalty.' WHEN 'protected:clip' THEN 'Their Receipt Clip halved the theft.' ELSE NULL END);
 INSERT INTO office_private.action_receipts(actor,request,action,target,result) VALUES(u,p_request,'deed:'||p_kind,p_target,result);
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.office_profile(p_player uuid,p_period text DEFAULT 'week',p_peer uuid DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE w text:=public.week_key();result jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM public.players WHERE id=auth.uid()) THEN RAISE EXCEPTION 'not signed in'; END IF;
 IF p_period IS NULL OR p_period NOT IN('week','lifetime') THEN RAISE EXCEPTION 'invalid period'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.players WHERE id=p_player) THEN RAISE EXCEPTION 'no player'; END IF;
 WITH visible AS(SELECT * FROM office_private.action_history h WHERE NOT hush AND (actor=p_player OR target=p_player) AND (p_period='lifetime' OR week=w) AND (p_peer IS NULL OR actor=p_peer OR target=p_peer)),
 kinds AS(SELECT kind,category,count(*) FILTER(WHERE actor=p_player) given,count(*) FILTER(WHERE target=p_player) received FROM visible GROUP BY kind,category),
 days AS(SELECT (happened_at AT TIME ZONE 'America/Los_Angeles')::date AS day,count(*) FILTER(WHERE actor=p_player) given,count(*) FILTER(WHERE target=p_player) received FROM visible WHERE happened_at>=now()-interval '30 days' GROUP BY 1),
 peers AS(SELECT CASE WHEN actor=p_player THEN target ELSE actor END other,count(*) FILTER(WHERE actor=p_player) given,count(*) FILTER(WHERE target=p_player) received FROM visible GROUP BY 1)
 SELECT jsonb_build_object('player',jsonb_build_object('id',p_player,'name',(SELECT name FROM public.players WHERE id=p_player)),
 'period',p_period,'week',w,'since',(SELECT started_at FROM office_private.history_coverage WHERE id=true),'continuous_since',(SELECT continuous_since FROM office_private.history_coverage WHERE id=true),'privacy','Hushed actions are excluded. Blocked includes reflected attempts; each initiated action is counted once.',
 'by_kind',coalesce((SELECT jsonb_agg(to_jsonb(kinds) ORDER BY kind) FROM kinds),'[]'::jsonb),
 'daily',coalesce((SELECT jsonb_agg(to_jsonb(days) ORDER BY days.day) FROM days),'[]'::jsonb),
 'reflections',(SELECT jsonb_build_object('protected',count(*) FILTER(WHERE r.defender=p_player),'returned_to_sender',count(*) FILTER(WHERE r.sender=p_player)) FROM office_private.reflections r JOIN visible h ON h.source_deed=r.source_deed),
 'coworkers',coalesce((SELECT jsonb_agg(jsonb_build_object('id',other,'name',coalesce(p.name,'Former player'),'given',given,'received',received) ORDER BY given+received DESC) FROM peers LEFT JOIN public.players p ON p.id=other),'[]'::jsonb)) INTO result;
 RETURN result;
END $$;

REVOKE ALL ON FUNCTION public.office_display_collectibles(text[]),public.office_display_memento(text),public.office_resupply(text,uuid),public.office_shield_quote(),public.office_buy_shield(uuid,uuid),public.office_deed(uuid,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.office_display_collectibles(text[]),public.office_display_memento(text),public.office_resupply(text,uuid),public.office_shield_quote(),public.office_buy_shield(uuid,uuid),public.office_deed(uuid,text,uuid) TO authenticated;
-- Perks reset Friday; an output perk must not be sold as a lifetime bonus.
UPDATE public.catalog c SET data=(SELECT jsonb_agg(CASE WHEN x->>'id'='compound' THEN jsonb_set(x,'{note}',to_jsonb('+5% output per level until Friday reset. Spending keeps your earned-Seniority bonus.'::text)) ELSE x END ORDER BY ord) FROM jsonb_array_elements(c.data) WITH ORDINALITY e(x,ord)) WHERE c.key='perks';

-- @END_OFFICE_DEPTH@

-- Everything below patches exact audited bodies; source drift aborts the whole transaction.
-- Filled by tools/build-next-week.py, not dynamic client-controlled SQL.
-- Settle the old earning period under the OLD multiplier before changing Seniority.
-- No sync/accrue/roll_week call: installation cannot trigger a season rollover.
DO $season$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.season_state WHERE id=1 AND current_week=public.week_key())
 THEN RAISE EXCEPTION 'Normal season rollover must finish before installation'; END IF;
END $season$;
WITH settlement AS MATERIALIZED (
 SELECT p.id,CASE WHEN p.last_tick IS NULL OR p.last_tick>=now() THEN 0 ELSE
 public.accrual_interval_gain(p,now()-make_interval(secs=>least(extract(epoch FROM now()-p.last_tick),
 (CASE WHEN p.dept='property' THEN 12 ELSE 8 END+4*public.perk_of(p,'deep_pockets'))*3600)),now()) END gain
 FROM public.players p
)
UPDATE public.players p SET pp=p.pp+s.gain,lifetime=p.lifetime+s.gain,cycle=p.cycle+s.gain,
 week_pp=p.week_pp+s.gain,day_pp=p.day_pp+s.gain,last_tick=now() FROM settlement s WHERE p.id=s.id;
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
END $function$
;
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.roll_week'::regproc))<>'0ecb8583745bf195bdb2dc73cec7fff6' THEN RAISE EXCEPTION 'Audited function drift: roll_week'; END IF; END $guard$;
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
end $function$
;
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.do_deed'::regproc))<>'3990db113fdb087cca7af01ed977496d' THEN RAISE EXCEPTION 'Audited function drift: do_deed'; END IF; END $guard$;
CREATE OR REPLACE FUNCTION public.do_deed(p_target uuid, p_kind text)
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; t players; victim players; d jsonb; price double precision; amt double precision:=0;
 soften double precision; eff double precision; budget double precision; cd interval; beneficiary uuid;
 blocked_by_filter boolean:=false; clipped boolean:=false; reflected boolean:=false; hostile boolean; deed_id bigint; outcome_detail text;
begin
  perform pg_advisory_xact_lock(728194,1);
  if auth.uid() is null or not exists(select 1 from players where id=auth.uid()) then raise exception 'not signed in'; end if;
  p:=accrue(auth.uid());
  if p_target is null or p_kind is null or p_target=p.id then raise exception 'choose a coworker'; end if;
  cd:=interval '5 minutes'-perk_of(p,'silver_tongue')*interval '1 minute';
  if p.last_deed is not null and now()-p.last_deed<cd then raise exception 'cooling off'; end if;
  select data->p_kind into d from catalog where key='deeds';
  if d is null then raise exception 'no such deed'; end if;
  if p_kind='cover' then d:='{"cost":0.05,"good":true,"mins":20,"mult":1.15}'::jsonb; end if;
  if d?'transfer' then raise exception 'cash transfer deeds are retired'; end if;
  t:=accrue(p_target);
  if t is null then raise exception 'no such player'; end if;
  price:=deed_price(p,p_kind);
  if price is null or price<=0 or price>='Infinity'::float8 then raise exception 'invalid deed price'; end if;
  if p.pp<price then raise exception 'cannot afford'; end if;

  hostile:=not coalesce((d->>'good')::boolean,false) and
    ((d?'mult' and (d->>'mult')::float8<1) or (d?'heat_to' and (d->>'heat_to')::int>0) or (d?'steal' and t.pp>0));
  if hostile then reflected:=office_private.consume_shield(t.id); end if;
  victim:=case when reflected then p else t end;
  beneficiary:=case when reflected then t.id else p.id end;
  soften:=greatest(0.2,case when victim.dept='systems' then 0.6 else 1 end*(1-0.25*perk_of(victim,'thick_skin')));

  if d?'steal' then
    -- Reserve the attack price before reflecting. Never credit more than is debited.
    budget:=greatest(0,victim.pp-case when reflected then price else 0 end);
    amt:=least(greatest(20,budget*(d->>'steal')::float8*soften),steal_cap(p),budget);
    if amt>0 and not reflected and office_private.clip_blocks(t.id) then amt:=amt*0.5;clipped:=true;end if;
    update players set pp=pp-amt where id=victim.id;
    update players set pp=pp+amt where id=beneficiary;
  end if;
  if not reflected and d?'mult' and (d->>'mult')::float8<1 and office_private.filter_blocks(t.id) then
    blocked_by_filter:=true;d:=d-'mult';
  end if;
  if p_kind='cover' then
    update players set buffs=coalesce((select jsonb_agg(b) from jsonb_array_elements(t.buffs) b where b->>'kind'<>'cover'),'[]'::jsonb) where id=t.id;
  end if;
  if d?'mult' then
    eff:=(d->>'mult')::float8;
    if eff<1 then eff:=1-(1-eff)*soften; end if;
    update players set buffs=buffs||jsonb_build_object('kind',p_kind,'mult',eff,
      'from_name',case when reflected then t.name||' · Return to Sender' else p.name end,
      'until',now()+((d->>'mins')||' minutes')::interval) where id=victim.id;
  end if;
  if d?'heat_to' then update players set heat=heat+(d->>'heat_to')::int where id=victim.id;end if;
  if (d->>'good')::boolean then update players set kind_received=kind_received+1 where id=t.id;end if;
  outcome_detail:=case when reflected then 'reflected:shield' when blocked_by_filter then 'blocked:filter' when clipped then 'protected:clip' else null end;
  -- One initiated deed. Its original target suffered no debit when reflected.
  insert into deeds(actor,target,kind,amount,detail) values(p.id,t.id,p_kind,case when reflected then 0 else amt end,outcome_detail) returning id into deed_id;
  if reflected then insert into office_private.reflections(source_deed,defender,sender,kind,amount) values(deed_id,t.id,p.id,p_kind,amt);end if;

  update players set pp=pp-price,last_deed=now(),
    goodwill=goodwill+case when (d->>'good')::boolean then 1 else 0 end,
    notoriety=notoriety+case when (d->>'good')::boolean then 0 else 1 end,
    heat=case when p_kind='blame' then case when reflected then (d->>'heat_to')::int else 0 end
              when (d->>'good')::boolean then heat else heat+1 end,
    busted=case when p_kind<>'blame' and not (d->>'good')::boolean and heat+1=5 then busted+1 else busted end,
    tally=jsonb_set(tally,array[p_kind],to_jsonb(coalesce((tally->>p_kind)::int,0)+1),true)
  where id=p.id returning * into p;
  perform bump_today(p.id,case when (d->>'good')::boolean then 'kind' else 'mean' end,1);
  if not (d->>'good')::boolean then perform check_rivalry(p.id,p_target);select * into p from players where id=p.id;end if;
  return p;
end $function$
;
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.dress'::regproc))<>'f49b09daf8daa3931b34e07a43a3f93e' THEN RAISE EXCEPTION 'Audited function drift: dress'; END IF; END $guard$;
CREATE OR REPLACE FUNCTION public.dress(p_target uuid, p_outfit text)
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_variable
declare v_p players; v_t players; v_c jsonb; v_price double precision; v_mine boolean;
begin
  perform pg_advisory_xact_lock(728194, 1);
  v_p := accrue(auth.uid());
  select e into v_c from catalog cat, jsonb_array_elements(cat.data) e
    where cat.key = 'costumes' and e ->> 'id' = p_outfit;
  if v_c is null then raise exception 'no such costume'; end if;

  v_mine := (p_target = v_p.id);
  if not v_mine then
    if v_p.last_deed is not null and now() - v_p.last_deed < (interval '5 minutes' - public.perk_of(v_p, 'silver_tongue') * interval '1 minute')
      then raise exception 'cooling off'; end if;
    v_t := accrue(p_target);
    if v_t is null then raise exception 'no such player'; end if;
    v_p := accrue(auth.uid());        -- re-read: accrue(target) may have moved the clock
  end if;

  -- the same function all_prices() quotes from
  v_price := costume_price(v_p, (v_c ->> 'cost')::double precision)
             * case when v_mine then 1 else 2 end
             * case when v_p.dept = 'contracts' then 0.7 else 1 end;

  if v_p.pp < v_price then
    raise exception 'that costs % and you have %', round(v_price::numeric), round(v_p.pp::numeric);
  end if;

  update players set outfit = jsonb_build_object(
      'id', p_outfit, 'by', v_p.id, 'by_name', case when v_mine then null else v_p.name end,
      'until', now() + ((v_c ->> 'mins') || ' minutes')::interval)
  where id = p_target;

  if v_mine then
    update players set pp = pp - v_price where id = v_p.id returning * into v_p;
  else
    insert into deeds (actor, target, kind, detail) values (v_p.id, p_target, 'dress', p_outfit);
    update players set pp = pp - v_price, last_deed = now(), notoriety = notoriety + 1,
      heat = heat + 1,
      busted = case when heat + 1 = 5 then busted + 1 else busted end,
      tally = jsonb_set(tally, array['dress'],
                to_jsonb(coalesce((tally ->> 'dress')::int, 0) + 1), true)
    where id = v_p.id returning * into v_p;
    perform bump_today(v_p.id, 'dress', 1);
  end if;
  return v_p;
end $function$
;
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.give_nickname'::regproc))<>'6e9f370eef3533c6eb1c0ceae85eb1fb' THEN RAISE EXCEPTION 'Audited function drift: give_nickname'; END IF; END $guard$;
CREATE OR REPLACE FUNCTION public.give_nickname(p_target uuid, p_text text)
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; t players; price double precision; nm text;
begin
  perform pg_advisory_xact_lock(728194, 1);
  p := accrue(auth.uid());
  if p_target = p.id then raise exception 'not to yourself'; end if;
  if p.last_nick is not null and now() - p.last_nick < interval '10 minutes'
    then raise exception 'cooling off'; end if;
  nm := btrim(regexp_replace(coalesce(p_text, ''), '\s+', ' ', 'g'));
  if char_length(nm) < 2 or char_length(nm) > 18 then raise exception 'bad nickname length'; end if;
  if nm !~ '^[A-Za-z0-9 ''\-\.]+$' then raise exception 'letters and numbers only'; end if;
  if not is_clean(nm) then raise exception 'keep it office-safe'; end if;
  t := accrue(p_target);
  if t is null then raise exception 'no such player'; end if;
  price := greatest(100, calc_rate(p) * live_mult(p) * 300);
  if p.pp < price then raise exception 'cannot afford'; end if;

  update players set nickname = jsonb_build_object(
    'text', nm, 'by', p.id, 'by_name', p.name, 'until', now() + interval '60 minutes')
  where id = t.id;
  insert into deeds (actor, target, kind, detail) values (p.id, p_target, 'nickname', nm);
  update players set pp = pp - price, last_nick = now(), notoriety = notoriety + 1,
    tally = jsonb_set(tally, array['nickname'],
              to_jsonb(coalesce((tally ->> 'nickname')::int, 0) + 1), true)
  where id = p.id returning * into p;
  return p;
end $function$
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

-- @END_PATCHES@

DO $costs$ BEGIN
 IF (SELECT jsonb_object_agg(x->>'id',(x->>'cost')::int) FROM public.catalog,jsonb_array_elements(data) x WHERE key='perks') IS DISTINCT FROM '{"deep_pockets":3,"compound":4,"thick_skin":5,"silver_tongue":4,"good_hands":3}'::jsonb
 THEN RAISE EXCEPTION 'Seniority perk costs drifted; review earned-point reconstruction'; END IF;
END $costs$;
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
