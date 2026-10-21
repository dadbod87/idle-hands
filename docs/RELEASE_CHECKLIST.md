# Idle Hands — Required pre-production release gate

## Before code
- [ ] Read AGENTS.md, CURRENT_STATE.md and CHANGELOG.md.
- [ ] Fetch newest main, confirm Vercel/Supabase targets, inspect affected RPCs.
- [ ] Create short-lived branch, document scope and rollback.
- [ ] Confirm no production-player reset or destructive test.

## Automated gate
- [ ] Run `npm install --no-save --no-package-lock @babel/parser@7` then `node tests/economy-and-office.test.cjs`.
- [ ] PR created to main, GitHub `Idle Hands regression gate` completed **success**, not just started.
- [ ] Test any altered economy formula both client and server; SQL hypothetical samples must be read-only on prod.
- [ ] Confirm NPC maximum, schedule determinism and no broken popup behavior for any NPC/office features.
- [ ] Confirm desktop/mobile layout in browser if graphical browser available; if not, report as unverified.

## Review and publish
- [ ] Update state and history documents with actual implementation and testing.
- [ ] Verify no secret or private employee data in repo.
- [ ] Merge PR only when checks green and no known blocking errors.
- [ ] Confirm Vercel Production `READY`, actual build SHA and relevant app behavior.
- [ ] Keep working fallback URL; custom domain requires independent DNS/HTTPS check.
- [ ] Record release SHA, limitations and follow-ups for the next AI chat.

## Do not overclaim
Passing this CI gate does NOT mean the browser or real RPC flows were tested. Never claim “full end-to-end QA” until an authenticated isolated test suite exists and has actually run.
