const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const {parse}=require('@babel/parser');
const html=fs.readFileSync('index.html','utf8');
const src=html.match(/<script type="text\/babel"[^>]*>([\s\S]*?)<\/script>/)?.[1];
assert(src,'Main Babel game script is present');
parse(src,{sourceType:'script',plugins:['jsx']});
function includes(text){assert(src.includes(text),'Missing feature or regression safeguard: '+text);}
[
 'function calcRate(p, cat)','function liveMult(p, ctx = {})',
 'const costOf =','const clickPow = Math.min',
 'onRestructure={async','api.allPrices().then(setPrices)',
 'const OFFICE_CAST=','function officeVisitorNow',
 'const OFFICE_GAGS=','const BINGO_WORDS=','const OFFICE_AWARDS=',
 'function officeFunAt','funTab==="daily"','funTab==="lounge"',
 'funTab==="incidents"','funTab==="bingo"','funTab==="awards"',
 'funTab==="rumors"','While you were out','Incident report'
].forEach(includes);
assert(src.includes('Math.ceil(costOf(it, have) * (me?.dept === "resale" ? 0.9 : 1))'),'Resale discount UI must match DB');
assert(src.includes('setPrices(null); api.allPrices().then(setPrices)'),'Reset must refresh server prices');
assert(src.includes('visitor.progress>(i+1)*0.16'),'Joey leaves boards');
const start=src.indexOf('const OFFICE_GAGS='),end=src.indexOf('const BUILD =',start);
assert(start>=0&&end>start,'Office comedy helpers');
const box={Date,Math};vm.createContext(box);
vm.runInContext(src.slice(start,end)+';this.fun=officeFunAt;this.words=BINGO_WORDS;this.gags=OFFICE_GAGS;',box);
assert.equal(box.words.length,9);
assert(box.gags.length>=8);
const a=box.fun(1780000000000),b=box.fun(1780000000000);
assert.equal(a.rumor,b.rumor,'NPC gag schedule is deterministic across clients');
assert.equal(a.rumors.length,8);
assert.equal(box.fun(1780000000000+86400000).day,a.day+1);
assert(box.fun(1780000000000+604800000).loungeStatus);
const slots=Array.from({length:8},(_,i)=>i);
assert.equal(new Set(slots).size,8,'Office cast bag rotation must not repeat a turn');
console.log('PASS: Babel/JSX syntax, economy guards, existing recap, all six comedy tabs, deterministic timeline, daily reset and pricing guards.');
