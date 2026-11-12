# Next-week office package - RELEASE HOLD

User-authorized implementation on 2026-11-12. **Do not merge to main, apply to Production, trigger a reset, change live balances/inventory, or release automatically.** Prepare, test, review and continue improving first. Target release is after the normal Friday 2026-11-13 16:00 America/Los_Angeles rollover is independently confirmed.

Base: GitHub main `9d622b9123c0e71c391637ec4a68335a8fcbb61f`. The local source checkpoint `9501f8a` has the identical complete root tree (every root blob/tree hash verified through the GitHub app). The approval UI is failing; use local source and connected GitHub operations, not repeated permission prompts. Remote feature commits use current main as parent.

## Accepted implementation contracts

- Durable journal of successful targeted actions, exactly once by source deed ID. Public statistics exclude hushed events; direct notification privacy is unchanged. Backfill only retained deeds, report coverage, never fabricate prior seasons. Lifetime history survives Friday.
- Seniority output uses earned points this week; available points remain spendable. Reconstruct earned points from available plus verified fixed-cost owned perks, then record new earned points explicitly. Friday clears both weekly balances and perks.
- Cover becomes a nonstacking, 20-minute +15% recipient benefit, never a BW transfer. Existing owned cosmetics and styles survive unchanged.
- Permanent fittings, pins and recoloring use a retained base-production high-water benchmark (minimum 0.25 BW/sec), excluding temporary bonuses/debuffs. It is monotone across restructures/weekly resets. Existing peak history is unknown: initialize from current production and track forward honestly. Quotes and actual charges share the same benchmark.
- Phone world taps move only; explicit contextual controls activate fixtures, desks, scenery and shared chair. Directory and keyboard are intentional shortcuts. Drags cancel movement and queued interaction. Minimap/emotes are collapsible on phones. Charts stay inside details.
- One weekly project: 12 category stamps, at least 3 contributors, at most one stamp per category/player/week (work, facilities, care, playful). Server-verified actions only; no BW donations. Async contributions, permanent completion history.
- Permanent nameplate (work+care), Incident Corkboard (three categories), and project plaque (completed project plus participation). Claim once, replay safe, no competitive output bonus.
- Two-slot weekly toolkit: Rescue, Confetti and Spam Filter, two charges each. Slot changes cannot refill charges. Rescue removes one eligible coworker debuff; Confetti is temporary/removable and has no income penalty; Filter blocks one eligible incoming debuff. Shared cooldowns and server receipts prevent spam/replays. No victim-farming rewards.

## Verification and release

All existing regression jobs plus new actual-SQL contracts and browser walks must pass on the exact candidate. Test anonymity, source-key replay, backfill, concurrency, boundary rollover, pricing, Seniority gains, tools, rewards and responsive controls. Never exercise real-account mutations. Keep unperformed tests explicit.

Before live release: reconcile newest main/Production, inspect normal rollover completion via season_state and seasons (read-only), review current candidate SHA/migration hash, preserve a read-only statistics snapshot if wanted, then apply additive migration and verify before merging frontend. Do not call sync/accrue/roll_week to force rollover. If reset is delayed or the package is not ready, hold. A time on the clock is not evidence of a completed reset.

Rollback frontend first; preserve lifetime history, earned collectibles, style records and receipts. Forward fixes are preferred to restoring the gift exploit or deleting progress. New work remains isolated from Idle Hands 2.
