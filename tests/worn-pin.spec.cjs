const {test,expect,devices}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
async function openCollection(page){
 await page.keyboard.down('ArrowUp');
 await expect.poll(()=>page.locator('.pg-me:not(.pg-wes)').evaluate(el=>parseFloat(el.style.top)),{timeout:10000,intervals:[30]}).toBeLessThan(205);
 await page.keyboard.up('ArrowUp');await page.keyboard.down('ArrowRight');
 await expect.poll(()=>page.locator('.pg-me:not(.pg-wes)').evaluate(el=>parseFloat(el.style.left)),{timeout:10000,intervals:[30]}).toBeGreaterThan(1690);
 await page.keyboard.up('ArrowRight');await expect(page.locator('.pg-prompt')).toContainText('HR Cabinet');
 await page.locator('.pg-prompt .pg-open').click();await page.locator('.pg-panel').getByRole('button',{name:'Collection',exact:true}).click();
}
for(const mode of ['desktop','mobile'])test(mode+': HR pin equips on character, survives reload and can be removed or replaced',async({browser})=>{
 const context=await browser.newContext(mode==='mobile'?{...devices['Pixel 7']}:{viewport:{width:1440,height:900}}),page=await context.newPage();
 const fixture=await installGameFixture(page,{ownedPins:['beta','p01']});
 await page.goto('http://127.0.0.1:8765/');await expect(page.locator('.pg-stage')).toBeVisible();
 const pin=page.locator('.pg-room .pg-body.me [data-worn-pin]');await expect(pin).toHaveCount(0);
 await openCollection(page);const panel=page.locator('.pg-panel');
 await panel.getByRole('button',{name:'Wear Beta Tester',exact:true}).click();
 await expect(panel.getByRole('button',{name:'Remove Beta Tester',exact:true})).toHaveAttribute('aria-pressed','true');
 await expect(panel.getByRole('status')).toContainText('Wearing: Beta Tester');
 await expect(pin).toHaveAttribute('data-worn-pin','beta');expect(fixture.player.pin).toBe('beta');
 await panel.getByRole('button',{name:'close',exact:true}).click();
 await page.getByTitle('Wave',{exact:true}).click();await expect(page.locator('.pg-body.me')).toHaveClass(/em-wave/);
 await expect(pin).toBeVisible();
 const inside=await pin.evaluate(el=>{const p=el.getBoundingClientRect(),t=el.closest('.pg-rig').querySelector('.pg-torso').getBoundingClientRect();return p.top>=t.top&&p.bottom<=t.bottom&&p.left>=t.left&&p.right<=t.right;});expect(inside).toBe(true);
 await page.screenshot({path:'test-results/'+mode+'-beta-pin-worn.png',fullPage:true});
 await page.reload();await expect(pin).toHaveAttribute('data-worn-pin','beta');
 await openCollection(page);await panel.getByRole('button',{name:'Remove Beta Tester',exact:true}).click();await expect(pin).toHaveCount(0);
 await panel.getByRole('button',{name:'Wear Five Year Pin',exact:true}).click();await expect(pin).toHaveAttribute('data-worn-pin','p01');
 expect(fixture.calls.filter(x=>x.rpc==='set_pin').map(x=>x.args.p_id)).toEqual(['beta',null,'p01']);
 expect(fixture.player.pp).toBe(500000);expect(fixture.player.equity).toBe(2);expect(fixture.player.owned.intern).toBe(2);expect(fixture.player.extras).toEqual(['beta','p01']);
 await page.goto('http://127.0.0.1:8765/?art-preview=1');const gallery=page.getByTestId('worn-pin-qa');
 await expect(gallery.locator('[data-worn-pin="beta"]')).toHaveCount(2);await expect(gallery.locator('.costumed.big [data-worn-pin="beta"]')).toBeVisible();
 await gallery.screenshot({path:'test-results/'+mode+'-pin-costume-gallery.png'});
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2)).toBe(true);await context.close();
});
