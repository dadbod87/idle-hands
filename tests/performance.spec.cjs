const {test,expect}=require('@playwright/test');
const {installGameFixture,openOwnDesk}=require('./game-fixture.cjs');
const base=process.env.PERF_BASE_URL||'http://127.0.0.1:8765/';
// Test-only access to the real subscription callback, without production sockets.
async function exposeNotifications(page){
 await page.route(base,async route=>{
  const response=await route.fetch();let html=await response.text();
  html=html.replace('function subscribeFloor(onChange) {','function subscribeFloor(onChange) { window.__floorChanged = onChange;');
  await route.fulfill({response,body:html});
 });
}
for(const width of [1440,390]) test(`${width}: update bursts stay bounded and purchases cannot pile up`,async({browser})=>{
 const ctx=await browser.newContext({viewport:{width,height:900},reducedMotion:'reduce'}),page=await ctx.newPage();
 let pending=0,maxPending=0,fail=false;
 const f=await installGameFixture(page,{upgrades:[{id:'qa_up',name:'Less paperwork',note:'QA approval',cost:100,t:'all',mult:2,req:['intern',2]}],handleRpc:async(name,args,p)=>{
  if(name==='buy_upgrade'){
   await new Promise(r=>setTimeout(r,700));p.upgrades.push(args.p_up);p.pp-=100;return {body:p};
  }
  if(name==='buy_item'){
   pending++;maxPending=Math.max(maxPending,pending);await new Promise(r=>setTimeout(r,700));pending--;
   if(fail)return {status:400,body:{message:'Fixture retry'}};
   p.owned[args.p_item]=(p.owned[args.p_item]||0)+1;p.pp-=100;return {body:p};
  }
 }});
 await exposeNotifications(page);await page.goto(base);await expect(page.locator('.pg-stage')).toBeVisible();await openOwnDesk(page);
 await page.waitForTimeout(2500);
 const before=f.calls.length;
 await page.evaluate(()=>{for(let i=0;i<100;i++)window.__floorChanged();});
 await page.waitForTimeout(2600);
 const burst=f.calls.slice(before);expect(burst.filter(x=>x.rpc==='office_state')).toHaveLength(1);
 for(const rpc of ['weekly_pins','spend_board','beta_testers','card_state'])expect(burst.filter(x=>x.rpc===rpc)).toHaveLength(0);
 // Only a personal heartbeat may request prices; the 100 notifications cannot.
 expect(burst.filter(x=>x.rpc==='all_prices').length).toBeLessThanOrEqual(1);
 const row=page.locator('.pg-purchase-list .pg-row').first(),start=f.calls.filter(x=>x.rpc==='buy_item').length;
 await row.evaluate(el=>{for(let i=0;i<20;i++)el.click();});
 await expect(row).toHaveAttribute('aria-busy','true');await expect(row).toBeDisabled();
 await expect.poll(()=>f.calls.filter(x=>x.rpc==='buy_item').length).toBe(start+1);
 await expect(row).toBeEnabled();expect(maxPending).toBe(1);
 // Failure clears the pending state and permits a deliberate retry.
 fail=true;await row.click();await expect(row).toBeEnabled();fail=false;await row.click();await expect(row).toBeEnabled();
 expect(f.calls.filter(x=>x.rpc==='buy_item')).toHaveLength(start+3);expect(f.player.owned.intern).toBe(4);
 await page.getByRole('button',{name:'Approvals',exact:true}).click();
 const approval=page.locator('.pg-purchase-list .pg-row').first();
 await approval.evaluate(el=>{for(let i=0;i<20;i++)el.click();});
 await expect(approval).toHaveAttribute('aria-busy','true');await expect(approval).toBeDisabled();
 await expect(approval).toHaveAttribute('aria-busy','false');
 expect(f.calls.filter(x=>x.rpc==='buy_upgrade')).toHaveLength(1);expect(f.player.upgrades).toEqual(['qa_up']);
 await page.getByRole('button',{name:'Requisitions',exact:true}).click();
 await page.screenshot({path:`test-results/performance-${width}.png`,fullPage:true});
 // Hidden tabs make no sync/claim/price/metadata/notification reads. Resume catches up.
 await page.evaluate(()=>{Object.defineProperty(document,'hidden',{configurable:true,get:()=>true});document.dispatchEvent(new Event('visibilitychange'));});
 await page.waitForTimeout(2500);const hiddenStart=f.calls.length;
 await page.evaluate(()=>{for(let i=0;i<100;i++)window.__floorChanged();});
 await page.waitForTimeout(12000);
 expect(f.calls.slice(hiddenStart).filter(x=>['sync','claim_incoming','all_prices','weekly_pins','spend_board','beta_testers','office_state'].includes(x.rpc))).toHaveLength(0);
 const shown=f.calls.length;await page.evaluate(()=>{Object.defineProperty(document,'hidden',{configurable:true,get:()=>false});document.dispatchEvent(new Event('visibilitychange'));});
 await expect.poll(()=>f.calls.slice(shown).some(x=>x.rpc==='sync')).toBe(true);
 await expect.poll(()=>f.calls.slice(shown).some(x=>x.rpc==='all_prices')).toBe(true);
 await expect(row).toBeEnabled();await ctx.close();
});
