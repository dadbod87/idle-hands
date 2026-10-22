const {test,expect}=require('@playwright/test');const {installGameFixture}=require('./game-fixture.cjs');const fs=require('node:fs'),vm=require('node:vm');
test('ambient bingo is credited and rejected suggestions retain the draft',async({browser})=>{
 test.setTimeout(60000);const context=await browser.newContext({viewport:{width:393,height:851},isMobile:true,hasTouch:true}),page=await context.newPage();
 const failures=['suggest_memo'];const fixture=await installGameFixture(page,{failRpcs:failures});
 await page.addInitScript(()=>{const original=window.setInterval;window.setInterval=function(fn,ms,...rest){if(ms===17000)window.__ambientSpeech=fn;return original(fn,ms,...rest);};});
 await page.goto('http://127.0.0.1:8765/');await expect(page.locator('.pg-stage')).toBeVisible();
 const source=fs.readFileSync('index.html','utf8'),c={};vm.createContext(c);vm.runInContext(source.slice(source.indexOf('const CATCHPHRASES ='),source.indexOf('const CATCHPHRASES =')+source.slice(source.indexOf('const CATCHPHRASES =')).indexOf('];')+2)+';this.lines=CATCHPHRASES',c);
 for(const word of ['in theory','please hold','question for you']){const index=c.lines.findIndex(l=>l.toLowerCase().includes(word));await page.evaluate(({index,len})=>{const random=Math.random;Math.random=()=> (index+.1)/len;try{window.__ambientSpeech();}finally{Math.random=random;}},{index,len:c.lines.length});}
 await page.getByRole('button',{name:'More',exact:true}).click();await page.getByRole('button',{name:'Office Nonsense',exact:true}).click();await page.getByRole('button',{name:'bingo',exact:true}).click();
 for(const w of ['in theory','please hold','question for you'])await expect(page.locator('.pg-bingosquare').filter({hasText:w})).toHaveClass(/on/);
 await page.getByRole('button',{name:'Return to actual work',exact:true}).click();
 await page.getByRole('button',{name:'Office directory',exact:true}).click();await page.getByRole('button',{name:'Walk to Suggestion Box',exact:true}).click();const input=page.locator('textarea.pg-suggest');await expect(input).toBeVisible({timeout:20000});
 const draft='A meeting about fewer meetings.';await input.fill(draft);await page.getByRole('button',{name:'File it',exact:true}).click();await expect(page.getByText('Error: Fixture request declined',{exact:true})).toBeVisible();await expect(input).toHaveValue(draft);
 failures.length=0;await page.getByRole('button',{name:'File it',exact:true}).click();await expect(input).toHaveValue('');expect(fixture.calls.filter(c=>c.rpc==='suggest_memo')).toHaveLength(2);expect(fixture.player.pp).toBe(500000);await context.close();
});
