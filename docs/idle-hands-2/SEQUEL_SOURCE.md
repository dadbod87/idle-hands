# Idle Hands 2 — implementation moved to separate source

Verified 2026-11-09. The source/planning authority is now the separate local repository:

- Path: `/Users/nicksummerlin/Documents/Codex/2026-10-22/continue-the-game-room-wording-update/work/idle-hands-2`
- Branch: `feat/engine-pilot`
- Complete checkpoint: `3c8a55226e7de3a157b8036e161142c4891365c8`
- Tested runtime snapshot: `eeae76d0a1732905f0ee2e92472ead430b6bdb3f` (follow-up is closeout/format attributes only).
- Remote: **none yet**. This local path is not a remote backup and will not work on another machine. Next IH2-015 establishes private GitHub source/CI and records a durable remote pointer here.

Read that repository's AGENTS.md, docs/CURRENT_STATE.md, docs/idle-hands-2/CURRENT_SESSION.md, then run its tracker. Do not recreate the sequel in this repository or use an old 1.0 worktree as source. The copied planning files here are a discovery snapshot; new implementation/decisions belong in the separate repository.

## Completed milestone

IH2-010 is complete locally: original placeholder square/workshop, keyboard/mouse/touch movement, obstacle-aware destination walking, collision, input-safe DOM menus, transitions and synthetic saved position. No multiplayer, backend, currency, house purchase, real account or deployed sequel exists yet. Future house plots are an inspectable, explicitly planned destination. The café and bridge committee are prototype interactions only.

Four domain tests, strict TypeScript/Vite build, four actual-input browser walkthroughs and ten tracker tests passed; all 40 upstream guidance hashes preserved. Desktop/phone/narrow/short screenshots and detailed metric/method evidence are committed in the sequel's docs/evidence/IH2-010/. A compact machine-readable copy is [pilot-checkpoint.json](pilot-checkpoint.json). Prototype visual inspection found no blocking control overlap; no physical-device or complete accessibility claim. No external HTTP attempted in browser fixtures, no real account/service calls.

## New user direction

Slow progression through stages over days/weeks, with humor, deeper systems, teamwork and persistent personal house plots/upgrades/decoration. Prefer GitHub/Vercel/Supabase where appropriate; modest extra hosting can be considered with a concrete cost estimate. Asset purchases remain excluded. See PACING_AND_HOUSING and DECISIONS; time ranges are proposed tuning targets to simulate, not implemented production rules.

Current Idle Hands remains build 194. No 1.0 runtime, deployment configuration, database, accounts or economy changed. This bridge update is documentation/tracker state only; its three existing CI jobs still gate merge.
