-- Additive cosmetic office play. No writes to players, earnings, catalog or existing claims.
CREATE TABLE public.office_play_votes (
 week text NOT NULL, voter uuid NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
 choice smallint NOT NULL CHECK(choice BETWEEN 0 AND 2), updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(week,voter)
);
CREATE TABLE public.office_play_nominations (
 week text NOT NULL, voter uuid NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
 category text NOT NULL CHECK(category IN ('glue','snacks','escape')),
 recipient uuid NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
 updated_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(week,voter,category), CHECK(voter<>recipient)
);
CREATE TABLE public.office_play_actions (
 week text NOT NULL, actor uuid NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
 day date NOT NULL, kind text NOT NULL CHECK(kind IN ('plant','bench','apology','calendar','shelf','notice','lounge','printer')),
 n smallint NOT NULL DEFAULT 1 CHECK(n BETWEEN 1 AND 6), updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(week,actor,day,kind)
);
CREATE INDEX office_play_votes_voter_idx ON public.office_play_votes(voter);
CREATE INDEX office_play_nominations_voter_idx ON public.office_play_nominations(voter);
CREATE INDEX office_play_nominations_recipient_idx ON public.office_play_nominations(recipient);
CREATE INDEX office_play_actions_actor_idx ON public.office_play_actions(actor);
ALTER TABLE public.office_play_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.office_play_nominations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.office_play_actions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.office_play_votes,public.office_play_nominations,public.office_play_actions FROM PUBLIC,anon,authenticated;
-- These tables are RPC-only: no direct Data API table grants or policies.
CREATE FUNCTION public.office_poll_config(p_week text) RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT (jsonb_build_array(
  jsonb_build_object('question','Who gets custody of the thermostat?','options',jsonb_build_array('The Cold Coalition','The Sweater Lobby','The plastic plant')),
  jsonb_build_object('question','The printer needs a name. Legal insists.','options',jsonb_build_array('Jamothy','Print Eastwood','Out of Office')),
  jsonb_build_object('question','Which position does this office urgently need?','options',jsonb_build_array('Deputy Snack Coordinator','Director of Unnecessary Meetings','Chief Chair Relocation Officer'))
 )->(mod(split_part(p_week,'-',1)::int*53+split_part(p_week,'-',2)::int,3)));
$$;
CREATE FUNCTION public.office_poll_summary(p_week text) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.office_poll_config(p_week)||jsonb_build_object('week',p_week,
 'counts',(SELECT jsonb_agg((SELECT count(*) FROM public.office_play_votes v WHERE v.week=p_week AND v.choice=i) ORDER BY i) FROM generate_series(0,2) i),
 'total',(SELECT count(*) FROM public.office_play_votes v WHERE v.week=p_week));
$$;
CREATE FUNCTION public.office_play_state() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE wk text:=public.week_key(); prior text:=public.week_key(public.week_started()-interval '1 second'); uid uuid:=auth.uid(); result jsonb;
BEGIN
 IF uid IS NULL OR NOT EXISTS(SELECT 1 FROM public.players WHERE id=uid AND signed_at IS NOT NULL) THEN RAISE EXCEPTION 'badge in first'; END IF;
 SELECT jsonb_build_object('week',wk,'ends_at',((public.week_started() AT TIME ZONE 'America/Los_Angeles')+interval '7 days') AT TIME ZONE 'America/Los_Angeles',
 'poll',public.office_poll_summary(wk)||jsonb_build_object('mine',(SELECT choice FROM public.office_play_votes WHERE week=wk AND voter=uid)),
 'previous_poll',public.office_poll_summary(prior),
 'nominations',coalesce((SELECT jsonb_agg(jsonb_build_object('category',category,'recipient',recipient,'name',p.name,'votes',votes) ORDER BY category,votes DESC,p.name,recipient)
  FROM (SELECT category,recipient,count(*) votes FROM public.office_play_nominations WHERE week=wk GROUP BY category,recipient) x JOIN public.players p ON p.id=x.recipient),'[]'::jsonb),
 'previous_nominations',coalesce((SELECT jsonb_agg(jsonb_build_object('category',category,'recipient',recipient,'name',p.name,'votes',votes) ORDER BY category,votes DESC,p.name,recipient) FROM (SELECT category,recipient,count(*) votes FROM public.office_play_nominations WHERE week=prior GROUP BY category,recipient) x JOIN public.players p ON p.id=x.recipient),'[]'::jsonb),
 'my_nominations',coalesce((SELECT jsonb_object_agg(category,recipient) FROM public.office_play_nominations WHERE week=wk AND voter=uid),'{}'::jsonb),
 'actions',coalesce((SELECT jsonb_object_agg(kind,n) FROM (SELECT kind,sum(n) n FROM public.office_play_actions WHERE week=wk GROUP BY kind) x),'{}'::jsonb),
 'contributors',(SELECT count(DISTINCT actor) FROM public.office_play_actions WHERE week=wk),
 'my_actions',coalesce((SELECT jsonb_object_agg(kind,n) FROM public.office_play_actions WHERE week=wk AND actor=uid AND day=(now() AT TIME ZONE 'America/Los_Angeles')::date),'{}'::jsonb),
 'hydrators',coalesce((SELECT jsonb_agg(jsonb_build_object('id',x.actor,'name',p.name,'visits',x.n) ORDER BY x.n DESC,p.name,x.actor) FROM (SELECT actor,sum(n) n FROM public.office_play_actions WHERE week=wk AND kind='plant' GROUP BY actor ORDER BY n DESC,actor LIMIT 3) x JOIN public.players p ON p.id=x.actor),'[]'::jsonb)) INTO result;
 RETURN result;
