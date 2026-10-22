const {test,expect,devices}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
const {model}=require('./chair-spawns.test.cjs');
const map=model();
for(const mode of ['desktop','mobile'])test(mode+': distant good chair renders and uses the server claim result',async({browser})=>{
 test.setTimeout(60000);
 let window,point;
 for(let w=4200000;w<4220000;w++){const p=map.at(w*420000+1000);if(p.y>790&&p.y<920&&(mode==='desktop'?p.x<350:p.x>3100)){window=w;point=p;break;}}
 expect(point).toBeTruthy();
 const context=await browser.newContext(mode==='mobile'?{...devices['Pixel 7']}:{viewport:{width:1440,height:900}}),page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(String(e)));
 await page.clock.setFixedTime(new Date(window*420000+1000));
 const state={total:0,target:10000000,tiers:0,streak:0,tz:'America/Los_Angeles'},failRpcs=['grab_chair'];
 const fixture=await installGameFixture(page,{officeState:state,failRpcs,onGrabChair:p=>{
  p.grabs=(p.grabs||0)+1;p.frenzy_until=new Date(window*420000+78000).toISOString();state.chair={window,by:p.name,mine:true};
 }});
 await page.goto('http://127.0.0.1:8765/');await expect(page.locator('.pg-stage')).toBeVisible({timeout:15000});
 const chair=page.getByRole('button',{name:'Grab the good chair',exact:true}),actor=page.locator('.pg-me:not(.pg-wes)');
 expect(await chair.evaluate(el=>({x:parseFloat(el.style.left),y:parseFloat(el.style.top)}))).toEqual({x:point.x,y:point.y});
 async function walk(axis,target){const initial=await actor.evaluate((el,k)=>parseFloat(el.style[k]),axis);if(Math.abs(initial-target)<20)return;const key=axis==='left'?(initial<target?'ArrowRight':'ArrowLeft'):(initial<target?'ArrowDown':'ArrowUp');
  try{await page.keyboard.down(key);await expect.poll(()=>actor.evaluate((el,k)=>parseFloat(el.style[k]),axis),{timeout:20000,intervals:[50]})[initial<target?'toBeGreaterThan':'toBeLessThan'](target);}finally{await page.keyboard.up(key);}}
 // A far click routes toward the chair without sending an RPC.
 const far=await chair.boundingBox();if(far&&far.x>0&&far.x+far.width<1440){await page.mouse.click(far.x+far.width/2,far.y+far.height/2);expect(fixture.calls.some(c=>c.rpc==='grab_chair')).toBe(false);}
 await walk('left',point.x+(mode==='desktop'?100:-60));await walk('top',point.y+60);
 await expect(chair).toBeInViewport();await page.screenshot({path:'test-results/'+mode+'-distant-good-chair.png',fullPage:true});
 const box=await chair.boundingBox();if(mode==='mobile')await page.touchscreen.tap(box.x+box.width/2,box.y+box.height/2);else await page.mouse.click(box.x+box.width/2,box.y+box.height/2);
 await expect.poll(()=>fixture.calls.filter(c=>c.rpc==='grab_chair').length).toBe(1);await expect(page.getByText('Error: Fixture request declined',{exact:true})).toBeVisible();
 expect(fixture.player.grabs).toBeUndefined();await expect(chair).toBeVisible();
 failRpcs.length=0;
 const retry=await chair.boundingBox();if(mode==='mobile')await page.touchscreen.tap(retry.x+retry.width/2,retry.y+retry.height/2);else await page.mouse.click(retry.x+retry.width/2,retry.y+retry.height/2);
 await expect.poll(()=>fixture.player.grabs).toBe(1);await expect(chair).toHaveCount(0);await expect(page.locator('.pg-jam.done')).toContainText('You got the good chair.');
 expect(fixture.player.pp).toBe(500000);expect(fixture.player.equity).toBe(2);expect(fixture.player.owned.intern).toBe(2);expect(errors).toEqual([]);
 await context.close();
});
