const {test,expect}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
const base=process.env.PLANTER_BASE_URL||'http://127.0.0.1:8765/';
for(const [mode,viewport] of [['desktop',{width:1440,height:900}],['mobile',{width:390,height:844}],['landscape',{width:844,height:390}]]){
 test(mode+': each planter keeps its own route, watering effect and joke rotation',async({browser})=>{
  test.setTimeout(150000);const context=await browser.newContext({viewport,reducedMotion:'reduce',isMobile:mode!=='desktop',hasTouch:mode!=='desktop'}),page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(String(e)));
  const f=await installGameFixture(page),before=JSON.stringify({pp:f.player.pp,equity:f.player.equity,owned:f.player.owned,kit:f.player.kit,look:f.player.look});
  await page.goto(base);await expect(page.locator('.pg-stage')).toBeVisible();
  const actor=page.locator('.pg-me:not(.pg-wes)'),caption=page.getByTestId('prop-performance');
  async function visitDave(){await page.getByRole('button',{name:'Office directory',exact:true}).click();await page.getByRole('button',{name:"Walk to Dave's Office",exact:true}).click();await expect(page.locator('.pg-panelhead')).toContainText('Dave',{timeout:25000});await page.locator('.pg-panel .pg-x').click();}
  async function waterDave(line){const prop=page.locator('[data-scenery="management-plant"]');if(mode==='desktop'){await prop.focus();await page.keyboard.press('Enter');}else await prop.tap();await expect(page.getByRole('dialog')).toContainText('planter by Dave’s office');await page.getByRole('button',{name:'Water the plastic plant',exact:true}).click();await expect(caption).toContainText(line,{timeout:20000});await checkTarget('management-plant',1935,350);}
  async function waterBreak(line){if(viewport.width<600)await page.getByRole('button',{name:'More',exact:true}).click();await page.getByRole('button',{name:'Office field guide',exact:true}).click();await page.getByRole('button',{name:/Make the props worse/}).click();await expect(caption).toContainText(line,{timeout:25000});await checkTarget('plant-rota',382.5,1180);}
  async function checkTarget(id,x,y){
   const effect=page.locator('.effect-plant');await expect(effect).toHaveAttribute('data-scenery-target',id);await expect(page.locator('.pg-body.me')).toHaveClass(/em-water/);await expect(page.getByRole('dialog')).toHaveCount(0);
   const point=await actor.evaluate(el=>({x:parseFloat(el.style.left),y:parseFloat(el.style.top)}));expect(Math.abs(point.x-x)).toBeLessThan(20);expect(Math.abs(point.y-y)).toBeLessThan(20);
   const bubble=page.getByTestId('prop-bubble');await expect(bubble).toHaveAttribute('data-scenery-target',id);
   if(mode==='landscape')await expect(bubble).toBeHidden();else {await expect(bubble).toBeVisible();const b=await bubble.boundingBox(),p=await page.locator('[data-scenery="'+id+'"]').boundingBox(),a=await page.locator('.pg-body.me').boundingBox(),stage=await page.locator('.pg-stage').boundingBox();expect(b.y+b.height+4).toBeLessThanOrEqual(p.y);expect(b.y+b.height+4).toBeLessThanOrEqual(a.y);expect(b.y).toBeGreaterThanOrEqual(stage.y);expect(b.x).toBeGreaterThanOrEqual(stage.x);expect(b.x+b.width).toBeLessThanOrEqual(stage.x+stage.width);}
   await expect(caption).toBeVisible();expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
  }
  await visitDave();await waterDave('Growth: administrative.');await page.screenshot({path:`test-results/${mode}-dave-planter-watering.png`,fullPage:true});
  await waterDave('The plant has declined to comment.');await waterBreak('Growth: administrative.');await page.screenshot({path:`test-results/${mode}-break-planter-watering.png`,fullPage:true});
  await page.reload();await expect(page.locator('.pg-stage')).toBeVisible();await visitDave();await waterDave('You watered the rota.');await waterBreak('The plant has declined to comment.');
  expect(f.calls.filter(c=>c.rpc==='office_perform').map(c=>c.args.p_kind)).toEqual(['plant','plant','plant','plant','plant']);
  expect(JSON.stringify({pp:f.player.pp,equity:f.player.equity,owned:f.player.owned,kit:f.player.kit,look:f.player.look})).toBe(before);expect(errors).toEqual([]);await context.close();
 });
}
