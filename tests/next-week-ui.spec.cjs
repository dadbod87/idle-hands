const {test,expect}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
const base='http://127.0.0.1:8765/';
for(const viewport of [{width:1440,height:900},{width:390,height:844},{width:844,height:390}])test(`next week ${viewport.width}x${viewport.height}: project, profiles, retry and toolkit`,async({browser})=>{
 const context=await browser.newContext({viewport,hasTouch:viewport.width<1000,reducedMotion:'reduce'}),page=await context.newPage();
 let profileFail=true;const state={version:1,week:'2026-47',project:{title:'The Break Room Has Standards Now',goal:12,minimum_contributors:3,total:5,contributors:3,mine:['work','care'],completed:false},toolkit:{slots:['rescue','confetti'],charges:{rescue:2,confetti:2,filter:2}},collectibles:[],completed_weeks:[],history_since:'2026-11-07T00:00:00Z'};
 const f=await installGameFixture(page,{handleRpc:async(name,args,p)=>{
  if(name==='office_week_status')return {body:state};
  if(name==='office_profile'){if(profileFail){profileFail=false;return {status:400,body:{message:'Fixture profile retry'}};}return {body:{player:{id:p.id,name:p.name},period:args.p_period,since:state.history_since,privacy:'Hushed actions are excluded from public charts.',by_kind:[{kind:'coffee',category:'help',given:5,received:3},{kind:'credit',category:'sabotage',given:4,received:2},{kind:'dress',category:'playful',given:1,received:1}],daily:[{day:'2026-11-13',given:10,received:6}],coworkers:[]}};}
  if(name==='office_equip_tools'){state.toolkit.slots=args.p_slots;return {body:state};}
  if(name==='office_claim_collectible'){p.office_collectibles=[args.p_item];state.collectibles=p.office_collectibles;return {body:p};}
 }});
 f.player.seniority_earned=20;f.player.equity=16;
 await page.goto(base);await expect(page.locator('.pg-stage')).toBeVisible();
 expect(f.calls.filter(c=>c.rpc==='office_week_status')).toHaveLength(0);
 if(viewport.width<1000)await page.getByRole('button',{name:'More',exact:true}).click();
 await page.getByRole('button',{name:'This week & player profiles',exact:true}).click();
 await expect(page.getByRole('heading',{name:state.project.title})).toBeVisible();
 await page.getByRole('button',{name:'Claim reward',exact:true}).first().click();await expect(page.getByRole('button',{name:'Owned',exact:true})).toHaveCount(1);
 await page.getByRole('button',{name:'Player profiles',exact:true}).click();await expect(page.getByRole('alert')).toContainText('Fixture profile retry');
 await page.getByRole('button',{name:/Retry/}).click();await expect(page.getByRole('img',{name:/Actions given/})).toBeVisible();
 await expect(page.getByRole('cell',{name:'help',exact:true})).toBeVisible();
 await page.getByRole('button',{name:'Toolkit',exact:true}).click();await expect(page.getByRole('heading',{name:'Choose two tools'})).toBeVisible();
 await page.getByRole('button',{name:'Emergency Stapler',exact:false}).click();await page.getByRole('button',{name:'Spam Filter',exact:false}).click();await page.getByRole('button',{name:'Save two-slot toolkit'}).click();
 await expect.poll(()=>state.toolkit.slots.includes('filter')).toBe(true);expect(state.toolkit.charges.rescue).toBe(2);
 await page.screenshot({path:`test-results/next-week-${viewport.width}-${viewport.height}.png`,fullPage:true});
 expect(await page.locator('.pg-panel').evaluate(el=>el.scrollWidth<=el.clientWidth+2)).toBe(true);
 await context.close();
});
for(const viewport of [{width:390,height:844},{width:844,height:390}])test(`next week ${viewport.width}: touch moves without opening a fixture`,async({browser})=>{
 const ctx=await browser.newContext({viewport,hasTouch:true,reducedMotion:'reduce'}),page=await ctx.newPage();const f=await installGameFixture(page);
 await page.goto(base);await expect(page.locator('.pg-stage')).toBeVisible();
 await page.getByRole('button',{name:'Office directory',exact:true}).click();await page.getByRole('button',{name:/HR Cabinet/}).click();await expect(page.locator('.pg-panel')).toBeVisible({timeout:30000});await page.locator('.pg-panel .pg-x').click();
 const before=f.calls.filter(c=>['do_deed','buy_item','grab_chair'].includes(c.rpc)).length;
 await page.locator('[data-fixture="hr"]').tap();await page.waitForTimeout(500);await expect(page.locator('.pg-panel')).toHaveCount(0);
 expect(f.calls.filter(c=>['do_deed','buy_item','grab_chair'].includes(c.rpc))).toHaveLength(before);
 await expect(page.getByRole('button',{name:/Open HR Cabinet/})).toBeVisible();
 await page.getByRole('button',{name:/Open HR Cabinet/}).click();await expect(page.locator('.pg-panel')).toBeVisible();
 await ctx.close();
});
