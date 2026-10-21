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
