const {test,expect,devices}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
for(const mode of ['desktop','mobile']){
 test(mode+': whiteboard shows server scoring cutoff, live countdown and viewer local time',async({browser})=>{
  const context=await browser.newContext({...mode==='mobile'?devices['Pixel 7']:{viewport:{width:1440,height:900}},timezoneId:'America/Los_Angeles'}),page=await context.newPage();
  const fixture=await installGameFixture(page,{coworkers:[{id:'qa-2',name:'QA Coworker',week_pp:200},{id:'qa-3',name:'QA Third',week_pp:100}],weekSchedule:{timezone:'America/Los_Angeles',server_now:'2026-10-23T22:50:00Z',starts_at:'2026-10-16T23:00:00Z',ends_at:'2026-10-23T23:00:00Z'}});
  await page.goto('http://127.0.0.1:8765/');await expect(page.locator('.pg-stage')).toBeVisible();
  const wall=page.getByTestId('wall-week-deadline');
  await expect(wall).toContainText('Fri, Oct 23, 4:00 PM PDT');
  expect(await page.locator('.pg-wbrow>.pg-face').evaluateAll(els=>els.every(el=>el.getBoundingClientRect().width<=14))).toBe(true);
  const timer=wall.getByRole('timer'),initial=await timer.innerText();
  await expect(timer).not.toHaveText(initial,{timeout:4000});
  expect(await wall.evaluate(el=>el.getBoundingClientRect().bottom<=el.closest('.pg-wb').getBoundingClientRect().bottom)).toBe(true);
  await page.keyboard.down('ArrowUp');
  await expect.poll(()=>page.locator('.pg-me:not(.pg-chance)').evaluate(el=>parseFloat(el.style.top)),{timeout:10000,intervals:[30]}).toBeLessThan(205);
  await page.keyboard.up('ArrowUp');await page.keyboard.down('ArrowLeft');
  await expect.poll(()=>page.locator('.pg-me:not(.pg-chance)').evaluate(el=>parseFloat(el.style.left)),{timeout:10000,intervals:[30]}).toBeLessThan(1210);
  await page.keyboard.up('ArrowLeft');
  await expect(page.locator('.pg-prompt')).toContainText('Whiteboard');await page.locator('.pg-prompt .pg-open').click();
  const panel=page.locator('.pg-panel'),deadline=panel.getByTestId('week-deadline');
  await expect(deadline).toContainText('This week ends Fri, Oct 23, 4:00 PM PDT');
  await expect(deadline).toContainText('Your time: Fri, Oct 23, 4:00 PM PDT');
  await expect(deadline.locator('time')).toHaveAttribute('datetime','2026-10-23T23:00:00Z');
  await page.screenshot({path:'test-results/'+mode+'-weekly-deadline.png',fullPage:true});
  await panel.getByRole('button',{name:'All time',exact:true}).click();await expect(deadline).toHaveCount(0);
  await expect(panel).toContainText('This one never resets.');
  await panel.getByRole('button',{name:'This week',exact:true}).click();await expect(deadline).toBeVisible();
  expect(fixture.calls.some(x=>x.rpc==='weekly_schedule')).toBe(true);expect(fixture.player.pp).toBe(500000);expect(fixture.player.week_pp).toBe(500000);
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2)).toBe(true);
  await page.goto('http://127.0.0.1:8765/?art-preview=1');
  await expect(page.getByTestId('weekly-board-qa').getByTestId('week-deadline')).toContainText('4:00 PM PDT');
  await context.close();
 });
}
