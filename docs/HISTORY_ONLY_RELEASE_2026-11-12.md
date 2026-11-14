# History-only release — live November 12, 2026

Nick explicitly authorized the separate history update. Migration `20261112195653_office_action_journal_history_only` was applied once at **11:56:53 AM Pacific** to the existing database. Frontend remains main `9d622b9` / build 194. The rest of build 195 stays held until after verified normal Friday rollover.

Reviewed source: `sql/office_action_journal.sql` at `7045b0e6e3f21a3a3f6421457290fc7b7c9e6d43`. SHA-256: `3d0e5d1a482bd5af84adfb67b9618128337045685d1c5a5712f96193a4d665d4`. The provider's stored migration statement is byte-for-byte identical. No manually invented migration filename was created. Do not reapply it or edit the historical payload.

## Verification at 11:59 AM Pacific

| Check | Result |
|---|---|
| Migration ledger entries | Exactly one |
| Retained targeted actions / journal rows | 946 / 946 |
| Missing / mismatched retained events | 0 / 0 |
| Earliest retained action | November 6, 4:12:09 PM Pacific |
| Continuous capture starts | November 12, 11:56:53 AM Pacific |
| Capture trigger | Enabled; INSERT and hush UPDATE |
| Existing player count | 7 |
| Full feature package installed | No |
| Private table RLS | Enabled on both tables |
| Anonymous/authenticated schema, table and helper access | None |

Helper source MD5 values match: classifier `0ff82e1975eda680a9d61b49297388bd`; capture `751b1e6b8981022f0578e5c7aa099e19`. Both set an empty search path. Only expected no-policy INFO notices concern the intentionally private tables; unrelated existing advisories were not changed.

Public function fingerprint stays `6f4df351d182f9823aa63fb48d0e3a72`; catalog fingerprint stays `ea8dfcb2601f556e1cd80745e3785b00`. The payload performs no player update, economy replacement, reset/accrual call, project award or frontend change. Player fingerprints differed between independent reads while the game remained live; this is not an identical-balances snapshot claim.

No post-install targeted action had occurred at verification. Future capture is enabled and tested in disposable SQL; no real player action or forced reset was used for QA, and no raw history export was needed.

All three code-candidate jobs passed on `7045b0e`: eight logic suites, both SQL installation orders, concurrency checks, 29 focused walkthroughs and 135 browser tests. [Run](https://github.com/dadbod87/idle-hands/actions/runs/43289100515). The first browser attempt stalled in the desktop rug test; the unchanged retry passed. Physical-phone and authenticated hosted isolated-backend gameplay remain unperformed.

This documentation-only receipt changes no tested runtime or SQL. Any newer candidate needs its own required gate before full release. Keep the journal on rollback. The full installer must validate and reuse it after independently confirmed Friday November 13, 4 PM Pacific rollover, without deleting history or awarding retrospective project credit. No automatic future deployment is scheduled.
