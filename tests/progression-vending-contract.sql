-- Disposable PostgreSQL only. Never execute on Production.
BEGIN;
DO $$ BEGIN IF current_database()<>'idle_hands_test' THEN RAISE EXCEPTION 'Isolated database required';END IF;END $$;
CREATE TABLE IF NOT EXISTS public.catalog(key text PRIMARY KEY,data jsonb);
INSERT INTO public.catalog(key,data) VALUES ('fund_tiers','[1e16,5.5e17,3e19,1.7e21,9.5e22,5.2e24,2.9e26,1.6e28]'),('vend_prizes','[{"kind":"nothing","text":"A strongly worded receipt.","w":1}]') ON CONFLICT(key) DO UPDATE SET data=excluded.data;
ALTER TABLE public.season_state ADD COLUMN IF NOT EXISTS mhit boolean DEFAULT false, ADD COLUMN IF NOT EXISTS streak int DEFAULT 0, ADD COLUMN IF NOT EXISTS best int DEFAULT 0;
ALTER TABLE public.printer_claims ADD COLUMN IF NOT EXISTS name text, ADD COLUMN IF NOT EXISTS fixer uuid;
ALTER TABLE public.chair_claims ADD COLUMN IF NOT EXISTS name text, ADD COLUMN IF NOT EXISTS taker uuid;
ALTER TABLE public.meeting_claims ADD COLUMN IF NOT EXISTS name text, ADD COLUMN IF NOT EXISTS attendee uuid, ADD COLUMN IF NOT EXISTS paid boolean DEFAULT false, ADD COLUMN IF NOT EXISTS joined_at timestamptz DEFAULT now();
CREATE OR REPLACE FUNCTION public.office_target() RETURNS double precision LANGUAGE sql AS $$SELECT 100::float8$$;
CREATE OR REPLACE FUNCTION public.printer_window() RETURNS integer LANGUAGE sql AS $$SELECT 0$$;
CREATE OR REPLACE FUNCTION public.chair_window() RETURNS integer LANGUAGE sql AS $$SELECT 0$$;
CREATE OR REPLACE FUNCTION public.meeting_window() RETURNS integer LANGUAGE sql AS $$SELECT 0$$;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
SELECT set_config('request.jwt.claim.sub',(SELECT id::text FROM public.players LIMIT 1),true);
CREATE OR REPLACE FUNCTION public.calc_rate(p public.players) RETURNS double precision LANGUAGE sql STABLE AS $$SELECT coalesce((p.owned->>'r190_rate')::float8,100)$$;
CREATE OR REPLACE FUNCTION public.live_mult(p public.players) RETURNS double precision LANGUAGE sql STABLE AS $$SELECT 1::float8$$;
CREATE OR REPLACE FUNCTION public.accrue(p_id uuid) RETURNS public.players LANGUAGE plpgsql AS $$DECLARE p public.players;BEGIN SELECT * INTO p FROM public.players WHERE id=p_id FOR UPDATE;RETURN p;END$$;
\i tests/fixtures/r190-baseline-functions.sql
\i tests/fixtures/style-catalog.sql
\i supabase/migrations/20261106213809_owned_item_styles.sql
-- Stage a pending quote at the old price, then verify the pricing migration invalidates it.
UPDATE public.players SET pp=1000000000,owned='{"r190_rate":100}' WHERE id=auth.uid();
CREATE TEMP TABLE old_style_quote AS SELECT public.quote_style('d1','#ff55b0','sparkle') value;
INSERT INTO public.style_quotes(player_id,item,color,design,color_fee,design_fee,rate,revision,week,expires_at,applied) SELECT id,'d1',null,'solid',0,0,0,0,public.week_key(),now()+interval '2 minutes',true FROM public.players WHERE id<>auth.uid() LIMIT 1;
CREATE TEMP TABLE r190_rows AS SELECT id,to_jsonb(employee) snapshot FROM public.players employee;
CREATE TEMP TABLE r190_bodies AS SELECT oid,md5(pg_get_functiondef(oid)) hash FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname IN ('ask_raise','use_vending','fund_tier','season_wipe');
\i supabase/migrations/20261106221939_fund_milestones_and_vending_status.sql
DO $tests$
DECLARE p public.players; state jsonb; uid uuid:=auth.uid(); snapshot jsonb; rejected boolean; threshold numeric; idx int:=0; prize jsonb;
BEGIN
 IF EXISTS(SELECT 1 FROM public.players employee JOIN r190_rows b USING(id) WHERE to_jsonb(employee)<>b.snapshot) THEN RAISE EXCEPTION 'Installation changed player progress';END IF;
 IF EXISTS(SELECT 1 FROM r190_bodies b WHERE md5(pg_get_functiondef(b.oid))<>b.hash) THEN RAISE EXCEPTION 'Existing action/economy/reset functions changed';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.style_quotes WHERE applied AND expires_at>now()) THEN RAISE EXCEPTION 'Accepted receipt was expired';END IF;
 IF EXISTS(SELECT 1 FROM public.style_quotes WHERE NOT applied AND expires_at>now()) THEN RAISE EXCEPTION 'Old-price quote still usable';END IF;
 rejected:=false;BEGIN PERFORM public.apply_style(((SELECT value FROM old_style_quote)->>'id')::uuid);EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'Old quote charged after price reduction';END IF;
 -- Simulate an old in-flight quote landing after migration: even a fresh expiry cannot revive its old price.
 UPDATE public.style_quotes SET expires_at=now()+interval '2 minutes' WHERE player_id=uid;
 rejected:=false;BEGIN PERFORM public.apply_style(((SELECT value FROM old_style_quote)->>'id')::uuid);EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'Late old-price quote charged';END IF;
 state:=public.quote_style('d1','#ff55b0','sparkle');IF (state->>'seconds_per_change')::int<>28800 OR (state->>'color_fee')::float8<>2880000 OR (state->>'design_fee')::float8<>2880000 OR (state->>'total')::float8<>5760000 THEN RAISE EXCEPTION 'Eight-hour split fee wrong';END IF;
 p:=public.apply_style((state->>'id')::uuid);IF p.pp<>994240000 OR p.cosmetic_styles->'d1'->>'design'<>'sparkle' THEN RAISE EXCEPTION 'Eight-hour payment/save failed';END IF;
 p:=public.apply_style((state->>'id')::uuid);IF p.pp<>994240000 THEN RAISE EXCEPTION 'Eight-hour accepted retry double charged';END IF;
 IF (SELECT jsonb_array_length(data) FROM public.catalog WHERE key='fund_tiers')<>20 THEN RAISE EXCEPTION 'Wrong tier count';END IF;
 IF (SELECT jsonb_agg(value ORDER BY ord) FROM public.catalog c CROSS JOIN LATERAL jsonb_array_elements(c.data) WITH ORDINALITY v(value,ord) WHERE c.key='fund_tiers' AND ord<=8)<>'[1e16,5.5e17,3e19,1.7e21,9.5e22,5.2e24,2.9e26,1.6e28]'::jsonb THEN RAISE EXCEPTION 'Existing tiers changed';END IF;
 UPDATE public.players SET week_pp=0;
 FOR threshold IN SELECT value::text::numeric FROM public.catalog c CROSS JOIN LATERAL jsonb_array_elements(c.data) v(value) WHERE c.key='fund_tiers' LOOP
  UPDATE public.players SET week_pp=threshold*0.999 WHERE id=uid;IF public.fund_tier()<>idx THEN RAISE EXCEPTION 'Below boundary wrong at %',threshold;END IF;
  idx:=idx+1;UPDATE public.players SET week_pp=threshold WHERE id=uid;IF public.fund_tier()<>idx THEN RAISE EXCEPTION 'At boundary wrong at %',threshold;END IF;
 END LOOP;
 UPDATE public.players SET week_pp=1.315e37 WHERE id=uid;
 IF public.fund_tier()<>13 OR (public.office_state()->>'tiers')::int<>13 OR public.office_state()->'fund_thresholds'<>(SELECT data FROM public.catalog WHERE key='fund_tiers') THEN RAISE EXCEPTION 'Live-scale tier/metadata mismatch';END IF;
 UPDATE public.players SET pp=1000000,last_vend=null,owned='{"r190_rate":100}',raises=4 WHERE id=uid;
 SELECT to_jsonb(employee) INTO snapshot FROM public.players employee WHERE id=uid;
 state:=public.vending_state();IF state->>'ready_at' IS NOT NULL OR (state->>'price')::float8<>4500 THEN RAISE EXCEPTION 'Initial status/quote mismatch';END IF;
 IF (SELECT to_jsonb(employee) FROM public.players employee WHERE id=uid)<>snapshot THEN RAISE EXCEPTION 'Reading status changed money or timers';END IF;
 prize:=public.use_vending();SELECT * INTO p FROM public.players WHERE id=uid;
 IF p.pp<>995500 OR p.last_vend<>now() OR prize->>'kind'<>'nothing' THEN RAISE EXCEPTION 'Existing price/outcome changed';END IF;
 state:=public.vending_state();IF (state->>'ready_at')::timestamptz<>now()+interval '10 minutes' THEN RAISE EXCEPTION 'Cooldown not projected from accepted pull';END IF;
 rejected:=false;BEGIN PERFORM public.use_vending();EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected OR (SELECT pp FROM public.players WHERE id=uid)<>995500 THEN RAISE EXCEPTION 'Duplicate pull charged';END IF;
 UPDATE public.players SET last_vend=now()-interval '9 minutes 59 seconds' WHERE id=uid;rejected:=false;BEGIN PERFORM public.use_vending();EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'Cooldown ended early';END IF;
 UPDATE public.players SET last_vend=now()-interval '10 minutes' WHERE id=uid;PERFORM public.use_vending();IF (SELECT pp FROM public.players WHERE id=uid)<>991000 THEN RAISE EXCEPTION 'Exact expiry not available';END IF;
 UPDATE public.players SET pp=0,last_vend=null WHERE id=uid;rejected:=false;BEGIN PERFORM public.use_vending();EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected OR (SELECT last_vend FROM public.players WHERE id=uid) IS NOT NULL THEN RAISE EXCEPTION 'Rejected pull started cooldown';END IF;
 UPDATE public.players SET owned='{"r190_rate":0}' WHERE id=uid;IF (public.vending_state()->>'price')::float8<>60 THEN RAISE EXCEPTION 'Existing minimum changed';END IF;
 state:=public.quote_style('d1','#43634b','check');IF (state->>'total')::float8<>2000 THEN RAISE EXCEPTION 'Eight-hour minimum changed';END IF;
 IF has_function_privilege('anon','public.vending_state()','EXECUTE') OR NOT has_function_privilege('authenticated','public.vending_state()','EXECUTE') THEN RAISE EXCEPTION 'Status grants incorrect';END IF;
 PERFORM set_config('request.jwt.claim.sub','',true);rejected:=false;BEGIN PERFORM public.vending_state();EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'Unauthenticated status permitted';END IF;PERFORM set_config('request.jwt.claim.sub',uid::text,true);
 PERFORM public.season_wipe();IF public.fund_tier()<>0 OR EXISTS(SELECT 1 FROM public.players WHERE raises<>0 OR last_vend IS NOT NULL) THEN RAISE EXCEPTION 'Weekly raises/cooldowns/fund did not reset';END IF;
 RAISE NOTICE 'PASS: real fund tier boundaries and extended metadata; unchanged pull price/outcome/10-minute cooldown; no-charge rejection, status is read-only, grants, weekly raises/fund reset';
END $tests$;
ROLLBACK;
