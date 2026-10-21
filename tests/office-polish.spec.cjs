const {test,expect,devices}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
for(const mode of ['desktop','mobile'])test(mode+': illustrated controls and directory keep real walking and emotes',async({browser})=>{
 const context=await browser.newContext(mode==='mobile'?{...devices['Pixel 7']}:{viewport:{width:1440,height:900}}),page=await context.newPage();
 const fixture=await installGameFixture(page);await page.goto('http://127.0.0.1:8765/');await expect(page.locator('.pg-stage')).toBeVisible();
 const emotes=page.locator('.pg-bar .pg-emote');await expect(emotes).toHaveCount(6);
 for(const label of ['Jump','Dance','Wave','Panic','Shrug','Type furiously']){
  const button=page.getByRole('button',{name:label,exact:true});await expect(button.locator('svg')).toBeVisible();
  const box=await button.boundingBox();expect(box.width).toBeGreaterThanOrEqual(44);expect(box.height).toBeGreaterThanOrEqual(44);
  await button.click();await expect(button).toHaveAttribute('aria-pressed','true');
 }
 await page.screenshot({path:'test-results/'+mode+'-polish-controls.png',fullPage:true});
 await page.getByRole('button',{name:'Office directory',exact:true}).click();const directory=page.getByTestId('office-directory');
 await expect(directory.getByRole('button',{name:/^Walk to /})).toHaveCount(11);
 await page.screenshot({path:'test-results/'+mode+'-office-directory.png',fullPage:true});
 await directory.getByRole('button',{name:'Walk to HR Cabinet',exact:true}).click();
 await expect(page.locator('.pg-body.me')).toHaveClass(/walking/);
 await expect(page.locator('.pg-panelhead')).toContainText('Personnel file',{timeout:20000});
 await page.locator('.pg-panel .pg-x').click();
 await page.getByRole('button',{name:'Office directory',exact:true}).click();
 await directory.getByRole('button',{name:'Walk to Your desk',exact:true}).click();
 await expect(page.locator('.pg-panelhead')).toContainText('Your desk',{timeout:20000});
 await expect(page.getByRole('button',{name:/Do actual work/})).toBeVisible();
 await page.locator('.pg-panel .pg-x').click();await page.getByRole('button',{name:'Turn sound on',exact:true}).click();
 await expect(page.getByRole('button',{name:'Turn sound off',exact:true})).toHaveAttribute('aria-pressed','true');
 await page.getByRole('button',{name:'Turn sound off',exact:true}).click();
 expect(fixture.player.pp).toBe(500000);expect(fixture.player.equity).toBe(2);expect(fixture.player.owned.intern).toBe(2);
 expect(fixture.calls.some(x=>['buy_item','buy_fitting','set_look','restructure'].includes(x.rpc))).toBe(false);
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2)).toBe(true);
 await page.goto('http://127.0.0.1:8765/?art-preview=1');await expect(page.getByTestId('polish-controls-qa').getByTestId('office-directory')).toBeVisible();
 await context.close();
});
