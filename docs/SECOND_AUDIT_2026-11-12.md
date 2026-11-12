# Second audit: give the office a second week

Audit base: held build 195, PR #56 head `0cc30badd04901daf725633d471492bc2e7ce1b8`; live main remains `9d622b9` / build 194. This is preparation, not a release authorization. No live player action or migration is part of this audit.

## What the evidence says

Read-only aggregate sample, November 12 at 10:33 Pacific: seven accounts, 945 retained targeted actions, five distinct actors. Credit stealing is 595/945 (63.0%). The two busiest actors produce 84.3% of actions. Four accounts own every highest-tier office fitting across five slots. Shared prop participation has 90 recorded actions from five contributors. These are action/progression observations, not measures of enjoyment, logins or time played. No private action export was attempted for this audit.

Build 195 closes the gift/restructure shortcut and adds goals outside the bank balance. Its remaining retention weakness is repeatability: the project has one hardcoded title/goal; all three rewards are single permanent IDs; the toolkit has two charges per tool per week and no earned resupply. A player can complete the personal collection and use the new tools early, then have little new to pursue on a later week.

## Findings before more content

| Priority | Finding | Practical consequence | Recommended response |
|---|---|---|---|
| High | Waiting until after reset to install the journal cannot capture the closing week's later actions once deeds are deleted. | The saved 942-event snapshot has a cutoff and cannot promise a complete week. | Prepare a separate, compatible journal-only installation for before Friday; keep it held until a concrete release decision. It changes no income, inventory, Seniority, prices or reset rules. |
| High | The project and its plaque do not provide a new collectible in week two. | More wealth is no longer the only dead end; the new collection can also be finished permanently. | Rotating projects with dated, collectible weekly mementos and persistent collection milestones. |
| High | The new defense excludes credit theft, which is 63% of observed actions. | The strongest existing play pattern has no new tactical counter. | Add a separate, two-slot-compatible Receipt Clip defense, with limited charges and explicit partial protection; do not silently make Spam Filter cover everything. |
| High | Repeated output sabotage stacks multiplicatively. Reply-All lasts eight minutes at 0.45× output while cooldown can be shorter. | Four simultaneous copies leave roughly 4.1% output before other modifiers for an unprotected player. | Refresh same-kind sabotage instead of stacking it, and test a combined negative-output floor alongside theft defense. Preserve distinct helpful effects. |
| Medium | All new tool charges can be used early; no earned resupply exists. | The feature becomes a weekly burst rather than a reason to return. | Bounded resupply earned through varied server-verified activity, with a weekly cap and no paid or unlimited refill loop. |
| Medium | Profile and project status share an error state. | A later successful status read erases a failed profile error, leaving a loading message after both requests finished. | Separate resource errors and retries. A deterministic synthetic hook probe reproduces this at the audit base. |
| Medium | Fitting purchases use an income-based fallback before the permanent-price quote arrives, and quote failures are silent. | Displayed prices may disagree with the new retained benchmark; a purchase can be offered without a confirmed price. | Require a valid current server quote before Buy, keep previews free, and show a deliberate retry on quote failure. |
| Medium | Project/charge status loads on entry and own mutations only. | Coworker contributions and an open panel crossing Friday remain stale until reopening. | One bounded visible refresh and a manual refresh; discard late results and preserve selection. No always-on HUD poll. |
| Medium | New tool controls do not explain shared cooldown, target eligibility or confirmed failure beside the action before trying. | Players discover ordinary rules through rejection messages. | Show the remaining cooldown, saved vs unsaved loadout, and a clear outcome. Keep server checks authoritative. |

The deterministic profile probe is a reproduction aid, not browser or hosted-backend evidence. Existing fixtures intentionally substitute some accrual/event dependencies; their success is not a claim about every live integration.

## Proposed next gameplay pack

### 1. A weekly project with a lasting scrapbook

Keep one office project, with a reachable base goal and an optional stretch goal. Use four rotating themes: Break Room Revival, IT Has Opened a Ticket, Facilities Inspection, and the Morale Committee. Change the actual focus and eligible action choices, not just the title. No project should require somebody to remain sabotaged, catch a scarce timed printer jam, or attack an unwilling coworker to finish.

Freeze each week's theme, objectives and reward when that week begins. Store completion and each player's earned memento by week; never recompute an older reward from a later template. Display one chosen plaque at the desk, with the rest in the scrapbook. Base participation rewards stay accessible to casual players; stretch finishes confer no income advantage.

