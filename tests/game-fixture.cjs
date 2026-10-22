// Runs the unmodified game UI and real Supabase client against intercepted HTTP.
// Every Supabase request is fulfilled locally. No production credentials or writes.
const fixtureId='00000000-0000-4000-8000-000000000001';

function makeOfficePlayFixture(){
 const votes={},nominations={},actions={},people={};
 const state=id=>{const entries=Object.values(votes),counts=[0,1,2].map(i=>entries.filter(v=>v===i).length),totals={},contributors=new Set();for(const [key,a] of Object.entries(actions)){totals[a.kind]=(totals[a.kind]||0)+a.n;contributors.add(a.id);}
 const grouped={};for(const [key,recipient] of Object.entries(nominations)){const category=key.split('|')[1],k=category+'|'+recipient;grouped[k]??={category,recipient,name:people[recipient]||'QA Pal',votes:0};grouped[k].votes++;}
 return {week:'2026-43',ends_at:'2026-10-23T23:00:00Z',poll:{question:'Who gets custody of the thermostat?',options:['The Cold Coalition','The Sweater Lobby','The plastic plant'],counts,total:entries.length,mine:votes[id]??null},previous_poll:{question:'The printer needs a name. Legal insists.',options:['Jamothy','Print Eastwood','Out of Office'],counts:[0,0,0],total:0},nominations:Object.values(grouped),my_nominations:Object.fromEntries(Object.entries(nominations).filter(([k])=>k.startsWith(id+'|')).map(([k,v])=>[k.split('|')[1],v])),actions:totals,contributors:contributors.size,my_actions:Object.fromEntries(Object.values(actions).filter(a=>a.id===id).map(a=>[a.kind,a.n])),hydrators:Object.values(actions).filter(a=>a.kind==='plant').map(a=>({id:a.id,name:people[a.id],visits:a.n}))};};
 return {people,state,vote:(id,c)=>{votes[id]=c;return state(id);},nominate:(id,c,r)=>{nominations[id+'|'+c]=r;return state(id);},perform:(id,k)=>{const key=id+'|'+k,a=actions[key];if(!a)actions[key]={id,kind:k,n:1,t:Date.now()};else if(a.n<6&&Date.now()-a.t>=15000){a.n++;a.t=Date.now();}return state(id);}};
}

