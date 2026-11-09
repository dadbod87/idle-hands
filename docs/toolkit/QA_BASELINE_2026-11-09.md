# Current-game QA baseline — 2026-11-09

This is a fixture-only diagnostic baseline for build 194, collected with the new local Playwright 1.56.1 / axe-core 4.14.0 tool in installed Chrome. It is not a production-account audit or a declaration of accessibility compliance. Two diagnostic flows completed (eight state scans). The 390px profile emulates mobile/touch; neither profile is a physical-device or full screen-reader/manual assessment.

## Automated findings

All reported rules below have axe impact `serious`. Counts are affected elements in that scan, not distinct bugs or unique players; the same background control can appear in several modal scans. Each state also has two incomplete results requiring manual review.

| Viewport | State | ARIA attribute | Contrast | Label/name mismatch |
|---|---|---:|---:|---:|
| 1440 | floor | 1 | 1 | 4 |
| 1440 | help | 1 | 1 | 4 |
| 1440 | directory | 1 | 1 | 14 |
| 1440 | desk | 1 | 3 | 2 |
| 390 | floor | 1 | 3 | 1 |
| 390 | help | 1 | 3 | 1 |
| 390 | directory | 1 | 3 | 7 |
| 390 | desk | 1 | 3 | 2 |

## Follow-up queue

- Review `aria-prohibited-attr` against the affected element role rather than removing labels indiscriminately.
- Inspect contrast in the screenshot and computed colors, including the phone HUD and desk content. Preserve the illustrated palette while making text readable.
- Reconcile visible control labels with accessible names, especially directory cards, without breaking useful speech/keyboard identification or hiding descriptive content.
- Perform keyboard/focus and real-device/screen-reader checks; automated findings and incomplete results do not settle those experiences.

No current-game UI changes are made by this tooling update. Review priorities and exact reproductions before fixing; baseline findings are visible, not silently suppressed. The full per-element evidence is in ignored local JSON/report artifacts.

## Tool behavior verified

- All eight scans captured real rendered fixture states; screenshots were inspected at desktop/phone size.
- No uncaught page errors or blocked external origins were observed; Supabase HTTP/auth/socket data stayed intercepted.
- No purchase/deed/work/restructure/style mutations occurred; synthetic economic fields remained unchanged.
- Report mode completed despite findings, with explicit mode annotations. Strict mode was separately checked to reject existing findings.
- Dependency audit reported zero known advisories for the pinned QA dependency graph at this date; that is not a security audit of the game.

## Reproduce

See [QA tool instructions](../../tools/qa/README.md). Generated screenshots, full axe output, summaries and failure traces are stored under ignored `test-results/` and `playwright-report/`. These outputs are not committed as a brittle DOM snapshot or a new CI exemption.
