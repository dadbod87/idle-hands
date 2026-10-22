# Build 169 — questionable responsibilities (2026-10-22)

Repairs ambient/partner bingo credit (cloned progress arrays, progress stamps, saved progress resumes), memo-draft loss on failure and duplicate pending sends, and good-chair UI reach (distant click routes toward it; a nearby second click claims). Existing chair timing/rewards unchanged; no server position tracking or anti-cheat claim.

Free prop performances: couch sitting, plastic-plant watering, printer apologies, meeting scheduling, urgent filing, mug amnesty and lounge planning. Six rotating punchlines each, original scene SVGs, sit/water poses, reduced-motion art, map-edge card clamping, and normal movement cancellation. Successful real printer fixes trigger a separate joke only after the server confirms the fix. No invented earnings. Optional field guide and Help introduce existing coffee invitations, costume previews, suggestions and bingo. Log expanded to 36 gags in deterministic shuffled bags without immediate repeats.

Shared additions use new dedicated RPC-only tables: one changeable weekly poll ballot/player, one changeable commendation/category/player for another real signed-in coworker, and bounded prop participation. Old-week ballots are rejected. Pacific Friday 4pm periods use existing week_key/week_started, including DST. Real aggregate counts, honest ties, last-week poll and honors, screenshot-ready certificates, actual plant-watering leaders, and four lounge milestones from real activity. All are cosmetic, without currency/ownership/player-row changes. The lounge remains closed and existing secrets stay functional. Missing service and failed filings show explicit errors/last confirmed records.

Migration: `20261022135640_shared_office_stories.sql` is additive. Tables have RLS and no direct anon/authenticated access; four public RPCs authenticate and require a signed-in player. Private aggregation/config helpers are not executable by anon/authenticated. Existing player rows, RPCs and economics are untouched. Frontend rollback can leave these additive tables/functions safely in place.

Validation/acceptance tracked in `COMEDY_RELEASE_2026-10-22.md` and release PR. Isolated actual migration contracts verify access, bad inputs, replay limits, changing ballots, previous-week separation and unchanged player snapshots. Browser fixtures verify real UI on desktop/phone, including two-player persistence and failure cases. No production test votes/claims/nominations or player resets. Physical phone and authenticated real Supabase gameplay writes remain unverified. Baseline Supabase advisory follow-ups are documented, separate from this feature. Release commit/CI/deployment evidence belongs in PR.

---

# Build 168 — map-wide good chair (2026-10-21)

