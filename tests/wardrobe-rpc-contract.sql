-- Ephemeral PostgreSQL contract harness; NEVER run against Production.
CREATE SCHEMA IF NOT EXISTS auth;
DO $create_role$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated; END IF; IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon; END IF; END $create_role$;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid $$;
CREATE TABLE public.players (
 id uuid PRIMARY KEY,
 pp numeric NOT NULL DEFAULT 0,
 spent numeric NOT NULL DEFAULT 0,
 look jsonb DEFAULT '{}'::jsonb,
 wardrobe_owned jsonb NOT NULL DEFAULT '[]'::jsonb
);
INSERT INTO public.players(id,pp,spent,look) VALUES(auth.uid(),2000000,0,'{"build":"regular","bottom":"trousers","top":0,"legs":0}'::jsonb);
CREATE OR REPLACE FUNCTION public.accrue(p_id uuid) RETURNS public.players LANGUAGE sql AS $$ SELECT * FROM public.players WHERE id=p_id $$;
\i sql/character_wardrobe.sql
\i supabase/migrations/20261021151041_character_heads.sql
DO $tests$
DECLARE p public.players; before_pp numeric; rejected boolean; head_id text;
BEGIN
 IF has_function_privilege('anon','public.set_look(jsonb)','EXECUTE') OR NOT has_function_privilege('authenticated','public.set_look(jsonb)','EXECUTE') THEN RAISE EXCEPTION 'Appearance RPC grants incorrect'; END IF;
 SELECT pp INTO before_pp FROM public.players WHERE id=auth.uid();
 rejected:=false;
 BEGIN PERFORM public.set_look('{"build":"regular","bottom":"trousers","top":0,"legs":0,"clothing":"blazer"}'::jsonb); EXCEPTION WHEN others THEN rejected:=true; END;
 IF NOT rejected THEN RAISE EXCEPTION 'Unpurchased clothing equipped'; END IF;
 rejected:=false;
 BEGIN PERFORM public.buy_wardrobe('unknown'); EXCEPTION WHEN others THEN rejected:=true; END;
 IF NOT rejected THEN RAISE EXCEPTION 'Invalid item purchased'; END IF;
 p:=public.buy_wardrobe('blazer');
 IF p.pp<>before_pp-45000 OR p.spent<>45000 OR NOT p.wardrobe_owned ? 'blazer' THEN RAISE EXCEPTION 'Price / inventory mismatch'; END IF;
 rejected:=false;
 BEGIN PERFORM public.buy_wardrobe('blazer'); EXCEPTION WHEN others THEN rejected:=true; END;
 IF NOT rejected THEN RAISE EXCEPTION 'Double-purchase allowed'; END IF;
 p:=public.set_look('{"build":"slim","bottom":"shorts","top":2,"legs":3,"hair":"curly","hairColor":3,"skin":2,"eyes":"wide","expression":"smile","glasses":true,"gender":"neutral","clothing":"blazer"}'::jsonb);
 IF p.look->>'head'<>'classic' THEN RAISE EXCEPTION 'Legacy head default changed'; END IF;
 IF p.look->>'clothing'<>'blazer' OR p.look->>'hair'<>'curly' THEN RAISE EXCEPTION 'Avatar save failed'; END IF;
 -- Save every head with the real function and retain purchased clothes and balance.
 FOREACH head_id IN ARRAY ARRAY['classic','round','square','pear','alien','robot','cyclops','frog','bag'] LOOP
  p:=public.set_look(jsonb_build_object('head',head_id,'gender','feminine','clothing','blazer'));
  IF p.look->>'head'<>head_id OR p.look->>'gender'<>'feminine' OR p.look->>'clothing'<>'blazer' OR p.pp<>before_pp-45000 THEN RAISE EXCEPTION 'Head persistence changed progress'; END IF;
 END LOOP;
 rejected:=false;
 BEGIN PERFORM public.set_look('{"head":"invalid"}'::jsonb); EXCEPTION WHEN others THEN rejected:=true; END;
 IF NOT rejected THEN RAISE EXCEPTION 'Invalid head accepted'; END IF;
 p:=public.set_look('{"build":"regular"}'::jsonb);
 IF p.look->>'head'<>'bag' THEN RAISE EXCEPTION 'Old client erased new head'; END IF;
 rejected:=false;
 BEGIN PERFORM public.set_look('{"build":"slim","bottom":"shorts","top":900,"legs":3}'::jsonb); EXCEPTION WHEN others THEN rejected:=true; END;
 IF NOT rejected THEN RAISE EXCEPTION 'Out-of-range avatar accepted'; END IF;
 UPDATE public.players SET pp=0 WHERE id=auth.uid();
 IF NOT EXISTS (SELECT 1 FROM public.players WHERE id=auth.uid() AND wardrobe_owned ? 'blazer') THEN RAISE EXCEPTION 'Permanent inventory lost during reset'; END IF;
 RAISE NOTICE 'PASS: purchase, pricing, ownership, equip, avatar persistence, invalid input and reset';
END $tests$;

-- Extend the actual deployed function; installation cannot rewrite players.
CREATE TEMP TABLE photo_before AS SELECT row_to_json(p)::jsonb AS value FROM public.players p;
\i supabase/migrations/20261022192506_custom_photo_head.sql
DO $photo_tests$
DECLARE p public.players; rejected boolean:=false;
BEGIN
 IF (SELECT value FROM photo_before)<>(SELECT row_to_json(p)::jsonb FROM public.players p) THEN RAISE EXCEPTION 'Photo installation changed a player'; END IF;
 IF has_function_privilege('anon','public.set_look(jsonb)','EXECUTE') OR NOT has_function_privilege('authenticated','public.set_look(jsonb)','EXECUTE') THEN RAISE EXCEPTION 'Photo migration changed grants'; END IF;
 p:=public.set_look('{"head":"photo","clothing":"blazer"}');
 IF p.look->>'head'<>'photo' OR p.pp<>0 OR NOT p.wardrobe_owned ? 'blazer' THEN RAISE EXCEPTION 'Photo persistence changed progress'; END IF;
 p:=public.set_look('{"clothing":"blazer"}');IF p.look->>'head'<>'photo' THEN RAISE EXCEPTION 'Older client erased photo selection'; END IF;
 p:=public.set_look('{"head":"frog","clothing":"blazer"}');IF p.look->>'head'<>'frog' THEN RAISE EXCEPTION 'Cannot return to illustrated head'; END IF;
 BEGIN PERFORM public.set_look('{"head":"photo2"}');EXCEPTION WHEN others THEN rejected:=true;END;IF NOT rejected THEN RAISE EXCEPTION 'Unknown photo head accepted'; END IF;
 RAISE NOTICE 'PASS: photo extension, no install writes, grants, persistence, illustrated switch and unchanged progress';
END $photo_tests$;
