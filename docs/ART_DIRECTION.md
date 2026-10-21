# Idle Hands — Visual Style Contract

Approved direction: **original, flat 2D cutout-cartoon office satire**. Inspired by simplicity and deadpan humor, not copies of any specific TV show's characters or assets.

## Five design families
1. **Art direction / palette:** warm paper `#F8F1E3`, ink `#2B2B2B`, sage `#8FA67A`, cubicle blue `#7B9CC4`, sticky note `#FFD36B`, orange `#F78B6B`. Minimal shading, bold outline, clear silhouettes, readable at phone size.
2. **Modular character bodies:** preserve existing player's custom photo/profile and wardrobe logic, animate existing arms, legs, faces and rig. Add cutout strokes and coherent footwear/hand shapes without changing hitboxes or status effects.
3. **Cast:** eight shuffled NPCs Jess, John, Kyle, Matt, Avah, Nick, Rilie, Joey plus independent Chance and Dave. Everyone uses the same reusable cutout visual language, with role-specific prop, hair and clothes. **Avah is BLONDE; Rilie is BRUNETTE.** Dialogue and schedule are separate from visual rendering.
4. **Props, office kit and cosmetics:** original SVG art in `OfficeIcon` for purchase/menu rows, plus inked office furniture tiers, colored office rugs and fixtures. Keep existing purchased items, tier IDs, costs, server quotes and character costume effects. Do not reset player inventory.
5. **UI icons:** SVG components rather than third-party image URLs. Maintain the catalog name-based semantic classification; fallback is the paperwork icon. Icons at 30–36px, mobile 25–29px, accessible labels remain real DOM text adjacent to the icons.

## Implementation
- `index.html`: `OfficeIcon`, `OfficeVisitorBody`, `ChanceBody`, `DaveBody`, `Body` rig styles and CSS for office art.
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
- `AvatarHead` must visually match the layered office cutout theme rather than use photo uploads. `AvatarControls` in onboarding and mirror must share `normalizedAvatar` exactly; hairstyle, hair color, skin, eyes, expression, glasses, body build, pants and shirt are free.
- Clothing upgrades are permanent visual-only pieces in `WARDROBE`, applied behind prank-costume overlays. Keep outfit palette consistent with the approved boards.
- New illustrations must be evaluated at actual game character scale, 390px viewport and 1440px viewport. The art preview is an integration test, not a substitute for player sign-in QA.

## Build 154 unified world

Recovered concept identities and full acceptance record are in `VISUAL_REDESIGN.md`. All cast now uses the player rig and head; the game adds front-facing desk/chair silhouettes, eight illustrated fixtures, inked companions, warm plank floors, sage tiles and blue cubicle edges. Actors and desks share depth ordering. The final CSS contract is intentionally after legacy rules so earlier gradients and masks cannot override it. `Face` uses an unmasked custom head when a stored look exists; legacy photo rendering remains available. No inventory IDs or persistence schema changed.

Art QA includes actual-game fixture walkthroughs with touch emulation. Do not confuse these with authenticated production or physical-device tests. Concept fidelity remains an adaptation, not a completed literal match.

## Build 156 character personalities

Nine head silhouettes share the existing ink, palette and expression rig. Classic is the backward-compatible default. Round, square and pear human faces retain all hairstyles; cyclops uses a single eye and a single glasses lens. Alien, robot, frog and paper-bag heads have intentional fixed silhouettes and explain that the human hair selection is retained. Body style controls torso shape, build controls width, and neither changes collision geometry or wardrobe ownership. Randomization changes free appearance only and retains the equipped garment. Test real creator and mirror controls at 390px and 1440px, all nine head outlines and nine style/build combinations, then verify saved appearance in the walking/emoting world rig.