Good-chair placement now selects an equally weighted point from a dense, cached pool across the entire usable map, replacing the east/central rectangle (x1150–3049, y700–1219). Every point excludes the full chair footprint plus clearance around all nine offices (including Chance's), fixture art/labels, scenery and solid decorative props; actual wall collision is also checked. Open floor/background zones remain eligible. A stable window hash selects the same point for everyone. Chair depth follows its floor position and its button has an accessible name.

Read-only production inspection confirmed chair_window supplies timing only and grab_chair does not accept coordinates. No server migration is needed; 7-minute schedule, 40-second visibility, claim behavior, Quick Hands grace, reward chances and rewards are unchanged. No player data was modified. Validation: parser/economy and approved-name contracts pass; chair contract verifies all 1,527 points and 20,000 windows for determinism, distribution, bounds, office exclusion and walkable connectivity. Two Chromium tests pass (desktop and Pixel 7 emulation): walk to opposite map edges, render the chair, reject a fixture claim without awarding anything, then apply an explicit successful server fixture response. Screenshots reviewed. CI/deployment evidence in release PR. Physical phone and real production claiming are unverified. Rollback: frontend revert; advise open clients to refresh to use the same placement version.

---

# Build 167 — all Office Nonsense sections visible (2026-10-21)

The six Office Nonsense buttons now use a scoped three-column/two-row grid instead of an overflowing catalog switch row. The hidden sixth button was Awards (the cosmetic Employee of the Minute joke). All labels wrap and targets remain at least 44px tall; selected state is exposed with aria-pressed. Other catalog/tab layouts are unchanged. Feedback toast flex items no longer retain a high z-index above open dialogs.

Frontend-only; no database, player progress, economy, awards qualification, localStorage or server behavior changed. Focused desktop, narrow phone and landscape tests activate all six sections without horizontal scrolling and verify Awards content and unchanged fixture progress. Required CI/deployment evidence is recorded in the release PR. Physical phone and authenticated production writes are not claimed. Rollback: revert this frontend change.

---

# Build 166 — prop scale and direct sound settings (2026-10-21)

Frontend-only correction to build 165: smaller unmounted apology sheet, smaller break-room noticeboard, properly filled/larger water cooler, and printer-area planter moved clear of its label. All seven substantial scenery props now open free readings (including Misc. Urgent shelf, couch and break notice). Couch/notice offer the existing walk to break-table social activities. Arrow movement remains available after an inspection closes; Enter/Space do not also open a nearby fixture.

The top-right Sound button opens the existing Sound & feel panel. Opening it does not change mute/volume. The redundant directory footer shortcut is removed; mobile More still offers sound settings. Default on/100% and explicit saved choices are unchanged. No SQL, RPC, player data, economy, catalog ID, schedule or ownership changes. Original names/brand remain intact.

Validation: local logic/name/sound contracts pass; focused desktop/phone checks and final required CI/release evidence recorded in the PR. Actual game uses isolated HTTP/WebSocket fixtures, not production player writes. Physical phone remains unverified. Rollback: frontend revert only.

---

# Build 165 — approved original names and readable scenery (2026-10-21)

This section supersedes earlier anonymization instructions below. The owner explicitly approved public use of the original first names and lounge/company names. Preserve these names; do not anonymize them again. Current display cast: Jess, John, Kyle, Matt, Avah, Nick, Rilie, Joey, plus Chance and owner Dave. Server memo resale references restore Angelica; Gwen was already unchanged. Internal cast aliases (nora/gus/etc.), player IDs, catalog IDs and storage keys intentionally stay stable. Original roles, first-name job plates, company branding/logo/background, mascot name, cigar lounge/humidor copy, notifications, achievements and server catalog text restored. Surnames stay omitted.

Calendar, two plastic-plant rotas and the printer apology are labeled world buttons opening free, keyboard-accessible inspection dialogs. The apology moves beside the printer with explicit context. Other scenery stays pointer-transparent; collision walls are unchanged. Printer added to the walking directory.

Migration `20261021203552_restore_original_names.sql` changes six exact-hash-guarded catalog text rows and only the existing ask_raise exception wording. No player table writes, reset, price, ownership, reward or schedule changes. Synthetic SQL checks actual migration, IDs/numbers and unchanged player snapshots. Local Node checks pass; full browser/SQL CI and production evidence belong in the release PR. Phone browser emulation is not a physical-phone test. Rollback frontend through Git; keep original-name catalog text unless the owner requests otherwise. Build 164 sound defaults remain on/100%, with saved preferences respected.

---

# Idle Hands — Current State / new-chat handoff

Updated: 2026-10-20 (America/Los_Angeles). Recheck deployed SHA and live configuration at the beginning of every session.

## Mission and product
A satirical multiplayer office idle game with the user-approved original first-name cast and The Patron Group branding. Users badge in, earn Busywork (BW), purchase staff, upgrades and cosmetics, interact and compete, then restructure for permanent Seniority. Intent: funny, approachable and rewarding to revisit; not demanding minute-by-minute attention.

## Runtime & ownership
- GitHub `dadbod87/idle-hands` / `main`; most application code in `index.html` (React 18 JSX transpiled by Babel at runtime).
- Vercel project `idle-hands`; known working https://idle-hands-one.vercel.app.
- Supabase ID `wbakpxbvqxppqbrwuokp` (production data, Auth, SQL RPCs). Do not embed new secrets.
- A custom domain attached earlier in Vercel is not in use; the public address is the Vercel URL.

## Economy
- Earn BW passively with server `accrue(uuid)`; click via `do_work`, purchases via `buy_item`, `buy_upgrade`; `restructure` exchanges cycle BW for Seniority.
- Ownership-based hire price growth (catalog tuning, observed 1.35); Resale department has 10% price discount; client must match server `ceil(...)`.
- Staff and upgrades reset on restructure; cycle/PP reset; temporary buffs, frenzy, heat cleared and `last_tick` reset; Seniority, perks, lifetime BW persist.
- Server `live_mult` and `live_mult_at`; idle `accrual_interval_gain` partitions time at event windows, Nora drinks, buffs, frenzy and hours. Offline cap remains 8 hours plus relevant perk/department modifiers.
- Caution: time-varying office-wide fund tiers/streak levels aren't fully historically reconstructed. Full authenticated economy regression suite remains to be built against a non-production DB.
- Rate-dependent cosmetic/action prices are computed on server by `all_prices` / `fitting_prices`; UI quotes refresh periodically and after restructure. Manual click capped by server and blocked by Doug call on UI.
- Nora drinks/slushies: office-wide +20% BW for 4-minute windows every 2 hours, backed by server. UI badge displays.

## NPCs and jokes
- Rotating shuffle-bag of eight visitors Nora, Gus, Rory, Theo, Iris, Bramblewick, Pip and builder Wren: 4-minute slots, 46-second visit, shuffled once per 8 opportunities.
- Wes (former employee) and Hal (owner) have independent schedules; at most 3 NPCs. Theo/Bramblewick occasionally exchange Buzzword Bingo bait.
- Wren leaves temporary wood scraps and talks about the endlessly unfinished rooftop lounge. Theo has a line about updating the operating agreement again. Wes teases Bramblewick about poison oak.
- Many dialogue exchanges and special overlaps; review `officeVisitorNow`, `visitorOrdinal`, tick effect and `OfficeVisitorBody` before editing.

## Existing returning-player UI
1. `While you were out`: away duration + accrued BW.
2. `Incident report`: direct actions by other players.
3. Weekly `Recap`: previous season summary.
Do not remove/duplicate these.

## Office Nonsense suite (added PR #1)
Optional button opens six tabs:
1. Rumor Mill: deterministically scheduled jokes.
2. Corporate Buzzword Bingo: 3×3 phrases heard during NPC visits, **per-browser localStorage** and UTC-day reset.
3. Daily HR assignments: work, encounter NPC, hire, **local-only**, joking title but no gameplay rewards.
4. Wren's Rooftop Lounge: intentionally futile rotating construction status/progress.
5. Employee of the Minute: meaningless award, changes every 30 min.
6. Office Incident Log: 8 recent **simulated** NPC rumors; not real historical logs and not the offline BW popup.
All six are cosmetic/optional; no BW economy effects.

## Visual tone
Warm retro workplace satire, desk/floor sprite world, stamp-like HR forms, funny copy; prioritize clarity on phone and desktop and avoid modal stacking. Accessibility/reduced motion should be considered for future UI changes.

## QA and release
- GitHub Actions `.github/workflows/regression.yml` runs `tests/economy-and-office.test.cjs` on PRs to main and pushes to main.
- CI verifies JSX parse and targeted helpers/invariants. It is not a full Playwright or Supabase E2E test.
- Mandatory release steps in `docs/RELEASE_CHECKLIST.md`. Read `AGENTS.md` first.

## Testing infrastructure update
CI additionally runs Playwright Chromium entry smoke tests at desktop/mobile sizes and ephemeral PostgreSQL contract tests. Neither exercises live authenticated Supabase RPCs. No Supabase test branch currently exists, and domain DNS remains independently unverified. Branch protection status needs explicit repository settings verification.

## 2026-10-20: Cutout art integration
Original vector-cutout illustrations integrated into existing hiring rows, approvals and cosmetic catalogue with consistent outlines, palette and no new hitboxes or economy impact. Rotating NPCs gain heavier ink lines, sleepy expressions and role props. Iris hair blonde and Pip brunette. Current generated art-direction posters remain concept art; hand-coded SVGs are production visuals, not automatic sprite exports. No authenticated full-world visual QA yet.

## Cutout art gallery & visual gate
Render `?art-preview=1` on the game URL to see a read-only, non-authenticated gallery of eight rotating NPCs plus Wes and Hal, palette, prop and icon samples. GitHub Actions Playwright tests desktop and phone gallery rendering and horizontal overflow; PNG artifacts archived seven days. This gallery is not a replacement for authenticated game-world navigation QA.

## Cutout-art implementation candidate (PR #4)
An original cutout SVG/CSS system adds 30px classed purchase icons across hire, approvals, vanity, office_kit, costume, staff, drink and perk lists, and updates all 10 NPCs with unified expressive silhouettes and props. Paper-doll body strokes and five office-kit furniture tiers are refreshed without altering stored ownership. Full test evidence and exact release state in PR #4. Read `docs/ART_DIRECTION.md`. Authenticated gameplay visually unverified; do not call the redesign complete until verified.

## Character creator / permanent wardrobe (PR #5)
- New employees create a cartoon employee rather than uploading a head photo. Build, body style, hair style/color, eyes/expression, skin tone, glasses, shirt/pants selectable free. All values persist in existing `players.look` JSONB via extended authenticated `set_look` RPC.
- Mirror allows existing players to update for free, preserving their prior BW, Seniority, vanity and office kit.
- Six permanent, cosmetic-only `wardrobe_owned` purchases paid in Busywork; separate from temporary coworker prank costumes. Purchase validations and outfit authorization are server-side. No player-account resets.
- Character rendering uses same cutout `AvatarHead` in onboarding, floor and player UI. Runtime backend migration `sql/character_wardrobe.sql` must be applied before production merge.

## 2026-10-20: Avatar and office art polish (PR #8)
The newer shared player avatar is rendered inside `.pg-avatar-head` rather than the legacy circular `.pg-face`, eliminating the duplicated oval behind hair. Eyes, facial expression and hair silhouettes are redrawn and the onboarding preview is enlarged. Actual `pg-officedesk` tiers now use the `OfficeDeskArt` SVG with tier-specific screens and clutter; all six permanently purchasable outfits use individual `WardrobeIcon` illustrations. The read-only art gallery includes an actual Onboard component for responsive tests. These production vector components approximate the original concept-art styling but are not literal raster sprites extracted from those boards. Authenticated full-office visual walkthrough remains outstanding.

## Build 154 candidate: unified world (feature branch)

See `docs/VISUAL_REDESIGN.md` for recovered concept sheets, acceptance status, limits and rollback. Shared player/NPC rig; angular heads and unmasked custom profile faces; tiered SVG furniture, illustrated kitchen fixtures, outlined companions, floor/cubicle/HUD materials; corrected actor/desk depth. Local versioned browser libraries remove the reproduced CDN boot failure. No database mutations, economy changes or inventory resets.

`tests/gameplay.spec.cjs` exercises the actual game with desktop and Pixel 7 touch emulation against intercepted Supabase HTTP/WebSocket responses. Walk, six emotes, desk/work, bingo, mirror equip/save/reload and retained fixture progress covered. This is not live Supabase E2E or physical-phone evidence. Vercel team access returned 403 and CLI has no credentials; Git integration release must be independently verified. Overall exact-art redesign is not complete.

## Build 155: mobile help dialog scrolling

Fixes the build 154 CSS regression that applied `overflow:hidden` to `.pg-card`, clipping onboarding help after Hal's office and hiding Start earning. Cards again scroll vertically, with touch panning, contained overscroll and a dynamic-viewport height cap. `.pg-panel` retains its separate clipped shell and scrolling body. `tests/modal-scroll.spec.cjs` sends touch swipes in 390x640 portrait and 844x390 landscape, verifies scrolling and the final button position, then taps Start earning to dismiss. No auth, economy or data changes. Local Node regression passed; local Chromium download was unavailable, so the required browser/SQL/logic CI gates must verify the candidate before merge. Rollback is a revert of this visual-only PR.

## 2026-10-21: Build 156 character personalities (candidate)

Body style now changes the shared torso silhouette (angular masculine, shaped feminine, original neutral) independently of slim/regular/broad build, clothing and movement. All nine combinations are distinct. New free `look.head` choices: classic, round, square, pear, alien, robot, cyclops, frog and paper bag. Existing looks default to classic. Shared `AvatarHead` renders these in the badge, mirror, HUD and office, with expressions and single-lens cyclops glasses. Special heads keep their fixed silhouette and preserve hidden hair choices. Creator/mirror get illustrated head buttons, selected color checkmarks, pants colors and a Surprise me control that preserves equipped clothing and purchases.

The additive `supabase/migrations/20261021151041_character_heads.sql` replaces only `set_look`: validates/persists head, keeps auth/ownership checks and preserves a saved head when older clients omit it. It performs no row updates during installation. Apply before frontend release and verify the live function definition. Original wardrobe migration stays unchanged. Browser tests cover creator choices on phone/desktop, actual mirror save/reload, retained fixture progress and emotes. The isolated Postgres contract tests every head and invalid values against the actual migration. No real-player tests or physical phone verification. Local Node regression passed; final CI evidence and live release are tracked in the PR. Rollback frontend first; keep the additive backend support to preserve new choices.

## 2026-10-21: Build 156 production observation

User reported manual deployment after Vercel connector access failures. Independently refreshed the public art gallery and observed `BUILD 156 · FACES WITH PERSONALITY`. Source merge `4b8dcffe88e35725bd87a20ebd8931dea68eb2ab`, all three PR #11 CI jobs green, Supabase character_heads migration applied/read-only verified. Vercel deployment metadata/READY still unavailable through the connector; physical-device gameplay not independently tested.

## Build 157: faithful supply-closet previews (candidate)

All 11 costume rows use `CostumePreview`, a read-only miniature of the existing `Body` rig with the selected recipient's normalized appearance and requested temporary costume. No duplicated generic hat/shirt/mascot pictograms. A separate Preview button expands a larger try-on without spending BW or equipping; it remains available when the purchase is disabled. The existing row purchase action, server quotes, target, duration, cooldown and price calculations remain intact. Unknown future costume IDs retain a safe fallback.

The actual Wardrobe component is also in `?art-preview=1`. Browser coverage opens every preview in the actual desktop/phone game with isolated HTTP/WebSocket fixtures, checks no dressing RPC/balance changes from previews, switches recipients to verify face and coworker pricing, then purchases and checks the real world rig. No production player data, SQL or RPC implementation changes. Local/CI evidence and deployed status are recorded in the PR. Rollback by reverting this visual-only change.

## Build 158: desk previews, shared break table and office commendations (candidate)

`FittingPreview` replaces generic category icons across all 34 Yourself/Your Office catalog items and provides free larger previews even for locked items. Desks/chairs reuse their actual office SVGs; rugs, wall art, held objects and atmosphere now share SVGs between the catalog and floor. Desk surfaces follow their material names (glass/walnut/marble/black). Existing IDs, tier order, server quotes and purchase calls are unchanged. The break table now visibly holds a pink donut box, mugs and a napkin with mismatched chairs, replacing the unclear grey oval. Eight friendly memos added.

Eight new cosmetic commendations in Personnel: Welcome Committee, Office Glue, What Goes Around, Cross-Department Collaboration, Dress for the Job You Invented, Facilities Have Questions, Recurring Calendar Invite, HR-Approved Menagerie. Each shows a real unlock goal. `claim_office_awards()` validates the signed-in player's stored stats; `office_award_ids(players)` is an internal helper. `save_achievements` keeps existing IDs, merges legacy submissions, ignores client-submitted new `oa_` IDs and adds only server-qualified new ones. Already earned awards persist when current stats fall. No award grants BW, boosts or inventory. Opening Personnel merges only returned award IDs into UI state, preserving the earning-display anchor.

Apply `supabase/migrations/20261021163031_office_recognition.sql` after isolated PostgreSQL checks and before frontend merge. Installation changes functions/grants only, not player rows. Existing legacy achievement predicates remain the old system; new commendations are server-qualified. Dedicated contracts exercise all eight thresholds, distinct collection counts, forged IDs, legacy retention, auth, cross-player isolation and unchanged economy. Browser tests exercise actual catalog/purchase and Personnel with isolated fixtures; read-only gallery includes both. Local parser/helper checks passed; final browser/SQL/CI evidence and live release state belong in the PR. Physical-device and authenticated production gameplay remain unverified. Rollback frontend first, retain additive backend support so earned IDs survive.

## Build 159: weekly scoring deadline (candidate)

The wall whiteboard shows the exact scoring cutoff and a live countdown; the expanded This week leaderboard also shows the office timezone and the viewer's local date/time. All time retains its permanent-total explanation. The timer comes from the read-only, authenticated `weekly_schedule()` RPC, using existing `week_started()` and `office_door.tz`. Production was read-only verified as America/New_York: Friday 17:00 Eastern (Oct 23, 2026 at 21:00 UTC / 14:00 Pacific for this week). No schedule, scoring, reset or player-data behavior is changed. Calendar arithmetic in office time handles DST weeks. UI anchors to server time, refreshes the schedule every 30 seconds while visible and on return, and shows Closing this week at zero until a new schedule arrives. RPC errors leave the last known schedule or an unavailable message; the browser never triggers a rollover.

Apply `supabase/migrations/20261021170311_weekly_deadline.sql` after isolated SQL verification and before frontend merge. It creates only the read-only schedule function/grants, with no player writes. Tests cover Friday boundary, weekend, both DST transitions, year rollover, auth/grants, server/client clock skew and retained points. Two focused desktop/Pixel 7 emulation browser checks passed locally and screenshots were reviewed. Full regression/CI/migration/release evidence belongs in the PR. Physical-device and authenticated production gameplay remain unverified. Rollback frontend first; the additive read-only RPC can remain.

## Build 160: Friday 16:00 Pacific scoring close (candidate)

User changed the weekly close to Friday 4 PM Pacific. `week_key(ts)` and `week_started(ts)` now use America/Los_Angeles and a Friday 16:00 wall-clock boundary; `weekly_schedule()` reports the same zone and next deadline. Existing office_door.tz is deliberately retained because it also controls earning bonuses. Current week 2026-43 remains active and closes Oct 23, 2026 at 23:00 UTC (16:00 PDT), two hours after the previous cutoff. Pacific standard time closes at 00:00 UTC Saturday while still Friday 16:00 locally.

`supabase/migrations/20261021171655_pacific_week_close.sql` first refuses a week-key mismatch against season_state, then replaces only the three scheduling functions. No rollover/reset calls, player-row writes or office timezone changes. Apply after isolated tests; verify current key and synthetic boundary samples read-only before/after. Existing season rollover consumers use the changed week_key/week_started automatically. The countdown UI remains server-anchored; QA fixtures and build label are updated. SQL tests use the actual migration and cover the former cutoff, before/exact boundary, weekends, both DST changes, ISO year crossing, RPC consistency, preserved player snapshots and office settings. Browser tests verify the Pacific date/time and timer at desktop/phone sizes. Final evidence is in the PR; physical-device and authenticated production gameplay remain unverified.

Rollback needs review before changing schedule functions near a cutoff: a different computed key could trigger the existing rollover on the next normal sync. Do not roll back by wiping progress. Keep the current season key intact and verify the intended boundary first.

## Build 161: worn pins on the character (candidate)

Reported beta pin equip saved successfully but was invisible on the floor. Root cause: Body never rendered players.pin; only leaderboard names used it. WornPin now draws the catalog's color/glyph as an outlined chest badge inside the animated/flipped rig, above clothing and costume layers. All owned catalog pins share this rendering. A beta metadata fallback keeps the known beta pin legible before catalog loading; it does not grant ownership. HR collection pin controls are real buttons with pressed state, Wear/Remove names and a saved Wearing status.

Existing set_pin RPC inspected read-only: validates stored extras ownership and returns the updated player. No SQL or purchase changes. Browser coverage uses the actual HR collection action with isolated fixtures: equip beta, visible chest placement/emote, reload retention, remove, replace with a regular pin, unchanged progress. QA includes normal and T-Rex costume pin layers. Exact checks/release are tracked in the PR; physical phone and signed-in production player writes remain unverified. Rollback is a frontend revert; saved pin and inventory IDs remain intact.


## Build 162: office polish review and navigation (candidate)

Review, priorities and acceptance: `POLISH_REVIEW_2026-10-21.md`. Six illustrated/labeled emote buttons preserve existing actions; utility buttons gain consistent SVGs/text; the ten-stop directory uses actual walking and panel opening. Lucide paths are pinned/licensed locally, while emote art is original SVG. Public game stays fictional; privacy guard now runs in CI.

Read-only production review found normal seasonal helper clearing permanent kit/vanity/spent, and directly callable by anon/authenticated. `20261021193821_preserve_permanent_cosmetics.sql` removes only those assignments and revokes direct client execution, retaining server-owner rollover access and existing seasonal reset behavior. Installation replaces the function/grants only; never invoke a live reset to test it. Isolated SQL contract checks preservation and grants using synthetic players. Apply only after all CI jobs pass, then inspect definition/grants read-only. Do not roll back this retention/access fix by restoring the old public destructive helper.

Local parser/economy and fictional-name checks pass; focused desktop/Pixel 7 browser flow passes. Exact full CI and release evidence belong in the PR. Physical phone, authenticated production gameplay and full art-direction acceptance remain unverified/unfinished; see review backlog. Base includes fictional-office main `64f12e7`.


## Build 163: the coffee has a subplot (candidate)

User authorized all four polish stages and deployment. Based on main `9ce6532` (build 162), branch `feat/lived-in-office`. Full staged acceptance and evidence in `POLISH_STAGES_163.md`; final CI/merge/deployment evidence in the release PR.

1. Three composed office zones, seven decorative props, consistent original SVG bench/shelf/notice/calendar/plant art. Decorations never intercept movement or change wall/fixture geometry. Break room tested and visually reviewed at desktop/phone.
2. Short rig/panel reactions distinguish drafting, confirmed filing/purchases, kindness, costumes and mishaps. Purchases require successful server return. Web Audio gets quiet stamp/keyboard/costume/coffee cues, saved master volume, immediate mute, hidden-tab silence and repetition caps. Sound & feel is in the directory and mobile More. No external audio/voice assets, credits, API keys or dependencies added.
3. Mobile primary row keeps work/directory/More, all six emotes remain visible; secondary tools move into More. Feedback has a reserved row. Camera measures actual controls rather than a fixed allowance. Shared dialogs trap focus, close with Escape and restore focus. Short phone/landscape, touch help scrolling and controls passed.
4. Break room has opt-in live coffee invitations (45 seconds), walking and shared waves; ephemeral channel signals cannot award anything. Kindness board derives only existing server deed records and respects hush. Three shared clock-based prop stories have illustrated inspections/punchlines. Existing office goal drives progress/celebration; office state now loads on entry and refreshes while visible. Normal kind actions/prices/RPCs unchanged.

Two-player browser test relays the actual Supabase client's broadcast protocol in memory, with isolated HTTP responses; verified invitation, walking, peer wave, a real UI deed request and note retention on reload. This is not production multiplayer or database E2E. Node audio graph and invite validation contracts pass. No SQL migration, schema, ownership, reset or economy changes. Real physical-phone and authenticated production interaction remain unverified. Rollback: revert frontend changes; all saved inventory/progress uses existing fields unchanged. Full regression and live production gallery must be verified before claiming release.


## Build 164: sound on at 100%

User requested sound enabled at full volume by default. Fresh browsers now start with muted=false and soundLevel=1. Existing explicit ih_muted/ih_sound_level settings still take precedence; an untouched former 35% default was never stored and becomes 100% on reload. No database/player changes. Existing sound contract verifies fresh defaults and saved-setting reload. Parser/name/audio/social checks and required CI must pass before merge; deployment evidence in release PR. Frontend-only rollback.
