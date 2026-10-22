-- Actual canonical helpers; only their default input clock is controlled for isolated tests.
CREATE OR REPLACE FUNCTION public.week_key(ts timestamptz DEFAULT coalesce(nullif(current_setting('test.secret_now',true),'')::timestamptz,now()))
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $key$
DECLARE loc timestamp; monday timestamp;
BEGIN
 loc:=ts AT TIME ZONE 'America/Los_Angeles'; monday:=date_trunc('week',loc);
 IF loc >= monday + interval '4 days 16 hours' THEN RETURN to_char(monday+interval '7 days','IYYY-IW'); END IF;
 RETURN to_char(monday,'IYYY-IW');
END $key$;

CREATE OR REPLACE FUNCTION public.week_started(ts timestamptz DEFAULT coalesce(nullif(current_setting('test.secret_now',true),'')::timestamptz,now()))
RETURNS timestamptz LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $start$
DECLARE loc timestamp; cutoff timestamp;
BEGIN
 loc:=ts AT TIME ZONE 'America/Los_Angeles';
 cutoff:=date_trunc('week',loc)+interval '4 days 16 hours';
 IF loc<cutoff THEN cutoff:=cutoff-interval '7 days'; END IF;
 RETURN cutoff AT TIME ZONE 'America/Los_Angeles';
END $start$;

