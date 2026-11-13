// Real HTTP -> PostgREST JWT verification -> Postgres roles/RLS -> actual held RPCs.
// Test-only identities/secret; never accepts a non-loopback endpoint or provider credentials.
const assert=require('node:assert/strict'),crypto=require('node:crypto');
const url=process.env.IDLE_HANDS_TEST_API||'http://127.0.0.1:3000';
assert.equal(new URL(url).hostname,'127.0.0.1','isolated loopback API required');
const secret=process.env.IH_TEST_JWT_SECRET;assert(secret&&secret.length>=32,'generated isolated JWT secret required');
const a='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',b='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
function token(id,extra={},key=secret){const h=Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url'),p=Buffer.from(JSON.stringify({sub:id,role:'authenticated',aud:'authenticated',exp:Math.floor(Date.now()/1000)+1800,...extra})).toString('base64url'),data=h+'.'+p;return data+'.'+crypto.createHmac('sha256',key).update(data).digest('base64url');}
async function call(path,body,jwt=token(a),method=body===undefined?'GET':'POST',extra={}){const r=await fetch(url+path,{method,headers:{...(jwt?{Authorization:'Bearer '+jwt}:{}),'Content-Type':'application/json',...extra},...(body===undefined?{}:{body:JSON.stringify(body)})});const text=await r.text();let data;try{data=JSON.parse(text);}catch{data=text;}return {status:r.status,data};}
const rpc=(name,args={},jwt)=>call('/rpc/'+name,args,jwt);
function ok(r){assert(r.status>=200&&r.status<300,JSON.stringify(r));return r.data;}
function denied(r){assert(r.status>=400&&r.status<500,JSON.stringify(r));}
(async()=>{
 let ready=false;for(let i=0;i<25;i++){try{const r=await rpc('office_shop_state');if(r.status===200){ready=true;break;}}catch{}await new Promise(r=>setTimeout(r,400));}assert(ready,'PostgREST did not become ready');
 denied(await rpc('office_shop_state',{},null));
 assert.equal((await rpc('office_shop_state',{},token(a,{},'invalid-signature-test-only-secret'))).status,401);
 assert.equal((await rpc('office_shop_state',{},token(a,{exp:Math.floor(Date.now()/1000)-3600}))).status,401);
 denied(await rpc('office_shop_state',{},token('ffffffff-ffff-4fff-8fff-ffffffffffff')));
 const own=ok(await call('/players?select=id,pp'));assert.equal(own.length,1);assert.equal(own[0].id,a);
 assert.deepEqual(ok(await call('/players?select=id&id=eq.'+b)),[]);
 denied(await call('/players?id=eq.'+a,{pp:999},token(a),'PATCH'));
 denied(await call('/season_results?select=*'));
 denied(await call('/season_results?select=*',undefined,token(a),'GET',{'Accept-Profile':'office_private'}));
 denied(await rpc('office_set_cosmetic_visibility',{p_slot:'held',p_visible:false},null));
 const hidden=ok(await rpc('office_set_cosmetic_visibility',{p_slot:'held',p_visible:false}));assert.equal(hidden.cosmetic_equipped.held,null);assert.equal(hidden.pp,own[0].pp);assert.deepEqual(ok(await rpc('office_set_cosmetic_visibility',{p_slot:'held',p_visible:false})),hidden);
 denied(await rpc('office_set_cosmetic_visibility',{p_slot:'balance',p_visible:false}));
 denied(await rpc('office_race',{},null));
 const race=ok(await rpc('office_race'));assert.equal(race.version,1);assert.equal(race.points.length,3);assert(race.points.some(p=>p.player===a&&p.balance===own[0].pp));assert(race.points.filter(p=>p.player!==a).every(p=>!Object.hasOwn(p,'balance')));
 const peerRace=ok(await rpc('office_race',{},token(b)));assert(peerRace.points.some(p=>p.player===b&&Object.hasOwn(p,'balance')));assert(peerRace.points.filter(p=>p.player!==b).every(p=>!Object.hasOwn(p,'balance')));
 denied(await rpc('office_race',{p_week:'forged-week'}));denied(await rpc('office_race',{p_day:'2000-01-01'}));denied(await rpc('office_race',{},token('ffffffff-ffff-4fff-8fff-ffffffffffff')));
 denied(await rpc('capture_race'));denied(await call('/race_points?select=*',undefined,token(a),'GET',{'Accept-Profile':'office_private'}));
 console.log('PASS JWT weekly race: authenticated recorded scores, owner-only balances, invalid/anonymous/deleted-user refusal and denied collector/private tables');
 const shop=ok(await rpc('office_shop_state'));assert.equal(shop.items.length,6);assert.equal(shop.items.find(x=>x.id==='coffee_tech').eligible,false);
 denied(await rpc('office_shop_quote',{p_item:'coffee_tech'}));denied(await rpc('office_shop_quote',{p_item:'forged'}));
 const q=ok(await rpc('office_shop_quote',{p_item:'theme_facilities'}));assert(q.price>0);
 denied(await rpc('office_shop_buy',{p_quote:q.quote,p_request:crypto.randomUUID()},token(b)));
 const id=crypto.randomUUID(),args={p_quote:q.quote,p_request:id};const results=await Promise.all([rpc('office_shop_buy',args),rpc('office_shop_buy',args)]);const bought=ok(results[0]);assert.deepEqual(ok(results[1]),bought);assert(bought.player.office_collectibles.includes('theme_facilities'));
 const after=ok(await call('/players?select=id,pp'))[0];assert.equal(after.pp,own[0].pp-q.price);
 denied(await rpc('office_shop_buy',{p_quote:crypto.randomUUID(),p_request:id}));
 denied(await rpc('office_shop_buy',{p_quote:q.quote,p_request:crypto.randomUUID()}));
 const status=ok(await rpc('office_week_status'));assert(status.collection.display.includes('theme_facilities'));
 ok(await rpc('office_display_collectibles',{p_items:[]}));assert.equal(ok(await call('/players?select=pp'))[0].pp,after.pp);
 const book=ok(await rpc('office_recordbook',{p_week:null,p_player:a}));assert.equal(book.season.coverage,'standings');assert.equal(book.standings.length,3);assert.equal(book.personal_best.earnings,500);assert.equal(book.standings[0].place,1);
 // Existing costume resolution and the earlier shield pack also cross the real API.
 const dressed=ok(await rpc('dress',{p_target:a,p_outfit:'budget_wizard'}));assert.equal(dressed.outfit.id,'budget_wizard');assert(Date.parse(dressed.outfit.until)>Date.now()+44*60000);
 denied(await rpc('set_look',{p_look:{clothing:'coffee_tech'}}));
 const shield=ok(await rpc('office_shield_quote')),shieldId=crypto.randomUUID();ok(await rpc('office_buy_shield',{p_quote:shield.quote,p_request:shieldId}));
 const attackArgs={p_target:a,p_kind:'replyall',p_request:crypto.randomUUID()};const reflected=ok(await rpc('office_deed',attackArgs,token(b)));assert.equal(reflected.reflected,true);assert.deepEqual(ok(await rpc('office_deed',attackArgs,token(b))),reflected);
 const sender=ok(await call('/players?select=id,buffs',undefined,token(b)))[0];assert(sender.buffs.some(x=>x.kind==='replyall'));assert.equal(ok(await rpc('office_week_status')).shield.armed,false);
 const bs=ok(await rpc('office_shop_state',{},token(b)));assert.equal(bs.items.find(x=>x.id==='theme_facilities').owned,false);
 console.log('PASS JWT-authenticated PostgREST API: missing/forged/expired/unknown-user rejection, role/RLS isolation, participation gate, quote ownership, concurrent replay, exact single payment, free display, costumes, one-shot reflection/replay and preserved complete standings');
})().catch(e=>{console.error(e);process.exitCode=1;});
