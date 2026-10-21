const {test,expect}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
for(const size of [{width:1440,height:900},{width:393,height:851},{width:320,height:640},{width:844,height:390}])test(`all Office Nonsense sections fit and open at ${size.width}x${size.height}`,async({browser})=>{
 const mobile=size.width<540||size.height<400;
 const context=await browser.newContext({viewport:size,isMobile:mobile,hasTouch:mobile}),page=await context.newPage();
 const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 const fixture=await installGameFixture(page);
 await page.goto('http://127.0.0.1:8765/');await expect(page.locator('.pg-stage')).toBeVisible({timeout:15000});
 if(size.width<540)await page.getByRole('button',{name:'More',exact:true}).click();
 await page.getByRole('button',{name:'Office Nonsense',exact:true}).click();
 const dialog=page.getByRole('dialog',{name:'Office notice',exact:true}),nav=dialog.getByRole('group',{name:'Office Nonsense sections'});
 await expect(nav.getByRole('button')).toHaveCount(6);
 const layout=await nav.evaluate(el=>{const n=el.getBoundingClientRect(),c=el.closest('.pg-card').getBoundingClientRect();return {width:el.clientWidth,scrollWidth:el.scrollWidth,left:n.left,right:n.right,cardLeft:c.left,cardRight:c.right,buttons:[...el.querySelectorAll('button')].map(b=>{const r=b.getBoundingClientRect();return {left:r.left,right:r.right,height:r.height};})};});
 expect(layout.scrollWidth).toBeLessThanOrEqual(layout.width+1);expect(layout.left).toBeGreaterThanOrEqual(layout.cardLeft);expect(layout.right).toBeLessThanOrEqual(layout.cardRight);
 for(const b of layout.buttons){expect(b.left).toBeGreaterThanOrEqual(layout.left-1);expect(b.right).toBeLessThanOrEqual(layout.right+1);expect(b.height).toBeGreaterThanOrEqual(44);}
 for(const [label,content] of [['Office log','purely comedic record'],['rumors','Rumor mill'],['bingo','phrases overheard today'],['daily',"HR's Daily To-Do List"],['lounge',"Joey's Cigar Lounge"],['awards','Employee of the Minute']]){
  const button=nav.getByRole('button',{name:label,exact:true});await expect(button).toBeInViewport();
  if(mobile)await button.tap();else await button.click();
  await expect(button).toHaveAttribute('aria-pressed','true');await expect(dialog).toContainText(content);
 }
 const colors=await nav.evaluate(el=>[getComputedStyle(el.querySelector('[aria-pressed="true"]')).backgroundColor,getComputedStyle(el.querySelector('[aria-pressed="false"]')).backgroundColor]);expect(colors[0]).not.toBe(colors[1]);
 await expect(dialog.getByText('🏆 Employee of the Minute',{exact:true})).toBeVisible();
 await page.screenshot({path:`test-results/office-nonsense-awards-${size.width}x${size.height}.png`,fullPage:true});
 await dialog.getByRole('button',{name:'Return to actual work',exact:true}).click();await expect(dialog).toHaveCount(0);
 expect(fixture.player.pp).toBe(500000);expect(fixture.player.equity).toBe(2);expect(fixture.player.owned.intern).toBe(2);
 expect(fixture.calls.some(c=>['buy_item','buy_fitting','do_deed','set_look','restructure'].includes(c.rpc))).toBe(false);expect(errors).toEqual([]);
 await context.close();
});