async function installGameFixture(page,options={}) {
 const now=new Date().toISOString();
 const player={id:options.id||fixtureId,name:options.name||'QA Employee',created_at:'2026-01-01T00:00:00Z',signed_at:now,last_tick:now,
 pp:500000,week_pp:500000,lifetime:500000,equity:2,raises:0,heat:0,owned:{intern:2},upgrades:[],buffs:[],perks:[],achievements:[],
 wardrobe_owned:['hoodie','cardigan','blazer','hawaiian','hoodie_gold','friday'],pet:'pig',pets:['pig','calf','moth','pigeon','balloon','dragon'],
 look:{build:'regular',bottom:'trousers',gender:'neutral',hair:'messy',hairColor:1,skin:0,eyes:'tired',expression:'deadpan',top:0,legs:0,clothing:'starter'},
 extras:options.ownedPins||[],pin:options.pin||null,vanity:{},kit:{desk:'d3',chair:'c2',rug:'r2'},streak:0,goodwill:0,notoriety:0};
 const calls=[];const officePlay=options.playStore||makeOfficePlayFixture();officePlay.people[player.id]=player.name;for(const p of options.coworkers||[])officePlay.people[p.id]=p.name;
 await page.addInitScript(({id})=>{
  const exp=Math.floor(Date.now()/1000)+3600;
  const token=btoa(JSON.stringify({alg:'HS256',typ:'JWT'}))+'.'+btoa(JSON.stringify({sub:id,role:'authenticated',exp}))+'.fixture';
  localStorage.setItem('sb-wbakpxbvqxppqbrwuokp-auth-token',JSON.stringify({access_token:token,refresh_token:'isolated-fixture',expires_at:exp,expires_in:3600,token_type:'bearer',user:{id,is_anonymous:false,aud:'authenticated',role:'authenticated'}}));
  if(localStorage.getItem('ih_muted')===null)localStorage.setItem('ih_muted','1');
 },{id:player.id});
 await page.routeWebSocket('**/wbakpxbvqxppqbrwuokp.supabase.co/**', ws=>options.liveBus?options.liveBus.connect(ws):ws.close());
 await page.route('https://wbakpxbvqxppqbrwuokp.supabase.co/**',async route=>{
  const req=route.request(),url=new URL(req.url());
  let result=null;
  if(url.pathname.includes('/auth/'))result={id:player.id,is_anonymous:false};
  else if(url.pathname.includes('/rpc/')){
   const rpc=url.pathname.split('/').pop(),args=req.postDataJSON()||{};
   calls.push({rpc,args});
   if(options.failRpcs?.includes(rpc)){await route.fulfill({status:400,contentType:'application/json',body:JSON.stringify({message:'Fixture request declined',code:'P0001'})});return;}
   if(rpc==='upsert_player'){player.name=args.p_name;result=player;}
   else if(rpc==='set_pin'){if(args.p_id!==null&&!player.extras.includes(args.p_id))throw Error('Fixture ownership violation');player.pin=args.p_id;result=player;}
   else if(rpc==='set_look'){player.look=args.p_look;result=player;}
   else if(rpc==='dress'){player.outfit={id:args.p_outfit,until:new Date(Date.now()+2700000).toISOString()};player.pp-=120;result=player;}
   else if(rpc==='do_deed'){if(options.onDeed)options.onDeed(player,args);else{player.pp-=100;player.goodwill=(player.goodwill||0)+1;}result=player;}
   else if(rpc==='fix_printer'){if(!options.onFixPrinter)throw Error('Printer fixture requires an explicit outcome');options.onFixPrinter(player,args);result=player;}
   else if(rpc==='grab_chair'){if(!options.onGrabChair)throw Error('Chair fixture requires an explicit outcome');options.onGrabChair(player,args);result=player;}
   else if(rpc==='do_work'){player.pp+=args.p_clicks;result=player;}
   else if(rpc==='buy_item'){player.owned[args.p_item]=(player.owned[args.p_item]||0)+1;player.pp-=100;result=player;}
   else if(['sync','check_in'].includes(rpc))result=player;
   else if(rpc==='save_achievements'){player.achievements=args.p_list;result=player;}
   else if(rpc==='weekly_schedule')result=options.weekSchedule||{timezone:'America/Los_Angeles',server_now:new Date().toISOString(),starts_at:'2026-10-16T23:00:00Z',ends_at:'2026-10-23T23:00:00Z'};
   else if(rpc==='office_play_state')result=officePlay.state(player.id);
   else if(rpc==='office_vote')result=officePlay.vote(player.id,args.p_choice);
   else if(rpc==='office_nominate')result=officePlay.nominate(player.id,args.p_category,args.p_recipient);
   else if(rpc==='office_perform')result=officePlay.perform(player.id,args.p_kind);
   else if(rpc==='office_state')result=options.officeState||{total:0,target:10000000,tiers:0,streak:0,tz:'America/Los_Angeles'};
   else if(rpc==='all_prices')result={vending:100,deeds:{},fittings:{}};
   else if(rpc==='fitting_prices')result={prices:Object.fromEntries(Object.values(options.fittings||{}).flat().map(x=>[x.id,1000]))};
   else if(rpc==='buy_fitting'){const item=(options.fittings?.[args.p_key]||[]).find(x=>x.id===args.p_id);const key=args.p_key==='vanity'?'vanity':'kit';player[key]={...player[key],[item.slot]:item.id};player.pp-=1000;result=player;}
   else if(rpc==='claim_office_awards'){player.achievements=[...new Set([...player.achievements,...(options.officeAwards||[])])];result=player;}
   else if(['claim_incoming','weekly_pins','spend_board','beta_testers'].includes(rpc))result=[];
  }else if(url.pathname.endsWith('/catalog'))result=Object.entries({items:[{id:'intern',name:'Office Intern',cost:100,rate:1,desc:'An isolated test hire.'}],upgrades:[],deeds:{},tuning:{growth:1.35},drinks:[],costumes:options.costumes||[],special_pins:[{id:'beta',name:'Beta Tester',hue:'#8A6A2A',glyph:'β',note:'Here before it worked.'}],weekly_pins:[{id:'p01',name:'Five Year Pin',hue:'#C9A253',glyph:'★',note:'Nobody can confirm the five years.'}],office_kit:options.fittings?.office_kit||[],vanity:options.fittings?.vanity||[]}).map(([key,data])=>({key,data}));
  else if(url.pathname.endsWith('/players'))result=url.searchParams.has('id')?player:[player,...(options.coworkers||[])];
  else if(url.pathname.endsWith('/deeds'))result=options.deeds||[];
  else if(['seasons','suggestions'].some(x=>url.pathname.endsWith('/'+x)))result=[];
  await route.fulfill({status:200,contentType:'application/json',headers:{'Access-Control-Allow-Origin':'*'},body:JSON.stringify(result)});
 });
 return {player,calls};
}
module.exports={installGameFixture,makeOfficePlayFixture};
