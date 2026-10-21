const {test,expect}=require('@playwright/test');const {installGameFixture}=require('./game-fixture.cjs');
for(const size of [{width:390,height:640},{width:393,height:851},{width:844,height:390}])test(`controls and modal focus at ${size.width}x${size.height}`,async({browser})=>{
 const context=await browser.newContext({viewport:size,isMobile:true,hasTouch:true}),page=await context.newPage();await installGameFixture(page);
 await page.goto('http://127.0.0.1:8765/');await expect(page.locator('.pg-stage')).toBeVisible({timeout:15000});
 const metrics=await page.evaluate(()=>{
  const r=s=>document.querySelector(s).getBoundingClientRect();return {stage:r('.pg-stage').height,bar:r('.pg-bar'),rail:r('.pg-feedback-rail'),width:document.documentElement.scrollWidth,statusHeight:[...document.querySelectorAll('.pg-bar>.pg-drinkboost,.pg-bar>.pg-statusboost')].reduce((sum,el)=>sum+el.getBoundingClientRect().height+6,0)};
 });
 expect(metrics.stage).toBeGreaterThanOrEqual(size.height<400?180:240);expect(metrics.rail.bottom).toBeLessThanOrEqual(metrics.bar.top+1);expect(metrics.width).toBeLessThanOrEqual(size.width+2);
 if(size.width<540){expect(metrics.bar.height-metrics.statusHeight).toBeLessThan(165);for(const el of await page.locator('.pg-utility-button,.pg-emote').all()){const b=await el.boundingBox();expect(b.width).toBeGreaterThanOrEqual(44);expect(b.height).toBeGreaterThanOrEqual(44);}}
 await page.getByRole('button',{name:'Office directory',exact:true}).click();const dialog=page.getByRole('dialog');await expect(dialog).toBeVisible();
 expect(await dialog.evaluate(el=>el.contains(document.activeElement))).toBe(true);
 const before=await page.locator('.pg-room>.pg-me').last().evaluate(el=>({x:el.style.left,y:el.style.top}));await page.keyboard.down('ArrowUp');await page.waitForTimeout(150);await page.keyboard.up('ArrowUp');
 expect(await page.locator('.pg-room>.pg-me').last().evaluate(el=>({x:el.style.left,y:el.style.top}))).toEqual(before);
 await page.keyboard.press('Tab');await expect(page.locator('.pg-panel .pg-x')).toBeFocused();await page.keyboard.press('Shift+Tab');await expect(dialog.getByRole('button',{name:"Walk to Dave's Office",exact:true})).toBeFocused();
 await page.keyboard.press('Tab');await expect(page.locator('.pg-panel .pg-x')).toBeFocused();await page.keyboard.press('Escape');await expect(dialog).toHaveCount(0);await expect(page.getByRole('button',{name:'Office directory',exact:true})).toBeFocused();
 if(size.width<540){await page.getByRole('button',{name:'More',exact:true}).click();await expect(page.getByRole('button',{name:'Office Nonsense',exact:true})).toBeVisible();await page.locator('.pg-bar').getByRole('button',{name:'Sound & feel',exact:true}).click();await expect(page.locator('.pg-panelhead')).toContainText('Sound & feel');await page.keyboard.press('Escape');}
 await page.screenshot({path:`test-results/mobile-hierarchy-${size.width}x${size.height}.png`,fullPage:true});await context.close();
});
