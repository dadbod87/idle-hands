# Idle Hands — Visual Style Contract

Approved direction: **original, flat 2D cutout-cartoon office satire**. Inspired by simplicity and deadpan humor, not copies of any specific TV show's characters or assets.

## Five design families
1. **Art direction / palette:** warm paper `#F8F1E3`, ink `#2B2B2B`, sage `#8FA67A`, cubicle blue `#7B9CC4`, sticky note `#FFD36B`, orange `#F78B6B`. Minimal shading, bold outline, clear silhouettes, readable at phone size.
2. **Modular character bodies:** preserve existing player's custom photo/profile and wardrobe logic, animate existing arms, legs, faces and rig. Add cutout strokes and coherent footwear/hand shapes without changing hitboxes or status effects.
3. **Cast:** eight shuffled NPCs Jess, John, Kyle, Matt, Avah, Nick, Rilie, Joey plus independent Chance and Dave. Everyone uses the same reusable cutout visual language, with role-specific prop, hair and clothes. **Avah is BLONDE; Rilie is BRUNETTE.** Dialogue and schedule are separate from visual rendering.
4. **Props, office kit and cosmetics:** original SVG art in `OfficeIcon` for purchase/menu rows, plus inked office furniture tiers, colored office rugs and fixtures. Keep existing purchased items, tier IDs, costs, server quotes and character costume effects. Do not reset player inventory.
5. **UI icons:** SVG components rather than third-party image URLs. Maintain the catalog name-based semantic classification; fallback is the paperwork icon. Icons at 30–36px, mobile 25–29px, accessible labels remain real DOM text adjacent to the icons.

## Implementation
- `index.html`: `OfficeIcon`, `OfficeVisitorBody`, `WesBody`, `HalBody`, `Body` rig styles and CSS for office art.
- `?art-preview=1`: read-only QA gallery with all ten NPCs, icons, office fixtures, five furniture tiers, shop navigation examples, desktop/mobile; does not touch player data.
- `tests/browser.spec.cjs`: launches Chromium at desktop (1440px) and phone (390px), renders gallery, checks responsive width, tabs and JavaScript errors. Screenshots uploaded as GitHub Actions artifact.
- `tests/economy-and-office.test.cjs`: syntax/logic assertions plus permanent hair requirements, original NPC rotation, cutout art placement.
- Generated concept sheets establish visual direction but **are not literal in-game texture sprites**. Current game artwork is original CSS/SVG, not bitmaps exported from the boards.

## Regression and known limits
- Screenshots of auth gate and the synthetic art gallery can be visually inspected in CI artifacts. These are not authenticated game sessions.
- Full production player-world navigation and purchase dialogs need a user-authenticated browser session or isolated Supabase credentials; do not claim otherwise.
- Characters based on coworkers are fictionalized office caricatures, not faithful portraits.
- Profile photos remain user-supplied; they are framed as part of the game's paper-doll body.
- Before changing any SVG or wearable layer, confirm that it does not obscure clickable objects, alter earning formulas, or change player inventory IDs.

## Character creator graphics contract
- Illustrated `AvatarHead` choices must visually match the layered office cutout theme. Owner-requested custom photos are an optional, ink-framed head choice beside the illustrated heads. `AvatarControls` in onboarding and mirror must share `normalizedAvatar` exactly; hairstyle, hair color, skin, eyes, expression, glasses, body build, pants and shirt are free.
- Clothing upgrades are permanent visual-only pieces in `WARDROBE`, applied behind prank-costume overlays. Keep outfit palette consistent with the approved boards.
- New illustrations must be evaluated at actual game character scale, 390px viewport and 1440px viewport. The art preview is an integration test, not a substitute for player sign-in QA.

## Build 154 unified world

Recovered concept identities and full acceptance record are in `VISUAL_REDESIGN.md`. All cast now uses the player rig and head; the game adds front-facing desk/chair silhouettes, eight illustrated fixtures, inked companions, warm plank floors, sage tiles and blue cubicle edges. Actors and desks share depth ordering. The final CSS contract is intentionally after legacy rules so earlier gradients and masks cannot override it. `Face` uses an unmasked custom head when a stored look exists; legacy photo rendering remains available. No inventory IDs or persistence schema changed.

