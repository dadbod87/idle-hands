const {test,expect,devices}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
const fittings=require('./fixtures/fittings.json');
async function openCatalogue(page){
 await page.getByRole('button',{name:/Go to your desk/}).click();
 await expect(page.getByRole('button',{name:/Do actual work/})).toBeVisible({timeout:30000});
 await page.locator('.pg-officedesk.mine').click();
 await page.getByRole('button',{name:'Catalogue',exact:true}).click();
 await page.locator('.pg-panel').getByRole('button',{name:'Your Office',exact:true}).click();
 return page.locator('[data-fitting-entry="tv1"]');
}
for(const mode of ['desktop','mobile'])test(mode+': premium TV preview, failed purchase, ownership, all four screens and reload',async({browser})=>{
 test.setTimeout(90000);
 const context=await browser.newContext({...mode==='mobile'?devices['Pixel 7']:{viewport:{width:1440,height:900}},reducedMotion:'reduce'}),page=await context.newPage();
 const failures=['buy_fitting'],f=await installGameFixture(page,{fittings,failRpcs:failures,fittingPrices:{tv1:61000000}});
 f.player.pp=80000000;f.player.kit.art='w2';
 await page.goto('http://127.0.0.1:8765/');await expect(page.locator('.pg-stage')).toBeVisible();
 await expect(page.getByTestId('office-tv')).toHaveCount(0);
 let row=await openCatalogue(page);
 await expect(row).toContainText('61.0M');
 await row.getByRole('button',{name:'Preview The Productivity Flatscreen',exact:true}).click();
 await expect(page.getByTestId('fitting-detail').locator('.pg-tv-art')).toHaveCount(1);
 expect(f.calls.some(c=>c.rpc==='buy_fitting')).toBe(false);expect(f.player.pp).toBe(80000000);
 const buy=row.locator('button.pg-row');await buy.click();
 await expect(page.locator('.pg-feedback-rail')).toContainText('Fixture request declined');
 await expect(page.getByTestId('office-tv')).toHaveCount(0);expect(f.player.pp).toBe(80000000);
 failures.pop();await buy.click();
 await expect.poll(()=>f.player.kit.tv).toBe('tv1');expect(f.player.pp).toBe(19000000);expect(f.player.kit.art).toBe('w2');expect(f.player.kit.desk).toBe('d3');
 await expect(row).toContainText('owned');await expect(buy).toBeDisabled();
 await page.keyboard.press('Escape');await expect(page.locator('.pg-room .pg-reaction')).toHaveCount(0,{timeout:5000});const tv=page.getByTestId('office-tv');await expect(tv).toBeVisible();
 const initial=Number(await tv.locator('svg').getAttribute('data-tv-screen'));
 for(let i=1;i<=4;i++){await tv.click();await expect(tv.locator('svg')).toHaveAttribute('data-tv-screen',String((initial+i)%4));}
 await page.clock.install();const frozen=await tv.locator('svg').getAttribute('data-tv-screen');await page.clock.fastForward(11000);await expect(tv.locator('svg')).toHaveAttribute('data-tv-screen',frozen);
 expect(await tv.evaluate(el=>{const r=el.getBoundingClientRect();return r.width>=44&&r.height>=44;})).toBe(true);
 const office=page.locator('.pg-office.mine');await expect(office.locator('[data-art-tier="w2"]')).toHaveCount(1);
 await tv.screenshot({path:'test-results/'+mode+'-springer-tv.png'});await page.locator('.pg-stage').screenshot({path:'test-results/'+mode+'-springer-office.png'});
 await page.reload();await expect(page.getByTestId('office-tv')).toHaveCount(1);expect(f.player.pp).toBe(19000000);
 expect(f.calls.filter(c=>c.rpc==='buy_fitting')).toHaveLength(2);
 await context.close();
});
test('premium TV cannot be bought under the server quote and gallery loads all four self-hosted stills',async({page})=>{
 const f=await installGameFixture(page,{fittings});f.player.pp=49999999;
 await page.goto('http://127.0.0.1:8765/');await expect(page.locator('.pg-stage')).toBeVisible();
 const row=await openCatalogue(page);await expect(row.locator('button.pg-row')).toBeDisabled();
 await row.getByRole('button',{name:'Preview The Productivity Flatscreen',exact:true}).click();expect(f.calls.some(c=>c.rpc==='buy_fitting')).toBe(false);
 await page.goto('http://127.0.0.1:8765/?art-preview=1');await expect(page.getByTestId('tv-qa').locator('.pg-tv-art')).toHaveCount(4);
 for(const image of await page.getByTestId('tv-qa').locator('image').all()){
  const response=await page.request.get(new URL(await image.getAttribute('href'),'http://127.0.0.1:8765/').href);expect(response.ok()).toBe(true);expect(response.headers()['content-type']).toContain('image/webp');
 }
 await page.getByTestId('tv-qa').screenshot({path:'test-results/springer-four-screens.png'});
});

test('visible TV rotates automatically and stops for reduced motion and hidden tabs',async({page})=>{
 test.setTimeout(60000);const f=await installGameFixture(page,{fittings});f.player.kit.tv='tv1';
 await page.goto('http://127.0.0.1:8765/');await expect(page.locator('.pg-stage')).toBeVisible();
 await page.getByRole('button',{name:/Go to your desk/}).click();await expect(page.getByRole('button',{name:/Do actual work/})).toBeVisible({timeout:30000});
 const tv=page.getByTestId('office-tv'),art=tv.locator('svg');await expect(tv).toBeVisible();const first=await art.getAttribute('data-tv-screen');
 await expect.poll(()=>art.getAttribute('data-tv-screen'),{timeout:12000}).not.toBe(first);
 await page.emulateMedia({reducedMotion:'reduce'});await page.clock.install();const still=await art.getAttribute('data-tv-screen');await page.clock.fastForward(21000);await expect(art).toHaveAttribute('data-tv-screen',still);
 await page.emulateMedia({reducedMotion:'no-preference'});await page.evaluate(()=>Object.defineProperty(document,'hidden',{configurable:true,get:()=>true}));await page.clock.fastForward(21000);await expect(art).toHaveAttribute('data-tv-screen',still);
 expect(f.calls.some(c=>c.rpc==='buy_fitting')).toBe(false);
});
