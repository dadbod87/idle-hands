/* Generated into index.html by build-next-week-client.py; no separate runtime dependency. */
function officeRead(promise){
 let timer;
 return Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Office records took too long. Please retry.')),15000);})]).finally(()=>clearTimeout(timer));
}
function earnedSeniority(p){return Math.max(0,Number(p?.seniority_earned??p?.equity??0));}
const OFFICE_TOOL_LABELS={rescue:'Emergency Stapler',confetti:'Confetti Cartridge',filter:'Spam Filter'};
const OFFICE_COLLECTIBLE_LABELS={nameplate:'Personalized nameplate',corkboard:'Incident Corkboard',plaque:'Project plaque'};
function OfficeCollectibleArt({item,name='EMPLOYEE'}){
 return <svg viewBox="0 0 160 100" role="img" aria-label={OFFICE_COLLECTIBLE_LABELS[item]} fill="none" stroke="#2B2B2B" strokeWidth="3" strokeLinejoin="round">
  {item==='nameplate'?<><path d="M10 80 26 28h110l16 52Z" fill="#C6A15F"/><path d="M31 36h100v32H31Z" fill="#FFF4D8"/><text x="81" y="56" textAnchor="middle" fill="#2B2B2B" stroke="none" fontSize="12">{name.slice(0,15)}</text></>:item==='corkboard'?<><rect x="15" y="9" width="130" height="82" rx="3" fill="#B78F5D"/><path d="M26 23h51v49H26Z" fill="#F8F1E3"/><path d="m89 26 40 4-5 39-40-4Z" fill="#FFD36B"/><circle cx="51" cy="26" r="4" fill="#F78B6B"/><path d="M34 42h31m-31 9h26m-26 10h28M93 46h25m-25 9h20"/></>:<><path d="M24 11h112v78H24Z" fill="#8FA67A"/><path d="M32 19h96v62H32Z" fill="#F8F1E3"/><path d="m80 25 6 12 13 2-10 10 2 14-11-7-12 7 3-14-10-10 13-2Z" fill="#FFD36B"/><text x="80" y="74" textAnchor="middle" stroke="none" fill="#2B2B2B" fontSize="8">WE DID A THING</text></>}
 </svg>;
}
function OfficeCollectionDecor({player}){
 const owned=player?.office_collectibles||[],confetti=Date.parse(player?.office_confetti?.until||'')>Date.now();
 if(!owned.length&&!confetti)return null;
 return <div className="pg-office-collection" aria-hidden="true">{owned.map(item=><span key={item}><OfficeCollectibleArt item={item} name={player.name}/></span>)}{confetti&&<i className="pg-confetti-desk">{Array.from({length:12},(_,i)=><b key={i} style={{left:(i*29%95)+'%',top:(i*17%65)+'%',background:['#F78B6B','#FFD36B','#7B9CC4'][i%3]}}/>)}</i>}</div>;
}
function OfficeActivityChart({rows}){
 const max=Math.max(1,...rows.map(r=>r.given+r.received));
 return <svg className="pg-activity-chart" viewBox={`0 0 400 ${Math.max(40,rows.length*32)}`} role="img" aria-label="Actions given in blue and received in sage; exact counts are in the table below.">
  <title>Successful coworker actions</title>{rows.map((r,i)=><g key={r.kind+':'+r.category}><text x="0" y={i*32+19} fontSize="11" fill="currentColor">{r.label||DEED_TEXT[r.kind]?.label||r.kind}</text><rect x="165" y={i*32+5} width={205*r.given/max} height="19" fill="#7B9CC4"/><rect x={165+205*r.given/max} y={i*32+5} width={205*r.received/max} height="19" fill="#8FA67A"/></g>)}</svg>;
}
function OfficeWeekPanel({me,board,onPlayer,initialPlayer}){
 const [tab,setTab]=useState(initialPlayer?'profiles':'project'),[status,setStatus]=useState(null),[profile,setProfile]=useState(null);
 const [error,setError]=useState(''),[statusError,setStatusError]=useState(''),[statusLoading,setStatusLoading]=useState(false),[profileError,setProfileError]=useState(''),[busy,setBusy]=useState(false),[feedback,setFeedback]=useState('');
 const [selected,setSelected]=useState(initialPlayer||me.id),[period,setPeriod]=useState('week'),[peer,setPeer]=useState(''),[target,setTarget]=useState(''),[slots,setSlots]=useState([]),[rewardWeek,setRewardWeek]=useState(''),[profileRetry,setProfileRetry]=useState(0),[errorSource,setErrorSource]=useState('');
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
  }catch(e){setErrorSource(request.current?'action':'status');setError(e.message||'The office did not confirm this action. Retry deliberately.');}
  finally{locked.current=false;setBusy(false);}
 };
 const interact=action=>{
  const key=target+':'+action;
  if(request.current?.key!==key)request.current={key,id:crypto.randomUUID()};
  return mutate(()=>api.officeInteract(target,action,request.current.id));
 };
 const shownError=error||(tab==='profiles'?profileError:statusError);
 const retry=()=>error&&errorSource==='action'&&request.current?interact(request.current.key.split(':')[1]):tab==='profiles'&&profileError?setProfileRetry(n=>n+1):loadStatus();
 const unsavedSlots=!!status&&slots.join(',')!==status.toolkit.slots.join(',');
 const choices=board.some(p=>p.id===me.id)?board:[me,...board];
 const mine=status?.project?.mine||[];
 const rewardHistory=status?.reward_weeks||[];
 const rewardRecord=rewardWeek===status?.week?status.project:rewardHistory.find(r=>r.week===rewardWeek);
 const rewardMine=rewardRecord?.mine||[];
 return <div className="pg-next-week" data-testid="next-week-office"><nav aria-label="Office records" className="pg-tabs">{[['project','This week'],['profiles','Player profiles'],['tools','Toolkit']].map(([id,label])=><button key={id} className={'pg-tab'+(tab===id?' on':'')} onClick={()=>{setTab(id);setError('');}}>{label}</button>)}</nav>
  <button className="pg-btn" disabled={busy||statusLoading} onClick={loadStatus}>{statusLoading?"Refreshing office records…":"Refresh office records"}</button>
  {shownError&&<div className="pg-next-error" role="alert">{shownError}<button className="pg-btn" disabled={busy} onClick={retry}>{error&&errorSource==='action'?'Retry action':tab==='profiles'&&profileError?'Retry profile':'Retry records'}</button></div>}
  {tab==='project'&&<><h3>{status?.project.title||'This week in the office'}</h3>{!status&&!statusError&&<p role="status">Reading the committee notes…</p>}{status&&<>
   <p>Contribute to the break room together. Earn one stamp in each category per week; no Busywork donations needed.</p>
   <label className="pg-next-progress">{status.project.total} / {status.project.goal} stamps · {status.project.contributors} / {status.project.minimum_contributors} contributors<progress max={status.project.goal} value={Math.min(status.project.total,status.project.goal)}/></label>
   <p>{status.project.completed?'Complete. Facilities has filed a surprised memo.':'The project needs both the stamp goal and the contributor goal.'}</p>
   <ul>{[['work','Do actual work at your desk'],['facilities','Water a plant or file a printer apology'],['care','Help a coworker with coffee, Cover or Rescue'],['playful','Dress a coworker, nickname them or send confetti']].map(([id,label])=><li key={id}>{mine.includes(id)?'✓ ':'○ '}{label}</li>)}</ul>
   <h4>Permanent things to earn</h4><p>These survive Friday and never increase output. Earn by playing; previewing is free.</p>
   <label>Claim from week <select value={rewardWeek} onChange={e=>setRewardWeek(e.target.value)}>{[...new Set([status.week,...rewardHistory.map(r=>r.week),...status.completed_weeks])].map(w=><option key={w}>{w}</option>)}</select></label>
   <div className="pg-collectible-grid">{Object.entries(OFFICE_COLLECTIBLE_LABELS).map(([id,label])=>{const owned=status.collectibles.includes(id),eligible=id==='nameplate'?rewardMine.includes('work')&&rewardMine.includes('care'):id==='corkboard'?rewardMine.length>=3:rewardRecord?.completed&&rewardMine.length>0;return <article key={id}><OfficeCollectibleArt item={id} name={me.name}/><h4>{label}</h4><p>{id==='nameplate'?'Work + care stamps':id==='corkboard'?'Three different category stamps':'Complete the project and contribute'}</p><button className="pg-btn" disabled={busy||owned||!eligible} onClick={()=>mutate(()=>api.officeCollectible(id,rewardWeek))}>{owned?'Owned':eligible?'Claim reward':'Keep playing'}</button></article>;})}</div>
  </>}</>}
  {tab==='profiles'&&<><div className="pg-next-selects"><label>Player<select value={selected} onChange={e=>{setSelected(e.target.value);setPeer('');}}>{choices.map(p=><option key={p.id} value={p.id}>{p.name}</option>)}</select></label><label>Period<select value={period} onChange={e=>setPeriod(e.target.value)}><option value="week">This week</option><option value="lifetime">Tracked lifetime</option></select></label><label>Coworker<select value={peer} onChange={e=>setPeer(e.target.value)}><option value="">Everyone</option>{choices.filter(p=>p.id!==selected).map(p=><option key={p.id} value={p.id}>{p.name}</option>)}</select></label></div>
   {!profile&&!profileError&&<p role="status">Reading the personnel file…</p>}{profile&&<><h3>{profile.player.name}'s office story</h3><p className="pg-small">Retained records from {new Date(profile.since).toLocaleDateString()}. Continuous tracking starts {new Date(profile.continuous_since||profile.since).toLocaleDateString()}. Earlier records may be incomplete. {profile.privacy}</p>
   {profile.by_kind.length?<><table><caption>How this player plays</caption><thead><tr><th>Category</th><th>Given</th><th>Received</th></tr></thead><tbody>{['help','sabotage','playful','blocked','other'].map(category=>{const rows=profile.by_kind.filter(r=>r.category===category);return rows.length>0&&<tr key={category}><th>{category}</th><td>{rows.reduce((n,r)=>n+r.given,0)}</td><td>{rows.reduce((n,r)=>n+r.received,0)}</td></tr>;})}</tbody></table><OfficeActivityChart rows={profile.by_kind}/><table><caption>Successful actions · blue given / sage received</caption><thead><tr><th>Action</th><th>Category</th><th>Given</th><th>Received</th></tr></thead><tbody>{profile.by_kind.map(r=><tr key={r.kind+':'+r.category}><th>{r.label||DEED_TEXT[r.kind]?.label||r.kind}</th><td>{r.category}</td><td>{r.given}</td><td>{r.received}</td></tr>)}</tbody></table><h4>Daily actions · last 30 days of selected period</h4><OfficeActivityChart rows={profile.daily.map(d=>({...d,kind:d.day,label:d.day,category:'daily'}))}/><table><thead><tr><th>Pacific date</th><th>Given</th><th>Received</th></tr></thead><tbody>{profile.daily.map(d=><tr key={d.day}><th>{d.day}</th><td>{d.given}</td><td>{d.received}</td></tr>)}</tbody></table>{profile.coworkers?.length>0&&<><h4>Coworker history</h4><table><thead><tr><th>Coworker</th><th>Given</th><th>Received</th></tr></thead><tbody>{profile.coworkers.map(p=><tr key={p.id}><th>{p.name}</th><td>{p.given}</td><td>{p.received}</td></tr>)}</tbody></table></>}</>:<p>No recorded public actions in this selection.</p>}</>}
  </>}
  {tab==='tools'&&<>{!status?<p>Read the office records before using tools.</p>:<><h3>Choose two tools</h3><p>Two charges per tool each week. Swapping tools does not refill them. Rescue and Confetti share the ordinary coworker-action cooldown.</p><div className="pg-tool-grid">{Object.entries(OFFICE_TOOL_LABELS).map(([id,label])=><button className="pg-btn" key={id} aria-pressed={slots.includes(id)} disabled={busy||(!slots.includes(id)&&slots.length>=2)} onClick={()=>{slotsDirty.current=true;setSlots(s=>s.includes(id)?s.filter(x=>x!==id):[...s,id]);}}>{label}<small>{status.toolkit.charges[id]} charges</small></button>)}</div><button className="pg-btn" disabled={busy} onClick={()=>mutate(()=>api.officeTools(slots))}>Save two-slot toolkit</button>
   {unsavedSlots&&<p role="status">Save your tool choices before using them. Refreshing preserves unsaved choices.</p>}
   <p>Spam Filter automatically blocks one eligible output debuff while equipped. It does not block credit stealing. Rescue clears one active meeting, chair, mute or reply-all penalty. Confetti lasts ten minutes and has no output penalty.</p>
   <label>Coworker<select aria-label="Toolkit recipient" disabled={busy||errorSource==='action'&&!!error} value={target} onChange={e=>{setTarget(e.target.value);request.current=null;}}><option value="">Choose someone</option>{choices.filter(p=>p.id!==me.id).map(p=><option key={p.id} value={p.id}>{p.name}</option>)}</select></label>
   {errorSource==='action'&&error&&<p>Retry the same action below. Your remaining charge is protected.</p>}<div className="pg-next-actions">{['rescue','confetti'].map(id=><button className="pg-btn" key={id} disabled={busy||unsavedSlots||!target||!status.toolkit.slots.includes(id)||status.toolkit.charges[id]<1} onClick={()=>interact(id)}>{id==='rescue'?'Rescue coworker':'Send confetti'}</button>)}</div>
   {Date.parse(status.confetti?.until||'')>Date.now()&&<button className="pg-btn" disabled={busy} onClick={()=>mutate(()=>api.officeClearConfetti())}>Clear confetti from my desk</button>}
   <p className="pg-small" role="status">{busy?'Waiting for the server…':feedback||'Actions and remaining charges are confirmed by the server.'}</p>
  </>}</>}
 </div>;
}
