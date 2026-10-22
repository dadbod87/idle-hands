# Office comedy release — acceptance and evidence

Scope approved October 22: repair audit findings; discoverable humor; interactive prop performances; persistent asynchronous office votes; named player commendations; shared lounge progression; more varied writing. Existing progress, first names, economy and functionality must survive.

Acceptance:
1. Bingo records ambient and visitor/partner speech without duplicate credit; visible progress feedback. Failed memo submission retains editable draft; no duplicate sends while filing. Chair requires approaching within normal reach (UI guard, not a claim of server-authoritative position tracking).
2. Free scene actions for couch, plant, printer apology, calendar, shelf and break notice produce visible original art/animation and rotating punchlines; reduced-motion alternative. Scene actions route the player to the prop and return to the floor. Successful real printer fixes also produce a visual joke. No new earnings or changes to normal movement/emotes.
3. Weekly real office poll: one changeable vote per player, fixed funny choices, real aggregate counts and previous outcome, Pacific Friday 4pm cycle. Can contribute while others are offline. Clear unavailable/error/pending states; no pretend votes.
4. Cosmetic commendations name actual players, preserve one ballot per voter/category/week, support changes and display ties honestly. No invented economic achievements.
5. Lounge story advances from real shared prop participation, with visible world staging, real counts and honest cosmetic-only labeling. Existing locked lounge and secrets remain functional.
6. Guided discovery is optional/dismissible, resumes correctly, and exposes existing coffee invites, costumes, suggestions and bingo. Existing desktop/mobile controls remain reachable.
7. Expand log variety and prevent immediate repeating log entries. Every stage gets relevant contracts/browser checks. Final full CI jobs all success before merge; migration is additive and verified before frontend release; public deployed artifact matches tested source.

Evidence and limitations will be recorded below and in release PR. All gameplay tests use isolated fixtures; no production test claims/votes/nominations or player resets. Physical phone remains unverified unless explicitly tested.

Stage 1: parser/economy + approved-name contracts pass. Three focused Chromium tests pass (18.5s): ambient bingo credit, failed/successful memo retries, desktop/mobile chair approach and claim outcomes. Chair location remains client-side; this is normal UI reach enforcement, not anti-cheat proof.

Stage 2: two focused desktop/Pixel 7 Chromium tests passed (17.9s), exercising plant and couch scenes, joke variation, reduced motion and unchanged inventory/economy. More scene coverage and final gallery review follow.

Stage 3: actual migration contract passed in isolated PostgreSQL WASM together with all seven pre-existing SQL fixtures. Checks include grants/RLS, authentication, changing ballots rather than duplicates, forged inputs/self-nominations, activity replay/cap, cross-player counts, prior-cycle separation, and exact preservation of synthetic player snapshots. CI PostgreSQL 16 remains the required release gate.

Stage 4: shared desktop/phone test passed (28.3s): vote/change/failure, cross-player reload, honest commendation tie and certificate, real-count lounge thresholds and world staging. Review caught and fixed left-edge scene-card clipping and widened the desktop shared cards. Added stale-week ballot checks, previous honors, explicit unavailable-service/recovery and all four paperwork actions/printer confirmation tests; final suite covers those changes.

Database advisory baseline (before migration): legacy `perk_of` search_path warning, broad legacy SECURITY DEFINER execute grants and anonymous-read policies, plus password-protection notice. These are pre-existing and need a separate access-control review; this release does not widen any existing grants. New tables deny direct client access and new RPCs require auth + an existing signed-in player. See [function advisory](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable) and [search path advisory](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable). Do not interpret a green gameplay suite as a security audit of the legacy game.

Final polish: field guide is linked from Help; new guide badge is dismissible/persistent. Scene scripts resume across reloads, effects appear on the prop itself, and sitting is aligned with the couch seat; normal walking cancels the pose. The on-floor joke card sits above the prop so it does not hide the performance. Desktop community cards override both width and max-width, and certificates scroll into view. A refresh started before a filing cannot overwrite the confirmed result, and polling pauses during a filing. Past-week ballots/commendations are refused by the server rather than silently voting in a new topic.

Local full-run investigation: one existing sound-settings test timed out waiting for boot after reload. Both desktop and mobile sound-settings cases passed on the focused rerun; no speculative auth changes were made. A later scene-test assertion was updated to check both reduced-motion water effects after the world effect was added. Full final GitHub CI is mandatory, with any remaining failures fixed before merge. No claim of a clean initial local full run.
