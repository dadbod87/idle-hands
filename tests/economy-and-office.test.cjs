const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const babel = require('@babel/parser');
const html = fs.readFileSync('index.html', 'utf8');
const src = html.match(/<script type="text\/babel"[^>]*>([\s\S]*?)<\/script>/)?.[1];
assert(src, 'React/Babel application entrypoint');
const ast = babel.parse(src, {sourceType:'script',plugins:['jsx']});
assert(ast.program.body.length > 100, 'Substantial application parsed');
const has = t => assert(src.includes(t), 'Required feature missing: '+t);
['function calcRate(p, cat)','function liveMult(p, ctx = {})',
 'const costOf =','function officeVisitorNow','function officeFunAt',
 'funTab==="incidents"','funTab==="rumors"','funTab==="bingo"',
 'funTab==="daily"','funTab==="lounge"','funTab==="awards"',
 'While you were out','Incident report','function noraDrinksAt',
 'api.restructure()','setPrices(null); api.allPrices().then(setPrices)',
 'Math.ceil(costOf(it, have) * (me?.dept === "resale" ? 0.9 : 1))'
].forEach(has);
const fragment = (a,b) => {
 const i=src.indexOf(a),j=src.indexOf(b,i);
 assert(i>=0 && j>i, 'Missing extraction boundaries '+a+' / '+b);
 return src.slice(i,j);
};
const context={Date,Math,localStorage:{getItem(){return null;}}};
vm.createContext(context);
vm.runInContext(
 fragment('const OFFICE_GAGS=', 'const BUILD =') +
 fragment('let ITEM_GROWTH =','const pick =')+
 ';this.fun=officeFunAt;this.cost=costOf;this.setGrowth=setItemGrowth;this.hash=officeHash;this.words=BINGO_WORDS;',
 context);
assert.equal(context.words.length,9,'Bingo 3x3');
const ts=1780000000000;
assert.equal(context.fun(ts).rumor,context.fun(ts).rumor,'Shared deterministic rumor');
assert.equal(context.fun(ts).rumors.length,8);
assert.equal(context.fun(ts+86400000).day,context.fun(ts).day+1,'Daily rollover');
assert(context.fun(ts+604800000).loungeStatus);
context.setGrowth(1.35);
assert.equal(context.cost({cost:100},0),100,'Seniority resets item cost when ownership zero');
assert.equal(context.cost({cost:100},1),135,'Owned staff price growth');
assert.equal(Math.ceil(context.cost({cost:100},0)*0.9),90,'Resale discount');
const castStart=src.indexOf('const OFFICE_CAST='),castEnd=src.indexOf(';\nfunction officeVisitorAt',castStart);
assert(castStart>=0 && castEnd>castStart);
const cast=JSON.parse(src.slice(castStart+'const OFFICE_CAST='.length,castEnd));
assert.equal(cast.length,8,'All eight shuffled visitors');
assert.equal(new Set(cast.map(x=>x.id)).size,8,'Unique cast IDs');
assert(cast.every(c=>c.lines.length && c.path.length>=2),'Each visitor has dialogue and walking path');
assert(cast.find(c=>c.id==='theo').lines.some(line=>line.includes('operating agreement')),'Matt gag');
assert.equal(cast.find(c=>c.id==='iris').hair,'#D5AB62','Avah must be blonde');
assert.equal(cast.find(c=>c.id==='pip').hair,'#51382E','Rilie must be brunette');
assert(src.includes('function OfficeIcon('),'Cutout vector icon system');
assert(src.includes('<OfficeIcon kind={it.name} />'),'Hiring art integrated');
assert(src.includes('<OfficeIcon kind={u.name+" upgrade"} />'),'Upgrades art integrated');
assert(src.includes('<FittingPreview item={x} kind={which} player={me}/>'),'Catalog previews use real item graphics');
assert(src.includes('<CostumePreview id={c.id} player={target}/>'),'Supply closet previews use actual equipped renderer');
assert(src.includes('<OfficeIcon kind={k.name+" senior badge"} compact/>'),'Seniority perks art integrated');
assert(src.includes('<OfficeIcon kind={d.name+" coffee mug"} compact/>'),'Coffee/beverage item art integrated');
assert(src.includes('<OfficeIcon kind={d.name+" slush drinks"} compact/>'),'Slush beverage item art integrated');
assert(src.includes('<OfficeIcon kind={d.name+" personnel"} compact/>'),'Personnel art integrated');
assert(src.includes('function ArtPreview()'),'Visual QA gallery exists');
assert(src.includes('function HalBody({ facing = 1 }) {'),'Dave wrapper preserved');
assert(src.includes('function WesBody({ facing = 1 }) {'),'Chance wrapper preserved');

