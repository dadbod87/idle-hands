-- Free appearance choices; never change ownership, prices or saved finishes.
CREATE FUNCTION public.office_set_cosmetic_visibility(p_slot text,p_visible boolean DEFAULT false)
RETURNS public.players LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();p public.players;next_display jsonb;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'not signed in';END IF;
 IF p_slot IS NULL OR p_visible IS NULL OR p_slot NOT IN('desk','chair','rug','art','tv','held','clothing','pin','glow','aura','size') THEN RAISE EXCEPTION 'choose a valid appearance slot';END IF;
 PERFORM pg_advisory_xact_lock(728194,1);
 SELECT * INTO p FROM public.players WHERE id=u FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'no player';END IF;
 IF p_slot='pin' THEN
  IF p_visible THEN RAISE EXCEPTION 'choose an owned pin to equip';END IF;
  IF p.pin IS NULL THEN RETURN p;END IF;
  UPDATE public.players SET pin=null,cosmetic_revision=cosmetic_revision+1 WHERE id=u RETURNING * INTO p;
 ELSIF p_slot='clothing' THEN
  IF p_visible THEN RAISE EXCEPTION 'choose an owned outfit to equip';END IF;
  IF coalesce(p.look->>'clothing','starter')='starter' THEN RETURN p;END IF;
  UPDATE public.players SET look=jsonb_set(coalesce(look,'{}'::jsonb),'{clothing}','"starter"'::jsonb),cosmetic_revision=cosmetic_revision+1 WHERE id=u RETURNING * INTO p;
 ELSE
  next_display:=CASE WHEN p_visible THEN p.cosmetic_equipped-p_slot ELSE p.cosmetic_equipped||jsonb_build_object(p_slot,null) END;
  IF next_display=p.cosmetic_equipped THEN RETURN p;END IF;
  UPDATE public.players SET cosmetic_equipped=next_display,cosmetic_revision=cosmetic_revision+1 WHERE id=u RETURNING * INTO p;
 END IF;
 RETURN p;
END $$;
REVOKE ALL ON FUNCTION public.office_set_cosmetic_visibility(text,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.office_set_cosmetic_visibility(text,boolean) TO authenticated;
-- Existing upgrade behavior already clears held/furniture display overrides.
-- Extend that behavior to the other cosmetic effects when a higher tier is bought.
CREATE FUNCTION office_private.restore_new_effect() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
DECLARE slot text;
BEGIN
 FOREACH slot IN ARRAY ARRAY['glow','aura','size'] LOOP
  IF NEW.vanity->>slot IS DISTINCT FROM OLD.vanity->>slot THEN NEW.cosmetic_equipped:=NEW.cosmetic_equipped-slot;END IF;
 END LOOP;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION office_private.restore_new_effect() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER office_restore_new_effect BEFORE UPDATE OF vanity ON public.players FOR EACH ROW EXECUTE FUNCTION office_private.restore_new_effect();
