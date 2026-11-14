const {test,expect}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
const base='http://127.0.0.1:8765/';
function state(){return {version:1,depth_version:1,confetti_rules:{version:1,mult:0.65,minutes:10},week:'2026-46',server_now:new Date().toISOString(),project:{theme:'it',title:'IT Has Opened a Ticket',description:'Work, tend the office and try a harmless prank.',categories:['work','facilities','playful'],goal:36,minimum_contributors:3,total:18,contributors:3,credit_unit:"daily_category",minimum_days:4,active_days:2,stretch_days:6,today:"2026-11-12",mine_today:["work","facilities","playful"],mine:['work','facilities','care'],completed:false,stretch_goal:60,stretch_contributors:5,stretch_completed:false},toolkit:{slots:['rescue','confetti'],charges:{rescue:1,confetti:2,filter:2,clip:2}},collection:{qualified_weeks:2,display:['nameplate','corkboard','plaque']},collectibles:['nameplate','corkboard','plaque','terrarium'],scrapbook:[{week:'2026-45',theme:'breakroom',title:'Break Room Revival',starts_at:'2026-10-30T23:00:00Z',stretch:true,selected:false}],resupply:{day:'2026-11-12',activity:['work','facilities'],used_this_week:0,weekly_limit:3,claimed_today:false,eligible:true},shield:{armed:false,price_hint:5000},cooldown_until:new Date(Date.now()+120000).toISOString(),completed_weeks:[],reward_weeks:[],history_since:'2026-11-07T00:12:00Z'};}
async function openRecords(page){await page.goto(base);await expect(page.locator('.pg-stage')).toBeVisible();if(await page.getByRole('button',{name:'More',exact:true}).isVisible())await page.getByRole('button',{name:'More',exact:true}).click();await page.getByRole('button',{name:'Office hub',exact:true}).click();}

test('project pacing: large totals cannot hide missing dates, new-day checks and weekly refresh',async({page})=>{
 const s=state();Object.assign(s.project,{total:42,contributors:7,active_days:2,completed:false});
 await installGameFixture(page,{handleRpc:async(name)=>{if(name==='office_week_status')return {body:s};}});await openRecords(page);
 await expect(page.locator('.pg-next-progress')).toContainText('42 / 36 daily contributions');await expect(page.getByText('The office needs all three: contributions, contributors and different active dates.',{exact:true})).toBeVisible();
 Object.assign(s.project,{total:84,active_days:4,completed:true,today:'2026-11-16',mine_today:[]});await page.getByRole('button',{name:'Refresh office records',exact:true}).click();await expect(page.getByText('Complete. Facilities has filed a surprised memo.',{exact:true})).toBeVisible();await expect(page.getByRole('heading',{name:'Your project contributions today · 2026-11-16',exact:true})).toBeVisible();await expect(page.getByText(/Your project contributions for today are complete/)).toHaveCount(0);
 await page.getByText('Optional stretch · 60 contributions / 5 contributors / 6 active dates',{exact:true}).click();await expect(page.getByText('A cosmetic distinction for the same project. Base rewards never require the stretch goal.',{exact:true})).toBeVisible();
 s.week='2026-48';Object.assign(s.project,{total:0,active_days:0,contributors:0,mine:[],mine_today:[],completed:false});await page.getByRole('button',{name:'Refresh office records',exact:true}).click();await expect(page.locator('.pg-next-progress')).toContainText('0 / 36 daily contributions');await expect(page.locator('.pg-next-progress')).toContainText('0 / 4 active Pacific dates');
});

