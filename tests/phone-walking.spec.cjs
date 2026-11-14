const {test,expect}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
for(const viewport of [{width:390,height:640},{width:393,height:851},{width:844,height:390}])test(`steady phone walking ${viewport.width}x${viewport.height}: nearby and selected actions never resize or zoom the floor`,async({browser})=>{
 test.setTimeout(80000);
 const ctx=await browser.newContext({viewport,isMobile:true,hasTouch:true}),page=await ctx.newPage();
 const f=await installGameFixture(page);await page.clock.setFixedTime(new Date('2026-11-14T15:26:48Z'));
 await page.goto('http://127.0.0.1:8765/');await expect(page.locator('.pg-stage')).toBeVisible();
 const hr=async()=>{await page.getByRole('button',{name:'Office directory',exact:true}).tap();await page.getByRole('button',{name:/Walk to HR Cabinet/}).tap();await expect(page.locator('.pg-panelhead')).toContainText('Personnel file',{timeout:30000});await page.locator('.pg-panel .pg-x').tap();};
 await hr();await expect(page.locator('.pg-floor-prompt .pg-open')).toBeVisible();
 await page.locator('.pg-floor-prompt .pg-open').tap();await expect(page.locator('.pg-panelhead')).toContainText('Personnel file');await page.locator('.pg-panel .pg-x').tap();
 await page.waitForTimeout(350);
 await page.evaluate(()=>{
  window.walkSamples=[];window.walkSampling=true;
  const sample=()=>{if(!window.walkSampling)return;const floor=document.querySelector('.pg-stage').getBoundingClientRect(),bar=document.querySelector('.pg-bar').getBoundingClientRect(),room=document.querySelector('.pg-room'),matrix=new DOMMatrix(getComputedStyle(room).transform),prompt=document.querySelector('.pg-prompt');window.walkSamples.push({height:floor.height,top:floor.top,barTop:bar.top,barHeight:bar.height,scale:matrix.a,prompt:prompt&&getComputedStyle(prompt).display!=='none'?prompt.textContent.trim():''});requestAnimationFrame(sample);};sample();
 });
 // Real touch taps on empty floor walk away from the cabinet across its reach boundary.
 for(let i=0;i<5;i++){
  const point=await page.evaluate(()=>{const floor=document.querySelector('.pg-stage').getBoundingClientRect(),room=document.querySelector('.pg-room'),actor=room.querySelector('.pg-body.me').closest('.pg-me'),matrix=new DOMMatrix(getComputedStyle(room).transform),y=parseFloat(actor.style.top);return {oldY:y,x:floor.left+parseFloat(actor.style.left)*matrix.a+matrix.e,y:Math.min(floor.bottom-62,floor.top+(y+65)*matrix.a+matrix.f)};});
  await page.touchscreen.tap(point.x,point.y);
  await expect.poll(()=>page.locator('.pg-room .pg-body.me').evaluate(el=>parseFloat(el.closest('.pg-me').style.top)),{timeout:4000}).toBeGreaterThan(point.oldY+25);
  await page.waitForTimeout(250);
 }
 await expect(page.locator('.pg-prompt .pg-open')).toHaveCount(0);
 await expect(page.getByRole('dialog')).toHaveCount(0);
 // Walk back through the same boundary, then deliberately select the object by touch.
 await hr();await page.locator('[data-fixture="hr"]').tap();await expect(page.getByRole('button',{name:/Open HR Cabinet/})).toBeVisible();
 await page.waitForTimeout(300);
 const samples=await page.evaluate(()=>{window.walkSampling=false;return window.walkSamples;});
 expect(samples.length).toBeGreaterThan(50);
 for(const key of ['height','top','barTop','barHeight','scale']){const values=samples.map(x=>x[key]);expect(Math.max(...values)-Math.min(...values),key+' changed while walking').toBeLessThan(key==='scale'?0.00001:1);}
 expect(samples.some(x=>x.prompt==='')).toBe(true);expect(samples.some(x=>x.prompt.includes('HR Cabinet'))).toBe(true);
 await expect(page.getByRole('button',{name:'Office hub',exact:true})).toBeVisible();
 const geometry=await page.evaluate(()=>{const p=document.querySelector('.pg-prompt').getBoundingClientRect(),floor=document.querySelector('.pg-stage').getBoundingClientRect(),rail=document.querySelector('.pg-feedback-rail').getBoundingClientRect();return {p:p.toJSON(),floor:floor.toJSON(),rail:rail.toJSON(),width:document.documentElement.scrollWidth,height:document.documentElement.scrollHeight};});
 expect(geometry.p.top).toBeGreaterThanOrEqual(geometry.floor.top);expect(geometry.p.bottom).toBeLessThanOrEqual(geometry.floor.bottom);expect(geometry.p.bottom).toBeLessThanOrEqual(geometry.rail.top);expect(geometry.p.height).toBe(48);expect(geometry.width).toBeLessThanOrEqual(viewport.width);expect(geometry.height).toBeLessThanOrEqual(viewport.height);
 await page.screenshot({path:`test-results/steady-walk-${viewport.width}.png`,fullPage:true});
 await page.getByRole('button',{name:/Open HR Cabinet/}).tap();await expect(page.locator('.pg-panelhead')).toContainText('Personnel file');
 expect(f.calls.filter(c=>['do_work','buy_item','do_deed','grab_chair','buy_fitting','office_interact'].includes(c.rpc))).toHaveLength(0);expect(f.player.pp).toBe(500000);expect(f.player.equity).toBe(2);
 await ctx.close();
});
