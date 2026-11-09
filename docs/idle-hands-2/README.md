# Idle Hands 2.0 — planning home

Status: **approved direction; preproduction only**. Recorded 2026-11-09 from Nick's conversation. Working title, not a final product name. No sequel code, repository, infrastructure, assets or paid services have been created or acquired by this planning update.

Idle Hands 2.0 is a **separate game**: a humorous shared company town combining idle production, personal creativity, cooperative construction and exploration. People should be able to return and see both their own progress and the visible impact of the community.

## Start here

- [Vision, experience and first playable neighborhood](VISION.md)
- [Reusable art, tools and systems: researched shortlist](REUSE_RESEARCH.md)
- [Installed development toolkit and popular-repository comparison](../DEVELOPMENT_TOOLKIT.md)
- Current game: [state](../CURRENT_STATE.md), [art direction](../ART_DIRECTION.md), [history](../CHANGELOG.md)

## Confirmed decisions

These are user-approved direction, not tentative feature suggestions.

| ID | Decision | Why it matters |
|---|---|---|
| D-001 | Build 2.0 as a separate game. | Keep current players and the live game stable; plan a separate runtime, data and release boundary. Sharing accounts or importing anything is a future decision, not assumed. |
| D-002 | The town and players' creative work persist. | Homes, decoration and community construction must feel worth investing in. |
| D-003 | Weekly competitions may reset scores/objectives without erasing the town. | Competition can renew without destroying creative investment. Exact seasons, currencies and reward rules remain undecided. |
| D-004 | Develop the idea and art direction deliberately, design the systems, and validate a small playable neighborhood before building a whole city. | Use early concept art and representative assets, then test rough gameplay before finishing the entire art library. |
| D-005 | Research reusable graphics and systems to accelerate development. | Evaluate licensing, visual fit and practical integration; research is not adoption or a purchase. |

The three-layer structure—your place, our town, beyond town—is the working concept. Specific businesses, characters, resources, combat and activities remain proposals.

## Gradual roadmap

| Stage | Concrete result | Ready to move on when |
|---|---|---|
| 1. Experience brief | A five-minute visit, first-session journey, core loop and tone; initial scope exclusions. | We can explain what is fun before listing more features. |
| 2. Visual exploration | Two or three coherent directions; camera, palette, scale and character/prop sheets; phone and desktop interface examples. | Nick chooses a direction; representative characters, buildings and controls read clearly on a phone. |
| 3. Systems and rough prototype | Resource flows, production, ownership, shared contributions and saving; one loop with placeholder art. | The loop is enjoyable, reconnects safely and cannot double-spend or erase progress. |
| 4. One polished neighborhood | A personal property, a few useful businesses, one shared project and one exploration area. | It is fun with several people, usable on desktop/phone, and survives reloads and concurrent contributions. |
| 5. Expand in small releases | More locations, professions, stories and personalization. | Each addition earns its place through playtesting, cost and performance evidence. |

## Next work queue

Unchecked items are planning tasks, not promises or approved spending.

- [ ] Write the five-minute visit and first twenty minutes of play.
- [ ] Decide the initial audience: office group, invited communities or broader public.
- [ ] Sketch the first neighborhood and its resource/project/exploration loop.
- [ ] Produce comparable art-direction boards with the same scene and characters.
- [ ] Test readability, movement and interaction on a narrow phone before producing bulk art.
- [ ] Compare one browser-first engine approach with one editor-first approach using the same tiny scene; do not select a stack from screenshots alone.
- [ ] Evaluate a small coherent asset sample and establish the attribution/provenance inventory described in the research document.
- [ ] Write personal/shared ownership and persistence rules before designing season rewards.
- [ ] Define one shared-project concurrency test and a performance budget before scaling the map.

## How to keep this discoverable and current

The root README, AGENTS.md and CURRENT_STATE.md point here. Use this directory for sequel discussions rather than adding speculative features to the live-game backlog.

Add dated decisions with an ID, explicit status (proposed/approved/superseded) and the user decision behind them. Do not silently promote a proposal into a requirement. Keep research links, license evidence and evaluation results in REUSE_RESEARCH.md. Record substantive planning updates in the repository changelog. When a separate sequel repository is deliberately created, move or copy this planning home there and leave a link here.
