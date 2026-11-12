const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),babel=require('@babel/parser');
const html=fs.readFileSync('index.html','utf8'),source=html.match(/<script type="text\/babel"[^>]*>([\s\S]*?)<\/script>/)[1];
const ast=babel.parse(source,{sourceType:'script',plugins:['jsx']});
const functions=ast.program.body.filter(x=>x.type==='FunctionDeclaration');
const c={Math,Date,HEAT_LIMIT:5,officeHour:()=>({hour:12,dow:3}),noraDrinksAt:()=>null};vm.createContext(c);
vm.runInContext(['earnedSeniority','perkCount','liveMult'].map(name=>{const n=functions.find(x=>x.id.name===name);assert(n,name);return source.slice(n.start,n.end);}).join('\n')+';this.earned=earnedSeniority;this.mult=liveMult;',c);
assert.equal(c.earned({equity:20}),20,'old backend fallback');
assert.equal(c.earned({equity:16,seniority_earned:20}),20,'available is not earned');
for(let earned=4;earned<=400;earned++)for(let level=0;level<5;level++){
 const available=earned-level*4;if(available<4)continue;
 const base={equity:available,seniority_earned:earned,perks:{compound:level},buffs:[]};
 const before=c.mult(base),after=c.mult({...base,equity:available-4,perks:{compound:level+1}});
 assert(after>before,`output perk must improve output at ${earned}/${level}`);
 assert.equal(c.earned({...base,equity:0}),earned,'spending preserves earned');
}
const snippet=source.slice(source.indexOf('/* BEGIN NEXT WEEK UI */')+'/* BEGIN NEXT WEEK UI */'.length,source.indexOf('/* END NEXT WEEK UI */')).trim();
assert.equal(snippet,(fs.readFileSync('tools/next-week-ui.jsx','utf8')+'\n'+fs.readFileSync('tools/office-boutique-ui.jsx','utf8')).trim(),'generated UI matches editable source');
const sql=fs.readFileSync('sql/next_week_office.sql','utf8');
assert.equal((sql.match(/-- @END_PATCHES@/g)||[]).length,1,'one reproducible patch block');
assert(sql.includes('ON CONFLICT(source_deed) DO UPDATE SET hush=office_private.action_history.hush OR excluded.hush'));
assert(!sql.includes('DELETE FROM office_private.action_history'),'lifetime history is never reset');
assert(sql.includes("cash transfer deeds are retired"));
assert(sql.includes("p.seniority_earned * 0.03"));
assert(sql.includes('REVOKE ALL ON ALL FUNCTIONS IN SCHEMA office_private'));
assert(sql.includes('record')||sql.includes('capture_deed'));
console.log('PASS next-week: real client multiplier across all affordable balances/levels; old-backend fallback, generated UI and SQL safety contracts');
