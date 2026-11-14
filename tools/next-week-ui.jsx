/* Generated into index.html by build-next-week-client.py; no separate runtime dependency. */
function officeRead(promise){
 let timer;
 return Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Office records took too long. Please retry.')),15000);})]).finally(()=>clearTimeout(timer));
}
function earnedSeniority(p){return Math.max(0,Number(p?.seniority_earned??p?.equity??0));}
const OFFICE_TOOL_HELP={rescue:'Remove one eligible penalty from a coworker.',confetti:'Reduce output by 35% for ten minutes before defenses. Adds heat.',filter:'Block one eligible output sabotage. Does not block credit theft.',clip:'Halve one positive credit theft after passive defenses.'};
const OFFICE_TOOL_LABELS={rescue:'Emergency Stapler',confetti:'Confetti Cartridge',filter:'Spam Filter',clip:'Receipt Clip'};
const OFFICE_COLLECTIBLE_LABELS={nameplate:'Personalized nameplate',corkboard:'Incident Corkboard',plaque:'Project plaque',terrarium:'Desk terrarium',duck:'Rubber-duck consultant',lamp:'Executive lamp'};
const OFFICE_COLLECTION_WEEKS={terrarium:2,duck:4,lamp:6};
const OFFICE_CATEGORY_TEXT={work:'Do actual work at your desk',facilities:'Water a plant or file a printer apology',care:'Help a coworker with coffee, Cover or Rescue',playful:'Dress a coworker, nickname them or send confetti'};
function OfficeCollectibleArt({item,name='EMPLOYEE',memento}){
 if(item.startsWith('theme_'))return <DeskThemeArt item={item}/>;
 return <svg viewBox="0 0 160 100" role="img" aria-label={OFFICE_COLLECTIBLE_LABELS[item]} fill="none" stroke="#2B2B2B" strokeWidth="3" strokeLinejoin="round">
  {item==='nameplate'?<><path d="M10 80 26 28h110l16 52Z" fill="#C6A15F"/><path d="M31 36h100v32H31Z" fill="#FFF4D8"/><text x="81" y="56" textAnchor="middle" fill="#2B2B2B" stroke="none" fontSize="12">{name.slice(0,15)}</text></>:item==='corkboard'?<><rect x="15" y="9" width="130" height="82" rx="3" fill="#B78F5D"/><path d="M26 23h51v49H26Z" fill="#F8F1E3"/><path d="m89 26 40 4-5 39-40-4Z" fill="#FFD36B"/><circle cx="51" cy="26" r="4" fill="#F78B6B"/><path d="M34 42h31m-31 9h26m-26 10h28M93 46h25m-25 9h20"/></>:item==='terrarium'?<><path d="m45 13 70 0 18 69H27Z" fill="#C6DAD4"/><path d="M31 66h98l4 16H27Z" fill="#9B7653"/><path d="M79 68V32m0 21L62 39m17 21 23-20"/><path d="M79 46c-26 0-26-23-26-23 25 0 26 23 26 23Zm2-8c0-23 24-21 24-21-1 22-24 21-24 21Zm3 23c0-23 30-23 30-23-4 24-30 23-30 23Z" fill="#8FA67A"/><path d="m41 29-7 25m85-17 4 17" stroke="#FFF8E8"/></>:item==='duck'?<><path d="M36 61c-15-3-15-15-15-15 13 7 20 5 20 5 12-9 29-9 41-4-6-14-3-32 15-33 21-1 28 19 17 32 8 4 13 10 12 18-2 28-80 31-90-3Z" fill="#FFD36B"/><path d="m115 31 21 7-23 8Z" fill="#F78B6B"/><circle cx="104" cy="27" r="3" fill="#2B2B2B"/><path d="M53 57c19-6 31 7 26 15-14 8-31-1-26-15Z" fill="#C6A15F"/><path d="M29 85h105" stroke="#7B9CC4"/></>:item==='lamp'?<><path d="M50 87h63l-8-9H59Z" fill="#C6A15F"/><path d="M80 78V43" strokeWidth="7"/><path d="m49 14 57 0 20 35H31Z" fill="#8FA67A"/><path d="M38 50h80l-9 9H48Z" fill="#FFD36B"/><path d="M112 51v20"/><circle cx="112" cy="74" r="3" fill="#C6A15F"/></>:<><path d="M24 11h112v78H24Z" fill="#8FA67A"/><path d="M32 19h96v62H32Z" fill="#F8F1E3"/><path d="m80 25 6 12 13 2-10 10 2 14-11-7-12 7 3-14-10-10 13-2Z" fill={memento?.stretch?'#F78B6B':'#FFD36B'}/><text x="80" y="74" textAnchor="middle" stroke="none" fill="#2B2B2B" fontSize="8">{memento?.week||'WE DID A THING'}</text></>}
 </svg>;
}
function OfficeConfettiArt(){
 const colors=['#F78B6B','#FFD36B','#7B9CC4','#8FA67A','#BB76A5','#FFF8E8'];
 return <div className="pg-confetti-incident" data-testid="confetti-incident" aria-hidden="true"><svg viewBox="0 0 240 190" fill="none" stroke="#2B2B2B" strokeWidth="1.5">
  <path className="pg-confetti-streamers" d="M24 27q28-26 16 7t19 20M104 10q-22 12 4 23t-7 24M198 19q-23 15 0 26t-8 24" stroke="#F78B6B" strokeWidth="7"/>
  <path d="M18 124q19-27 38-11 16-40 39-16 20-32 43-7 22-17 35 13 29-13 49 20l-10 25H28Z" fill="#FFD36B" strokeWidth="3"/>
  {Array.from({length:72},(_,i)=>{const x=18+i*47%207,y=99+i*23%49;return <rect key={i} x={x} y={y} width={9+i%4} height={5+i%3} rx="1" fill={colors[i%colors.length]} transform={`rotate(${i*37%150-75} ${x} ${y})`}/>;})}
  <path d="M29 133q-19 27 5 40m37-38q28 20 6 40m103-44q-23 28 1 43m24-49q27 23 3 40" stroke="#7B9CC4" strokeWidth="6"/>
  {Array.from({length:36},(_,i)=>{const x=12+i*43%216,y=8+i*19%92;return <g className="pg-confetti-fall" key={i} style={{animationDelay:-(i%12)*.31+'s',animationDuration:3+i%5*.35+'s','--confetti-drift':(i%2?14:-14)+'px'}}><rect x={x} y={y} width={8+i%4} height={5+i%3} rx="1" fill={colors[(i+2)%colors.length]} transform={`rotate(${i*31%160} ${x} ${y})`}/></g>;})}
 </svg></div>;
}
function OfficeCollectionDecor({player}){
 const owned=(player?.office_display??player?.office_collectibles??[]).slice(0,3),confetti=Date.parse(player?.office_confetti?.until||'')>Date.now();
 if(!owned.length&&!confetti)return null;
 return <>{owned.length>0&&<div className="pg-office-collection" aria-hidden="true">{owned.map(item=><span key={item}><OfficeCollectibleArt item={item} name={player.name} memento={item==='plaque'?player.office_memento:null}/></span>)}</div>}{confetti&&<OfficeConfettiArt/>}</>;
}
function OfficeShieldArt(){return <svg viewBox="0 0 160 100" role="img" aria-label="Return to Sender reflective shield" fill="none" stroke="#2B2B2B" strokeWidth="4" strokeLinejoin="round"><path d="m80 8 46 15v28c0 24-28 35-46 42-18-7-46-18-46-42V23Z" fill="#7B9CC4"/><path d="M49 34h62v39H49Z" fill="#F8F1E3"/><path d="m50 35 30 21 30-21"/><path d="M101 79H72c-23 0-26-32-4-32h18m-9-10 12 10-12 10" stroke="#F78B6B" strokeWidth="7"/></svg>;}
function OfficeActivityChart({rows}){
 const max=Math.max(1,...rows.map(r=>r.given+r.received));
 return <svg className="pg-activity-chart" viewBox={`0 0 400 ${Math.max(40,rows.length*32)}`} role="img" aria-label="Actions given in blue and received in sage; exact counts are in the table below.">
  <title>Recorded coworker actions</title>{rows.map((r,i)=><g key={r.kind+':'+r.category}><text x="0" y={i*32+19} fontSize="11" fill="currentColor">{r.label||DEED_TEXT[r.kind]?.label||r.kind}</text><rect x="165" y={i*32+5} width={205*r.given/max} height="19" fill="#7B9CC4"/><rect x={165+205*r.given/max} y={i*32+5} width={205*r.received/max} height="19" fill="#8FA67A"/></g>)}</svg>;
}
function OfficeWeekPanel({me,board,onPlayer,initialPlayer}){
 const [tab,setTab]=useState(initialPlayer?'profiles':'project'),[status,setStatus]=useState(null),[profile,setProfile]=useState(null);
 const [error,setError]=useState(''),[statusError,setStatusError]=useState(''),[statusLoading,setStatusLoading]=useState(false),[profileError,setProfileError]=useState(''),[busy,setBusy]=useState(false),[feedback,setFeedback]=useState('');
 const [selected,setSelected]=useState(initialPlayer||me.id),[period,setPeriod]=useState('week'),[peer,setPeer]=useState(''),[target,setTarget]=useState(''),[slots,setSlots]=useState([]),[rewardWeek,setRewardWeek]=useState(''),[profileRetry,setProfileRetry]=useState(0),[errorSource,setErrorSource]=useState('');
 const [quote,setQuote]=useState(null),[quoteError,setQuoteError]=useState(''),[quoteLoading,setQuoteLoading]=useState(false),[clock,setClock]=useState(Date.now()),[guideHidden,setGuideHidden]=useState(()=>{try{return localStorage.getItem('ih_office_guide_'+me.id)==='1';}catch{return false;}});
 const quoteSeq=useRef(0),serverClock=useRef({server:Date.now(),client:Date.now()});
 const locked=useRef(false),request=useRef(null),statusSeq=useRef(0),statusRef=useRef(null),slotsDirty=useRef(false),statusInFlight=useRef(false);
 const loadStatus=useCallback(async()=>{
  if(statusInFlight.current)return;
  statusInFlight.current=true;setStatusLoading(true);
  const seq=++statusSeq.current;
  try{
   const s=await officeRead(api.officeWeek());
   if(s?.version!==1)throw Error('This package is waiting for its prepared backend.');
   if(seq!==statusSeq.current)return;
   const oldWeek=statusRef.current?.week,changed=!!oldWeek&&oldWeek!==s.week;
   statusRef.current=s;setStatus(s);setStatusError('');
   serverClock.current={server:Date.parse(s.server_now)||Date.now(),client:Date.now()};
   if(changed){setQuote(null);quoteSeq.current++;setQuoteLoading(false);}
   if(changed||!slotsDirty.current){setSlots(s.toolkit.slots);slotsDirty.current=false;}
   setRewardWeek(current=>current&&current!==oldWeek?current:s.week);
  }catch(e){if(seq===statusSeq.current)setStatusError(e.message||'Could not read office records.');}
  finally{if(seq===statusSeq.current){statusInFlight.current=false;setStatusLoading(false);}}
 },[]);
 useEffect(()=>{loadStatus();return()=>{statusSeq.current++;};},[loadStatus]);
 useEffect(()=>{
  const refresh=()=>{if(document.visibilityState!=='hidden'&&!locked.current)loadStatus();};
  const timer=setInterval(refresh,30000);document.addEventListener('visibilitychange',refresh);
  return()=>{clearInterval(timer);document.removeEventListener('visibilitychange',refresh);};
 },[loadStatus]);
 useEffect(()=>{const timer=setInterval(()=>setClock(Date.now()),1000);return()=>{clearInterval(timer);quoteSeq.current++;};},[]);
 useEffect(()=>{
  if(tab!=='profiles')return;
  let live=true;setProfile(null);setProfileError('');
  officeRead(api.officeProfile(selected,period,peer||null)).then(p=>{
   if(!p?.player||!Array.isArray(p.by_kind)||!Array.isArray(p.daily))throw Error('The profile records are unavailable.');
   if(live)setProfile(p);
  }).catch(e=>{if(live)setProfileError(e.message||'Could not read this profile.');});
  return()=>{live=false;};
 },[tab,selected,period,peer,profileRetry]);
 const mutate=async fn=>{
  if(locked.current)return;
  locked.current=true;statusSeq.current++;statusInFlight.current=false;setStatusLoading(false);setBusy(true);setError('');setFeedback('');
  try{
   const result=await fn();
   setFeedback(result?.outcome||'Saved. The office has filed it.');
   if(result?.player){
    // A saved receipt can belong to an earlier week. Refresh current player/status
    // rather than displaying the old receipt's balance, perks or remaining charges.
    onPlayer(await api.sync());await loadStatus();
   }else if(result?.id){onPlayer(result);await loadStatus();}
   else if(result?.version===1){statusRef.current=result;setStatus(result);setSlots(result.toolkit.slots);slotsDirty.current=false;setStatusError('');}
   else await loadStatus();
   request.current=null;
  }catch(e){setErrorSource(request.current?'action':'status');setError(e.message||'The office did not confirm this action. Retry deliberately.');if(!request.current)setStatusError('Refresh office records to check the last confirmed state before making another change.');}
  finally{locked.current=false;setBusy(false);}
 };
 const act=(key,invoke)=>{
  if(locked.current)return;
  if(request.current?.key!==key)request.current={key,id:crypto.randomUUID(),invoke};
  const sent=request.current;return mutate(()=>sent.invoke(sent.id));
 };
 const interact=action=>act(target+':'+action,id=>api.officeInteract(target,action,id));
 const reviewShield=async()=>{
  if(locked.current)return;
  const seq=++quoteSeq.current;setQuoteLoading(true);setQuoteError('');setQuote(null);
  try{const q=await officeRead(api.officeShieldQuote());if(!q?.quote||!Number.isFinite(q.price)||q.price<=0||!Number.isFinite(Date.parse(q.expires_at)))throw Error('A confirmed shield quote is unavailable.');if(seq===quoteSeq.current){setQuote(q);serverClock.current={server:Date.parse(q.server_now)||Date.now(),client:Date.now()};}}
  catch(e){if(seq===quoteSeq.current)setQuoteError(e.message||'Could not read shield price.');}
  finally{if(seq===quoteSeq.current)setQuoteLoading(false);}
 };
 const shownError=error||(tab==='profiles'?profileError:statusError);
 const retry=()=>error&&errorSource==='action'&&request.current?mutate(()=>request.current.invoke(request.current.id)):tab==='profiles'&&profileError?setProfileRetry(n=>n+1):loadStatus();
 const unsavedSlots=!!status&&slots.join(',')!==status.toolkit.slots.join(',');
 const choices=board.some(p=>p.id===me.id)?board:[me,...board];
 const mine=status?.project?.mine||[];
 const rewardHistory=status?.reward_weeks||[];
 const rewardRecord=rewardWeek===status?.week?status.project:rewardHistory.find(r=>r.week===rewardWeek);
 const rewardMine=rewardRecord?.mine||[];
 const depth=status?.depth_version===1,qualified=status?.collection?.qualified_weeks||0,display=status?.collection?.display||[],projectCategories=status?.project?.categories||Object.keys(OFFICE_CATEGORY_TEXT);
 const dailyProject=status?.project?.credit_unit==='daily_category',projectMine=dailyProject?(status.project.mine_today||[]):mine;
 const serverNow=serverClock.current.server+clock-serverClock.current.client,cooldown=Math.max(0,Math.ceil((Date.parse(status?.cooldown_until||'')-serverNow)/1000))||0;
 const quoteSeconds=quote?Math.max(0,Math.ceil((Date.parse(quote.expires_at)-serverNow)/1000)):0;
 const quoteValid=!!quote&&quote.week===status?.week&&quoteSeconds>0;
 const nextCollection=Object.keys(OFFICE_COLLECTION_WEEKS).find(id=>!status?.collectibles.includes(id));
 const collectionCards=(ids,permanent=false)=>ids.map(id=>{const label=OFFICE_COLLECTIBLE_LABELS[id],owned=status.collectibles.includes(id),required=OFFICE_COLLECTION_WEEKS[id],eligible=required?qualified>=required:id==='nameplate'?rewardMine.includes('work')&&rewardMine.includes('care'):id==='corkboard'?rewardMine.length>=3:rewardRecord?.completed&&(rewardRecord.categories||projectCategories).some(c=>rewardMine.includes(c));return <article key={id}><OfficeCollectibleArt item={id} name={me.name}/><h4>{label}</h4><p>{required?`${qualified} / ${required} qualifying weeks`:id==='nameplate'?'Work + care stamps':id==='corkboard'?'Three different category stamps':'Complete the project and contribute'}</p><button className="pg-btn" disabled={busy||owned||!eligible} onClick={()=>mutate(()=>api.officeCollectible(id,rewardWeek))}>{owned?'Owned':eligible?'Claim reward':'Keep playing'}</button>{permanent&&owned&&<button className="pg-btn" aria-pressed={display.includes(id)} disabled={busy||(!display.includes(id)&&display.length>=3)} onClick={()=>mutate(()=>api.officeDisplay(display.includes(id)?display.filter(x=>x!==id):[...display,id]))}>{display.includes(id)?`Hide ${label}`:`Display ${label}`}</button>}</article>;});
 return <div className="pg-next-week" data-depth={depth?'true':'false'} data-testid="next-week-office"><nav aria-label="Office records" className="pg-tabs">{[['project','This week'],['profiles','Player profiles'],['tools','Toolkit'],...(depth?[['collection','Collection'],['boutique','Boutique'],['records','Record book']]:[])].map(([id,label])=><button key={id} className={'pg-tab'+(tab===id?' on':'')} onClick={()=>{setTab(id);setError('');}}>{label}</button>)}</nav>
  <button className="pg-btn" disabled={busy||statusLoading} onClick={loadStatus}>{statusLoading?"Refreshing office records…":"Refresh office records"}</button>
  {shownError&&<div className="pg-next-error" role="alert">{shownError}<button className="pg-btn" disabled={busy} onClick={retry}>{error&&errorSource==='action'?'Retry action':tab==='profiles'&&profileError?'Retry profile':'Retry records'}</button></div>}
  {tab==='project'&&<><h3>{status?.project.title||'This week in the office'}</h3>{!status&&!statusError&&<p role="status">Reading the committee notes…</p>}{status&&<>
   <p>{status.project.description||'Contribute to the break room together.'} {dailyProject?'Each person can add one contribution per listed category per Pacific date. Repeating the same category today adds no extra project progress.':'Earn one stamp in each listed category per week.'} No Busywork donations needed.</p>
   <label className="pg-next-progress">{status.project.total} / {status.project.goal} {dailyProject?'daily contributions':'stamps'} · {status.project.contributors} / {status.project.minimum_contributors} contributors{dailyProject&&<> · {status.project.active_days} / {status.project.minimum_days} active Pacific dates</>}<progress max={status.project.goal} value={Math.min(status.project.total,status.project.goal)}/></label>
   <p>{status.project.completed?'Complete. Facilities has filed a surprised memo.':dailyProject?'The office needs all three: contributions, contributors and different active dates.':'The project needs both the stamp goal and the contributor goal.'}</p>
   {dailyProject&&<h4>Your project contributions today · {status.project.today}</h4>}
   <ul>{projectCategories.map(id=><li key={id}>{projectMine.includes(id)?'✓ ':'○ '}{OFFICE_CATEGORY_TEXT[id]}</li>)}</ul>
   {dailyProject&&projectCategories.every(id=>projectMine.includes(id))&&!status.project.stretch_completed&&<p className="pg-note">Your project contributions for today are complete. Come back on another Pacific date to add more; you can still help, prank and work now.</p>}
   {depth&&<><p className="pg-small">This theme stays fixed until Friday. Other activities still count toward your personal collection and supplies. {dailyProject&&'Personal starter rewards still use your weekly category stamps.'}</p><details><summary>Optional stretch · {status.project.stretch_goal} {dailyProject?'contributions':'stamps'} / {status.project.stretch_contributors} contributors{dailyProject&&<> / {status.project.stretch_days} active dates</>}</summary><p>{status.project.stretch_completed?'Stretch complete. The scrapbook gets a special stamp.':'A cosmetic distinction for the same project. Base rewards never require the stretch goal.'}</p></details><aside className="pg-next-goal"><h4>Next thing to work towards</h4><p>{nextCollection?`${OFFICE_COLLECTIBLE_LABELS[nextCollection]} · ${qualified} / ${OFFICE_COLLECTION_WEEKS[nextCollection]} qualifying weeks`:'Your collection is complete. Earn this week’s dated memento for the scrapbook.'}</p><p>A qualifying week means work + another activity across two Pacific dates. Missed weeks never erase progress.</p><button className="pg-btn" onClick={()=>setTab('collection')}>View lasting collection</button></aside>{!guideHidden&&<details className="pg-next-guide"><summary>A short route through the office</summary><ol><li>Do actual work at your desk.</li><li>Water a plant or file a printer apology for free.</li><li>Help a coworker or try a harmless prank.</li><li>Return here to see stamps, earned supplies and your next reward.</li></ol><p>Friday refreshes the competition and tool supplies. Your collection, scrapbook and tracked lifetime history stay.</p><button className="pg-btn" onClick={()=>{setGuideHidden(true);try{localStorage.setItem('ih_office_guide_'+me.id,'1');}catch{}}}>Dismiss office route</button></details>}</>}
   <h4>Permanent things to earn</h4><p>These survive Friday and never increase output. Earn by playing; previewing is free.</p>
   <label>Claim from week <select value={rewardWeek} onChange={e=>setRewardWeek(e.target.value)}>{[...new Set([status.week,...rewardHistory.map(r=>r.week),...status.completed_weeks])].map(w=><option key={w}>{w}</option>)}</select></label>
   <div className="pg-collectible-grid">{collectionCards(['nameplate','corkboard','plaque'])}</div>
  </>}</>}
  {tab==='boutique'&&depth&&<OfficeBoutique me={me} onPlayer={async p=>{onPlayer(p);await loadStatus();}} status={status} onDisplay={(id,shown)=>mutate(()=>api.officeDisplay(shown?display.filter(x=>x!==id):[...display,id]))}/>}
  {tab==='records'&&depth&&<OfficeRecordBook me={me} board={board}/>}
  {tab==='collection'&&depth&&<><h3>A desk with a history</h3><p>{qualified} qualifying weeks. Work + another activity across two Pacific dates earns one week; it never needs a streak.</p><p>Display up to three owned decorations. Hide one to make room; nothing is sold or lost.</p><div className="pg-collectible-grid">{collectionCards(Object.keys(OFFICE_COLLECTIBLE_LABELS),true)}</div><h3>Dated project scrapbook</h3><p>Complete the office project and contribute in one of its listed categories. Mementos are saved automatically, including for later contributors. Select one for your project plaque.</p>{!status.scrapbook?.length?<p>No dated mementos yet. This week’s project is a place to start.</p>:<div className="pg-scrapbook">{status.scrapbook.map(m=><article key={m.week}><OfficeCollectibleArt item="plaque" memento={m}/><div><h4>{m.title}</h4><p>{new Date(m.starts_at).toLocaleDateString(undefined,{timeZone:'America/Los_Angeles'})} · {m.week} · {m.stretch?'Stretch finish':'Base finish'}</p><button className="pg-btn" disabled={busy||m.selected} onClick={()=>mutate(()=>api.officeMemento(m.week))}>{m.selected?'Selected for plaque':'Select for plaque'}</button></div></article>)}</div>}</>}
  {tab==='profiles'&&<><div className="pg-next-selects"><label>Player<select value={selected} onChange={e=>{setSelected(e.target.value);setPeer('');}}>{choices.map(p=><option key={p.id} value={p.id}>{p.name}</option>)}</select></label><label>Period<select value={period} onChange={e=>setPeriod(e.target.value)}><option value="week">This week</option><option value="lifetime">Tracked lifetime</option></select></label><label>Coworker<select value={peer} onChange={e=>setPeer(e.target.value)}><option value="">Everyone</option>{choices.filter(p=>p.id!==selected).map(p=><option key={p.id} value={p.id}>{p.name}</option>)}</select></label></div>
   {!profile&&!profileError&&<p role="status">Reading the personnel file…</p>}{profile&&<><h3>{profile.player.name}'s office story</h3><p className="pg-small">Retained records from {new Date(profile.since).toLocaleDateString()}. Continuous tracking starts {new Date(profile.continuous_since||profile.since).toLocaleDateString()}. Earlier records may be incomplete. {profile.privacy}</p>
   {profile.reflections&&<p>Shield protections: {profile.reflections.protected} · Sabotages returned to this sender: {profile.reflections.returned_to_sender}. Reflected attempts are counted once under blocked.</p>}
   {profile.by_kind.length?<><table><caption>How this player plays</caption><thead><tr><th>Category</th><th>Given</th><th>Received</th></tr></thead><tbody>{['help','sabotage','playful','blocked','other'].map(category=>{const rows=profile.by_kind.filter(r=>r.category===category);return rows.length>0&&<tr key={category}><th>{category}</th><td>{rows.reduce((n,r)=>n+r.given,0)}</td><td>{rows.reduce((n,r)=>n+r.received,0)}</td></tr>;})}</tbody></table><OfficeActivityChart rows={profile.by_kind}/><table><caption>Recorded actions · blue given / sage received</caption><thead><tr><th>Action</th><th>Category</th><th>Given</th><th>Received</th></tr></thead><tbody>{profile.by_kind.map(r=><tr key={r.kind+':'+r.category}><th>{r.label||DEED_TEXT[r.kind]?.label||r.kind}</th><td>{r.category}</td><td>{r.given}</td><td>{r.received}</td></tr>)}</tbody></table><h4>Daily actions · last 30 days of selected period</h4><OfficeActivityChart rows={profile.daily.map(d=>({...d,kind:d.day,label:d.day,category:'daily'}))}/><table><thead><tr><th>Pacific date</th><th>Given</th><th>Received</th></tr></thead><tbody>{profile.daily.map(d=><tr key={d.day}><th>{d.day}</th><td>{d.given}</td><td>{d.received}</td></tr>)}</tbody></table>{profile.coworkers?.length>0&&<><h4>Coworker history</h4><table><thead><tr><th>Coworker</th><th>Given</th><th>Received</th></tr></thead><tbody>{profile.coworkers.map(p=><tr key={p.id}><th>{p.name}</th><td>{p.given}</td><td>{p.received}</td></tr>)}</tbody></table></>}</>:<p>No recorded public actions in this selection.</p>}</>}
  </>}
  {tab==='tools'&&<>{!status?<p>Read the office records before using tools.</p>:<><h3>Your two-tool toolkit</h3><p>Equip up to two different tools. Both slots work the same way. Changes save immediately; swapping never refills charges. These tools are separate from the objects your character carries.</p><div className="pg-tool-slots">{[0,1].map(index=>{const id=status.toolkit.slots[index]||'',active=id==='rescue'||id==='confetti';return <section className="pg-tool-slot" key={index} aria-label={'Tool slot '+(index+1)}><h4>Tool slot {index+1}</h4><strong>{OFFICE_TOOL_LABELS[id]||'Empty slot'}</strong>{id&&<><span className="pg-state-badge">{active?'Use on coworker':'Automatic defense'}</span><p>{status.toolkit.charges[id]} charges remaining</p><p>{OFFICE_TOOL_HELP[id]}</p></>}<label>Change tool<select aria-label={'Change tool in slot '+(index+1)} value={id} disabled={busy||statusLoading||!!statusError||!!request.current} onChange={e=>{const next=[...status.toolkit.slots];if(e.target.value)next[index]=e.target.value;else next.splice(index,1);mutate(()=>api.officeTools(next.filter(Boolean)));}}><option value="">Empty slot</option>{Object.entries(OFFICE_TOOL_LABELS).filter(([key])=>depth||key!=='clip').map(([key,label])=><option key={key} value={key} disabled={status.toolkit.slots.includes(key)&&key!==id}>{label}{status.toolkit.slots.includes(key)&&key!==id?' · already equipped':''}</option>)}</select></label>{id&&<button className="pg-btn" disabled={busy||statusLoading||!!statusError||!!request.current} onClick={()=>mutate(()=>api.officeTools(status.toolkit.slots.filter((_,i)=>i!==index)))}>Remove {OFFICE_TOOL_LABELS[id]}</button>}</section>;})}</div><p role="status">{busy?'Saving or processing your request…':'Equipped choices above are confirmed by the server.'}</p>
   <details className="pg-tool-rules"><summary>Compare tools and defense rules</summary><dl>{Object.entries(OFFICE_TOOL_LABELS).filter(([id])=>depth||id!=='clip').map(([id,label])=><React.Fragment key={id}><dt><b>{label}</b> · {status.toolkit.charges[id]} charges</dt><dd>{OFFICE_TOOL_HELP[id]}</dd></React.Fragment>)}</dl><p>Spam Filter automatically blocks one eligible output debuff while equipped. It does not block credit stealing. Rescue clears one active meeting, chair, mute, reply-all or confetti penalty. Confetti reduces output by 35% for ten minutes before Systems and Thick Skin defenses. Cleanup or Rescue clears it; Spam Filter blocks it and Return to Sender reflects it. Sending it adds one heat. It does not drain saved Busywork.{depth?' Receipt Clip halves one positive credit theft after passive defenses. Empty thefts use no charge.':''}</p>
   </details><p>Charges refresh with the weekly reset. Rescue and Confetti share the ordinary coworker-action cooldown.</p><label>Coworker<select aria-label="Toolkit recipient" disabled={busy||errorSource==='action'&&!!error} value={target} onChange={e=>{setTarget(e.target.value);request.current=null;}}><option value="">Choose someone</option>{choices.filter(p=>p.id!==me.id).map(p=><option key={p.id} value={p.id}>{p.name}</option>)}</select></label>
   {status.confetti_rules?.version!==1&&<p>Confetti output rules are waiting for the updated backend. Rescue and cleanup remain available.</p>}{errorSource==='action'&&error&&<p>Retry the same request below. An accepted request will not be charged again.</p>}{cooldown>0&&<p role="status">Coworker actions ready in {cooldown}s. Defensive shields and automatic tools work independently.</p>}<div className="pg-next-actions">{['rescue','confetti'].map(id=>{const reason=busy?'Waiting for the server…':statusLoading?'Refreshing tool status…':statusError?'Refresh office records before acting.':errorSource==='action'&&error?'Retry the unconfirmed action above.':!status.toolkit.slots.includes(id)?'Equip '+OFFICE_TOOL_LABELS[id]+' first.':status.toolkit.charges[id]<1?'No charges remaining. Check earned refills below.':!target?'Choose a coworker.':cooldown>0?'Ready in '+cooldown+'s.':id==='confetti'&&status.confetti_rules?.version!==1?'Confetti is temporarily unavailable.':'';return <div key={id}><button className="pg-btn primary" disabled={!!reason} onClick={()=>interact(id)}>{id==='rescue'?'Rescue coworker':'Send confetti'}</button><p className="pg-action-reason" role="status">{reason||'Ready · uses one charge'}</p></div>;})}</div>
   {depth&&<><section className="pg-next-supply" aria-label="Earned resupply"><h4>The supply cupboard</h4><p>{status.resupply.used_this_week} / {status.resupply.weekly_limit} weekly refills · {status.resupply.claimed_today?'Today’s refill used':status.resupply.eligible?'Today’s refill earned':'Work + a different activity today to earn one refill'}</p><p>One charge per Pacific date, up to three each week. Maximum two remaining per tool. Choose a depleted tool; no Busywork payment.</p><div className="pg-next-actions">{Object.entries(OFFICE_TOOL_LABELS).map(([id,label])=><button className="pg-btn" key={id} disabled={busy||!status.resupply.eligible||status.toolkit.charges[id]>=2} onClick={()=>act('resupply:'+id,requestId=>api.officeResupply(id,requestId))}>Refill {label}</button>)}</div></section><details className="pg-next-shield" aria-label="Reflective shield"><summary>Return to Sender · {status.shield.armed?'Armed':'Review a shield'}</summary><OfficeShieldArt/><h3>Return to Sender</h3><p><b>{status.shield.armed?'One shield armed':'No shield armed'}</b></p><p>Reflect the next credit theft, output sabotage or blame back onto its sender. The sender pays their attack cost and cooldown; their passive defenses apply. No bouncing between shields. Reflection uses your shield before Filter or Clip, preserving those charges. Helpful deeds and playful pranks pass through.</p><p>One armed shield, purchased separately from tool slots. It protects a future attack; Rescue removes existing penalties. An unused charge expires Friday. Its price benchmark starts fresh each Friday; restructuring within the week never discounts or refills it.</p><button className="pg-btn" disabled={busy||quoteLoading||status.shield.armed} onClick={reviewShield}>{quoteLoading?'Reading shield price…':quote?'Refresh shield price':'Review shield price'}</button>{quoteError&&<p role="alert">{quoteError} <button className="pg-btn" disabled={busy||quoteLoading} onClick={reviewShield}>Retry shield price</button></p>}{quote&&<div className="pg-shield-quote"><p>Confirmed price: <b>{fmt(quote.price)} BW</b> · Your balance: {fmt(me.pp)} BW</p><p>{quote.basis}. Twice your highest base sabotage quote ({fmt(quote.attack_reference)} BW); other players’ live costs can differ.</p><p>{quoteValid?`Quote valid for ${quoteSeconds}s`:'Quote expired. Review a fresh price before buying.'}</p><button className="pg-btn primary" disabled={busy||statusLoading||!!statusError||status.shield.armed||!quoteValid||me.pp<quote.price} onClick={()=>act('shield:'+quote.quote,requestId=>api.officeBuyShield(quote.quote,requestId))}>Buy and arm for {fmt(quote.price)} BW</button></div>}</details></>}
   {Date.parse(status.confetti?.until||'')>Date.now()&&<button className="pg-btn" disabled={busy} onClick={()=>mutate(()=>api.officeClearConfetti())}>Clear confetti from my desk</button>}
   <p className="pg-small" role="status">{busy?'Waiting for the server…':feedback||'Actions and remaining charges are confirmed by the server.'}</p>
  </>}</>}
 </div>;
}
