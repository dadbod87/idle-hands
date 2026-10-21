const {test,expect,devices}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
for(const mode of ['desktop','mobile']){
 test(mode+': actual game navigation, movement, work, emotes and appearance using isolated HTTP fixtures',async({browser})=>{
  const context=await browser.newContext(mode==='mobile'?{...devices['Pixel 7']}:{viewport:{width:1440,height:900}});
  const page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(String(e)));
  const fixture=await installGameFixture(page);
  await page.goto('http://127.0.0.1:8765/');
  await expect(page.locator('.pg-stage')).toBeVisible();
  const avatar=page.locator('.pg-room .pg-body.me');
  await expect(avatar).toBeVisible();
  await expect(page.locator('.pg-officedesk .pg-desk-svg')).toHaveCount(9);
  await expect(page.locator('.pg-officechair svg')).toHaveCount(9);
  await expect(avatar.locator('.pg-avatar-head .pg-face')).toHaveCount(0);
  const initial=await avatar.locator('..').evaluate(el=>({x:el.style.left,y:el.style.top}));
  const stage=page.locator('.pg-stage'),box=await stage.boundingBox();
  if(mode==='mobile')await page.touchscreen.tap(box.x+box.width/2+80,box.y+box.height/2+30);
  else await stage.click({position:{x:box.width/2+100,y:box.height/2+30}});
  await expect(avatar).toHaveClass(/walking/);
  await expect.poll(async()=>avatar.locator('..').evaluate(el=>({x:el.style.left,y:el.style.top}))).not.toEqual(initial);
  await page.screenshot({path:'test-results/'+mode+'-game-walking.png',fullPage:true});
  await expect(avatar).toHaveClass(/idling/,{timeout:15000});
  await page.getByTitle('Wave', {exact:true}).click();
  await expect(avatar).toHaveClass(/em-wave/);
  await page.screenshot({path:'test-results/'+mode+'-game-wave.png',fullPage:true});
  for(const [label,id] of [['Dance','dance'],['Panic','panic'],['Shrug','shrug'],['Jump','jump'],['Type furiously','type']]){
    await page.getByTitle(label,{exact:true}).click();
    await expect(avatar).toHaveClass(new RegExp('em-'+id));
  }
  await page.getByRole('button',{name:/Go to your desk/}).click();
  await expect(page.getByRole('button',{name:/Do actual work/})).toBeVisible({timeout:30000});
  await page.getByRole('button',{name:/Do actual work/}).click();
  await expect.poll(()=>fixture.calls.some(x=>x.rpc==='do_work')).toBe(true);
  await page.screenshot({path:'test-results/'+mode+'-game-desk.png',fullPage:true});
  await page.getByRole('button',{name:/Office Nonsense/}).click();
  await page.getByRole('button',{name:'bingo',exact:true}).click();
  await expect(page.locator('.pg-bingosquare')).toHaveCount(9);
  await page.getByRole('button',{name:'Return to actual work',exact:true}).click();
  // Reload into the actual hallway, walk to the mirror, and save via the real UI.
  await page.reload();
  await expect(page.locator('.pg-stage')).toBeVisible();
  await page.getByText('The Mirror',{exact:true}).click();
  await expect(page.locator('.pg-panel')).toBeVisible({timeout:15000});
  await page.getByLabel('Hair',{exact:true}).selectOption('long');
  await page.getByLabel('Expression',{exact:true}).selectOption('skeptical');
  await page.getByRole('button',{name:/Suspiciously Comfortable Hoodie/}).click();
  await expect.poll(()=>fixture.player.look.clothing).toBe('hoodie');
  expect(fixture.player.look.hair).toBe('long');
  expect(fixture.player.look.expression).toBe('skeptical');
  await page.screenshot({path:'test-results/'+mode+'-game-mirror.png',fullPage:true});
  await page.getByRole('button',{name:'Reissue the badge',exact:true}).click();
  await expect.poll(()=>fixture.calls.some(x=>x.rpc==='upsert_player')).toBe(true);
  await page.reload();
  await expect(page.locator('.pg-room .pg-body.me')).toHaveClass(/garment-hoodie/);
  expect(fixture.player.equity).toBe(2);
  expect(fixture.player.owned.intern).toBe(2);
  expect(fixture.player.wardrobe_owned).toHaveLength(6);
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2)).toBe(true);
  expect(errors).toEqual([]);
  await context.close();
 });
}
