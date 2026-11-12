const fs=require('fs'),vm=require('vm');
const B=require(process.cwd()+'/vendor/babel-7.28.5.min.js');
const source=fs.readFileSync('tools/next-week-ui.jsx','utf8');
const slots=[],effects=[];let ix=0;
function state(v){const i=ix++;if(!(i in slots))slots[i]=typeof v==='function'?v():v;return [slots[i],n=>slots[i]=typeof n==='function'?n(slots[i]):n];}
function ref(v){const i=ix++;if(!(i in slots))slots[i]={current:v};return slots[i];}
function effect(fn,deps){const i=ix++,old=slots[i];if(!old||deps.some((x,j)=>x!==old[j])){slots[i]=deps;effects.push(fn);}}
let resolveStatus,rejectProfile;
const ctx={React:{createElement:(type,props,...children)=>({type,props,children})},useState:state,useRef:ref,useEffect:effect,useCallback:fn=>{ix++;return fn;},api:{officeWeek:()=>new Promise(r=>resolveStatus=r),officeProfile:()=>new Promise((r,e)=>rejectProfile=e)},document:{visibilityState:'visible',addEventListener(){},removeEventListener(){}},setInterval:()=>0,clearInterval(){},setTimeout:()=>0,clearTimeout(){},DEED_TEXT:{},Date,Math,crypto:require('crypto').webcrypto};
vm.createContext(ctx);vm.runInContext(B.transform(source,{presets:['react']}).code+'\nthis.panel=OfficeWeekPanel;',ctx);
const me={id:'fixture',name:'Fixture'},props={me,board:[me],onPlayer(){},initialPlayer:me.id};
function render(){ix=0;return ctx.panel(props)}
function text(t){if(t==null||t===false)return '';if(typeof t!=='object')return String(t);return (t.children||[]).flat(Infinity).map(text).join(' ')}
(async()=>{render();for(const e of effects.splice(0))e();rejectProfile(new Error('PROFILE_FAILED'));for(let i=0;i<8;i++)await Promise.resolve();let before=text(render());resolveStatus({version:1,week:'fixture',project:{mine:[]},toolkit:{slots:[],charges:{}},collectibles:[],completed_weeks:[]});for(let i=0;i<8;i++)await Promise.resolve();let after=text(render());const observed={profileErrorInitiallyVisible:before.includes('PROFILE_FAILED'),profileErrorAfterStatus:after.includes('PROFILE_FAILED'),permanentLoadingAfterBothRequestsFinished:after.includes('Reading the personnel file')};require('node:assert/strict').deepEqual(observed,{profileErrorInitiallyVisible:true,profileErrorAfterStatus:true,permanentLoadingAfterBothRequestsFinished:false});console.log('PASS actual office panel: late status success preserves profile failure and retry');})();
