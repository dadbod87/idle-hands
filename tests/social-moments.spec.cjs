const {test,expect,devices}=require('@playwright/test');const {installGameFixture}=require('./game-fixture.cjs');const {makeLiveBus}=require('./live-bus.cjs');
test('two isolated players invite, walk, wave, and see actual kindness log notes',async({browser})=>{
 test.setTimeout(90000);
 const aCtx=await browser.newContext({viewport:{width:1440,height:900}}),bCtx=await browser.newContext({...devices['Pixel 7']});
 const a=await aCtx.newPage(),b=await bCtx.newPage(),bus=makeLiveBus(),deeds=[],aid='00000000-0000-4000-8000-000000000001',bid='00000000-0000-4000-8000-000000000002';
 const second={id:bid,name:'QA Pal',created_at:'2026-01-02T00:00:00Z',look:{},pp:500000,lifetime:500000};
 const first={id:aid,name:'QA Employee',created_at:'2026-01-01T00:00:00Z',look:{},pp:500000,lifetime:500000};
 a.setDefaultTimeout(10000);b.setDefaultTimeout(10000);
 const fa=await installGameFixture(a,{coworkers:[second],liveBus:bus,deeds,onDeed:(p,args)=>{p.pp-=100;p.goodwill++;deeds.unshift({id:'kind-note-1',kind:args.p_kind,actor:p.id,target:args.p_target,created_at:new Date().toISOString()});}});
 const fb=await installGameFixture(b,{id:bid,name:'QA Pal',coworkers:[first],liveBus:bus,deeds});
 for(const page of [a,b]){await page.goto('http://127.0.0.1:8765/');await expect(page.locator('.pg-stage')).toBeVisible({timeout:15000});}
 await a.bringToFront();console.log('social: inviter walking');await a.getByRole('button',{name:'Office directory',exact:true}).click();await a.getByRole('button',{name:'Walk to The Break Table',exact:true}).click();
 await expect(a.locator('.pg-panelhead')).toContainText('Break room',{timeout:20000});await expect(a.getByRole('meter',{name:'Shared office goal'})).toBeVisible();console.log('social: break room opened, relay sockets',bus.sockets.length);await expect(a.getByRole('button',{name:'Start a coffee break',exact:true})).toBeEnabled({timeout:10000});
 await a.getByRole('button',{name:'Start a coffee break',exact:true}).click();await expect(b.getByTestId('live-break-invite')).toContainText('QA Employee');
 await b.bringToFront();console.log('social: recipient walking');await b.getByRole('button',{name:'Walk over',exact:true}).click();await expect(b.locator('.pg-panelhead')).toContainText('Break room',{timeout:20000});
 await b.getByRole('button',{name:'Wave with the room',exact:true}).click();await expect(b.locator('.pg-room .pg-body.me')).toHaveClass(/em-wave/);
 await expect(a.locator('.pg-peername').filter({hasText:'QA Pal'}).locator('..').locator('.pg-body')).toHaveClass(/em-wave/,{timeout:5000});
 expect(fa.player.pp).toBe(500000);expect(fb.player.pp).toBe(500000);expect(fa.calls.some(x=>x.rpc==='do_deed')).toBe(false);
 // Read jokes without a purchase, then use the unchanged server deed action.
 await a.bringToFront();
 await expect(a.getByTestId('office-moments')).toBeVisible({timeout:15000});
 for(const label of ['Inspect the plant','Read the printer apology','Check the calendar']){await a.getByTestId('office-moments').getByRole('button',{name:label,exact:true}).click();await expect(a.locator('.pg-prop-punchline')).not.toBeEmpty();}
 await a.locator('.pg-picks').getByRole('button',{name:/QA Pal/}).click();await a.getByRole('button',{name:/Leave a coffee/}).click();
 await expect.poll(()=>deeds.length).toBe(1);expect(fa.player.pp).toBe(499900);expect(fa.player.goodwill).toBe(1);expect(fb.player.pp).toBe(500000);
 await b.bringToFront();console.log('social: checking stored kindness');await b.reload();await expect(b.locator('.pg-stage')).toBeVisible({timeout:15000});await b.getByRole('button',{name:'Office directory',exact:true}).click();await b.getByRole('button',{name:'Walk to The Break Table',exact:true}).click();
 await expect(b.getByTestId('kindness-board')).toContainText("QA Employee left a coffee on QA Pal's desk.",{timeout:20000});
 await b.screenshot({path:'test-results/mobile-live-office-moments.png',fullPage:true});
 expect(fa.player.equity).toBe(2);expect(fb.player.equity).toBe(2);expect(bus.messages.some(x=>x.payload.event==='moment')).toBe(true);
 await aCtx.close();await bCtx.close();
});
