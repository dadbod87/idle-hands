const assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs');
const src=fs.readFileSync('index.html','utf8'),start=src.indexOf('function queuedRefresh('),end=src.indexOf('/* ===== components/OfficeFloor.jsx',start);
let timers=new Map(),id=0,calls=0,finish;const document={hidden:false};
const c=vm.createContext({document,setTimeout:fn=>{timers.set(++id,fn);return id;},clearTimeout:n=>timers.delete(n)});
vm.runInContext(src.slice(start,end)+';this.make=queuedRefresh;',c);
const fire=async()=>{const f=[...timers.values()];timers.clear();for(const fn of f)fn();await new Promise(r=>setImmediate(r));};
(async()=>{
 const q=c.make(()=>{calls++;return new Promise(r=>finish=r);});
 for(let n=0;n<100;n++)q.request();assert.equal(timers.size,1);await fire();assert.equal(calls,1);
 for(let n=0;n<100;n++)q.request();assert.equal(timers.size,0,'never overlaps a slow request');
 finish();await new Promise(r=>setImmediate(r));assert.equal(timers.size,1,'one trailing read retains changes during request');
 await fire();assert.equal(calls,2);finish();await new Promise(r=>setImmediate(r));assert.equal(timers.size,0);
 document.hidden=true;q.request();assert.equal(timers.size,0);document.hidden=false;q.request();assert.equal(timers.size,1);q.stop();await fire();assert.equal(calls,2,'cleanup cancels pending work');
 const failed=c.make(async()=>{calls++;throw Error('offline');});failed.request();await fire();failed.request();await fire();assert.equal(calls,4,'failed request releases lock for retry');failed.stop();
 console.log('PASS refresh queue: 200 events, slow request, trailing read, hidden/resume, cleanup, failure retry');
})().catch(e=>{console.error(e);process.exitCode=1;});
