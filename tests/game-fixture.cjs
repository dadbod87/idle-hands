// Runs the unmodified game UI and real Supabase client against intercepted HTTP.
// Every Supabase request is fulfilled locally. No production credentials or writes.
const fixtureId='00000000-0000-4000-8000-000000000001';
async function installGameFixture(page,options={}) {
 const now=new Date().toISOString();
 const player={id:fixtureId,name:'QA Employee',created_at:'2026-01-01T00:00:00Z',signed_at:now,last_tick:now,
 pp:500000,week_pp:500000,lifetime:500000,equity:2,raises:0,heat:0,owned:{intern:2},upgrades:[],buffs:[],perks:[],achievements:[],
 wardrobe_owned:['hoodie','cardigan','blazer','hawaiian','hoodie_gold','friday'],pet:'pig',pets:['pig','calf','moth','pigeon','balloon','dragon'],
 look:{build:'regular',bottom:'trousers',gender:'neutral',hair:'messy',hairColor:1,skin:0,eyes:'tired',expression:'deadpan',top:0,legs:0,clothing:'starter'},
 vanity:{},kit:{desk:'d3',chair:'c2',rug:'r2'},streak:0,goodwill:0,notoriety:0};
 const calls=[];
 await page.addInitScript(({id})=>{
  const exp=Math.floor(Date.now()/1000)+3600;
  const token=btoa(JSON.stringify({alg:'HS256',typ:'JWT'}))+'.'+btoa(JSON.stringify({sub:id,role:'authenticated',exp}))+'.fixture';
  localStorage.setItem('sb-wbakpxbvqxppqbrwuokp-auth-token',JSON.stringify({access_token:token,refresh_token:'isolated-fixture',expires_at:exp,expires_in:3600,token_type:'bearer',user:{id,is_anonymous:false,aud:'authenticated',role:'authenticated'}}));
  localStorage.setItem('ih_muted','1');
 },{id:fixtureId});
 await page.routeWebSocket('**/wbakpxbvqxppqbrwuokp.supabase.co/**', ws=>ws.close());
 await page.route('https://wbakpxbvqxppqbrwuokp.supabase.co/**',async route=>{
  const req=route.request(),url=new URL(req.url());
  let result=null;
  if(url.pathname.includes('/auth/'))result={id:fixtureId,is_anonymous:false};
  else if(url.pathname.includes('/rpc/')){
   const rpc=url.pathname.split('/').pop(),args=req.postDataJSON()||{};
   calls.push({rpc,args});
   if(rpc==='upsert_player'){player.name=args.p_name;result=player;}
   else if(rpc==='set_look'){player.look=args.p_look;result=player;}
   else if(rpc==='dress'){player.outfit={id:args.p_outfit,until:new Date(Date.now()+2700000).toISOString()};player.pp-=120;result=player;}
   else if(rpc==='do_work'){player.pp+=args.p_clicks;result=player;}
   else if(rpc==='buy_item'){player.owned[args.p_item]=(player.owned[args.p_item]||0)+1;player.pp-=100;result=player;}
   else if(['sync','check_in'].includes(rpc))result=player;
   else if(rpc==='save_achievements'){player.achievements=args.p_list;result=player;}
   else if(rpc==='office_state')result={total:0,target:10000000,tiers:0,streak:0,tz:'America/Los_Angeles'};
   else if(rpc==='all_prices')result={vending:100,deeds:{},fittings:{}};
   else if(rpc==='fitting_prices')result={};
   else if(['claim_incoming','weekly_pins','spend_board','beta_testers'].includes(rpc))result=[];
  }else if(url.pathname.endsWith('/catalog'))result=Object.entries({items:[{id:'intern',name:'Office Intern',cost:100,rate:1,desc:'An isolated test hire.'}],upgrades:[],deeds:{},tuning:{growth:1.35},drinks:[],costumes:options.costumes||[],office_kit:[],vanity:[]}).map(([key,data])=>({key,data}));
  else if(url.pathname.endsWith('/players'))result=url.searchParams.has('id')?player:[player,...(options.coworkers||[])];
  else if(['seasons','suggestions','deeds'].some(x=>url.pathname.endsWith('/'+x)))result=[];
  await route.fulfill({status:200,contentType:'application/json',headers:{'Access-Control-Allow-Origin':'*'},body:JSON.stringify(result)});
 });
 return {player,calls};
}
module.exports={installGameFixture};
