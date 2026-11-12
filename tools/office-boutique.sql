-- Added to the held package after the existing office depth fragment.
CREATE TABLE office_private.boutique_quotes(actor uuid PRIMARY KEY,quote uuid NOT NULL,item text NOT NULL,week text NOT NULL,price float8 NOT NULL,rate float8 NOT NULL,expires_at timestamptz NOT NULL);
ALTER TABLE office_private.boutique_quotes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON office_private.boutique_quotes FROM PUBLIC,anon,authenticated;
CREATE FUNCTION office_private.boutique_catalog() RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT '[{"id":"coffee_tech","name":"Emergency Coffee Technician","kind":"clothing","seconds":7200,"minimum":2000,"care_days":3,"weeks":0,"note":"Permanent apron, utility belt and an oversized emergency flask."},{"id":"meeting_survivor","name":"Meeting Survivor","kind":"clothing","seconds":28800,"minimum":8500,"care_days":0,"weeks":2,"note":"Rolled sleeves, a loosened tie and evidence of several meetings."},{"id":"theme_facilities","name":"Facilities Desk Set","kind":"desk","seconds":7200,"minimum":2000,"care_days":0,"weeks":0,"note":"Sage work mat, miniature tool caddy and a suspiciously clean checklist."},{"id":"theme_accounting","name":"Accounting Desk Set","kind":"desk","seconds":43200,"minimum":12000,"care_days":0,"weeks":0,"note":"Premium ledger mat, calculator and a very serious brass pen cup."},{"id":"theme_it","name":"IT Desk Set","kind":"desk","seconds":14400,"minimum":4000,"care_days":0,"weeks":1,"note":"Cubicle-blue circuit mat, miniature server and a cable that goes nowhere."},{"id":"theme_chaos","name":"Office Chaos Desk Set","kind":"desk","seconds":28800,"minimum":8500,"care_days":0,"weeks":3,"note":"Sticky-note mat, runaway paperwork and a tiny controlled incident."}]'::jsonb
$$;
CREATE FUNCTION office_private.boutique_eligibility(p_actor uuid,item jsonb) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT (SELECT count(DISTINCT day) FROM office_private.daily_activity WHERE actor=p_actor AND category='care')>=coalesce((item->>'care_days')::int,0)
 AND (office_private.collection_progress(p_actor)->>'qualified_weeks')::int>=coalesce((item->>'weeks')::int,0)
$$;
CREATE FUNCTION public.office_shop_state() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.players;items jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 SELECT * INTO p FROM public.players WHERE id=auth.uid();IF NOT FOUND THEN RAISE EXCEPTION 'no player';END IF;
 SELECT jsonb_agg(i||jsonb_build_object('eligible',office_private.boutique_eligibility(p.id,i),'owned',CASE WHEN i->>'kind'='clothing' THEN p.wardrobe_owned? (i->>'id') ELSE p.office_collectibles? (i->>'id') END,
 'price_hint',ceil(greatest((i->>'minimum')::float8,public.permanent_price_rate(p)*(i->>'seconds')::float8)))) INTO items FROM jsonb_array_elements(office_private.boutique_catalog()) i;
 RETURN jsonb_build_object('version',1,'server_now',now(),'week',public.week_key(),'items',items,'care_days',(SELECT count(DISTINCT day) FROM office_private.daily_activity WHERE actor=p.id AND category='care'),'qualified_weeks',(office_private.collection_progress(p.id)->>'qualified_weeks')::int);
