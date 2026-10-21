-- Isolated PostgreSQL only, after wardrobe-rpc-contract.sql. Never run on Production.
ALTER TABLE public.players ADD COLUMN goodwill integer DEFAULT 0,
 ADD COLUMN kind_received integer DEFAULT 0, ADD COLUMN tally jsonb DEFAULT '{}'::jsonb,
 ADD COLUMN kit jsonb DEFAULT '{}'::jsonb, ADD COLUMN streak integer DEFAULT 0,
 ADD COLUMN cow jsonb DEFAULT '[]'::jsonb, ADD COLUMN achievements jsonb DEFAULT '[]'::jsonb,
 ADD COLUMN owned jsonb DEFAULT '{}'::jsonb, ADD COLUMN equity integer DEFAULT 0;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('test.employee_id',true),'')::uuid $$;
SELECT set_config('test.employee_id','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false);
INSERT INTO public.players(id,pp) VALUES('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',999);
\i supabase/migrations/20261021163031_office_recognition.sql
DO $tests$
DECLARE p public.players; rejected boolean;
BEGIN
 IF has_function_privilege('anon','public.claim_office_awards()','EXECUTE') OR has_function_privilege('anon','public.save_achievements(jsonb)','EXECUTE') OR has_function_privilege('authenticated','public.office_award_ids(public.players)','EXECUTE') THEN RAISE EXCEPTION 'Award grants too broad'; END IF;
 UPDATE public.players SET pp=1234,spent=42,equity=2,owned='{"intern":2}',achievements='["a1","legacy_keep"]',wardrobe_owned='["blazer","blazer","blazer"]',cow='["pig","pig","pig"]',goodwill=2,kind_received=4,streak=6,tally='{"coffee":1,"hype":1,"cover":0}',kit='{"desk":"d1","chair":"c1","rug":"r1","art":null}' WHERE id=auth.uid();
 PERFORM public.save_achievements('["a2","oa_welcome","oa_invented"]');
 SELECT * INTO p FROM public.players WHERE id=auth.uid();
 IF NOT p.achievements ?& ARRAY['a1','a2','legacy_keep'] OR EXISTS(SELECT 1 FROM jsonb_array_elements_text(p.achievements) AS a(id) WHERE left(id,3)='oa_') THEN RAISE EXCEPTION 'Legacy lost or forged/duplicate/below-threshold awards accepted'; END IF;
 rejected:=false; BEGIN PERFORM public.save_achievements('[{}]'); EXCEPTION WHEN others THEN rejected:=true; END;
 IF NOT rejected THEN RAISE EXCEPTION 'Invalid list element accepted'; END IF;
 rejected:=false; BEGIN PERFORM public.save_achievements('{}'); EXCEPTION WHEN others THEN rejected:=true; END;
 IF NOT rejected THEN RAISE EXCEPTION 'Invalid list accepted'; END IF;
 UPDATE public.players SET goodwill=3 WHERE id=auth.uid(); p:=public.claim_office_awards();
 IF NOT p.achievements ? 'oa_welcome' OR p.achievements ? 'oa_glue' THEN RAISE EXCEPTION 'Welcome threshold wrong'; END IF;
 UPDATE public.players SET goodwill=5,kind_received=5,tally='{"coffee":1,"hype":1,"cover":1}',wardrobe_owned='["blazer","hoodie","cardigan"]',cow='["pig","moth","calf"]',streak=7,kit='{"desk":"d1","chair":"c1","rug":"r1","art":"w1"}' WHERE id=auth.uid();
 p:=public.claim_office_awards();
 IF jsonb_array_length(public.office_award_ids(p))<>7 OR p.achievements ? 'oa_glue' THEN RAISE EXCEPTION 'Eligibility thresholds wrong'; END IF;
 UPDATE public.players SET goodwill=15 WHERE id=auth.uid(); p:=public.claim_office_awards();
 IF jsonb_array_length(public.office_award_ids(p))<>8 THEN RAISE EXCEPTION 'Not all eight awards claimed'; END IF;
 IF p.pp<>1234 OR p.spent<>42 OR p.equity<>2 OR p.owned->>'intern'<>'2' THEN RAISE EXCEPTION 'Awards changed economy/progress'; END IF;
 UPDATE public.players SET goodwill=0,kind_received=0,tally='{}',streak=0,cow='[]',kit='{}',wardrobe_owned='[]' WHERE id=auth.uid();
 PERFORM public.save_achievements('[]'); p:=public.claim_office_awards();
 IF jsonb_array_length(p.achievements)<>11 THEN RAISE EXCEPTION 'Previously earned awards lost or duplicated'; END IF;
 IF EXISTS(SELECT 1 FROM public.players WHERE id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' AND (pp<>999 OR achievements<>'[]'::jsonb)) THEN RAISE EXCEPTION 'Other employee changed'; END IF;
 PERFORM set_config('test.employee_id','',false);
 rejected:=false; BEGIN PERFORM public.claim_office_awards(); EXCEPTION WHEN others THEN rejected:=true; END;
 IF NOT rejected THEN RAISE EXCEPTION 'Unsigned claim allowed'; END IF;
 RAISE NOTICE 'PASS: eight server-qualified awards, boundaries, distinct collections, forgery rejection, additive persistence, auth and unchanged economy';
END $tests$;
