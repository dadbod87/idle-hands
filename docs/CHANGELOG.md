# Build 174 — conflict-resolution training (2026-10-22, candidate)

Adds The Productivity Flatscreen in Your Desk → Catalogue → Your Office, with its own permanent TV slot. Original inked TV art is shared by the purchase thumbnail, free preview and office wall. Four self-hosted Springer stills rotate every 10 seconds only while visible and the tab is active; reduced motion holds the still, and tap/keyboard advances it without a popup or currency effect. Existing desk, chair, rug, wall art and paths are preserved. Source credits/third-party provenance: assets/tv/SOURCES.md.

Price is server-authoritative: max(50,000,000 BW, three days of current effective output). Migration 20261022170845_premium_springer_tv changes only the existing fitting quote/purchase formula to honor optional per-item min_cost, then appends tv1 to office_kit. Existing items have no min_cost and retain exactly their old prices. No player writes, schema, grants, multiplier, reset or capacity changes. TV uses existing kit persistence through restructuring and weekly rollover. SQL guard aborts if function implementations have changed unexpectedly or tv1 conflicts.

Local parser/name checks and all eight isolated PostgreSQL fixture suites passed, including actual TV quote/purchase bodies. Eight focused desktop/Pixel 7 browser checks passed: previews, failure/success charging, all screens, reload/old decor, affordability, four WebP responses, automatic rotation, reduced motion and hidden-tab pause. World/gallery screenshots visually reviewed. Required CI and production evidence belong in the release PR. No production test accounts or purchases. Physical-phone gameplay remains unverified. CLI generated the migration filename, then automatic approval review rejected its PostHog analytics contact; no retry/bypass. Deployment uses the existing native database connection.

Rollback: revert frontend; additive catalog TV can remain installed. Avoid removing a purchased TV's catalog ID; retain stored kit.tv. SQL price changes are no-ops for pre-existing items.

---

# Build 173 — you found nothing (2026-10-22)

The invite-door joke now has its own warm-gold, readable line instead of disappearing into 10px low-opacity fine print. Supporting copy is 12px opaque text. Invite validation, account creation and gameplay are unchanged. Frontend rollback: revert this release.

The owner separately authorized a fresh-launch production account reset. Executed once through the connected Supabase SQL tool against project wbakpxbvqxppqbrwuokp: four Auth accounts and three characters removed, along with refresh tokens, sessions, player/social history, suggestions, seasonal winners and shared participation. Independent read-back confirmed accounts/characters/sessions/refresh tokens/event claims/shared activity all zero. Hash guards preserved all 26 catalog rows, public game-function definitions and door settings except the now-empty admin pointer; the existing first-new-player admin assignment remains. No schema, RPC, invite-code or schedule change. This is an explicit administrative operation, not a regression test or weekly rollover. The guarded one-time SQL is archived under ops/ and must never run automatically. Six legacy uploaded badge photos remain in Storage; connected tools expose no Storage deletion API. Clean them through Supabase Storage → badges, retaining the bucket and policies. No claim of complete uploaded-file erasure.

Canonical game address is now https://idlehands.thepatrongrp.com/ (same Vercel project and Supabase database); https://game.thepatrongrp.com/ is the separately hosted hub. These user-confirmed DNS/TLS changes supersede the old-domain notes below. Old address forwarding has not been enabled.

Validation: local JSX/economy and approved-name checks passed. After installing missing Chromium, both desktop and 390px entry browser tests passed; screenshots visually reviewed for legibility and clipping. No production account was created. Required CI gates and live deployment verification pending; exact evidence belongs in PR.

---

# Idle Hands — Development history

This is a concise human-readable chronology, not a substitute for Git history or SQL migrations. Update this in every behavior-changing PR with date, outcome, PR/commit and test evidence.

## 2026-10-22: Build 172 — above the paperwork
- Restored visible prop punchlines as compact text-only speech bubbles matching the cigar-lounge style, positioned above prop and character.
- Measure actual text height and retain feedback-strip fallback when camera headroom is insufficient; no large illustrated cards return.
- Desktop/phone/landscape regression coverage, no player data or backend changes; release evidence in PR.

## 2026-10-22: Build 171 — let the office perform
- Removed the obstructing illustrated popup from all prop actions; jokes use the feedback strip below the floor. Confirmation/error messages remain visible alongside the caption.
- Watering can sits beside the plant; couch shows the seated character without a card. Small world effects, saved jokes, reduced motion and shared participation remain.
- Desktop/phone/landscape and paperwork/lounge/printer browser checks guard against popup recurrence; release evidence in PR. No backend/player-data change.

