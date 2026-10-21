const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');const s=fs.readFileSync('index.html','utf8');
const a=s.indexOf('function normalizeBreakInvite'),b=s.indexOf('/** Live updates: any change',a),sandbox={};vm.createContext(sandbox);vm.runInContext(s.slice(a,b)+';this.validate=normalizeBreakInvite;this.scene=officeSceneAt;',sandbox);
const now=1800000000000,players=[{id:'known'}],invite={id:'known',kind:'break',t:now};
assert.equal(sandbox.validate(invite,now,players).until,now+45000);for(const bad of [null,{}, {...invite,id:'unknown'}, {...invite,kind:'thanks'}, {...invite,t:now+5001},{...invite,t:now-45001},{...invite,t:Infinity},{...invite,t:'now'}])assert.equal(sandbox.validate(bad,now,players),null);
assert.equal(sandbox.scene(now),sandbox.scene(now));assert.notEqual(sandbox.scene(now),sandbox.scene(now+1800000));assert.equal(sandbox.scene(now),sandbox.scene(now+5400000));
console.log('PASS: cosmetic invite allowlist, known players, expiry, future/replay bounds, numeric validation and shared prop phases');
