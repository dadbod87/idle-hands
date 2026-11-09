# Idle Hands 2 — separate private source authority

Verified 2026-11-09. Continue sequel work in **[dadbod87/idle-hands-2](https://github.com/dadbod87/idle-hands-2)** (private), default branch `main`. Clone/fetch that repository and read its AGENTS.md and docs/idle-hands-2/CURRENT_SESSION.md. Source, decisions, roadmap and evidence are authoritative there; do not implement 2.0 in the existing game's repository or resume from an old local pilot branch.

Local checkout: `/Users/nicksummerlin/Documents/Codex/2026-10-22/continue-the-game-room-wording-update/work/idle-hands-2`. Its complete pilot/feedback history is backed up. Initial remote seed: `af7d9dd` (includes exit-position correction). CI/bootstrap review: [sequel PR #1](https://github.com/dadbod87/idle-hands-2/pull/1); final tested/merge state belongs to that live PR and source handoff, not this discovery snapshot. The earlier local-only [pilot-checkpoint.json](pilot-checkpoint.json) is historical evidence, not the latest source pointer.

## Current capabilities and boundaries

Separate original placeholder square/workshop, continuous keyboard/normalized diagonals, precise tap destinations, obstacle paths, collision, input-safe DOM menus, click-door automatic entry/exit and saved positions. Exiting the workshop now returns directly in front of the door. No multiplayer, backend, real accounts/currency, house sale or deployed sequel exists yet. No purchased assets or extra hosting.

The independent CI workflow defines domain-build-plan and browser-playtest (strict build, ten domain tests, roadmap/ten tests, 40 upstream hashes, four actual-input viewports and collected artifacts). Verify actual job status on the intended commit. CI is not physical-device, backend or production proof. GitHub's API rejected private branch protection with HTTP 403 requiring a paid-plan upgrade; do not make the repository public or buy a plan as a workaround. Project instructions still require both jobs to pass before merging.

After IH2-015, the visual kit is next: make the accepted movement feel alive through coherent characters/animation and art. Quest/skill/gathering/crafting/shared restoration/NPC/decorating and slow housing progression are staged in the separate source; not all implemented.

Current Idle Hands remains build 194. No original-game runtime, accounts, economy, database or deployment configuration changes. This pointer update follows this repository's existing three-job CI gate; it does not deploy the sequel.
