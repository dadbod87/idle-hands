# Idle Hands polish review — 2026-10-21

## Judgment and evidence

The cutout characters, expressions, faithful shop previews, companions and warm paper UI are a strong foundation. The largest remaining visual gain is a more intentionally composed, lived-in office: distinctive spaces, readable silhouettes, meaningful props and reactions that make the comedy visible during play.

Reviewed the actual source at main `64f12e7`, current Supabase function definitions/permissions and catalog metadata read-only, original concept boards, read-only art gallery, and desktop/Pixel 7 gameplay using isolated HTTP/WebSocket fixtures. Existing main's fictional-office changes are retained. No real player was used for tests. This is a qualitative review, not measured player research, a complete security audit, or a claim that concept fidelity is finished.

## Findings and ordered work

| Priority | Finding and consequence | Recommended result and acceptance |
| --- | --- | --- |
| P0 — addressed in this pass | Catalog says office/vanity purchases are kept forever, but the normal weekly rollover's season helper cleared kit, vanity and lifetime spending. The helper was also directly executable by unsigned clients. | Preserve those fields alongside existing permanent collections. Restrict the internal helper while retaining its server-owned caller. Test actual migration in isolated PostgreSQL; install without resetting players and inspect grants read-only. |
| P1 — first pass implemented | Punctuation-only emote controls are hard to discover; mobile navigation requires knowing where distant fixtures are. | Six illustrated, labeled emotes and a ten-stop office directory using actual walking/open behavior. Desktop/phone tests must verify actions, 44px emote targets, retained progress and no unintended purchase calls. |
| P1 — next art stage | Large tiled floor areas and repeated, widely spaced objects dominate the phone camera. The concept boards have denser, warmer compositions and more characterful set dressing. | Build one exemplary break-room zone first: consistent furniture perspective, foreground/middle/background layers, grouped table/chairs, plant, noticeboard and two readable prop jokes. Preserve walkable routes and interaction hitboxes. Review normal gameplay at 390px, not only a large gallery. Then apply the same system to work bays and management corner. |
| P1 — next feedback stage | Characters have expressions/movement, but many outcomes are still communicated primarily through panels and transient text. | Give work, purchase, gift and friendly interaction one distinct visual response each: receipt, desk object change, short character reaction, or paired emote. Keep server confirmation authoritative; cap simultaneous effects. Reduced-motion equivalent and quiet sound controls required. |
| P1 — mobile hierarchy | The illustrated HUD and bottom toolbar consume substantial vertical space. Toasts can temporarily cover emotes; the new directory helps reach destinations but adds another toolbar action. | Measure usable world height on short phones and landscape. Move secondary instructions into Help, reserve feedback space above controls, and compact stable status information. Keep earnings/work and close/back actions visible; no hidden onboarding content. This pass does not claim to finish that redesign. |
| P2 — comedy | Most humor lives in copy. Additional awards alone will have diminishing returns. | Add visual setups/payoffs: an artificial plant with a watering rota, a printer apologizing on paper, a calendar booking a meeting about meetings. Use three recurring jokes with changing states and character reactions; avoid repeating identical toast lines. Keep all people/company names fictional. |
| P2 — social engagement | Existing gifts, kindness, competition and costumes provide good hooks, but their shared stories could be more visible. | Prototype opt-in team moments: shared break-table celebration, a visible thank-you note, cooperative weekly decoration. Show who helped and why it changed. Validate abuse/privacy/cooldowns and server authority before implementing rewards or durable social records. |
| P2 — early goals | Many systems compete for attention before the first useful hire. | Observe fresh-account play in a dedicated test environment. Make the next affordable hire and its effect explicit; provide an optional three-minute route from work to hire to friendly action. Measure time to first hire/interaction before changing economy. |
| P2 — accessibility | Touch labels/focus styles improve controls, but consistent panel focus/return, keyboard paths and small text need a broader audit. | Complete each primary flow with keyboard and touch, meaningful labels, visible focus and non-color status. Verify browser text scaling, motion preference and scrollable panels on small viewports. |
| P2 — technical polish | A large single HTML file and in-browser Babel complicate asset ownership and startup profiling. | Profile cold startup/frame timing first. Gradually extract components and precompile JSX while retaining identical behavior. Avoid an engine rewrite or animation dependency until measurements justify it. |

