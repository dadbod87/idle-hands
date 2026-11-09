const {test,expect}=require('@playwright/test'),{installStyleFixture}=require('./style-fixture.cjs'),{openOwnDesk}=require('./game-fixture.cjs');
const base=process.env.STYLE_BASE_URL||'http://127.0.0.1:8765/';
for(const width of [1440,390])test(`${width}: every rug keeps its identity across all custom finishes and on the floor`,async({browser})=>{
 test.setTimeout(180000);const ctx=await browser.newContext({viewport:{width,height:900},reducedMotion:'reduce'}),page=await ctx.newPage(),f=await installStyleFixture(page);f.player.kit.rug='r4';const before=f.player.pp;
 const designs=['Solid','Stripes','Checker','Polka dots','Sparkle','Confetti'];const counts=[0,4,2,9];
 for(let n=1;n<=4;n++){
  await page.goto(base);await expect(page.locator('.pg-stage')).toBeVisible();await openOwnDesk(page);await page.getByRole('button',{name:'Catalogue',exact:true}).click();await page.getByRole('button',{name:'Customize owned items',exact:true}).click();const editor=page.getByTestId('style-editor');await editor.getByLabel('Customize owned item',{exact:true}).selectOption('r'+n);
  const preview=editor.locator('.pg-style-preview [data-rug-tier]'),motif=preview.locator('[data-rug-motif]');await expect(motif.locator('path')).toHaveCount(counts[n-1]);const signature=await motif.locator('path').evaluateAll(nodes=>nodes.map(x=>x.getAttribute('d')));
  for(const color of ['Hot pink','Forest green']){await editor.getByRole('button',{name:color,exact:true}).click();for(const design of designs){await editor.getByRole('button',{name:design,exact:true}).click();expect(await motif.locator('path').evaluateAll(nodes=>nodes.map(x=>x.getAttribute('d')))).toEqual(signature);if(n>1)await expect(motif.locator('path').first()).toHaveAttribute('stroke',color==='Hot pink'?'#4C5145':'#F4E8CD');await expect(preview.locator(':scope > path').first()).toHaveAttribute('fill',design==='Solid'?(color==='Hot pink'?'#ff55b0':'#43634b'):/^url\(#material-/);}}
  await preview.screenshot({path:`test-results/rug-preview-${width}-r${n}.png`});
  // Existing saved finish fixture: reload must retain tier identity without a new payment.
  f.player.cosmetic_equipped.rug='r'+n;f.player.cosmetic_styles['r'+n]={color:'#ff55b0',design:'sparkle'};await page.reload();await expect(page.locator('.pg-stage')).toBeVisible();await openOwnDesk(page);await page.locator('.pg-panel .pg-x').click();const world=page.locator('.pg-officedesk.mine').locator('xpath=..').locator('[data-rug-tier="r'+n+'"]');await expect(world).toHaveCount(1);expect(await world.locator('[data-rug-motif] path').evaluateAll(nodes=>nodes.map(x=>x.getAttribute('d')))).toEqual(signature);await page.screenshot({path:`test-results/rug-world-${width}-r${n}.png`,fullPage:true});
 }
 expect(f.player.pp).toBe(before);expect(f.calls.some(x=>['quote_style','apply_style','buy_fitting'].includes(x.rpc))).toBe(false);await ctx.close();
});
