const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const s=fs.readFileSync('index.html','utf8'),a=s.indexOf('function activeEffects('),b=s.indexOf('function ActiveEffects(',a);
const c={Date,HEAT_LIMIT:5,DEED_TEXT:{meeting:{label:'Recurring meeting'}},noraDrinksAt:()=>null,eventAt:()=>null,countdown:ms=>String(Math.round(ms/1000))};vm.createContext(c);vm.runInContext(s.slice(a,b)+';this.project=activeEffects;',c);
const now=Date.parse('2026-10-22T09:00:00Z'),iso=n=>new Date(now+n).toISOString();
const p={heat:5,frenzy_until:iso(77000),buffs:[{kind:'espresso',mult:1.35,until:iso(77000)},{kind:'meeting',mult:.65,until:iso(100000)},
 {kind:'crash',mult:.85,start:iso(77000),until:iso(150000)},{kind:'legacy',mult:1.2,from:iso(77000),until:iso(150000)},
 {kind:'expired',mult:2,until:iso(-1)},{kind:'bad-date',mult:2,until:'oops'}]};
const snapshot=JSON.stringify(p),cat={drinks:[{id:'espresso',name:'Double Espresso'}]};
let list=c.project(p,cat,now);assert.equal(list.length,4);assert.equal(list[0].name,'Double Espresso');assert.equal(list[1].name,'Recurring meeting');assert.equal(list[1].tone,'negative');assert.equal(list[2].mult,7);assert.equal(list[3].until,null);
list=c.project(p,cat,now+77000);assert.equal(list.length,4);assert(!list.some(e=>e.id==='frenzy'));assert(list.some(e=>e.name==='Drink crash'));
assert.equal(c.project(p,cat,now+150000).length,1);assert.equal(JSON.stringify(p),snapshot);
c.noraDrinksAt=()=>({remaining:60,mult:1.2});c.eventAt=()=>({id:'lunch',name:'Catered Lunch',mult:2.5,end:now+60000,line:'Office event'});
list=c.project({buffs:[]},{},now);assert.equal(list.length,2);assert.equal(list[0].until,now+60000);assert.equal(list[1].id,'event-lunch');
assert.equal(c.effectBenefit(.65),'−35% output');assert.equal(c.effectBenefit(7),'+600% output');assert.equal(c.effectRemaining(null,now),'Until settled');
console.log('PASS: actual HUD projection; authoritative multipliers, delayed/legacy starts, expiry boundaries, schedule windows, readable labels and immutable player state');
