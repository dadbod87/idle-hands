/* Permanent cosmetic shop and true season records, generated with the office UI. */
const OFFICE_BOUTIQUE_ITEMS=[
 {id:'coffee_tech',name:'Emergency Coffee Technician',kind:'clothing',note:'Apron, utility belt and an oversized emergency flask.'},
 {id:'meeting_survivor',name:'Meeting Survivor',kind:'clothing',note:'Rolled sleeves, a loosened tie and meeting stickers.'},
 {id:'theme_facilities',name:'Facilities Desk Set',kind:'desk'},
 {id:'theme_accounting',name:'Accounting Desk Set',kind:'desk'},
 {id:'theme_it',name:'IT Desk Set',kind:'desk'},
 {id:'theme_chaos',name:'Office Chaos Desk Set',kind:'desk'}
];
function DeskThemeArt({item}){
 const theme=item.replace('theme_',''),color={facilities:'#8FA67A',accounting:'#C6A15F',it:'#7B9CC4',chaos:'#F78B6B'}[theme]||'#8FA67A';
 return <svg viewBox="0 0 160 100" role="img" aria-label={OFFICE_BOUTIQUE_ITEMS.find(x=>x.id===item)?.name||'Desk theme'} fill="none" stroke="#2B2B2B" strokeWidth="3" strokeLinejoin="round" strokeLinecap="round">
 <path d="m12 65 20-13h98l20 13-5 26H17Z" fill={color}/><path d="M23 72h113m-108 9h102" stroke="#F8F1E3" opacity=".55"/>
 {theme==='facilities'&&<><path d="M29 37h58v30H29Z" fill="#C6A15F"/><path d="M32 41h52M43 37V20q15-12 30 0v17"/><path d="m43 38-8-25m5-4-9 3m23 26V9m-5 0h10" strokeWidth="5"/><path d="m100 18 29 3-4 46-29-3Z" fill="#F8F1E3"/><path d="m101 34 4 4 7-9m-8 17 4 4 7-9m4-9 5 1m-7 11 5 1" strokeWidth="2"/></>}
 {theme==='accounting'&&<><path d="M27 19h49v46H27Z" fill="#F8F1E3"/><path d="M34 29h34m-34 9h34m-34 9h34M52 24v35" strokeWidth="1.5"/><rect x="82" y="27" width="28" height="39" rx="3" fill="#4C6068"/><path d="M87 32h18v8H87Z" fill="#C6DAD4"/>{[47,55].map(y=><path key={y} d={`M88 ${y}h3m5 0h3m5 0h1`} stroke="#F8F1E3"/>)}<path d="M121 39h20v27h-20Z" fill="#C6A15F"/><path d="m124 39-3-19m13 19 5-22" strokeWidth="4"/></>}
 {theme==='it'&&<><rect x="29" y="13" width="42" height="54" rx="3" fill="#4C6068"/>{[22,36,50].map(y=><g key={y}><path d={`M35 ${y}h29v9H35Z`} fill="#7B9CC4"/><circle cx="60" cy={y+4} r="2" fill="#8FA67A" stroke="none"/></g>)}<path d="M75 61q20-16 22 0t20-4q4-13 14 0" strokeWidth="4"/><path d="M95 23h37v22H95Z" fill="#C6DAD4"/><path d="m102 31 4 4-4 4m10 1h9" strokeWidth="2"/></>}
 {theme==='chaos'&&<><path d="m30 17 38 5-6 44-38-5Z" fill="#F8F1E3"/><path d="m66 28 29-8 11 36-30 8Z" fill="#FFD36B"/><path d="m35 32 20 3m-22 5 20 3m-21 5 15 2" strokeWidth="1.5"/><path d="M113 42h25v23h-25Z" fill="#7B9CC4"/><path d="M138 46q16 0 0 12M121 34q-7-8 1-14"/><path d="m106 17 3-9m11 14 9-4m-22 61 10 3m9-8 6-6" stroke="#F8F1E3" strokeWidth="4"/><path d="m46 68 18 7-13 11-12-9Z" fill="#FFD36B"/></>}
 </svg>;
}
function OfficeBoutiqueArt({item,player}){
 return item.kind==='desk'?<DeskThemeArt item={item.id}/>:<div className="pg-costume-preview large" role="img" aria-label={item.name+' outfit preview'}><Body p={{...player,look:{...normalizedAvatar(lookFor(player)),clothing:item.id},outfit:null,vanity:{},cosmetic_equipped:{}}}/></div>;
}
function OfficeBoutique({me,onPlayer,status,onDisplay}){
 const [shop,setShop]=useState(null),[error,setError]=useState(''),[busy,setBusy]=useState(false),[selected,setSelected]=useState(null),[quote,setQuote]=useState(null),[feedback,setFeedback]=useState(''),[clock,setClock]=useState(Date.now());
 const reviewArea=useRef(null);
 const lock=useRef(false),pending=useRef(null),seq=useRef(0),server=useRef({at:Date.now(),local:Date.now()});
 const load=useCallback(async()=>{try{const s=await officeRead(api.officeShop());if(s?.version!==1||!Array.isArray(s.items))throw Error('Boutique records are unavailable.');setShop(s);setError('');}catch(e){setError(e.message||'Could not read boutique.');}},[]);
 useEffect(()=>{let active=true;officeRead(api.officeShop()).then(s=>{if(s?.version!==1||!Array.isArray(s.items))throw Error('Boutique records are unavailable.');if(active)setShop(s);}).catch(e=>{if(active)setError(e.message);});return()=>{active=false;seq.current++;};},[]);
 useEffect(()=>{const t=setInterval(()=>setClock(Date.now()),1000);return()=>clearInterval(t);},[]);
 const review=async item=>{if(lock.current)return;const n=++seq.current;setSelected(item);setQuote(null);setError('');setFeedback('');setBusy(true);lock.current=true;
  try{const q=await officeRead(api.officeShopQuote(item.id));if(!q?.quote||q.item!==item.id||!Number.isFinite(q.price)||q.price<=0||!Number.isFinite(Date.parse(q.expires_at)))throw Error('A confirmed item price is unavailable.');if(n===seq.current){setQuote(q);server.current={at:Date.parse(q.server_now)||Date.now(),local:Date.now()};}}
  catch(e){if(n===seq.current)setError(e.message);}finally{if(n===seq.current){setBusy(false);lock.current=false;}}
 };
 const purchase=async()=>{if(lock.current||!quote)return;lock.current=true;setBusy(true);setError('');if(!pending.current)pending.current={quote:quote.quote,id:crypto.randomUUID()};const sent=pending.current;
  try{const r=await api.officeShopBuy(sent.quote,sent.id);await onPlayer(await api.sync());setFeedback(r.outcome||'Purchased.');pending.current=null;setQuote(null);setSelected(null);await load();}
  catch(e){setError(e.message||'Purchase not confirmed. Retry the same request.');}finally{lock.current=false;setBusy(false);}
 };
 const recover=async()=>{if(lock.current)return;lock.current=true;setBusy(true);try{await onPlayer(await api.sync());const fresh=await officeRead(api.officeShop());if(fresh?.version!==1||!Array.isArray(fresh.items))throw Error('Could not confirm owned items.');setShop(fresh);setFeedback(fresh.items.find(i=>i.id===selected?.id)?.owned?'This item is owned. Your purchase was confirmed.':'Ownership refreshed. Review a fresh price to try again.');pending.current=null;setQuote(null);setSelected(null);setError('');}catch(e){setError(e.message);}finally{lock.current=false;setBusy(false);}};
 const remaining=quote?Math.max(0,Math.ceil((Date.parse(quote.expires_at)-(server.current.at+clock-server.current.local))/1000)):0;
 const retryPending=!!pending.current;
 useEffect(()=>{if(selected||feedback){reviewArea.current?.focus({preventScroll:true});reviewArea.current?.scrollIntoView({block:'nearest'});}},[selected?.id,quote?.quote,error,feedback]);
 return <section aria-label="Office Boutique"><h3>Office Boutique</h3><p>Permanent, cosmetic and entirely unofficial. Desk sets use one of your three display slots. Outfits are equipped free in the Mirror. No income bonuses.</p><p>Prices use your retained permanent production benchmark. Work toward participation requirements, then review the exact price before buying.</p>
 <div className="pg-boutique-notice" ref={reviewArea} tabIndex={-1}>
 {error&&<div role="alert" className="pg-next-error">{error}{retryPending&&<button className="pg-btn" disabled={busy} onClick={recover}>Refresh owned items</button>}{!retryPending&&<button className="pg-btn" disabled={busy} onClick={()=>selected?review(selected):load()}>Retry boutique</button>}</div>}
 {selected&&<aside className="pg-next-goal" aria-label="Reviewed boutique purchase"><h4>{selected.name}</h4>{!quote&&!error&&<p>Reading current price…</p>}{quote&&<><p>Confirmed price: <b>{fmt(quote.price)} BW</b> · Available: {fmt(me.pp)} BW</p><p>{quote.basis}</p><p>{remaining>0?`Quote valid for ${remaining}s`:'Quote expired. Review a fresh price.'}</p><button className="pg-btn primary" disabled={busy||(!retryPending&&(remaining<=0||quote.week!==shop?.week||me.pp<quote.price))} onClick={purchase}>{retryPending?'Retry unconfirmed purchase':'Buy '+selected.name+' for '+fmt(quote.price)+' BW'}</button>{!retryPending&&<button className="pg-btn" disabled={busy} onClick={()=>{seq.current++;setSelected(null);setQuote(null);setError('');}}>Cancel purchase</button>}</>}</aside>}
 {feedback&&<p role="status">{feedback}</p>}
 </div>
 {!shop&&!error&&<p role="status">Opening the supply requisition…</p>}
 {shop&&<><p>{shop.care_days} helping dates · {shop.qualified_weeks} qualifying weeks. Helping dates start with this package’s tracked activity.</p><div className="pg-collectible-grid pg-boutique-grid">{shop.items.map(item=>{const shown=(status?.collection?.display||[]).includes(item.id),full=(status?.collection?.display||[]).length>=3;return <article key={item.id}><OfficeBoutiqueArt item={item} player={me}/><h4>{item.name}</h4><p>{item.note}</p><p>{item.care_days>0?`${item.care_days} different helping dates`:item.weeks>0?`${item.weeks} qualifying weeks`:'No participation requirement'} · {item.seconds/3600} hours pricing basis; minimum {fmt(item.minimum)} BW</p><p>{item.owned?'Owned permanently':item.eligible?'Available to purchase':'Participation required'}</p><button className="pg-btn" disabled={busy||retryPending||item.owned||!item.eligible} onClick={()=>review(item)}>{item.owned?'Owned':'Review '+item.name}</button>{item.owned&&item.kind==='desk'&&<button className="pg-btn" disabled={busy||retryPending||(!shown&&full)} onClick={()=>onDisplay(item.id,shown)}>{shown?'Hide ':'Display '}{item.name}</button>}</article>;})}</div></>}


 </section>;
}
function OfficeRecordBook({me,board}){
 const [book,setBook]=useState(null),[week,setWeek]=useState(''),[player,setPlayer]=useState(me.id),[error,setError]=useState(''),[retry,setRetry]=useState(0);
 useEffect(()=>{let live=true;setBook(null);setError('');officeRead(api.officeRecordbook(week,player)).then(r=>{if(r?.version!==1||!Array.isArray(r.seasons)||!Array.isArray(r.standings))throw Error('Season records are unavailable.');if(live)setBook(r);}).catch(e=>{if(live)setError(e.message||'Could not read season records.');});return()=>{live=false;};},[week,player,retry]);
 const choices=board.some(p=>p.id===me.id)?board:[me,...board];
 return <section aria-label="Season record book"><h3>The office record book</h3><p>Completed competitions, final standings and personal bests. Friday resets the competition; these records remain.</p>{error&&<div role="alert">{error}<button className="pg-btn" onClick={()=>setRetry(x=>x+1)}>Retry season records</button></div>}{!book&&!error&&<p role="status">Finding the old score sheets…</p>}{book&&<>
 <div className="pg-next-selects"><label>Completed week<select aria-label="Completed week" value={week||book.selected_week||''} onChange={e=>setWeek(e.target.value)}>{book.seasons.length?book.seasons.map(s=><option key={s.week} value={s.week}>{s.week}{s.coverage==='winner_only'?' · winner only':''}</option>):<option value="">No completed records yet</option>}</select></label><label>Personal best for<select aria-label="Personal best for" value={player} onChange={e=>setPlayer(e.target.value)}>{choices.map(p=><option key={p.id} value={p.id}>{p.name}</option>)}</select></label></div>
 <aside className="pg-next-goal"><h4>Best recorded weekly earnings</h4>{book.personal_best?<p>{fmt(book.personal_best.earnings)} BW · {book.personal_best.week} · place {book.personal_best.place}</p>:<p>No complete standings recorded for this player yet. Older winner-only summaries cannot supply a personal best.</p>}</aside>
 {!book.season?<p>The first completed season will appear after normal rollover.</p>:<><h4>{book.season.week} · {book.season.winner_name||'No winner recorded'}</h4><p>Closed {new Date(book.season.closed_at).toLocaleString(undefined,{timeZone:'America/Los_Angeles'})} Pacific · Winning earnings: {fmt(book.season.top)} BW</p>{book.season.coverage==='standings'?<table><caption>Final game-recorded standings · tied earnings share a place</caption><thead><tr><th>Place</th><th>Employee</th><th>Weekly earnings</th></tr></thead><tbody>{book.standings.map(p=><tr key={p.player}><td>{p.place}</td><th>{p.name}</th><td>{fmt(p.earnings)} BW</td></tr>)}</tbody></table>:<p>Winner-only historical summary. Individual standings were not preserved for this week.</p>}
 {book.awards?.length>0&&<><h4>From the retained public action history</h4><ul>{book.awards.map(a=><li key={a.category+a.player}>{({help:'Helping hand',playful:'Office stylist and prankster',sabotage:'Office menace'})[a.category]}: {a.name} · {a.actions} actions</li>)}</ul></>}</>}
 <p className="pg-small">{book.note}</p>
 </>}</section>;
}
