-- Isolated PostgreSQL only. NEVER run this fixture on Production.
begin;
create table if not exists public.catalog(key text primary key,data jsonb);
insert into public.catalog(key,data) values ('office_kit','[{"id":"d1","slot":"desk","tier":1,"secs":400},{"id":"d2","slot":"desk","tier":2,"secs":2400}]') on conflict(key) do update set data=excluded.data;
create or replace function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
select set_config('request.jwt.claim.sub',(select id::text from public.players limit 1),true);
create or replace function public.calc_rate(p public.players) returns double precision language sql stable as $$select coalesce((p.owned->>'tv_fixture_rate')::double precision,0)$$;
create or replace function public.live_mult(p public.players) returns double precision language sql stable as $$select 1::double precision$$;
CREATE OR REPLACE FUNCTION public.buy_fitting(p_key text, p_id text)
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; it jsonb; slot text; tier int; have text; have_tier int;
        col text; price double precision;
begin
  if p_key not in ('vanity', 'office_kit') then raise exception 'no such catalogue'; end if;
  p := accrue(auth.uid());
  select value into it from catalog, jsonb_array_elements(data) v(value)
   where key = p_key and value ->> 'id' = p_id;
  if it is null then raise exception 'no such thing'; end if;

  slot := it ->> 'slot'; tier := (it ->> 'tier')::int;
  col := case when p_key = 'vanity' then 'vanity' else 'kit' end;
  if col = 'vanity' then have := p.vanity ->> slot; else have := p.kit ->> slot; end if;
  if have is not null then
    select (value ->> 'tier')::int into have_tier from catalog, jsonb_array_elements(data) v(value)
     where key = p_key and value ->> 'id' = have;
  else have_tier := 0; end if;

  if tier <= have_tier then raise exception 'already have that'; end if;
  if tier > have_tier + 1 then raise exception 'buy them in order'; end if;
  price := greatest(1000, calc_rate(p) * live_mult(p) * (it ->> 'secs')::double precision);
  if p.pp < price then raise exception 'cannot afford'; end if;

  if col = 'vanity' then
    update players set pp = pp - price, spent = spent + price,
      vanity = vanity || jsonb_build_object(slot, p_id) where id = p.id returning * into p;
  else
    update players set pp = pp - price, spent = spent + price,
      kit = kit || jsonb_build_object(slot, p_id) where id = p.id returning * into p;
  end if;
  return p;
end $function$
;

CREATE OR REPLACE FUNCTION public.fitting_prices()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; eff double precision; out jsonb := '{}'::jsonb; it jsonb;
begin
  select * into p from players where id = auth.uid();
  if p.id is null then return jsonb_build_object('rate', 0, 'prices', '{}'::jsonb); end if;
  eff := calc_rate(p) * live_mult(p);
  for it in select value from catalog, jsonb_array_elements(data) v(value)
            where key in ('vanity', 'office_kit') loop
    out := out || jsonb_build_object(it ->> 'id',
             greatest(1000, eff * (it ->> 'secs')::double precision));
  end loop;
  return jsonb_build_object('rate', eff, 'prices', out);
end $function$
;
create temp table tv_install_before as select id,to_jsonb(p) as snapshot from public.players p;
\i supabase/migrations/20261022170845_premium_springer_tv.sql
do $tests$
declare v_player public.players; price double precision; rejected boolean; uid uuid:=auth.uid();
begin
 if exists(select 1 from public.players p join tv_install_before b using(id) where to_jsonb(p)<>b.snapshot) then raise exception 'Migration rewrote players'; end if;
 if (select count(*) from jsonb_array_elements((select data from catalog where key='office_kit'))v where v->>'id'='tv1')<>1 then raise exception 'TV catalog not additive'; end if;
 -- Existing prices stay identical; TV cannot be bought cheaply at zero production.
 price:=(public.fitting_prices()->'prices'->>'tv1')::double precision;
 if price<>50000000 then raise exception 'TV quote below premium floor: %',price; end if;
 if (public.fitting_prices()->'prices'->>'d1')::double precision<>1000 then raise exception 'Legacy price changed'; end if;
 update public.players set pp=49999999,kit='{"desk":"d1","art":"w2"}',spent=0,owned='{}' where id=uid;
 rejected:=false;begin perform public.buy_fitting('office_kit','tv1');exception when others then rejected:=true;end;
 if not rejected or (select kit ? 'tv' from players where id=uid) then raise exception 'Unaffordable TV awarded'; end if;
 update public.players set pp=150000000,owned='{"tv_fixture_rate":400}' where id=uid;
 price:=(public.fitting_prices()->'prices'->>'tv1')::double precision;
 if price<>103680000 then raise exception 'Three-day rate quote incorrect'; end if;
 if (public.fitting_prices()->'prices'->>'d1')::double precision<>160000 then raise exception 'Existing rate-scaled price changed'; end if;
 v_player:=public.buy_fitting('office_kit','tv1');
 if v_player.pp<>46320000 or v_player.spent<>103680000 or v_player.kit->>'tv'<>'tv1' or v_player.kit->>'desk'<>'d1' or v_player.kit->>'art'<>'w2' then raise exception 'TV charged/equipped incorrectly'; end if;
 rejected:=false;begin perform public.buy_fitting('office_kit','tv1');exception when others then rejected:=true;end;
 if not rejected then raise exception 'Duplicate TV charged'; end if;
 perform public.season_wipe();
 if (select kit->>'tv' from players where id=uid)<>'tv1' then raise exception 'TV lost on weekly rollover'; end if;
 rejected:=false;begin perform public.buy_fitting('office_kit','missing-tv');exception when others then rejected:=true;end;
 if not rejected then raise exception 'Unknown item accepted'; end if;
 perform set_config('request.jwt.claim.sub','',true);
 v_player:=public.buy_fitting('office_kit','tv1');
 if v_player.id is not null then raise exception 'Signed-out purchase awarded a player'; end if;
 raise notice 'PASS: TV floor/rate quote, funds, charge, ownership, old decor, duplicates, permanent rollover, unknown item and auth';
end $tests$;
-- Repeat installation remains additive and preserves behavior.
\i supabase/migrations/20261022170845_premium_springer_tv.sql
rollback;
