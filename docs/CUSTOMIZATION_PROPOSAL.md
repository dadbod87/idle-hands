# Interior Affairs — revised concept, November 6

Status: reviewable offline concept, not an implemented purchase system. Build 188 only changes live chair/rug placement. No paid finish, new ownership record or pricing change is deployed.

## Scope and appearance

Every owned physical item should support its own saved style: all desk/chair/rug tiers, wall-art frames, TV casings, held accessories, and purchased clothing. This is not limited to the currently equipped item or the three original preview examples. Unlocking an item and equipping it must be tracked separately, so earlier purchases can be selected. Nonphysical auras/glow/size effects, living companions, player photos, picture contents and TV program images are not repainted. Physical materials remain outlined and readable.

Offer a custom color picker plus pinks, purples, lavender, neon lime/cyan/orange, gold and quiet neutrals. Solid, stripes, checker, polka dots, confetti and static sparkle provide playful designs without motion/flashing. Preview pattern scale on each material; keep meaningful artwork, screens and hardware intact. Desk finish covers the top and drawer cabinets together, with material shading. All tiers, garment layers, carried items and other players must use the same renderer as catalogue previews. A full-item inspection pane complements the office composition so nothing is hidden while choosing.

The offline sample covers seven representative item types. The furniture SVGs come from the game; other drawings illustrate scope rather than claiming complete production-tier art coverage. No persistence beyond the open demo page is claimed.

## Proposed price

One day of current authoritative output per applied color/design change: 86,400 seconds times the server's quoted output. At 100 BW/sec the example is 8,640,000 BW. This is a price coefficient, not a 24-hour cooldown or guaranteed waiting period. Offline caps and competing spending still matter. Previewing/cancelling is free, and an identical saved style cannot be charged again. Color and design changed together are one application, not two charges. Saved finishes should survive restructuring and weekly resets, since the underlying cosmetics survive.

Before implementation, specify the exact server rate basis (temporary boosts/work-hour treatment), minimum fee at zero/low output, quote lifetime, and whether restoring an old finish is charged. Do not silently use a zero-cost quote or the previous ten-minute example. No live affordability rebalance is approved by this proposal.

## Implementation gate

Add validated per-item style records and separate equipped/owned selection; migrate existing highest-tier ownership safely. Validate exact ownership and a bounded color/finish vocabulary server-side. Server must quote and atomically deduct, reject stale/duplicate requests, and apply no productivity benefit. Keep renderers and all resets consistent. Run actual RPC bodies in isolated PostgreSQL and intercepted browser fixtures before any deployment; no real player purchases for QA. The broader feature needs a separate implementation/release, not just front-end demo buttons.
