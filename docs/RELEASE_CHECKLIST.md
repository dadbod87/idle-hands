# Idle Hands — Required pre-production release gate

## Before code
- [ ] Read AGENTS.md, CURRENT_STATE.md and CHANGELOG.md.
- [ ] Fetch newest main, confirm Vercel/Supabase targets, inspect affected RPCs.
- [ ] Create short-lived branch, document scope and rollback.
- [ ] Confirm no production-player reset or destructive test.

## Automated gate
- [ ] Run `npm install --no-save --no-package-lock @babel/parser@7` then `node tests/economy-and-office.test.cjs`.
- [ ] PR created to main; GitHub `Idle Hands regression gate` jobs **economy-and-office**, **browser-smoke**, **isolated-postgres** all completed **success**, not just started.
- [ ] Test any altered economy formula both client and server; SQL hypothetical samples must be read-only on prod.
- [ ] Confirm NPC maximum, schedule determinism and no broken popup behavior for any NPC/office features.
- [ ] Confirm desktop/mobile layout in browser if graphical browser available; if not, report as unverified.

## Review and publish
- [ ] Update state and history documents with actual implementation and testing.
- [ ] Verify no secret or private employee data in repo.
- [ ] Merge PR only when checks green and no known blocking errors.
- [ ] Confirm Vercel Production `READY`, actual build SHA and relevant app behavior.
- [ ] Keep working fallback URL; custom domain requires independent DNS/HTTPS check.
- [ ] Record release SHA, limitations and follow-ups for the next AI chat.

## Do not overclaim
Passing this CI gate does NOT mean the browser or real RPC flows were tested. Never claim “full end-to-end QA” until an authenticated isolated test suite exists and has actually run.

## Visual releases
- [ ] Read `docs/ART_DIRECTION.md` for palette, character constraints and CSS/SVG asset families.
- [ ] CI browser-smoke produces desktop/mobile art gallery and wardrobe screenshots; review screenshots visually before merge.
- [ ] Check no overlapping labels/buttons in hiring, approvals, costumes, personnel, bar, and Seniority screens in an authenticated test session when available.
- [ ] If actual in-game navigation cannot be verified, mark it unverified explicitly, not 'passed'.

## Active-effect HUD presentation
- [ ] Run `node tests/active-effects.test.cjs` and `tests/active-effects.spec.cjs`; inspect desktop, narrow-phone and short-landscape screenshots.
- [ ] Check zero-income expiry, future starts (including timestamp-valued legacy `from`), multiple benefits/penalties, full long-name details, keyboard/tap/hover, no duplicate status badges and retained settlement/notification controls.
- [ ] Preserve build 174 TV/four-screen and prop/camera tests.
- [ ] Confirm the served production HTML matches the merged artifact, capture production desktop/mobile in-game screenshots, and disclose intercepted fixture data.

## Stable purchases and custom faces
- [ ] Repeatedly click a fixed purchase coordinate across receipt arrival/expiry; verify target/neighbor bounds and no unintended purchase on desktop, phone and short landscape.
- [ ] Test custom face selection, preview, invalid/decode/upload failure, retry, save/reload, HUD/world rendering, illustrated/photo switching and unchanged progress using intercepted fixtures.
- [ ] Execute the photo extension through the isolated wardrobe SQL suite; verify the guarded additive migration live before frontend deployment.
- [ ] Inspect head-picker and in-game screenshots at phone/desktop and preserve prior HUD, wardrobe, TV and prop gates.

## Transparent custom photos
- [ ] Sample fully transparent, half-alpha and opaque pixels before upload and after reload in HUD/world at desktop/phone sizes; fixture storage must serve actual uploaded bytes.
- [ ] Verify PNG MIME/path, opaque JPEG inputs, existing JPG URLs, upload failure/retry and no progress mutation; review screenshots before merge.

## Per-planter watering
- [ ] Activate Dave’s planter by keyboard/touch, then the couch-side planter; verify exact actor/effect anchors and independent rotations across reload.
- [ ] Test desktop/phone/short landscape, bubble/actor/prop clearance or caption fallback, preserved field-guide destination and unchanged player progress/shared plant activity.

## Frameless faces and weekly secret
- [ ] Check photo-head computed border/shadow/padding/clipping and alpha in preview/HUD/world; review desktop/phone screenshots.
- [ ] Execute actual scheduler/claim SQL with 1,000 draws, reset/DST/year boundaries, stable same-week time, stale pins, one shared claim and unchanged progress/grants.
- [ ] Verify the guarded function migration and existing claim remain intact before frontend release; never trigger a real secret claim for QA.

## Deleted-account session recovery
- [ ] Test stale cached JWTs, account deletion during intake and the exact players_id_fkey race without production writes.
- [ ] Confirm the fresh signup uses its newly issued identity; retain invite and sound preferences.
- [ ] Temporary Auth/network failure must preserve the saved session and retry the same account.
- [ ] Confirm normal signed-in/magic-link behavior still boots after validating Auth events outside the SDK callback lock.

## Birthday Card feedback
- [ ] Run six card browser fixtures at desktop, phone and short sizes; inspect the cost, shortfall and persistent feedback beside the button.
- [ ] Execute the actual sign_card body and guarded projection in isolated PostgreSQL; verify quote/charge, Pacific week, minimum, insufficient/duplicate no-charge, final payout/cake, unchanged installation data/grants.
- [ ] Apply and independently verify the read-only card_state projection before frontend deployment; confirm sign_card hash remains unchanged. Never sign or spend real player Busywork for QA.
