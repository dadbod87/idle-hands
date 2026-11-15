const {test,expect}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
for(const viewport of [{width:1440,height:900},{width:390,height:844},{width:844,height:390}])test(`minimap navigation ${viewport.width}: visible default, opt-in travel, doorway arrival and saved controls`,async({browser})=>{
 test.setTimeout(90000);
 const touch=viewport.width<1000,ctx=await browser.newContext({viewport,isMobile:touch,hasTouch:touch}),page=await ctx.newPage(),f=await installGameFixture(page),errors=[];
 page.on('pageerror',e=>errors.push(e.message));await page.clock.setFixedTime(new Date('2026-11-14T16:10:00Z'));
 const actor=page.locator('.pg-room .pg-body.me'),map=page.getByRole('group',{name:'Office minimap'}),target=page.getByRole('button',{name:'Choose walking destination on minimap'});
 const position=()=>actor.evaluate(el=>({x:parseFloat(el.closest('.pg-me').style.left),y:parseFloat(el.closest('.pg-me').style.top)}));
 const more=async()=>{const b=page.getByRole('button',{name:'More',exact:true});if(await b.isVisible()&&await b.getAttribute('aria-expanded')==='false')await b.click();};
 const dismissMore=async()=>{const b=page.getByRole('button',{name:'More',exact:true});if(await b.isVisible()&&await b.getAttribute('aria-expanded')==='true')await b.click();};
 const tapAt=async(x,y)=>{const r=await target.boundingBox(),px=r.x+x/3400*r.width,py=r.y+y/1700*r.height;if(touch)await page.touchscreen.tap(px,py);else await page.mouse.click(px,py);};
 await page.goto('http://127.0.0.1:8765');await expect(map).toBeVisible();await expect(target).toBeDisabled();const before=await position();await tapAt(1700,850);await page.waitForTimeout(300);expect(await position()).toEqual(before);
 await more();await page.getByRole('button',{name:'Map movement: off',exact:true}).click();await dismissMore();await expect(target).toBeEnabled();
 await tapAt(1700,850);await expect.poll(async()=>{const p=await position();return Math.hypot(p.x-1700,p.y-850);}).toBeLessThan(16);await expect(page.getByRole('dialog')).toHaveCount(0);
 // Tap the drawn office itself: map borders must not offset visual destinations.
 const office=await map.locator('.pg-mapoffice').first().boundingBox();
 if(touch)await page.touchscreen.tap(office.x+office.width/2,office.y+office.height/2);else await page.mouse.click(office.x+office.width/2,office.y+office.height/2);
 await expect.poll(async()=>{const p=await position();return Math.hypot(p.x-270,p.y-1490);},{timeout:15000}).toBeLessThan(16);await expect(page.getByRole('dialog')).toHaveCount(0);
 // A dragged or cancelled gesture cannot queue another walk.
 const rect=await target.boundingBox(),p0=await position();
 if(touch){const cdp=await ctx.newCDPSession(page);await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:rect.x+30,y:rect.y+30}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:rect.x+60,y:rect.y+30}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});}
 else{await page.mouse.move(rect.x+30,rect.y+30);await page.mouse.down();await page.mouse.move(rect.x+60,rect.y+30,{steps:3});await page.mouse.up();}
 await page.waitForTimeout(300);expect(await position()).toEqual(p0);
 // Keyboard activation deliberately walks to the office center.
 await target.focus();await page.keyboard.press('Enter');await expect.poll(async()=>{const p=await position();return Math.hypot(p.x-1700,p.y-850);},{timeout:15000}).toBeLessThan(16);
 await page.reload();await expect(map).toBeVisible();await expect(target).toBeEnabled();await more();await page.getByRole('button',{name:'Hide minimap',exact:true}).click();await page.reload();await expect(page.locator('.pg-stage')).toBeVisible();await expect(map).toHaveCount(0);await more();await page.getByRole('button',{name:'Show minimap',exact:true}).click();await page.getByRole('button',{name:'Map movement: on',exact:true}).click();await dismissMore();await expect(target).toBeDisabled();
 await page.screenshot({path:`test-results/minimap-${viewport.width}.png`,fullPage:true});
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
 expect(f.calls.filter(c=>['do_work','buy_item','office_deed','do_deed','grab_chair','office_interact'].includes(c.rpc))).toHaveLength(0);expect(f.player.pp).toBe(500000);expect(f.player.equity).toBe(2);expect(errors).toEqual([]);await ctx.close();
});
test('minimap controls work for the session when preference storage is unavailable',async({page})=>{
 await installGameFixture(page);await page.addInitScript(()=>{for(const key of ['getItem','setItem']){const original=Storage.prototype[key];Storage.prototype[key]=function(name,...rest){if(name.startsWith('ih-minimap-'))throw Error('Storage unavailable');return original.call(this,name,...rest);};}});
 await page.goto('http://127.0.0.1:8765');await expect(page.locator('.pg-map')).toBeVisible();await page.getByRole('button',{name:'Map movement: off',exact:true}).click();await expect(page.locator('.pg-map-target')).toBeEnabled();await page.getByRole('button',{name:'Hide minimap',exact:true}).click();await expect(page.locator('.pg-map')).toHaveCount(0);
});