## 2026-10-22: Build 170 — a little more headroom
- Fixed camera-edge clipping caught in the hosted desktop smoke after build 169. Full scene cards stay in the current viewport; short landscape views use compact text beside the actor. No backend/data/economy change.
- Replaced the blue-box watering can with one shared illustrated can: open loop handle, rounded reservoir, fill opening, angled spout, brass shower rose and droplets. Both world effect and scene card use it.
- Explicit scene bounds checks added for desktop, phone portrait and short landscape; required CI and deployment evidence in release PR.

## 2026-10-22: Build 169 — questionable responsibilities
- Fixed ambient/partner bingo collection, memo failure draft retention/pending sends, and chair approach interaction.
- Added free original animated prop performances, rotating punchlines, sitting/watering poses, optional field guide, Help discoveries, and 36 non-adjacent-repeat log gags. Successful real printer fixes get a confirmed visual joke.
- Added persistent weekly office votes, named cosmetic commendations/certificates with honest ties and past results, actual watering leaders, and shared lounge milestones. Pacific Friday 4pm cycle; no Busywork rewards or player-row changes.
- Additive restricted/RLS migration, actual SQL contracts and desktop/phone/two-player fixtures cover data preservation and failure cases. Acceptance and evidence in COMEDY_RELEASE_2026-10-22.md and release PR.

## 2026-10-21: Build 168 — musical chairs
- Good chair can appear throughout usable map space, with equally weighted safe locations outside all private offices, fixtures and solid scenery. Shared deterministic window selection preserves one location for every client.
- Timing/claims/rewards unchanged; backend inspected read-only, no migration/player writes. Distribution, geometry, connectivity and desktop/phone fixture interaction evidence tracked in PR.

## 2026-10-21: Build 167 — room for nonsense
- Fixed clipped Office Nonsense navigation: all six buttons, including Awards after Lounge, fit in two rows with wrapping labels and selected-state accessibility.
- Feedback notifications stay below open dialogs instead of painting over their controls.
- Responsive browser checks activate every section and verify the joke award without changing player progress. No data, economy or reward changes; exact CI/release evidence in PR.

## 2026-10-21: Build 166 — a place for everything
- Corrected oversized apology/notice art, tiny water cooler framing and printer-label planter overlap.
- Shelf, couch and break notice now open free illustrated readings; couch/notice connect to actual break-table activities.
- HUD Sound opens Sound & feel without muting; removed directory footer shortcut. Saved preferences/defaults preserved.
- Keyboard movement restored after scenery readings. Browser coverage checks new interactions, retained progress, direct sound access and saved settings; release evidence in PR. No database or economy changes.

## 2026-10-21: Build 165 — familiar faces
- Owner explicitly reversed anonymization: original first-name cast, roles, lounge, brand/mascot, catalog, memo and raise-message names restored. Internal IDs and all player data remain intact. Active agent rule and CI guard now protect approved original names; historical records remain unchanged.
- Calendar/plant rotas/printer apology open accessible, free illustrated readings. Apology moved beside printer and explained. Printer joins walking directory; decorative scenery still passes movement clicks.
- Node regression passes; focused and full desktop/mobile browser, isolated SQL and deployment evidence recorded in release PR. No physical-phone or authenticated production writes claimed.

## 2026-10-21: Build 164 — sound on
- Sound defaults to enabled at 100%, as requested. Saved mute/volume choices still apply.
- Existing sound contract covers fresh defaults and preference reload; no data or economy changes. CI/deployment evidence in release PR.

## 2026-10-21: Build 163 — the coffee has a subplot (candidate)
- Implemented the four requested polish stages: lived-in office zones, confirmed action reactions and office sound cues, compact measured mobile controls, opt-in coffee breaks and recurring social/prop humor.
- Volume/mute persist locally; hidden tabs and rapid repeats stay quiet. Existing sound control preserved; new Sound & feel auditions added. No voice service credits used or new third-party assets imported.
- Kindness notes use existing server deeds; live invitations/waves are transient cosmetics. Existing office status gets an initial/visible refresh. No database migration, balance change or player reset.
- Stage tests: environment desktop/phone; sound graph and purchase failure/success; seven mobile/dialog/scroll checks; two-player isolated broadcast/deed flow. Exact full regression, screenshots and live deployment in release PR. Physical-phone and authenticated production E2E remain unverified.

