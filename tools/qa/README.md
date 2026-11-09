# Local accessibility and browser diagnostics

This is a development-only Playwright + axe-core tool. It runs the current game on a loopback server, intercepts game/auth/RPC/socket data using the existing synthetic fixture, blocks other external requests, and visits the floor, Help, Office Directory and desk at 1440px and 390px. The narrow profile emulates mobile/touch; it is not a physical-device test.

## Run from the repository root

Requires Node >=22.12 and Python 3. Dependencies are isolated here, not in the game or a root package.json.

```sh
npm ci --prefix tools/qa --ignore-scripts
```

Use the installed Chrome browser (the path verified on the development Mac):

```sh
QA_BROWSER=chrome npm --prefix tools/qa run audit
```

Or install the pinned Playwright Chromium, then run without QA_BROWSER:

```sh
(cd tools/qa && npx playwright install chromium)
npm --prefix tools/qa run audit
```

For Linux automation, use an OS/browser combination supported by the pinned Playwright version; the repository currently uses Ubuntu 24.04 for Playwright 1.56.1. QA_PORT can select another local port; an occupied port fails instead of silently testing a different server. Production/custom remote base URLs are deliberately unsupported.

## Read the results

```sh
npm --prefix tools/qa run report
```

Artifacts stay in ignored `test-results/qa-audit/` and `playwright-report/qa/`: screenshots, axe JSON, per-profile summaries and diagnostic HTML; failure traces are retained. All captured account/session data is synthetic. The fixture clock holds scheduled world events quiet while normal intervals continue running.

**Default mode collects findings; a completed audit is not an accessibility pass.** Existing violations are visible in the reports, not hidden by broad exclusions or new CI exceptions. WCAG 2 A/AA and 2.1 A/AA tagged rules are scanned. Incomplete results need review. Automated scans do not cover every accessibility criterion, screen-reader experience, art readability, keyboard/touch route or physical device.

For a deliberate zero-violation check after addressing the baseline:

```sh
QA_A11Y_STRICT=1 QA_BROWSER=chrome npm --prefix tools/qa run audit
```

Strict mode fails on detected violations. Both modes still fail on navigation errors, uncaught page errors, accidental economy-action calls or changed synthetic economic fields. This tool does not replace the existing regression/release gate. No production purchasing, server load testing, account creation or progress changes are involved.

Dependencies: Playwright / @playwright/test (Apache-2.0), axe-core / @axe-core/playwright (MPL-2.0). See lockfile and package notices.
