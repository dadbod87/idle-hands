const {test,expect}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
const base=process.env.PROFILE_BASE_URL||'http://127.0.0.1:8765';
const root='https://wbakpxbvqxppqbrwuokp.supabase.co/rest/v1/rpc/';
async function setup(page,{balance=10000,cost=720,mine=false,paid=false}={}){
 const f=await installGameFixture(page);f.player.pp=balance;
 const card={week:'fixture-week',signers:mine?[f.player.id]:[],pot:0,paid,staff:4,mine,contribution:cost};
 await page.route(root+'card_state',r=>r.fulfill({json:card}));
 await page.goto(base);await expect(page.locator('.pg-stage')).toBeVisible();
 await page.getByRole('button',{name:'Office directory',exact:true}).click();await page.getByRole('button',{name:'Walk to Vending Machine',exact:true}).click();
 await expect(page.locator('.pg-panelhead')).toContainText('Office fund',{timeout:25000});
 const button=page.locator('.pg-panel').getByRole('button',{name:/Sign the card|Not enough Busywork|Already done|You signed it/});
 await button.scrollIntoViewIfNeeded();
 return {f,card,button};
}
for(const [mode,viewport] of [['desktop',{width:1440,height:900}],['phone',{width:390,height:844}],['short',{width:844,height:390}]]){
 test(mode+': insufficient funds show cost; successful signing is visible and survives reload',async({browser})=>{
  const context=await browser.newContext({viewport}),page=await context.newPage();
  const {f,card,button}=await setup(page,{balance:100,cost:720});let writes=0;
  await expect(button).toBeDisabled();await expect(page.locator('#card-contribution')).toContainText('720 BW');await expect(page.locator('#card-contribution')).toContainText('more BW');
  f.player.pp=10000;await page.reload();await expect(page.locator('.pg-stage')).toBeVisible();await page.getByRole('button',{name:'Office directory',exact:true}).click();await page.getByRole('button',{name:'Walk to Vending Machine',exact:true}).click();await expect(page.locator('.pg-panelhead')).toContainText('Office fund',{timeout:25000});
  await page.route(root+'sign_card',async r=>{writes++;await new Promise(resolve=>setTimeout(resolve,600));card.mine=true;card.signers=[f.player.id];card.pot=720;f.player.pp-=720;await r.fulfill({json:card});});
  const sign=page.getByRole('button',{name:'Sign the card',exact:true});await sign.scrollIntoViewIfNeeded();await sign.focus();await page.keyboard.press('Enter');await expect(page.getByRole('button',{name:'Signing…',exact:true})).toBeDisabled();await expect(page.locator('#card-feedback')).toContainText('Your contribution is in the pot');await expect(page.getByRole('button',{name:'You signed it',exact:true})).toBeDisabled();expect(writes).toBe(1);expect(card.signers.length).toBe(1);expect(f.player.pp).toBe(9280);
  await page.screenshot({path:`test-results/card-signed-${mode}.png`,fullPage:true});
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
  await page.reload();await expect(page.locator('.pg-stage')).toBeVisible();await page.getByRole('button',{name:'Office directory',exact:true}).click();await page.getByRole('button',{name:'Walk to Vending Machine',exact:true}).click();await expect(page.getByRole('button',{name:'You signed it',exact:true})).toBeDisabled();expect(writes).toBe(1);await context.close();
 });
}
test('server rejection stays beside the card, retry succeeds and the final signature shows cake',async({page})=>{
 const {f,card,button}=await setup(page);let writes=0;
 await page.route(root+'sign_card',async r=>{writes++;if(writes===1)return r.fulfill({status:400,json:{message:'cannot afford',code:'P0001'}});card.mine=true;card.paid=true;card.signers=[f.player.id,'two','three','four'];await r.fulfill({json:card});});
 await button.click();await expect(page.locator('#card-feedback')).toHaveText('Not enough Busywork.');await expect(button).toBeEnabled();await expect(page.locator('#card-feedback')).toBeInViewport();
 await button.click();await expect(page.locator('#card-feedback')).toContainText('Cake for the office!');await expect(page.getByRole('button',{name:'Already done',exact:true})).toBeDisabled();expect(writes).toBe(2);
});
test('network failure can retry; a failed balance refresh does not undo a saved signature',async({page})=>{
 const {f,card,button}=await setup(page);let writes=0;
 await page.route(root+'sign_card',async r=>{writes++;if(writes===1)return r.abort('failed');card.mine=true;card.signers=[f.player.id];await page.route(root+'sync',r=>r.abort('failed'));await r.fulfill({json:card});});
 await button.click();await expect(page.locator('#card-feedback')).toContainText('Lost the connection');await button.click();await expect(page.locator('#card-feedback')).toContainText('Your contribution is in the pot');expect(writes).toBe(2);
});
test('already signed and paid cards stay disabled',async({page})=>{
 const {button}=await setup(page,{mine:true,paid:true});await expect(button).toHaveText('Already done');await expect(button).toBeDisabled();
});