Art QA includes actual-game fixture walkthroughs with touch emulation. Do not confuse these with authenticated production or physical-device tests. Concept fidelity remains an adaptation, not a completed literal match.

## Build 156 character personalities

Nine head silhouettes share the existing ink, palette and expression rig. Classic is the backward-compatible default. Round, square and pear human faces retain all hairstyles; cyclops uses a single eye and a single glasses lens. Alien, robot, frog and paper-bag heads have intentional fixed silhouettes and explain that the human hair selection is retained. Body style controls torso shape, build controls width, and neither changes collision geometry or wardrobe ownership. Randomization changes free appearance only and retains the equipped garment. Test real creator and mirror controls at 390px and 1440px, all nine head outlines and nine style/build combinations, then verify saved appearance in the walking/emoting world rig.

## Build 157 supply-closet previews

Costume thumbnails and expanded try-ons must use `CostumePreview` → `Body` → `Hat` / `CostumeSuit`, with the selected recipient's normalized look. Use category icons only for unknown catalog IDs. The try-on is presentation-only: never mutate the selected player or send a purchase RPC until the player activates the existing purchase row. Keep preview controls enabled when funds/cooldown prevent purchase. Hide duplicate costume-name labels and pause animation only inside preview containers; retain equipped-world layering and animation. Verify all 11 costumes in the actual Wardrobe at phone/desktop sizes and in the read-only gallery.

## Build 158 desk catalog and shared objects

`FittingPreview` selects by stable slot/item ID. Furniture uses `OfficeDeskArt`, `OfficeChairArt`, `OfficeRugArt`, `OfficeWallArt`; carried objects use `HeldItemArt`, atmosphere uses `AuraArt`, and glow/presence use the actual Body styles. Catalog and office must show the same item. Keep surfaces faithful to item names; no tier/price/ownership changes. Pause motion in catalog previews only. The break table should read as shared food and coffee, with no ambiguous grey bowl. Personnel commendations display both humorous notes and concrete server-qualified goals, with no gameplay bonus.

## Build 161 worn pins

WornPin uses PIN_INDEX color/glyph and a bold outlined circular badge on the chest. Keep it inside pg-rig/pg-flip so motion and facing follow the character, above garment/costume art without covering the face or changing hitboxes. Beta metadata fallback describes the existing pin only; ownership remains server-controlled. Use accessible HR Wear/Remove controls and preserve leaderboard identity.


## Build 162 utility controls and navigation

Use `EmoteArt` for six original cutout gestures with visible labels and 44px minimum targets; keep actual world emote behavior unchanged. `UtilityIcon` uses a pinned, licensed Lucide path subset for general controls. Directory cards reuse `OfficeIcon` and real walking destinations. These controls are not a replacement for the next environment-composition and feedback stages; their review and acceptance live in `POLISH_REVIEW_2026-10-21.md`. Test at phone/desktop and preserve route/hitbox semantics.


## Build 163 lived-in office and reaction system

`OfficeEnvironment`/`SceneryArt` compose three floor zones and seven decorative props, sharing warm paper/ink/sage/blue/coral. Keep purely decorative props pointer-transparent and world depth explicit. Readable story props are labeled accessible buttons opening free inspection dialogs; they do not become collision walls. `FloorReaction` uses a paper receipt, stamp, mug/heart, costume or mishap card; one short local reaction at a time, still for reduced motion. Confirmed outcomes follow successful server responses; drafting has no invented reward. A receipt also appears inside purchase panels.

Phone work/directory/emotes stay visible. Secondary tools are under More; notifications occupy measured space above the toolbar. Scenery, action and social components are also in the read-only gallery. The break room's three prop stories share a half-hour clock phase and offer readable illustrated inspections. Existing real office goal controls celebration bunting. Kindness notes use server deed names/masking; coffee-break signals are transient and never an official reward. All new art/audio is original SVG/Web Audio code; existing Lucide utility notices remain intact. Test touch, keyboard, hidden audio, failure paths and two-player fixture broadcasts before release.

