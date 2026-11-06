# Catalogue timing audit and repaint proposal — November 6, 2026

## Verified current rules

Read-only inspection of the production catalogue and actual fitting_prices, buy_fitting, accrue and season_wipe definitions. Audited all 35 vanity/office items. No player data, catalogue values or pricing functions were changed.

The authoritative price is max(1,000 BW, item minimum price, current effective BW/sec × item's secs). The legacy catalogue cost field is not the current charge. Displayed “days of output” are a price equivalent, not a countdown or a guaranteed time to afford it. Rates and quotes move with progression, buffs and events.

Weekly reset clears spendable BW, staff, Seniority and perks; existing cosmetics remain. Saved cosmetic tiers can therefore be accumulated across multiple weeks, while spendable BW cannot be carried over for a large final purchase. The current week is 2026-10-30T23:00:00+00:00 to 2026-11-07T00:00:00+00:00: 169 hours because daylight saving time ended. Other Pacific weeks are 168 hours, or 167 hours in spring.

## Findings

- Unapproved Purple: 937,500 seconds = 10.851 days. This final tier alone exceeds every weekly saving window at constant earnings. Including the earlier glow tiers, its same-rate chain totals 13.563 days.
- Golden Stapler: 576,000 seconds = 6.667 days (160 hours). Prior tiers must already be owned to fit its normal steady-rate saving into one week; the full same-rate held-item chain is 7.999 days.
- Something Black And Seamless: 518,400 seconds = 6 days (144 hours). The full same-rate desk chain is 7.199 days.
- The Founder Portrait: 4.764 days for its final tier; 5.556 days for its complete art chain.
- These are conditional affordability findings, not proof of absolute impossibility. A price quoted after bonuses end can fall relative to money earned earlier; active work and other income can also alter the result. A low/zero passive rate can bind the minimum-price floor. These special cases are not a reliable normal-play progression target.

At a constant rate, no other spending, no lost accrual and non-binding minimum prices, an item requiring more seconds than the remaining week cannot be bought with that week's passive income. Prior cosmetic purchases further reduce the available budget unless owned from earlier weeks. Rate growth often makes current quotes more expensive than the average rate at which saved BW was earned.

Offline cap matters: default accrual is capped at 8 hours per absence (12 for Property), extended by Deep Pockets. A once-daily player with the default cap receives approximately 56 hours of credited absence in a seven-day week, not 168. Thus even a 6-day price is not a casual daily-check-in target under this simplified model. Bonuses, work, purchases, perk acquisition and actual earning history require a dedicated synthetic progression simulation before guaranteeing accessibility.

The TV's 50,000,000 BW minimum is another exception: its 3-day label understates passive saving time below roughly 192.9 BW/sec. The common 1,000 BW floor similarly dominates at low rates.

## Recommended balance follow-up (not applied)

Use a three-day maximum for individual cosmetic price-equivalent coefficients as an active-player ceiling: g6 937500 → 259200; h5 576000 → 259200; d5 518400 → 259200; w4 411600 → 259200. Keep ownership, style IDs, existing TV imagery, and all already-purchased items intact.

This makes the flat-rate complete glow chain approximately 5.71 days, held-item chain 4.33 days and desk chain 4.20 days, before other purchases. It is not a daily-only player guarantee: if once-daily default-cap play is the intended target, use a lower ceiling (e.g. 48 credited hours) or separately reconsider offline accrual. That is a balance decision, not part of the directory release.

Before changing live prices: run synthetic 167/168/169-hour weeks, multiple start days, 4/8/12/24-hour login intervals, starting ownership from prior weeks, growing/flat/zero rates, buff entry/expiry and planned spending. Recalculate the label from the actual quoted price/current rate when floors dominate, or label the displayed duration explicitly as the pricing basis. Never test by granting currency or buying with real accounts.

## Proposed catalogue repaint flow (not implemented)

1. Start with owned office furniture: desks, chairs, rugs and frame accents. Keep photos, TV stills, character appearance and ink outlines intact.
2. Add an accessible Customize color control beside an owned item's preview. Presets plus a labeled native color picker update a free local preview; cancel restores the current appearance.
3. Show a server-quoted repaint fee (proposal: about ten minutes of output, with a small minimum), then an explicit Apply color purchase. Charge once only after validation; an unchanged color should not charge.
4. Save colors by item/style, visible both in the catalogue and on the office floor to coworkers. Colors should persist through weekly resets and restructuring, like the underlying purchased cosmetics.
5. Separate owned/unlocked progress from the selected style if users should re-equip earlier purchases. Current kit/vanity fields retain only the highest tier per slot; a lower equipped style must not erase that unlock history or make the next tier unavailable.
6. A transactional server RPC must verify ownership, validate color/region, quote/check/deduct BW atomically, rate-limit duplicate submissions and return authoritative appearance. Test insufficient BW, concurrent clicks, cancel/retry, same-color no-charge, reload, two-player rendering and weekly persistence in isolated data.

This provides a lasting office-theme collection and a modest repeat spending outlet. Fees, ownership semantics and tintable regions need a settled design before building the paid system.

## Full catalogue coefficients

The cumulative column assumes buying all tiers in that slot at one constant rate with price floors inactive. It is an analytical price sum, not an executed full-game simulation.

| Item | ID | Final-tier days | Slot chain through tier (days) |
|---|---|---:|---:|
| Unapproved Purple | g6 | 10.851 | 13.563 |
| The Golden Stapler | h5 | 6.667 | 7.999 |
| Something Black And Seamless | d5 | 6.000 | 7.199 |
| The Founder Portrait | w4 | 4.764 | 5.556 |
| The Productivity Flatscreen | tv1 | 3.000 | 3.000 |
| Leather. Reclining. Silent. | c4 | 2.778 | 3.240 |
| Server Room Green | g5 | 2.170 | 2.712 |
| Handwoven, Allegedly | r4 | 1.985 | 2.315 |
| A Trophy For Something | h4 | 1.111 | 1.333 |
| Actual Marble | d4 | 1.000 | 1.199 |
| Small Contained Flames | a3 | 0.926 | 1.086 |
| An Actual Painting | w3 | 0.681 | 0.792 |
| Corner Office Energy | s3 | 0.463 | 0.543 |
| Fire Drill Red | g4 | 0.434 | 0.542 |
| The Mesh One From The Catalogue | c3 | 0.397 | 0.462 |
| A Rug People Comment On | r3 | 0.284 | 0.330 |
| A Briefcase With Nothing In It | h3 | 0.185 | 0.222 |
| Walnut, Or Close Enough | d3 | 0.167 | 0.199 |
| A Faint Shimmer | a2 | 0.139 | 0.160 |
| A Framed Certificate | w2 | 0.097 | 0.111 |
| Executive Blue | g3 | 0.087 | 0.108 |
| Presence | s2 | 0.069 | 0.080 |
| Lumbar Support | c2 | 0.057 | 0.065 |
| Something With A Pattern | r2 | 0.041 | 0.046 |
| A Clipboard | h2 | 0.031 | 0.036 |
| Glass Top | d2 | 0.028 | 0.032 |
| Perpetual Dust Motes | a1 | 0.021 | 0.021 |
| Employee Of The Month Sheen | g2 | 0.017 | 0.021 |
| A Motivational Print | w1 | 0.014 | 0.014 |
| Good Posture | s1 | 0.010 | 0.010 |
| A Chair That Goes Up | c1 | 0.008 | 0.008 |
| A Rug, Finally | r1 | 0.006 | 0.006 |
| A Mug You Never Wash | h1 | 0.005 | 0.005 |
| A Desk Without A Wobble | d1 | 0.005 | 0.005 |
| A Faint Warmth | g1 | 0.003 | 0.003 |

