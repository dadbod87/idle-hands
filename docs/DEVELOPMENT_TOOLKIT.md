# Idle Hands development toolkit

Updated 2026-11-09. This setup supports maintenance of the current game and preparation for a **separate** Idle Hands 2.0. The [approved sequel decisions](idle-hands-2/README.md) remain authoritative. Later the same day, the user delegated the engine choice: [Phaser was selected as the working sequel engine](idle-hands-2/ENGINE_DECISION.md), with a separate local pilot required. The comparison table below preserves the earlier shortlist snapshot.

## What is actually added

| Component | State | Purpose |
|---|---|---|
| OpenAI Game Studio skills | Installed repository-locally under `.agents/skills`, with all supporting references/scripts. | Architecture, game UI, playtests, sprite workflows and optional engine-specific help. |
| Pinned source/integrity record | `.agents/game-studio.lock.json`; 40 unmodified upstream files at commit `d420d13051bffe4543ed39e30fa46b87148e47dd`, bundle 0.1.2. | Reproducible provenance and offline integrity checking; no silent auto-updates. |
| Accessibility/browser diagnostic tool | [tools/qa](../tools/qa/README.md), exact dependency versions and npm lockfile. | Fixture-only desktop/mobile scans, screenshots, reports, page errors and failure traces for the current game. |
| Repository research snapshot | [dated metadata](toolkit/repositories-2026-11-09.json), plus the decisions below. | Records popularity, maintenance, licenses and source commits without confusing popularity with suitability. |

No engine runtime, multiplayer server, hosted service or paid asset has been added. No root package.json, game build config, production data or current game code changes are part of this setup.

## Use the installed skills

Open the repository root for project-local skill discovery; from a parent workspace, read AGENTS.md and these paths explicitly. New skill metadata is available on a subsequent turn in a session working in this repository. These files are not an app-plugin connection or a global install across unrelated projects.

| Task | Skill |
|---|---|
| Current game browser QA / screenshots | [game-playtest](../.agents/skills/game-playtest/SKILL.md) |
| HUD, menus, responsive layouts | [game-ui-frontend](../.agents/skills/game-ui-frontend/SKILL.md) |
| Sequel architecture / boundaries | [web-game-foundations](../.agents/skills/web-game-foundations/SKILL.md) |
| Route a future game task | [game-studio](../.agents/skills/game-studio/SKILL.md) |
| Phaser implementation after a stack decision | [phaser-2d-game](../.agents/skills/phaser-2d-game/SKILL.md) |
| Approved raster sprite animation work | [sprite-pipeline](../.agents/skills/sprite-pipeline/SKILL.md) |

The complete upstream bundle also includes optional Three.js, React Three Fiber and 3D-asset skills so cross-references stay intact. They are dormant unless an appropriate 3D task is actually requested. No 3D libraries were installed. Optional asset/engine utilities have their own prerequisites (for example Pillow for the sprite scripts); install those only for a task that actually uses them. The browser audit has its separate reproducible setup below.

**Project integration rules:** The current game remains React/SVG/DOM with its existing server authority and art direction. An upstream preference for canvas, Phaser or another stack is not permission to rewrite it. The sequel remains in preproduction; compare candidates before adopting an engine. Preserve current release gates, user authorizations, fixture isolation and host tool rules (including image tools). Skills do not grant permission for production mutations, purchases, provider setup, account imports or deployment of the sequel. Use existing skills/tools rather than duplicating them or adding a broad agent framework by default.

Verify the installation offline:

```sh
python3 tools/verify-game-skills.py
```

For updates, review the desired upstream revision, affected instructions/scripts, license and project compatibility first; update the recorded source/hashes deliberately. See [third-party notices](../.agents/THIRD_PARTY_NOTICES.md). Do not run arbitrary setup scripts or replace instructions just because a repository is popular.

## Repository comparison

GitHub metadata checked 2026-11-09; stars are a dated popularity signal, not a security, quality or scalability guarantee. All listed repositories were unarchived at inspection. A recent push does not prove every release is maintained. Exact API snapshots and default-branch commits are preserved in the linked JSON.

