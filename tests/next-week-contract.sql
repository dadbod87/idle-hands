\set ON_ERROR_STOP on
-- Last CI contract suite. Completely isolated disposable DB; no provider connection.
DO $$ BEGIN IF current_database()<>'idle_hands_test' THEN RAISE EXCEPTION 'isolated test DB required'; END IF; END $$;
DROP SCHEMA IF EXISTS office_private CASCADE;
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
DROP SCHEMA IF EXISTS auth CASCADE;
\i tests/fixtures/next-week-schema.sql
ALTER TABLE public.players ADD PRIMARY KEY(id);
ALTER TABLE public.catalog ADD PRIMARY KEY(key);
ALTER TABLE public.office_play_actions ADD PRIMARY KEY(week,actor,day,kind);
ALTER TABLE public.printer_claims ADD PRIMARY KEY(window_id);
ALTER TABLE public.chair_claims ADD PRIMARY KEY(window_id);
ALTER TABLE public.style_quotes ADD PRIMARY KEY(player_id);
\i tests/fixtures/next-week-catalog.sql
INSERT INTO public.office_door(id,tz) VALUES(1,'America/Los_Angeles');
INSERT INTO public.season_state(id,current_week,mw,mhit,streak) VALUES(1,'fixture','fixture',true,0);
INSERT INTO public.players(id,name,pp,owned,equity,last_tick) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Fixture A',1e40,'{"intern":20}',20,now()),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Fixture B',1e40,'{"intern":1}',0,now()),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','Fixture C',1e40,'{"intern":1}',0,now());
CREATE FUNCTION public.accrue(p_id uuid) RETURNS public.players LANGUAGE sql AS $$SELECT * FROM public.players WHERE id=p_id$$;
-- Install the actual historic ownership helper/trigger from its pre-migration schema.
DROP TABLE public.style_quotes;
ALTER TABLE public.players DROP COLUMN cosmetic_styles,DROP COLUMN cosmetic_equipped,DROP COLUMN cosmetic_revision;
\i supabase/migrations/20261106213809_owned_item_styles.sql
\i tests/fixtures/next-week-baseline.sql
-- These dependencies are deterministic fixture substitutes. Action and migration bodies are actual.
CREATE FUNCTION public.event_mult(ts timestamptz) RETURNS float8 LANGUAGE sql AS $$SELECT 1::float8$$;
CREATE FUNCTION public.jess_boost_mult(ts timestamptz) RETURNS float8 LANGUAGE sql AS $$SELECT 1::float8$$;
CREATE FUNCTION public.check_margarita() RETURNS void LANGUAGE plpgsql AS $$BEGIN END$$;
CREATE FUNCTION public.settle_meetings() RETURNS void LANGUAGE plpgsql AS $$BEGIN END$$;
CREATE FUNCTION public.roll_week() RETURNS void LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'fixture unexpectedly requested rollover'; END$$;
CREATE FUNCTION public.accrual_interval_gain(p public.players,since_ts timestamptz,until_ts timestamptz) RETURNS float8 LANGUAGE sql AS $$SELECT 0::float8$$;
CREATE FUNCTION public.bump_today(p_id uuid,k text,n int) RETURNS void LANGUAGE plpgsql AS $$BEGIN END$$;
CREATE FUNCTION public.check_rivalry(p_a uuid,p_b uuid) RETURNS boolean LANGUAGE sql AS $$SELECT false$$;
CREATE FUNCTION public.office_play_state() RETURNS jsonb LANGUAGE sql AS $$SELECT '{}'::jsonb$$;
UPDATE public.season_state SET current_week=public.week_key(),mw=public.week_key();
INSERT INTO public.deeds(actor,target,kind,created_at,hush) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','coffee',now()-interval '1 hour',false),
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','credit',now()-interval '30 minutes',true);
SELECT set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false);
CREATE TEMP TABLE before_install AS SELECT id,kit,vanity,wardrobe_owned,cosmetic_styles,pp FROM public.players;
\i sql/next_week_office.sql
BEGIN;
DO $test$
DECLARE p public.players;t public.players;r jsonb;r2 jsonb;before_rate float8;after_rate float8;before_pp float8;n int;rejected boolean;uid uuid:=auth.uid();rid uuid:=gen_random_uuid();anchor float8;q jsonb;
BEGIN
 IF EXISTS(SELECT 1 FROM public.players employee JOIN before_install b USING(id) WHERE employee.kit<>b.kit OR employee.vanity<>b.vanity OR employee.wardrobe_owned<>b.wardrobe_owned OR employee.cosmetic_styles<>b.cosmetic_styles OR employee.pp<>b.pp) THEN RAISE EXCEPTION 'installation changed ownership or funds'; END IF;
 IF (SELECT count(*) FROM office_private.action_history)<>2 OR (SELECT count(*) FROM office_private.project_stamps)<>0 THEN RAISE EXCEPTION 'backfill count or historic reward wrong'; END IF;
 r:=public.office_profile(uid,'lifetime',NULL);
 IF jsonb_array_length(r->'by_kind')<>1 OR r#>>'{by_kind,0,kind}'<>'coffee' THEN RAISE EXCEPTION 'hushed source leaked'; END IF;
 UPDATE public.deeds SET hush=true WHERE kind='coffee';r:=public.office_profile(uid,'lifetime',NULL);IF jsonb_array_length(r->'by_kind')<>0 THEN RAISE EXCEPTION 'later hush leaked'; END IF;
 -- Actual before/after perk functions: an output upgrade never removes earned points.
 SELECT * INTO p FROM public.players WHERE id=uid;before_rate:=public.live_mult(p);p:=public.buy_perk('compound');after_rate:=public.live_mult(p);
 IF p.equity<>16 OR p.seniority_earned<>20 OR abs(after_rate/before_rate-1.05)>0.0000001 THEN RAISE EXCEPTION 'Seniority purchase lost output'; END IF;
 FOR n IN 1..4 LOOP p:=public.buy_perk('compound');END LOOP;
 IF p.equity<>0 OR p.seniority_earned<>20 THEN RAISE EXCEPTION 'all perk levels erased earned points'; END IF;
 UPDATE public.players SET owned='{"intern":1}',last_restructure=null,cycle=1e30 WHERE id=uid;
 SELECT public.permanent_price_rate(employee) INTO anchor FROM public.players employee WHERE id=uid;
 p:=public.restructure();IF p.seniority_earned<=20 OR public.permanent_price_rate(p)<anchor OR p.pp<>0 THEN RAISE EXCEPTION 'restructure lost earned points or price anchor'; END IF;
 -- A large donor can no longer transfer cash, and repeated Cover cannot stack.
 UPDATE public.players SET pp=1e40,last_deed=null,owned='{"original":100}' WHERE id=uid;
 SELECT pp INTO before_pp FROM public.players WHERE id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
 p:=public.do_deed('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','cover');
 IF (SELECT pp FROM public.players WHERE id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')<>before_pp THEN RAISE EXCEPTION 'cover minted cash'; END IF;
 UPDATE public.players SET last_deed=null WHERE id=uid;p:=public.do_deed('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','cover');
 IF (SELECT count(*) FROM public.players employee,jsonb_array_elements(employee.buffs) b WHERE employee.id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' AND b->>'kind'='cover')<>1 THEN RAISE EXCEPTION 'cover stacks'; END IF;
 -- Reset-safe permanent quotes use retained base production; temporary multipliers do not discount.
 SELECT public.permanent_price_rate(employee) INTO anchor FROM public.players employee WHERE id=uid;
 UPDATE public.players SET owned='{}',upgrades='[]',buffs='[]',pp=1e40 WHERE id=uid;
 r:=public.fitting_prices();IF (r->>'rate')::float8<anchor THEN RAISE EXCEPTION 'fittings quote collapsed'; END IF;
 SELECT * INTO p FROM public.players WHERE id=uid;IF public.permanent_price_rate(p)<anchor THEN RAISE EXCEPTION 'price floor lost'; END IF;
 -- Project credits have a uniqueness key and require three contributors.
 PERFORM office_private.project_credit(uid,'work');PERFORM office_private.project_credit(uid,'work');
 IF (SELECT count(*) FROM office_private.project_stamps WHERE actor=uid AND category='work')<>1 THEN RAISE EXCEPTION 'duplicate stamp'; END IF;
 FOR t IN SELECT * FROM public.players LOOP
  PERFORM office_private.project_credit(t.id,'work');PERFORM office_private.project_credit(t.id,'facilities');PERFORM office_private.project_credit(t.id,'care');PERFORM office_private.project_credit(t.id,'playful');
 END LOOP;
 r:=public.office_week_status();IF r#>>'{project,total}'<>'12' OR r#>>'{project,contributors}'<>'3' OR r#>>'{project,completed}'<>'true' THEN RAISE EXCEPTION 'project completion incorrect'; END IF;
 p:=public.office_claim_collectible('nameplate',public.week_key());p:=public.office_claim_collectible('nameplate',public.week_key());p:=public.office_claim_collectible('corkboard',public.week_key());p:=public.office_claim_collectible('plaque',public.week_key());
 IF jsonb_array_length(p.office_collectibles)<>3 THEN RAISE EXCEPTION 'reward duplication or missing reward'; END IF;
 -- Two-slot changes preserve all charges. Replayed actions cannot spend another charge.
 r:=public.office_equip_tools(ARRAY['rescue','confetti']);
 UPDATE public.players SET last_deed=null WHERE id=uid;
 UPDATE public.players SET buffs=jsonb_build_array(jsonb_build_object('kind','replyall','mult',0.45,'until',now()+interval '8 minutes')) WHERE id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
 r:=public.office_interact('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','rescue',rid);r2:=public.office_interact('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','rescue',rid);
 IF r<>r2 OR r#>>'{status,toolkit,charges,rescue}'<>'1' OR (SELECT jsonb_array_length(buffs) FROM public.players WHERE id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')<>0 THEN RAISE EXCEPTION 'rescue replay or effect incorrect'; END IF;
 r:=public.office_equip_tools(ARRAY['filter']);r:=public.office_equip_tools(ARRAY['rescue','confetti']);IF r#>>'{toolkit,charges,rescue}'<>'1' THEN RAISE EXCEPTION 'slot swap refilled charges'; END IF;
 rejected:=false;BEGIN PERFORM public.office_equip_tools(ARRAY['rescue','rescue']);EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'duplicate slots';END IF;
 rejected:=false;BEGIN PERFORM public.office_interact(uid,'confetti',gen_random_uuid());EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'self action';END IF;
 UPDATE public.players SET last_deed=null WHERE id=uid;r:=public.office_interact('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','confetti',gen_random_uuid());
 IF (SELECT office_confetti IS NULL FROM public.players WHERE id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb') THEN RAISE EXCEPTION 'confetti missing'; END IF;
 PERFORM set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);p:=public.office_clear_confetti();IF p.office_confetti IS NOT NULL THEN RAISE EXCEPTION 'cannot remove confetti'; END IF;
 r:=public.office_equip_tools(ARRAY['filter']);PERFORM set_config('request.jwt.claim.sub',uid::text,true);UPDATE public.players SET last_deed=null WHERE id=uid;
 p:=public.do_deed('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','replyall');
 IF NOT EXISTS(SELECT 1 FROM public.deeds WHERE detail='blocked:filter') OR (SELECT charges->>'filter' FROM office_private.toolkits WHERE actor='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' AND week=public.week_key())<>'1' THEN RAISE EXCEPTION 'filter did not block exactly once'; END IF;
 IF EXISTS(SELECT 1 FROM public.players employee,jsonb_array_elements(employee.buffs) b WHERE employee.id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' AND b->>'kind'='replyall') THEN RAISE EXCEPTION 'blocked debuff landed'; END IF;
 -- Permissions and privacy are database-enforced, not just hidden buttons.
 IF has_function_privilege('anon','public.office_interact(uuid,text,uuid)','EXECUTE') OR has_function_privilege('authenticated','office_private.project_credit(uuid,text)','EXECUTE') OR has_table_privilege('authenticated','office_private.action_history','SELECT') THEN RAISE EXCEPTION 'unsafe grants'; END IF;
 PERFORM set_config('request.jwt.claim.sub','',true);rejected:=false;BEGIN PERFORM public.office_profile(uid,'lifetime',NULL);EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'anonymous profile';END IF;PERFORM set_config('request.jwt.claim.sub',uid::text,true);
 SELECT count(*) INTO n FROM office_private.action_history;
 PERFORM public.season_wipe();
 IF (SELECT count(*) FROM office_private.action_history)<>n OR EXISTS(SELECT 1 FROM public.deeds) OR EXISTS(SELECT 1 FROM public.players WHERE seniority_earned<>0 OR equity<>0) THEN RAISE EXCEPTION 'Friday history or Seniority reset incorrect'; END IF;
 SELECT * INTO p FROM public.players WHERE id=uid;
 IF jsonb_array_length(p.office_collectibles)<>3 OR public.permanent_price_rate(p)<anchor THEN RAISE EXCEPTION 'Friday removed ownership or price anchor'; END IF;
 IF NOT EXISTS(SELECT 1 FROM office_private.project_completions) THEN RAISE EXCEPTION 'project history reset'; END IF;
 -- Pacific Friday boundary, including standard/daylight time, belongs to one week only.
 IF public.week_key('2026-11-13 23:59:59Z')=public.week_key('2026-11-14 00:00:00Z') OR public.week_key('2026-10-30 22:59:59Z')=public.week_key('2026-10-30 23:00:00Z') THEN RAISE EXCEPTION 'Friday attribution failed'; END IF;
 RAISE NOTICE 'PASS next-week: exact backfill/privacy, actual Seniority functions, cover/pricing, project/claims, tools/replays/filter, grants and reset persistence';
END $test$;
ROLLBACK;
