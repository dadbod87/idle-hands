-- User-approved restoration of original first names, lounge and brand text.
-- Catalog text only; unchanged catalog keys, IDs, numbers, prices, flags and player records.
-- Exact reviewed hashes prevent overwriting concurrent catalog edits. Entire DO is atomic.
DO $restore$
DECLARE r record; candidate jsonb; d text; before_def text; n int:=0;
BEGIN
 FOR r IN SELECT key,data FROM public.catalog WHERE key IN ('chance_extra','costumes','items','mail','memos_extra','office_kit') ORDER BY key FOR UPDATE LOOP
  IF md5(r.data::text) IS DISTINCT FROM CASE r.key
   WHEN 'chance_extra' THEN 'a6f6aa9fcc3d2be786f638dba7213689'
   WHEN 'costumes' THEN '8a7560ede4fc406cbcadab849488a7e9'
   WHEN 'items' THEN '5de58a4cf887fcf1af90d80af3c4b9b9'
   WHEN 'mail' THEN '3f95763732317b73e77c2feab82ae7bf'
   WHEN 'memos_extra' THEN 'b3c19e66a787c1d3444db9cc3fc4edc7'
   WHEN 'office_kit' THEN 'c0ed42190bf450815afd753da0b835ae'
  END THEN RAISE EXCEPTION 'name restoration: catalog % changed since review; nothing applied',r.key; END IF;
  d:=r.data::text;
  d:=replace(d,'Wes', 'Chance');
  d:=replace(d,'Hal', 'Dave');
  d:=replace(d,'Nora', 'Jess');
  d:=replace(d,'Gus', 'John');
  d:=replace(d,'Rory', 'Kyle');
  d:=replace(d,'Theo', 'Matt');
  d:=replace(d,'Iris', 'Avah');
  d:=replace(d,'Bramblewick', 'Nick');
  d:=replace(d,'Pip', 'Rilie');
  d:=replace(d,'Wren', 'Joey');
  d:=replace(d,'Lena', 'Angelica');
  d:=replace(d,'rooftop', 'cigar');
  d:=replace(d,'Rooftop', 'Cigar');
  d:=replace(d,'Ledger the Lynx', 'Patron the Ledger Lynx');
  d:=replace(d,'The Original Example Property Co.', 'The Original Patron Group');
  d:=replace(d,'A Second Example Property Co.', 'A Second Patron Group');
  d:=replace(d,'its own Example Property Co.', 'its own Dave');
  d:=replace(d,'Example Co. Standard Time', 'Patron Standard Time');
  candidate:=d::jsonb;
  IF jsonb_path_query_array(candidate,'strict $.** ? (@.type() == "number" || @.type() == "boolean")') IS DISTINCT FROM jsonb_path_query_array(r.data,'strict $.** ? (@.type() == "number" || @.type() == "boolean")')
   OR jsonb_path_query_array(candidate,'strict $.**.id') IS DISTINCT FROM jsonb_path_query_array(r.data,'strict $.**.id') THEN
   RAISE EXCEPTION 'name restoration would alter catalog IDs or numbers: %',r.key;
  END IF;
  UPDATE public.catalog SET data=candidate WHERE key=r.key;
  n:=n+1;
 END LOOP;
 IF n<>6 THEN RAISE EXCEPTION 'name restoration: expected 6 catalog rows, found %',n; END IF;
 before_def:=pg_get_functiondef('public.ask_raise'::regproc);
 IF position('hal is out of yeses' in before_def)=0 THEN RAISE EXCEPTION 'name restoration: ask_raise wording changed'; END IF;
 EXECUTE replace(before_def,'hal is out of yeses','dave is out of yeses');
END $restore$;