for(const viewport of [{width:1440,height:900},{width:390,height:844},{width:844,height:390}])test(`office depth ${viewport.width}: lasting goals, dated display, two slots and earned refill`,async({browser})=>{
 const ctx=await browser.newContext({viewport,hasTouch:viewport.width<1000,reducedMotion:'reduce'}),page=await ctx.newPage(),s=state(),errors=[];page.on('pageerror',e=>errors.push(String(e)));
 const f=await installGameFixture(page,{handleRpc:async(name,args,p)=>{
  if(name==='office_week_status')return {body:s};
  if(name==='office_display_collectibles'){s.collection.display=args.p_items;p.office_display=args.p_items;return {body:p};}
  if(name==='office_display_memento'){const m=s.scrapbook.find(m=>m.week===args.p_week);s.scrapbook.forEach(m=>m.selected=m.week===args.p_week);p.office_memento=m;return {body:p};}
  if(name==='office_equip_tools'){s.toolkit.slots=args.p_slots;return {body:s};}
  if(name==='office_resupply'){s.toolkit.charges[args.p_tool]++;s.resupply.claimed_today=true;s.resupply.eligible=false;s.resupply.used_this_week++;return {body:{outcome:'One charge restored.',status:s}};}
 }});
 f.player.office_collectibles=s.collectibles;f.player.office_display=s.collection.display;
 await openRecords(page);await expect(page.getByRole('heading',{name:s.project.title})).toBeVisible();
 await expect(page.getByText(/This theme stays fixed/)).toBeVisible();
 await expect(page.locator('.pg-next-progress')).toContainText('18 / 36 daily contributions');await expect(page.locator('.pg-next-progress')).toContainText('2 / 4 active Pacific dates');await expect(page.getByText(/Your project contributions for today are complete/)).toBeVisible();
 await page.getByText('A short route through the office',{exact:true}).click();await page.getByRole('button',{name:'Dismiss office route',exact:true}).click();await expect(page.getByText('A short route through the office',{exact:true})).toHaveCount(0);
 await page.getByRole('button',{name:'Collection',exact:true}).click();
 await expect(page.getByRole('heading',{name:'A desk with a history'})).toBeVisible();
 await expect(page.getByText(/2 qualifying weeks/).first()).toBeVisible();
 await expect(page.getByRole('button',{name:'Display Desk terrarium',exact:true})).toBeDisabled();
 await page.getByRole('button',{name:'Hide Incident Corkboard',exact:true}).click();
 await expect(page.getByRole('button',{name:'Display Desk terrarium',exact:true})).toBeEnabled();await page.getByRole('button',{name:'Display Desk terrarium',exact:true}).click();
 await expect.poll(()=>f.player.office_display).toEqual(['nameplate','plaque','terrarium']);
 await page.getByRole('button',{name:'Select for plaque',exact:true}).click();await expect(page.getByRole('button',{name:'Selected for plaque',exact:true})).toBeVisible();
 expect(f.player.office_memento.week).toBe('2026-45');
 await page.screenshot({path:`test-results/office-collection-${viewport.width}.jpg`,type:'jpeg',quality:65,fullPage:true});
 await page.getByRole('button',{name:'Toolkit',exact:true}).click();
 await expect(page.getByLabel('Change tool in slot 2',{exact:true})).toBeEnabled();
 await page.getByLabel('Change tool in slot 2',{exact:true}).selectOption('clip');
 await expect.poll(()=>s.toolkit.slots).toEqual(['rescue','clip']);
 await expect(page.getByRole('button',{name:'Rescue coworker',exact:true})).toBeDisabled();await expect(page.getByText(/Coworker actions ready in/)).toBeVisible();
 await page.getByRole('button',{name:'Refill Emergency Stapler',exact:true}).click();await expect(page.getByText(/Today’s refill used/)).toBeVisible();
 await expect(page.getByRole('button',{name:'Refill Emergency Stapler',exact:true})).toBeDisabled();expect(f.calls.filter(c=>c.rpc==='office_resupply')).toHaveLength(1);expect(f.player.pp).toBe(500000);
 expect(f.calls.some(c=>['buy_item','buy_fitting','office_buy_shield','office_claim_collectible'].includes(c.rpc))).toBe(false);
 await page.locator('.pg-next-shield>summary').click();await page.screenshot({path:`test-results/office-depth-${viewport.width}.jpg`,type:'jpeg',quality:65,fullPage:true});
 expect(await page.locator('.pg-panel').evaluate(el=>el.scrollWidth<=el.clientWidth+2)).toBe(true);expect(errors).toEqual([]);await ctx.close();
});