END $$;
CREATE FUNCTION public.office_shop_quote(p_item text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.players;i jsonb;q office_private.boutique_quotes;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 SELECT * INTO p FROM public.players WHERE id=auth.uid();IF NOT FOUND THEN RAISE EXCEPTION 'no player';END IF;
 SELECT x INTO i FROM jsonb_array_elements(office_private.boutique_catalog()) x WHERE x->>'id'=p_item;IF NOT FOUND THEN RAISE EXCEPTION 'unknown shop item';END IF;
 IF NOT office_private.boutique_eligibility(p.id,i) THEN RAISE EXCEPTION 'participation requirement not complete';END IF;
 q.actor:=p.id;q.quote:=gen_random_uuid();q.item:=p_item;q.week:=public.week_key();q.rate:=public.permanent_price_rate(p);q.price:=ceil(greatest((i->>'minimum')::float8,q.rate*(i->>'seconds')::float8));q.expires_at:=now()+interval '2 minutes';
 IF NOT (q.price>0 AND q.price<'Infinity'::float8) THEN RAISE EXCEPTION 'invalid item price';END IF;
 INSERT INTO office_private.boutique_quotes VALUES(q.actor,q.quote,q.item,q.week,q.price,q.rate,q.expires_at) ON CONFLICT(actor) DO UPDATE SET quote=excluded.quote,item=excluded.item,week=excluded.week,price=excluded.price,rate=excluded.rate,expires_at=excluded.expires_at;
 RETURN (to_jsonb(q)-'actor')||jsonb_build_object('server_now',now(),'name',i->>'name','basis','Permanent base-production benchmark; temporary boosts and restructuring do not discount it');
END $$;
CREATE FUNCTION public.office_shop_buy(p_quote uuid,p_request uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();p public.players;q office_private.boutique_quotes;i jsonb;r office_private.action_receipts;result jsonb;
BEGIN
 IF u IS NULL OR p_quote IS NULL OR p_request IS NULL THEN RAISE EXCEPTION 'not signed in';END IF;
 PERFORM pg_advisory_xact_lock(728194,1);
 SELECT * INTO r FROM office_private.action_receipts WHERE actor=u AND request=p_request;
 IF FOUND THEN IF r.action<>'shop:'||p_quote::text OR r.target<>u THEN RAISE EXCEPTION 'request belongs to a different action';END IF;RETURN r.result;END IF;
 p:=public.accrue(u);IF p IS NULL THEN RAISE EXCEPTION 'no player';END IF;
 SELECT * INTO q FROM office_private.boutique_quotes WHERE actor=u AND quote=p_quote FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'review a current item price';END IF;
 SELECT x INTO i FROM jsonb_array_elements(office_private.boutique_catalog()) x WHERE x->>'id'=q.item;
 IF q.expires_at<=now() OR q.week<>public.week_key() OR q.rate<>public.permanent_price_rate(p)
 OR q.price<>ceil(greatest((i->>'minimum')::float8,public.permanent_price_rate(p)*(i->>'seconds')::float8)) THEN RAISE EXCEPTION 'item quote changed or expired; review a fresh price';END IF;
 IF NOT office_private.boutique_eligibility(u,i) THEN RAISE EXCEPTION 'participation requirement not complete';END IF;
 IF (i->>'kind'='clothing' AND p.wardrobe_owned?q.item) OR (i->>'kind'='desk' AND p.office_collectibles?q.item) THEN RAISE EXCEPTION 'already owned';END IF;
 IF p.pp<q.price THEN RAISE EXCEPTION 'not enough busywork';END IF;
 UPDATE public.players SET pp=pp-q.price,spent=spent+q.price,
 wardrobe_owned=CASE WHEN i->>'kind'='clothing' THEN wardrobe_owned||to_jsonb(q.item) ELSE wardrobe_owned END,
 office_collectibles=CASE WHEN i->>'kind'='desk' THEN office_collectibles||to_jsonb(q.item) ELSE office_collectibles END,
 office_display=CASE WHEN i->>'kind'='desk' AND jsonb_array_length(office_display)<3 THEN office_display||to_jsonb(q.item) ELSE office_display END
 WHERE id=u RETURNING * INTO p;
 result:=jsonb_build_object('player',to_jsonb(p),'outcome',(i->>'name')||' purchased. Permanent, cosmetic and deeply unofficial.');
 INSERT INTO office_private.action_receipts(actor,request,action,target,result) VALUES(u,p_request,'shop:'||p_quote::text,u,result);
 RETURN result;
END $$;
CREATE FUNCTION public.office_recordbook(p_week text DEFAULT NULL,p_player uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();chosen text;subject uuid:=coalesce(p_player,auth.uid());result jsonb;
BEGIN
 IF u IS NULL OR NOT EXISTS(SELECT 1 FROM public.players WHERE id=u) THEN RAISE EXCEPTION 'not signed in';END IF;
 chosen:=coalesce(p_week,(SELECT week FROM office_private.season_records ORDER BY closed_at DESC,week DESC LIMIT 1));
 IF p_week IS NOT NULL AND NOT EXISTS(SELECT 1 FROM office_private.season_records WHERE week=p_week) THEN RAISE EXCEPTION 'no recorded season';END IF;
 WITH award_counts AS(SELECT h.category,h.actor,count(*) actions FROM office_private.action_history h WHERE h.week=chosen AND NOT h.hush AND h.category IN('help','playful','sabotage') GROUP BY h.category,h.actor),
 ranked_awards AS(SELECT *,rank() OVER(PARTITION BY category ORDER BY actions DESC) position FROM award_counts)
 SELECT jsonb_build_object('version',1,'selected_week',chosen,
 'seasons',coalesce((SELECT jsonb_agg(to_jsonb(s) ORDER BY closed_at DESC,week DESC) FROM (SELECT week,closed_at,winner_name,top,coverage FROM office_private.season_records ORDER BY closed_at DESC,week DESC LIMIT 104) s),'[]'::jsonb),
 'season',(SELECT to_jsonb(s)-'captured_at' FROM office_private.season_records s WHERE week=chosen),
 'standings',coalesce((SELECT jsonb_agg(to_jsonb(s) ORDER BY place,name,player) FROM office_private.season_results s WHERE week=chosen),'[]'::jsonb),
 'personal_best',(SELECT to_jsonb(s) FROM office_private.season_results s WHERE player=subject ORDER BY earnings DESC,week DESC LIMIT 1),
 'awards',coalesce((SELECT jsonb_agg(jsonb_build_object('category',a.category,'player',a.actor,'name',coalesce(s.name,p.name,'Former player'),'actions',a.actions) ORDER BY a.category,a.actor) FROM ranked_awards a LEFT JOIN office_private.season_results s ON s.week=chosen AND s.player=a.actor LEFT JOIN public.players p ON p.id=a.actor WHERE a.position=1),'[]'::jsonb),
 'note','Standings preserve the game-recorded weekly earnings at normal rollover, not a reconstructed earnings timeline. Tied earnings share a place. Older winner-only records do not contain full standings. Awards use retained public actions and may be incomplete for older weeks.') INTO result;
 RETURN result;
END $$;
-- Catalogue-only additions: the existing dress RPC retains its price, cooldown,
-- duration, heat, commit bonus, target validation and history behavior.
DO $$ BEGIN IF (SELECT md5(data::text) FROM public.catalog WHERE key='costumes') IS DISTINCT FROM 'f019e5276e00dc418f1684a6fb351324' THEN RAISE EXCEPTION 'costume catalogue drift; review before extending';END IF;END $$;
UPDATE public.catalog SET data=data||'[{"id":"budget_wizard","name":"Budget Wizard","cost":0.025,"kind":"body","mins":45},{"id":"filing_cabinet","name":"Walking Filing Cabinet","cost":0.04,"kind":"body","mins":45}]'::jsonb WHERE key='costumes';
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA office_private FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.office_shop_state(),public.office_shop_quote(text),public.office_shop_buy(uuid,uuid),public.office_recordbook(text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.office_shop_state(),public.office_shop_quote(text),public.office_shop_buy(uuid,uuid),public.office_recordbook(text,uuid) TO authenticated;
