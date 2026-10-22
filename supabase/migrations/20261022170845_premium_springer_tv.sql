-- Additive premium TV. No player rows, identifiers, old prices or grants changed.
do $migration$
declare body text; old_needle text; new_needle text; fn text; items jsonb;
tv jsonb := '{"id":"tv1","name":"The Productivity Flatscreen","slot":"tv","tier":1,"secs":259200,"min_cost":50000000,"note":"One channel. Four Springer moments. HR has classified it as conflict-resolution training."}'::jsonb;
begin
  foreach fn in array array['buy_fitting','fitting_prices'] loop
    body:=pg_get_functiondef(case when fn='buy_fitting' then 'public.buy_fitting(text,text)'::regprocedure else 'public.fitting_prices()'::regprocedure end);
    old_needle:=case when fn='buy_fitting' then 'greatest(1000, calc_rate(p)' else 'greatest(1000, eff *' end;
    new_needle:=case when fn='buy_fitting' then 'greatest(1000, coalesce((it ->> ''min_cost'')::double precision, 0), calc_rate(p)' else 'greatest(1000, coalesce((it ->> ''min_cost'')::double precision, 0), eff *' end;
    if strpos(body,new_needle)>0 then continue; end if;
    if (length(body)-length(replace(body,old_needle,'')))/length(old_needle)<>1 then
      raise exception 'Unexpected % price implementation; migration aborted',fn;
    end if;
    execute replace(body,old_needle,new_needle);
  end loop;
  select data into items from public.catalog where key='office_kit' for update;
  if items is null or jsonb_typeof(items)<>'array' then raise exception 'Missing office kit catalog'; end if;
  if exists(select 1 from jsonb_array_elements(items) v where v->>'id'='tv1' and v<>tv) then raise exception 'TV id already has different data'; end if;
  if not exists(select 1 from jsonb_array_elements(items) v where v->>'id'='tv1') then
    update public.catalog set data=items||jsonb_build_array(tv) where key='office_kit';
  end if;
end $migration$;