## Unified art system to carry forward

- Keep warm paper, sage, cubicle blue, sticky-note yellow and restrained coral with bold ink contours. Keep one shared head/body rig, expression vocabulary and depth ordering for players/NPCs/costumes/pins.
- Give environments a coherent perspective and scale guide: chair seat, desk edge, character feet and prop contact shadows must agree. Separate floor/background, furniture, depth-sorted actors and overlays explicitly.
- Treat pets as supporting silhouettes with one readable personality action; retain clear foot contact and avoid hiding nearby buttons or worn pins.
- Keep catalog previews generated from actual item art. Utility icons may use consistent line SVGs; humorous world objects and emotes should retain the game's original cutout art.
- Make UI panels feel like office documents through hierarchy, limited stamps and concise copy. Avoid filling every gap with decoration or putting implementation details into game flows.

## Useful tools and repositories

1. **Lucide** — https://github.com/lucide-icons/lucide. Reused a small pinned set of SVG paths for Help, sound, account and map. Full ISC/Feather MIT notices are in `vendor/lucide-LICENSE.txt`; pinned revision and files in `vendor/LICENSES.txt`. Original emote/world artwork stays native to this game.
2. **Motion** — https://github.com/motiondivision/motion. Useful reference for short reactions, sequencing and reduced-motion support if future profiling warrants a library. MIT; no dependency or copied code added in this pass.
3. **Kenney UI Pack** — https://kenney.nl/assets/ui-pack. CC0 examples of a systematic asset family. Useful organization reference; no assets imported, because the current ink/paper system already has its own style.
4. **Game Accessibility Guidelines** — https://gameaccessibilityguidelines.com/basic/. Review reference for readable text, well-spaced controls and consistent input. Not a claim of compliance.

The imagegen skill was consulted for asset strategy: editable SVG/code is appropriate for this existing vector system. No bitmap asset was generated. Original concept sheets were reviewed locally; they contain historical references and are not republished into the fictional public game.

## This pass: build 162, “find your people”

- Original illustrated emote controls with labels and pressed state; existing six gameplay actions retained.
- Consistent labeled utility icons and keyboard focus styling.
- Illustrated ten-stop directory with short office jokes; uses the real movement/open logic, without teleportation or spending.
- Permanent kit/vanity/spending retention and restricted internal seasonal reset helper. Intended seasonal economy reset stays unchanged; no live reset invoked.
- Fictional-name guard added to CI. Exact legacy database-column exception only.
- Read-only gallery renders the new components. New desktop and Pixel 7 fixture tests exercise actual walking, Personnel, desk, emotes and sound controls, not merely static mockups.

## Verification and limits

Local parser/economy assertions and fictional-name guard passed. Focused desktop/phone browser checks passed; full regression evidence and deployment commit are recorded in the release PR. Required gate: economy-and-office, isolated-postgres and browser-smoke all successful before merge. The SQL contract executes the actual season helper against synthetic rows only and verifies installation leaves rows untouched, collections survive, the intended seasonal counters reset, and clients lack direct execution.

Physical-phone gameplay and authenticated production multiplayer/RPC purchasing are **unverified**. A dedicated Supabase test project is still needed for safe full browser → real API → database verification. Emulation is not a physical phone. Larger environment artwork, outcome feedback, social prototypes, panel accessibility and startup profiling remain unfinished, with acceptance above. Production verification must separately confirm the served build and migration grants; passing fixtures alone is insufficient.
