const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),parser=require('@babel/parser');
const source=fs.readFileSync('index.html','utf8').match(/<script type="text\/babel"[^>]*>([\s\S]*?)<\/script>/)[1];
const ast=parser.parse(source,{sourceType:'script',plugins:['jsx']}),names=['OFFICE_COLLECTIBLE_LABELS','OFFICE_DESK_SET_LABELS','officeDisplayItems','officeDisplayChange'];
const ctx={};vm.createContext(ctx);
vm.runInContext(ast.program.body.filter(n=>names.includes(n.id?.name)||n.declarations?.some(d=>names.includes(d.id.name))).map(n=>source.slice(n.start,n.end)).join('\n')+'\nthis.ids=Object.keys(OFFICE_COLLECTIBLE_LABELS).concat(Object.keys(OFFICE_DESK_SET_LABELS));this.sets=Object.keys(OFFICE_DESK_SET_LABELS);',ctx);
const plain=value=>JSON.parse(JSON.stringify(value));
for(const theme of ctx.sets){
 assert.deepEqual(plain(ctx.officeDisplayItems({office_display:['nameplate','corkboard',theme]})),['nameplate','corkboard',theme],'saved boutique sets must reach the world renderer');
 assert.deepEqual(plain(ctx.officeDisplayItems({office_collectibles:[theme]})),[theme],'legacy owned fallback');
 assert.deepEqual(plain(ctx.officeDisplayItems({office_display:[],office_collectibles:[theme]})),[],'explicit hiding overrides ownership');
 assert.deepEqual(plain(ctx.officeDisplayChange(['nameplate','corkboard','plaque'],theme)),{items:['nameplate','corkboard',theme],replaced:'plaque'});
 assert.deepEqual(plain(ctx.officeDisplayChange(['nameplate','theme_it','lamp'],theme==='theme_it'?'theme_chaos':theme)).items,['nameplate',theme==='theme_it'?'theme_chaos':theme,'lamp'],'prefer swapping another set, preserving later lamp');
}
assert.deepEqual(plain(ctx.officeDisplayItems({office_display:['unknown','theme_it','theme_it','corkboard']})),['theme_it','corkboard']);
// Exercise all valid ordered display combinations: no duplicates, lost ownership,
// input mutation, extra slots or multi-click removal is needed for a replacement.
for(const a of ctx.ids)for(const b of ctx.ids.filter(x=>x!==a))for(const c of ctx.ids.filter(x=>x!==a&&x!==b))for(const id of ctx.ids){
 const before=[a,b,c],snapshot=[...before],change=plain(ctx.officeDisplayChange(before,id));
 assert.deepEqual(before,snapshot);assert(change.items.length<=3);assert.equal(new Set(change.items).size,change.items.length);
 if(before.includes(id))assert.deepEqual(change.items,before.filter(x=>x!==id));
 else{assert(change.items.includes(id));assert.equal(before.filter(x=>!change.items.includes(x)).length,1);assert(before.includes(change.replaced));}
}
console.log('PASS decoration display: all four saved sets, explicit hiding and automatic bounded swaps across every ordered full display');
