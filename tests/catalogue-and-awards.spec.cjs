const {test,expect,devices}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
const fittings=require('./fixtures/fittings.json');
for(const mode of ['desktop','mobile']){
 test(mode+': actual desk shows all fitting previews for free and purchase equips the shared item art',async({browser})=>{
  const context=await browser.newContext(mode==='mobile'?{...devices['Pixel 7']}:{viewport:{width:1440,height:900}}),page=await context.newPage();
  test.setTimeout(60000);
  const fixture=await installGameFixture(page,{fittings});
  await page.goto('http://127.0.0.1:8765/');await expect(page.locator('.pg-stage')).toBeVisible();
  await page.getByRole('button',{name:/Go to your desk/}).click();
  await expect(page.getByRole('button',{name:/Do actual work/})).toBeVisible({timeout:30000});
  await page.locator('.pg-officedesk.mine').click();
  await page.getByRole('button',{name:'Catalogue',exact:true}).click({timeout:15000});
  const panel=page.locator('.pg-panel');
  for(const [label,key] of [['Yourself','vanity'],['Your Office','office_kit']]){
   await panel.getByRole('button',{name:label,exact:true}).click();
   await expect(panel.locator('[data-fitting-entry]')).toHaveCount(17);
   for(const item of fittings[key]){
    const entry=panel.locator(`[data-fitting-entry="${item.id}"]`);
    await entry.getByRole('button',{name:'Preview '+item.name,exact:true}).click();
    await expect(panel.getByTestId('fitting-detail').locator('[data-fitting-preview]')).toHaveAttribute('data-fitting-preview',item.id);
   }
   await panel.getByTestId('fitting-detail').screenshot({path:'test-results/'+mode+'-'+key+'-preview.png'});
  }
  expect(fixture.player.pp).toBe(500000);
  expect(fixture.calls.filter(x=>x.rpc==='buy_fitting')).toHaveLength(0);
  await panel.getByRole('button',{name:'Yourself',exact:true}).click();
  const mug=panel.locator('[data-fitting-entry="h1"]');
  await mug.getByRole('button',{name:/A Mug You Never Wash/}).filter({hasNotText:'Preview'}).first().click();
  await expect.poll(()=>fixture.player.vanity.held).toBe('h1');
  expect(fixture.calls.filter(x=>x.rpc==='buy_fitting')).toEqual([{rpc:'buy_fitting',args:{p_key:'vanity',p_id:'h1'}}]);
  await expect(page.locator('.pg-room .pg-body.me [data-held-item="h1"]')).toHaveCount(1);
  expect(fixture.player.equity).toBe(2);expect(fixture.player.owned.intern).toBe(2);
  await context.close();
 });
 test(mode+': personnel shows server awards and read-only visual gallery fits the screen',async({browser})=>{
  const context=await browser.newContext(mode==='mobile'?{...devices['Pixel 7']}:{viewport:{width:1440,height:900}}),page=await context.newPage();
  const fixture=await installGameFixture(page,{officeAwards:['oa_welcome']});fixture.player.goodwill=3;
  await page.goto('http://127.0.0.1:8765/');await expect(page.locator('.pg-stage')).toBeVisible();
  // Walk north until the wall cabinet is in the actual camera view.
  await page.keyboard.down('ArrowUp');await page.waitForTimeout(2100);await page.keyboard.up('ArrowUp');
  await page.keyboard.down('ArrowRight');await page.waitForTimeout(450);await page.keyboard.up('ArrowRight');
  await page.getByText('HR Cabinet',{exact:true}).click();
  const panel=page.locator('.pg-panel');await expect(panel).toBeVisible({timeout:20000});
  await panel.getByRole('button',{name:/^Awards /}).click();
  await expect(panel.locator('[data-office-award]')).toHaveCount(8);
  await expect(panel.locator('[data-office-award="oa_welcome"]')).toContainText('Earned');
  await expect(panel.locator('[data-office-award="oa_glue"]')).toContainText('To earn');
  expect(fixture.calls.some(x=>x.rpc==='claim_office_awards')).toBe(true);
  expect(fixture.player.pp).toBe(500000);
  await page.screenshot({path:'test-results/'+mode+'-personnel-commendations.png',fullPage:true});
  await page.goto('http://127.0.0.1:8765/?art-preview=1');
  const gallery=page.getByTestId('fittings-qa');
  for(const [label,key] of [['Yourself','vanity'],['Your Office','office_kit']]){
   await gallery.getByRole('button',{name:label,exact:true}).click();
   await expect(gallery.locator('[data-fitting-entry]')).toHaveCount(17);
   // Even locked/unaffordable items must have a usable preview.
   const item=fittings[key][0];await gallery.getByRole('button',{name:'Preview '+item.name,exact:true}).click();
   await expect(gallery.getByTestId('fitting-detail')).toBeVisible();
   await gallery.screenshot({path:'test-results/'+mode+'-'+key+'-catalogue.png'});
  }
  await page.getByTestId('break-table-qa').screenshot({path:'test-results/'+mode+'-break-table.png'});
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2)).toBe(true);
  await context.close();
 });
}
