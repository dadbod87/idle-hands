-- Eight cosmetic awards derived only from the signed-in employee's stored stats.
-- Existing legacy award IDs are retained; no currency, inventory or boosts change.
CREATE OR REPLACE FUNCTION public.office_award_ids(p public.players)
RETURNS jsonb LANGUAGE sql STABLE SET search_path TO ''
AS $awards$
 SELECT coalesce(jsonb_agg(id ORDER BY id),'[]'::jsonb)
 FROM (VALUES
 ('oa_welcome',coalesce((p).goodwill,0)>=3),
 ('oa_glue',coalesce((p).goodwill,0)>=15),
 ('oa_reciprocity',coalesce((p).goodwill,0)>=5 AND coalesce((p).kind_received,0)>=5),
 ('oa_collaboration',coalesce(((p).tally->>'coffee')::numeric,0)>0 AND coalesce(((p).tally->>'hype')::numeric,0)>0 AND coalesce(((p).tally->>'cover')::numeric,0)>0),
 ('oa_wardrobe',(SELECT count(DISTINCT value) FROM jsonb_array_elements_text(CASE WHEN jsonb_typeof((p).wardrobe_owned)='array' THEN (p).wardrobe_owned ELSE '[]'::jsonb END))>=3),
 ('oa_facilities',coalesce((p).kit->>'desk','') IN ('d1','d2','d3','d4','d5') AND coalesce((p).kit->>'chair','') IN ('c1','c2','c3','c4') AND coalesce((p).kit->>'rug','') IN ('r1','r2','r3','r4') AND coalesce((p).kit->>'art','') IN ('w1','w2','w3','w4')),
 ('oa_streak',coalesce((p).streak,0)>=7),
 ('oa_menagerie',(SELECT count(DISTINCT value) FROM jsonb_array_elements_text(CASE WHEN jsonb_typeof((p).cow)='array' THEN (p).cow ELSE '[]'::jsonb END))>=3)
 ) AS candidates(id,earned) WHERE earned;
$awards$;
REVOKE ALL ON FUNCTION public.office_award_ids(public.players) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.save_achievements(p_list jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $save$
DECLARE p public.players; v jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 IF p_list IS NULL OR jsonb_typeof(p_list)<>'array' THEN RAISE EXCEPTION 'invalid award list'; END IF;
 IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_list) AS x(value) WHERE jsonb_typeof(value)<>'string') THEN RAISE EXCEPTION 'invalid award id'; END IF;
 SELECT * INTO p FROM public.players WHERE id=auth.uid() FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'no employee'; END IF;
 SELECT coalesce(jsonb_agg(id ORDER BY id),'[]'::jsonb) INTO v FROM (
  SELECT value AS id FROM jsonb_array_elements_text(coalesce(p.achievements,'[]'::jsonb))
  UNION SELECT value FROM jsonb_array_elements_text(p_list) WHERE left(value,3)<>'oa_'
  UNION SELECT value FROM jsonb_array_elements_text(public.office_award_ids(p))
 ) AS earned;
 IF v IS DISTINCT FROM p.achievements THEN UPDATE public.players SET achievements=v WHERE id=p.id; END IF;
END
$save$;
REVOKE ALL ON FUNCTION public.save_achievements(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_achievements(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.claim_office_awards()
RETURNS public.players LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $claim$
DECLARE p public.players;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not signed in'; END IF;
 PERFORM public.save_achievements('[]'::jsonb);
 SELECT * INTO p FROM public.players WHERE id=auth.uid();
 RETURN p;
END
$claim$;
REVOKE ALL ON FUNCTION public.claim_office_awards() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_office_awards() TO authenticated;
