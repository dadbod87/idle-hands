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
