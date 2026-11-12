\set ON_ERROR_STOP on
DO $$ BEGIN IF current_database()<>'idle_hands_test' THEN RAISE EXCEPTION 'disposable database required';END IF;END $$;
\i tests/fixtures/appearance-baseline.sql
\i tests/fixtures/costume-price-baseline.sql
REVOKE ALL ON FUNCTION public.set_look(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.set_look(jsonb) TO authenticated;
-- This adapter is isolated-test plumbing for real PostgREST JWT claim settings.
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT coalesce(nullif(current_setting('request.jwt.claim.sub',true),''),nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub')::uuid
$$;
DO $$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ih_api') THEN CREATE ROLE ih_api LOGIN NOINHERIT PASSWORD 'isolated-api-test-only';END IF;END $$;
GRANT authenticated,anon TO ih_api;
GRANT USAGE ON SCHEMA public,auth TO authenticated,anon;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon,authenticated;
GRANT SELECT ON public.players TO authenticated;
ALTER TABLE public.players ENABLE ROW LEVEL SECURITY;
CREATE POLICY isolated_own_player ON public.players FOR SELECT TO authenticated USING(id=auth.uid());
-- Complete a season using the actual rollover, then leave synthetic funds for API checks.
UPDATE public.players SET week_pp=CASE WHEN name='Fixture A' THEN 500 WHEN name='Fixture B' THEN 250 ELSE 100 END;
UPDATE public.season_state SET current_week=public.week_key(now()-interval '7 days');
SELECT public.roll_week();
UPDATE public.players SET pp=1e9,owned='{}',last_tick=now(),last_deed=null;
NOTIFY pgrst,'reload schema';
