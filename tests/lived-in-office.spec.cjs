const {test,expect,devices}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
for(const mode of ['desktop','mobile'])test(mode+': lived-in scenery preserves real destinations and player progress',async({browser})=>{
 const context=await browser.newContext(mode==='mobile'?{...devices['Pixel 7']}:{viewport:{width:1440,height:900}}),page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(String(e)));const fixture=await installGameFixture(page);
 await page.goto('http://127.0.0.1:8765/');await expect(page.locator('.pg-stage')).toBeVisible();
 await expect(page.locator('.pg-room [data-zone]')).toHaveCount(3);await expect(page.locator('.pg-room [data-scenery]')).toHaveCount(7);
 expect(await page.locator('.pg-room .pg-scenery').evaluateAll(els=>els.every(el=>getComputedStyle(el).pointerEvents==='none'))).toBe(true);
 await page.getByRole('button',{name:'Office directory',exact:true}).click();await page.getByRole('button',{name:'Walk to The Break Table',exact:true}).click();
 await expect(page.locator('.pg-panelhead')).toContainText('Break room',{timeout:20000});await page.locator('.pg-panel .pg-x').click();
 await page.screenshot({path:'test-results/'+mode+'-lived-in-breakroom.png',fullPage:true});
 await page.getByTitle('Wave',{exact:true}).click();await expect(page.locator('.pg-room .pg-body.me')).toHaveClass(/em-wave/);
 expect(fixture.player.pp).toBe(500000);expect(fixture.player.equity).toBe(2);expect(fixture.player.kit.desk).toBe('d3');
 expect(fixture.calls.some(x=>['buy_item','buy_fitting','do_deed','set_look'].includes(x.rpc))).toBe(false);
 expect(errors).toEqual([]);expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2)).toBe(true);
 await page.goto('http://127.0.0.1:8765/?art-preview=1');await expect(page.getByTestId('environment-qa').locator('svg')).toHaveCount(6);
 await page.getByTestId('environment-qa').screenshot({path:'test-results/'+mode+'-environment-art.png'});
 await context.close();
});
