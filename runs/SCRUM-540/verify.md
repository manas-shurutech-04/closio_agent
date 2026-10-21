# SCRUM-540 — verification

## Run 2 — 2026-10-19 · dev check (B)
Repos: nodejs-ws2targetsalesincentive (MR !248, merge commit 1e8fea4f), nodejs-ws1closio (MR !561, merge commit 65712e8b) · Ruleset: rulesets/story-implementation-workflow.md · Memory applied: none

Setup: dev WS2 `https://dev-target-sales-ws2-apiprivate.japfacomfeed.co.id` (the `http://` address the user gave only redirects to it, so it was saved with `https://`), dev WS1 `https://dev-closio-ws1-apiprivate.japfacomfeed.co.id`, WS1 session from the dev WS1 login. P = the logged-in user's partner `e3d8f926-a1bf-4890-9524-cc2d610152f9` (the seeded October 2026 config only); Q = `a5400000-0000-4000-8000-000000000540` (no configs). The user said both repos are deployed on dev.

### AC checks
**AC1 — all configs for the partner ✅**
- ✅ WS2 direct, `X-Partner-Id: P` → 200, P's seeded config (30 days, 2026-10-01..2026-10-31, active). The first try gave 504 Gateway Time-out once; the same call answered 200 right after, and every later call too
- ✅ WS1 `GET /api/incentives/v1/trader-stock-days-multiplier-configs` → 200, P's seeded config. First tries ❌: 597 `GENERAL_ERROR` `Tidak ditemukan`, also without a session, while an existing route without a session gave 401 `SESSION_EXPIRED`: dev WS1 wasn't running the merged `develop` yet. After it was deployed on dev, the call answered 200

