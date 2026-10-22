const {test,expect}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');const path=require('node:path');
const base=process.env.PROFILE_BASE_URL||'http://127.0.0.1:8765',photo=path.join(__dirname,'fixtures/custom-face.png');
async function openDesk(page){await page.getByRole('button',{name:'Office directory',exact:true}).click();await page.getByRole('button',{name:'Walk to Your desk',exact:true}).click();await expect(page.locator('.pg-panelhead')).toContainText('Your desk',{timeout:20000});}
async function openMirror(page){await page.getByRole('button',{name:'Office directory',exact:true}).click();await page.getByRole('button',{name:'Walk to The Mirror',exact:true}).click();await expect(page.locator('.pg-panelhead')).toContainText(/The mirror/i,{timeout:20000});}
for(const viewport of [{width:1440,height:900},{width:390,height:844},{width:844,height:390}]){
 test(viewport.width+': repeated fixed-coordinate purchases never move the target when receipts arrive or expire',async({browser})=>{
  test.setTimeout(70000);const context=await browser.newContext({viewport,reducedMotion:'reduce'}),page=await context.newPage();
  const f=await installGameFixture(page,{items:[{id:'intern',name:'Office Intern',cost:100,rate:1,note:'A deliberately long explanation that wraps to multiple lines without moving neighboring purchase targets.'},{id:'poster',name:'Motivational Poster',cost:100,rate:1,note:'Do not accidentally buy this.'}],upgrades:[{id:'up1',name:'An extremely official productivity improvement',cost:100,mult:2,t:'all',req:['intern',0],note:'Keep this row still after approval.'},{id:'up2',name:'Second approval',cost:100,mult:2,t:'all',req:['intern',0],note:'Do not accidentally approve this.'}]});
  await page.goto(base);await expect(page.locator('.pg-stage')).toBeVisible();await openDesk(page);
  const row=page.getByRole('button',{name:/Office Intern/}),other=page.getByRole('button',{name:/Motivational Poster/});
  const before=await row.boundingBox(),next=await other.boundingBox();await page.clock.install();
  for(let i=0;i<5;i++){await page.mouse.click(before.x+before.width/2,before.y+before.height/2);await expect.poll(()=>f.player.owned.intern).toBe(3+i);const after=await row.boundingBox();expect(Math.abs(after.y-before.y)).toBeLessThan(1);expect(Math.abs((await other.boundingBox()).y-next.y)).toBeLessThan(1);await page.clock.fastForward(i%2?2600:300);}
  await expect(page.locator('.pg-panel-receipt')).toHaveCount(1);expect(f.player.owned.poster||0).toBe(0);
  const body=await page.locator('.pg-panelbody').boundingBox();await page.locator('.pg-panel').getByRole('button',{name:'Approvals',exact:true}).click();
  const upgrade=page.getByRole('button',{name:/An extremely official/}),uBefore=await upgrade.boundingBox();await upgrade.click();await expect(upgrade).toBeDisabled();await expect.poll(()=>f.player.upgrades.includes('up1')).toBe(true);await page.clock.fastForward(2600);
  expect(Math.abs((await upgrade.boundingBox()).y-uBefore.y)).toBeLessThan(1);expect(Math.abs((await page.locator('.pg-panelbody').boundingBox()).y-body.y)).toBeLessThan(1);expect(f.player.upgrades).not.toContain('up2');
  await page.screenshot({path:`test-results/stable-purchases-${viewport.width}.png`,fullPage:true});await context.close();
 });
}
for(const viewport of [{width:1440,height:900},{width:390,height:844}]){
 test(viewport.width+': photo upload previews and persists on HUD/world/reload, then switches back to an illustration',async({browser})=>{
  test.setTimeout(90000);const context=await browser.newContext({viewport,reducedMotion:'reduce'}),page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(String(e)));
  const failures=['badge_upload'],f=await installGameFixture(page,{failRpcs:failures});const snapshot={pp:f.player.pp,equity:f.player.equity,owned:{...f.player.owned},wardrobe:[...f.player.wardrobe_owned]};
  await page.goto(base);await expect(page.locator('.pg-stage')).toBeVisible();await openMirror(page);const dialog=page.getByRole('dialog');
  const tile=dialog.getByRole('button',{name:'Custom photo',exact:true});await expect(tile).toBeVisible();
  expect(await tile.evaluate(el=>!!el.closest('.pg-head-picker'))).toBe(true);
  await dialog.getByLabel('Upload custom face',{exact:true}).setInputFiles(photo);await expect(tile).toHaveAttribute('aria-pressed','true');await expect(dialog.getByLabel('Eyes',{exact:true})).toHaveCount(0);await expect(dialog.getByLabel('Body style',{exact:true})).toBeVisible();
  await expect(dialog.locator('.pg-mirrorrow .pg-preview').last().locator('[data-head="photo"] img')).toBeVisible();
  await expect(dialog.getByRole('button',{name:'Legacy photo (optional)',exact:true})).toHaveCount(0);
  await dialog.getByRole('button',{name:'Reissue the badge',exact:true}).click();await expect(dialog.getByRole('alert')).toContainText('Fixture upload declined');expect(f.player.look.head||'classic').toBe('classic');expect(f.uploads).toHaveLength(0);
  failures.length=0;await dialog.getByRole('button',{name:'Reissue the badge',exact:true}).click();await expect(dialog).toHaveCount(0);expect(f.uploads).toHaveLength(1);expect(f.uploads[0].body.includes(Buffer.from([255,216,255]))).toBe(true);
  expect(f.player.look.head).toBe('photo');expect(f.player.avatar_url).toContain('/storage/v1/object/public/badges/');
  await expect(page.locator('.pg-hud [data-head="photo"] img')).toBeVisible();await expect(page.locator('.pg-body.me [data-head="photo"] img')).toBeVisible();
  await page.reload();await expect(page.locator('.pg-hud [data-head="photo"] img')).toBeVisible();
  await page.screenshot({path:`test-results/custom-face-world-${viewport.width}.png`,fullPage:true});
  await openMirror(page);await expect(tile).toHaveAttribute('aria-pressed','true');await dialog.getByRole('button',{name:'Paper bag',exact:true}).click();await dialog.getByRole('button',{name:'Reissue the badge',exact:true}).click();await expect(dialog).toHaveCount(0);
  await expect(page.locator('.pg-body.me [data-head]')).toHaveAttribute('data-head','bag');expect(f.player.avatar_url).toBeTruthy();
  await openMirror(page);await tile.click();await dialog.getByRole('button',{name:'Reissue the badge',exact:true}).click();await expect(dialog).toHaveCount(0);await expect(page.locator('.pg-body.me [data-head="photo"] img')).toBeVisible();expect(f.uploads).toHaveLength(1);
  expect({pp:f.player.pp,equity:f.player.equity,owned:f.player.owned,wardrobe:f.player.wardrobe_owned}).toEqual(snapshot);expect(errors).toEqual([]);await context.close();
 });
}
test('photo input rejects invalid/undecodable images, supports retry, and appears in onboarding beside heads',async({page})=>{
 await page.goto(base+'/?art-preview=1');const creator=page.getByTestId('onboard-qa');await expect(creator).toBeVisible();
 const input=creator.getByLabel('Upload custom face',{exact:true});await input.setInputFiles({name:'not-a-photo.txt',mimeType:'text/plain',buffer:Buffer.from('test')});await expect(creator.locator('.pg-err')).toContainText('Choose a JPG');
 await input.setInputFiles({name:'large.png',mimeType:'image/png',buffer:Buffer.alloc(10*1024*1024+1)});await expect(creator.locator('.pg-err')).toContainText('smaller than 10 MB');
 await input.setInputFiles({name:'broken.png',mimeType:'image/png',buffer:Buffer.from('not an image')});await expect(creator.locator('.pg-err')).toContainText('could not be opened');
 await input.setInputFiles(photo);await expect(creator.getByRole('button',{name:'Custom photo',exact:true})).toHaveAttribute('aria-pressed','true');await expect(creator.locator('.pg-avatar-preview [data-head="photo"] img')).toBeVisible();await expect(creator.locator('.pg-err')).toHaveCount(0);
 await creator.screenshot({path:'test-results/custom-face-onboarding.png'});
});
