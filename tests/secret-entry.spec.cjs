const {test,expect}=require('@playwright/test');const {installGameFixture}=require('./game-fixture.cjs');
for(const [mode,viewport] of [['desktop',{width:1440,height:900}],['mobile',{width:390,height:844}]]){
 test(mode+': locked doors enter only when the server grants the weekly secret',async({browser})=>{
  test.setTimeout(70000);const context=await browser.newContext({viewport,reducedMotion:'reduce'}),page=await context.newPage();let enabled=false,claimed=false;
  const f=await installGameFixture(page,{onCowTry:()=>{if(!enabled||claimed)return null;claimed=true;return {orbs:24,secs:75,loot:'pig'};}});
  async function visitDoor(){
   const actor=page.locator('.pg-me:not(.pg-wes)');await page.bringToFront();
   // Playwright keydown has no OS repeat. Repeat the held key so a reload/blur
   // cannot strand the test at spawn after its sole input event is dropped.
   try{await expect.poll(async()=>{await page.keyboard.down('ArrowLeft');return actor.evaluate(el=>parseFloat(el.style.left));},{timeout:10000,intervals:[100,250]}).toBeLessThan(115);}
   finally{await page.keyboard.up('ArrowLeft');}
  }
  async function knock(){const before=f.calls.filter(c=>c.rpc==='cow_try').length;await page.locator('.pg-room .pg-fx').filter({hasText:'Cigar Lounge'}).click();await expect.poll(()=>f.calls.filter(c=>c.rpc==='cow_try').length,{timeout:10000}).toBe(before+1);}
  await page.goto('http://127.0.0.1:8765/');await expect(page.locator('.pg-stage')).toBeVisible();await visitDoor();await knock();await expect(page.locator('.pg-cowlevel')).toHaveCount(0);
  enabled=true;await knock();await expect(page.locator('.pg-cowlevel')).toBeVisible();await expect(page.locator('.pg-cow')).toHaveCount(24);await page.screenshot({path:`test-results/${mode}-server-granted-secret.png`,fullPage:true});
  await page.reload();await expect(page.locator('.pg-stage')).toBeVisible();await visitDoor();await knock();await expect(page.locator('.pg-cowlevel')).toHaveCount(0);
  expect(f.calls.filter(c=>c.rpc==='cow_finish')).toHaveLength(0);expect(f.player.pp).toBe(500000);expect(f.player.cow).toBeUndefined();await context.close();
 });
}
