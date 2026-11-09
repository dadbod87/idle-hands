// Diagnostic collection only by default. Zero violations is not asserted unless strict mode is selected.
const {test,expect}=require('@playwright/test');
const AxeBuilder=require('@axe-core/playwright').default;
const fs=require('node:fs/promises');
const {installGameFixture}=require('../../tests/game-fixture.cjs');
// Only the observed read/fixture-boot calls are allowed; unknown actions fail closed.
const allowedRpcs=new Set(['all_prices','beta_testers','check_in','claim_incoming','office_play_state','office_state','save_achievements','spend_board','sync','weekly_pins','weekly_schedule','who_approves']);
for(const width of [1440,390])test.describe(`${width}px`,()=>{
 test.use({viewport:{width,height:900},isMobile:width<600,hasTouch:width<600});
 test('fixture-only accessibility and browser diagnostic audit',async({page,baseURL},info)=>{
  const origin=new URL(baseURL);
  if(origin.protocol!=='http:'||origin.hostname!=='127.0.0.1')throw Error('This audit only runs on its local fixture server');
  const errors=[],blocked=[];
  page.on('pageerror',e=>errors.push(String(e)));
  // Supabase HTTP is fulfilled by the fixture installed below; all other external requests are blocked.
  await page.route('**/*',route=>{const u=new URL(route.request().url());if(u.origin===origin.origin||['data:','blob:'].includes(u.protocol))return route.continue();blocked.push(u.origin);return route.abort();});
  await page.clock.setFixedTime(new Date('2026-10-24T12:34:00Z'));
  const fixture=await installGameFixture(page),before=JSON.stringify(fixture.player);
  const scans=[];
  const capture=async state=>{
   const result=await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21a','wcag21aa']).analyze();
   const file=info.outputPath(`${state}-axe.json`);
   await fs.writeFile(file,JSON.stringify(result,null,2));await info.attach(`${state} accessibility`,{path:file,contentType:'application/json'});
   await page.screenshot({path:info.outputPath(`${state}.png`),fullPage:true});
   scans.push({state,violations:result.violations.map(v=>({id:v.id,impact:v.impact,help:v.help,helpUrl:v.helpUrl,elements:v.nodes.length,targets:v.nodes.map(n=>n.target)})),incomplete:result.incomplete.length});
  };
  await page.goto('/');await expect(page.locator('.pg-stage')).toBeVisible();await capture('floor');
  await page.getByRole('button',{name:'How to play',exact:true}).click();await expect(page.getByRole('dialog')).toBeVisible();await capture('help');
  await page.getByRole('button',{name:'Start earning',exact:true}).click();
  await page.getByRole('button',{name:'Office directory',exact:true}).click();await expect(page.locator('.pg-panelhead')).toContainText('Office directory');await capture('directory');
  await page.getByRole('button',{name:/^close$/i}).click();
  const away=page.locator('.pg-bar>.pg-work.away');if(await away.isVisible())await away.click();
  await expect(page.locator('.pg-bar>.pg-work')).not.toHaveClass(/\baway\b/,{timeout:25000});
  await page.locator('.pg-officedesk.mine').click();await expect(page.locator('.pg-panelhead')).toContainText('Your desk');await capture('desk');
  const summary={width,fixtureData:true,strict:process.env.QA_A11Y_STRICT==='1',scans,errors,blockedExternalOrigins:[...new Set(blocked)],rpcCounts:fixture.calls.reduce((out,c)=>(out[c.rpc]=(out[c.rpc]||0)+1,out),{})};
  const summaryPath=info.outputPath('summary.json');await fs.writeFile(summaryPath,JSON.stringify(summary,null,2));await info.attach('Audit summary',{path:summaryPath,contentType:'application/json'});
  const groups=scans.reduce((n,s)=>n+s.violations.length,0);
  info.annotations.push({type:'accessibility-mode',description:`${summary.strict?'Strict':'Report only'}: ${groups} rule/state groups; manual review still required`});
  console.log(`${width}px ${summary.strict?'STRICT':'REPORT ONLY'}: ${groups} accessibility rule/state groups recorded. Audit completion is not accessibility compliance.`);
  expect(errors).toEqual([]);
  expect(fixture.calls.filter(c=>!allowedRpcs.has(c.rpc))).toEqual([]);
  // Boot can update synthetic achievement metadata; economic fields must stay untouched.
  const original=JSON.parse(before);for(const key of ['pp','lifetime','equity','owned','upgrades','kit','wardrobe_owned'])expect(fixture.player[key]).toEqual(original[key]);
  if(process.env.QA_A11Y_STRICT==='1')expect(scans.flatMap(s=>s.violations)).toEqual([]);
 });
});
