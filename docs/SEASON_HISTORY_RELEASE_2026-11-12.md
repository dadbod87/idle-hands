# Private standings preservation — live November 12

The user authorized the record book/cosmetic continuation and checks, retaining the history-only-before-reset / gameplay-after-reset split. Applied only private preservation, once, as provider migration `20261112215816_office_season_records_history_only` at 13:58:16 Pacific. The full gameplay package and frontend remain held; main is still `9d622b9`, build 194.

Reviewed payload: `sql/season_records_history_only.sql`, source checkpoint `bd79bcf85508e9b8d4e1e2e3abb18afd19317bba`. Stored provider payload SHA-256 matches exactly:
`10db950e43efaaea4c34736d89166a975a9446cceb3745fe496ff7e27a49d1b6`.

The two private tables and private season trigger preserve game-recorded weekly earnings, places and names when the existing normal rollover inserts its season, before it clears player counters. No player/catalog/public-function update, accrual call, forced reset, gameplay control or client grant. Older seasons backfill only their recorded winner summary; no old individual standings are invented.

Post-install verification:

- Three historical winner-only summaries; zero full standing rows before the next natural rollover.
- Public function fingerprint unchanged: `1885d7cfd8fbf9196db03ed4ee430455`.
- Catalog fingerprint unchanged: `93d503bc3add0d000f5049b73cd7a446`.
- Current week stayed `2026-46`; no rollover was invoked.
- Capture body MD5 `09c36ae4200284848c84da1bf9085e24`, matching reviewed source; trigger enabled.
- Both private tables have RLS. Neither anon nor authenticated can read/write them or execute the capture function.
- Security advisors report informational RLS/no-policy notes for these deliberately private, client-denied tables. Do not add permissive policies to suppress the notes. [Advisor documentation](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy).
- Existing action journal continues: aggregate verification found 1,018 archived actions and zero retained events missing. No raw action export.

Both installation orders, unchanged player/public-function checks, natural rollover, ties, immutable results, old coverage, privacy and reuse passed actual PostgreSQL contracts in regression run `43315096847`'s isolated database job. Browser/gameplay results and final candidate evidence belong to PR #56; they are not required to expose this private capture because no UI was released.

Do not reapply the standalone migration. The full held installer validates/reuses it. Keep both action and standings preservation on frontend rollback. Future schema changes need a separate reviewed forward migration; the applied payload is immutable. After normal Friday rollover, independently verify complete capture before releasing the reviewed gameplay/backend. Physical-device and hosted Supabase Auth checks remain distinct from disposable API/browser evidence.
