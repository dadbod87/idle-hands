-- One-time administrative operation requested by the owner on 2026-10-22.
-- Production project: wbakpxbvqxppqbrwuokp (Idle Hands ONLY).
-- Not a migration, not a CI fixture, never run automatically or replay.
-- Four Auth accounts / three characters inspected; mismatching counts abort.
-- Revokes refresh sessions and removes all player/game history. Preserves catalog,
-- functions, schema, code/rate-limit settings, and canonical cow scheduling.
-- Six legacy badge objects require Storage API/dashboard cleanup separately.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';
lock table auth.users in share row exclusive mode;
lock table public.players in exclusive mode;
do $reset$
declare catalog_before text; door_before text; functions_before text;
begin
  if (select count(*) from auth.users) <> 4 or (select count(*) from public.players) <> 3 then
    raise exception 'Account/character counts changed since inspection; reset aborted';
  end if;
  select md5(coalesce(jsonb_agg(to_jsonb(c) order by c.key)::text,'')) into catalog_before from public.catalog c;
  select md5((to_jsonb(d)-'admin')::text) into door_before from public.office_door d where id=1;
  select md5(string_agg(pg_get_functiondef(p.oid),E'\n' order by p.oid)) into functions_before
    from pg_proc p where p.pronamespace='public'::regnamespace and p.prokind='f';
  delete from auth.refresh_tokens where user_id in (select id::text from auth.users);
  delete from auth.sessions where user_id in (select id from auth.users);
  delete from public.office_play_nominations;
  delete from public.office_play_votes;
  delete from public.office_play_actions;
  delete from public.deeds;
  delete from public.chair_claims;
  delete from public.printer_claims;
  delete from public.meeting_claims;
  delete from public.birthday_card;
  delete from public.suggestions;
  delete from public.seasons;
  update public.cow_state set taken_by=null,taken_at=null,orbs=null,secs_per_orb=null,loot=null,finished=false;
  update public.season_state set current_week=public.week_key(),mw=public.week_key(),mhit=false,streak=0,best=0,target=null,target_week=null where id=1;
  update public.office_door set admin=null where id=1;
  delete from auth.users;
  if exists(select 1 from auth.users) or exists(select 1 from public.players) or exists(select 1 from auth.sessions) or exists(select 1 from auth.refresh_tokens) then
    raise exception 'Reset incomplete; transaction rolled back';
  end if;
  if catalog_before is distinct from (select md5(coalesce(jsonb_agg(to_jsonb(c) order by c.key)::text,'')) from public.catalog c)
    or door_before is distinct from (select md5((to_jsonb(d)-'admin')::text) from public.office_door d where id=1)
    or functions_before is distinct from (select md5(string_agg(pg_get_functiondef(p.oid),E'\n' order by p.oid)) from pg_proc p where p.pronamespace='public'::regnamespace and p.prokind='f') then
    raise exception 'Preserved game configuration changed; transaction rolled back';
  end if;
end $reset$;
commit;
select jsonb_build_object('accounts',(select count(*) from auth.users),'characters',(select count(*) from public.players),'sessions',(select count(*) from auth.sessions),'refresh_tokens',(select count(*) from auth.refresh_tokens),'deeds',(select count(*) from public.deeds),'seasons',(select count(*) from public.seasons),'suggestions',(select count(*) from public.suggestions),'votes',(select count(*) from public.office_play_votes),'nominations',(select count(*) from public.office_play_nominations),'prop_participation',(select count(*) from public.office_play_actions),'birthday_cards',(select count(*) from public.birthday_card),'catalog_entries',(select count(*) from public.catalog),'office_config_preserved',true,'storage_badge_uploads',(select count(*) from storage.objects where bucket_id='badges'),'admin_unassigned',(select admin is null from public.office_door where id=1)) as reset_result;
