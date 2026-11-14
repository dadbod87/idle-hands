"""Validate a PRIVATE read-only history export and optionally emit a private import file.

This command never connects to a database. Run the emitted SQL only at the reviewed
release after the additive migration. Raw history must never enter the public repo.
"""
from pathlib import Path
import argparse,json,hashlib,uuid,datetime
p=argparse.ArgumentParser();p.add_argument('snapshot',type=Path);p.add_argument('--emit-sql',type=Path);args=p.parse_args()
data=json.loads(args.snapshot.read_text());assert data['project']=='wbakpxbvqxppqbrwuokp' and data['version']==1
assert isinstance(data['deeds'],list) and len(data['deeds'])<=100000
ids=set()
for r in data['deeds']:
 assert isinstance(r['id'],int) and r['id']>0 and r['id'] not in ids;ids.add(r['id'])
 uuid.UUID(r['actor']);uuid.UUID(r['target']);assert r['actor']!=r['target']
 assert isinstance(r['kind'],str) and len(r['kind'])<=40 and isinstance(r['hush'],bool)
 stamp=r['created_at'].replace('Z','+00:00')
 parsed=datetime.datetime.strptime(stamp,'%Y-%m-%dT%H:%M:%S.%f%z' if '.' in stamp else '%Y-%m-%dT%H:%M:%S%z')
 assert parsed.tzinfo is not None
 assert isinstance(r['amount'],(int,float)) and abs(r['amount'])<float('inf')
digest=hashlib.sha256(args.snapshot.read_bytes()).hexdigest()
print(json.dumps({'rows':len(ids),'exported_at':data['exported_at'],'week':data['week'],'sha256':digest}))
if args.emit_sql:
 out=args.emit_sql.resolve();repo=Path(__file__).resolve().parents[1]
 if repo==out or repo in out.parents:raise SystemExit('Refusing to write private history into the public repository')
 literal=json.dumps(data['deeds'],separators=(',',':')).replace("'","''")
 sql="""-- PRIVATE history import. Review snapshot SHA-256: %s
BEGIN;
LOCK TABLE office_private.action_history IN SHARE ROW EXCLUSIVE MODE;
CREATE TEMP TABLE history_import AS SELECT * FROM jsonb_to_recordset('%s'::jsonb) AS x(id bigint,actor uuid,target uuid,kind text,amount float8,hush boolean,created_at timestamptz,blocked boolean);
DO $$ BEGIN IF EXISTS(SELECT 1 FROM history_import i JOIN office_private.action_history h ON h.source_deed=i.id WHERE h.actor<>i.actor OR h.target<>i.target OR h.kind<>i.kind OR h.happened_at<>i.created_at) THEN RAISE EXCEPTION 'Conflicting source identity'; END IF; END $$;
INSERT INTO office_private.action_history(source_deed,actor,target,kind,category,amount,hush,happened_at,week)
SELECT id,actor,target,kind,office_private.action_category(kind,CASE WHEN blocked THEN 'blocked:filter' ELSE NULL END),amount,hush,created_at,public.week_key(created_at) FROM history_import
ON CONFLICT(source_deed) DO UPDATE SET hush=office_private.action_history.hush OR excluded.hush;
UPDATE office_private.history_coverage SET started_at=least(started_at,coalesce((SELECT min(created_at) FROM history_import),started_at));
COMMIT;
"""%(digest,literal)
 out.parent.mkdir(parents=True,exist_ok=True);out.write_text(sql);print('Wrote private import payload; no database changes executed.')
