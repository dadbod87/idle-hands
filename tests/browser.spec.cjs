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
