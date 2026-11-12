"""Actual held RPCs in concurrent disposable PostgreSQL sessions. No hosted access."""
import concurrent.futures
import json
import os
import subprocess

if os.environ.get('PGDATABASE') != 'idle_hands_test':
    raise SystemExit('Refusing anything except the dedicated synthetic database')

A = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
B = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
C = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'

def sql(source, actor=A):
    source = f"SET statement_timeout='15s'; SET request.jwt.claim.sub='{actor}'; " + source
    result = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-c', source], text=True, capture_output=True)
    if result.returncode:
        raise AssertionError(result.stderr)
    return result.stdout.strip()

def together(jobs):
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(jobs)) as pool:
        return list(pool.map(lambda j: sql(*j), jobs))

sql("UPDATE players SET last_deed=NULL,pp=1e40; DELETE FROM office_private.toolkits; "
    f"UPDATE players SET buffs=jsonb_build_array(jsonb_build_object('kind','replyall','mult',0.45,'until',now()+interval '8 minutes')) WHERE id='{B}';")
request = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
call = f"SELECT office_interact('{B}','rescue','{request}');"
replies = together([(call, A), (call, A)])
assert json.loads(replies[0]) == json.loads(replies[1]), 'duplicate requests returned different receipts'
assert sql(f"SELECT count(*) FROM office_private.action_receipts WHERE actor='{A}' AND request='{request}'") == '1'
assert sql(f"SELECT charges->>'rescue' FROM office_private.toolkits WHERE actor='{A}' AND week=week_key()") == '1'
sql('UPDATE players SET last_deed=NULL;')
together([
    (f"SELECT office_interact('{B}','confetti','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee');", A),
    (f"SELECT office_interact('{A}','confetti','ffffffff-ffff-4fff-8fff-ffffffffffff');", B),
])
assert sql('SELECT count(*) FROM players WHERE office_confetti IS NOT NULL') == '2', 'opposite actions lost an effect'

# Completion is observed atomically even when the final contributors arrive together.
sql('DELETE FROM office_private.project_stamps; DELETE FROM office_private.project_completions;')
together([(f"SELECT office_private.project_credit('{actor}',c) FROM unnest(ARRAY['work','facilities','care','playful']) c;", actor) for actor in [A, B, C]])
assert sql('SELECT count(*) FROM office_private.project_stamps WHERE week=week_key()') == '12'
assert sql('SELECT count(*) FROM office_private.project_completions WHERE week=week_key()') == '1'
together([("SELECT office_claim_collectible('nameplate',week_key());", A)] * 2)
assert sql(f"SELECT jsonb_array_length(office_collectibles) FROM players WHERE id='{A}'") == '1'

# Last defense charge can be consumed by only one incoming action.
sql('UPDATE players SET last_deed=NULL,buffs=\'[]\',pp=1e40;')
sql("SELECT office_equip_tools(ARRAY['filter']);", B)
sql(f"UPDATE office_private.toolkits SET charges=jsonb_set(charges,'{{filter}}','1') WHERE actor='{B}' AND week=week_key();")
together([(f"SELECT do_deed('{B}','replyall');", actor) for actor in [A, C]])
assert sql("SELECT count(*) FROM deeds WHERE kind='replyall' AND detail='blocked:filter'") == '1'
assert sql(f"SELECT count(*) FROM players,jsonb_array_elements(buffs) b WHERE id='{B}' AND b->>'kind'='replyall'") == '1'
assert sql(f"SELECT charges->>'filter' FROM office_private.toolkits WHERE actor='{B}' AND week=week_key()") == '0'
print('PASS concurrent receipt replay, opposite actions, project completion, collectible claims and final filter charge')

# Re-running the smaller installer must never downgrade the full capture trigger.
before = sql("SELECT md5(prosrc) FROM pg_proc WHERE oid='office_private.capture_deed()'::regprocedure")
attempt = subprocess.run(['psql', '-X', '-v', 'ON_ERROR_STOP=1', '-f', 'sql/office_action_journal.sql'], text=True, capture_output=True)
assert attempt.returncode != 0 and 'journal downgrade refused' in attempt.stderr
assert sql("SELECT md5(prosrc) FROM pg_proc WHERE oid='office_private.capture_deed()'::regprocedure") == before
print('PASS journal installer refuses a downgrade after the full package')