Candidate base remains 12 distinct player/category stamps and three contributors. Candidate optional stretch is 20 stamps and five contributors. With seven accounts, this is a hypothesis to simulate/playtest, not a promise that five will participate. No forced daily streak or punishment for an absent coworker.

### 2. A permanent collection ladder that money cannot skip

Add three later goals: desk terrarium, rubber-duck ornament, executive lamp. Tie the first to varied facilities participation on distinct days, the second to playful/cooperative variety, and the lamp to participation across several distinct weeks. Existing nameplate/corkboard/plaque stay intact.

Use small, visible stages, such as contributing in two, four and six distinct weeks. A missed week does not erase anything. Preview the next item and its exact eligibility. An optional cosmetic finish may cost Busywork after earning the unlock, using a server quote from the retained price benchmark. No output multiplier, cash resale or inventory reset.

Reuse existing Today assignments where possible. The game already has three server-drawn daily jobs and daily post; a second disconnected daily checklist would add clutter rather than depth. Surface the next reachable collection step beside those assignments and the project.

### 3. Social counterplay and limited resupply

Receipt Clip: protect part of one incoming credit theft, consuming a charge only when an eligible positive theft would happen. Proposed starting protection is 50%; the attacker receives exactly the target's actual debit. The prevented amount is not minted or reimbursed elsewhere. Keep it distinct from Spam Filter's output-debuff defense. Both compete with Rescue and Confetti for the same two slots.

Bound output sabotage at the same time: repeated copies of one sabotage should refresh duration rather than multiply penalties. Specify and simulate a combined penalty floor before implementation, including old saves with already-stacked effects, mixed attackers, Rescue, filters, retries and reset. This is a proposed balance change, not part of the prepared reliability fixes.

Earn at most one resupply on a qualifying day and at most three per week, after work plus a different activity category. Choose one tool to restore by one charge, capped at two remaining. No reward for repeated victim farming, replayed requests, swapping slots or merely having a large balance. The current Resale/department rules do not reduce a token cost to zero because resupply has no cash price.

These numbers require isolated simulations, concurrency tests and a small playtest. Add counterplay and pacing together; do not add another unrestricted attack before people have a useful defense.

### 4. A short first-session route

The first five minutes should show one useful next step: work, try a free prop, help somebody, see progress toward the nameplate. Returning players should see the nearest unfinished goal and what Friday refreshes versus what persists. Keep this inside a dismissible panel; preserve the playfield and the original cutout art. No tutorial purchases or automatic paid actions.

## Bounded work prepared during this audit

Prepare the compatible journal-only payload and its before-reset/after-reset fixture path. Fix the reproduced resource-error race and unconfirmed fitting-price purchases. Refresh open records without losing an unsaved loadout, refresh current state after an older saved receipt, and replace three undefined getMe callbacks with the existing sync method. Record the repeatable-content design above before implementing it. Keep the larger gameplay pack as a reviewable proposal rather than silently adding a new currency, trading market, loot-box system or new engine.

Required proof for the bounded work: journal-only installation leaves every player field and all core economy/reset function definitions unchanged; retained and new deeds survive normal rollover; hush stays private; the full installer works with and without the earlier journal; repeating or downgrading installers cannot damage history or project credit. Browser tests must reproduce the profile/status race and slow/failed quote cases with synthetic data. The complete three-job gate must pass on the resulting PR head.

## Friday decision

The verified next cutoff is Friday November 13 at 4 PM Pacific (`2026-11-14 00:00 UTC`). The safest proposed sequence is the small history-only installation before that cutoff, followed by the complete feature release after independently confirming normal rollover. Capturing history in its existing database avoids depending on a private export to a local file.

Publishing every economy change before Friday is a different option: earned-Seniority reconciliation can change output and Cover changes behavior during the closing competition; a project launched late also has a shortened first week. That needs a deliberate release decision and communication. This audit does not apply either option, force a reset, or schedule an automatic deployment.

## Build order after review

1. Journal preservation and the confirmed reliability fixes.
2. Rotating projects, immutable dated mementos and a visible next collection goal.
3. Receipt Clip plus capped earned resupply, balanced together.
4. Additional earned decorations and a short first-session route.

For each addition: specify earning/spending rules, simulate casual and dominant play, test retries/concurrency/rollover, inspect phone/desktop art, then add it to the held build. Preserve current inventory, the existing cast, private history and the separate Idle Hands 2 repository boundary.
