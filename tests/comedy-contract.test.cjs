const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),s=fs.readFileSync('index.html','utf8');
const extract=(a,b)=>{const i=s.indexOf(a),j=s.indexOf(b,i);assert(i>=0&&j>i);return s.slice(i,j);};const c={Date,Math};vm.createContext(c);
vm.runInContext(extract('const OFFICE_GAGS=','const BUILD =')+extract('const PROP_ACTIONS={','function PerformanceArt')+';this.fun=officeFunAt;this.rumor=rumorIndex;this.gags=OFFICE_GAGS;this.actions=PROP_ACTIONS;this.lounge=loungeStory;',c);
assert(c.gags.length>=36);for(let slot=4200000;slot<4210000;slot++){assert.notEqual(c.rumor(slot),c.rumor(slot-1),'No adjacent repeats even at shuffled-bag boundary');assert.equal(c.fun(slot*240000).rumor,c.gags[c.rumor(slot)]);}
for(const [total,stage] of [[0,0],[2,0],[3,1],[7,1],[8,2],[14,2],[15,3],[900,3]])assert.equal(c.lounge({actions:{plant:total}}).stage,stage);
for(const kind of ['plant','bench','apology','calendar','shelf','notice','lounge']){assert(c.actions[kind].lines.length>=6);assert.equal(new Set(c.actions[kind].lines).size,c.actions[kind].lines.length);}
console.log('PASS: 36+ gags, 10,000 no-repeat rumor transitions, four real-count lounge stages and varied free scene scripts');
