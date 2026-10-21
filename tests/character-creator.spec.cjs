const {test,expect}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
const heads=[['Office original','classic'],['Round face','round'],['Square jaw','square'],['Big cheeks','pear'],['Alien intern','alien'],['Auto employee','robot'],['Cyclops','cyclops'],['Frog accountant','frog'],['Paper bag','bag']];
for(const viewport of [{width:1440,height:900},{width:390,height:844}]){
 test(viewport.width+': creator visibly changes every head and body style without changing other choices',async({browser})=>{
  const context=await browser.newContext({viewport,reducedMotion:'reduce'}),page=await context.newPage();
  await page.goto('http://127.0.0.1:8765/?art-preview=1');
  const creator=page.getByTestId('onboard-qa'),preview=creator.locator('.pg-avatar-preview');
  await expect(preview).toBeVisible();
  const shapes=[];
  for(const build of ['slim','regular','broad']){
   await creator.getByLabel('Build',{exact:true}).selectOption(build);
   for(const style of ['neutral','masculine','feminine']){
    await creator.getByLabel('Body style',{exact:true}).selectOption(style);
    shapes.push(await preview.locator('.pg-body-outline').getAttribute('d'));
   }
  }
  expect(new Set(shapes).size).toBe(9);
  await creator.getByLabel('Hair',{exact:true}).selectOption('bun');
  await creator.getByLabel('Expression',{exact:true}).selectOption('happy');
  const outlines=[];
  for(const [label,id] of heads){
   await creator.getByRole('button',{name:label,exact:true}).click();
   await expect(creator.getByRole('button',{name:label,exact:true})).toHaveAttribute('aria-pressed','true');
   await expect(preview.locator('[data-head]')).toHaveAttribute('data-head',id);
   outlines.push(await preview.locator('.pg-head-outline').getAttribute('d'));
   await expect(creator.getByLabel('Build',{exact:true})).toHaveValue('broad');
   await expect(creator.getByLabel('Expression',{exact:true})).toHaveValue('happy');
  }
  expect(new Set(outlines).size).toBe(heads.length);
  await creator.getByRole('button',{name:'Office original',exact:true}).click();
  await expect(creator.getByLabel('Hair',{exact:true})).toHaveValue('bun');
  await creator.getByRole('button',{name:'Pants color 3',exact:true}).click();
  await expect(creator.getByRole('button',{name:'Pants color 3',exact:true})).toHaveAttribute('aria-pressed','true');
  await creator.locator('.pg-head-picker').screenshot({path:'test-results/heads-'+viewport.width+'.png'});
  await preview.screenshot({path:'test-results/body-style-'+viewport.width+'.png'});
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2)).toBe(true);
  await context.close();
 });
}
