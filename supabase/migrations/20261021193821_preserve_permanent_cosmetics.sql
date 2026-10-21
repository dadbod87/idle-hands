-- Permanent catalog cosmetics match the UI promise: kept across weekly seasons.
-- Install only the function; never invoke a season reset from this migration.
CREATE OR REPLACE FUNCTION public.season_wipe()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $wipe$
#variable_conflict use_variable
DECLARE v_n int;
BEGIN
 UPDATE players SET
  pp=0,cycle=0,week_pp=0,day_pp=0,
  owned='{}'::jsonb,upgrades='[]'::jsonb,buffs='[]'::jsonb,
  equity=0,perks='{}'::jsonb,raises=0,frenzy_until=null,
  heat=0,busted=0,goodwill=0,notoriety=0,hush=0,quits=0,
  grabs=0,kind_received=0,rivalries=0,hits='{}'::jsonb,tally='{}'::jsonb,
  today='{}'::jsonb,contracts=null,mail=null,streak=0,last_checkin=null,
  nickname=null,outfit=null,ooo=null,
  last_restructure=null,last_deed=null,last_nick=null,last_vend=null,
  last_break=null,last_work=null,last_tick=now()
 WHERE id IS NOT NULL;
 GET DIAGNOSTICS v_n=ROW_COUNT;
 DELETE FROM deeds WHERE id IS NOT NULL;
 DELETE FROM chair_claims WHERE window_id IS NOT NULL;
 DELETE FROM printer_claims WHERE window_id IS NOT NULL;
 DELETE FROM meeting_claims WHERE window_id IS NOT NULL;
 DELETE FROM birthday_card WHERE week_key IS NOT NULL;
 RETURN v_n;
END $wipe$;
-- kit, vanity and lifetime cosmetic spending intentionally remain untouched,
-- as do existing wardrobe, pin, pet, trophy and achievement collections.
-- Only server-owned rollover code should call this internal all-player helper.
REVOKE ALL ON FUNCTION public.season_wipe() FROM PUBLIC, anon, authenticated;
