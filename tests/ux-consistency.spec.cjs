const {test,expect}=require('@playwright/test');
const {installGameFixture,openOwnDesk}=require('./game-fixture.cjs');
const base='http://127.0.0.1:8765/';
test('invite service failure keeps digits and retries instead of blaming the code',async({page})=>{
 let checks=0;
 await page.route('https://wbakpxbvqxppqbrwuokp.supabase.co/**',async route=>{
  if(route.request().url().endsWith('/check_code')){checks++;await route.fulfill({status:checks===1?503:200,contentType:'application/json',body:checks===1?JSON.stringify({message:'Service offline'}):'false'});}
  else await route.fulfill({status:200,contentType:'application/json',body:'null'});
 });
 await page.goto(base);const code=page.getByLabel('Invite code',{exact:true});await expect(code).toBeVisible();
 await code.fill('1234');await expect(page.getByRole('status')).toContainText('Could not reach the office');
 await expect(code).toHaveValue('1234');await page.getByRole('button',{name:'Retry office code',exact:true}).click();
 await expect(page.getByRole('status')).toContainText("That's not it");await expect(code).toHaveValue('');expect(checks).toBe(2);
});
for(const viewport of [{width:1440,height:900},{width:390,height:844},{width:844,height:390}])test('restructure confirmation '+viewport.width+' cancels safely and retains focus',async({browser})=>{
 const ctx=await browser.newContext({viewport,hasTouch:viewport.width<1000,reducedMotion:'reduce'}),page=await ctx.newPage();
 const f=await installGameFixture(page,{handleRpc:async name=>name==='restructure'?{status:503,body:{message:'HR connection unavailable'}}:undefined});f.player.cycle=1e15;
 await page.goto(base);await expect(page.locator('.pg-stage')).toBeVisible();await openOwnDesk(page);
 await page.getByRole('button',{name:'Seniority',exact:true}).click();
 const action=page.getByRole('button',{name:'Restructure the department',exact:true});await action.click();
 const dialog=page.getByRole('dialog',{name:'Confirm department restructure',exact:true});
 await expect(dialog).toBeVisible();await expect(dialog).toContainText('Lifetime progress and existing Seniority survive');
 await page.screenshot({path:'test-results/ux-confirm-'+viewport.width+'.png'});
 await dialog.getByRole('button',{name:'Cancel · keep my department',exact:true}).click();await expect(dialog).toHaveCount(0);
 await expect(action).toBeFocused();expect(f.calls.some(c=>c.rpc==='restructure')).toBe(false);
 await action.click();await dialog.getByRole('button',{name:'Confirm restructure',exact:true}).click();await expect(dialog.getByRole('alert')).toContainText('HR connection unavailable');
 expect(f.player.pp).toBe(500000);expect(f.calls.filter(c=>c.rpc==='restructure')).toHaveLength(1);await dialog.getByRole('button',{name:'Cancel · keep my department',exact:true}).click();await expect(action).toBeFocused();await ctx.close();
});