**AC2 — status filter ✅**
- ✅ WS2 direct `?status=active` → 200, P's 1 active config
- ✅ WS2 direct `?status=inactive` → 200, `configs: []` (P has no inactive config on dev)
- ✅ WS2 direct `?status=foo` → 400 `VALIDATION_ERROR` `status must be one of: active, inactive`
- ✅ WS1 `?status=active` → 200, P's 1 active config; `?status=inactive` → 200, `configs: []`
- ✅ WS1 `?status=foo` → 400 `VALIDATION_ERROR` `status harus salah satu dari: active, inactive` (WS2's 400 passed on, `details.upstream_message` in English)

**AC3 — empty result ✅**
- ✅ WS2 direct, Q → 200 `{ status: success, data: { configs: [] } }`

**AC4 — response shape ✅**
- ✅ The config has exactly the 8 fields `id`, `valid_from`, `valid_to`, `multiplier_days` (number 30), `status`, `created_by`, `created_by_name`, `created_at`; dates `YYYY-MM-DD`; `created_at` `….004Z`; `created_by` / `created_by_name` null on the seeded row

**AC5 — WS1 forwards correctly ✅**
- ✅ WS1 with the session → WS2's 200 body passed on unchanged, with P's data (P from the session, the S2S keys accepted by dev WS2)
- ✅ WS1 `?foo=1` → 400 `GENERAL_ERROR` `(root) Skema tidak valid | value={"foo":"1"} | schemaPath=#/errorMessage`
- ✅ WS1 without a session → 401 `SESSION_EXPIRED`

**AC6 — missing client credentials ✅**
- ✅ WS2 no keys / only `x-client-id` / only `x-client-secret` → 401 `MISSING_CLIENT_CREDENTIALS` `Missing client credentials` (all 3)

**AC7 — unknown client ✅**
- ✅ WS2 unknown `x-client-id` → 401 `UNKNOWN_CLIENT` `Unknown client`

**AC8 — wrong client secret ✅**
- ✅ WS2 known id, wrong secret → 401 `INVALID_CLIENT_AUTH` `Invalid client credentials`

**AC9 — missing partner ID ✅**
- ✅ WS2 no `X-Partner-Id` → 400 `PARTNER_ID_MISSING` `X-Partner-Id header is required.`

**AC10 — invalid partner ID ✅**
- ✅ WS2 `X-Partner-Id: abc` → 400 `VALIDATION_ERROR` `Request validation failed`, `details.missing_or_invalid: ["X-Partner-Id"]`

### Test data
None: every check is a GET, on the seeded config and a partner with no configs. Write calls sent: none. WS1 session forgotten, `local/quick-checks/SCRUM-540/` removed.

### Result
✅ Every AC passed on dev (AC1–AC10, 20 scenarios: 13 on WS2 direct, 7 through WS1). Dev WS1 got the merged `develop` part-way through this run (its first calls gave 597 until then). Verified with the dev check (B).

## Run 1 — 2026-10-18 15:50 · B quick check
Repos: nodejs-ws2targetsalesincentive, nodejs-ws1closio · Ruleset: rulesets/story-implementation-workflow.md · Memory applied: none

Setup: both repos on this Mac (branch `SCRUM-540/backend-get-trader-stock-days`); WS1 session from the dev WS1 login; WS1's `WS2TARGETSALES_BASE_URL` pointed at the local WS2 for this run; local WS2 in `RUN_MODE=api`. P = the logged-in user's partner `e3d8f926-a1bf-4890-9524-cc2d610152f9` (seeded October 2026 config + 2 test configs); Q = `a5400000-0000-4000-8000-000000000540` (1 test config). WS1 messages come back in Indonesian (its default language); WS2's English message is in `details.upstream_message`.

### AC checks
**AC1 — all configs for the partner ✅**
- ✅ WS1 `GET /api/incentives/v1/trader-stock-days-multiplier-configs` → 200, P's 3 configs (Nov active, Jan–Jun inactive, seeded Oct), none of Q's, `created_at` newest first
- ✅ WS2 direct, `X-Partner-Id: P` → 200, the same 3 configs; Q → only Q's config (28 days)

**AC2 — status filter ✅**
- ✅ WS1 `?status=active` → 200, 2 active configs
- ✅ WS1 `?status=inactive` → 200, 1 inactive config
- ✅ WS2 direct `?status=foo` → 400 `VALIDATION_ERROR` `status must be one of: active, inactive` (no `details`)
- ✅ WS1 `?status=foo` → 400 `VALIDATION_ERROR` `status harus salah satu dari: active, inactive` (WS2's 400 passed on)

**AC3 — empty result ✅**
- ✅ WS2 direct, a partner with no configs → 200 `{ status: success, data: { configs: [] } }` (not through WS1: the login's partner has configs)

**AC4 — response shape ✅**
- ✅ Every config has exactly the 8 fields `id`, `valid_from`, `valid_to`, `multiplier_days`, `status`, `created_by`, `created_by_name`, `created_at`; `multiplier_days` a number (30, 31, 28); `valid_to` null on the open-ended one; dates `YYYY-MM-DD`; `created_at` `….000Z`

**AC5 — WS1 forwards correctly ✅**
- ✅ WS1 with the session → WS2's 200 body passed on unchanged, with P's data (P resolved from the session, `X-Partner-Id` and the S2S keys accepted by WS2)
- ✅ `X-User-Id` / `X-User-Name`: not visible in a response; checked in the code: `buildWs2Headers` (`nodejs-ws1closio/src/utils/helperFunctions.js:22-30`) adds them from `req.session.cUserUuid` / `cUserName`, which the controller passes
- ✅ WS1 `?foo=1` → 400 `GENERAL_ERROR` `(root) Skema tidak valid | value={"foo":"1"} | schemaPath=#/errorMessage` (the existing `validateSchema` format, "Invalid schema" in Indonesian)
- ✅ WS1 without a session → 401 `SESSION_EXPIRED`

**AC6 — missing client credentials ✅**
- ✅ WS2 no keys → 401 `MISSING_CLIENT_CREDENTIALS` `Missing client credentials`
- ✅ WS2 only `x-client-id` → 401 `MISSING_CLIENT_CREDENTIALS`
- ✅ WS2 only `x-client-secret` → 401 `MISSING_CLIENT_CREDENTIALS`

**AC7 — unknown client ✅**
- ✅ WS2 unknown `x-client-id` → 401 `UNKNOWN_CLIENT` `Unknown client`

**AC8 — wrong client secret ✅**
- ✅ WS2 known id, wrong secret → 401 `INVALID_CLIENT_AUTH` `Invalid client credentials`

**AC9 — missing partner ID ✅**
- ✅ WS2 no `X-Partner-Id` → 400 `PARTNER_ID_MISSING` `X-Partner-Id header is required.`

**AC10 — invalid partner ID ✅**
- ✅ WS2 `X-Partner-Id: abc` → 400 `VALIDATION_ERROR` `Request validation failed`, `details.missing_or_invalid: ["X-Partner-Id"]`

### Repo tests and checks
- nodejs-ws2targetsalesincentive: ✅ tests and coverage gate (`npm run coverage:check`): 2788 passing, 6 pending · 92.59% stmts, 82.95% branches, 91.14% funcs, 93.35% lines (gate 80/70/80/80) · ✅ lint (12 changed files) · ✅ `check:circular`
- nodejs-ws1closio: no test suite (D25) · ✅ lint (4 changed files) · ✅ `check:circular`

### Story check
skipped (quick check)

### Test data
- Added (after a clear yes): 3 configs marked `created_by_name = 'SCRUM-540 QA'` — P inactive 30 days 2026-01-01..2026-06-30, P active 31 days from 2026-11-01 (open-ended), Q active 28 days. The card's QA SQL starts P's active one on 2026-07-01, which would overlap the seeded active October config (`excl_tsdmc_no_active_overlap`), so it starts on 2026-11-01.
- Write calls sent: none (every check is a GET).
- Cleaned up (after a clear yes): the 3 test configs deleted; the seeded default config stays. Servers stopped, WS1 session forgotten, `local/quick-checks/SCRUM-540/` removed.

### Result
✅ Every AC passed (AC1–AC10, 22 scenarios), the repo tests and checks passed; story check skipped (quick check). Verified with B quick check.
