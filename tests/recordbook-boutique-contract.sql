\set ON_ERROR_STOP on
DO $$ BEGIN IF current_database()<>'idle_hands_test' THEN RAISE EXCEPTION 'isolated test DB required';END IF; END $$;
\i tests/fixtures/appearance-baseline.sql
\i tests/fixtures/costume-price-baseline.sql
BEGIN;
DO $pack$
DECLARE a uuid:='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';b uuid:='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';c uuid:='cccccccc-cccc-4ccc-8ccc-cccccccccccc';p public.players;q jsonb;r jsonb;r2 jsonb;before_pp float8;price float8;req uuid;rejected boolean;w text:=public.week_key();closing text:=public.week_key(now()-interval '7 days');i int;old_week text;
BEGIN
 PERFORM set_config('request.jwt.claim.sub',a::text,true);
 UPDATE public.players SET pp=1e20,owned='{}',last_tick=now(),last_deed=null,buffs='[]',dept=null;
 IF jsonb_array_length(public.office_shop_state()->'items')<>6 OR jsonb_array_length((SELECT data FROM public.catalog WHERE key='costumes'))<>13 THEN RAISE EXCEPTION 'pack catalogue incomplete';END IF;
 rejected:=false;BEGIN PERFORM public.office_shop_quote('coffee_tech');EXCEPTION WHEN others THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'helping requirement bypassed';END IF;
 rejected:=false;BEGIN PERFORM public.office_shop_quote('theme_chaos');EXCEPTION WHEN others THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'weeks requirement bypassed';END IF;
 rejected:=false;BEGIN PERFORM public.office_shop_quote('forged');EXCEPTION WHEN others THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'unknown item accepted';END IF;
 q:=public.office_shop_quote('theme_facilities');price:=(q->>'price')::float8;SELECT pp INTO before_pp FROM public.players WHERE id=a;req:=gen_random_uuid();
 r:=public.office_shop_buy((q->>'quote')::uuid,req);r2:=public.office_shop_buy((q->>'quote')::uuid,req);
 IF r<>r2 OR (SELECT pp FROM public.players WHERE id=a)<>before_pp-price OR NOT (SELECT office_collectibles?'theme_facilities' FROM public.players WHERE id=a) THEN RAISE EXCEPTION 'quote/payment/receipt mismatch';END IF;
 rejected:=false;BEGIN PERFORM public.office_shop_buy(gen_random_uuid(),req);EXCEPTION WHEN others THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'shop nonce rebound';END IF;
 rejected:=false;BEGIN PERFORM public.office_shop_buy((q->>'quote')::uuid,gen_random_uuid());EXCEPTION WHEN others THEN rejected:=true;END;
 IF NOT rejected OR (SELECT pp FROM public.players WHERE id=a)<>before_pp-price THEN RAISE EXCEPTION 'duplicate owned item charged';END IF;
 q:=public.office_shop_quote('theme_accounting');PERFORM set_config('request.jwt.claim.sub',b::text,true);
 rejected:=false;BEGIN PERFORM public.office_shop_buy((q->>'quote')::uuid,gen_random_uuid());EXCEPTION WHEN others THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'another actor spent quote';END IF;
 PERFORM set_config('request.jwt.claim.sub',a::text,true);
 UPDATE office_private.boutique_quotes SET expires_at=now()-interval '1 second' WHERE actor=a;
 rejected:=false;BEGIN PERFORM public.office_shop_buy((q->>'quote')::uuid,gen_random_uuid());EXCEPTION WHEN others THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'expired item quote accepted';END IF;
 q:=public.office_shop_quote('theme_accounting');UPDATE public.players SET cosmetic_rate_peak=cosmetic_rate_peak*2+1 WHERE id=a;
 rejected:=false;BEGIN PERFORM public.office_shop_buy((q->>'quote')::uuid,gen_random_uuid());EXCEPTION WHEN others THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'changed item benchmark accepted';END IF;
 q:=public.office_shop_quote('theme_accounting');UPDATE public.players SET pp=0 WHERE id=a;
 rejected:=false;BEGIN PERFORM public.office_shop_buy((q->>'quote')::uuid,gen_random_uuid());EXCEPTION WHEN others THEN rejected:=true;END;
 IF NOT rejected OR (SELECT pp FROM public.players WHERE id=a)<>0 THEN RAISE EXCEPTION 'insufficient purchase changed balance';END IF;
 UPDATE public.players SET pp=1e20 WHERE id=a;
 FOR i IN 0..2 LOOP
  old_week:=public.week_key(now()-make_interval(weeks=>i));
  INSERT INTO office_private.daily_activity(actor,day,week,category) VALUES(a,(now() AT TIME ZONE 'America/Los_Angeles')::date-i*7,old_week,'work'),(a,(now() AT TIME ZONE 'America/Los_Angeles')::date-i*7,old_week,'care'),(a,(now() AT TIME ZONE 'America/Los_Angeles')::date-i*7-1,old_week,'facilities') ON CONFLICT DO NOTHING;
 END LOOP;
 q:=public.office_shop_quote('coffee_tech');r:=public.office_shop_buy((q->>'quote')::uuid,gen_random_uuid());
 p:=public.set_look('{"clothing":"coffee_tech","head":"photo"}');
 IF p.look->>'clothing'<>'coffee_tech' OR p.look->>'head'<>'photo' THEN RAISE EXCEPTION 'new garment cannot equip through actual appearance RPC';END IF;
 q:=public.office_shop_quote('meeting_survivor');PERFORM public.office_shop_buy((q->>'quote')::uuid,gen_random_uuid());
 q:=public.office_shop_quote('theme_chaos');PERFORM public.office_shop_buy((q->>'quote')::uuid,gen_random_uuid());
 p:=public.office_display_collectibles(ARRAY['theme_chaos','theme_facilities']);IF jsonb_array_length(p.office_display)<>2 THEN RAISE EXCEPTION 'theme display failed';END IF;
 -- Existing dress body must still quote, charge, last 45m and record one playful deed.
 p:=public.dress(a,'budget_wizard');IF p.outfit->>'id'<>'budget_wizard' OR (p.outfit->>'until')::timestamptz<>now()+interval '45 minutes' THEN RAISE EXCEPTION 'wizard costume duration missing';END IF;
 p:=public.dress(b,'filing_cabinet');IF NOT EXISTS(SELECT 1 FROM public.deeds WHERE actor=a AND target=b AND kind='dress' AND detail='filing_cabinet') THEN RAISE EXCEPTION 'cabinet deed missing';END IF;
 -- Capture all standings before the actual normal wipe. Preserve names and ties.
 UPDATE public.players SET week_pp=CASE id WHEN a THEN 500 WHEN b THEN 500 ELSE 100 END;
 UPDATE public.season_state SET current_week=closing;
 INSERT INTO public.deeds(actor,target,kind,created_at,hush) VALUES(b,a,'coffee',now()-interval '7 days',false),(b,a,'coffee',now()-interval '7 days',false),(a,b,'coffee',now()-interval '7 days',true);
 PERFORM public.roll_week();r:=public.office_recordbook(closing,a);
 IF jsonb_array_length(r->'standings')<>3 OR r#>>'{season,coverage}'<>'standings' OR (SELECT count(*) FROM office_private.season_results WHERE week=closing AND place=1)<>2 OR (SELECT place FROM office_private.season_results WHERE week=closing AND player=c)<>3 THEN RAISE EXCEPTION 'normal reset lost standings or ties';END IF;
 IF r#>>'{personal_best,earnings}'<>'500' OR EXISTS(SELECT 1 FROM office_private.season_results WHERE week=closing AND earnings=0) THEN RAISE EXCEPTION 'record book saved post-wipe zeroes';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(r->'awards') x WHERE x->>'category'='help' AND x->>'player'=a::text) THEN RAISE EXCEPTION 'hushed deed appeared in public award';END IF;
 UPDATE public.players SET name='New current name',week_pp=9999 WHERE id=a;
 UPDATE public.seasons SET stats='{}' WHERE week_key=closing;
 IF NOT EXISTS(SELECT 1 FROM office_private.season_results WHERE week=closing AND player=a AND name='Fixture A' AND earnings=500) THEN RAISE EXCEPTION 'recap edit rewrote immutable standings';END IF;
 INSERT INTO public.seasons(week_key,winner_name,top) VALUES('1999-01','Historical winner',321);
 r:=public.office_recordbook('1999-01',a);IF r#>>'{season,coverage}'<>'winner_only' OR jsonb_array_length(r->'standings')<>0 THEN RAISE EXCEPTION 'historical standings fabricated';END IF;
 IF NOT (SELECT wardrobe_owned?'coffee_tech' AND wardrobe_owned?'meeting_survivor' AND office_collectibles?'theme_chaos' AND office_collectibles?'theme_facilities' FROM public.players WHERE id=a) THEN RAISE EXCEPTION 'reset lost boutique items';END IF;
 IF has_table_privilege('authenticated','office_private.season_results','SELECT,INSERT,UPDATE,DELETE') OR has_function_privilege('anon','public.office_recordbook(text,uuid)','EXECUTE') OR has_function_privilege('authenticated','office_private.boutique_catalog()','EXECUTE') THEN RAISE EXCEPTION 'pack grants exposed private data';END IF;
 PERFORM set_config('request.jwt.claim.sub','',true);rejected:=false;BEGIN PERFORM public.office_recordbook();EXCEPTION WHEN others THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'anonymous recordbook accepted';END IF;
 RAISE NOTICE 'PASS boutique/recordbook: quotes, retries, actor binding, participation, real costume/appearance bodies, persistent themes/outfits, normal reset standings/ties, old coverage and hush privacy';
END $pack$;
ROLLBACK;
