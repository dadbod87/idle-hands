const {test,expect} = require('@playwright/test');
const base = 'http://127.0.0.1:8765';
for(const size of [{name:'desktop',width:1440,height:900},{name:'mobile',width:390,height:844}]){
 test(size.name+': renders initial game entry without fatal exceptions',async ({browser})=>{
  const context=await browser.newContext({viewport:{width:size.width,height:size.height},reducedMotion:'reduce'});
  const page=await context.newPage();
  const errors=[];
  page.on('pageerror',e=>errors.push(String(e)));
  await page.goto(base,{waitUntil:'domcontentloaded'});
  await expect(page).toHaveTitle(/Idle Hands/);
  await expect(page.locator('#root')).toBeAttached();
  await page.waitForTimeout(2500);
  const body=await page.locator('body').innerText();
  expect(body.length).toBeGreaterThan(10);
  expect(errors).toEqual([]);
  await page.screenshot({path:'test-results/'+size.name+'-entry.png',fullPage:true});
  await context.close();
 });
}

for(const viewport of [{name:'desktop',width:1440,height:900},{name:'mobile',width:390,height:844}]){
 test(viewport.name+': artwork gallery has no JSX errors or horizontal overflow',async ({browser})=>{
  const context=await browser.newContext({viewport:{width:viewport.width,height:viewport.height},reducedMotion:'reduce'});
  const page=await context.newPage(); const exceptions=[];page.on('pageerror',e=>exceptions.push(String(e)));
  await page.goto(base+'/?art-preview=1',{waitUntil:'domcontentloaded'});
  await expect(page.getByTestId('art-preview')).toBeVisible({timeout:15000});
  await expect(page.locator('.ar-npc')).toHaveCount(10);
  await expect(page.locator('.ar-palette span')).toHaveCount(6);
  await expect(page.locator('.ar-fixture')).toHaveCount(12);
  await expect(page.getByTestId('avatar-qa')).toBeVisible();
  await expect(page.getByTestId('onboard-qa')).toBeVisible();
  await expect(page.getByTestId('onboard-qa').locator('.pg-avatar-head')).toHaveCount(1);
  const onboardingWidth=await page.getByTestId('onboard-qa').evaluate(el=>({client:el.clientWidth,scroll:el.scrollWidth}));
  expect(onboardingWidth.scroll).toBeLessThanOrEqual(onboardingWidth.client+2);
  await page.getByTestId('onboard-qa').screenshot({path:'test-results/'+viewport.name+'-real-onboarding.png',animations:'disabled'});

  await expect(page.getByTestId('avatar-qa').locator('.pg-avatar-head')).toHaveCount(1);
  await expect(page.getByTestId('avatar-qa').locator('.pg-avatar-head .pg-face')).toHaveCount(0);
  const hs=await page.getByTestId('avatar-qa').locator('.pg-avatar-head').evaluate(el=>{
    const c=getComputedStyle(el);return {radius:c.borderRadius,bg:c.backgroundColor,border:c.borderTopWidth};
  });
  expect(hs.radius).toBe('0px');
  expect(hs.bg).toBe('rgba(0, 0, 0, 0)');
  expect(hs.border).toBe('0px');

  await expect(page.getByTestId('avatar-qa').locator('.ar-cell')).toHaveCount(6);
  await page.getByTestId('avatar-qa').getByLabel('Hair', {exact:true}).selectOption('long');
  await page.getByTestId('avatar-qa').getByLabel('Expression').selectOption('happy');
  await expect(page.getByTestId('avatar-qa').getByLabel('Hair', {exact:true})).toHaveValue('long');
  await page.getByTestId('avatar-qa').screenshot({path:'test-results/'+viewport.name+'-avatar-creator.png',animations:'disabled'});

  await expect(page.locator('.ar-icons .pg-iconart').first()).toBeVisible();
  await expect(page.getByTestId('art-shop-preview')).toBeVisible();
  for(const tab of ['Requisitions','Approvals','Wardrobe','Office upgrades']){
    await page.getByTestId('art-shop-preview').getByRole('button',{name:tab,exact:true}).click();
    await expect(page.getByTestId('art-shop-preview').locator('.pg-row')).toHaveCount(3);
    const shop=await page.getByTestId('art-shop-preview').evaluate(el=>({scroll:el.scrollWidth,client:el.clientWidth}));
    expect(shop.scroll).toBeLessThanOrEqual(shop.client+2);
  }
  await page.getByTestId('art-shop-preview').getByRole('button',{name:'Wardrobe',exact:true}).click();
  await page.getByTestId('art-shop-preview').screenshot({path:'test-results/'+viewport.name+'-wardrobe-gallery.png',animations:'disabled'});

  const widths=await page.evaluate(()=>({scroll:document.documentElement.scrollWidth,viewport:window.innerWidth}));
  expect(widths.scroll).toBeLessThanOrEqual(widths.viewport+2);
  expect(exceptions).toEqual([]);
  // Capture each surface at its actual layout, avoiding five redundant very tall page bitmaps.
  await page.locator('.ar-npc').first().locator('..').screenshot({path:'test-results/'+viewport.name+'-cast-gallery.png',animations:'disabled'});
  await context.close();
 });
}