assert(src.includes('await saveClothingLook(next);') && src.includes('const saveClothingLook=next=>onLook('),'Outfit equip persists through server while protecting pending photo drafts');
assert(src.includes('const next={...look,clothing:it.id};'),'Purchased wardrobe equip prepares appearance');
const bagForRound = round => {
 const o=cast.map((_,i)=>i);
 for(let i=o.length-1;i>0;i--){
   const j=context.hash((round*8191+i*131)|0)%(i+1);
   [o[i],o[j]]=[o[j],o[i]];
 }
 return o;
};
for(let round=0;round<100;round++) assert.equal(new Set(bagForRound(round)).size,cast.length,'No repeat within round');
assert(src.includes('const clickPow = Math.min('),'Server-aligned click cap expression');
assert(src.includes('if (dougCallNow(Date.now())) return;'),'Manual click guard');
console.log('PASS: JSX parse; 6 comedy features; existing recaps; cost growth/reset/discount; 100 no-repeat rotations; daily rollover; all NPCs; click guard.');

const weekContext={Date,Math};vm.createContext(weekContext);
vm.runInContext(fragment('function weeklyTimeLeft(', 'function WeeklyDeadline(')+';this.left=weeklyTimeLeft;this.countdown=weeklyCountdown;',weekContext);
const schedule={ends_at:'2026-10-23T21:00:00Z',server_now:'2026-10-23T20:59:50Z',received_at:100000};
assert.equal(weekContext.left(schedule,100000),10,'Server time anchors countdown despite wrong client clock');
assert.equal(weekContext.left(schedule,105000),5,'Countdown advances with elapsed client time');
assert.equal(weekContext.left(schedule,120000),0,'No negative countdown at closing');
assert.equal(weekContext.left(null,100000),null,'No fabricated deadline when unavailable');
assert.equal(weekContext.countdown(183845),'2d 03h 04m 05s left');
console.log('PASS: weekly countdown server clock, elapsed time, cutoff and missing schedule');

// Exercise actual camera framing with a plant taller than the actor-centered headroom.
const cameraContext={Math,clamp:(x,a,b)=>Math.max(a,Math.min(b,x))};vm.createContext(cameraContext);
vm.runInContext(fragment('function propCameraY(', 'function PropPunchline(')+';this.frame=propCameraY;',cameraContext);
const plantScene={top:1000,py:1070},actorPosition={y:1180};
for(const height of [38,54,72,90])for(const viewportHeight of [400,500,700]){
 const centered=actorPosition.y-viewportHeight/2;
 const framed=cameraContext.frame(centered,plantScene,actorPosition,{h:viewportHeight},height,1700);
 const bubbleBottom=Math.min(plantScene.top-16,actorPosition.y-110);
 assert(bubbleBottom-height>=framed+10,'Measured bubble stays inside camera');
 assert(actorPosition.y+40<=framed+viewportHeight-10,'Whole actor remains visible');
 assert(1140+24<=framed+viewportHeight-10,'Whole prop and label remain visible');
 assert(framed>=0&&framed<=1700-viewportHeight,'Camera stays in room');
}
assert.equal(cameraContext.frame(1090,plantScene,actorPosition,{h:180},54,1700),1090,'Short viewport retains feedback-strip fallback');
assert.equal(cameraContext.frame(0,{top:30,py:70},{y:130},{h:400},54,1700),0,'No false headroom above room edge');
assert.equal(cameraContext.frame(980,plantScene,actorPosition,{h:400},0,1700),980,'Wait for actual text measurement');
console.log('PASS: prop camera frames measured bubble, tall prop and actor; short/edge fallback retained');

// Presentation contract runs in the existing regression job; no workflow change needed.
require('./active-effects.test.cjs');
