-- Read-only production ownership resolver; disposable fixture and guarded patch source.
CREATE OR REPLACE FUNCTION public.style_item_info(p players, p_item text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
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
END $function$
;

