# Idle Hands — Current State / new-chat handoff

Updated: 2026-10-20 (America/Los_Angeles). Recheck deployed SHA and live configuration at the beginning of every session.

## Mission and product
A satirical multiplayer office idle game set in a fictional office (Example Property Co.). Users badge in, earn Busywork (BW), purchase staff, upgrades and cosmetics, interact and compete, then restructure for permanent Seniority. Intent: funny, approachable and rewarding to revisit; not demanding minute-by-minute attention.

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
