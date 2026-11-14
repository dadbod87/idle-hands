"""Actual pg_cron/background-worker and rollover-lock checks. Disposable DB only."""
import subprocess,time,json
from pathlib import Path

def query(sql,check=True):
    p=subprocess.run(['psql','-X','-v','ON_ERROR_STOP=1','-At','-c',sql],text=True,capture_output=True)
    if check and p.returncode:raise AssertionError(p.stderr)
    return p.stdout.strip()

assert query('select current_database()')=='idle_hands_test'
def clock(at):
    query("CREATE OR REPLACE FUNCTION office_private.race_now() RETURNS timestamptz LANGUAGE sql STABLE SET search_path='' AS $$SELECT '%s'::timestamptz$$"%at)
def payload(name,ok=True):
    r=subprocess.run(['psql','-X','-v','ON_ERROR_STOP=1','-f','sql/weekly_race_'+name+'.sql'],text=True,capture_output=True)
    assert (r.returncode==0)==ok,r.stderr
    return r.stderr
def activate(ok=True):return payload('activate',ok)
def prepare(ok=True):return payload('prepare',ok)
def runs(job):return int(query("SELECT count(*) FROM cron.job_run_details WHERE jobid=%s AND status='succeeded'"%job) or '0')
def wait_for(check,diagnostic):
    until=time.monotonic()+18
    while time.monotonic()<until:
        if check():return
        time.sleep(.35)
    raise AssertionError(diagnostic())

clock('2026-11-13 23:59:59Z')
assert 'held until Friday' in activate(False)
assert 'held until Friday' in prepare(False)
clock('2026-11-14 00:00Z')
query("UPDATE public.season_state SET current_week='old-unclosed-week'")
assert 'normal rollover is incomplete' in prepare(False)
query("UPDATE public.season_state SET current_week=public.week_key(office_private.race_now()); UPDATE public.players SET week_pp=100,pp=1000,last_tick='2026-11-14 00:00Z',last_restructure=null;")
assert 'prepare and verify' in activate(False)
before=query('SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM public.players p')
prepare();prepare()
assert query('SELECT enabled FROM office_private.race_control')=='f'
assert query("SELECT count(*) FROM cron.job WHERE jobname='idle-hands-weekly-race' AND active AND schedule='*/5 * * * *' AND command='SELECT office_private.capture_race();' AND username=current_user AND database=current_database()")=='1'
probe=int(query("SELECT cron.schedule('idle-hands-weekly-race-ci-probe','1 second','SELECT office_private.capture_race();')"))
diagnostic=lambda:query("SELECT status,return_message FROM cron.job_run_details WHERE jobid=%s"%probe)
wait_for(lambda:runs(probe)>0,diagnostic)
assert query('SELECT count(*) FROM office_private.race_batches')=='0','prepared scheduler recorded before release activation'
assert query('SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM public.players p')==before

# Simulate the operator confirming Production READY, then activate on Friday evening.
clock('2026-11-14 00:05Z');activate()
assert query("SELECT not_before='2026-11-14 00:05Z'::timestamptz FROM office_private.race_control")=='t'
previous=runs(probe)
clock('2026-11-14 00:06Z');activate()
assert query("SELECT not_before='2026-11-14 00:05Z'::timestamptz FROM office_private.race_control")=='t','activation replay moved the start time'
assert 'remain disabled' in prepare(False)
wait_for(lambda:runs(probe)>previous and query('SELECT count(*) FROM office_private.race_batches')=='1',diagnostic)
assert query('SELECT count(*) FROM office_private.race_batches')=='1'
assert query("SELECT bool_and(recorded_at>='2026-11-14 00:05Z' AND recorded_at<'2026-11-14 08:00Z') FROM office_private.race_batches")=='t','first recording was retroactive or still delayed until Saturday'
assert query('SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM public.players p')==before,'background capture changed players'
query("SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname IN('idle-hands-weekly-race','idle-hands-weekly-race-ci-probe')")

# The roller's FOR UPDATE lock must prevent a shared snapshot halfway through a wipe.
clock('2026-11-21 08:00Z')
query('UPDATE public.players SET week_pp=500')
rolling=subprocess.Popen(['psql','-X','-v','ON_ERROR_STOP=1','-At','-c',"BEGIN;SELECT current_week FROM public.season_state WHERE id=1 FOR UPDATE;SELECT pg_advisory_xact_lock(728194,9);UPDATE public.season_state SET current_week=public.week_key(office_private.race_now());UPDATE public.players SET week_pp=0;SELECT pg_sleep(1.5);COMMIT;"],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
until=time.monotonic()+5
while time.monotonic()<until:
    if query("SELECT EXISTS(SELECT 1 FROM pg_locks WHERE locktype='advisory' AND classid=728194 AND objid=9 AND granted)")=='t':break
    time.sleep(.03)
else:raise AssertionError('roller lock did not start')
capture=subprocess.Popen(['psql','-X','-v','ON_ERROR_STOP=1','-At','-c','SELECT office_private.capture_race()'],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
time.sleep(.2);assert capture.poll() is None,'capture did not wait for the season lock'
out,err=rolling.communicate(timeout=8);assert rolling.returncode==0,err
out,err=capture.communicate(timeout=8);assert capture.returncode==0 and out.strip()=='3',(out,err)
assert query('SELECT count(*) FROM office_private.race_points p JOIN office_private.race_batches b ON b.id=p.batch WHERE b.week=public.week_key(office_private.race_now()) AND p.weekly_earnings<>0')=='0'
clock('2026-11-21 08:05Z')
copies=[subprocess.Popen(['psql','-X','-v','ON_ERROR_STOP=1','-At','-c','SELECT office_private.capture_race()'],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True) for _ in range(2)]
values=[]
for p in copies:
    out,err=p.communicate(timeout=8);assert p.returncode==0,err;values.append(out.strip())
assert sorted(values)==['0','3'],values

# A colliding job name must never be silently overwritten.
query("SELECT cron.schedule('idle-hands-weekly-race','*/5 * * * *','SELECT 1;')")
assert 'definition drift' in activate(False)
assert query("SELECT command FROM cron.job WHERE jobname='idle-hands-weekly-race'")=='SELECT 1;'
query('UPDATE office_private.race_control SET enabled=false')
assert 'scheduler definition drift' in prepare(False)
query("SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname='idle-hands-weekly-race'; UPDATE office_private.race_control SET enabled=false;")
query("CREATE OR REPLACE FUNCTION office_private.race_now() RETURNS timestamptz LANGUAGE sql STABLE SET search_path='' AS $$SELECT now()$$")
print('PASS actual pg_cron: guarded/idempotent preparation with zero pre-release capture, post-release Friday recording, immutable activation time, successful background execution, unchanged players, rollover lock, concurrent capture replay and drift refusal')
