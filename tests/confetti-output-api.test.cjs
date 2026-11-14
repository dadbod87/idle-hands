// Isolated JWT/API extension; never targets provider hosts.
const assert=require('node:assert/strict'),crypto=require('node:crypto');
const url=process.env.IDLE_HANDS_TEST_API||'http://127.0.0.1:3000';assert.equal(new URL(url).hostname,'127.0.0.1');
const secret=process.env.IH_TEST_JWT_SECRET;assert(secret&&secret.length>=32);
const a='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',b='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
function token(id){const h=Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url'),p=Buffer.from(JSON.stringify({sub:id,role:'authenticated',aud:'authenticated',exp:Math.floor(Date.now()/1000)+1800})).toString('base64url'),s=h+'.'+p;return s+'.'+crypto.createHmac('sha256',secret).update(s).digest('base64url');}
async function rpc(name,args={},id=a){const r=await fetch(url+'/rpc/'+name,{method:'POST',headers:{'Content-Type':'application/json',...(id?{Authorization:'Bearer '+token(id)}:{})},body:JSON.stringify(args)});return {status:r.status,body:await r.json()};}
function ok(r){assert(r.status>=200&&r.status<300,JSON.stringify(r));return r.body;}
(async()=>{
 const args={p_target:a,p_action:'confetti',p_request:crypto.randomUUID()};
 assert((await rpc('office_interact',args,null)).status>=400);
 const result=ok(await rpc('office_interact',args,b));assert.equal(result.detail,'sabotage:confetti');assert.deepEqual(ok(await rpc('office_interact',args,b)),result);
 const status=ok(await rpc('office_week_status'));assert.equal(status.confetti_rules.mult,0.65);assert.equal(status.confetti.mult,0.65);
 const cleared=ok(await rpc('office_clear_confetti'));assert.equal(cleared.office_confetti,null);assert(!cleared.buffs.some(x=>x.kind==='confetti'));
 const profile=ok(await rpc('office_profile',{p_player:b,p_period:'week',p_peer:null}));assert(profile.by_kind.some(x=>x.kind==='confetti'&&x.category==='sabotage'));
 console.log('PASS confetti JWT API: anonymous refusal, authoritative multiplier, receipt replay, own cleanup and sabotage history');
})().catch(e=>{console.error(e);process.exitCode=1;});
