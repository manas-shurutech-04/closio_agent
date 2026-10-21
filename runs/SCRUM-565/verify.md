# SCRUM-565 — verification

## Run 2 — 2026-10-21 16:12 · B quick check
Repos: closio-web-v2 · Ruleset: rulesets/frontend-story-workflow.md · Memory applied: none

### APIs (web cards)
- `ageing-options` — GET `/api/incentives/v1/ageing-deduction-configs/options` — available on dev; probe → 200.
- `channels` — GET `/api/dashboard/v1/field-list/046226b9-5e58-416a-9613-dc583c97d3e5/options` — available on dev; probe → 200.
- API probe: ✅ every GET API answers on dev (login succeeded after fe-login-password was updated).

### AC checks
- AC 1 — channel dropdown stays usable at 786px: ✅ (dropdown width ≥ 190px)
- AC 1 — channel dropdown stays usable at 390px: ✅
- AC 2 — "+ Tipe Salesman" does not overlap the dropdown at 786px: ✅
- AC 3 — header stays a single row on desktop (1280px): ✅
- Playwright: 3 ACs, 4 tests, all passed.

### API structures
- None in the card (CSS-only card; no `## API request and response`).

### Repo tests and checks
- `closio-web-v2 test`: 219 files, 4075/4075 passed (coverage: branches 78.33%, statements/lines 65.03%, functions 62.82%). The Roles flaky test passed this run. No check commands for this repo.

### Story check
- skipped (quick check)

### Test data
- none (layout checks only; GET APIs). Quick-check scratch files removed.

### Result
PASSED — all 3 ACs ✅, repo tests ✅. The container-driven fix (flex-wrap + min-width on the dropdown) holds at 786px, 390px and 1280px.

## Run 1 — 2026-10-21 16:05 · B quick check
Repos: closio-web-v2 · Ruleset: rulesets/frontend-story-workflow.md · Memory applied: none

### APIs (web cards)
- `ageing-options` — GET VITE_INCENTIVE_BASE_URL `/ageing-deduction-configs/options` — user: available on dev (not mocked).
- `channels` — GET VITE_FORMS_BASE_URL `/field-list/046226b9-5e58-416a-9613-dc583c97d3e5/options` — user: available on dev (not mocked).
- API probe: ❌ did not run — blocked at login (see Result).

### AC checks
- AC 1 (dropdown usable at 786/390px): NOT CHECKED — blocked at login.
- AC 2 (no overlap at 786px): NOT CHECKED — blocked at login.
- AC 3 (single-row desktop at 1280px): NOT CHECKED — blocked at login.
- Playwright scenarios written: local/quick-checks/SCRUM-565/ac-1.spec.ts, ac-2.spec.ts, ac-3.spec.ts (kept for a re-run).

### API structures
- None in the card (CSS-only card; no `## API request and response`).

### Repo tests and checks
- Not re-run this run (blocked before reaching the checks). Prior develop run: ChannelBox 11/11, SlabConfigForm 14/14, full suite 4074 pass + 1 pre-existing flaky (Roles, unrelated).

### Story check
- skipped (quick check)

### Test data
- none (layout checks only; GET APIs)

### Result
BLOCKED — the automated e2e login fails, so no AC could be checked by Playwright.
- The Playwright `loggedIn` fixture submits the FE login (phone 6285200001 from Keychain) and the login page returns a server error: "Terjadi Kesalahan — Terjadi kesalahan. Silakan coba lagi dalam beberapa saat." `page.waitForURL` then times out (never leaves /login). Reproduced twice.
- This is an e2e login / environment setup issue, independent of the SCRUM-565 CSS change.
- Note: the layout fix was already visually confirmed by the user at 786px during the develop review and approved.
- Suggested fixes (user decides):
  1. Check/refresh the Playwright FE login (Keychain / `/flow-configure-user playwright`), or confirm the running web app points at the same environment that login belongs to, then re-run `/flow-verify SCRUM-565 quick`.
  2. Or, given the manual visual confirmation, decide whether to record the verification as manually confirmed and proceed to `/flow-push`.
