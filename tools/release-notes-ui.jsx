// Update this manifest for every player-facing release. Acknowledgement is local
// to this player/browser, never an economic action or a claim of cross-device sync.
const RELEASE_NOTES = {
 id: "198",
 title: "Paperwork pileup",
 changes: [
  ["Confetti hurts output", "New Confetti Incidents cut output by 35% for ten minutes before Systems and Thick Skin defenses. Cleanup or IT Rescue restores the rate. Spam Filter blocks it and Return to Sender can reflect it. Sending one adds heat. Saved Busywork is never drained, and earlier cosmetic-only confetti stays harmless."],
  ["Tap nearby desks and the good chair", "On phones, walk up to your desk or the good chair and tap it directly. No separate action button is required when you are in reach. Distant taps still walk without automatically opening or claiming anything."],
  ["Confetti catastrophe", "Confetti Incidents now bury the desk in a bright mound, hang streamers over the edges and keep showering paper until cleared or expired. The ten-minute prank is removable from Toolkit; new incidents now carry the output penalty described above."],
  ["Lifetime profiles and charts", "Helping, sabotage and playful actions now have lasting records, including received actions and coworker relationships. Recorded history survives Friday. Older gaps stay labelled."],
  ["Weekly Race", "Compare recorded weekly earnings and leaderboard positions over time. Your spendable-balance history is private to you. Five-minute recording starts after release activation; earlier points are not reconstructed."],
  ["Seniority that stays useful", "Your 3% output bonus uses Seniority earned this week. Spending points on perks no longer removes that earned bonus. Both weekly points and perks still reset Friday."],
  ["Fairer prices and Cover", "Cover gives a coworker +15% output for 20 minutes instead of transferring cash. Permanent cosmetic prices retain your highest tracked base production, so restructuring cannot make the whole catalogue cheap."],
  ["Phone movement", "Tap to walk. Tap your own desk or the good chair directly when nearby; other fixtures retain their nearby action button. Minimap and emotes can collapse."],
  ["New ways to help and prank", "IT Rescue removes an eligible negative effect. Confetti adds a temporary desk prank with the output penalty described above. Normal sabotage stacking stays."],
  ["Tools and reflection", "Choose two toolkit items. Earn limited refills through varied activity. Receipt Clip reduces one eligible theft; the separately purchased Return to Sender shield reflects one eligible sabotage without reflection chains."],
  ["Projects and lasting collections", "Add one project contribution per listed category per person per Pacific date. The shared goal needs 36 contributions, three people and four active dates; stretch needs 60, five people and six dates. Personal starter rewards stay quick. Earn dated plaques and multi-week terrarium, duck and lamp rewards; qualifying weeks need not be consecutive."],
  ["Costumes, outfits and desk sets", "Try Budget Wizard and Walking Filing Cabinet costumes. Earn Emergency Coffee Technician and Meeting Survivor outfits, plus Facilities, Accounting, IT and Chaos desk sets."],
  ["Your look, your choice", "Owned items are grouped by type. Switching owned glows or atmospheres, hiding effects and choosing empty hands are free. Recolor effects with the existing confirmed-price customization flow. Ownership and saved finishes survive removal and Friday resets."],
  ["Season records and safer purchases", "The record book keeps complete final standings from preserved seasons, ties and personal bests. Quotes, errors and retries are clearer, and repeated requests do not duplicate confirmed purchases."]
 ]
};
function releaseNotesSeen(player){
 try{return JSON.parse(localStorage.getItem('ih_release_notes_'+player))===RELEASE_NOTES.id;}catch{return false;}
}
function ReleaseNotes({onClose}){
 return <Modal label="What's new" onClose={onClose}><section data-testid="release-notes">
  <div className="pg-stamp">What's new · build {RELEASE_NOTES.id}</div><h2>{RELEASE_NOTES.title}</h2>
  <p>New things to do, lasting progress and more ways to make the office your own.</p>
  <ul className="pg-helplist">{RELEASE_NOTES.changes.map(([title,body])=><li key={title}><b>{title}</b><br/>{body}</li>)}</ul>
  <p className="pg-fine">You can reopen this list in Help → What's new. Dismissal is remembered for your player in this browser.</p>
  <button className="pg-btn primary" style={{minHeight:44}} onClick={onClose}>Got it · back to the office</button>
 </section></Modal>;
}
