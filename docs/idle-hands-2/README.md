# Idle Hands 2.0 — planning and build home

Status: **preproduction setup complete; engine pilot next** (2026-11-09). Working title. Separate game; no sequel runtime, hosted service or asset purchase exists yet. Current game remains build 194.

Nick has delegated routine design and technical choices, asked for free assets and a system that can progress one prompt at a time. The agent selects reasonable defaults, tests them and records decisions. No large upfront questionnaire is required.

## Start / resume

1. Read [current handoff](CURRENT_SESSION.md) and the latest dated closeout it links.
2. Read [build protocol](BUILD_SYSTEM.md), [decision log](DECISIONS.md), [first-session brief](EXPERIENCE_BRIEF.md) and [free-assets policy](FREE_ASSETS.md).
3. Run `python3 tools/idle-hands-2.py status`, `check` and `prompt` from the repository root. Say **“Continue Idle Hands 2.0”** to work on the next ready task. This is an on-demand workflow, not unattended background execution.

The [machine-readable roadmap](ROADMAP.json) is authoritative for task status/dependencies/acceptance/evidence. The script is read-only and validates the records; an agent must inspect the actual evidence and update them honestly. A fresh session must fetch current source and reconcile remote PRs/worktrees before acting.

## Chosen direction

- [Engine comparison and decision](ENGINE_DECISION.md): **Phaser 4 + TypeScript + Vite + DOM UI**, selected after current source/documentation review; validate desktop/phone in IH2-010. RPGJS offers more built-in RPG systems and remains the fallback if the pilot changes the tradeoff. Neither engine has been runtime-tested here.
- A humorous shared company town: personal workshop/home, cooperative visible construction and modest exploration. [Experience brief](EXPERIENCE_BRIEF.md) defines the first five/twenty minutes and persistence boundaries.
- Original or verified CC0 assets first; $0 asset purchases. No mandatory monetization in the first release. Free hosting feasibility remains unproven and has its own measured gate.
- Separate local sequel repository at the pilot; no sequel runtime inside 1.0. Its exact location/authority pointer will be recorded here when created. No account imports or new cloud resources assumed.

## Stages

| Task | Reviewable result | Gate |
|---|---|---|
| IH2-000 | Comparison, defaults, brief and build/continuity system | Source-reviewed documents and tracker tests; complete |
| IH2-010 | Separate local engine pilot | Walk/interact/transition, desktop/narrow/short screenshots and measured budgets |
| IH2-020 | One coherent visual kit | Comparable samples, licensed asset inventory, phone readability |
| IH2-030 | Fun local workshop loop | Gather/craft/decorate, saved synthetic state, deterministic idle tests |
| IH2-040 | Durable two-player bridge loop | Transactions, replay/concurrency, restart/reconnect and rollover safety |
| IH2-050 | Polished neighborhood | Small content scope, first-session playtest and phone usability |
| IH2-060 | Private-preview readiness package | Measured 20-client cost/performance, permissions, backup/restore, hosting decision |
| IH2-070 | Invited beta | Approved isolated target, actual deployed artifact and device verification |
| IH2-080 | Public launch | Beta issues resolved, concrete launch package and explicit launch authorization |

These are dependency gates, not promised dates. The task file contains full acceptance criteria and exclusions; update it rather than maintaining another checkbox list here. Expansion comes after the first neighborhood proves its value.

## Background and discovery

- [Original vision](VISION.md)
- [Historical reusable-art/system research](REUSE_RESEARCH.md) — paid options are now excluded
- [Installed development toolkit](../DEVELOPMENT_TOOLKIT.md)
- Current game: [state](../CURRENT_STATE.md), [art direction](../ART_DIRECTION.md), [history](../CHANGELOG.md)

Root README, AGENTS and CURRENT_STATE point here. Direct user decisions and agent defaults are distinguished in DECISIONS. Keep dated closeouts, exact check/artifact evidence, discovered follow-ups and a next task. When implementation moves to the sequel repository, copy this system there, repair links and leave the authoritative pointer here. Never rely on this chat as the only record.