for(const width of [1440,390])test(`office depth ${width}: confirmed shield prices, expiry, accepted-reply loss and same-request retry`,async({browser})=>{
 const ctx=await browser.newContext({viewport:{width,height:844},hasTouch:width<1000}),page=await ctx.newPage(),s=state();let reads=0,saved,charges=0;const requests=[];
 const f=await installGameFixture(page,{handleRpc:async(name,args,p)=>{
  if(name==='office_week_status')return {body:s};
  if(name==='office_shield_quote'){
   reads++;if(reads===1)return {status:503,body:{message:'Quote office is unavailable'}};
   return {body:{quote:`00000000-0000-4000-8000-${String(reads).padStart(12,'0')}`,week:s.week,server_now:new Date().toISOString(),price:5000,attack_reference:2500,basis:'Retained base production',expires_at:new Date(Date.now()+(reads===2?-1000:120000)).toISOString()}};
  }
  if(name==='office_buy_shield'){
   requests.push(args);
   if(!saved){charges++;p.pp-=5000;s.shield.armed=true;saved=JSON.parse(JSON.stringify({outcome:'Return to Sender armed.',player:p,status:s}));return {status:503,body:{message:'Shield accepted, reply lost'}};}
   return {body:saved};
  }
 }});
 await openRecords(page);await expect(page.getByRole('heading',{name:s.project.title})).toBeVisible();await page.getByRole('button',{name:'Toolkit',exact:true}).click();await page.locator('.pg-next-shield>summary').click();
 expect(f.calls.some(c=>c.rpc==='office_buy_shield')).toBe(false);await expect(page.getByRole('button',{name:/Buy and arm/})).toHaveCount(0);
 await page.getByRole('button',{name:'Review shield price',exact:true}).click();await expect(page.getByRole('alert')).toContainText('Quote office is unavailable');
 await page.getByRole('button',{name:'Retry shield price',exact:true}).click();await expect(page.getByRole('button',{name:/Buy and arm/})).toBeDisabled();await expect(page.getByText(/Quote expired/)).toBeVisible();
 await page.getByRole('button',{name:'Refresh shield price',exact:true}).click();await expect(page.getByRole('button',{name:/Buy and arm/})).toBeEnabled();
 await page.screenshot({path:`test-results/office-shield-${width}.jpg`,type:'jpeg',quality:65,fullPage:true});
 await page.getByRole('button',{name:/Buy and arm/}).click();await expect(page.getByRole('alert')).toContainText('Shield accepted, reply lost');
 await page.getByRole('button',{name:'Retry action',exact:true}).click();await expect.poll(()=>requests.length).toBe(2);await expect(page.getByText('One shield armed',{exact:true})).toBeVisible();
 expect(charges).toBe(1);expect(new Set(requests.map(r=>r.p_request)).size).toBe(1);expect(new Set(requests.map(r=>r.p_quote)).size).toBe(1);expect(f.player.pp).toBe(495000);
 await expect(page.getByRole('button',{name:/Buy and arm/})).toBeDisabled();await ctx.close();
});

test('office depth art: all earned decorations and the shield render without spending',async({page})=>{
 const f=await installGameFixture(page);await page.setViewportSize({width:390,height:844});await page.goto(base+'?art-preview=1');
 const gallery=page.locator('[aria-label="Earned office collectibles"]');await expect(gallery.getByRole('img')).toHaveCount(7);await gallery.screenshot({path:'test-results/office-depth-art-390.jpg',type:'jpeg',quality:65});
 expect(f.calls.some(c=>['office_buy_shield','office_claim_collectible','buy_fitting','do_deed','office_deed'].includes(c.rpc))).toBe(false);
});

