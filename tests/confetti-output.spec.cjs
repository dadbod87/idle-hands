const {test,expect}=require('@playwright/test');
const {installGameFixture}=require('./game-fixture.cjs');
for(const viewport of [{width:1440,height:900},{width:390,height:844},{width:844,height:390}])test(`confetti output ${viewport.width}: penalty badge, defenses copy and free cleanup`,async({browser})=>{
 const ctx=await browser.newContext({viewport,hasTouch:viewport.width<1000,reducedMotion:'reduce'}),page=await ctx.newPage(),until=new Date(Date.now()+600000).toISOString();
 const state={version:1,confetti_rules:{version:1,mult:0.65,minutes:10},week:'2026-47',project:{title:'Fixture project',goal:36,minimum_contributors:3,total:0,contributors:0,mine:[]},toolkit:{slots:['rescue','confetti'],charges:{rescue:2,confetti:2,filter:2}},collectibles:[],completed_weeks:[],confetti:{until,mult:0.65}};
 const f=await installGameFixture(page,{handleRpc:async(name,args,p)=>{
  if(name==='office_week_status')return {body:state};
  if(name==='office_clear_confetti'){p.office_confetti=null;p.buffs=p.buffs.filter(b=>b.kind!=='confetti');state.confetti=null;return {body:p};}
 }});
 f.player.office_confetti=state.confetti;f.player.buffs=[{kind:'confetti',mult:0.65,start:new Date().toISOString(),until,from_name:'Fixture coworker'}];
 await page.goto('http://127.0.0.1:8765/');await expect(page.locator('.pg-stage')).toBeVisible();
 await expect(page.locator('.pg-effect').filter({hasText:'Confetti Incident'})).toContainText('−35%');
 if(await page.getByRole('button',{name:'More',exact:true}).isVisible())await page.getByRole('button',{name:'More',exact:true}).click();
 await page.getByRole('button',{name:'This week & player profiles',exact:true}).click();await page.getByRole('button',{name:'Toolkit',exact:true}).click();
 await expect(page.locator('.pg-panel')).toContainText('Confetti reduces output by 35%');
 await expect(page.locator('.pg-panel')).toContainText('Spam Filter blocks it and Return to Sender reflects it');
 await expect(page.locator('.pg-panel')).not.toContainText('has no output penalty');
 await page.screenshot({path:`test-results/confetti-output-${viewport.width}.jpg`,type:'jpeg',quality:65,fullPage:true});
 await page.getByRole('button',{name:'Clear confetti from my desk'}).click();
 await expect(page.locator('.pg-effect').filter({hasText:'Confetti Incident'})).toHaveCount(0);
 expect(f.player.pp).toBe(500000);expect(state.toolkit.charges.confetti).toBe(2);
 expect(f.calls.filter(c=>['buy_item','do_deed','office_interact'].includes(c.rpc))).toHaveLength(0);
 await ctx.close();
});
