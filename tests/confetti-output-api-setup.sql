-- Disposable API fixtures only; retain actual patched functions.
DO $$BEGIN IF current_database()<>'idle_hands_test' THEN RAISE EXCEPTION 'isolated fixture required';END IF;END$$;
UPDATE public.players SET pp=1e6,buffs='[]',office_confetti=NULL,heat=0,dept=NULL,perks='{}',last_deed=NULL,last_tick=now();
UPDATE office_private.shields SET armed=false;
INSERT INTO office_private.toolkits(actor,week) SELECT id,public.week_key() FROM public.players ON CONFLICT DO NOTHING;
UPDATE office_private.toolkits SET slots=ARRAY['rescue','confetti'],charges='{"rescue":2,"confetti":2,"filter":2,"clip":2}';
