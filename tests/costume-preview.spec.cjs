const {test,expect,devices}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
const costumes=[['cone','Traffic Cone'],['party','Party Hat'],['hardhat','Hard Hat'],['visor','Accounting Visor'],['kilt','Business Kilt'],['robe','Bathrobe'],['hawaii','Hawaiian Shirt'],['suit','Interview Suit'],['trex','Inflatable T-Rex'],['mascot','Ledger the Lynx'],['board','Sandwich Board']].map(([id,name])=>({id,name,cost:.0001}));
for(const mode of ['desktop','mobile']){
 test(mode+': actual supply closet previews every costume for free and purchase still equips selected costume',async({browser})=>{
  const context=await browser.newContext(mode==='mobile'?{...devices['Pixel 7']}:{viewport:{width:1440,height:900}});
  const page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(String(e)));
  const fixture=await installGameFixture(page,{costumes,coworkers:[{id:'00000000-0000-4000-8000-000000000002',name:'QA Coworker',look:{head:'robot',build:'slim',bottom:'trousers',top:2,legs:0}}]});
  fixture.player.look.head='alien';
  await page.goto('http://127.0.0.1:8765/');
  await expect(page.locator('.pg-stage')).toBeVisible();
  await page.getByText('Supply Closet',{exact:true}).click();
  const panel=page.locator('.pg-panel');
  await expect(panel).toBeVisible({timeout:20000});
  await expect(panel.locator('.pg-costume-entry')).toHaveCount(11);
  for(const c of costumes){
   const row=panel.locator(`[data-costume-entry="${c.id}"]`);
   const inspect=row.getByRole('button',{name:'Preview '+c.name,exact:true});
   await inspect.click();
   await expect(inspect).toHaveAttribute('aria-expanded','true');
   const detail=panel.getByTestId('costume-detail');
   await expect(detail.locator('.pg-costume-preview')).toHaveAttribute('data-costume',c.id);
   await expect(detail.locator('[data-head]')).toHaveAttribute('data-head','alien');
   await expect(detail.locator('.pg-body')).toHaveClass(/costumed/);
   if(['cone','party','hardhat','visor'].includes(c.id))await expect(detail.locator('.pg-hat')).toHaveCount(1);
   if(['trex','mascot'].includes(c.id))await expect(detail.locator('.pg-suit')).toHaveCount(2);
   if(c.id==='board')await expect(detail.getByText('ASK ME ABOUT SYNERGY',{exact:true})).toHaveCount(1);
  }
  expect(fixture.calls.filter(x=>x.rpc==='dress')).toHaveLength(0);
  expect(fixture.player.pp).toBe(500000);
  expect(fixture.player.outfit).toBeUndefined();
  await panel.locator('.pg-pick').filter({hasText:'QA Coworker'}).click();
  await expect(panel.getByTestId('costume-detail').locator('[data-head]')).toHaveAttribute('data-head','robot');
  await expect(panel.getByRole('button',{name:'Dress QA Coworker in Sandwich Board — 240 BW',exact:true})).toBeEnabled();
  await panel.locator('.pg-pick').filter({hasText:'yourself'}).click();
  await expect(panel.getByTestId('costume-detail').locator('[data-head]')).toHaveAttribute('data-head','alien');
  await panel.locator('[data-costume-entry="party"]').getByRole('button',{name:'Preview Party Hat',exact:true}).click();
  await panel.getByTestId('costume-detail').screenshot({path:'test-results/'+mode+'-party-costume-preview.png'});
  await panel.locator('[data-costume-entry="visor"]').getByRole('button',{name:'Preview Accounting Visor',exact:true}).click();
  await panel.getByTestId('costume-detail').screenshot({path:'test-results/'+mode+'-visor-costume-preview.png'});
  await panel.locator('[data-costume-entry="trex"]').getByRole('button',{name:'Preview Inflatable T-Rex',exact:true}).click();
  await panel.getByTestId('costume-detail').screenshot({path:'test-results/'+mode+'-trex-costume-preview.png'});
  await panel.getByRole('button',{name:'Wear Inflatable T-Rex — 120 BW',exact:true}).click();
  await expect(panel).toHaveCount(0);
  expect(fixture.calls.filter(x=>x.rpc==='dress')).toEqual([{rpc:'dress',args:{p_target:fixture.player.id,p_outfit:'trex'}}]);
  await expect(page.locator('.pg-room .pg-body.me')).toHaveClass(/costumed/);
  await expect(page.locator('.pg-room .pg-body.me .pg-suit')).toHaveCount(2);
  expect(fixture.player.owned.intern).toBe(2);
  expect(fixture.player.equity).toBe(2);
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2)).toBe(true);
  expect(errors).toEqual([]);
  await context.close();
 });
 test(mode+': read-only gallery renders all costume thumbnails without overflow',async({browser})=>{
  const context=await browser.newContext({viewport:mode==='mobile'?{width:390,height:844}:{width:1440,height:900}}),page=await context.newPage();
  await page.goto('http://127.0.0.1:8765/?art-preview=1');
  const closet=page.getByTestId('closet-qa');
  await expect(closet.locator('.pg-costume-preview')).toHaveCount(11);
  await closet.getByRole('button',{name:'Preview Party Hat',exact:true}).click();
  await expect(closet.getByTestId('costume-detail')).toBeVisible();
  await closet.screenshot({path:'test-results/'+mode+'-supply-closet.png'});
  expect(await closet.evaluate(el=>el.scrollWidth<=el.clientWidth+2)).toBe(true);
  await context.close();
 });
}
