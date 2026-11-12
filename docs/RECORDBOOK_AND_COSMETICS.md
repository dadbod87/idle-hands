# Record book and cosmetic pack — held gameplay

Nick authorized implementation and checks on November 12. Continue in PR #56; do not release gameplay before the verified normal Friday rollover.

## Preservation

The action journal captures coworker deeds, not a complete financial timeline. The separate `season_records_history_only.sql` payload prepares private final standings capture. Its AFTER season insert/stats-update trigger observes the existing normal rollover before the existing wipe. It writes no player, catalog or public function; it invokes no accrual or reset. Existing seasons backfill as winner-only summaries, never reconstructed standings. Complete snapshots preserve game-recorded weekly earnings, names and competition ranks with ties. Once complete, recap edits cannot rewrite them. This is not an offline earnings settlement or a correction to the game's winner selection.

The full held package creates or validates/reuses the exact private core. RLS and revoked direct access protect both tables. The authenticated record-book RPC exposes only completed-season summaries, standings, best recorded earnings and awards derived from non-hushed retained actions. It labels partial older coverage. Installation before normal reset is necessary to preserve this week's individual standings; the action journal alone cannot do so.

## Content and prices

Budget Wizard and Walking Filing Cabinet use the existing 45-minute costume price, self/coworker targeting, cooldown, heat, commit bonus and history rules. Previewing never spends. They have no additional income multiplier.

Six permanent boutique items use confirmed two-minute quotes at the retained permanent base-production benchmark. Paid purchases use actor/request receipts; retries cannot charge twice. Equip/display is free. Both new outfits use the existing ownership-checked color/design editor and its unchanged fees. Existing inventories, prices and garment IDs remain intact.

| Item | Pricing basis | Minimum BW | Participation |
|---|---:|---:|---|
| Emergency Coffee Technician outfit | 2 hours | 2,000 | Help on 3 distinct tracked Pacific dates |
| Meeting Survivor outfit | 8 hours | 8,500 | 2 qualifying weeks |
| Facilities desk set | 2 hours | 2,000 | Available immediately |
| Accounting desk set | 12 hours | 12,000 | Available immediately |
| IT desk set | 4 hours | 4,000 | 1 qualifying week |
| Office Chaos desk set | 8 hours | 8,500 | 3 qualifying weeks |

These are pricing equivalents, not promised saving times. Floors can dominate. No stockpiling currency across resets, donations, output bonus or random loot. Desk bundles each take one of three display slots. Permanent outfits equip through the existing Mirror, including custom-photo heads and coworker-visible rigs. Missed weeks do not erase eligibility; previous untracked helping dates cannot be invented.

At a flat base rate and inactive floors, all six items total 36 hours of base output; the two immediate desk sets total 14 hours. Participation spreads the remaining purchases across at least three qualifying weeks. An eight-hour absence cap and production growth can change actual affordability. These calculations do not prove retention or human pacing.

## Verification limits

Use isolated PostgreSQL contracts for the actual record, quote, purchase, appearance, costume and rollover bodies. Exercise authenticated API calls with signed synthetic JWTs against disposable PostgREST. Browser screenshots and touch emulation cover narrow portrait, short landscape and desktop; they are not physical-phone tests. No separate hosted Idle Hands test project/branch is connected (checked November 12). Other Patron Platform projects are unrelated and must not be used. Do not substitute production accounts or provision paid test infrastructure silently.
