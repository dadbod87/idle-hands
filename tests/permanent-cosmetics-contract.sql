-- Isolated PostgreSQL fixture only. NEVER invoke this contract on Production.
ALTER TABLE public.players
 ADD COLUMN IF NOT EXISTS vanity jsonb DEFAULT '{}', ADD COLUMN IF NOT EXISTS cycle numeric DEFAULT 0, ADD COLUMN IF NOT EXISTS week_pp numeric DEFAULT 0,
 ADD COLUMN IF NOT EXISTS day_pp numeric DEFAULT 0, ADD COLUMN IF NOT EXISTS upgrades jsonb DEFAULT '[]',
 ADD COLUMN IF NOT EXISTS buffs jsonb DEFAULT '[]', ADD COLUMN IF NOT EXISTS perks jsonb DEFAULT '{}',
 ADD COLUMN IF NOT EXISTS raises integer DEFAULT 0, ADD COLUMN IF NOT EXISTS frenzy_until timestamptz,
 ADD COLUMN IF NOT EXISTS heat integer DEFAULT 0, ADD COLUMN IF NOT EXISTS busted integer DEFAULT 0,
 ADD COLUMN IF NOT EXISTS notoriety integer DEFAULT 0, ADD COLUMN IF NOT EXISTS hush integer DEFAULT 0,
 ADD COLUMN IF NOT EXISTS quits integer DEFAULT 0, ADD COLUMN IF NOT EXISTS grabs integer DEFAULT 0,
 ADD COLUMN IF NOT EXISTS rivalries integer DEFAULT 0, ADD COLUMN IF NOT EXISTS hits jsonb DEFAULT '{}',
 ADD COLUMN IF NOT EXISTS today jsonb DEFAULT '{}', ADD COLUMN IF NOT EXISTS contracts jsonb,
 ADD COLUMN IF NOT EXISTS mail jsonb, ADD COLUMN IF NOT EXISTS last_checkin timestamptz,
 ADD COLUMN IF NOT EXISTS nickname jsonb, ADD COLUMN IF NOT EXISTS outfit jsonb, ADD COLUMN IF NOT EXISTS ooo text,
 ADD COLUMN IF NOT EXISTS last_restructure timestamptz, ADD COLUMN IF NOT EXISTS last_deed timestamptz,
 ADD COLUMN IF NOT EXISTS last_nick timestamptz, ADD COLUMN IF NOT EXISTS last_vend timestamptz,
 ADD COLUMN IF NOT EXISTS last_break timestamptz, ADD COLUMN IF NOT EXISTS last_work timestamptz,
 ADD COLUMN IF NOT EXISTS last_tick timestamptz, ADD COLUMN IF NOT EXISTS extras jsonb DEFAULT '[]',
 ADD COLUMN IF NOT EXISTS pin text, ADD COLUMN IF NOT EXISTS pet text, ADD COLUMN IF NOT EXISTS trophies integer DEFAULT 0;
CREATE TABLE public.deeds(id uuid);
CREATE TABLE public.chair_claims(window_id integer);
CREATE TABLE public.printer_claims(window_id integer);
CREATE TABLE public.meeting_claims(window_id integer);
CREATE TABLE public.birthday_card(week_key text);
UPDATE public.players SET pp=1234,cycle=1200,week_pp=3000,day_pp=500,equity=2,owned='{"intern":2}',
 kit='{"desk":"d4","chair":"c2","rug":"r3","art":"w1"}',vanity='{"glow":"g2","held":"h1"}',spent=42000,
 wardrobe_owned='["hoodie"]',extras='["beta","p01"]',pin='beta',pet='pig',cow='["pig","moth"]',achievements='["oa_welcome"]',trophies=3;
CREATE TEMP TABLE keep_cosmetics AS SELECT id,kit,vanity,spent,wardrobe_owned,extras,pin,pet,cow,achievements,trophies FROM public.players;
\i supabase/migrations/20261021193821_preserve_permanent_cosmetics.sql
CREATE FUNCTION public.test_season_rollover() RETURNS int LANGUAGE sql SECURITY DEFINER SET search_path TO '' AS $$ SELECT public.season_wipe() $$;
DO $tests$
DECLARE affected int;
BEGIN
 IF has_function_privilege('anon','public.season_wipe()','EXECUTE') OR has_function_privilege('authenticated','public.season_wipe()','EXECUTE') THEN RAISE EXCEPTION 'Internal reset exposed to game clients'; END IF;
 -- Installing the migration itself must not reset anyone.
 IF EXISTS(SELECT 1 FROM public.players WHERE pp<>1234 OR week_pp<>3000) THEN RAISE EXCEPTION 'Migration reset players during installation'; END IF;
 affected:=public.test_season_rollover(); -- Synthetic rows only, in this isolated CI database.
 IF affected<>(SELECT count(*) FROM keep_cosmetics) OR (SELECT count(*) FROM public.players)<>affected THEN RAISE EXCEPTION 'Player rows lost'; END IF;
 IF EXISTS(SELECT 1 FROM public.players WHERE pp<>0 OR week_pp<>0 OR day_pp<>0 OR equity<>0 OR owned<>'{}'::jsonb) THEN RAISE EXCEPTION 'Intended seasonal economy reset changed'; END IF;
 IF EXISTS(SELECT 1 FROM public.players p JOIN keep_cosmetics k USING(id) WHERE
  ROW(p.kit,p.vanity,p.spent,p.wardrobe_owned,p.extras,p.pin,p.pet,p.cow,p.achievements,p.trophies)
  IS DISTINCT FROM ROW(k.kit,k.vanity,k.spent,k.wardrobe_owned,k.extras,k.pin,k.pet,k.cow,k.achievements,k.trophies)) THEN RAISE EXCEPTION 'Permanent cosmetics or collections lost'; END IF;
 RAISE NOTICE 'PASS: installation never resets players; real season function preserves cosmetics/spending/collections while seasonal earnings reset';
END $tests$;

-- Premium TV shares the permanent kit contract; stays isolated from Production.
\i tests/premium-tv-contract.sql
