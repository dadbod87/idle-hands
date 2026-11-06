-- Additive cosmetic styles. No currency grants, resets, purchase-price changes or player backfill.
ALTER TABLE public.players
 ADD COLUMN cosmetic_styles jsonb NOT NULL DEFAULT '{}'::jsonb,
 ADD COLUMN cosmetic_equipped jsonb NOT NULL DEFAULT '{}'::jsonb,
 ADD COLUMN cosmetic_revision bigint NOT NULL DEFAULT 0;
CREATE TABLE public.style_quotes (
 player_id uuid PRIMARY KEY REFERENCES public.players(id) ON DELETE CASCADE,
 id uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
 item text NOT NULL, color text, design text NOT NULL,
 color_fee double precision NOT NULL, design_fee double precision NOT NULL,
 rate double precision NOT NULL, revision bigint NOT NULL, week text NOT NULL,
 expires_at timestamptz NOT NULL, applied boolean NOT NULL DEFAULT false
);
ALTER TABLE public.style_quotes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.style_quotes FROM PUBLIC,anon,authenticated;

-- Internal ownership resolver. Highest-tier records remain the authoritative unlocks;
-- selecting an earlier cosmetic never lowers them or unlocks the next tier early.
CREATE FUNCTION public.style_item_info(p public.players,p_item text) RETURNS jsonb
LANGUAGE plpgsql STABLE SET search_path='' AS $$
DECLARE it jsonb; kind text; have text; highest int;
BEGIN
 IF left(p_item,4)='pin:' THEN
  IF NOT coalesce(p.extras,'[]'::jsonb) ? substr(p_item,5) THEN RAISE EXCEPTION 'pin not owned'; END IF;
  RETURN jsonb_build_object('kind','pin','slot','pin');
 END IF;
 IF p_item IN ('starter','hoodie','cardigan','blazer','hawaiian','hoodie_gold','friday') THEN
  IF p_item<>'starter' AND NOT coalesce(p.wardrobe_owned,'[]'::jsonb) ? p_item THEN RAISE EXCEPTION 'item not owned'; END IF;
  RETURN jsonb_build_object('kind','wardrobe','slot','clothing');
 END IF;
 SELECT c.key,v.value INTO kind,it FROM public.catalog c CROSS JOIN LATERAL jsonb_array_elements(c.data) v(value)
 WHERE c.key IN ('office_kit','vanity') AND v.value->>'id'=p_item;
 IF it IS NULL OR it->>'slot' NOT IN ('desk','chair','rug','art','tv','held') THEN RAISE EXCEPTION 'not a physical catalogue item'; END IF;
 have:=CASE WHEN kind='office_kit' THEN p.kit->>(it->>'slot') ELSE p.vanity->>(it->>'slot') END;
 SELECT (v.value->>'tier')::int INTO highest FROM public.catalog c CROSS JOIN LATERAL jsonb_array_elements(c.data) v(value)
 WHERE c.key=kind AND v.value->>'id'=have;
 -- The standard desk and chair are already visible in every new employee's office.
 IF NOT (p_item IN ('d1','c1')) AND coalesce(highest,0)<(it->>'tier')::int THEN RAISE EXCEPTION 'item not owned'; END IF;
 RETURN jsonb_build_object('kind',kind,'slot',it->>'slot');
