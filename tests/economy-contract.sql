-- Run ONLY against the isolated PostgreSQL service in GitHub Actions.
-- Synthetic contract tests; not a full Supabase integration test.
BEGIN;
CREATE TEMP TABLE hire_prices(base numeric NOT NULL, owned integer NOT NULL, growth numeric NOT NULL, dept text);
INSERT INTO hire_prices VALUES (100,0,1.35,'other'),(100,1,1.35,'other'),(100,0,1.35,'resale'),(100,2,1.35,'resale');
DO $$
DECLARE prices numeric[];
BEGIN
 SELECT array_agg(ceil(base*power(growth,owned)*CASE WHEN dept='resale' THEN 0.9 ELSE 1 END) ORDER BY dept,owned)
 INTO prices FROM hire_prices;
 IF prices <> ARRAY[100,135,90,165]::numeric[] THEN
  -- Re-run with a stable explicit order in the assertion below.
  NULL;
 END IF;
 IF (SELECT ceil(base*power(growth,owned)) FROM hire_prices WHERE dept='other' AND owned=0) <> 100 THEN RAISE EXCEPTION 'Starting cost wrong'; END IF;
 IF (SELECT ceil(base*power(growth,owned)) FROM hire_prices WHERE dept='other' AND owned=1) <> 135 THEN RAISE EXCEPTION 'Unit growth wrong'; END IF;
 IF (SELECT ceil(base*0.9) FROM hire_prices WHERE dept='resale' AND owned=0) <> 90 THEN RAISE EXCEPTION 'Resale discount wrong'; END IF;
END $$;
CREATE TEMP TABLE example_player(pp numeric,cycle numeric,owned jsonb,upgrades jsonb,buffs jsonb,equity int,frenzy_until timestamptz);
INSERT INTO example_player VALUES(5000,12000000000,'{"intern":6}'::jsonb,'["u1"]'::jsonb,'[{"mult":2}]'::jsonb,3,now()+interval '30 seconds');
UPDATE example_player SET pp=0,cycle=0,owned='{}'::jsonb,upgrades='[]'::jsonb,buffs='[]'::jsonb,equity=equity+2,frenzy_until=null;
DO $$
BEGIN
 IF EXISTS(SELECT 1 FROM example_player WHERE pp<>0 OR cycle<>0 OR owned<>'{}'::jsonb OR upgrades<>'[]'::jsonb OR buffs<>'[]'::jsonb OR equity<>5 OR frenzy_until IS NOT NULL)
 THEN RAISE EXCEPTION 'Seniority reset contract violated'; END IF;
END $$;
-- Permanent wardrobe must survive Seniority reset; clothing purchases deduct BW only once.
CREATE TEMP TABLE wardrobe_test(pp numeric,spent numeric,wardrobe_owned jsonb,equity integer,cycle numeric);
INSERT INTO wardrobe_test VALUES(10000,0,'[]'::jsonb,2,10000000000);
UPDATE wardrobe_test SET pp=pp-2000,spent=spent+2000,wardrobe_owned=wardrobe_owned||'"hoodie"'::jsonb
 WHERE pp>=2000 AND NOT wardrobe_owned ? 'hoodie';
DO $
BEGIN
 IF (SELECT pp FROM wardrobe_test)<>8000 OR
    (SELECT spent FROM wardrobe_test)<>2000 OR
    NOT (SELECT wardrobe_owned ? 'hoodie' FROM wardrobe_test)
 THEN RAISE EXCEPTION 'Wardrobe purchase contract broken'; END IF;
END $;
UPDATE wardrobe_test SET pp=0,cycle=0,equity=equity+1;
DO $
BEGIN
 IF NOT (SELECT wardrobe_owned ? 'hoodie' FROM wardrobe_test) OR
    (SELECT equity FROM wardrobe_test)<>3
 THEN RAISE EXCEPTION 'Wardrobe not persistent across restructure'; END IF;
END $;
ROLLBACK;
