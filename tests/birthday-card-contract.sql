-- ONLY the ephemeral CI database. Actual deployed sign_card body + new projection.
BEGIN;
DO $$ BEGIN IF current_database()<>'idle_hands_test' THEN RAISE EXCEPTION 'isolated fixture database required'; END IF; END $$;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS lifetime numeric DEFAULT 0;
ALTER TABLE public.birthday_card ADD COLUMN IF NOT EXISTS signers jsonb NOT NULL DEFAULT '[]',
 ADD COLUMN IF NOT EXISTS pot double precision NOT NULL DEFAULT 0,
 ADD COLUMN IF NOT EXISTS paid boolean NOT NULL DEFAULT false;
CREATE UNIQUE INDEX IF NOT EXISTS fixture_card_week ON public.birthday_card(week_key);
CREATE OR REPLACE FUNCTION public.calc_rate(p public.players) RETURNS double precision LANGUAGE sql STABLE AS $$ SELECT coalesce(nullif(current_setting('test.card_rate',true),''),'2')::double precision $$;
CREATE OR REPLACE FUNCTION public.live_mult(p public.players) RETURNS double precision LANGUAGE sql STABLE AS $$ SELECT 1.5::double precision $$;
CREATE OR REPLACE FUNCTION public.accrue(p_id uuid) RETURNS public.players LANGUAGE sql AS $$ SELECT * FROM public.players WHERE id=p_id $$;
\i tests/fixtures/birthday-card-baseline.sql
CREATE TEMP TABLE card_players_before AS SELECT to_jsonb(p) snapshot FROM public.players p;
CREATE TEMP TABLE card_rows_before AS SELECT to_jsonb(c) snapshot FROM public.birthday_card c;
CREATE TEMP TABLE card_acl_before AS SELECT proacl FROM pg_proc WHERE oid='public.card_state()'::regprocedure;
\i supabase/migrations/20261023163213_birthday_card_state.sql
DO $tests$
BEGIN
 IF (SELECT proacl FROM pg_proc WHERE oid='public.card_state()'::regprocedure) IS DISTINCT FROM (SELECT proacl FROM card_acl_before) THEN RAISE EXCEPTION 'grants changed'; END IF;
 IF EXISTS((SELECT snapshot FROM card_players_before EXCEPT SELECT to_jsonb(p) FROM public.players p) UNION ALL (SELECT to_jsonb(p) FROM public.players p EXCEPT SELECT snapshot FROM card_players_before)) THEN RAISE EXCEPTION 'installation changed players'; END IF;
 IF EXISTS((SELECT snapshot FROM card_rows_before EXCEPT SELECT to_jsonb(c) FROM public.birthday_card c) UNION ALL (SELECT to_jsonb(c) FROM public.birthday_card c EXCEPT SELECT snapshot FROM card_rows_before)) THEN RAISE EXCEPTION 'installation changed card rows'; END IF;
END $tests$;
-- Deliberately different from ISO calendar week: exercise shared week-key routing.
CREATE OR REPLACE FUNCTION public.week_key(ts timestamptz DEFAULT now()) RETURNS text LANGUAGE sql STABLE AS $$ SELECT 'fixture-pacific-week'::text $$;
SELECT set_config('test.employee_id','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false);
UPDATE public.players SET pp=10000,buffs='[]';
DELETE FROM public.birthday_card;
DO $tests$
DECLARE s jsonb; before_pp numeric; n int; reject boolean; share double precision;
BEGIN
 s:=public.card_state();
 IF s->>'week'<>'fixture-pacific-week' OR (s->>'mine')::boolean OR (s->>'paid')::boolean OR (s->>'contribution')::numeric<>720 THEN RAISE EXCEPTION 'initial projection or contribution incorrect: %',s; END IF;
 SELECT pp INTO before_pp FROM public.players WHERE id=auth.uid();
 UPDATE public.players SET pp=719 WHERE id=auth.uid();
 reject:=false;BEGIN PERFORM public.sign_card(); EXCEPTION WHEN raise_exception THEN IF SQLERRM='cannot afford' THEN reject:=true; ELSE RAISE; END IF; END;
 IF NOT reject OR EXISTS(SELECT 1 FROM public.birthday_card) OR (SELECT pp FROM public.players WHERE id=auth.uid())<>719 THEN RAISE EXCEPTION 'insufficient funds must not charge or sign'; END IF;
 UPDATE public.players SET pp=before_pp WHERE id=auth.uid();
 s:=public.sign_card();
 IF NOT (s->>'mine')::boolean OR jsonb_array_length(s->'signers')<>1 OR (s->>'pot')::numeric<>720 OR (SELECT pp FROM public.players WHERE id=auth.uid())<>before_pp-720 THEN RAISE EXCEPTION 'saved signature not reflected or incorrect charge: %',s; END IF;
 reject:=false;BEGIN PERFORM public.sign_card(); EXCEPTION WHEN raise_exception THEN IF SQLERRM='already signed' THEN reject:=true; ELSE RAISE; END IF; END;
 IF NOT reject OR (SELECT pp FROM public.players WHERE id=auth.uid())<>before_pp-720 THEN RAISE EXCEPTION 'duplicate charged'; END IF;
 -- The last signature exercises the actual unchanged payout/cake code.
 DELETE FROM public.birthday_card;
 SELECT count(*) INTO n FROM public.players;
 INSERT INTO public.birthday_card(week_key,signers,pot) SELECT public.week_key(),coalesce(jsonb_agg(id::text),'[]'),10000 FROM public.players WHERE id<>auth.uid();
 SELECT pp INTO before_pp FROM public.players WHERE id=auth.uid();
 s:=public.sign_card();share:=10720.0*2/n;
 IF NOT (s->>'paid')::boolean OR NOT (s->>'mine')::boolean OR jsonb_array_length(s->'signers')<>n OR abs((SELECT pp FROM public.players WHERE id=auth.uid())-(before_pp-720+share))>0.000001 THEN RAISE EXCEPTION 'final signature/payout changed: %',s; END IF;
 IF EXISTS(SELECT 1 FROM public.players WHERE NOT buffs @> '[{"kind":"cake","mult":1.2}]'::jsonb) THEN RAISE EXCEPTION 'cake missing'; END IF;
 PERFORM set_config('test.card_rate','0',false);s:=public.card_state();
 IF (s->>'contribution')::numeric<>50 THEN RAISE EXCEPTION 'minimum cost changed'; END IF;
 PERFORM set_config('test.employee_id','',false);s:=public.card_state();
 IF s->'contribution'<>'null'::jsonb THEN RAISE EXCEPTION 'quote without player'; END IF;
END $tests$;
ROLLBACK;
