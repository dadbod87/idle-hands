const {test,expect,devices}=require('@playwright/test');
const {installGameFixture,openOwnDesk}=require('./game-fixture.cjs');
const base=process.env.FURNITURE_BASE_URL||'http://127.0.0.1:8765/';
for(const [mode,options] of [['desktop',{viewport:{width:1440,height:900}}],['phone',{...devices['Pixel 7']}],['short',{viewport:{width:844,height:390},isMobile:true,hasTouch:true}]])test(mode+': owned chair and rug remain visible around the unchanged desk',async({browser})=>{
 test.setTimeout(60000);const context=await browser.newContext(options),page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const fixture=await installGameFixture(page);await page.goto(base);await expect(page.locator('.pg-stage')).toBeVisible();await openOwnDesk(page);await page.locator('.pg-panel .pg-x').click();
 const desk=page.locator('.pg-officedesk.mine'),office=page.locator('.pg-office.mine'),chair=office.locator('xpath=following-sibling::*[1]'),rug=office.locator('.pg-rug-art');
 await expect(chair).toHaveClass(/pg-officechair/);const d=await desk.boundingBox(),c=await chair.boundingBox(),r=await rug.boundingBox(),o=await office.boundingBox();
 expect(c.y+c.height).toBeLessThan(d.y-8);expect(c.x).toBeGreaterThan(o.x);expect(c.x+c.width).toBeLessThan(o.x+o.width);
 expect(r.x).toBeLessThan(d.x);expect(r.x+r.width).toBeGreaterThan(d.x+d.width);expect(r.y+r.height).toBeGreaterThan(d.y+d.height+20);
 // Desk anchor is the original 50px inset; never move a purchase target to expose art.
 expect(await desk.evaluate((node,officeLeft)=>parseFloat(node.style.left)-officeLeft,await office.evaluate(node=>parseFloat(node.style.left)))).toBe(50);expect(await desk.evaluate(node=>[node.style.width,node.style.height])).toEqual(['200px','100px']);
 await page.screenshot({path:'test-results/furniture-'+mode+'.png',fullPage:true});expect(errors).toEqual([]);expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2)).toBe(true);
 expect(fixture.player.pp).toBe(500000);expect(fixture.player.kit).toEqual({desk:'d3',chair:'c2',rug:'r2'});expect(fixture.calls.some(c=>['buy_fitting','buy_item','set_look','restructure'].includes(c.rpc))).toBe(false);await context.close();
});
for(const [mode,viewport] of [['desktop',{width:1440,height:900}],['phone',{width:390,height:844}]])test(mode+': furniture gallery remains readable',async({page})=>{
 await page.setViewportSize(viewport);await page.goto(new URL('?art-preview=1',base).href);const gallery=page.getByTestId('fittings-qa');await expect(gallery).toBeVisible();await gallery.getByRole('button',{name:'Your Office',exact:true}).click();await gallery.scrollIntoViewIfNeeded();await expect(gallery.locator('[data-fitting-preview="d3"]')).toBeVisible();await expect(gallery.locator('[data-fitting-preview="c2"]')).toBeVisible();await expect(gallery.locator('[data-fitting-preview="r2"]')).toBeVisible();await page.screenshot({path:'test-results/furniture-gallery-'+mode+'.png',fullPage:true});expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2)).toBe(true);
});

test('desk helper waits through Doug’s scheduled call without earning or changing progress',async({page})=>{
 test.setTimeout(60000);const period=83*60000,offset=31*60000,at=Math.floor((Date.now()-offset)/period)*period+offset+20000;
 await page.clock.install({time:new Date(at)});const fixture=await installGameFixture(page);await page.goto(base);await expect(page.locator('.pg-stage')).toBeVisible();await expect(page.getByRole('button',{name:/Doug is on the phone/})).toBeDisabled();
 const opening=openOwnDesk(page);await page.clock.fastForward(61000);await opening;await expect(page.locator('.pg-panelhead')).toContainText('Your desk');expect(fixture.player.pp).toBe(500000);expect(fixture.calls.some(x=>x.rpc==='do_work')).toBe(false);
});
