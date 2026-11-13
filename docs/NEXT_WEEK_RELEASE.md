# Next-week office package — staged release

The owner approved the automatic November 13, 2026 release task at 16:01 America/Los_Angeles, including migration, scheduler activation, merge and deployment, subject to the technical release gates. Do not publish early or force the normal weekly reset. The later instruction permits Weekly Race recording after the new Production release is confirmed live, replacing the earlier midnight delay.

Draft PR: https://github.com/dadbod87/idle-hands/pull/56. Its current candidate and complete three-job regression result are authoritative. Review current source and provider state before acting; a clock time is not evidence that rollover completed. This public contract intentionally excludes raw player history, export details and production history counts.

## Package

- Durable social profiles and charts with honest retained-history coverage and hush-safe public statistics. History survives Friday; missing older events are not invented.
- Weekly earned Seniority supplies the output bonus separately from points available to spend. Friday still clears weekly Seniority and perks.
- Cover becomes a nonstacking twenty-minute +15% benefit instead of a cash transfer. Permanent cosmetic pricing retains a base-production high-water benchmark across restructuring and reset.
- Deliberate phone movement and nearby interaction controls, with collapsible minimap/emotes.
- Rotating cooperative projects, stretch goals, dated mementos and participation-based multi-week collections without a consecutive streak requirement.
- A two-slot toolkit, bounded earned refills, Rescue, Confetti, Spam Filter, Receipt Clip and one purchased Return to Sender shield. Normal sabotage stacking remains; reflection never chains and theft transfers only the actual debit.
- Season records, personal bests, two costumes, participation outfits and themed desk sets. Ownership and saved finishes persist.
- Grouped owned-item customization, empty hands, removable effects and earlier owned glow/atmosphere choices. Free equip never lowers highest ownership. Confirmed paid colors use existing pricing; atmosphere patterns render through the shared material helper, while non-solid glow quotes are refused.
- A build-specific What's new notice after sign-in and startup notices. Dismissal is per player/browser, Help can reopen it, and blocked storage still permits dismissal for the session. No acknowledgement RPC changes progress. Keep the manifest aligned with BUILD for future player-facing updates.

## Release order

1. Read AGENTS.md, CURRENT_STATE.md, CHANGELOG.md, RELEASE_CHECKLIST.md and the PR. Reconcile current main, reviewed candidate, deployment and all three completed-success checks. Never certify changed source with older green results.
2. Independently verify the ordinary Friday rollover saved complete closing standings and retained action history. If incomplete, hold. Do not call sync, accrue, roll_week or season_wipe to manufacture readiness.
3. Compare the reviewed payload hashes in the release task/PR with fetched source. Check installed stages before retries. Do not reapply either existing history-preservation stage. Apply the full guarded backend once through the provider migration mechanism and verify functions, privacy, ownership, counters, prices and history. Its legitimate old capped-income settlement is not a reason to expect every balance unchanged. Never run mutation tests against real players.
4. Apply sql/weekly_race_prepare.sql after backend verification. It prepares one exact five-minute job while collection stays disabled. Verify its owner/database/command/schedule/active status and a real successful zero-capture execution. Mismatched jobs must not be overwritten. No manual collector call substitutes for scheduler evidence.
5. Publish the exact reviewed frontend only after these gates pass. Confirm Production READY, deployment commit, served source and safe browser behavior.
6. Only then apply sql/weekly_race_activate.sql. It requires the prepared job and normal rollover, sets the first activation time and enables recording. The database lower bound remains Friday's reset. Replays preserve the start time. Verify first real scheduled samples at or after activation; do not fabricate earlier points or expose peer wallet history. If activation fails, keep collection paused and report the partial release.
7. Record actual release evidence and limitations. Physical-phone and hosted Supabase Auth tests remain distinct from fixture/API tests. Preserve all history, rewards, receipts, styles and saved charts on rollback; prefer forward fixes and never restore the gift exploit. No automatic live-player QA or messages to other people.

See WEEKLY_RACE_CONTRACT.md, OFFICE_DEPTH_CONTRACT.md and RECORDBOOK_AND_COSMETICS.md for detailed feature behavior. Immutable preservation payloads remain in source; this public summary does not duplicate private exports or historical operational receipts.
