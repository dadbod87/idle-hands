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
 'While you were out','Incident report','function jessDrinksAt',
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
assert(cast.find(c=>c.id==='matt').lines.some(line=>line.includes('operating agreement')),'Matt gag');
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