END;
$$;
CREATE FUNCTION public.office_vote(p_choice integer,p_week text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE uid uuid:=auth.uid(); wk text:=public.week_key();
BEGIN
 IF uid IS NULL OR NOT EXISTS(SELECT 1 FROM public.players WHERE id=uid AND signed_at IS NOT NULL) THEN RAISE EXCEPTION 'badge in first'; END IF;
 IF p_week IS DISTINCT FROM wk THEN RAISE EXCEPTION 'that ballot belongs to a different week; refresh office records'; END IF;
 IF p_choice IS NULL OR p_choice NOT BETWEEN 0 AND 2 THEN RAISE EXCEPTION 'that is not on the ballot'; END IF;
 INSERT INTO public.office_play_votes(week,voter,choice) VALUES(wk,uid,p_choice)
 ON CONFLICT(week,voter) DO UPDATE SET choice=excluded.choice,updated_at=now();
 RETURN public.office_play_state();
END;
$$;
CREATE FUNCTION public.office_nominate(p_category text,p_recipient uuid,p_week text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE uid uuid:=auth.uid(); wk text:=public.week_key();
BEGIN
 IF uid IS NULL OR NOT EXISTS(SELECT 1 FROM public.players WHERE id=uid AND signed_at IS NOT NULL) THEN RAISE EXCEPTION 'badge in first'; END IF;
 IF p_week IS DISTINCT FROM wk THEN RAISE EXCEPTION 'that commendation belongs to a different week; refresh office records'; END IF;
 IF p_category IS NULL OR p_category NOT IN ('glue','snacks','escape') THEN RAISE EXCEPTION 'unrecognized commendation'; END IF;
 IF p_recipient IS NULL OR p_recipient=uid OR NOT EXISTS(SELECT 1 FROM public.players WHERE id=p_recipient AND signed_at IS NOT NULL) THEN RAISE EXCEPTION 'choose another badged-in coworker'; END IF;
 INSERT INTO public.office_play_nominations(week,voter,category,recipient) VALUES(wk,uid,p_category,p_recipient)
 ON CONFLICT(week,voter,category) DO UPDATE SET recipient=excluded.recipient,updated_at=now();
 RETURN public.office_play_state();
END;
$$;
CREATE FUNCTION public.office_perform(p_kind text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE uid uuid:=auth.uid(); wk text:=public.week_key(); d date:=(now() AT TIME ZONE 'America/Los_Angeles')::date;
BEGIN
 IF uid IS NULL OR NOT EXISTS(SELECT 1 FROM public.players WHERE id=uid AND signed_at IS NOT NULL) THEN RAISE EXCEPTION 'badge in first'; END IF;
 IF p_kind IS NULL OR p_kind NOT IN ('plant','bench','apology','calendar','shelf','notice','lounge','printer') THEN RAISE EXCEPTION 'unrecognized office activity'; END IF;
 -- Unique actor/day/kind and atomic update prevent retries/concurrency from farming the story.
 -- Repeats still perform locally; the shared story counts at most six per kind/day and one per 15 seconds.
 INSERT INTO public.office_play_actions(week,actor,day,kind) VALUES(wk,uid,d,p_kind)
 ON CONFLICT(week,actor,day,kind) DO UPDATE SET n=public.office_play_actions.n+1,updated_at=now()
 WHERE public.office_play_actions.n<6 AND public.office_play_actions.updated_at<=now()-interval '15 seconds';
 RETURN public.office_play_state();
END;
$$;
REVOKE ALL ON FUNCTION public.office_poll_config(text),public.office_poll_summary(text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.office_play_state(),public.office_vote(integer,text),public.office_nominate(text,uuid,text),public.office_perform(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.office_play_state(),public.office_vote(integer,text),public.office_nominate(text,uuid,text),public.office_perform(text) TO authenticated;
