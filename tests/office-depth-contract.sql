\set ON_ERROR_STOP on
-- Run after next-week-contract.sql; actual held RPCs, disposable database only.
DO $$ BEGIN IF current_database()<>'idle_hands_test' THEN RAISE EXCEPTION 'isolated test DB required'; END IF; END $$;
BEGIN;
DO $depth$
DECLARE
 a uuid:='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';b uuid:='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';c uuid:='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
 d uuid:='dddddddd-dddd-4ddd-8ddd-dddddddddddd';e uuid:='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
 p public.players;t public.players;cfg office_private.projects;q jsonb;r jsonb;r2 jsonb;req uuid;quote_id uuid;deed_id bigint;
 before_a float8;before_b float8;price float8;total float8;n int;rejected boolean;w text:=public.week_key();i int;day1 date;week1 text;eligible text;excluded text;
BEGIN
 PERFORM set_config('request.jwt.claim.sub',b::text,true);
 IF EXISTS(SELECT 1 FROM public.catalog,LATERAL jsonb_array_elements(data) x WHERE key='perks' AND x->>'id'='compound' AND x->>'note' NOT LIKE '%Friday reset%') THEN RAISE EXCEPTION 'weekly perk sold as permanent';END IF;
 UPDATE public.players SET pp=1e6,last_deed=null,buffs='[]',perks='{}',heat=0;
 cfg:=office_private.ensure_project();r:=public.office_week_status();
 IF r#>>'{project,goal}'<>'9' OR cardinality(cfg.categories)<>3 OR r#>>'{project,stretch_goal}'<>'15' THEN RAISE EXCEPTION 'project configuration missing';END IF;
 IF EXISTS(SELECT 1 FROM office_private.mementos) OR EXISTS(SELECT 1 FROM office_private.daily_activity) THEN RAISE EXCEPTION 'history backfill awarded retrospective goals';END IF;
 q:=public.office_shield_quote();quote_id:=(q->>'quote')::uuid;price:=(q->>'price')::float8;req:=gen_random_uuid();
 IF price<120 OR price<>2*(q->>'attack_reference')::float8 THEN RAISE EXCEPTION 'shield price not above reference attack';END IF;
 SELECT pp INTO before_b FROM public.players WHERE id=b;
 r:=public.office_buy_shield(quote_id,req);r2:=public.office_buy_shield(quote_id,req);
 IF r<>r2 OR (SELECT pp FROM public.players WHERE id=b)<>before_b-price OR NOT EXISTS(SELECT 1 FROM office_private.shields WHERE actor=b AND week=w AND armed) THEN RAISE EXCEPTION 'duplicate shield charged or armed twice';END IF;
 rejected:=false;BEGIN PERFORM public.office_buy_shield(gen_random_uuid(),req);EXCEPTION WHEN others THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'shield nonce rebound';END IF;
 q:=public.office_shield_quote();rejected:=false;BEGIN PERFORM public.office_buy_shield((q->>'quote')::uuid,gen_random_uuid());EXCEPTION WHEN others THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'shield stockpile permitted';END IF;
 PERFORM public.office_equip_tools(ARRAY['filter','clip']);

 -- Reflection wins before active defenses; passive protection applies to the sender.
 PERFORM set_config('request.jwt.claim.sub',a::text,true);
 q:=public.office_shield_quote();PERFORM public.office_buy_shield((q->>'quote')::uuid,gen_random_uuid());
 UPDATE public.players SET dept='systems',perks='{"thick_skin":2}',last_deed=null WHERE id=a;
 req:=gen_random_uuid();SELECT count(*) INTO n FROM public.deeds;
 r:=public.office_deed(b,'replyall',req);r2:=public.office_deed(b,'replyall',req);
 IF r<>r2 OR r->>'reflected'<>'true' OR (SELECT count(*) FROM public.deeds)<>n+1 THEN RAISE EXCEPTION 'reflected deed replay duplicated';END IF;
 IF NOT EXISTS(SELECT 1 FROM office_private.shields WHERE actor=a AND week=w AND armed) OR EXISTS(SELECT 1 FROM office_private.shields WHERE actor=b AND week=w AND armed) THEN RAISE EXCEPTION 'reflection chain or charge consumption wrong';END IF;
 IF (SELECT jsonb_array_length(buffs) FROM public.players WHERE id=b)<>0 OR abs((SELECT (buffs->0->>'mult')::float8 FROM public.players WHERE id=a)-0.835)>1e-9 THEN RAISE EXCEPTION 'reflected effect ignored sender passive defenses';END IF;
 IF (SELECT charges->>'filter' FROM office_private.toolkits WHERE actor=b AND week=w)<>'2' OR (SELECT charges->>'clip' FROM office_private.toolkits WHERE actor=b AND week=w)<>'2' THEN RAISE EXCEPTION 'reflection consumed another active defense';END IF;
 SELECT max(id) INTO deed_id FROM public.deeds WHERE actor=a;
 IF NOT EXISTS(SELECT 1 FROM office_private.action_history WHERE source_deed=deed_id AND category='blocked' AND amount=0) THEN RAISE EXCEPTION 'reflection falsely counted as successful harm';END IF;
 r:=public.office_profile(b,'lifetime',a);IF r#>>'{reflections,protected}'<>'1' THEN RAISE EXCEPTION 'reflection chart missing';END IF;
 UPDATE public.deeds SET hush=true WHERE id=deed_id;
 r:=public.office_profile(b,'lifetime',a);IF r#>>'{reflections,protected}'<>'0' THEN RAISE EXCEPTION 'hushed reflection leaked';END IF;

 -- Existing repeated sabotage still stacks. No same-kind refresh/cap was added.
 UPDATE public.players SET last_deed=null WHERE id=a;PERFORM public.do_deed(c,'replyall');
 UPDATE public.players SET last_deed=null WHERE id=a;PERFORM public.do_deed(c,'replyall');
 IF (SELECT jsonb_array_length(buffs) FROM public.players WHERE id=c)<>2 THEN RAISE EXCEPTION 'stacking strategy changed';END IF;

 UPDATE office_private.shields SET armed=true WHERE actor=b AND week=w;
 UPDATE public.players SET last_deed=null,heat=4 WHERE id=a;
 UPDATE public.players SET heat=2 WHERE id=b;
 r:=public.office_deed(b,'blame',gen_random_uuid());
 IF (SELECT heat FROM public.players WHERE id=a)<>3 OR (SELECT heat FROM public.players WHERE id=b)<>2 THEN RAISE EXCEPTION 'blame reflection erased returned heat or harmed shield owner';END IF;

 -- Reflected theft reserves the attack cost and transfers only the actual balance.
 UPDATE office_private.shields SET armed=true WHERE actor=b AND week=w;
 UPDATE public.players SET pp=1e6,last_deed=null WHERE id=a;
 SELECT * INTO p FROM public.players WHERE id=a;price:=public.deed_price(p,'credit');
 UPDATE public.players SET pp=price+17 WHERE id=a;
 SELECT pp INTO before_b FROM public.players WHERE id=b;total:=price+17+before_b;
 r:=public.office_deed(b,'credit',gen_random_uuid());
 IF abs((SELECT pp FROM public.players WHERE id=a))>1e-6 OR abs((SELECT pp FROM public.players WHERE id=b)-before_b-17)>1e-6 OR (r->>'amount')::float8<>17 THEN RAISE EXCEPTION 'reflected theft minted funds or spent reserved attack price';END IF;
 IF abs((SELECT sum(pp) FROM public.players WHERE id IN(a,b))-(total-price))>1e-6 THEN RAISE EXCEPTION 'reflected money not conserved';END IF;

 -- Ordinary theft also has to transfer actual debit, including balances below 20.
 UPDATE public.players SET pp=1e6,last_deed=null WHERE id=a;
 UPDATE public.players SET pp=5 WHERE id=b;
 UPDATE office_private.toolkits SET slots=ARRAY[]::text[] WHERE actor=b AND week=w;
 SELECT * INTO p FROM public.players WHERE id=a;price:=public.deed_price(p,'credit');
 r:=public.office_deed(b,'credit',gen_random_uuid());
 IF (r->>'amount')::float8<>5 OR (SELECT pp FROM public.players WHERE id=b)<>0 OR abs((SELECT pp FROM public.players WHERE id=a)-(1e6-price+5))>1e-6 THEN RAISE EXCEPTION 'small-balance theft minted money';END IF;
 UPDATE office_private.shields SET armed=true WHERE actor=b AND week=w;
 UPDATE public.players SET last_deed=null WHERE id=a;
 PERFORM public.office_deed(b,'credit',gen_random_uuid());
 IF NOT EXISTS(SELECT 1 FROM office_private.shields WHERE actor=b AND week=w AND armed) THEN RAISE EXCEPTION 'empty theft consumed shield';END IF;

 -- Clip competes for two slots and only consumes a positive eligible theft.
 UPDATE office_private.shields SET armed=false WHERE actor=b AND week=w;
 PERFORM set_config('request.jwt.claim.sub',b::text,true);PERFORM public.office_equip_tools(ARRAY['filter','clip']);
 PERFORM set_config('request.jwt.claim.sub',a::text,true);
 UPDATE public.players SET last_deed=null WHERE id=a;UPDATE public.players SET pp=1000 WHERE id=b;
 r:=public.office_deed(b,'credit',gen_random_uuid());
 IF (r->>'amount')::float8<>60 OR (SELECT pp FROM public.players WHERE id=b)<>940 OR (SELECT charges->>'clip' FROM office_private.toolkits WHERE actor=b AND week=w)<>'1' THEN RAISE EXCEPTION 'clip did not halve actual theft once';END IF;
 UPDATE public.players SET last_deed=null WHERE id=a;UPDATE public.players SET pp=0 WHERE id=b;
 PERFORM public.office_deed(b,'credit',gen_random_uuid());
 IF (SELECT charges->>'clip' FROM office_private.toolkits WHERE actor=b AND week=w)<>'1' THEN RAISE EXCEPTION 'zero debit consumed clip';END IF;

 -- Rejected/expired and changed benchmark quotes do not charge or arm.
 PERFORM set_config('request.jwt.claim.sub',b::text,true);UPDATE public.players SET pp=1e6 WHERE id=b;
 q:=public.office_shield_quote();UPDATE office_private.shield_quotes SET expires_at=now()-interval '1 second' WHERE actor=b;
 rejected:=false;BEGIN PERFORM public.office_buy_shield((q->>'quote')::uuid,gen_random_uuid());EXCEPTION WHEN others THEN rejected:=true;END;
 IF NOT rejected OR (SELECT pp FROM public.players WHERE id=b)<>1e6 THEN RAISE EXCEPTION 'expired quote charged';END IF;
 q:=public.office_shield_quote();UPDATE public.players SET owned='{"intern":100}' WHERE id=b;
 rejected:=false;BEGIN PERFORM public.office_buy_shield((q->>'quote')::uuid,gen_random_uuid());EXCEPTION WHEN others THEN rejected:=true;END;
 IF NOT rejected OR (SELECT pp FROM public.players WHERE id=b)<>1e6 THEN RAISE EXCEPTION 'changed benchmark quote charged';END IF;
 q:=public.office_shield_quote();UPDATE public.players SET buffs='[{"kind":"meeting","mult":0.1}]' WHERE id=b;
 IF (public.office_shield_quote()->>'price')::float8<>(q->>'price')::float8 THEN RAISE EXCEPTION 'temporary sabotage discounted shield';END IF;
 UPDATE public.players SET buffs='[]',owned='{}' WHERE id=b;
 IF (public.office_shield_quote()->>'price')::float8<>(q->>'price')::float8 THEN RAISE EXCEPTION 'restructure-sized production drop discounted shield';END IF;

 -- Work + a different category; one daily and three weekly restoration claims.
 PERFORM set_config('request.jwt.claim.sub',a::text,true);
 PERFORM public.office_equip_tools(ARRAY['rescue','confetti']);
 UPDATE office_private.toolkits SET charges=jsonb_set(charges,'{confetti}','1') WHERE actor=a AND week=w;
 rejected:=false;BEGIN PERFORM public.office_resupply('confetti',gen_random_uuid());EXCEPTION WHEN others THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'resupply without work/activity';END IF;
 PERFORM office_private.project_credit(a,'work');PERFORM office_private.project_credit(a,'facilities');
 req:=gen_random_uuid();r:=public.office_resupply('confetti',req);r2:=public.office_resupply('confetti',req);
 IF r<>r2 OR (SELECT charges->>'confetti' FROM office_private.toolkits WHERE actor=a AND week=w)<>'2' OR (SELECT count(*) FROM office_private.resupplies WHERE actor=a)<>1 THEN RAISE EXCEPTION 'resupply replay duplicated';END IF;
 UPDATE office_private.toolkits SET charges=jsonb_set(charges,'{rescue}','1') WHERE actor=a AND week=w;
 rejected:=false;BEGIN PERFORM public.office_resupply('rescue',gen_random_uuid());EXCEPTION WHEN others THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'daily supply cap bypassed';END IF;
 rejected:=false;BEGIN PERFORM public.office_resupply('rescue',req);EXCEPTION WHEN others THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'supply receipt rebound';END IF;
 DELETE FROM office_private.resupplies WHERE actor=a;
 INSERT INTO office_private.resupplies SELECT a,(now() AT TIME ZONE 'America/Los_Angeles')::date-g,w,'confetti' FROM generate_series(1,3) g;
 rejected:=false;BEGIN PERFORM public.office_resupply('rescue',gen_random_uuid());EXCEPTION WHEN others THEN rejected:=true;END;
 IF NOT rejected OR (SELECT charges->>'rescue' FROM office_private.toolkits WHERE actor=a AND week=w)<>'1' THEN RAISE EXCEPTION 'weekly supply cap bypassed';END IF;

 -- No consecutive-week requirement; paid wealth cannot skip the collection ladder.
 DELETE FROM office_private.daily_activity WHERE actor=a;
 FOR i IN 0..5 LOOP
  day1:=((public.week_started()-make_interval(weeks=>i)+interval '2 hours') AT TIME ZONE 'America/Los_Angeles')::date;
  week1:=public.week_key(public.week_started()-make_interval(weeks=>i));
  INSERT INTO office_private.daily_activity(actor,day,week,category) VALUES(a,day1,week1,'work'),(a,day1+1,week1,'facilities');
  IF i=0 THEN
   rejected:=false;BEGIN PERFORM public.office_claim_collectible('terrarium',w);EXCEPTION WHEN others THEN rejected:=true;END;
   IF NOT rejected THEN RAISE EXCEPTION 'one week skipped ladder';END IF;
  ELSIF i=1 THEN p:=public.office_claim_collectible('terrarium',w);
  ELSIF i=3 THEN p:=public.office_claim_collectible('duck',w);
  ELSIF i=5 THEN p:=public.office_claim_collectible('lamp',w);END IF;
 END LOOP;
 IF jsonb_array_length(p.office_collectibles)<>3 OR (office_private.collection_progress(a)->>'qualified_weeks')::int<>6 THEN RAISE EXCEPTION 'persistent ladder wrong';END IF;
 FOR t IN SELECT * FROM public.players LOOP
  PERFORM office_private.project_credit(t.id,'work');PERFORM office_private.project_credit(t.id,'facilities');PERFORM office_private.project_credit(t.id,'care');PERFORM office_private.project_credit(t.id,'playful');
 END LOOP;
 IF (SELECT count(*) FROM office_private.mementos WHERE week=w)<>3 THEN RAISE EXCEPTION 'base project missing dated mementos';END IF;
 p:=public.office_claim_collectible('nameplate',w);p:=public.office_claim_collectible('corkboard',w);p:=public.office_claim_collectible('plaque',w);
 IF jsonb_array_length(p.office_collectibles)<>6 OR jsonb_array_length(p.office_display)<>3 THEN RAISE EXCEPTION 'starter collection lost or desk overfilled';END IF;
 p:=public.office_display_collectibles(ARRAY['lamp','nameplate','duck']);
 rejected:=false;BEGIN PERFORM public.office_display_collectibles(ARRAY['lamp','nameplate','duck','plaque']);EXCEPTION WHEN others THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'desk display exceeds three';END IF;
 p:=public.office_display_memento(w);
 IF p.office_memento->>'title'<>cfg.title THEN RAISE EXCEPTION 'dated display wrong';END IF;
 INSERT INTO public.players(id,name,pp) VALUES(d,'Fixture D',1000),(e,'Fixture E',1000);
 SELECT x INTO excluded FROM unnest(ARRAY['work','facilities','care','playful']) x WHERE NOT x=ANY(cfg.categories);
 PERFORM office_private.project_credit(d,excluded);
 IF EXISTS(SELECT 1 FROM office_private.mementos WHERE actor=d) THEN RAISE EXCEPTION 'off-theme late contribution got memento';END IF;
 PERFORM office_private.project_credit(d,cfg.categories[1]);
 IF NOT EXISTS(SELECT 1 FROM office_private.mementos WHERE actor=d AND week=w) THEN RAISE EXCEPTION 'late contributor lost completed project reward';END IF;
 FOR t IN SELECT * FROM public.players LOOP
  FOREACH eligible IN ARRAY cfg.categories LOOP PERFORM office_private.project_credit(t.id,eligible);END LOOP;
 END LOOP;
 IF (SELECT count(*) FROM office_private.mementos WHERE week=w AND stretch)<>5 THEN RAISE EXCEPTION 'stretch completion or late award wrong';END IF;
 UPDATE office_private.projects SET title='A later template edit' WHERE week=w;
 IF (SELECT reward->>'title' FROM office_private.mementos WHERE actor=a AND week=w)<>cfg.title THEN RAISE EXCEPTION 'historical memento recomputed';END IF;

 -- Normal weekly state expires by key; lifetime earning/display history survives wipes.
 INSERT INTO office_private.shields(actor,week,armed) VALUES(a,'previous-fixture-week',true) ON CONFLICT DO NOTHING;
 UPDATE office_private.shields SET armed=false WHERE actor=a AND week=w;
 r:=public.office_week_status();IF r#>>'{shield,armed}'<>'false' THEN RAISE EXCEPTION 'old-week shield leaked';END IF;
 PERFORM public.season_wipe();SELECT * INTO p FROM public.players WHERE id=a;
 IF jsonb_array_length(p.office_collectibles)<>6 OR jsonb_array_length(p.office_display)<>3 OR p.office_memento->>'week'<>w OR (office_private.collection_progress(a)->>'qualified_weeks')::int<>6 THEN RAISE EXCEPTION 'reset erased permanent progression';END IF;
 IF has_function_privilege('anon','public.office_buy_shield(uuid,uuid)','EXECUTE') OR has_function_privilege('authenticated','office_private.consume_shield(uuid)','EXECUTE') OR has_table_privilege('authenticated','office_private.reflections','SELECT') THEN RAISE EXCEPTION 'unsafe depth grants';END IF;
 RAISE NOTICE 'PASS office depth: frozen themed projects, late/stretch mementos, multi-week ladder, supply caps, quote/payment replay, passive reflection, no loops, heat, stacking, conservation, privacy and reset persistence';
END $depth$;
ROLLBACK;
