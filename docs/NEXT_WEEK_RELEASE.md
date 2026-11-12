# Next-week office package - RELEASE HOLD

User-authorized implementation on 2026-11-12. **History-only exception: Nick explicitly authorized it, and migration `20261112195653_office_action_journal_history_only` is now live.** See [receipt](HISTORY_ONLY_RELEASE_2026-11-12.md). Do not reapply it. **The remaining full package stays held: do not merge the frontend, apply the full migration, trigger a reset, change live balances/inventory, or release automatically.** Target release is after normal Friday 2026-11-13 16:00 America/Los_Angeles rollover is independently confirmed.

Base: GitHub main `9d622b9123c0e71c391637ec4a68335a8fcbb61f`. The local source checkpoint `9501f8a` has the identical complete root tree (every root blob/tree hash verified through the GitHub app). The approval UI is failing; use local source and connected GitHub operations, not repeated permission prompts. Remote feature commits use current main as parent.

## Accepted implementation contracts

- Durable journal of successful targeted actions, exactly once by source deed ID. Public statistics exclude hushed events; direct notification privacy is unchanged. Backfill only retained deeds, report coverage, never fabricate prior seasons. Lifetime history survives Friday.
- Seniority output uses earned points this week; available points remain spendable. Reconstruct earned points from available plus verified fixed-cost owned perks, then record new earned points explicitly. Friday clears both weekly balances and perks.
- Cover becomes a nonstacking, 20-minute +15% recipient benefit, never a BW transfer. Existing owned cosmetics and styles survive unchanged.
- Permanent fittings, pins and recoloring use a retained base-production high-water benchmark (minimum 0.25 BW/sec), excluding temporary bonuses/debuffs. It is monotone across restructures/weekly resets. Existing peak history is unknown: initialize from current production and track forward honestly. Quotes and actual charges share the same benchmark.
- Phone world taps move only; explicit contextual controls activate fixtures, desks, scenery and shared chair. Directory and keyboard are intentional shortcuts. Drags cancel movement and queued interaction. Minimap/emotes are collapsible on phones. Charts stay inside details.
- Rotating weekly project with three frozen eligible categories. Base: nine eligible player/category stamps and three contributors; optional stretch: fifteen and five. All four personal categories are still retained for individual rewards. No BW donations, income-sabotage requirement or retrospective awards. Dated mementos archive automatically and late eligible contributors can earn them.
- Permanent nameplate (work+care), Incident Corkboard (three categories) and project plaque (completed project plus relevant participation), plus terrarium/duck/lamp at two/four/six qualifying weeks. A qualifying week has work plus another category across two Pacific dates; it need not be consecutive. Display at most three owned decorations and choose a dated plaque. No competitive output bonus.
- Two-slot weekly toolkit: Rescue, Confetti, Spam Filter and Receipt Clip, two charges each. Clip halves one eligible positive theft after passive defenses. Work plus another activity on the same Pacific date earns at most one restored charge; maximum three claims per week and two charges per tool. Swapping never refills. Received attacks earn no supplies.
- Return to Sender is one separately purchased armed shield. Confirmed two-minute quotes use twice the most expensive sabotage at the base-production benchmark retained within the current week, excluding temporary bonuses and department discounts. No stockpile, free rearm or reflection chains. The sender pays their original cost/cooldown and receives their own hostile payload with passive defenses. Reflection precedes other active defenses. Actual-debit transfers reserve the attack cost; returned blame heat survives the original cleanse. Ordinary sabotage stacking stays intact.
- Social actions and defensive purchases have actor/request-bound receipts. A sender can explicitly recover an unconfirmed action even during cooldown. One original deed records a reflected attempt as blocked; actual reflection metadata remains private and obeys hush exclusions. The normal weekly output-perk description discloses its reset.

## Verification and release

All existing regression jobs plus new actual-SQL contracts and browser walks must pass on the exact candidate. Test anonymity, source-key replay, backfill, concurrency, boundary rollover, pricing, Seniority gains, tools, rewards and responsive controls. Never exercise real-account mutations. Keep unperformed tests explicit.

Before live release: reconcile newest main/Production, inspect normal rollover completion via season_state and seasons (read-only), review current candidate SHA/migration hash, preserve a read-only statistics snapshot if wanted, then apply additive migration and verify before merging frontend. Do not call sync/accrue/roll_week to force rollover. If reset is delayed or the package is not ready, hold. A time on the clock is not evidence of a completed reset.

Rollback frontend first; preserve lifetime history, earned collectibles, style records and receipts. Forward fixes are preferred to restoring the gift exploit or deleting progress. New work remains isolated from Idle Hands 2.

## Review and continuation

Draft PR: https://github.com/dadbod87/idle-hands/pull/56. The PR head and its complete three-job gate are authoritative. Remaining candidate files are held; only the journal-only migration has been applied. No main merge, full-package migration or automatic release.

