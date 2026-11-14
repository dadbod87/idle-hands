CREATE OR REPLACE FUNCTION public.do_deed(p_target uuid, p_kind text)
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p players; t players; victim players; d jsonb; price double precision; amt double precision:=0;
 soften double precision; eff double precision; budget double precision; cd interval; beneficiary uuid;
 blocked_by_filter boolean:=false; clipped boolean:=false; reflected boolean:=false; hostile boolean; deed_id bigint; outcome_detail text;
begin
  perform pg_advisory_xact_lock(728194,1);
  if auth.uid() is null or not exists(select 1 from players where id=auth.uid()) then raise exception 'not signed in'; end if;
  p:=accrue(auth.uid());
  if p_target is null or p_kind is null or p_target=p.id then raise exception 'choose a coworker'; end if;
  cd:=interval '5 minutes'-perk_of(p,'silver_tongue')*interval '1 minute';
  if p.last_deed is not null and now()-p.last_deed<cd then raise exception 'cooling off'; end if;
  select data->p_kind into d from catalog where key='deeds';
  if d is null then raise exception 'no such deed'; end if;
  if p_kind='cover' then d:='{"cost":0.05,"good":true,"mins":20,"mult":1.15}'::jsonb; end if;
  if d?'transfer' then raise exception 'cash transfer deeds are retired'; end if;
  t:=accrue(p_target);
  if t is null then raise exception 'no such player'; end if;
  price:=deed_price(p,p_kind);
  if price is null or price<=0 or price>='Infinity'::float8 then raise exception 'invalid deed price'; end if;
  if p.pp<price then raise exception 'cannot afford'; end if;

  hostile:=not coalesce((d->>'good')::boolean,false) and
    ((d?'mult' and (d->>'mult')::float8<1) or (d?'heat_to' and (d->>'heat_to')::int>0) or (d?'steal' and t.pp>0));
  if hostile then reflected:=office_private.consume_shield(t.id); end if;
  victim:=case when reflected then p else t end;
  beneficiary:=case when reflected then t.id else p.id end;
  soften:=greatest(0.2,case when victim.dept='systems' then 0.6 else 1 end*(1-0.25*perk_of(victim,'thick_skin')));

  if d?'steal' then
    -- Reserve the attack price before reflecting. Never credit more than is debited.
    budget:=greatest(0,victim.pp-case when reflected then price else 0 end);
    amt:=least(greatest(20,budget*(d->>'steal')::float8*soften),steal_cap(p),budget);
    if amt>0 and not reflected and office_private.clip_blocks(t.id) then amt:=amt*0.5;clipped:=true;end if;
    update players set pp=pp-amt where id=victim.id;
    update players set pp=pp+amt where id=beneficiary;
  end if;
  if not reflected and d?'mult' and (d->>'mult')::float8<1 and office_private.filter_blocks(t.id) then
    blocked_by_filter:=true;d:=d-'mult';
  end if;
  if p_kind='cover' then
    update players set buffs=coalesce((select jsonb_agg(b) from jsonb_array_elements(t.buffs) b where b->>'kind'<>'cover'),'[]'::jsonb) where id=t.id;
  end if;
  if d?'mult' then
    eff:=(d->>'mult')::float8;
    if eff<1 then eff:=1-(1-eff)*soften; end if;
    update players set buffs=buffs||jsonb_build_object('kind',p_kind,'mult',eff,
      'from_name',case when reflected then t.name||' · Return to Sender' else p.name end,
      'until',now()+((d->>'mins')||' minutes')::interval) where id=victim.id;
  end if;
  if d?'heat_to' then update players set heat=heat+(d->>'heat_to')::int where id=victim.id;end if;
  if (d->>'good')::boolean then update players set kind_received=kind_received+1 where id=t.id;end if;
  outcome_detail:=case when reflected then 'reflected:shield' when blocked_by_filter then 'blocked:filter' when clipped then 'protected:clip' else null end;
  -- One initiated deed. Its original target suffered no debit when reflected.
  insert into deeds(actor,target,kind,amount,detail) values(p.id,t.id,p_kind,case when reflected then 0 else amt end,outcome_detail) returning id into deed_id;
  if reflected then insert into office_private.reflections(source_deed,defender,sender,kind,amount) values(deed_id,t.id,p.id,p_kind,amt);end if;

  update players set pp=pp-price,last_deed=now(),
    goodwill=goodwill+case when (d->>'good')::boolean then 1 else 0 end,
    notoriety=notoriety+case when (d->>'good')::boolean then 0 else 1 end,
    heat=case when p_kind='blame' then case when reflected then (d->>'heat_to')::int else 0 end
              when (d->>'good')::boolean then heat else heat+1 end,
    busted=case when p_kind<>'blame' and not (d->>'good')::boolean and heat+1=5 then busted+1 else busted end,
    tally=jsonb_set(tally,array[p_kind],to_jsonb(coalesce((tally->>p_kind)::int,0)+1),true)
  where id=p.id returning * into p;
  perform bump_today(p.id,case when (d->>'good')::boolean then 'kind' else 'mean' end,1);
  if not (d->>'good')::boolean then perform check_rivalry(p.id,p_target);select * into p from players where id=p.id;end if;
  return p;
end $function$
