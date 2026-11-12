from pathlib import Path
root=Path(__file__).resolve().parents[1]
path=root/'index.html';s=path.read_text()
if '/* BEGIN NEXT WEEK UI */' in s:
 a=s.index('/* BEGIN NEXT WEEK UI */');b=s.index('/* END NEXT WEEK UI */',a)+len('/* END NEXT WEEK UI */')
 s=s[:a]+'/* BEGIN NEXT WEEK UI */\n'+(root/'tools/next-week-ui.jsx').read_text()+'\n/* END NEXT WEEK UI */'+s[b:]
 path.write_text(s);print('Updated generated UI');raise SystemExit
def replace(a,b):
 global s
 assert a in s,a[:120]
 s=s.replace(a,b,1)
replace('build 194 · less paperwork', 'build 195 · the office remembers')
replace('let m = 1 + (p.equity || 0) * 0.03','let m = 1 + earnedSeniority(p) * 0.03')
replace('  cover: { label: "Cover their shift", eff: "they receive 150% of what you pay", good: true,','  cover: { label: "Cover their shift", eff: "+15% output for 20 min; replaces existing Cover", good: true,')
replace('hit: (n) => `${n} covered your shift. That is real money.`','hit: (n) => `${n} covered your shift. Output up 15% for twenty minutes.`')
replace('  nickname: { label:', '''  rescue: {label:"IT Rescue",eff:"Clears one eligible coworker debuff",good:true,mine:n=>`You rescued ${n}'s afternoon.`,wire:(a,b)=>`${a} cleared one penalty for ${b}.`,hit:n=>`${n} cleared one of your eligible penalties.`},
  confetti: {label:"Confetti Incident",eff:"Ten minutes of removable desk confetti",good:false,mine:n=>`You decorated ${n}'s desk. Facilities has questions.`,wire:(a,b)=>`${a} delivered confetti to ${b}.`,hit:n=>`${n} decorated your desk with confetti. No output penalty.`},
  nickname: { label:''')
replace('  sync: () => rpc("sync"),','''  officeWeek:()=>rpc("office_week_status"),
  officeProfile:(player,period,peer)=>rpc("office_profile",{p_player:player,p_period:period,p_peer:peer}),
  officeTools:slots=>rpc("office_equip_tools",{p_slots:slots}),
  officeInteract:(target,action,request)=>rpc("office_interact",{p_target:target,p_action:action,p_request:request}),
  officeCollectible:(item,week)=>rpc("office_claim_collectible",{p_item:item,p_week:week}),
  officeClearConfetti:()=>rpc("office_clear_confetti"),
  sync: () => rpc("sync"),''')
replace('  const [near, setNear] = useState(null);','''  const [near, setNear] = useState(null);
  const [worldIntent,setWorldIntent]=useState(null),[emotesOpen,setEmotesOpen]=useState(false),[mapOpen,setMapOpen]=useState(false);
  const worldActivation=useRef(null),touchGesture=useRef(null);''')
replace('  const view = { w: stage.w / zoom, h: stage.h / zoom };','''  const view = { w: stage.w / zoom, h: stage.h / zoom };
  const touchMovement=stage.w<700;
  useEffect(()=>{const cancel=e=>{if(['ArrowUp','ArrowDown','ArrowLeft','ArrowRight','w','a','s','d'].includes(e.key)&&!e.target.closest('input,select,textarea')){setWorldIntent(null);worldActivation.current=null;}};window.addEventListener('keydown',cancel);return()=>window.removeEventListener('keydown',cancel);},[]);''')
replace('  const openFixture = (f) => {','''  // Pointer movement and interaction are separate intents on phones. Keyboard
  // activation (detail=0) and explicitly labeled directory routes remain intentional.
  const captureWorldTap=e=>{
    if(!touchMovement||e.detail===0)return;
    e.preventDefault();e.stopPropagation();
    if(touchGesture.current?.dragged){goRef.current=null;setWorldIntent(null);worldActivation.current=null;return;}
    const el=e.target.closest('[data-fixture],.pg-officedesk,[data-scenery],.pg-chair,.pg-office-tv');
    const fx=el?.dataset.fixture&&FIXTURES.find(f=>f.id===el.dataset.fixture),prop=el?.dataset.scenery&&SCENERY.find(p=>p.id===el.dataset.scenery);
    let point=null,label='',activate=null;
    if(fx){point={x:fx.x+fx.w/2,y:Math.min(ROOM.h-50,fx.y+fx.h+60)};label='Open '+fx.label;activate=()=>openFixture(fx);}
    else if(prop){point={x:prop.x+prop.w/2,y:prop.y+prop.h+35};label='Inspect '+(prop.label||PROP_LABELS[prop.kind]);activate=()=>setPanel('prop:'+prop.id);}
    else if(el?.classList.contains('pg-officedesk')&&el.classList.contains('mine')&&myOffice){point={x:myOffice.cx,y:myOffice.cy+40};label='Open your desk';activate=()=>setPanel('shop');}
    else if(el?.classList.contains('pg-chair')&&chair){point={x:chair.x,y:chair.y+45};label='Grab the good chair';activate=grabChair;}
    else if(el?.classList.contains('pg-office-tv')){const r=el.getBoundingClientRect(),stageBox=stageRef.current.getBoundingClientRect();point={x:(r.left+r.width/2-stageBox.left)/zoom+cam.x,y:(r.bottom-stageBox.top)/zoom+cam.y+40};label='Change TV channel';activate=()=>el.click();}
    if(point){setWorldIntent({...point,label});worldActivation.current=activate;routeTo(point.x,point.y);}
    else{setWorldIntent(null);worldActivation.current=null;walkClick(e);}
  };
  const openFixture = (f) => {''')
