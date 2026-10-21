const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const html=fs.readFileSync('index.html','utf8'),src=html.slice(html.indexOf('let ctx = null'),html.indexOf('/* ===== lib/supabaseClient'));
let now=10000,oscillators=0,visibilityHandler;const storage=new Map(),masters=[];
const param=()=>({value:0,setValueAtTime(){},exponentialRampToValueAtTime(){}});
const node=()=>({connect(){return this;},start(){},stop(){},gain:param(),frequency:param()});
class AudioContext{constructor(){this.currentTime=0;this.sampleRate=8000;this.state='running';this.destination={};}createGain(){const n=node();masters.push(n);return n;}createOscillator(){oscillators++;return node();}createBuffer(c,n){return {getChannelData:()=>new Float32Array(n)}}createBufferSource(){return node()}createBiquadFilter(){return node()}}
const sandbox={Date:{now:()=>now},Math,Number,window:{AudioContext},document:{hidden:false,addEventListener:(name,fn)=>{if(name==='visibilitychange')visibilityHandler=fn;}},localStorage:{getItem:k=>storage.get(k)??null,setItem:(k,v)=>storage.set(k,v)}};
vm.createContext(sandbox);vm.runInContext(src+';this.api={sfx,setMuted,setSoundLevel,getSoundLevel,isMuted};',sandbox);const a=sandbox.api;
assert.equal(a.isMuted(),false);assert.equal(a.getSoundLevel(),1);a.setMuted(false);assert.equal(a.sfx('buy'),true);assert.equal(masters[0].gain.value,1);
const before=oscillators;for(let i=0;i<100;i++)a.sfx('buy');assert.equal(oscillators,before,'repeated stamps are throttled');
a.setMuted(true);assert.equal(masters[0].gain.value,0,'mute silences already scheduled nodes');now+=1000;assert.equal(a.sfx('kind'),false);
a.setSoundLevel(.22);a.setMuted(false);assert.equal(masters[0].gain.value,.22);assert.equal(storage.get('ih_sound_level'),'.22'.replace(/^\./,'0.'));
a.setSoundLevel(0);assert.equal(a.sfx('kind'),false);a.setSoundLevel(.4);sandbox.document.hidden=true;visibilityHandler();assert.equal(masters[0].gain.value,0,'in-flight audio also stops on hide');assert.equal(a.sfx('event'),false,'background tab silent');sandbox.document.hidden=false;visibilityHandler();assert.equal(masters[0].gain.value,.4);
now+=1000;assert.equal(a.sfx('dress'),true,'costume cue exists');assert.equal(a.sfx('filed'),true);assert.equal(a.sfx('break'),true);assert.equal(a.sfx('missing'),false);
a.setSoundLevel(99);assert.equal(a.getSoundLevel(),1);a.setSoundLevel(NaN);assert.equal(a.getSoundLevel(),1);
console.log('PASS: sound graph volume, immediate mute, saved level, zero/hidden silence, throttling and costume/filed/break cues');

// Reload honors a player's explicit choices rather than replacing them with defaults.
storage.set('ih_sound_level','0.22');storage.set('ih_muted','1');
const reload={...sandbox};vm.createContext(reload);vm.runInContext(src+';this.saved={level:getSoundLevel(),muted:isMuted()};',reload);
assert.equal(reload.saved.level,.22);assert.equal(reload.saved.muted,true);
console.log('PASS: fresh sound is on at 100%; saved mute/volume survive reload');
