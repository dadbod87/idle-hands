-- Actual style RPCs in the disposable PostgreSQL harness, never Production.
BEGIN;
DO $$ BEGIN IF current_database()<>'idle_hands_test' THEN RAISE EXCEPTION 'Isolated test database required'; END IF; END $$;
CREATE TABLE IF NOT EXISTS public.catalog(key text PRIMARY KEY,data jsonb);
\i tests/fixtures/style-catalog.sql
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
SELECT set_config('request.jwt.claim.sub',(SELECT id::text FROM public.players LIMIT 1),true);
CREATE OR REPLACE FUNCTION public.calc_rate(p public.players) RETURNS double precision LANGUAGE sql STABLE AS $$SELECT coalesce((p.owned->>'style_test_rate')::double precision,100)$$;
CREATE OR REPLACE FUNCTION public.live_mult(p public.players) RETURNS double precision LANGUAGE sql STABLE AS $$SELECT coalesce(nullif(current_setting('style_test.mult',true),''),'1')::double precision$$;
CREATE OR REPLACE FUNCTION public.week_key(ts timestamptz DEFAULT now()) RETURNS text LANGUAGE sql STABLE AS $$SELECT coalesce(nullif(current_setting('style_test.week',true),''),'2030-01')$$;
CREATE OR REPLACE FUNCTION public.accrue(p_id uuid) RETURNS public.players LANGUAGE plpgsql AS $$DECLARE p public.players;BEGIN SELECT * INTO p FROM public.players WHERE id=p_id FOR UPDATE;RETURN p;END$$;
\i tests/fixtures/style-baseline-functions.sql
CREATE TEMP TABLE style_install_before AS SELECT id,to_jsonb(p) snapshot FROM public.players p;
\i supabase/migrations/20261106213809_owned_item_styles.sql
DO $tests$
DECLARE p public.players; q jsonb; q2 jsonb; before_pp double precision; uid uuid:=auth.uid(); rejected boolean; item text; design text; n int; keeps jsonb; other_id uuid;
BEGIN
 IF EXISTS(SELECT 1 FROM public.players employee JOIN style_install_before b USING(id) WHERE to_jsonb(employee)-'cosmetic_styles'-'cosmetic_equipped'-'cosmetic_revision'<>b.snapshot) THEN RAISE EXCEPTION 'Install rewrote existing values'; END IF;
 IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='public.style_quotes'::regclass) OR has_table_privilege('authenticated','public.style_quotes','SELECT') OR has_table_privilege('anon','public.style_quotes','INSERT') THEN RAISE EXCEPTION 'Quote storage exposed'; END IF;
 IF has_function_privilege('anon','public.quote_style(text,text,text)','EXECUTE') OR has_function_privilege('authenticated','public.style_item_info(public.players,text)','EXECUTE') OR NOT has_function_privilege('authenticated','public.apply_style(uuid)','EXECUTE') THEN RAISE EXCEPTION 'RPC permissions wrong'; END IF;
 UPDATE public.players SET pp=1e12,spent=0,kit='{"desk":"d3","chair":"c4","rug":"r4","art":"w4","tv":"tv1"}',vanity='{"held":"h5"}',wardrobe_owned='["hoodie","cardigan","blazer","hawaiian","hoodie_gold","friday"]',extras='["beta"]',owned='{"style_test_rate":100}' WHERE id=uid;
 SELECT pp INTO before_pp FROM public.players WHERE id=uid;
 q:=public.quote_style('d3','#FF55B0','sparkle');
 IF (q->>'color_fee')::float8<>8640000 OR (q->>'design_fee')::float8<>8640000 OR (q->>'total')::float8<>17280000 OR (SELECT pp FROM public.players WHERE id=uid)<>before_pp THEN RAISE EXCEPTION 'Separate quote or free preview incorrect'; END IF;
 p:=public.apply_style((q->>'id')::uuid);
 IF p.pp<>before_pp-17280000 OR p.spent<>17280000 OR p.cosmetic_styles->'d3'<>'{"color":"#ff55b0","design":"sparkle"}'::jsonb THEN RAISE EXCEPTION 'Atomic payment/style failed'; END IF;
 p:=public.apply_style((q->>'id')::uuid);IF p.pp<>before_pp-17280000 THEN RAISE EXCEPTION 'Retry double charged'; END IF;
 q:=public.quote_style('d3','#ff55b0','sparkle');IF (q->>'total')::float8<>0 THEN RAISE EXCEPTION 'Unchanged style charged';END IF;
 q:=public.quote_style('d3','#8b4cdd','sparkle');IF (q->>'color_fee')::float8<>8640000 OR (q->>'design_fee')::float8<>0 THEN RAISE EXCEPTION 'Color-only cost';END IF;
 p:=public.apply_style((q->>'id')::uuid);
 q:=public.quote_style('d3','#8b4cdd','dots');IF (q->>'color_fee')::float8<>0 OR (q->>'design_fee')::float8<>8640000 THEN RAISE EXCEPTION 'Design-only cost';END IF;
 p:=public.apply_style((q->>'id')::uuid);
 q:=public.quote_style('d3','#8b4cdd','solid');IF (q->>'total')::float8<>0 THEN RAISE EXCEPTION 'Pattern removal charged';END IF;
 p:=public.apply_style((q->>'id')::uuid);
 -- Price/revision/expiry/week changes and replaced requests never spend.
 q:=public.quote_style('d3','#35e6ee','check');UPDATE public.style_quotes SET expires_at=now()-interval '1 second' WHERE player_id=uid;
 rejected:=false;BEGIN PERFORM public.apply_style((q->>'id')::uuid);EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'Expired quote accepted';END IF;
 q:=public.quote_style('d3','#35e6ee','check');PERFORM set_config('style_test.mult','2',true);
 rejected:=false;BEGIN PERFORM public.apply_style((q->>'id')::uuid);EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'Changed output accepted';END IF;PERFORM set_config('style_test.mult','1',true);
 q:=public.quote_style('d3','#35e6ee','check');p:=public.equip_style_item('d1');
 IF p.kit->>'desk'<>'d3' OR p.cosmetic_equipped->>'desk'<>'d1' THEN RAISE EXCEPTION 'Equipping earlier purchase lowered unlocks';END IF;
 rejected:=false;BEGIN PERFORM public.apply_style((q->>'id')::uuid);EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'Stale appearance accepted';END IF;
 q:=public.quote_style('d3','#35e6ee','check');PERFORM set_config('style_test.week','2030-02',true);
 rejected:=false;BEGIN PERFORM public.apply_style((q->>'id')::uuid);EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'Previous-week quote accepted';END IF;
 q:=public.quote_style('d3','#35e6ee','check');q2:=public.quote_style('c2','#35e6ee','check');
 rejected:=false;BEGIN PERFORM public.apply_style((q->>'id')::uuid);EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'Replaced quote accepted';END IF;
 -- A valid quote cannot be applied by another authenticated employee.
 q:=public.quote_style('d3','#35e6ee','check');SELECT id INTO other_id FROM public.players WHERE id<>uid LIMIT 1;
 IF other_id IS NULL THEN RAISE EXCEPTION 'Second synthetic player required';END IF;
 PERFORM set_config('request.jwt.claim.sub',other_id::text,true);rejected:=false;BEGIN PERFORM public.apply_style((q->>'id')::uuid);EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'Other player applied quote';END IF;PERFORM set_config('request.jwt.claim.sub',uid::text,true);
 -- Ownership, malformed inputs, anonymous and foreign-quote defenses.
 FOREACH item IN ARRAY ARRAY['d4','d5','g1','missing','pin:missing'] LOOP
  rejected:=false;BEGIN PERFORM public.quote_style(item,'#ff55b0','solid');EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'Unauthorized item % accepted',item;END IF;
 END LOOP;
 rejected:=false;BEGIN PERFORM public.quote_style('d3','url(javascript:bad)','solid');EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'Invalid color accepted';END IF;
 rejected:=false;BEGIN PERFORM public.quote_style('d3','#ffffff','animated-script');EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'Invalid design accepted';END IF;
 rejected:=false;BEGIN PERFORM public.apply_style(gen_random_uuid());EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'Foreign quote accepted';END IF;
 PERFORM set_config('request.jwt.claim.sub','',true);rejected:=false;BEGIN PERFORM public.quote_style('d1',null,'solid');EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'Anonymous quote accepted';END IF;PERFORM set_config('request.jwt.claim.sub',uid::text,true);
 UPDATE public.players SET pp=0 WHERE id=uid;q:=public.quote_style('d3','#35e6ee','check');rejected:=false;BEGIN PERFORM public.apply_style((q->>'id')::uuid);EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected OR (SELECT pp FROM public.players WHERE id=uid)<>0 THEN RAISE EXCEPTION 'Unaffordable purchase changed balance';END IF;
 UPDATE public.players SET owned='{"style_test_rate":0}' WHERE id=uid;q:=public.quote_style('d3','#35e6ee','check');IF (q->>'total')::float8<>2000 THEN RAISE EXCEPTION 'Zero-income minimum';END IF;
 UPDATE public.players SET owned='{"style_test_rate":100}',pp=1e12,cycle=1e14,last_restructure=null WHERE id=uid;
 -- Highest-tier purchasing and automatic display still work with a lower item equipped.
 p:=public.buy_fitting('office_kit','d4');IF p.kit->>'desk'<>'d4' OR p.cosmetic_equipped ? 'desk' THEN RAISE EXCEPTION 'New upgrade failed to equip';END IF;
 UPDATE public.players SET kit=kit||'{"desk":"d5"}' WHERE id=uid;
 -- Every physical tier/wardrobe/pin accepts all six finish IDs through actual RPCs.
 FOR item IN SELECT v->>'id' FROM public.catalog c CROSS JOIN LATERAL jsonb_array_elements(c.data) v WHERE c.key='office_kit' OR c.key='vanity' AND v->>'slot'='held'
 UNION SELECT unnest(ARRAY['starter','hoodie','cardigan','blazer','hawaiian','hoodie_gold','friday','pin:beta']) LOOP
  FOREACH design IN ARRAY ARRAY['solid','stripe','check','dots','sparkle','confetti'] LOOP
   q:=public.quote_style(item,'#ff55b0',design);p:=public.apply_style((q->>'id')::uuid);
  END LOOP;
  p:=public.equip_style_item(item);
 END LOOP;
 keeps:=jsonb_build_array(p.cosmetic_styles,p.cosmetic_equipped);
 p:=public.restructure();IF jsonb_build_array(p.cosmetic_styles,p.cosmetic_equipped)<>keeps THEN RAISE EXCEPTION 'Restructure removed finishes';END IF;
 PERFORM public.season_wipe();SELECT * INTO p FROM public.players WHERE id=uid;IF jsonb_build_array(p.cosmetic_styles,p.cosmetic_equipped)<>keeps OR p.pp<>0 OR p.kit->>'desk'<>'d5' THEN RAISE EXCEPTION 'Weekly reset removed physical styles/unlocks';END IF;
 RAISE NOTICE 'PASS: actual style RPC ownership, split charges, minima, idempotency, stale/expired/week/rate validation, free equip, every physical tier and reset persistence';
END $tests$;
ROLLBACK;
