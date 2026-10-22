-- Change only the scheduler body. Preserve RPC signature, grants, ownership,
-- existing claims/rewards and player rows; reject drift from the reviewed source.
DO $migration$
DECLARE source_text text; definition text;
BEGIN
 SELECT prosrc,pg_get_functiondef(oid) INTO source_text,definition
 FROM pg_proc WHERE oid='public.cow_arm()'::regprocedure;
 IF md5(source_text)<>'897ce6434e2f36952543e835b7927da5' THEN
  RAISE EXCEPTION 'cow_arm changed since review; stop and reconcile';
 END IF;
 EXECUTE replace(definition,source_text,$body$
declare
 c public.cow_state;
 k text := public.week_key();
 week_start timestamptz := public.week_started();
 week_end timestamptz;
 earliest timestamptz;
 latest timestamptz;
begin
 -- Calendar arithmetic in Pacific time includes 167/169-hour DST weeks.
 week_end := ((week_start AT TIME ZONE 'America/Los_Angeles') + interval '7 days') AT TIME ZONE 'America/Los_Angeles';
 earliest := week_start + interval '1 hour';
 latest := week_end - interval '1 hour';
 select * into c from public.cow_state where id=1 for update;
 if c.id is null then
  insert into public.cow_state(id,week_key,unlock_at)
   values(1,k,earliest + random() * (latest-earliest))
   on conflict(id) do nothing;
  select * into c from public.cow_state where id=1 for update;
 end if;
 if c.week_key is distinct from k then
  -- One persisted draw per office week, shared by every player. Ignore legacy
  -- pin_next timestamps, which could open the level at or before the reset.
  update public.cow_state set week_key=k,
   unlock_at=earliest + random() * (latest-earliest),pin_next=null,
   taken_by=null,taken_at=null,orbs=null,secs_per_orb=null,
   loot=null,finished=false
  where id=1 returning * into c;
 end if;
 return c;
end $body$);
END $migration$;
