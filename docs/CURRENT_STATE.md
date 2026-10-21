# Idle Hands — Current State / new-chat handoff

Updated: 2026-10-20 (America/Los_Angeles). Recheck deployed SHA and live configuration at the beginning of every session.

## Mission and product
A satirical multiplayer office idle game for The Patron Group. Users badge in, earn Busywork (BW), purchase staff, upgrades and cosmetics, interact and compete, then restructure for permanent Seniority. Intent: funny, approachable and rewarding to revisit; not demanding minute-by-minute attention.

## Runtime & ownership
- GitHub `dadbod87/idle-hands` / `main`; most application code in `index.html` (React 18 JSX transpiled by Babel at runtime).
- Vercel project `idle-hands`; known working https://idle-hands-one.vercel.app.
- Supabase ID `wbakpxbvqxppqbrwuokp` (production data, Auth, SQL RPCs). Do not embed new secrets.
- Custom `idle-hands.thepatrongrp.com` registered/verified on Vercel; DNS record `idle-hands CNAME cname.vercel-dns.com` was outstanding as of last investigation; DNS uses Google nameservers, potentially managed at Squarespace. **Verify before promoting custom URL.**

## Economy
- Earn BW passively with server `accrue(uuid)`; click via `do_work`, purchases via `buy_item`, `buy_upgrade`; `restructure` exchanges cycle BW for Seniority.
- Ownership-based hire price growth (catalog tuning, observed 1.35); Resale department has 10% price discount; client must match server `ceil(...)`.
- Staff and upgrades reset on restructure; cycle/PP reset; temporary buffs, frenzy, heat cleared and `last_tick` reset; Seniority, perks, lifetime BW persist.
- Server `live_mult` and `live_mult_at`; idle `accrual_interval_gain` partitions time at event windows, Jess drinks, buffs, frenzy and hours. Offline cap remains 8 hours plus relevant perk/department modifiers.
- Caution: time-varying office-wide fund tiers/streak levels aren't fully historically reconstructed. Full authenticated economy regression suite remains to be built against a non-production DB.
- Rate-dependent cosmetic/action prices are computed on server by `all_prices` / `fitting_prices`; UI quotes refresh periodically and after restructure. Manual click capped by server and blocked by Doug call on UI.
- Jess drinks/slushies: office-wide +20% BW for 4-minute windows every 2 hours, backed by server. UI badge displays.

## NPCs and jokes
- Rotating shuffle-bag of eight visitors Jess, John, Kyle, Matt, Avah, Nick, Rilie and builder Joey: 4-minute slots, 46-second visit, shuffled once per 8 opportunities.
- Chance (former employee) and Dave (owner) have independent schedules; at most 3 NPCs. Matt/Nick occasionally exchange Buzzword Bingo bait.
- Joey leaves temporary wood scraps and talks about the endlessly unfinished cigar lounge. Matt has a line about updating the operating agreement again. Chance teases Nick about poison oak.
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
4. Joey's Cigar Lounge: intentionally futile rotating construction status/progress.
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
Original vector-cutout illustrations integrated into existing hiring rows, approvals and cosmetic catalogue with consistent outlines, palette and no new hitboxes or economy impact. Rotating NPCs gain heavier ink lines, sleepy expressions and role props. Avah hair blonde and Rilie brunette. Current generated art-direction posters remain concept art; hand-coded SVGs are production visuals, not automatic sprite exports. No authenticated full-world visual QA yet.

## Cutout art gallery & visual gate
Render `?art-preview=1` on the game URL to see a read-only, non-authenticated gallery of eight rotating NPCs plus Chance and Dave, palette, prop and icon samples. GitHub Actions Playwright tests desktop and phone gallery rendering and horizontal overflow; PNG artifacts archived seven days. This gallery is not a replacement for authenticated game-world navigation QA.

## Cutout-art implementation candidate (PR #4)
An original cutout SVG/CSS system adds 30px classed purchase icons across hire, approvals, vanity, office_kit, costume, staff, drink and perk lists, and updates all 10 NPCs with unified expressive silhouettes and props. Paper-doll body strokes and five office-kit furniture tiers are refreshed without altering stored ownership. Full test evidence and exact release state in PR #4. Read `docs/ART_DIRECTION.md`. Authenticated gameplay visually unverified; do not call the redesign complete until verified.

## Character creator / permanent wardrobe (PR #5)
- New employees create a cartoon employee rather than uploading a head photo. Build, body style, hair style/color, eyes/expression, skin tone, glasses, shirt/pants selectable free. All values persist in existing `players.look` JSONB via extended authenticated `set_look` RPC.
- Mirror allows existing players to update for free, preserving their prior BW, Seniority, vanity and office kit.
- Six permanent, cosmetic-only `wardrobe_owned` purchases paid in Busywork; separate from temporary coworker prank costumes. Purchase validations and outfit authorization are server-side. No player-account resets.
- Character rendering uses same cutout `AvatarHead` in onboarding, floor and player UI. Runtime backend migration `sql/character_wardrobe.sql` must be applied before production merge.

## Employee Creator & Persistent Clothing (PR #5)
- First login builds a cartoon employee, including body, hair style/color, skin, eyes, expression, glasses, shirt, pants; no photo required.
- Profile appearance persists through Supabase `set_look`; multiplayer `Body` uses the same data and `AvatarHead` artwork.
- A separate, permanent six-piece wardrobe is bought with BW through `buy_wardrobe`; the `wardrobe_owned` JSONB field is not reset by Seniority. Bought outfits must be equipped and profile saved.
- Existing social costume pranks remain temporary and separate. Full authenticated sign-in/purchase/reset E2E pending an isolated test account.
