# Interior Affairs — implementation contract, November 6

Build 189 implemented the approved concept; build 190 adds natural palettes, compact prices and the approved eight-hour fees. Earlier offline HTML demos remain design artifacts and are not connected to game accounts.

## Scope and ownership

All physical catalogue tiers: desk/chair/rug, wall-art frame, TV casing, held accessory; all purchased wardrobe tops plus Standard Issue; owned pins. Nonphysical glow/size/atmosphere effects, living companions/mounts and temporary prank costumes retain their original systems. Photos, TV programs and picture contents are not repainted. Standard desk/chair are eligible because every employee already sees them; other items require ownership.

Highest-tier `kit`/`vanity` remain authoritative sequential unlocks. `cosmetic_equipped` stores an earlier selected physical tier without lowering those unlocks. Sequential history means earlier tiers are owned. `wardrobe_owned` and `extras` remain the clothing/pin ownership sources. Equipping is free; buying the next tier still uses the original purchase RPC/formula. The before-update trigger clears only the affected selection when a highest-tier fitting changes. No existing player rows are backfilled.

`cosmetic_styles` stores a separate `{color,design}` per item ID; pin keys use `pin:`. Color is null (original) or an exact six-digit hex; design is one of solid, stripe, check, dots, sparkle, confetti. Original outlines/material details remain. Each renderer uses unique SVG pattern IDs. Wardrobe sleeves use corresponding static CSS patterns. Styles and selected items persist through both reset functions because those columns are not reset.

## Prices and confirmation

Each changed color costs eight hours of output: `max(1000,ceil(calc_rate(player)*live_mult(player)*28800))` BW. Adding/changing a non-solid design costs that same eight-hour unit independently. Changing both costs sixteen hours (two units). Removing a design is free, unchanged components cost zero, and restoring an older color/design is a new change. Previews/cancellation/equipping have no charge. The live multiplier intentionally matches existing catalogue pricing, including boosts, penalties and time-of-day rules. These are output coefficients, not waiting timers or guaranteed offline earning times.

Build 190 expires only unconfirmed quotes at the former one-day price; payment validation also rejects old-price quotes completing after migration. Already accepted receipts and saved styles remain intact. The palette has twelve playful and twelve natural presets plus the custom picker. Large totals/shortfalls are abbreviated, with optional expanded amounts.

The player requests a server quote only after choosing Review price. It displays exact color fee, design fee, total, and any shortfall. Quote expires after two minutes and is tied to player, desired style, appearance revision, week and rate. Applying locks the player's current accrued row, validates quote/ownership/version/week/rate/balance again, and atomically deducts BW, increases spent, stores the style and marks the quote accepted. Retrying that accepted quote returns the current player without another payment. Quotes are bounded to one per player; a newer quote replaces an older one. No raw color, price or arbitrary player ID is accepted by the apply RPC.

## Access and validation

Private quote table: RLS enabled, no PUBLIC/anon/authenticated grants or policies. Three authenticated, auth.uid-checked SECURITY DEFINER entry points with empty search_path; ownership/material trigger helpers are not client-executable. Existing players RLS provides read-only access to public appearance data, with no write policies. Server data remains authoritative. Response failures refresh saved state before another reviewed attempt; errors remain beside the controls.

Tests execute actual style functions and existing reset/progression bodies in isolated PostgreSQL; browser HTTP uses synthetic fixtures. A local two-session test proves one charge for concurrent duplicate application. Every supported physical tier is rendered in read-only art QA at phone/desktop, with current-game purchase/preview/reload/equip/expiry/funds/error checks at desktop, phone and short sizes. No real player purchases/grants are used for testing.

## Deployment and rollback

Apply the additive migration after checks, verify schema/grants/function hashes without player writes, then publish the tested frontend. A frontend rollback leaves persisted paid styles/columns intact. Removing the storage or reverting paid records is not part of rollback.