The held SQL settles existing capped offline accrual under the old functions before switching Seniority. It does not call sync, accrue or roll_week during installation. It requires season_state.current_week to match week_key at transaction time. The normal recap classifies Rescue as help. All fourteen replaced functions have audited-definition guards; the earned-point reconstruction also guards the fixed perk costs. Targeted social RPCs acquire one common transaction lock before locking either player, preventing opposite-direction deadlocks in this small office. The concurrency harness exercises actual RPC bodies in separate disposable sessions.

Profiles distinguish retained older events from the beginning of continuous tracking. The private November 12 snapshot retains 942 deeds at 09:13:48 Pacific; it is not the final pre-reset history. Actions occurring later and deleted before installation cannot be reconstructed from that snapshot. The live journal now backfills all 946 retained events and captures later deeds inside the existing database; a fresh local export is not needed for these captured events. Never force rollover for a snapshot or test. An optional earlier private export may only be imported after source-identity review if it contains genuinely missing events. Do not add player history or import SQL to this public repository.

Before the held release:

1. Confirm the reviewed candidate SHA and all three completed-success jobs; inspect its desktop, portrait and landscape screenshots. Keep physical-phone/authenticated-isolated gameplay distinct from fixture evidence.
2. Independently read current main, deployed build, season_state and the completed seasons row after Friday November 13, 16:00 Pacific. If rollover is incomplete, hold.
3. Generate a migration with the installed Supabase CLI, copy the exact reviewed payload, and compare SHA-256. Inspect current function hashes and the perk cost guard before applying. Never test the payload against live accounts.
4. Apply the additive backend once, then verify function hashes, private-schema grants/RLS, journal/backfill counts, earned-versus-available counters, retained peak rates, permanent inventory/styles and correct catalog Cover behavior. Installation legitimately settles old offline earnings, so compare that settlement with the old capped accrual formula rather than expecting unchanged balances.
5. Verify existing journal coverage and survival of normal rollover. No export is required for captured events. Any optional earlier import needs source-identity checks and hush protection; label missing coverage honestly.
6. Only after backend verification, release the reviewed frontend and verify Vercel READY, served artifact and browser behavior. The candidate preview blocks access to live accounts; it is not an isolated hosted game backend.
7. If a problem appears, revert the frontend first and preserve journal, rewards, receipts and styles. Prefer a forward database fix. Do not restore the cash-gift exploit or delete progress as a rollback.

The former follow-up ideas are now built into the held depth pack; see OFFICE_DEPTH_CONTRACT.md. Review casual/coordinated play, quote failures/replays, concurrent defenses and supplies, dated rewards, phone art and progression before release. Avoid another instantly completed cash-only catalogue.

## Second audit: optional pre-deadline history stage

The [second audit](SECOND_AUDIT_2026-11-12.md) recommends preserving the journal before Friday while leaving the full economy/content release until after normal rollover. Nick subsequently explicitly authorized this separate stage, and it is now live; see the receipt. The full economy/content release remains held until verified normal rollover.

`sql/office_action_journal.sql` is the immutable, reviewed journal-only payload already applied once. It creates the private journal/coverage/classifier/capture trigger and backfills currently retained deeds. It updates no player row, replaces no public function, grants no client access, starts no project and calls no reset/accrual function. It refuses an existing journal or a downgrade after the full package. Keep it installed on any rollback so history survives.

The full payload contains a generated copy of the same core. When an earlier journal exists, it validates its version marker, columns, primary keys, coverage row, helper bodies, RLS, trigger and grants, then reuses it without deleting or re-awarding history. The full capture function adds future project credit only after that installation. Both direct full installation and journal-first installation have isolated fixtures. The generator is canonical; do not hand-edit the embedded core.

The stage was applied through the provider migration tool. Its generated ledger version, exact stored payload, helper definitions, privacy and backfill were verified. Public economy/reset functions and catalog are unchanged; the payload performs no player writes. Do not run the standalone installer again. Existing gameplay can then record new deeds into its private journal through the ordinary trigger. After verified normal rollover, apply the reviewed full package and frontend using the existing checklist. No local export is necessary for captured events. If the first stage is not installed until after reset, it cannot restore deleted events that were never captured.

The later depth pack implements the design proposals in held source, with its current contract in OFFICE_DEPTH_CONTRACT.md. PR #56 records current candidate hashes, completed checks and remaining review limits; earlier green results do not certify a later head.

The record-book/cosmetic continuation is documented in RECORDBOOK_AND_COSMETICS.md. A separately reviewed private standings-capture payload can preserve this week before reset; it changes no player/catalog/public economy function. Its live status must be recorded explicitly. New garment IDs also extend the existing guarded ownership resolver so paid color/design changes and free equip work correctly. Exact-head API, SQL, visual and browser evidence belongs to PR #56.