## 2026-10-21: Build 162 — find your people (candidate)
- Reviewed original concept direction, actual gameplay and read-only server contracts; prioritized environment composition, outcome feedback, mobile hierarchy and social comedy in `POLISH_REVIEW_2026-10-21.md`.
- Illustrated/labeled emotes, labeled utility controls and ten-stop walking directory. Existing movement, economy and social actions retained; fictional-office changes preserved.
- Migration preserves permanent desk/vanity purchases and spending through seasonal rollover; revokes direct client access to internal reset helper. No production reset executed. Actual function tested only in isolated PostgreSQL.
- New desktop/phone fixture flow; fictional-name guard joins CI. Local parser/helper/name checks and focused browser checks pass; full CI/migration/live evidence in PR. Physical-device and authenticated production checks remain unverified.

## 2026-10-21: Fictional office — public game uses no real people or company
- Every character, role, brand, place and joke target in the game is now fictional (Example Property Co.; Wes, Hal, Nora, Gus,
  Rory, Theo, Iris, Bramblewick, Pip, Wren, Lena). The nameplate job list matched against players' first names is empty.
- New logo and a logo-free entry background (the previous artwork carried a real company's mark).
- Migration `20261021200000_fictional_office_catalog.sql`: catalog **text** in six rows and one server message; ids, prices,
  numbers and catalog keys unchanged (asserted in the migration). Dry-run on Production read-only before applying.
- Persistent identifiers kept on purpose: catalog keys `chance_extra` / `dave_extra`, item / achievement / deed ids, storage keys.
- Player accounts, names, progress, purchases and relationships are untouched (no player table is written).
- New guard test `tests/fictional-names.test.cjs` (hashed deny-list, words and identifier parts). Run it with `node tests/fictional-names.test.cjs`; adding it to the CI workflow is a follow-up (needs a token with the GitHub `workflow` scope).

## 2026-10-20 and earlier: core product
- React/Babel one-page game built with Supabase-backed auth, BW idle production, hire/upgrade catalogs, Seniority restructuring, social actions, gifts, collectibles, events, office exploration, achievements, leaderboards and weekly recap.
- Product reset authorized for beta; legacy accounts/progress wiped. Beta badge granted to new records created through Nov 20, 2026 PT. Never run reset without explicit authorization.
- Characters expanded: Wes, Hal and Nora/Gus/Rory/Theo/Iris/Bramblewick/Pip/Wren. Equal-probability shuffled guest turns replaced alphabetical/scheduled priority; max three NPCs. Wren's construction joke and Theo–Bramblewick bingo exchanges added.
- Nora's Mericans/slushies boosts and Wes's poison-oak dialogue added. Server economy strengthened around temporary modifiers.
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
Original vector-cutout illustrations integrated into existing hiring rows, approvals and cosmetic catalogue with consistent outlines, palette and no new hitboxes or economy impact. Rotating NPCs gain heavier ink lines, sleepy expressions and role props. Iris hair blonde and Pip brunette. Current generated art-direction posters remain concept art; hand-coded SVGs are production visuals, not automatic sprite exports. No authenticated full-world visual QA yet.

## 2026-10-20: Cutout character, costume, office kit and UI art — PR #4
- Added original vector menu art with ink outlines and semantic category grouping across existing catalogs, without new items or changed prices.
- Unified ten office characters' cutout silhouettes and props. Iris is blonde, Pip brunette.
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

## 2026-10-21: Build 155 mobile onboarding help scroll fix

- Restores vertical scrolling on shared card dialogs after the cutout-world CSS accidentally overrode it with hidden overflow.
- Keeps cards within the current mobile viewport, enables touch panning, and preserves separate panel-body scrolling.
- Adds portrait/landscape touch-swipe regression coverage reaching and tapping Start earning at the bottom of Help. Node regression passed locally; local Chromium installation was blocked by download errors. Require all three CI jobs green before release. No player data, APIs or economy changes.

## 2026-10-21: Build 156 body style fix and illustrated head collection

- Fixes the unused body-style setting by giving every style/build combination its own torso path in the shared player/NPC rig.
- Adds nine free head shapes, including alien intern, robot employee, cyclops, frog accountant and paper bag; keeps familiar human faces and existing player looks.
- Adds a visual head picker, Surprise me, pants colors and accessible selected swatches. Special heads explain their fixed silhouette; hidden hair choices are retained.
- Extends the authenticated appearance RPC with a validated head field. Installation does not rewrite players, spend BW or reset inventory; older clients keep a stored head when omitted.
- Expands desktop/phone browser playthrough and actual isolated Postgres RPC contracts. Release, migration and exact verification evidence are recorded in the PR; physical phone and authenticated production gameplay are not claimed.

## 2026-10-21: Build 157 supply-closet try-on previews

- Replaces repeated category icons with actual rendered costume/character miniatures for all 11 supply-closet items.
- Adds free, expandable previews on the selected person's appearance, with an explicit purchase hint on the existing buy row.
- Uses shared Body/Hat/CostumeSuit rendering so the preview and equipped floor appearance stay consistent; pauses animation within the preview only.
- Adds actual Wardrobe gallery and desktop/phone fixture tests for every costume, recipient changes, preview without spending and purchase/equip continuity. No economy, inventory, SQL or production-player changes.

## 2026-10-21: Build 158 office personality

- All 34 catalog items get specific previews, with shared equipped artwork for furniture, held items, rugs, wall art and personal effects. Free expanded previews work before an item unlocks.
- Corrects desk material finishes and adds chair mesh/lumbar/leather details. Replaces break table's ambiguous tray with donuts, mugs, chairs and a napkin.
- Adds eight goal-based cosmetic Personnel commendations emphasizing kindness, reciprocity and collaboration alongside collection and streak milestones, plus eight light office memos.
- New award claims derive from stored server stats; new IDs cannot be asserted by a client. Existing awards/progress are merged and retained. No currency or productivity reward changes.
- Adds isolated PostgreSQL eligibility/auth/retention tests and phone/desktop actual UI/catalog/awards verification. Deployment and exact test evidence are recorded in the PR.

## 2026-10-21: Build 159 weekly scoring countdown

- Adds a live countdown and exact cutoff to the wall whiteboard and This week leaderboard, with office timezone and viewer-local time in the expanded panel.
- Reads the existing server boundary (Friday 17:00 America/New_York currently) through a new authenticated, read-only schedule RPC; no changes to points, resets, purchases or stored players.
- Keeps daylight-saving calendar weeks accurate and never uses a wrong device clock as the countdown anchor. Resynchronizes while visible/on return and waits for the server at the cutoff.
- Adds isolated SQL boundary/DST/auth tests, countdown helper checks and actual whiteboard navigation tests at desktop/phone sizes. Exact gates and live release state are tracked in the PR.

## 2026-10-21: Build 160 Friday 4 PM Pacific

- Changes actual server week boundaries and week keys to Friday 16:00 America/Los_Angeles, following Pacific daylight saving automatically.
- Countdown RPC and read-only gallery use the Pacific deadline. This week ends Oct 23 at 4 PM PDT / 23:00 UTC.
- Migration guards the active season key and does not reset progress or shift unrelated office-hour earning bonuses.
- Adds isolated boundary/DST/year/unchanged-player contracts and updates desktop/phone countdown expectations. Final gate, migration and deployment evidence is tracked in the PR.

## 2026-10-21: Build 161 worn pin rendering

- Fixes equipped beta/weekly pins missing from character models by rendering the catalog pin on the chest inside the shared animated rig.
- Keeps pins visible over costumes and preserves existing leaderboard pins, ownership validation and stored selection.
- Improves HR pin buttons with accessible Wear/Remove names, selected state and Wearing feedback.
- Adds desktop/phone HR equip/reload/remove/replace checks and costume-layer gallery coverage. No server, economy or inventory changes.
# 2026-10-22: TV recovery camera correction (build 174 candidate)

- Frame the measured prop punchline, whole prop and actor together when the camera has room; preserve short-viewport feedback-strip fallback and strict clearance assertions.
- Remeasure bubbles on actual size changes, including font/layout changes.
- Add deterministic checks using the actual camera helper for tall props, varied text/viewport heights and impossible room-edge/short layouts.
- Recovery session verified the saved PR/main heads and failed CI logs. Local parser/economy/name/sound/social/chair/comedy checks passed. Production migration/release remain blocked by Supabase SQL approval denial and Vercel team-scope 403; live TV screenshots remain unperformed. No player data changed.