END $$;
REVOKE ALL ON FUNCTION public.style_item_info(public.players,text) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.quote_style(p_item text,p_color text,p_design text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.players; old jsonb; q public.style_quotes; unit double precision; r double precision; cf double precision; df double precision;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 IF p_color IS NOT NULL AND p_color !~ '^#[0-9a-fA-F]{6}$' THEN RAISE EXCEPTION 'invalid color'; END IF;
 IF p_design IS NULL OR p_design NOT IN ('solid','stripe','check','dots','sparkle','confetti') THEN RAISE EXCEPTION 'invalid design'; END IF;
 SELECT * INTO p FROM public.players WHERE id=auth.uid() FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'no employee'; END IF;
 PERFORM public.style_item_info(p,p_item);
 old:=coalesce(p.cosmetic_styles->p_item,'{"color":null,"design":"solid"}'::jsonb);
 r:=public.calc_rate(p)*public.live_mult(p);
 IF r::text IN ('NaN','Infinity','-Infinity') OR r<0 THEN RAISE EXCEPTION 'output unavailable'; END IF;
 unit:=greatest(1000,ceil(r*86400));
 cf:=CASE WHEN (old->>'color') IS DISTINCT FROM lower(p_color) THEN unit ELSE 0 END;
 -- Removing a pattern is free; adding/changing one is a separate day of output.
 df:=CASE WHEN coalesce(old->>'design','solid')<>p_design AND p_design<>'solid' THEN unit ELSE 0 END;
 INSERT INTO public.style_quotes(player_id,item,color,design,color_fee,design_fee,rate,revision,week,expires_at)
 VALUES(p.id,p_item,lower(p_color),p_design,cf,df,r,p.cosmetic_revision,public.week_key(),now()+interval '2 minutes')
 ON CONFLICT(player_id) DO UPDATE SET id=gen_random_uuid(),item=excluded.item,color=excluded.color,design=excluded.design,
 color_fee=excluded.color_fee,design_fee=excluded.design_fee,rate=excluded.rate,revision=excluded.revision,week=excluded.week,expires_at=excluded.expires_at,applied=false
 RETURNING * INTO q;
 RETURN jsonb_build_object('id',q.id,'item',q.item,'color',q.color,'design',q.design,'color_fee',cf,'design_fee',df,'total',cf+df,'rate',r,'expires_at',q.expires_at,'balance',p.pp);
END $$;
REVOKE ALL ON FUNCTION public.quote_style(text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.quote_style(text,text,text) TO authenticated;

CREATE FUNCTION public.apply_style(p_quote uuid) RETURNS public.players
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.players; q public.style_quotes; r double precision; total double precision;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 -- Follow the game's existing accrual/weekly lock order, then serialize on the player.
 p:=public.accrue(auth.uid());
 SELECT * INTO p FROM public.players WHERE id=auth.uid() FOR UPDATE;
 SELECT * INTO q FROM public.style_quotes WHERE player_id=p.id AND id=p_quote FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'quote replaced; review a fresh quote'; END IF;
 IF q.applied THEN RETURN p; END IF; -- Same accepted request is safe to retry.
 IF q.expires_at<=now() OR q.week<>public.week_key() OR q.revision<>p.cosmetic_revision THEN RAISE EXCEPTION 'quote expired; review a fresh quote'; END IF;
 PERFORM public.style_item_info(p,q.item);
 r:=public.calc_rate(p)*public.live_mult(p);
 IF r::text IN ('NaN','Infinity','-Infinity') OR abs(r-q.rate)>greatest(0.000000001,abs(q.rate)*0.000000001) THEN RAISE EXCEPTION 'output changed; review a fresh quote'; END IF;
 total:=q.color_fee+q.design_fee;
 IF p.pp<total THEN RAISE EXCEPTION 'not enough Busywork for this style'; END IF;
 UPDATE public.players SET pp=pp-total,spent=coalesce(spent,0)+total,
 cosmetic_styles=cosmetic_styles||jsonb_build_object(q.item,jsonb_build_object('color',q.color,'design',q.design)),
 cosmetic_revision=cosmetic_revision+1 WHERE id=p.id RETURNING * INTO p;
 UPDATE public.style_quotes SET applied=true WHERE player_id=p.id AND id=q.id;
 RETURN p;
END $$;
REVOKE ALL ON FUNCTION public.apply_style(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.apply_style(uuid) TO authenticated;

CREATE FUNCTION public.equip_style_item(p_item text) RETURNS public.players
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.players; info jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 SELECT * INTO p FROM public.players WHERE id=auth.uid() FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'no employee'; END IF;
 info:=public.style_item_info(p,p_item);
 IF info->>'kind'='pin' THEN
  UPDATE public.players SET pin=substr(p_item,5),cosmetic_revision=cosmetic_revision+1 WHERE id=p.id RETURNING * INTO p;
 ELSIF info->>'kind'='wardrobe' THEN
  UPDATE public.players SET look=jsonb_set(coalesce(look,'{}'::jsonb),'{clothing}',to_jsonb(p_item)),cosmetic_revision=cosmetic_revision+1 WHERE id=p.id RETURNING * INTO p;
 ELSE
  UPDATE public.players SET cosmetic_equipped=cosmetic_equipped||jsonb_build_object(info->>'slot',p_item),cosmetic_revision=cosmetic_revision+1 WHERE id=p.id RETURNING * INTO p;
 END IF;
 RETURN p;
END $$;
REVOKE ALL ON FUNCTION public.equip_style_item(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.equip_style_item(text) TO authenticated;

-- Preserve automatic display of a newly purchased higher tier, including old clients.
CREATE FUNCTION public.style_new_fitting() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
DECLARE slot text;
BEGIN
 FOREACH slot IN ARRAY ARRAY['desk','chair','rug','art','tv'] LOOP
  IF (NEW.kit->>slot) IS DISTINCT FROM (OLD.kit->>slot) THEN NEW.cosmetic_equipped:=NEW.cosmetic_equipped-slot; END IF;
 END LOOP;
 IF (NEW.vanity->>'held') IS DISTINCT FROM (OLD.vanity->>'held') THEN NEW.cosmetic_equipped:=NEW.cosmetic_equipped-'held'; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.style_new_fitting() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER style_new_fitting BEFORE UPDATE OF kit,vanity ON public.players FOR EACH ROW EXECUTE FUNCTION public.style_new_fitting();
NOTIFY pgrst,'reload schema';
