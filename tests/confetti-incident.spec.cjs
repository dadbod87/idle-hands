const {test,expect}=require('@playwright/test');
const {installGameFixture,openOwnDesk}=require('./game-fixture.cjs');
for(const viewport of [{width:1440,height:900},{width:390,height:844},{width:844,height:390}]){
 test(`confetti ${viewport.width}: severe desk effect, cleanup and input passthrough`,async({browser})=>{
  const ctx=await browser.newContext({viewport,reducedMotion:'reduce',hasTouch:viewport.width<1000}),page=await ctx.newPage();
  const until=new Date(Date.now()+600000).toISOString();
  const state={version:1,week:'2026-47',project:{title:'Fixture project',goal:36,minimum_contributors:3,total:0,contributors:0,mine:[]},toolkit:{slots:['rescue','confetti'],charges:{rescue:2,confetti:2,filter:2}},collectibles:[],completed_weeks:[],confetti:{until}};
  const f=await installGameFixture(page,{handleRpc:async(name,args,p)=>{
   if(name==='office_week_status')return {body:state};
   if(name==='office_clear_confetti'){p.office_confetti=null;state.confetti=null;return {body:p};}
  }});
  f.player.office_confetti={until};f.player.office_display=['nameplate'];
  await page.goto('http://127.0.0.1:8765/');await expect(page.locator('.pg-stage')).toBeVisible();
  await openOwnDesk(page);await page.locator('.pg-panel .pg-x').click();
  const desk=page.locator('.pg-officedesk.mine'),effect=desk.getByTestId('confetti-incident');
  await expect(effect).toHaveCount(1);await expect(effect.locator('rect')).toHaveCount(108);
  const bounds=await effect.boundingBox(),deskBounds=await desk.boundingBox();
  expect(bounds.width).toBeGreaterThan(deskBounds.width);expect(bounds.height).toBeGreaterThan(deskBounds.height*1.75);
  expect(await effect.evaluate(el=>getComputedStyle(el).pointerEvents)).toBe('none');
  expect(await effect.locator('.pg-confetti-fall').first().evaluate(el=>getComputedStyle(el).animationName)).toBe('none');
  expect(await desk.evaluate(el=>{const r=el.getBoundingClientRect();return !document.elementFromPoint(r.x+r.width/2,r.y+r.height/2)?.closest('.pg-confetti-incident');})).toBe(true);
  await desk.scrollIntoViewIfNeeded();await desk.screenshot({path:`test-results/confetti-${viewport.width}.jpg`,type:'jpeg',quality:75});
  // A dedicated close-up includes the complete shower above and ribbons below the desk.
  await effect.screenshot({path:`test-results/confetti-effect-${viewport.width}.jpg`,type:'jpeg',quality:75});
  if(await page.getByRole('button',{name:'More',exact:true}).isVisible())await page.getByRole('button',{name:'More',exact:true}).click();
  await page.getByRole('button',{name:'This week & player profiles',exact:true}).click();await page.getByRole('button',{name:'Toolkit',exact:true}).click();
  await page.getByRole('button',{name:'Clear confetti from my desk',exact:true}).click();await expect(effect).toHaveCount(0,{timeout:15000});
  expect(f.calls.filter(c=>c.rpc==='office_clear_confetti')).toHaveLength(1);
  expect(f.calls.filter(c=>['buy_item','do_deed','office_interact'].includes(c.rpc))).toHaveLength(0);
  expect(f.player.pp).toBe(500000);expect(state.toolkit.charges.confetti).toBe(2);
  await ctx.close();
 });
 test(`confetti ${viewport.width}: gallery animation and expired incident`,async({browser})=>{
  const ctx=await browser.newContext({viewport,reducedMotion:'no-preference'}),page=await ctx.newPage();
  await page.goto('http://127.0.0.1:8765/?art-preview=1');const effect=page.getByTestId('confetti-art-qa').getByTestId('confetti-incident');
  await expect(effect).toBeVisible();expect(await effect.locator('.pg-confetti-fall').first().evaluate(el=>getComputedStyle(el).animationName)).toBe('pg-confetti-fall');
  expect(await page.locator('body').evaluate(el=>el.scrollWidth<=innerWidth+2)).toBe(true);
  await ctx.close();
  const other=await browser.newContext({viewport}),p=await other.newPage(),f=await installGameFixture(p);f.player.office_confetti={until:'2000-01-01T00:00:00Z'};
  await p.goto('http://127.0.0.1:8765/');await expect(p.locator('.pg-stage')).toBeVisible();await expect(p.getByTestId('confetti-incident')).toHaveCount(0);await other.close();
 });
}
