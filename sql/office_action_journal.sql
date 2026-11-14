-- RELEASE HOLD: optional journal-only installation BEFORE normal Friday rollover.
-- No player updates, economy replacements, client grants, project rewards or reset calls.
-- Generate a provider migration only after the separate release decision.
BEGIN;
CREATE SCHEMA IF NOT EXISTS office_private;
REVOKE ALL ON SCHEMA office_private FROM PUBLIC,anon,authenticated;
LOCK TABLE public.deeds IN SHARE ROW EXCLUSIVE MODE;
DO $journal_guard$ BEGIN
 IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='players' AND column_name='seniority_earned') THEN
  RAISE EXCEPTION 'full office package already installed; journal downgrade refused';
 END IF;
 IF to_regclass('office_private.action_history') IS NOT NULL OR to_regclass('office_private.history_coverage') IS NOT NULL THEN
  RAISE EXCEPTION 'journal already exists; verify and reuse it through the full installer';
 END IF;
END $journal_guard$;
-- @JOURNAL_CORE@
CREATE TABLE office_private.action_history(
 source_deed bigint PRIMARY KEY, actor uuid NOT NULL,target uuid NOT NULL,
 kind text NOT NULL,category text NOT NULL CHECK(category IN('help','sabotage','playful','blocked','other')),
 amount double precision NOT NULL DEFAULT 0,hush boolean NOT NULL DEFAULT false,
 happened_at timestamptz NOT NULL,week text NOT NULL
);
CREATE INDEX action_history_actor_time ON office_private.action_history(actor,happened_at);
CREATE INDEX action_history_target_time ON office_private.action_history(target,happened_at);
CREATE INDEX action_history_week ON office_private.action_history(week);
CREATE TABLE office_private.history_coverage(id boolean PRIMARY KEY DEFAULT true CHECK(id),started_at timestamptz NOT NULL,continuous_since timestamptz NOT NULL DEFAULT now());
INSERT INTO office_private.history_coverage(started_at) SELECT coalesce(min(created_at),now()) FROM public.deeds;
CREATE FUNCTION office_private.action_category(k text,detail text DEFAULT NULL) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE WHEN detail='blocked:filter' THEN 'blocked'
 WHEN k IN('coffee','hype','cover','rescue') THEN 'help'
 WHEN k IN('dress','nickname','confetti') THEN 'playful'
 WHEN k IN('credit','mute','chair','meeting','replyall','blame') THEN 'sabotage' ELSE 'other' END
$$;
INSERT INTO office_private.action_history(source_deed,actor,target,kind,category,amount,hush,happened_at,week)
 SELECT id,actor,target,kind,office_private.action_category(kind,detail),coalesce(amount,0),coalesce(hush,false),created_at,public.week_key(created_at) FROM public.deeds
 ON CONFLICT(source_deed) DO NOTHING;

CREATE FUNCTION office_private.capture_deed() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $journal_capture$
BEGIN
 INSERT INTO office_private.action_history(source_deed,actor,target,kind,category,amount,hush,happened_at,week)
 VALUES(NEW.id,NEW.actor,NEW.target,NEW.kind,office_private.action_category(NEW.kind,NEW.detail),coalesce(NEW.amount,0),coalesce(NEW.hush,false),NEW.created_at,public.week_key(NEW.created_at))
 ON CONFLICT(source_deed) DO UPDATE SET hush=office_private.action_history.hush OR excluded.hush;
 RETURN NEW;
END $journal_capture$;
CREATE TRIGGER office_capture_deed AFTER INSERT OR UPDATE OF hush ON public.deeds FOR EACH ROW EXECUTE FUNCTION office_private.capture_deed();
ALTER TABLE office_private.action_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.history_coverage ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE office_private.action_history,office_private.history_coverage FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION office_private.action_category(text,text),office_private.capture_deed() FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE office_private.action_history IS 'idle-hands:action-journal:v1';
-- @END_JOURNAL_CORE@
NOTIFY pgrst,'reload schema';
COMMIT;
