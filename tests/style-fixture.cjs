// Intercepted simulation for UI only; actual payment RPC bodies run in customization-contract.sql.
const fs=require('node:fs'),{installGameFixture}=require('./game-fixture.cjs');
const fittings=JSON.parse(fs.readFileSync(require('node:path').join(__dirname,'../index.html'),'utf8').match(/const ART_FITTINGS=(.*?);\n/)[1]);
fittings.office_kit.push({id:'tv1',name:'The Productivity Flatscreen',slot:'tv',tier:1,secs:259200,min_cost:50000000});
async function installStyleFixture(page,options={}){
 let quote=null,serial=0,failed=false;
 const fixture=await installGameFixture(page,{items:[{id:'intern',name:'Office Intern',cost:100,rate:50,desc:'Isolated style preview staff'}],fittings,ownedPins:['beta'],handleRpc:async(rpc,a,p)=>{
  if(rpc==='quote_style'){
   if(options.failQuote)return {status:400,body:{message:'Quote temporarily unavailable'}};
   const old=p.cosmetic_styles[a.p_item]||{color:null,design:'solid'},color_fee=old.color!==a.p_color?2880000:0,design_fee=old.design!==a.p_design&&a.p_design!=='solid'?2880000:0;
   quote={id:'00000000-0000-4000-8000-'+String(++serial).padStart(12,'0'),item:a.p_item,color:a.p_color,design:a.p_design,color_fee,design_fee,total:color_fee+design_fee,balance:p.pp,rate:100,seconds_per_change:28800,expires_at:new Date(Date.now()+(options.ttl||120000)).toISOString()};return {body:quote};
  }
  if(rpc==='apply_style'){
   if(options.failApply&&!failed){failed=true;return {status:400,body:{message:'Output changed; review a fresh quote'}};}
   if(!quote||a.p_quote!==quote.id||p.pp<quote.total)return {status:400,body:{message:'Style request declined'}};
   p.pp-=quote.total;p.spent+=quote.total;p.cosmetic_styles[quote.item]={color:quote.color,design:quote.design};p.cosmetic_revision++;return options.lostResponse?{status:503,body:{message:'Response lost after save'}}:{body:p};
  }
  if(rpc==='office_set_cosmetic_visibility'){
   if(options.failVisibility)return {status:503,body:{message:'Appearance update unavailable'}};
   if(a.p_slot==='pin')p.pin=null;
   else if(a.p_slot==='clothing')p.look.clothing='starter';
   else if(a.p_visible)delete p.cosmetic_equipped[a.p_slot];
   else p.cosmetic_equipped[a.p_slot]=null;
   p.cosmetic_revision++;return {body:p};
  }
  if(rpc==='equip_style_item'){
   const item=fittings.office_kit.concat(fittings.vanity).find(x=>x.id===a.p_item);
   if(item)p.cosmetic_equipped[item.slot]=item.id;else if(a.p_item.startsWith('pin:'))p.pin=a.p_item.slice(4);else p.look.clothing=a.p_item;
   p.cosmetic_revision++;return {body:p};
  }
 }});
 Object.assign(fixture.player,{pp:options.balance??1000000000,spent:0,equity:0,kit:{desk:'d3',chair:'c2',rug:'r2',art:'w2',tv:'tv1'},vanity:{held:'h2'},cosmetic_styles:options.styles||{},cosmetic_equipped:{},cosmetic_revision:0});return fixture;
}
module.exports={installStyleFixture,fittings};