test('office depth: server-clock cooldown and shield quote expire with a skewed client clock',async({page})=>{
 let server=Date.now();const s=state(),peer={id:'00000000-0000-4000-8000-000000000099',name:'Fixture coworker'};s.cooldown_until=new Date(server+20000).toISOString();
 await page.clock.install({time:new Date(server+3600000)});
 const f=await installGameFixture(page,{coworkers:[peer],handleRpc:async(name)=>{
  if(name==='office_week_status'){s.server_now=new Date(server).toISOString();return {body:s};}
  if(name==='office_shield_quote')return {body:{quote:'11111111-1111-4111-8111-111111111111',week:s.week,server_now:new Date(server).toISOString(),expires_at:new Date(server+20000).toISOString(),price:5000,attack_reference:2500,basis:'Current week base production'}};
 }});
 await openRecords(page);await expect(page.getByRole('heading',{name:s.project.title})).toBeVisible();await page.getByRole('button',{name:'Toolkit',exact:true}).click();await page.getByLabel('Toolkit recipient',{exact:true}).selectOption(peer.id);
 await expect(page.getByRole('button',{name:'Send confetti',exact:true})).toBeDisabled();server+=21000;await page.clock.fastForward(21000);await expect(page.getByRole('button',{name:'Send confetti',exact:true})).toBeEnabled();
 await page.locator('.pg-next-shield>summary').click();await page.getByRole('button',{name:'Review shield price',exact:true}).click();await expect(page.getByRole('button',{name:/Buy and arm/})).toBeEnabled();
 server+=21000;await page.clock.fastForward(21000);await expect(page.getByRole('button',{name:/Buy and arm/})).toBeDisabled();expect(f.calls.some(c=>['office_buy_shield','office_interact'].includes(c.rpc))).toBe(false);
});

test('office depth: sender recovers a reflected action receipt without a second attack',async({page})=>{
 test.setTimeout(75000);const peer={id:'00000000-0000-4000-8000-000000000099',name:'Fixture defender'};let saved,uses=0;const requests=[];
 const f=await installGameFixture(page,{coworkers:[peer],handleRpc:async(name,args,p)=>{
  if(name==='office_deed'){
   requests.push(args.p_request);
   if(!saved){uses++;p.pp-=100;p.last_deed=new Date().toISOString();p.buffs=[{kind:'replyall',mult:0.45,until:new Date(Date.now()+480000).toISOString()}];saved=JSON.parse(JSON.stringify({player:p,reflected:true,outcome:'Return to Sender: your sabotage bounced back onto you.'}));return {status:503,body:{message:'Accepted attack reply lost'}};}
   return {body:saved};
  }
 }});
 await page.goto(base);await expect(page.locator('.pg-stage')).toBeVisible();await page.getByRole('button',{name:'Office directory',exact:true}).click();await page.getByRole('button',{name:/Walk to Meeting Room/}).click();await expect(page.locator('.pg-panelhead')).toContainText('Meeting room',{timeout:30000});
 await page.locator('.pg-picks').getByRole('button',{name:/Fixture defender/}).click();await page.getByRole('button',{name:/Start a reply-all storm/}).click();
 await expect(page.getByRole('button',{name:'Retry unconfirmed action',exact:true})).toBeVisible();await page.getByRole('button',{name:'Retry unconfirmed action',exact:true}).click();
 await expect.poll(()=>requests.length).toBe(2);await expect(page.locator('.pg-panel')).toHaveCount(0);
 await expect(page.locator('.pg-toast')).toContainText('bounced back');expect(uses).toBe(1);expect(new Set(requests).size).toBe(1);expect(f.player.pp).toBe(499900);expect(f.player.buffs).toHaveLength(1);
});

test('office depth: a hushed reflection incident explains protection without naming the sender',async({page})=>{
 let delivered=false;const peer={id:'00000000-0000-4000-8000-000000000099',name:'Fixture attacker'};
 await installGameFixture(page,{coworkers:[peer],handleRpc:async(name,args,p)=>{
  if(name==='claim_incoming'){if(delivered)return {body:[]};delivered=true;return {body:[{id:123,actor:peer.id,target:p.id,kind:'credit',amount:0,hush:true,detail:'reflected:shield',created_at:new Date().toISOString()}]};}
 }});
 await page.goto(base);const dialog=page.getByRole('dialog',{name:'Office notice',exact:true});await expect(dialog.getByText('Returned to sender',{exact:true})).toBeVisible();await expect(dialog).toContainText('Your Return to Sender reflected Someone');await expect(dialog).not.toContainText('Fixture attacker');await expect(dialog).not.toContainText('walked off with the points');
});
