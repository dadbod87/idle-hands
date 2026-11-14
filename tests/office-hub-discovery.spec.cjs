const {test,expect}=require('@playwright/test');
const {installGameFixture,openOwnDesk}=require('./game-fixture.cjs');
const base='http://127.0.0.1:8765/';
function officeStatus(){return {version:1,depth_version:1,confetti_rules:{version:1},week:'2026-47',server_now:new Date().toISOString(),project:{title:'Synthetic weekly project',description:'A disposable UI fixture.',categories:['work','care','playful'],goal:36,minimum_contributors:3,minimum_days:4,active_days:1,total:1,contributors:1,mine:[],mine_today:[],today:'2026-11-13',credit_unit:'daily_category',stretch_goal:60,stretch_contributors:5,stretch_days:6},toolkit:{slots:['rescue','confetti'],charges:{rescue:2,confetti:2,filter:2,clip:2}},collection:{qualified_weeks:6,display:['nameplate','corkboard','lamp']},collectibles:['nameplate','corkboard','lamp'],scrapbook:[],resupply:{used_this_week:0,weekly_limit:3,claimed_today:false,eligible:false},shield:{armed:false},completed_weeks:[],reward_weeks:[]};}
for(const viewport of [{width:1440,height:900},{width:390,height:844},{width:844,height:390}]){
 test('earned decor '+viewport.width+': real nameplate, wall mount, hidden items and unchanged progress',async({browser})=>{
  test.setTimeout(150000);
  const ctx=await browser.newContext({viewport,hasTouch:viewport.width<1000,reducedMotion:'reduce'}),page=await ctx.newPage(),f=await installGameFixture(page);
  f.player.office_collectibles=['nameplate','corkboard','lamp'];f.player.office_display=[...f.player.office_collectibles];
  await page.goto(base);await expect(page.locator('.pg-stage')).toBeVisible();await openOwnDesk(page);await page.locator('.pg-panel .pg-x').click();
  const desk=page.locator('.pg-officedesk.mine'),name=desk.locator('[data-desk-nameplate]'),board=page.locator('[data-office-corkboard]');
  await expect(name).toHaveText('QA Employee');await expect(desk.locator('.pg-fxlabel')).toHaveCount(0);await expect(board).toHaveCount(1);
  const d=await desk.boundingBox(),b=await board.boundingBox();expect(b.y+b.height).toBeLessThanOrEqual(d.y+2);expect(b.width).toBeGreaterThan(50);
  expect(await board.evaluate(el=>getComputedStyle(el).pointerEvents)).toBe('none');
  expect(await desk.locator('.pg-desk-collectible').evaluate(el=>getComputedStyle(el).position)).toBe('relative');
  await page.screenshot({path:'test-results/hub-decor-'+viewport.width+'.png',fullPage:true});
  f.player.office_display=[];await page.reload();await expect(page.locator('.pg-stage')).toBeVisible();
  await expect(page.locator('[data-desk-nameplate]')).toHaveCount(0);await expect(page.locator('[data-office-corkboard]')).toHaveCount(0);
  await expect(page.locator('.pg-officedesk.mine .pg-fxlabel')).toHaveText('Your Desk');
  expect(f.player.pp).toBe(500000);expect(f.calls.some(c=>['buy_item','office_display','office_interact','restructure'].includes(c.rpc))).toBe(false);await ctx.close();
 });
 test('Office hub '+viewport.width+': six direct sections and distinct employee spotlight',async({browser})=>{
  test.setTimeout(150000);
  const ctx=await browser.newContext({viewport,hasTouch:viewport.width<1000,reducedMotion:'reduce'}),page=await ctx.newPage(),status=officeStatus();
  const f=await installGameFixture(page,{officeState:{total:1000,target:100,tiers:0,streak:4,best:4,hit:true,goal:{name:'The Margarita Machine',won:'MARGARITA FRIDAY. Existing reward.',target_policy_version:2,target_policy:'Future weekly goals use at least 150% of the previous completed season.'}},weekSchedule:{timezone:'America/Los_Angeles',server_now:new Date().toISOString(),starts_at:new Date(Date.now()-3600000).toISOString(),ends_at:new Date(Date.now()+6*86400000).toISOString()},handleRpc:async(name,args,p)=>{
   if(name==='office_week_status')return {body:status};
   if(name==='office_profile')return {body:{player:{id:args.p_player,name:p.name},since:'2026-11-12T00:00:00Z',by_kind:[],daily:[],coworkers:[],privacy:'Synthetic public history.'}};
  }});
  await page.goto(base);await expect(page.locator('.pg-stage')).toBeVisible();
  const hub=page.getByRole('button',{name:'Office hub',exact:true});await expect(hub).toBeVisible();await hub.click();
  await expect(page.locator('.pg-panelhead')).toContainText('Office hub');
  const nav=page.getByRole('navigation',{name:'Office records',exact:true});
  for(const label of ['This week','Player profiles','Toolkit','Collection','Boutique','Record book'])await expect(nav.getByRole('button',{name:label,exact:true})).toBeVisible();
  expect(await nav.evaluate(el=>el.scrollWidth<=el.clientWidth+2)).toBe(true);
  await page.screenshot({path:'test-results/hub-navigation-'+viewport.width+'.png',fullPage:true});await page.locator('.pg-panel .pg-x').click();
  await page.getByRole('button',{name:'Office directory',exact:true}).click();await page.getByRole('button',{name:'Walk to Employee Of The Week',exact:true}).click();
  await expect(page.locator('.pg-panelhead')).toContainText('Employee of the Week',{timeout:30000});
  await expect(page.getByRole('heading',{name:'Leading this week',exact:true})).toBeVisible();
  await expect(page.getByRole('button',{name:'All time',exact:true})).toHaveCount(0);
  await page.screenshot({path:'test-results/employee-spotlight-'+viewport.width+'.png',fullPage:true});
  await page.getByRole('button',{name:'View full whiteboard',exact:true}).click();
  await page.getByRole('button',{name:'All time',exact:true}).click();await page.getByRole('button',{name:'View QA Employee profile',exact:true}).click();
  await expect(page.locator('.pg-panelhead')).toContainText('Office hub');await page.getByRole('button',{name:'Back to whiteboard',exact:true}).click();
  await expect(page.getByRole('button',{name:'All time',exact:true})).toHaveAttribute('aria-pressed','true');
  await page.locator('.pg-panel .pg-x').click();await page.getByRole('button',{name:'Office directory',exact:true}).click();await page.getByRole('button',{name:'Walk to Vending Machine',exact:true}).click();
  await expect(page.locator('.pg-margbox')).toContainText('Bought.',{timeout:30000});await expect(page.locator('.pg-margbox')).toContainText('150%');
  expect(f.player.pp).toBe(500000);expect(f.calls.some(c=>['buy_item','office_interact','office_claim_collectible','vend'].includes(c.rpc))).toBe(false);await ctx.close();
 });
}
