\set ON_ERROR_STOP on
\i tests/next-week-contract.sql
-- Restore the actual production integrator before exercising the guarded patch.
\i tests/fixtures/confetti-accrual-baseline.sql
UPDATE public.players SET office_confetti=jsonb_build_object('until',now()+interval '10 minutes'),buffs='[]' WHERE name='Fixture B';
CREATE TEMP TABLE confetti_install_players AS SELECT id,to_jsonb(p) body FROM public.players p;
\i sql/confetti_output_penalty.sql
DO $$BEGIN IF EXISTS(SELECT 1 FROM public.players p JOIN confetti_install_players b USING(id) WHERE to_jsonb(p)<>b.body) THEN RAISE EXCEPTION 'installation changed players';END IF;END$$;
BEGIN;
DO $test$
DECLARE a uuid:='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';b uuid:='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';c uuid:='cccccccc-cccc-4ccc-cccc-cccccccccccc';
 req uuid:=gen_random_uuid();r jsonb;r2 jsonb;p public.players;base public.players;v public.players;before_balance float8;actual float8;expected float8;n int;rejected boolean;deed_id bigint;t0 timestamptz:='2026-11-14 04:10:00Z';
BEGIN
 -- Fixtures only. All actual RPCs and migration bodies run in this disposable DB.
 SELECT id INTO c FROM public.players WHERE name='Fixture C';
 UPDATE public.players SET pp=1e6,buffs='[]',office_confetti=NULL,dept=NULL,heat=0,perks='{}',last_tick=now(),last_deed=NULL,frenzy_until=NULL;
 INSERT INTO office_private.toolkits(actor,week) SELECT id,public.week_key() FROM public.players ON CONFLICT DO NOTHING;
 UPDATE office_private.toolkits SET slots=ARRAY['rescue','confetti'],charges='{"rescue":2,"confetti":2,"filter":2,"clip":2}';
 UPDATE office_private.shields SET armed=false;
 PERFORM set_config('request.jwt.claim.sub',a::text,true);
 SELECT pp INTO before_balance FROM public.players WHERE id=b;
 r:=public.office_interact(b,'confetti',req);r2:=public.office_interact(b,'confetti',req);
 IF r<>r2 OR (SELECT charges->>'confetti' FROM office_private.toolkits WHERE actor=a AND week=public.week_key())<>'1' THEN RAISE EXCEPTION 'confetti replay charged twice';END IF;
 SELECT * INTO v FROM public.players WHERE id=b;
 IF (v.buffs->0->>'mult')::float8<>0.65 OR (v.buffs->0->>'start')::timestamptz<>now() OR (v.buffs->0->>'until')::timestamptz<>now()+interval '10 minutes' OR v.pp<>before_balance THEN RAISE EXCEPTION 'wrong penalty window or wallet drained';END IF;
 base:=jsonb_populate_record(v,'{"buffs":[]}'::jsonb);
 IF abs(public.live_mult(v)/public.live_mult(base)-0.65)>1e-10 THEN RAISE EXCEPTION 'live output not reduced';END IF;
 IF (SELECT heat FROM public.players WHERE id=a)<>1 OR (SELECT notoriety FROM public.players WHERE id=a)<>1 THEN RAISE EXCEPTION 'sabotage heat missing';END IF;
 SELECT max(id) INTO deed_id FROM public.deeds WHERE actor=a;
 IF (SELECT category FROM office_private.action_history WHERE source_deed=deed_id)<>'sabotage' OR NOT EXISTS(SELECT 1 FROM office_private.project_stamps WHERE actor=a AND week=public.week_key() AND category='playful') THEN RAISE EXCEPTION 'history or project category wrong';END IF;
 IF office_private.action_category('confetti','Confetti delivered. No income penalty.')<>'playful' THEN RAISE EXCEPTION 'legacy cosmetic actions reclassified';END IF;
 UPDATE public.players SET buffs=buffs||jsonb_build_object('kind','meeting','mult',0.5,'until',now()+interval '1 hour') WHERE id=b RETURNING * INTO v;
 IF abs(public.live_mult(v)/public.live_mult(base)-0.325)>1e-10 THEN RAISE EXCEPTION 'ordinary sabotage stopped stacking';END IF;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);rejected:=false;
 BEGIN PERFORM public.office_interact(b,'confetti',gen_random_uuid());EXCEPTION WHEN others THEN rejected:=true;END;
 IF NOT rejected OR (SELECT charges->>'confetti' FROM office_private.toolkits WHERE actor=c AND week=public.week_key())<>'2' THEN RAISE EXCEPTION 'duplicate desk cost a charge';END IF;
 PERFORM set_config('request.jwt.claim.sub',b::text,true);p:=public.office_clear_confetti();
 IF p.office_confetti IS NOT NULL OR jsonb_array_length(p.buffs)<>1 OR p.buffs->0->>'kind'<>'meeting' THEN RAISE EXCEPTION 'cleanup left penalty or removed another sabotage';END IF;
 PERFORM set_config('request.jwt.claim.sub',a::text,true);UPDATE public.players SET last_deed=NULL WHERE id=a;
 PERFORM public.office_interact(b,'confetti',gen_random_uuid());
 PERFORM set_config('request.jwt.claim.sub',c::text,true);PERFORM public.office_interact(b,'rescue',gen_random_uuid());
 SELECT * INTO v FROM public.players WHERE id=b;
 IF v.office_confetti IS NOT NULL OR EXISTS(SELECT 1 FROM jsonb_array_elements(v.buffs) x WHERE x->>'kind'='confetti') OR jsonb_array_length(v.buffs)<>1 THEN RAISE EXCEPTION 'rescue did not clear matching confetti';END IF;
 -- Passive defenses, active filter and reflection order.
 UPDATE public.players SET buffs='[]',office_confetti=NULL,last_deed=NULL,heat=0;
 UPDATE office_private.toolkits SET charges='{"rescue":2,"confetti":2,"filter":2,"clip":2}';
 UPDATE public.players SET dept='systems',perks='{"thick_skin":2}' WHERE id=b;
 PERFORM set_config('request.jwt.claim.sub',a::text,true);PERFORM public.office_interact(b,'confetti',gen_random_uuid());
 SELECT * INTO v FROM public.players WHERE id=b;
 IF abs((v.buffs->0->>'mult')::float8-0.895)>1e-10 THEN RAISE EXCEPTION 'passive defenses ignored';END IF;
 PERFORM set_config('request.jwt.claim.sub',b::text,true);PERFORM public.office_clear_confetti();
 UPDATE office_private.toolkits SET slots=ARRAY['filter','clip'] WHERE actor=b;
 UPDATE public.players SET last_deed=NULL WHERE id=a;
 PERFORM set_config('request.jwt.claim.sub',a::text,true);r:=public.office_interact(b,'confetti',gen_random_uuid());
 IF r->>'detail'<>'blocked:filter' OR (SELECT office_confetti FROM public.players WHERE id=b) IS NOT NULL OR (SELECT charges->>'filter' FROM office_private.toolkits WHERE actor=b AND week=public.week_key())<>'1' THEN RAISE EXCEPTION 'filter did not block confetti once';END IF;
 UPDATE public.players SET last_deed=NULL WHERE id=a;
 UPDATE office_private.toolkits SET charges=jsonb_set(charges,'{confetti}','2') WHERE actor=a;
 INSERT INTO office_private.shields(actor,week,armed) VALUES(a,public.week_key(),true),(b,public.week_key(),true) ON CONFLICT(actor,week) DO UPDATE SET armed=true;
 r:=public.office_interact(b,'confetti',gen_random_uuid());
 IF NOT (r->>'reflected')::boolean OR (SELECT office_confetti FROM public.players WHERE id=a) IS NULL OR (SELECT office_confetti FROM public.players WHERE id=b) IS NOT NULL
 OR NOT (SELECT armed FROM office_private.shields WHERE actor=a AND week=public.week_key()) OR (SELECT armed FROM office_private.shields WHERE actor=b AND week=public.week_key())
 OR (SELECT charges->>'filter' FROM office_private.toolkits WHERE actor=b AND week=public.week_key())<>'1' THEN RAISE EXCEPTION 'reflection chained or spent another defense';END IF;
 SELECT max(id) INTO deed_id FROM public.deeds WHERE actor=a;
 IF (SELECT category FROM office_private.action_history WHERE source_deed=deed_id)<>'blocked' OR NOT EXISTS(SELECT 1 FROM office_private.reflections WHERE source_deed=deed_id AND sender=a AND defender=b) THEN RAISE EXCEPTION 'reflection history wrong';END IF;
 -- Actual interval integration must split at both the new buff start and expiry.
 SELECT * INTO p FROM public.players WHERE id=a;p:=jsonb_populate_record(p,'{"buffs":[],"frenzy_until":null,"heat":0}'::jsonb);base:=p;
 p.buffs:=jsonb_build_array(jsonb_build_object('kind','confetti','mult',0.65,'start',t0,'until',t0+interval '10 minutes'));
 actual:=public.accrual_interval_gain(p,t0-interval '10 minutes',t0+interval '20 minutes');
 expected:=public.accrual_interval_gain(base,t0-interval '10 minutes',t0)+public.accrual_interval_gain(p,t0,t0+interval '10 minutes')+public.accrual_interval_gain(base,t0+interval '10 minutes',t0+interval '20 minutes');
 IF abs(actual-expected)>greatest(1e-6,abs(expected)*1e-10) THEN RAISE EXCEPTION 'offline expiry repriced unpenalized time';END IF;
 IF abs(public.accrual_interval_gain(p,t0+interval '10 minutes',t0+interval '20 minutes')-public.accrual_interval_gain(base,t0+interval '10 minutes',t0+interval '20 minutes'))>1e-6 THEN RAISE EXCEPTION 'penalty persisted after expiry';END IF;
 IF public.office_week_status()#>>'{confetti_rules,mult}'<>'0.65' THEN RAISE EXCEPTION 'rules projection mismatch';END IF;
 IF has_function_privilege('anon','public.office_interact(uuid,text,uuid)','EXECUTE') OR has_function_privilege('authenticated','office_private.capture_deed()','EXECUTE') THEN RAISE EXCEPTION 'private function exposed';END IF;
 RAISE NOTICE 'PASS confetti output: atomic replay, no wallet drain, positive stacking, cooldown/charges, passive/filter/reflection/rescue/cleanup, honest history and actual offline boundaries';
END $test$;
ROLLBACK;
