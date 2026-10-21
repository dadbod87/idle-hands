-- Additive appearance-only RPC extension. No rows or balances modified on install.
CREATE OR REPLACE FUNCTION public.set_look(p_look jsonb)
RETURNS public.players LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $body$
DECLARE p public.players; v jsonb; garment text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 IF p_look IS NULL OR jsonb_typeof(p_look) <> 'object' THEN RAISE EXCEPTION 'invalid avatar'; END IF;
 SELECT * INTO p FROM public.players WHERE id=auth.uid() FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'no employee'; END IF;
 v:=jsonb_build_object(
 'build',coalesce(p_look->>'build','regular'),
 'bottom',coalesce(p_look->>'bottom','trousers'),
 'top',coalesce(p_look->'top','0'::jsonb),
 'legs',coalesce(p_look->'legs','0'::jsonb),
 'head',coalesce(p_look->>'head',p.look->>'head','classic'),
 'gender',coalesce(p_look->>'gender','neutral'),
 'hair',coalesce(p_look->>'hair','messy'),
 'hairColor',coalesce(p_look->'hairColor','0'::jsonb),
 'skin',coalesce(p_look->'skin','0'::jsonb),
 'eyes',coalesce(p_look->>'eyes','tired'),
 'expression',coalesce(p_look->>'expression','deadpan'),
 'glasses',coalesce(p_look->'glasses','false'::jsonb),
 'clothing',coalesce(p_look->>'clothing','starter'));
 IF v->>'build' NOT IN ('slim','regular','broad') OR
    v->>'bottom' NOT IN ('trousers','skirt','shorts') OR
    v->>'head' NOT IN ('classic','round','square','pear','alien','robot','cyclops','frog','bag') OR
    v->>'gender' NOT IN ('masculine','feminine','neutral') OR
    v->>'hair' NOT IN ('short','messy','long','bun','bob','curly','bald') OR
    v->>'eyes' NOT IN ('tired','bright','wide','sleepy') OR
    v->>'expression' NOT IN ('deadpan','smile','skeptical','happy','surprised')
 THEN RAISE EXCEPTION 'invalid appearance'; END IF;
 IF jsonb_typeof(v->'top')<>'number' OR jsonb_typeof(v->'legs')<>'number' OR
    jsonb_typeof(v->'hairColor')<>'number' OR jsonb_typeof(v->'skin')<>'number' OR
    jsonb_typeof(v->'glasses')<>'boolean'
 THEN RAISE EXCEPTION 'invalid appearance types'; END IF;
 IF (v->>'top')::integer NOT BETWEEN 0 AND 7 OR (v->>'legs')::integer NOT BETWEEN 0 AND 4 OR
    (v->>'hairColor')::integer NOT BETWEEN 0 AND 6 OR (v->>'skin')::integer NOT BETWEEN 0 AND 5
 THEN RAISE EXCEPTION 'invalid palette selection'; END IF;
 garment:=v->>'clothing';
 IF garment<>'starter' AND NOT p.wardrobe_owned ? garment THEN RAISE EXCEPTION 'clothing not purchased'; END IF;
 UPDATE public.players SET look=v WHERE id=p.id RETURNING * INTO p;
 RETURN p;
END
$body$;

REVOKE ALL ON FUNCTION public.set_look(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_look(jsonb) TO authenticated;
