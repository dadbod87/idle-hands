const {test,expect,devices}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
for(const mode of ['desktop','mobile'])test(mode+': lived-in scenery preserves real destinations and player progress',async({browser})=>{
 test.setTimeout(90000);
 const context=await browser.newContext(mode==='mobile'?{...devices['Pixel 7']}:{viewport:{width:1440,height:900}}),page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(String(e)));const fixture=await installGameFixture(page);
 await page.goto('http://127.0.0.1:8765/');await expect(page.locator('.pg-stage')).toBeVisible();
 await expect(page.locator('.pg-room [data-zone]')).toHaveCount(3);await expect(page.locator('.pg-room [data-scenery]')).toHaveCount(7);
 expect(await page.locator('.pg-room .pg-scenery:not(button)').evaluateAll(els=>els.every(el=>getComputedStyle(el).pointerEvents==='none'))).toBe(true);
 const actor=page.locator('.pg-me:not(.pg-wes)');
 async function walkAxis(axis,target){
  const initial=await actor.evaluate((el,axis)=>parseFloat(el.style[axis]),axis);
  if(Math.abs(initial-target)<20)return;
  const key=axis==='left'?(initial<target?'ArrowRight':'ArrowLeft'):(initial<target?'ArrowDown':'ArrowUp');
  await expect.poll(async()=>{await page.keyboard.down(key);return actor.evaluate((el,axis)=>parseFloat(el.style[axis]),axis);},{timeout:15000,intervals:[50]} )[initial<target?'toBeGreaterThan':'toBeLessThan'](target);
  await page.keyboard.up(key);
 }
 for(const [destination,label,copy] of [["Dave's Office","Check the calendar","Management's meeting calendar"],["The Printer","Read the printer apology","Facilities posted this beside the printer"]]){
  await page.getByRole('button',{name:'Office directory',exact:true}).click();
  await page.getByRole('button',{name:'Walk to '+destination,exact:true}).click();
  await expect(page.locator('.pg-panelhead')).toBeVisible({timeout:20000});
  await page.locator('.pg-panel .pg-x').click();
  const prop=page.locator('.pg-room').getByRole('button',{name:label,exact:true});
  await expect(prop).toBeInViewport();
  if(mode==='mobile')await prop.tap();else {await prop.focus();await page.keyboard.press('Enter');}
  await expect(page.getByRole('dialog',{name:label,exact:true})).toBeVisible();
  await expect(page.getByTestId('prop-inspection')).toContainText(copy);
  await page.screenshot({path:'test-results/'+mode+'-'+(destination==='The Printer'?'printer-note':'calendar')+'.png',fullPage:true});
  await page.keyboard.press('Escape');await expect(prop).toBeFocused();
  if(destination==='The Printer'){
   const printer=page.locator('.pg-room .pg-fx').filter({hasText:'The Printer'}),label=printer.locator('.pg-fxlabel');
   const paperBox=await prop.boundingBox(),printerBox=await printer.boundingBox();expect(paperBox.width).toBeLessThan(printerBox.width*.6);expect(paperBox.height).toBeLessThan(printerBox.height);
   const overlap=await label.evaluate(el=>{const a=el.getBoundingClientRect();return [...document.querySelectorAll('.pg-room .pg-decor.pg-plant')].some(p=>{const b=p.getBoundingClientRect();return a.left<b.right&&a.right>b.left&&a.top<b.bottom&&a.bottom>b.top;});});expect(overlap).toBe(false);
   await page.screenshot({path:'test-results/'+mode+'-world-printer-scale.png',fullPage:true});
   await walkAxis('left',2633);await page.screenshot({path:'test-results/'+mode+'-world-water-cooler.png',fullPage:true});
  }
 }
 await page.getByRole('button',{name:'Office directory',exact:true}).click();await page.getByRole('button',{name:'Walk to The Break Table',exact:true}).click();
 await expect(page.locator('.pg-panelhead')).toContainText('Break room',{timeout:20000});await page.locator('.pg-panel .pg-x').click();
 await page.screenshot({path:'test-results/'+mode+'-lived-in-breakroom.png',fullPage:true}); // All seven substantial scenery props now answer a click, including the two plants.
 await expect(page.locator('.pg-room button[data-scenery]')).toHaveCount(7);

 for(const [x,y,id,label] of [[850,1110,'bench','Take a minute on the couch'],[1000,700,'break-notice','Read the break room notice'],[1930,1170,'office-shelf','Browse Misc. Urgent']]){
  await walkAxis('left',x);await walkAxis('top',y);
  const prop=page.locator('.pg-room [data-scenery="'+id+'"]');await expect(prop).toBeInViewport();
  if(mode==='mobile')await prop.tap();else await prop.click();
  await expect(page.getByRole('dialog',{name:label,exact:true})).toBeVisible();
  await expect(page.getByTestId('prop-inspection').locator('.pg-note')).not.toBeEmpty();
  await page.screenshot({path:'test-results/'+mode+'-'+id+'-reading.png',fullPage:true});
  if(id!=='office-shelf')await expect(page.getByRole('button',{name:'Head to the break table',exact:true})).toBeVisible();
  await page.keyboard.press('Escape');await expect(prop).toBeFocused();
 }
 // The couch's useful exit follows the existing walk route and opens real break activities.
 await walkAxis('left',850);await walkAxis('top',1110);
 await page.locator('.pg-room [data-scenery="bench"]').click();await page.getByRole('button',{name:'Head to the break table',exact:true}).click();
 await expect(page.locator('.pg-panelhead')).toContainText('Break room',{timeout:20000});await page.locator('.pg-panel .pg-x').click();

 await page.getByTitle('Wave',{exact:true}).click();await expect(page.locator('.pg-room .pg-body.me')).toHaveClass(/em-wave/);
 expect(fixture.player.pp).toBe(500000);expect(fixture.player.equity).toBe(2);expect(fixture.player.kit.desk).toBe('d3');
 expect(fixture.calls.some(x=>['buy_item','buy_fitting','do_deed','set_look'].includes(x.rpc))).toBe(false);
 expect(errors).toEqual([]);expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2)).toBe(true);
 await page.goto('http://127.0.0.1:8765/?art-preview=1');await expect(page.getByTestId('environment-qa').locator('svg')).toHaveCount(6);
 await page.getByTestId('environment-qa').screenshot({path:'test-results/'+mode+'-environment-art.png'});
 await context.close();
});
