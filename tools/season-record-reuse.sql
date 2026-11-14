DO $season_reuse$ BEGIN
 IF to_regclass('office_private.season_records') IS NULL AND to_regclass('office_private.season_results') IS NULL THEN
  EXECUTE $season_core$-- Private preservation only. No client endpoint, economy change, accrual or reset.
CREATE TABLE office_private.season_records(
 week text PRIMARY KEY,closed_at timestamptz NOT NULL,winner uuid,winner_name text,top float8 NOT NULL,
 coverage text NOT NULL CHECK(coverage IN('winner_only','standings')),captured_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE office_private.season_records IS 'idle-hands:season-records:v1';
CREATE TABLE office_private.season_results(
 week text NOT NULL REFERENCES office_private.season_records(week),player uuid NOT NULL,name text NOT NULL,
 earnings float8 NOT NULL CHECK(earnings>=0 AND earnings<'Infinity'::float8),place bigint NOT NULL CHECK(place>0),
 PRIMARY KEY(week,player)
);
ALTER TABLE office_private.season_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_private.season_results ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON office_private.season_records,office_private.season_results FROM PUBLIC,anon,authenticated;
CREATE FUNCTION office_private.capture_season() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $season_capture$
DECLARE closing text;
BEGIN
 SELECT current_week INTO closing FROM public.season_state WHERE id=1;
 -- The ordinary rollover inserts its season before clearing player weekly counters.
 -- Historical/admin recap edits must never manufacture past standings from today's players.
 IF NEW.week_key=closing AND closing IS DISTINCT FROM public.week_key()
 AND NOT EXISTS(SELECT 1 FROM office_private.season_records WHERE week=closing AND coverage='standings') THEN
  INSERT INTO office_private.season_records(week,closed_at,winner,winner_name,top,coverage)
  VALUES(closing,NEW.closed_at,NEW.winner,NEW.winner_name,coalesce(NEW.top,0),'standings')
  ON CONFLICT(week) DO UPDATE SET closed_at=excluded.closed_at,winner=excluded.winner,winner_name=excluded.winner_name,top=excluded.top,coverage='standings',captured_at=now();
  INSERT INTO office_private.season_results(week,player,name,earnings,place)
  SELECT closing,id,name,week_pp,rank() OVER(ORDER BY week_pp DESC) FROM public.players
  ON CONFLICT(week,player) DO NOTHING;
 ELSE
  INSERT INTO office_private.season_records(week,closed_at,winner,winner_name,top,coverage)
  VALUES(NEW.week_key,NEW.closed_at,NEW.winner,NEW.winner_name,coalesce(NEW.top,0),'winner_only') ON CONFLICT DO NOTHING;
 END IF;
 RETURN NEW;
END $season_capture$;
REVOKE ALL ON FUNCTION office_private.capture_season() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER office_capture_season AFTER INSERT OR UPDATE OF stats ON public.seasons FOR EACH ROW EXECUTE FUNCTION office_private.capture_season();
INSERT INTO office_private.season_records(week,closed_at,winner,winner_name,top,coverage)
 SELECT week_key,closed_at,winner,winner_name,coalesce(top,0),'winner_only' FROM public.seasons ON CONFLICT DO NOTHING;
$season_core$;
 ELSE
  IF to_regclass('office_private.season_records') IS NULL OR to_regclass('office_private.season_results') IS NULL THEN RAISE EXCEPTION 'incomplete season history'; END IF;
  IF obj_description('office_private.season_records'::regclass,'pg_class') IS DISTINCT FROM 'idle-hands:season-records:v1'
  OR (SELECT array_agg(attname::text||':'||format_type(atttypid,atttypmod) ORDER BY attnum) FROM pg_attribute WHERE attrelid='office_private.season_records'::regclass AND attnum>0 AND NOT attisdropped) IS DISTINCT FROM ARRAY['week:text','closed_at:timestamp with time zone','winner:uuid','winner_name:text','top:double precision','coverage:text','captured_at:timestamp with time zone']
  OR (SELECT array_agg(attname::text||':'||format_type(atttypid,atttypmod) ORDER BY attnum) FROM pg_attribute WHERE attrelid='office_private.season_results'::regclass AND attnum>0 AND NOT attisdropped) IS DISTINCT FROM ARRAY['week:text','player:uuid','name:text','earnings:double precision','place:bigint']
  OR (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('office_private.capture_season()')) IS DISTINCT FROM '09c36ae4200284848c84da1bf9085e24'
  OR EXISTS(SELECT 1 FROM pg_class WHERE oid IN('office_private.season_records'::regclass,'office_private.season_results'::regclass) AND NOT relrowsecurity)
  OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='office_capture_season' AND tgrelid='public.seasons'::regclass AND tgfoid='office_private.capture_season()'::regprocedure AND tgenabled='O' AND NOT tgisinternal)
  OR has_table_privilege('anon','office_private.season_records','SELECT,INSERT,UPDATE,DELETE') OR has_table_privilege('authenticated','office_private.season_records','SELECT,INSERT,UPDATE,DELETE')
  OR has_table_privilege('anon','office_private.season_results','SELECT,INSERT,UPDATE,DELETE') OR has_table_privilege('authenticated','office_private.season_results','SELECT,INSERT,UPDATE,DELETE')
  OR has_function_privilege('anon','office_private.capture_season()','EXECUTE') OR has_function_privilege('authenticated','office_private.capture_season()','EXECUTE')
  OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='office_private.season_records'::regclass AND contype='p' AND conkey=ARRAY[1]::smallint[])
  OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='office_private.season_results'::regclass AND contype='p' AND conkey=ARRAY[1,2]::smallint[])
  THEN RAISE EXCEPTION 'prior season history drift; review before reuse'; END IF;
 END IF;
END $season_reuse$;
