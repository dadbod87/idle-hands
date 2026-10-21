# Idle Hands — mandatory instructions for AI coding agents

Read **this file first**, followed by `docs/CURRENT_STATE.md`, `docs/CHANGELOG.md`, and `docs/RELEASE_CHECKLIST.md`. Git history and code are canonical; documentation must be updated whenever behavior changes.

## Repository and deployment
- Repository: `dadbod87/idle-hands`; production branch: `main`.
- Application: single-file `index.html` with React 18, Babel standalone and Supabase JS, hosted on Vercel project `idle-hands` under The Patron Group.
- Public Vercel URL: https://idle-hands-one.vercel.app/
- Requested custom domain `idle-hands.thepatrongrp.com` is attached/verified in Vercel, **DNS activation not independently verified**. Never announce it live without resolving and testing it.
- Production Supabase project: `wbakpxbvqxppqbrwuokp`. Treat all player data as real. No destructive queries or testing with real accounts.
- Timezone for office/user: America/Los_Angeles; some shared NPC timers are deliberately UTC-epoch based.

## Required change workflow (NO DIRECT MAIN EDITS)
1. Read the four repo documents above, inspect relevant code and Supabase functions; reconcile source docs with runtime.
2. Create a short-lived feature branch from current `main`. Implement the smallest scoped change.
3. Keep all user progress intact. Use separate test fixtures or synthetic read-only SQL. Never execute season wipes, delete players, or invoke restructure on users for tests.
4. Run `node tests/economy-and-office.test.cjs` after installing `@babel/parser@7` in the test environment, and verify any domain-specific tests.
5. Open PR to `main`, wait for GitHub Action `Idle Hands regression gate` to complete successfully. Fix failures on the branch. **Do not merge on pending/failing checks.**
6. For economy SQL changes, use Supabase migrations, compare client/server formulas, verify hypothetical calculations read-only. SQL migrations are not automatically transactionally tied to Vercel; stage cautiously.
7. Merge only after green checks and explicit investigation of runtime-specific regressions. Verify Vercel Production READY and run a real browser playthrough when available.
8. Update `docs/CURRENT_STATE.md`, `docs/CHANGELOG.md` and any altered operational contract in same PR. Record exact tests, limitations, and commit IDs. Never claim an unperformed browser/E2E check.

## Strict game invariants
- Busywork/earnings, purchases, account/auth, Seniority/restructure and achievements are server-authoritative (Supabase); front-end display must reflect backend, not invent awards.
- Purchases: item price = ceil(base cost * growth^(owned units) * Resale discount [0.9 for resale]); default growth comes from catalog (currently 1.35; verify live). Ownership resets on restructuring, permanent Seniority does not.
- Current server idle accrual integrates time-dependent bonuses; check events, buffs, Jess 20% window, chair frenzy 77 seconds, work-hour modifier and offline cap before modifying.
- Avoid duplicate or competing popups: `While you were out` shows offline BW, `Incident report` covers targeted player actions, `Recap` covers weekly summary. `Office Incident Log` is a separate optional simulated history.
- Eight rotating office guests shuffle without replacement: Jess, John, Kyle, Matt, Avah, Nick, Rilie, Joey; Chance and Dave are independent. Keep at most 3 NPC avatars, including paired Nick/Matt gag.
- Office Nonsense features use local browser state for bingo/tasks and deterministic simulated rumors/log. Do not claim cross-device persistence or server gameplay rewards for them.
- Preserve harmless company satire; don't add real employee private information, credentials, secrets, or work data.

## Gaps and test honesty
- The CI gate includes parser and deterministic/helper assertions; **not** authenticated browser tests, real Supabase purchasing, responsive screenshots or multi-client E2E.
- Before expanding real-money-like economies or progress reset logic, develop a separate Supabase test project/isolated fixture path. Do not point destructive suites at Production.
- GitHub branch protection (required status checks) is a separate repository setting. Even a green CI job does not prove that protections are configured; verify and enforce if access permits.

## Expanded gate
- PR workflow now includes browser smoke at desktop/390px and PostgreSQL 16 synthetic contract fixtures. These tests are isolated from Production Supabase.
- No real Supabase test project is yet connected. Tests against real RPCs and authenticated flows require a dedicated test project and secrets; never substitute production credentials.
- Required GitHub branch protection must be separately configured via repository Settings; this connector does not expose branch protection editing. Never claim it's enforced without verification.

## Approved art direction
Read `docs/ART_DIRECTION.md` before creating/editing characters, office furniture, wardrobe, cosmetics, props or icons. Avah MUST have blonde hair and Rilie brunette. Art QA must render `?art-preview=1` at phone/desktop and test every affected category; never change player inventory IDs/prices to achieve visual effects.