replace('             onClick={walkClick}>','''             onPointerDownCapture={e=>{touchGesture.current={x:e.clientX,y:e.clientY,dragged:false};}}
             onPointerMoveCapture={e=>{const g=touchGesture.current;if(touchMovement&&g&&Math.hypot(e.clientX-g.x,e.clientY-g.y)>10){g.dragged=true;goRef.current=null;setWorldIntent(null);worldActivation.current=null;}}}
             onPointerCancelCapture={()=>{goRef.current=null;setWorldIntent(null);worldActivation.current=null;touchGesture.current={dragged:true};}}
             onClickCapture={captureWorldTap} onClick={walkClick}>''')
replace('<div key={f.id} className={"pg-fx"','<div key={f.id} data-fixture={f.id} className={"pg-fx"')
replace('                  <OfficeDeskArt tier={physicalId(p,"desk")} style={itemStyle(p,physicalId(p,"desk"))}/>','''                  <OfficeDeskArt tier={physicalId(p,"desk")} style={itemStyle(p,physicalId(p,"desk"))}/>
                  <OfficeCollectionDecor player={p}/>''')
replace('        <MiniMap pos={pos} board={board} meId={me?.id} cam={cam} view={view} chair={chair} />','''        {(!touchMovement||mapOpen)&&<MiniMap pos={pos} board={board} meId={me?.id} cam={cam} view={view} chair={chair} />}
        {touchMovement&&worldIntent&&<div className="pg-destination" aria-hidden="true" style={{left:(worldIntent.x-cam.x)*zoom,top:(worldIntent.y-cam.y)*zoom}}>◇</div>}''')
replace('          <div id="office-more-actions" className="pg-more-content">','''          <div id="office-more-actions" className="pg-more-content">
            <button className="pg-btn" onClick={()=>{setMoreOpen(false);setPanel('officeweek');}}>This week &amp; player profiles</button>
            {touchMovement&&<button className="pg-btn" aria-pressed={mapOpen} onClick={()=>setMapOpen(v=>!v)}>{mapOpen?'Hide minimap':'Show minimap'}</button>}''')
replace('        <div className="pg-emotes" aria-label="Express yourself">','''        {touchMovement&&<button className="pg-btn" aria-expanded={emotesOpen} onClick={()=>setEmotesOpen(v=>!v)}>Emotes</button>}
        <div className="pg-emotes" aria-label="Express yourself" hidden={touchMovement&&!emotesOpen}>''')
replace('          {near\n            ? (','''          {touchMovement&&worldIntent?<><b>{worldIntent.label}</b><button className="pg-open" disabled={dist(pos,worldIntent)>180} onClick={()=>{worldActivation.current?.();setWorldIntent(null);worldActivation.current=null;}}> {worldIntent.label}</button></>:near
            ? (''')
replace('          {panel === "sound" &&','''          {panel === "officeweek" && <OfficeWeekPanel me={me} board={board} onPlayer={applyServer}/>}
          {panel === "sound" &&''')
