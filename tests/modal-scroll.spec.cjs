const {test,expect}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
for(const viewport of [{width:390,height:640},{width:844,height:390}]){
 test(`onboarding help scrolls by touch and closes at ${viewport.width}x${viewport.height}`,async({browser})=>{
  const context=await browser.newContext({viewport,isMobile:true,hasTouch:true,deviceScaleFactor:1});
  const page=await context.newPage();
  await installGameFixture(page);
  await page.goto('http://127.0.0.1:8765/');
  await expect(page.locator('.pg-stage')).toBeVisible();
  await page.locator('.pg-hud .pg-help').first().tap();
  const card=page.locator('.pg-card');
  await expect(card.getByText('Your first five minutes',{exact:true})).toBeVisible();
  const bounds=await card.boundingBox();
  expect(bounds.y).toBeGreaterThanOrEqual(0);
  expect(bounds.y+bounds.height).toBeLessThanOrEqual(viewport.height);
  const session=await context.newCDPSession(page);
  const x=bounds.x+bounds.width*.65,y=bounds.y+bounds.height-45;
  await session.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y}]});
  for(let step=1;step<=10;step++){
    await session.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:y-step*(bounds.height-95)/10}]});
  }
  await session.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  await expect.poll(()=>card.evaluate(el=>el.scrollTop),{timeout:2000}).toBeGreaterThan(0);
  // Scroll to the last action, then activate it with an actual touch tap.
  const start=card.getByRole('button',{name:'Start earning',exact:true});
  await start.scrollIntoViewIfNeeded();
  const end=await start.boundingBox();
  expect(end.y).toBeGreaterThanOrEqual(bounds.y);
  expect(end.y+end.height).toBeLessThanOrEqual(bounds.y+bounds.height+1);
  await page.screenshot({path:`test-results/help-bottom-${viewport.width}x${viewport.height}.png`,fullPage:true});
  await start.tap();
  await expect(card).toHaveCount(0);
  await expect(page.locator('.pg-stage')).toBeVisible();
  await context.close();
 });
}
