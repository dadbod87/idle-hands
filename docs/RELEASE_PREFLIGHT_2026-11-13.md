# November 13 release preflight — preparation only

The owner authorized Weekly Race, corrected price wording and release verification. The existing candidate is f390448 in draft PR #56; all its required jobs passed. New race changes need their own exact-head gate. Main remains 9d622b9 / build 194. No frontend merge, full migration, pg_cron installation/activation, real-player test or forced rollover was performed.

Read-only database checks on November 13:

| Check | Result |
|---|---|
| All fourteen guarded public function definitions | Match the audited full-installer hashes |
| Action journal | 1,342 archived actions; zero retained events missing |
| Current season state / expected calendar week | Both 2026-46; Friday rollover has not occurred |
| Existing private history tables | RLS enabled |
| pg_cron installed / named scheduler API | Absent; activation is still required |
| pg_cron available / preloaded | Version 1.6.4 available; shared library already preloaded |

The applied journal and standings-only payloads remain immutable. The full new payload and separate race activation source are held in this PR. Local parser, generated-client consistency and actual chart geometry checks passed; new isolated SQL, background scheduler, API and browser evidence belongs to the PR gate.

This is not evidence of a completed reset. Nick subsequently approved an automatic release task for November 13, 16:01 Pacific, subject to all technical release gates. His later instruction replaces the midnight delay with recording after the new release is live. After 4 PM Pacific, re-read current main/candidate and live function guards, independently verify the ordinary rollover and complete final standings for 2026-46, compare the reviewed payload hashes, apply/verify the backend, then prepare/verify the exact five-minute job while collection stays disabled. A real successful pre-publication scheduler run must return zero snapshots. Verify without forcing income/reset.

Publish the frontend only after the backend/prepared-job checks and successful exact-head gate. Confirm Production READY, served source and current browser behavior; only then apply the separate activation payload and verify the first actual scheduled samples. Activation sets not_before to its actual time, bounded below by Friday's reset, and idempotent retries preserve it. Hosted Supabase Auth sign-in and physical-phone checks remain unperformed; synthetic browser/JWT tests are distinct evidence. Preserve action history, final standings, race charts, styles, rewards and receipts on rollback.