## Build 166 prop scale and discoverability

World prop art must read at a consistent scale beside the player and neighboring fixtures. The printer apology is a small sheet without the oversized blue mounting slab; the break-room notice is smaller than a vending machine. The water cooler uses a tight, centered SVG viewBox so its bottle and cabinet fill its world footprint. Keep decorative plants clear of fixture labels. All seven substantial scenery props are free inspection buttons; couch/notice readings also offer the real walking route to break-table activities. Keep arrow movement working after closing a reading; stop only activation keys from triggering the nearby fixture. The HUD Sound button opens Sound & feel without toggling mute/volume. Sound controls remain available through mobile More, while the directory is for destinations.

## Build 169 interactive office satire

`PerformanceArt` and `PropPerformance` use original warm-paper/ink SVGs for watering, couch breaks, absurd paperwork and ceremonial lounge planning. Free actions route to the world prop, then show small pointer-transparent world effects; rotating punchlines use a small text-only `PropPunchline` bubble styled like existing desk/lounge speech, with the feedback strip as an accessible fallback; sit/water poses use the existing body rig. Walking cancels those poses, and reduced motion stops decorative animation. Never restore illustrated performance cards. Measure text height and place the bubble above both prop and actor, with camera-safe horizontal bounds. If there is no headroom, hide the bubble and keep the feedback-strip caption; never clamp it down over the action. `WateringCanArt` is shared by the card and world effect: preserve the open handle, curved tank, fill opening and angled spout/shower rose so it reads at phone size. `LoungeWorld` stays inside the existing lounge fixture footprint and reflects real server-counted participation; it does not open the locked lounge or alter its secrets.

Polls and commendations use readable cards, minimum 44px action controls, honest ties and explicit cosmetic-only descriptions. Certificates scroll into view after creation. The optional Office field guide is reachable through More (desktop directly) and Help. Performance art also appears in the read-only QA gallery.

## Build 174 premium office television

`SpringerTVArt` shares an original thick-ink flatscreen, reflection, power light and mounting silhouette across catalog and world. Four sourced photographic show stills sit within the screen, with an illustrated fallback title if an image fails; source provenance is in assets/tv/SOURCES.md. `OfficeTelevision` occupies the upper-right interior wall separately from existing art and desks; it must retain a 44px-plus action target, stop event propagation on activation, and never open a character-obscuring card. Pause automatic changes for reduced motion, hidden tabs and off-camera TVs. Test four image responses, all frames, successful/failed purchase, persistent decor, phone placement and old catalog compatibility.

## Build 175 active-effect badges

Use the warm-paper/sage/coral and thick ink contract for the single HUD status strip. Benefits use ▲ with solid borders; penalties use ▼ with dashed borders. Badges and detail close controls have 44px touch targets. Keep the row bounded and horizontally scrollable; never wrap an unbounded stack over the office. Full names, multiplier, time and provenance remain accessible on hover, focus and tap. Detail cards must remain inside the HUD width and stop activation keys from moving/opening floor fixtures.

## Build 176 stable purchasing and custom photos

Keep transient panel feedback in a reserved 56px slot above the independently scrolling body. Purchasing dialogs and row geometry remain stable during confirmation arrival/expiry, number changes and unlock descriptions. Use the existing warm paper/ink style. Custom photo is an explicit head choice beside the illustrations, sharing a bold ink frame in Mirror previews, HUD and the moving character rig; preserve body, wardrobe, costumes and pin layers. Decode/crop photos locally before upload, show errors beside the picker and retain uploaded photos when selecting illustrated heads.

## Build 178 transparent custom faces

Preserve alpha through the 256px crop and PNG upload. The shared custom-head ink frame has no opaque backing so the office/body remains visible through translucent pixels. Keep the border, crop, dimensions, body and wardrobe layers unchanged. Older flattened uploads require re-uploading the original.
