const {test,expect}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
const base=process.env.PROFILE_BASE_URL||'http://127.0.0.1:8765';
const root='https://wbakpxbvqxppqbrwuokp.supabase.co';
const key='sb-wbakpxbvqxppqbrwuokp-auth-token';
async function missing(route){await route.fulfill({status:403,contentType:'application/json',body:JSON.stringify({code:'user_not_found',error_code:'user_not_found',message:'User from sub claim in JWT does not exist'})});}
async function setup(page){
 const f=await installGameFixture(page);
 await page.addInitScript(()=>{localStorage.setItem('ih_code','fixture-office');localStorage.setItem('ih_sound_level','0.22');});
 await page.route(root+'/rest/v1/rpc/check_code',r=>r.fulfill({json:true}));
 await page.route(root+'/auth/v1/logout**',r=>r.fulfill({status:204}));
 return f;
}
for(const width of [1440,390]){
 test(width+': deleted cached account is cleared and fresh intake uses the new Auth identity',async({browser})=>{
  const context=await browser.newContext({viewport:{width,height:900}}),page=await context.newPage(),f=await setup(page);
  let deleted=true,created=false,signups=0;const next='00000000-0000-4000-8000-000000000002';
  await page.route(root+'/auth/v1/user',async r=>deleted?missing(r):r.fallback());
  await page.route(root+'/rest/v1/players**',async r=>!created&&new URL(r.request().url()).searchParams.has('id')?r.fulfill({json:null}):r.fallback());
  await page.route(root+'/auth/v1/signup',async r=>{
   signups++;deleted=false;f.player.id=next;
   const exp=Math.floor(Date.now()/1000)+3600;
   const token=Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url')+'.'+Buffer.from(JSON.stringify({sub:next,role:'authenticated',exp})).toString('base64url')+'.fixture';
   await r.fulfill({json:{access_token:token,refresh_token:'new-fixture',expires_at:exp,expires_in:3600,token_type:'bearer',user:{id:next,is_anonymous:true,aud:'authenticated',role:'authenticated'}}});
  });
  await page.route(root+'/rest/v1/rpc/upsert_player',async r=>{
   const token=r.request().headers().authorization.split(' ')[1];expect(JSON.parse(Buffer.from(token.split('.')[1],'base64url')).sub).toBe(next);created=true;await r.fallback();
  });
  await page.goto(base);const start=page.getByRole('button',{name:"I'm new — badge in",exact:true});await expect(start).toBeVisible();
  expect(await page.evaluate(k=>localStorage.getItem(k),key)).toBeNull();expect(signups).toBe(0);expect(f.calls.some(c=>c.rpc==='upsert_player')).toBe(false);
  expect(await page.evaluate(()=>localStorage.getItem('ih_sound_level'))).toBe('0.22');
  await start.click();await expect(page.getByRole('heading',{name:'Badge in',exact:true})).toBeVisible();await page.getByPlaceholder('e.g. Dana R.').fill('Fresh Hire');await page.getByRole('button',{name:'Start the shift',exact:true}).click();
  await expect.poll(()=>created).toBe(true);await expect(page.getByText('Before you generate Busywork',{exact:true})).toBeVisible();expect(f.calls.some(c=>c.rpc==='set_look')).toBe(true);await expect(page.getByText("Couldn't badge in",{exact:false})).toHaveCount(0);expect(signups).toBe(1);
  await page.screenshot({path:`test-results/deleted-session-fresh-${width}.png`,fullPage:true});await context.close();
 });
 test(width+': deletion while intake is open returns to sign-in without an invalid player write',async({browser})=>{
  const context=await browser.newContext({viewport:{width,height:900}}),page=await context.newPage(),f=await setup(page);let deleted=false;
  await page.route(root+'/auth/v1/user',r=>deleted?missing(r):r.fallback());
  await page.route(root+'/rest/v1/players**',r=>new URL(r.request().url()).searchParams.has('id')?r.fulfill({json:null}):r.fallback());
  await page.goto(base);await expect(page.getByRole('heading',{name:'Badge in',exact:true})).toBeVisible();deleted=true;
  await page.getByPlaceholder('e.g. Dana R.').fill('Late Hire');await page.getByRole('button',{name:'Start the shift',exact:true}).click();
  await expect(page.getByRole('status')).toContainText('Your old badge is no longer active');expect(f.calls.some(c=>c.rpc==='upsert_player')).toBe(false);expect(await page.evaluate(k=>localStorage.getItem(k),key)).toBeNull();await context.close();
 });
}
test('foreign-key race verifies deletion before clearing the stale session',async({page})=>{
 await setup(page);let deleted=false,writes=0;
 await page.route(root+'/auth/v1/user',r=>deleted?missing(r):r.fallback());
 await page.route(root+'/rest/v1/players**',r=>new URL(r.request().url()).searchParams.has('id')?r.fulfill({json:null}):r.fallback());
 await page.route(root+'/rest/v1/rpc/upsert_player',async r=>{writes++;deleted=true;await r.fulfill({status:409,json:{code:'23503',message:'insert or update on table "players" violates foreign key constraint "players_id_fkey"'}});});
 await page.goto(base);await expect(page.getByRole('heading',{name:'Badge in',exact:true})).toBeVisible();await page.getByPlaceholder('e.g. Dana R.').fill('Race Hire');await page.getByRole('button',{name:'Start the shift',exact:true}).click();
 await expect(page.getByRole('status')).toContainText('Your old badge is no longer active');expect(writes).toBe(1);expect(await page.evaluate(k=>localStorage.getItem(k),key)).toBeNull();
});
test('temporary Auth failure preserves the saved session and retry returns to the same desk',async({page})=>{
 const f=await setup(page);let unavailable=true,logouts=0;
 await page.route(root+'/auth/v1/user',r=>unavailable?r.fulfill({status:502,json:{message:'Temporary Auth outage'}}):r.fallback());
 await page.route(root+'/auth/v1/logout**',async r=>{logouts++;await r.fulfill({status:204});});
 await page.goto(base);await expect(page.getByText("Couldn't check your sign-in. Check your connection and try again.",{exact:true})).toBeVisible();
 expect(await page.evaluate(k=>localStorage.getItem(k),key)).not.toBeNull();expect(logouts).toBe(0);unavailable=false;
 await page.getByRole('button',{name:'Try again',exact:true}).click();await expect(page.locator('.pg-hudname')).toHaveText(f.player.name);expect(logouts).toBe(0);
});
