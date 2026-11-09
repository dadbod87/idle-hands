-- Disposable database only; never run on Production.
BEGIN;
DO $$ BEGIN IF current_database()<>'idle_hands_test' THEN RAISE EXCEPTION 'isolated database required'; END IF; END $$;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS name text DEFAULT 'QA', ADD COLUMN IF NOT EXISTS last_deed timestamptz, ADD COLUMN IF NOT EXISTS dept text, ADD COLUMN IF NOT EXISTS outfit jsonb, ADD COLUMN IF NOT EXISTS notoriety int DEFAULT 0, ADD COLUMN IF NOT EXISTS heat int DEFAULT 0, ADD COLUMN IF NOT EXISTS busted int DEFAULT 0, ADD COLUMN IF NOT EXISTS tally jsonb DEFAULT '{}', ADD COLUMN IF NOT EXISTS perks jsonb DEFAULT '{}';
ALTER TABLE public.deeds ADD COLUMN IF NOT EXISTS actor uuid, ADD COLUMN IF NOT EXISTS target uuid, ADD COLUMN IF NOT EXISTS kind text, ADD COLUMN IF NOT EXISTS detail text;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT id FROM public.players ORDER BY id LIMIT 1 $$;
CREATE OR REPLACE FUNCTION public.accrue(p_id uuid) RETURNS public.players LANGUAGE sql AS $$SELECT * FROM public.players WHERE id=p_id$$;
CREATE OR REPLACE FUNCTION public.perk_of(p public.players,k text) RETURNS int LANGUAGE sql IMMUTABLE AS $$SELECT coalesce((p.perks->>k)::int,0)$$;
CREATE OR REPLACE FUNCTION public.costume_price(p public.players,c double precision) RETURNS double precision LANGUAGE sql STABLE AS $$SELECT 100::float8$$;
CREATE OR REPLACE FUNCTION public.bump_today(p_id uuid,k text,n int) RETURNS void LANGUAGE plpgsql AS $$BEGIN END$$;
CREATE TABLE IF NOT EXISTS public.catalog(key text PRIMARY KEY,data jsonb);
INSERT INTO public.catalog(key,data) VALUES('costumes','[{"id":"party","cost":1,"mins":45}]') ON CONFLICT(key) DO UPDATE SET data=excluded.data;
\i tests/fixtures/silver-dress-baseline.sql
\i supabase/migrations/20261109161639_silver_tongue_costume_cooldown.sql
DO $$ DECLARE lv int; boundary int; t uuid; rejected boolean; BEGIN
 SELECT id INTO t FROM public.players WHERE id<>auth.uid() LIMIT 1;
 IF t IS NULL THEN RAISE EXCEPTION 'second fixture player required'; END IF;
 FOR lv IN 0..3 LOOP
 boundary:=(5-lv)*60;
 UPDATE public.players SET pp=10000,perks=jsonb_build_object('silver_tongue',lv),last_deed=now()-make_interval(secs=>boundary-1),tally='{}',heat=0,notoriety=0,busted=0 WHERE id=auth.uid();
 rejected:=false;BEGIN PERFORM public.dress(t,'party');EXCEPTION WHEN others THEN IF SQLERRM<>'cooling off' THEN RAISE;END IF;rejected:=true;END;
 IF NOT rejected OR (SELECT pp FROM public.players WHERE id=auth.uid())<>10000 THEN RAISE EXCEPTION 'early action charged/allowed';END IF;
 UPDATE public.players SET last_deed=now()-make_interval(secs=>boundary) WHERE id=auth.uid();
 PERFORM public.dress(t,'party');
 IF (SELECT pp FROM public.players WHERE id=auth.uid())<>9800 THEN RAISE EXCEPTION 'boundary payment mismatch';END IF;
 -- Self-costume remains allowed even immediately after a coworker action.
 PERFORM public.dress(auth.uid(),'party');
 IF (SELECT pp FROM public.players WHERE id=auth.uid())<>9700 THEN RAISE EXCEPTION 'self exemption/payment changed';END IF;
 END LOOP;
 RAISE NOTICE 'PASS actual dress: levels 0-3, early rejection without charge, exact expiry, self exemption';
 END $$;
ROLLBACK;
