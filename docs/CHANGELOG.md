# Idle Hands — Development history

This is a concise human-readable chronology, not a substitute for Git history or SQL migrations. Update this in every behavior-changing PR with date, outcome, PR/commit and test evidence.

## 2026-10-20 and earlier: core product
- React/Babel one-page game built with Supabase-backed auth, BW idle production, hire/upgrade catalogs, Seniority restructuring, social actions, gifts, collectibles, events, office exploration, achievements, leaderboards and weekly recap.
- Product reset authorized for beta; legacy accounts/progress wiped. Beta badge granted to new records created through Nov 20, 2026 PT. Never run reset without explicit authorization.
- Characters expanded: Chance, Dave and Jess/John/Kyle/Matt/Avah/Nick/Rilie/Joey. Equal-probability shuffled guest turns replaced alphabetical/scheduled priority; max three NPCs. Joey's construction joke and Matt–Nick bingo exchanges added.
- Jess's Mericans/slushies boosts and Chance's poison-oak dialogue added. Server economy strengthened around temporary modifiers.
- Audit fixes: Resale discounts reflected in UI, price quotes refreshed after sync/restructure, restructure clears active buffs/frenzy and resets last_tick, server accrual integrates historical timed events and 77-second chair frenzy.
- Vercel project linked to requested custom domain, but public DNS unverified.

## 2026-10-20: Office Nonsense, PR #1
- Merged as `a2bb5ce4` following successful GitHub Actions regression check.
- Added six optional comedy features, not additional BW currency or new forced modal.
- Existing While You Were Out and targeted incident notifications deliberately preserved.

## 2026-10-20: CI/handoff hardening, this PR
- Strengthens executable regression assertions for cost growth, reset-at-zero pricing, resale discount, NPC casts and 100 shuffle rounds, deterministic log and UTC daily rollover.
- Makes agent-specific context documents and release checklist mandatory for next chats.
- Follow-ups: add real browser/playwright visual smoke tests and a dedicated non-production Supabase economy fixture, then enforce required CI as GitHub branch protection. Do not claim these are implemented unless verified.

## 2026-10-20: Browser and isolated Postgres regression gate
- Added Chromium page-load tests at 1440px and 390px, and temporary PostgreSQL synthetic pricing/reset assertions in CI. No production player data accessed.
- Mandatory status-check branch protection and an authenticated test Supabase project are still separate follow-ups until configured/verified.

## 2026-10-20: Cutout art integration
Original vector-cutout illustrations integrated into existing hiring rows, approvals and cosmetic catalogue with consistent outlines, palette and no new hitboxes or economy impact. Rotating NPCs gain heavier ink lines, sleepy expressions and role props. Avah hair blonde and Rilie brunette. Current generated art-direction posters remain concept art; hand-coded SVGs are production visuals, not automatic sprite exports. No authenticated full-world visual QA yet.

## 2026-10-20: Cutout character, costume, office kit and UI art — PR #4
- Added original vector menu art with ink outlines and semantic category grouping across existing catalogs, without new items or changed prices.
- Unified ten office characters' cutout silhouettes and props. Avah is blonde, Rilie brunette.
- Refreshed player wardrobe strokes and office desk/chair/rug levels, and flattened familiar office fixtures.
- Added read-only `?art-preview=1` and Chromium screenshot artifacts for art QA with phone, desktop, tabs and overflow checks.
- Concept artwork was used as visual guidance, not copied as bitmap assets. A full authenticated in-office visual playthrough has not been completed.

## 2026-10-20: Character builder & permanent wardrobe (PR #5)
- Builds free first-day character creator using cutout sprite head, selectable body style, hair, eyes, expression, skin color and starter shirt; no mandatory uploaded photo.
- Adds free mirror appearance changes for existing players, permanent BW-priced outfit collection, own-and-equip restrictions and cross-device server save.
- Adds actual RPC isolation tests for wardrobe purchase/ownership and Playwright creator preview at phone/desktop. Database changes are additive and intended to preserve Seniority and inventory through resets.

## 2026-10-20: Avatar overlap fix and closer cutout art — PR #8
- Removed the inherited round badge layer from character creator heads; unified the actual game renderer and previews.
- Redrew the small avatar face/hair shapes and enlarged the onboarding preview for visibility on phones.
- Replaced flat rectangle desk props with illustrated tier-aware desk SVGs and differentiated permanent clothing thumbnails.
- Added browser checks for old-mask regression and non-authenticated real onboarding layout, plus archived phone/desktop screenshots.
- No economy RPCs, item ownership IDs or production player records changed.

## Build 154 candidate: unified cutout world

- Recovered and visually compared original/updated concept sheets, with source identities and acceptance gaps in `VISUAL_REDESIGN.md`.
- Unified all ten NPCs with the player avatar rig; improved face, body proportions, clothing/role details, hand skin tones and emote expressions. Removed legacy head mask from custom HUD/list faces too.
- Illustrated five desk/four chair tiers, kitchen and service fixtures, companions and scenery; unified floors/cubicle/nameplate/HUD surfaces and improved phone target sizes and sprite readability.
- Corrected depth sorting so actors can stand behind their desks. Kept map geometry, collisions, paths, items, prices, timers and server API unchanged.
- Self-hosted pinned browser dependencies after reproducing a CDN startup failure. Added full game UI tests with isolated HTTP fixtures and touch emulation; kept existing PostgreSQL contract jobs.
- No production player data or SQL changed. Live authenticated and physical-device verification remain outstanding; exact concept-art fidelity not claimed.
- CI follow-up: restricted Playwright discovery to browser spec files; kept the Node helper regression in its own dependency/job boundary. All six local browser tests passed after the correction.
