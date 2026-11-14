const {test,expect}=require('@playwright/test');
const {installGameFixture,openOwnDesk}=require('./game-fixture.cjs');
for(const viewport of [{width:390,height:640},{width:390,height:844},{width:844,height:390}])test(`nearby desk ${viewport.width}x${viewport.height}: one touch opens, dragging does not`,async({browser})=>{
 const ctx=await browser.newContext({viewport,hasTouch:true,reducedMotion:'reduce'}),page=await ctx.newPage(),f=await installGameFixture(page);
 await page.goto('http://127.0.0.1:8765/');await expect(page.locator('.pg-stage')).toBeVisible();await openOwnDesk(page);await page.locator('.pg-panel .pg-x').click();
 const desk=page.locator('.pg-officedesk.mine');await desk.tap();await expect(page.locator('.pg-panelhead')).toContainText('Your desk');
 await expect(page.locator('.pg-prompt .pg-open')).toHaveCount(0);await page.locator('.pg-panel .pg-x').click();
 await page.evaluate(()=>{window.tapEvents=[];for(const type of ['pointerdown','pointerup','pointercancel','click'])document.addEventListener(type,e=>window.tapEvents.push({type,primary:e.isPrimary,pointer:e.pointerType,detail:e.detail,target:e.target.closest('.pg-officedesk,.pg-me,.pg-room')?.className}),true);});
 const b=await desk.boundingBox(),cdp=await ctx.newCDPSession(page),x=b.x+b.width/2,y=b.y+b.height/2;
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y}]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:x+40,y:y+12}]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 await expect(page.locator('.pg-panel')).toHaveCount(0);await expect(page.locator('.pg-destination')).toHaveCount(0);
 await desk.tap();try{await expect(page.locator('.pg-panelhead')).toContainText('Your desk');}catch(e){console.log('TOUCH_DIAGNOSTICS',JSON.stringify(await page.evaluate(()=>({events:window.tapEvents,prompt:document.querySelector('.pg-prompt')?.textContent,actor:document.querySelector('.pg-me')?.getAttribute('style')}))));throw e;}
 expect(f.calls.filter(c=>['do_deed','buy_item','grab_chair','do_work'].includes(c.rpc))).toHaveLength(0);
 expect(f.player.pp).toBe(500000);expect(f.player.equity).toBe(2);expect(f.player.owned.intern).toBe(2);await ctx.close();
});
