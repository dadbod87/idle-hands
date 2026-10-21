# Build 163 — staged office polish

User explicitly authorized implementing review recommendations 1–4, in sequence with testing, then deploying. Base main `9ce65326ac60733c862ca9361657d1a4d306ecd2`; feature branch `feat/lived-in-office`. This document records the delivered scope and limits; exact final head/CI/merge/live evidence belongs in the release PR.

## Acceptance and stage evidence

| Stage | Implemented acceptance | Focused verification before advancing |
| --- | --- | --- |
| 1. Lived-in environment | Break room, work corridor and management corner have distinct flooring/composition; bench, noticeboard, shelf, plant rota, printer apology and calendar use shared original SVG art. Existing destinations, walls, routes and inventory remain intact. | Two desktop/Pixel 7 gameplay tests passed after visual adjustment of plant/bench placement. Actual walking to the break table, emote, retained progress, non-intercepting decor and six gallery illustrations checked. Screenshots reviewed. Local checkpoint `ba3a399`. |
| 2. Action feedback and sound | Drafting is provisional; server-confirmed work/purchases get a filing stamp/receipt, kindness gets a mug/heart, costumes get a shirt reaction. Panel receipts stay visible while shopping. Quiet stamp, keyboard, costume, coffee and existing event cues use adjustable master volume. Immediate mute, background silence, per-cue cooldown and burst limit. Reduced motion stays still. | Audio graph contract passed. Two desktop/phone tests passed for failed/successful purchase, unchanged state on failure, sound preference reload and reduced-motion art. Four existing catalog/personnel flows passed. A five-second desktop startup timeout was corrected to a bounded 15-second wait; rerun passed. Local checkpoint `ad176a9`. |
| 3. Mobile hierarchy | Work, directory and six emotes remain directly accessible. More contains secondary tools. Feedback cannot cover controls. Camera measures HUD/control/footer space. Dialogs have names, contained keyboard focus, Escape close and focus return. | Seven checks passed: 390×640, 393×851 and 844×390 layouts; measured targets/bar/feedback/world space, More access, focus containment/return; existing touch-scroll Help and directory/emote flows. Short-phone screenshot reviewed. Local checkpoint `db9b7a1`. |
| 4. Social comedy | Optional 45-second live coffee invitation, walk over, shared wave, nearby count. Kindness board shows existing server-recorded good deeds with masking retained. Plant/printer/calendar stories share a clock phase and readable inspection punchlines. Existing shared goal supplies progress and celebration; initial office snapshot loads on entry. | Actual Supabase browser client ran through an in-memory WebSocket relay and isolated HTTP fixture in desktop + phone contexts. Invitation, walk, cross-client wave, harmless inspections, existing deed action, expected sender cost and note after recipient reload passed. Validation contract rejects unknown/stale/future/invalid signal types. Local checkpoint `49f45dc`; initial-goal refresh added during integration. |

## How the social features work

Coffee invitations and waves are ephemeral player presence, available to currently connected clients. They are cosmetic signals, not verified reward records or a durable chat service. Invitations accept only a known floor player and a bounded timestamp, expire after 45 seconds, are limited locally to one per minute, and are rate-limited on receipt. The sender sees a failed-send message when disconnected; nobody is automatically moved or charged. Walk over always uses the existing walking/open behavior. Nearby count means nearby live avatars, not compulsory attendance.

Kindness notes come exclusively from `loadFloor()`'s existing deeds query, mapped through existing `DEED_TEXT`; no note text or award is accepted from the invitation channel. Recent notes are limited by the existing 30-deed feed. Existing hush masking is retained. Friendly actions still use `do_deed` and normal server pricing/cooldowns. This pass creates no new permanent social records or economy rules.

The shared goal reads existing `office_state` total/target/hit; no new goal or reward is created. A read refresh on entry, visibility return and every 30 seconds while visible fixes the initial quiet-floor gap. Decorative celebration appears only when existing state reports the goal met.

## Audio and voice decision

The user's video trial auditions used ElevenLabs; an earlier local narration used Kokoro. This release uses original synthesized Web Audio, adding no external voice account, cloned voice, audio asset, billing dependency, secret or trial-credit consumption. Voice lines are not part of this acceptance. A future voice pass should choose a deliberately small set of lines/voices and verify the current public-game license before generating/exporting assets.

Sound & feel offers labeled auditions and a 0–100% master effects slider. The previous sound toggle remains. Preferences stay in local storage. Build 163 initially used 35%; build 164 changes the default to 100% with sound enabled, per user request. Saved preferences take precedence; mute immediately gates already-scheduled notes; hidden tabs silence the master and reject new cues. Rapid work, repeated purchases and events have individual cooldowns plus a short global burst cap. Sound is presentation only and never determines an outcome.

## Safety, regression and release

No SQL migration, data reset, inventory-field change, item ID/price change or new game currency. Preserve build 162's retention/access fix and the fictional-office names. All new art is native SVG and all new sound is native synthesis; existing Lucide license attribution remains. No new runtime library is installed.

Integration run: 31/32 browser checks passed; the expanded gallery timed out during its fifth redundant full-page screenshot. Gallery captures now target their named surfaces (onboarding, avatar controls, shop, cast), preserving all content/overflow assertions. Four focused entry/gallery checks then passed. Final CI must run the complete suite on this capture change. Dialog arrow keys also remain inside the dialog rather than moving the hidden player.

Required final gate: parser/economy assertions, fictional-name guard, sound graph contract, cosmetic signal contract; full Playwright suite; existing isolated PostgreSQL contracts. All three CI jobs must finish successfully before merge. Screenshot artifacts include actual game flow at desktop and emulated phone sizes, plus the read-only gallery. Deployment verification must confirm the public build, new artwork/reactions/stories and Vercel success for the merged SHA.

Physical-device gameplay, audible mixing on real speakers/headphones and authenticated production multiplayer/RPC writes remain unverified. Browser tests use intercepted HTTP and WebSockets, not a live Supabase test project. Existing recommendation backlog beyond these four delivered stages (economy/player research, complete accessibility certification, startup profiling/build-pipeline extraction) is still separate work. Do not label this an exhaustive game redesign or security audit.

Rollback is a frontend revert. Existing saved player fields, ownership and prior backend protections remain intact; do not wipe progress or revert the previous retention fix. Deployment evidence is appended to the release PR after actual verification.
