const {test,expect}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
const base=process.env.HUD_BASE_URL||'http://127.0.0.1:8765';
const quiet=Date.parse('2026-10-22T09:00:00Z');
const iso=offset=>new Date(quiet+offset).toISOString();
async function setup(page,mode='multiple'){
 await page.clock.install({time:new Date(quiet)});
 const f=await installGameFixture(page,{name:'QA Employee With A Long Display Name'});
 f.player.equity=0;f.player.owned={};
 if(mode!=='none')f.player.buffs=[{kind:'espresso',name:'Double Espresso',mult:1.35,until:iso(77000)}];
 if(mode==='multiple'){
  f.player.heat=5;f.player.frenzy_until=iso(77000);
  f.player.buffs.push({kind:'meeting',mult:.65,from_name:'QA Pal',until:iso(125000)},
   {kind:'crash',mult:.85,start:iso(77000),until:iso(150000)},
   {kind:'legacy',name:'An extraordinarily long official productivity improvement initiative',mult:1.2,from:'2026-10-22T09:01:17Z',until:iso(150000)},
   {kind:'expired',mult:2,until:iso(-1000)});
 }
 await page.goto(base);await expect(page.locator('.pg-stage')).toBeVisible({timeout:20000});
 return f;
}
for(const size of [{width:1440,height:900},{width:1024,height:768},{width:390,height:844},{width:320,height:568},{width:844,height:390}]){
 test(`active effects responsive and accessible at ${size.width}x${size.height}`,async({browser})=>{
  const context=await browser.newContext({viewport:size,hasTouch:size.width<900,reducedMotion:'reduce'}),page=await context.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(String(e)));const f=await setup(page);
  const strip=page.getByRole('region',{name:'Active effects',exact:true}),badges=strip.locator('.pg-effect');
  await expect(badges).toHaveCount(4);
  await expect(page.locator('.pg-hudpp .pg-tag.bad,.pg-bar>.pg-statusboost,.pg-bar>.pg-drinkboost')).toHaveCount(0);
  await expect(page.getByRole('button',{name:/Dave wants to see you/})).toBeVisible();
  const first=badges.first();await first.focus();await expect(page.getByRole('region',{name:'Effect details',exact:true})).toContainText('Double Espresso');
  await expect(page.locator('#active-effect-description')).toContainText('+35% output');
  await expect(page.locator('#active-effect-description')).toContainText('left');
  await page.keyboard.press('Enter');await expect(first).toHaveAttribute('aria-expanded','true');
  await page.keyboard.press('Escape');await expect(page.getByRole('region',{name:'Effect details',exact:true})).toHaveCount(0);
  const negative=strip.locator('[data-effect-id^="buff-1-"]');await negative.click();
  await expect(page.locator('#active-effect-description')).toContainText('Penalty: −35% output');
  expect(await negative.locator('.pg-effect-symbol').innerText()).toBe('▼');
  await page.getByRole('button',{name:'Close effect details',exact:true}).click();
  // Bounded strip and badges cannot collide with identity, balance or utility controls.
  const m=await page.evaluate(()=>{const r=s=>{const x=document.querySelector(s).getBoundingClientRect();return {x:x.x,y:x.y,right:x.right,bottom:x.bottom,height:x.height}};return {width:document.documentElement.scrollWidth,strip:r('.pg-effects'),name:r('.pg-hudid'),balance:r('.pg-hudpp'),buttons:r('.pg-hudbtns'),stage:r('.pg-stage')}});
  expect(m.width).toBeLessThanOrEqual(size.width+1);expect(m.stage.height).toBeGreaterThanOrEqual(size.height<640?180:240);
  const overlap=(a,b)=>a.x<b.right&&b.x<a.right&&a.y<b.bottom&&b.y<a.bottom;
  for(const other of [m.name,m.balance,m.buttons])expect(overlap(m.strip,other)).toBe(false);
  for(const b of await badges.all())expect((await b.boundingBox()).height).toBeGreaterThanOrEqual(44);
  await strip.locator('[data-effect-id="review"]').scrollIntoViewIfNeeded();
  await strip.locator('[data-effect-id="review"]').click();await expect(page.locator('#active-effect-description')).toContainText('Until settled');
  await page.getByRole('button',{name:'Close effect details',exact:true}).click();
  await page.clock.fastForward(78000);
  await expect(strip.locator('[data-effect-id="frenzy"]')).toHaveCount(0);
  await expect(strip.getByRole('button',{name:/Double Espresso/})).toHaveCount(0);
  const long=strip.getByRole('button',{name:/An extraordinarily long/});await long.scrollIntoViewIfNeeded();await long.click();
  await expect(page.locator('#active-effect-description')).toContainText('An extraordinarily long official productivity improvement initiative');
  await page.screenshot({path:`test-results/hud-effects-${size.width}x${size.height}.png`,fullPage:true});
  await page.clock.fastForward(73000);await expect(badges).toHaveCount(1);await expect(badges).toContainText('Under review');
  expect(f.player.pp).toBe(500000);expect(f.player.buffs).toHaveLength(5);expect(errors).toEqual([]);
  await context.close();
 });
}
test('empty and single boost, hover details, countdown and expiry without earning rerenders',async({page})=>{
 await setup(page,'none');const strip=page.getByRole('region',{name:'Active effects',exact:true});await expect(strip).toContainText('No active effects');
 await setup(page,'one');const first=strip.locator('.pg-effect');await expect(first).toHaveCount(1);
 await first.hover();await expect(page.locator('#active-effect-description')).toContainText('Double Espresso');
 const before=await first.innerText();await page.clock.fastForward(3000);expect(await first.innerText()).not.toBe(before);
 await page.clock.fastForward(75000);await expect(first).toHaveCount(0);await expect(strip).toContainText('No active effects');await expect(page.locator('#active-effect-detail')).toHaveCount(0);
});
test('office event and Jess windows appear once and expire; event explanation and bell remain',async({page})=>{
 await setup(page,'none');await page.clock.setSystemTime(new Date('2026-10-22T00:10:00Z'));await page.clock.fastForward(1000);
 await expect(page.locator('.pg-effect[data-effect-id="event-drill"]')).toHaveCount(1);
 await expect(page.locator('.pg-event')).toContainText('Office bulletin');await expect(page.getByRole('button',{name:'alert me',exact:true})).toBeVisible();
 await page.clock.setSystemTime(new Date('2026-10-22T00:13:00Z'));await page.clock.fastForward(1000);await expect(page.locator('.pg-effect')).toHaveCount(0);
 await page.clock.setSystemTime(new Date('2026-10-22T00:55:00Z'));await page.clock.fastForward(1000);await expect(page.locator('[data-effect-id="jess"]')).toContainText('+20% output');
 await page.clock.fastForward(240000);await expect(page.locator('[data-effect-id="jess"]')).toHaveCount(0);
});
test('phone tap pins full details, repeat tap/outside dismiss; HUD keys do not activate the office',async({browser})=>{
 const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true}),page=await context.newPage();await setup(page);
 const badge=page.locator('.pg-effect').first();await badge.tap();await expect(page.locator('#active-effect-description')).toContainText('Double Espresso');
 await badge.tap();await expect(page.locator('#active-effect-detail')).toHaveCount(0);await badge.tap();
 await page.getByRole('button',{name:'Close effect details',exact:true}).tap();await expect(page.locator('#active-effect-detail')).toHaveCount(0);
 await badge.tap();await page.locator('.pg-hudname').tap();await expect(page.locator('#active-effect-detail')).toHaveCount(0);
 await badge.focus();await page.keyboard.press('Enter');await expect(page.getByRole('dialog')).toHaveCount(0);await page.keyboard.press('Escape');await expect(page.locator('#active-effect-detail')).toHaveCount(0);
 await context.close();
});
