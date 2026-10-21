# Unified cutout world — implementation and acceptance

Candidate build 154. Branch: `feat/unified-cutout-world`. Base: `3760535`.

## Recovered design evidence

Recovered and visually inspected the earlier concept sheets from ChatGPT Library, rather than treating earlier implementation screenshots as the target:

| Reference | File | Library identity |
| --- | --- | --- |
| Original art direction brief | image-gen-1(9).png | libfile_171ce4bba9a8819189195cfb2fea16e8 |
| Updated art pack | image-gen-1(10).png | libfile_89e2a1af29ac8191b9eb10cadccc3984 |
| Modular character guide | image-gen-2(3).png | libfile_54b5abc2283c8191898a4760466ba5ed |
| Ten-person office cast | image-gen-3(2).png | libfile_ac34a8f6e8048191b705d13f81adf984 |
| Furniture/props progression | image-gen-4(1).png | libfile_52a09e761fe08191a8fb8d1e8b8758c1 |
| UI/HUD guide | image-gen-5(1).png | libfile_7c8c17761e34819191bdfd290a32b79c |

The sheets show flat cutout forms, angular faces, oversized half-lidded eyes, long trouser silhouettes, warm paper, blue cubicles, wood furniture, smiley mugs, plants and paperwork. These are the reference, not a claim of pixel-for-pixel reproduction. The game still uses original scalable SVG/CSS assets, not extracted raster sprites or a perspective recreation of the concept paintings.

## Art system implemented

- Players, onboarding, HUD faces, mirror and all ten NPCs share `AvatarHead` and the `Body` rig. NPC identity comes from hair, clothing, cap, glasses, facial hair and role props. Avah blonde; Rilie brunette.
- The custom face bypasses every legacy circular photo mask, including HUD/list contexts. Skin tone also applies to hands and short-pants legs. Emotes change the shared face while using the existing skeletal animations.
- Five front-facing desk tiers use the same frame, cabinets, monitor, mug and paperwork vocabulary. Four illustrated chairs, inked companions/mount, plants, boxes and eight major fixtures share ink and palette.
- Warm plank office floors, sage corridor tiles, blue cubicle edges, readable paper nameplates and a matching HUD. Phone zoom is at least 0.7 for legible sprites. Phone controls have larger targets and the minimap is smaller.
- Actors and furnishings depth-sort in the same room context. Desk art can now cover legs behind the desk rather than characters always floating on top.
- Browser dependencies are versioned local distributions with bundled licenses. The previous CDN startup failure was reproduced locally; self-hosting lets the actual UI render without those third-party script requests.

## Acceptance record

| Criterion | Evidence/status |
| --- | --- |
| Recover original visual references | PASS: six sheets opened and compared visually; identities above |
| Shared characters, expressions and cast | PASS: shared production components; desktop/390px gallery checks |
| Movement and six emotes | PASS: actual game component, Chromium desktop and Pixel 7 touch emulation, isolated HTTP fixture |
| Furniture, floors, environment and UI integrated in game | PASS for implemented assets; actual desk/walking screenshots inspected, not just gallery |
| Head/photo mask and desk depth defects | PASS in local actual-game screenshots and mask checks |
| Appearance equip/save/reload | PASS using actual mirror UI and real client against intercepted RPC responses; hoodie, long hair and skeptical expression persist in fixture |
| Existing economy/player progress | No SQL, catalog prices, inventory identifiers, or production player records changed. Existing deterministic assertions pass. Fixture preserves Seniority, hires and six wardrobe purchases |
| Isolated PostgreSQL RPC regression | Required GitHub CI job; record run result before merge |
| Real Supabase appearance API exists | Read-only check confirmed `sync`, `set_look(jsonb)`, `buy_wardrobe(text)`, `buy_item(text)`, `set_pet(text)` |
| Authenticated production gameplay | NOT VERIFIED: no isolated Supabase project or authenticated test session available; no production users used for tests |
| Physical mobile gameplay | NOT VERIFIED: touch emulation is not a physical Android/iPhone test |
| Exact concept-art fidelity | NOT MET: coherent vector adaptation; detailed concept-painting appearance is not fully reproduced |
| Vercel deployment | Team inspection returned 403 missing team grant; CLI fallback has no credentials. Use existing Git integration only if its deployment is independently verified |

## Verification history

1. Initial JSX/economy/office helper tests passed. Browser setup first lacked Chromium, then reproduced the external Supabase script load failure.
2. After local dependencies and character stage: four entry/gallery tests passed.
3. After furniture/environment stage: four entry/gallery tests passed.
4. Actual-game test revealed incorrect desk occlusion. After depth fix: desktop/mobile walking, work, wave and bingo tests passed.
5. Broader fixture pass exercises all six emotes, mirror save/equip and reload; two gameplay tests passed. Combined entry/gallery/gameplay suite has six browser tests; re-run final candidate in CI.

`tests/game-fixture.cjs` intercepts every HTTP and WebSocket request to the named production Supabase host. It does not add a production bypass or write real accounts. It proves UI integration, not backend authorization/economy behavior. The separate isolated PostgreSQL contract gate tests actual wardrobe RPC bodies.

## Release and rollback

Open PR and require all three regression jobs green before merging. Verify the Git-linked Vercel result and served build. Do not label the overall redesign complete while the unmet/unverified criteria above remain. Revert this PR to restore prior visual behavior; no database rollback is needed.

CI run 39555054411 confirmed economy-and-office and isolated-postgres success. Browser discovery initially also loaded the separate Node helper test and failed because its parser dependency belongs to the other job. Playwright now explicitly discovers only `*.spec.cjs`; all six local browser tests passed again after that correction. Require the new CI run green before merge.