replace('<Standings board={board} me={me} fund={fund} feuds={feuds} schedule={weekSchedule} />','<Standings board={board} me={me} fund={fund} feuds={feuds} schedule={weekSchedule} onPlayer={applyServer} />')
replace('const PANEL_TITLES = {','const PANEL_TITLES = {\n  officeweek:"The office has a record",')
replace('function Standings({ board, me, fund, feuds = [], schedule }) {','function Standings({ board, me, fund, feuds = [], schedule, onPlayer }) {\n  const [profileId,setProfileId]=useState(null);')
replace('  const kindest = [...board].sort','  if(profileId)return <><button className="pg-btn" onClick={()=>setProfileId(null)}>Back to whiteboard</button><OfficeWeekPanel me={me} board={board} initialPlayer={profileId} onPlayer={onPlayer}/></>;\n  const kindest = [...board].sort')
replace('<b>{p.name}{me && p.id === me.id ? " (you)" : ""}','<b><button className="pg-profile-link" aria-label={"View "+p.name+" profile"} onClick={()=>setProfileId(p.id)}>{p.name}{me && p.id === me.id ? " (you)" : ""}</button>')
replace('title="on the floor now"','title="Account recently updated; coworker actions can update this too"')
replace('<p>Each unspent <b>Seniority</b> point adds <b>+3% output</b> for the rest of this game week.</p>','<p>Each <b>Seniority</b> point earned this week adds <b>+3% output</b>. Spending points keeps that earned bonus.</p>')
replace('Keep Seniority for its +3% output bonus per point, or spend it here on perks.','Earned Seniority keeps its +3% output bonus per point when you spend available points on perks.')
replace('      <div className="pg-list">\n        {perks.map','      <p><b>{earnedSeniority(me)} earned this week</b> · {me?.equity||0} available to spend. Spending never removes the earned bonus.</p>\n      <div className="pg-list">\n        {perks.map')
replace('▲ {me.equity} Seniority','▲ {me.equity} available Seniority')
replace('`+${(me.equity * 3).toFixed(0)}% output from ${me.equity} Seniority (3% each). Resets every Friday at 4 PM Pacific.`','`+${(earnedSeniority(me)*3).toFixed(0)}% from ${earnedSeniority(me)} earned Seniority; ${me.equity} available. Spending keeps the earned bonus. Resets Friday at 4 PM Pacific.`')
replace('<div><b>{me?.equity || 0}</b><span>Seniority · +{(me?.equity || 0) * 3}%</span></div>','<div><b>{me?.equity || 0}</b><span>available Seniority · {earnedSeniority(me)} earned · +{earnedSeniority(me)*3}%</span></div>')
replace('function EquityShop({ me, cat, onBuy }) {','/* BEGIN NEXT WEEK UI */\n'+(root/'tools/next-week-ui.jsx').read_text()+'\n/* END NEXT WEEK UI */\n\nfunction EquityShop({ me, cat, onBuy }) {')
replace('</style>','''/* Next-week office: keep secondary records inside panels. */
.pg-emotes[hidden]{display:none}.pg-next-week{padding:12px}.pg-next-week select{display:block;width:100%;min-height:44px;margin:6px 0 12px}.pg-next-week button{min-height:44px}.pg-next-selects{display:flex;gap:10px;flex-wrap:wrap}.pg-next-selects label{flex:1 1 140px}.pg-next-week table{border-collapse:collapse;width:100%;font-size:12px;margin:12px 0}.pg-next-week td,.pg-next-week th{padding:8px;border-bottom:1px solid #8FA67A;text-align:left}.pg-next-week caption{text-align:left;padding:8px}.pg-next-error{padding:12px;border:2px dashed #F78B6B}.pg-next-error button{display:block;margin-top:10px}.pg-next-progress progress{display:block;width:100%;height:20px}.pg-activity-chart{width:100%;margin:10px 0}.pg-collectible-grid,.pg-tool-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px;margin:12px 0}.pg-collectible-grid article{padding:10px;border:2px solid #8FA67A;background:#303E37}.pg-collectible-grid svg{width:100%;height:95px}.pg-collectible-grid h4{min-height:42px}.pg-tool-grid button small{display:block}.pg-next-actions{display:flex;gap:10px;flex-wrap:wrap;margin:12px 0}.pg-office-collection{pointer-events:none;position:absolute;inset:-50px 8px auto;display:flex;justify-content:flex-end;gap:2px;height:42px}.pg-office-collection>span{width:48px}.pg-office-collection svg{width:100%;height:100%}.pg-confetti-desk{position:absolute;inset:48px 0 auto;height:70px;width:100%}.pg-confetti-desk b{position:absolute;width:7px;height:4px;transform:rotate(27deg)}.pg-profile-link{font:inherit;color:inherit;background:transparent;border:0;text-decoration:underline;cursor:pointer;min-height:44px;text-align:left}.pg-destination{position:absolute;pointer-events:none;color:#FFD36B;font-size:30px;transform:translate(-50%,-50%)}.pg-next-week .pg-tabs{overflow-x:auto;scrollbar-width:thin}.pg-tabs{scrollbar-width:thin}@media(max-width:600px){.pg-collectible-grid{grid-template-columns:1fr}.pg-tool-grid{grid-template-columns:1fr}.pg-collectible-grid h4{min-height:0}.pg-next-week td,.pg-next-week th{padding:6px 3px}.pg-collectible-grid article{display:grid;grid-template-columns:90px 1fr;gap:8px}.pg-collectible-grid article svg{grid-row:span 3}.pg-root .pg-room{touch-action:none}}
</style>''')
path.write_text(s)
print('Integrated next-week UI, stable Seniority display and deliberate phone controls')