| Repository | Stars at check | License | Decision / fit |
|---|---:|---|---|
| [OpenAI plugins](https://github.com/openai/plugins) | 7,837 | Per-plugin; Game Studio manifest declares MIT | **Installed Game Studio only**, pinned and scoped above. Repository-wide license metadata is empty; do not assume every plugin shares this license. [Source manifest](https://github.com/openai/plugins/blob/d420d13051bffe4543ed39e30fa46b87148e47dd/plugins/game-studio/.codex-plugin/plugin.json). |
| [Playwright](https://github.com/microsoft/playwright) | 99,683 | Apache-2.0 | **Already used; reused and formalized** for diagnostic tooling. Retain current 1.56.1 browser/CI compatibility rather than upgrading incidentally. |
| [axe-core](https://github.com/dequelabs/axe-core) / [axe-core-npm](https://github.com/dequelabs/axe-core-npm) | 7,788 / 733 | MPL-2.0 | **Added as development tooling** via @axe-core/playwright 4.14.0. Finds automated accessibility issues; not a substitute for manual review. [Official integration guide](https://playwright.dev/docs/accessibility-testing). |
| [RPGJS](https://github.com/RSamaium/RPG-JS) | 1,684 | MIT engine | **Priority 2.0 comparison candidate.** Existing maps/events/dialogue/inventory/save/load/multiplayer could reduce custom work. Audit actual persistence semantics, phone controls, extension points and costs against our neighborhood loop. The commercial Studio is separate from the open-source engine. |
| [Phaser](https://github.com/phaserjs/phaser) | 40,681 | MIT | **Priority alternative.** More freedom over a custom management/city loop; compare with RPGJS before building equivalent systems ourselves. Networking and persistence remain separate design work. |
| [Colyseus](https://github.com/colyseus/colyseus) | 7,525 | MIT | **Evaluate with a custom-engine route.** Authoritative rooms/state sync; still need durable town saves, atomic contributions, permissions and recovery. Do not add a second multiplayer layer if the chosen framework already solves the same problem. |
| [Godot](https://github.com/godotengine/godot) | 119,877 | MIT | **Alternative, not installed.** Good candidate if editor/native workflows win; prove browser/phone loading and usability in the same small scene. |
| [PixiJS](https://github.com/pixijs/pixijs) | 48,660 | MIT | **Alternative renderer, not installed.** Suitable when we deliberately want to assemble our own systems; avoid adding it beside another renderer without a concrete need. |
| [LDtk](https://github.com/deepnight/ldtk) | 4,390 | MIT | **Evaluate after map/camera choice.** Reuse level authoring instead of hand-writing a full editor. Third-party tiles still need their own licenses. |
| [fast-check](https://github.com/dubzzz/fast-check) | 5,242 | MIT | **Future test candidate.** Useful for generated economic/simulation invariants once the relevant rules are isolated; not installed without a meaningful property to exercise. |
| [k6](https://github.com/grafana/k6) | 32,233 | AGPL-3.0 | **Deferred load-test tool.** Needs an isolated backend and a representative scenario. No production load tests or new runtime dependency added. Review tool/license obligations for its intended distribution. |
| [Superpowers](https://github.com/obra/superpowers) | 315,056 | MIT | **Reviewed, not bootstrapped.** Useful root-cause/verification ideas; a wholesale agent-workflow installation would overlap existing instructions and bring additional skill dependencies/process defaults. Keep this project's release/authorization workflow coherent. |
| [OpenAI skills](https://github.com/openai/skills) | 28,614 | Per-skill | **Catalog reviewed.** Current game-specific examples moved to OpenAI plugins. Do not install a third-party mirror of the missing develop-web-game skill. Existing host browser/Vercel/Supabase skills already cover much of this setup. |

The RPGJS [engine README](https://github.com/RSamaium/RPG-JS/tree/v5) describes its built-in systems; this is not a verified complete cooperative idle-city implementation. Its own skill auto-scaffolds a non-RPGJS workspace, so that skill is **not installed here** while the current game is not an RPGJS project and the sequel uses a separate Phaser pilot. This prevents accidental conversion of 1.0 during a future agent task.

## Clean path to 2.0

1. Use the [experience/first-neighborhood brief](idle-hands-2/VISION.md) to define a small comparison task.
2. Follow the [sequel build system](idle-hands-2/BUILD_SYSTEM.md) and dependency roadmap. Source review chose Phaser; validate its tiny pilot first, then durable shared play. Reopen RPGJS only if evidence changes the decision, rather than building two complete prototypes.
3. Measure effort, source clarity, phone controls/loading, save semantics and operational cost. Include Godot if the editor/native path is a genuine contender.
4. Select one coherent route, pin exact versions, and record the decision. Do not combine engines or create a new game server merely to collect tools.
5. Use the existing asset/license research and representative art sample; preserve town/creative work across competition cycles.

Start with the smallest scene and tools that answer a real question. This toolkit supplies guidance and diagnostics; it does not implement 2.0 or certify that any framework will meet the final game's scope without custom work.
