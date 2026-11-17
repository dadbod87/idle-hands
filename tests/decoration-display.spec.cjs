const {test,expect}=require('@playwright/test');
const {installGameFixture,openOwnDesk}=require('./game-fixture.cjs');
const base='http://127.0.0.1:8765/';
const sets={theme_facilities:'Facilities Desk Set',theme_accounting:'Accounting Desk Set',theme_it:'IT Desk Set',theme_chaos:'Office Chaos Desk Set'};
function status(){return {version:1,depth_version:1,week:'2026-47',server_now:new Date().toISOString(),project:{title:'Synthetic project',categories:['work','care','playful'],goal:36,total:0,contributors:0,minimum_contributors:3,mine:[],stretch_goal:60,stretch_contributors:5},collection:{qualified_weeks:6,display:['nameplate','corkboard','plaque']},collectibles:['nameplate','corkboard','plaque',...Object.keys(sets)],scrapbook:[],toolkit:{slots:['rescue','confetti'],charges:{rescue:2,confetti:2,filter:2,clip:2}},resupply:{used_this_week:0,weekly_limit:3,activity:[]},shield:{armed:false},completed_weeks:[],reward_weeks:[]};}
async function hub(page,tab){await page.locator('.pg-bar>.pg-hub-button').click();await page.getByRole('navigation',{name:'Office records',exact:true}).getByRole('button',{name:tab,exact:true}).click();}
async function boot(page){await page.goto(base);await expect(page.locator('.pg-stage')).toBeVisible();}
for(const viewport of [{width:1440,height:900},{width:390,height:844},{width:844,height:390}]){
 test('owned desk display '+viewport.width+': automatic swaps, real world art, hide and reload',async({browser})=>{
  test.setTimeout(180000);
  const ctx=await browser.newContext({viewport,hasTouch:viewport.width<1000,reducedMotion:'reduce'}),page=await ctx.newPage(),s=status(),errors=[];page.on('pageerror',e=>errors.push(String(e)));
  const f=await installGameFixture(page,{handleRpc:async(name,args,p)=>{
   if(name==='office_week_status')return {body:s};
   if(name==='office_shop_state')return {body:{version:1,week:s.week,care_days:7,qualified_weeks:6,items:Object.entries(sets).map(([id,name])=>({id,name,kind:'desk',owned:true,eligible:true,seconds:14400,minimum:4000,weeks:1,note:'Permanent synthetic desk set.'}))}};
   if(name==='office_display_collectibles'){expect(args.p_items.length).toBeLessThanOrEqual(3);expect(new Set(args.p_items).size).toBe(args.p_items.length);expect(args.p_items.every(id=>p.office_collectibles.includes(id))).toBe(true);p.office_display=[...args.p_items];s.collection.display=[...args.p_items];return {body:p};}
  }});
  f.player.office_collectibles=[...s.collectibles];f.player.office_display=[...s.collection.display];
  await page.clock.setFixedTime(new Date('2026-11-14T16:10:00Z'));await boot(page);await hub(page,'Boutique');
  for(const [id,label] of Object.entries(sets)){
   const before=f.calls.filter(c=>c.rpc==='office_display_collectibles').length;
   const button=page.getByRole('button',{name:'Display '+label,exact:true});await expect(button).toBeEnabled();await button.click();
   await expect(page.getByRole('button',{name:'Hide '+label,exact:true})).toHaveAttribute('aria-pressed','true');
   await expect(page.getByTestId('office-display-feedback')).toContainText('Displayed '+label+'.');
   await expect.poll(()=>f.player.office_display).toEqual(['nameplate','corkboard',id]);
   expect(f.calls.filter(c=>c.rpc==='office_display_collectibles').length).toBe(before+1);
   if(id==='theme_it')await page.screenshot({path:'test-results/desk-set-controls-'+viewport.width+'.png',fullPage:true});
   await page.locator('.pg-panel .pg-x').click();await openOwnDesk(page);await page.locator('.pg-panel .pg-x').click();
   const art=page.locator('.pg-officedesk.mine [data-office-decoration="'+id+'"]');await expect(art).toBeVisible();await expect(art.locator('svg')).toHaveAttribute('aria-label',label);
   const box=await art.boundingBox();expect(box.width).toBeGreaterThan(12);expect(box.height).toBeGreaterThan(12);expect(await art.evaluate(el=>getComputedStyle(el.parentElement).pointerEvents)).toBe('none');
   if(id==='theme_it')await page.screenshot({path:'test-results/desk-set-world-'+viewport.width+'.png',fullPage:true});
   await page.reload();await expect(page.locator('.pg-stage')).toBeVisible();await expect(page.locator('.pg-officedesk.mine [data-office-decoration="'+id+'"]')).toHaveCount(1);await hub(page,'Boutique');
  }
  await page.getByRole('button',{name:'Hide Office Chaos Desk Set',exact:true}).click();await expect.poll(()=>f.player.office_display).toEqual(['nameplate','corkboard']);
  await page.getByRole('button',{name:'Display IT Desk Set',exact:true}).click();await expect.poll(()=>f.player.office_display).toEqual(['nameplate','corkboard','theme_it']);
  await page.getByRole('button',{name:'Collection',exact:true}).click();await page.getByRole('button',{name:'Display Project plaque',exact:true}).click();await expect.poll(()=>f.player.office_display).toEqual(['nameplate','corkboard','plaque']);
  await expect(page.getByTestId('office-display-feedback')).toContainText('IT Desk Set stored; still owned.');
  expect(f.player.office_collectibles).toEqual(s.collectibles);expect(f.player.pp).toBe(500000);expect(f.calls.some(c=>['office_shop_buy','buy_item','restructure','office_claim_collectible'].includes(c.rpc))).toBe(false);expect(errors).toEqual([]);expect(await page.locator('.pg-panel').evaluate(el=>el.scrollWidth<=el.clientWidth+2)).toBe(true);await ctx.close();
 });
}
test('display uncertain save: no optimistic art or replay; refresh reconciles accepted replacement',async({page})=>{
 const s=status();let writes=0;
 const f=await installGameFixture(page,{handleRpc:async(name,args,p)=>{
  if(name==='office_week_status')return {body:s};
  if(name==='office_shop_state')return {body:{version:1,week:s.week,items:[{id:'theme_it',name:'IT Desk Set',kind:'desk',owned:true,eligible:true,seconds:14400,minimum:4000,weeks:1}]}};
  if(name==='office_display_collectibles'){writes++;p.office_display=[...args.p_items];s.collection.display=[...args.p_items];return {status:503,body:{message:'Display response lost'}};}
 }});
 f.player.office_collectibles=[...s.collectibles];f.player.office_display=[...s.collection.display];await boot(page);await hub(page,'Boutique');
 await page.getByRole('button',{name:'Display IT Desk Set',exact:true}).click();await expect(page.getByRole('alert')).toContainText('Display response lost');
 await expect(page.locator('.pg-officedesk.mine [data-office-decoration="theme_it"]')).toHaveCount(0);await expect(page.getByRole('button',{name:'Display IT Desk Set',exact:true})).toBeDisabled();
 await page.getByRole('button',{name:'Retry records',exact:true}).click();await expect(page.getByRole('button',{name:'Hide IT Desk Set',exact:true})).toBeEnabled();expect(writes).toBe(1);
 await page.reload();await expect(page.locator('.pg-stage')).toBeVisible();await expect(page.locator('.pg-officedesk.mine [data-office-decoration="theme_it"]')).toHaveCount(1);expect(writes).toBe(1);expect(f.player.pp).toBe(500000);expect(f.player.office_collectibles).toEqual(s.collectibles);
});
