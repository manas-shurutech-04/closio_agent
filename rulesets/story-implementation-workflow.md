# Story Implementation Workflow

> **closio-agent's ruleset for every card** ([D26](../docs/design-decisions.md#d26), [D64](../docs/design-decisions.md#d64), rule A19).
>
> - **Who changes it:** the closio-agent builders, in this folder. No command adds or changes it.
> - **Your own changes go in your user memory** (`flow-memory`): an entry may change a point of this ruleset for you, and the plan names which entry changed which point. The agent rules (`AGENTS.md`, [docs/agent-rules.md](../docs/agent-rules.md)) always win over both.
> - **Backend repos** (`type: BE` in `config/repos/`) follow all of it.
> - **The web app** (`type: FE`) follows its own ruleset, [frontend-story-workflow.md](frontend-story-workflow.md) ([D80](../docs/design-decisions.md#d80), 2026-10-19).
> - **Where it came from:** the SCRUM-517 session (2026-10-02), copied from `japfa/backend/story-implementation-workflow.md` on 2026-10-17. Changed since: Steps instead of Phases, each mapped to its command; works in Claude Code and Codex; Express 5; `validateSchema` before `isAuthenticated` in WS1; migrations and seeders only after the user's yes; keys never pasted into chat; each repo's own test commands and Node version; one plan format with `flow-start`; the card's error codes checked against the code; GitLab MCP, `glab` and the session stats removed; the tests written and run in `flow-develop` (D65), with `scripts/repo-run.sh`; rules A20–A23 added (where request validation goes, no redundant code, every WS1 response field, a review before any migration; D66); Step 8 brought up to date on 2026-10-19 (the checks are built in `flow-verify` and `flow-finish`; WS1 sessions come from the dev login, rule A24; a direct WS2 call sends the caller's client pair, WS1's, D37); planning asked the grilling way and Step 9's MR review by `flow-review` (2026-10-19, D76, D78).

---

## Overview

| Step | What | closio-agent command |
|------|------|----------------------|
| 1. Read the card | Read the Jira card, summarize the ACs | `flow-start` (step 2) |
| 2. Explore | Answer four questions about the codebase | `flow-start` (step 7) |
| 3. Targeted file reads | Read the ~15–20 files to copy patterns from | `flow-start` (step 7) |
| 4. Plan | List all files, map the ACs, get approval | `flow-start` (steps 8–10) |
| 5. Implement | Write new files, edit index files | `flow-develop` |
| 6. Write tests | Unit tests (controller + service) + API integration tests | `flow-develop` |
| 7. Run tests | Run the repo's test commands, fix failures | `flow-develop` (`flow-verify` runs them again) |
| 8. Curl checks | API smoke tests against the running servers | `flow-verify` (on this Mac), `flow-finish` (on dev) |
| 9. Verify | Read edited files, sanity check, MR description; the MR's self-review and the reviewers' comments | `flow-verify`, `flow-push`, `flow-review` |

---

## Step 1 — Read the card

**Goal:** Understand what to build.

Read the card with your AI tool's Jira tools (Claude Code: the Atlassian connector; Codex: the Atlassian app; [setup guide, section 3](../docs/setup-guide.md)). `flow-start` does this and checks the card against the card template ([D58](../docs/design-decisions.md#d58)).

**Output a summary with:**
- Endpoint path and HTTP method
- Acceptance criteria table
- Response shape (JSON example)
- Error reference table (HTTP code, error_code, message, trigger): **to check against the code** (rule A16). The codes and messages that already exist in the code win, and every difference is asked about before planning (rule A18).
- Out of scope items

---

## Step 2 — Explore

**Goal:** Understand the codebase architecture without reading 100 files manually.

Answer these four questions. Where your tool can run helpers in parallel (Claude Code), one helper per question saves time (~2.5 min instead of ~6). Otherwise, read the files directly; every command works in both tools (rule A4).

| Question | Focus | What it discovers |
|-------|-------------|-------------------|
| **A — Project Structure** | "Explore overall project structure" | Monorepo layout, services, tech stack, frameworks |
| **B — Similar Endpoints** | "Search for existing options/similar endpoints" | The closest pattern to copy (route → controller → service flow) |
| **C — Target Module** | "Explore the [incentives/target] module" | Existing models, migrations, seeders, routes, services |
| **D — Cross-Cutting** | "Explore error handling, S2S auth, validation" | Middleware patterns, createError, header validation, forwarding |

**Key question for each:**
- A: "What services exist and where does my code go?"
- B: "What's the exact file-by-file pattern I should copy?"
- C: "What already exists in my target module? Do I need new tables?"
- D: "How do errors, auth, and headers work? What middleware exists?"

---

## Step 3 — Targeted File Reads

**Goal:** Read the exact files you'll copy patterns from. Exploring gives you the map; now read the territory.

The file names below are **examples from `nodejs-ws2targetsalesincentive` and `nodejs-ws1closio`**. In another repo, read the file that does the same job: for example, `headerUtils.js` isn't in ws2closio, ws2notification or ws2pricingengine, and `tableOwnership.js` isn't in ws2closio or ws2pricingengine.

### Must-read files (in order):

**The closest existing endpoint (end-to-end):**
1. WS2 route file (e.g., `incentivePayoutConfigRoutes.js`)
2. WS2 controller file (e.g., `incentivePayoutConfigController.js`)
3. WS2 service file (e.g., `incentivePayoutConfigService.js`)
4. WS2 model file (e.g., `IncentiveScorePayoutConfig.js`)
5. WS2 migration file (e.g., `create-incentive-score-payout-configs.js`)
6. WS2 seeder file (if applicable)
7. WS1 route file (e.g., `incentivePayoutConfigRoutes.js`)
8. WS1 controller file (e.g., `incentivePayoutConfigController.js`)
9. WS1 schema file (e.g., `getPayoutConfigs.js`)

**Shared utilities:**
10. `headerUtils.js` — `getPartnerIdFromHeaders` etc.
11. `createError.js` — Error factory signature
12. `helperFunctions.js` — `buildWs2Headers`, `buildUpstreamFailureResponse`
13. `pgDbUtils.js` — `isValidUuid`
14. `verifyClientAuth.js` — S2S middleware
15. `errorHandler.js` — Error response shape
16. `validateSchema.js` — How `res.validateResponse` works
17. `tableOwnership.js` — Migration helper

**Index files (where you'll register):**
18. WS2 `models/incentives/index.js`
19. WS2 `routes/incentives/index.js`
20. WS1 `routes/incentives/index.js`

**Error codes and messages (rule A16):**
21. WS2 constants (e.g., `src/constants/appConstants.js`, `src/constants/errorCodeEnums.json`) and the codes the closest controllers and middlewares already use
22. WS1 message files (`locales/en/…/messages.json`, `locales/en/api/error.json`)

**What already exists (rule A21, no redundant code):**
23. For every function, helper, constant or regex the card will need, search the repo for one that already does exactly the same job: by name, by what it does, and in the `utils`, `helpers`, `constants` and `middlewares` folders (e.g. `isValidUuid` in `pgDbUtils.js`, `isUuid` in `dataTypeUtils.js`, `isValidUUID` in WS1's `helperFunctions.js`). Note each one you'll reuse, and anything close but not the same, to ask the user about.

**The WS1 response (rule A22):**
24. The WS2 model and the service's response for the card's endpoint: every field the response can return, including the optional ones (e.g. `updated_at`, `updated_by`, `updated_by_name`). This is the list the user confirms before planning.

---

## Step 4 — Plan

**Goal:** Get user alignment before writing code. Every difference between the card and the code is asked about first, the grilling way ([grilling.md](grilling.md), rule A26: what the code answers shown as found, the real decisions in rounds with a recommended answer each, until nothing is open), and nothing is saved before the user's yes in chat (rule A18).

### Plan format (the one `flow-start` shows):

```
Ruleset: rulesets/story-implementation-workflow.md · Memory applied: M2 (changes: …) or none

## Summary
## Acceptance criteria
## Decided before planning      (one line each, pointing to the card's decisions.md: "decision 3")

## Changes
### WS2 — nodejs-ws2targetsalesincentive (N files)
1. Migration — what table, what columns
2. Seeder — what seed data (only when the card needs one)
3. Model — Sequelize model
4. Service — business logic
5. Controller — request handling
6. Route — endpoint path
7. Register in index files

### WS1 — nodejs-ws1closio (N files)
1. Controller — BFF forwarding logic
2. Schema — presence, type and format checks; every response field
3. Route — middleware chain
4. Register in index file

## AC → Implementation Mapping
| AC | Where | How |

## Validation, reuse and response fields
- Validation (rule A20): each check and where it goes: WS1 schema (presence, type, format) · WS2 controller inline · WS2 utils (which file, why) · WS2 service (needs the database)
- Reused (rule A21): <function> from <file> · … · new ones: <function> (searched, none found)
- WS1 response fields (rule A22): every field, required or optional (nullable), as confirmed by the user

## Error codes          (the existing ones, from the code)
## Migrations, seeders, queues
## Tests
## Out of scope
```

---

## Step 5 — Implement

**Goal:** Write all the code.

### Dependency order (WS2 first, then WS1):

```
WS2:
  1. Migration file          (Write — new)
  2. Seeder file             (Write — new, only when the card needs one)
  3. Model file              (Write — new)
  4. Service file            (Write — new)
  5. Controller file         (Write — new)
  6. Route file              (Write — new)
  7. Register model in index (Edit — existing)
  8. Register route in index (Edit — existing)

WS1:
  9.  Controller file        (Write — new)
  10. Schema file            (Write — new)
  11. Route file             (Write — new)
  12. Register route in index (Edit — existing)
```

**Tips:**
- Create independent files in parallel (migration + seeder + model together)
- Edit index files after all new files exist
- Always verify edited index files with Read after editing
- Migrations and seeders follow the repo's existing Sequelize pattern ([D51](../docs/design-decisions.md#d51))

**Where request validation goes (rule A20):**
- **WS1 is a proxy.** Its schema file (`schemas/v1/...`) checks only **presence** (`required`), **type** and **format** (`type`, `pattern`, `minLength`…), each with an `errorMessage` through `replaceMessagePlaceholders` using message keys already in its locale files, as `approval-tools/sfa/approvalApprove/approveRequest.js` does. A URL ID (a path parameter, which the schema doesn't see) is format-checked in the WS1 controller with the existing `isValidUUID` from `utils/helperFunctions.js`. **No business rule in WS1.**
- **WS2 checks everything it receives again** (it's also called directly) and **owns every business-logic check** (ranges, date order, allowed values and combinations…):
  - needs only the request → in the **controller**: inline when small; a function in the repo's domain utils file (e.g. `src/utils/incentives/<feature>Utils.js`) when large: over about 30 lines, used by more than one handler (e.g. create and update), or a nested body (arrays of rows, groups). The function returns an error (`{ error_code, message, details }`) or nothing, and the controller turns it into the 400, as `validateAgeingDeductionConfigBody` does.
  - needs the database (overlap, "does it exist", a run in progress) → in the **service**.
- Error codes, statuses and messages come from the code (rule A16). New code only: existing validation isn't moved unless the card asks.

**No redundant code (rule A21):**
- Before creating any function, helper, constant or regex, search the repo for one that does exactly the same job (Step 3, item 23). **The same:** import and reuse it, never a new copy. **Close but not the same:** ask the user: reuse, extend, or write a new one. **None:** create it.
- Write each search in the card's `develop.md` ("searched for X: none" or "reused X from <file>").
- Where copies already exist, use the one in the shared utils file. WS1's `asyncHandler` has no shared copy: reuse the one in the route file you add to; a new route file copies that one line, as the other route files do.

**Every WS1 response field (rule A22):**
- The WS1 schema's `responses` lists every field the WS2 response can return, as confirmed by the user when planning. Fields that aren't always there are nullable (`type: ['string', 'null']`) and left out of `required`, as `getAgeingDeductionConfigs.js` lists `updated_by`, `updated_by_name` and `updated_at`.

**Common pitfalls (from SCRUM-517 review):**
- **Express 5 (all backend repos, `express ^5.1.0`):** an error thrown in an async route handler reaches the error middleware by itself. Copy what the closest existing route file does: WS2 routes don't wrap their handlers; some WS1 route files (all the incentives ones) wrap them with a small local `asyncHandler`, so a new route in such a file does the same.
- **WS1 routes — middleware order:** `validateSchema` always goes first, then `isAuthenticated`. A request that fails validation then never costs the database calls `isAuthenticated` makes. (For new routes; existing routes stay as they are.)
- **Trailing newline:** Ensure all files end with a newline to avoid `\ No newline at end of file` in diffs.

---

## Step 6 — Write Tests

**Goal:** Write unit tests (controller + service) and API integration tests, committed to the repo, in the format the repo registered (`test_framework` and `test_layout` in `config/repos/<repo>.yaml`). Repos whose `test_command` is `none` get no committed tests ([D25](../docs/design-decisions.md#d25)): today `nodejs-ws1closio` and `ws2jauth`.

### Test stack (the WS2 repos)
- **mocha** — test runner
- **chai** + **chai-as-promised** — assertions
- **sinon** — stubs, spies, mocks (auto-restored via `test/helpers/sinon.js`)
- **proxyquire** (`.noCallThru()`) — dependency injection
- **supertest** — HTTP integration tests
- **nyc** — coverage; the gate is `npm run coverage:check` (80% stmts, 70% branches, 80% funcs, 80% lines)

### Test file structure (example from `nodejs-ws2targetsalesincentive`; follow your repo's `test_layout`):
```
test/
├── unit/
│   ├── controller/incentives/  → ageingDeductionConfigController.spec.js
│   └── services/incentives/    → ageingDeductionConfigService.spec.js
└── api/                        → ageingDeductionConfigOptions.api.spec.js
```

### Controller test pattern:
```javascript
const sinon = require('../../../helpers/sinon');
const { expect } = require('../../../helpers/chai');
const proxyquire = require('proxyquire').noCallThru();

describe('Controller: myController.myMethod', () => {
  let myService;
  let myMethod;
  let req, res, next;

  beforeEach(() => {
    sinon.restore();
    myService = { myMethod: sinon.stub() };
    ({ myMethod } = proxyquire('path/to/controller', {
      'path/to/service': myService,
    }));
    req = { headers: { 'x-partner-id': 'uuid' }, query: {} };
    res = { status: sinon.stub().returnsThis(), json: sinon.stub().returnsThis() };
    next = sinon.stub();
  });

  it('returns 400 when header missing', async () => {
    req.headers = {};
    await myMethod(req, res, next);
    expect(next.firstCall.args[0].status).to.equal(400);
  });

  it('returns 200 on success', async () => {
    myService.myMethod.resolves(data);
    await myMethod(req, res, next);
    expect(res.status.calledOnceWithExactly(200)).to.equal(true);
  });
});
```

### Service test pattern:
```javascript
describe('Service: myService.myMethod', () => {
  const loadService = () => {
    const ModelStub = { findAll: sinon.stub() };
    const service = proxyquire('path/to/service', {
      'path/to/models': { MyModel: ModelStub },
    });
    return { service, ModelStub };
  };

  it('queries with correct attributes and order', async () => {
    const { service, ModelStub } = loadService();
    ModelStub.findAll.resolves([]);
    await service.myMethod();
    expect(ModelStub.findAll.firstCall.args[0].order).to.deep.equal([['col', 'ASC']]);
  });
});
```

### API integration test pattern:
```javascript
const request = require('supertest');
const { createTestApp } = require('../helpers/testApp');

describe('API: GET /endpoint', () => {
  const buildApp = () => {
    serviceStub = sinon.stub();
    const verifyClientAuth = proxyquire('...verifyClientAuth', {
      '../configs/credentialsConfig': { credentialsMap: new Map([['ws1-closio', 'secret-A']]) },
    });
    const controller = proxyquire('...controller', { '...service': { method: serviceStub } });
    const routes = proxyquire('...routes', { '...controller': controller });
    const indexRoutes = proxyquire('...index', {
      '../../middlewares/verifyClientAuth': verifyClientAuth,
      './myRoutes': routes,
    });
    return createTestApp((router) => { router.use(indexRoutes); });
  };

  it('returns 200 with data', async () => {
    serviceStub.resolves(data);
    const res = await request(app).get(endpoint).set(validHeaders);
    expect(res.status).to.equal(200);
  });
});
```

### What to test (map every test to the card's ACs; this table is SCRUM-517's, as an example):
| Test Category | ACs Covered |
|---------------|-------------|
| Missing header → 400 | AC 7 |
| Malformed UUID → 400 | AC 8 |
| Missing S2S creds → 401 (`MISSING_CLIENT_CREDENTIALS`) | AC 9 |
| Wrong S2S secret → 401 (`INVALID_CLIENT_AUTH`) | AC 9 |
| Happy path → 200 with correct data | AC 1, AC 2 |
| Default deduction percentage = 0 | AC 1 |
| Order by overdue_days ASC | AC 2 |
| Same result for different partners | AC 3 |
| Read-only (no side effects) | AC 4 |
| Service throws → 500 | AC 10 |

---

## Step 7 — Run Tests

**Goal:** Execute tests and fix any failures.

closio-agent runs them with `bash scripts/repo-run.sh <repo> test`: the repo's own coverage command (every test and the coverage gate in one run), in the repo's folder, on its Node version (rule A13). By hand, in the repo's folder, after switching to the repo's Node version in the same command (`node_version` in `config/repos/<repo>.yaml`):

```bash
# Only the new test files
source "${NVM_DIR:-$HOME/.nvm}/nvm.sh" && nvm use 22 && npx mocha test/unit/controller/incentives/ageingDeductionConfigController.spec.js --exit

# The whole unit suite, then the API tests (regressions)
source "${NVM_DIR:-$HOME/.nvm}/nvm.sh" && nvm use 22 && npm run test:unit && npm run test:api

# The coverage gate (80/70/80/80)
source "${NVM_DIR:-$HOME/.nvm}/nvm.sh" && nvm use 22 && npm run coverage:check
```

In ws2notification, ws2pricingengine and ws2targetsalesincentive, husky also runs the coverage gate on every commit and push.

---

## Step 8 — Curl Checks

**Goal:** Smoke test the running API with curl commands.

### Prerequisites
- WS2 (nodejs-ws2targetsalesincentive) running on its configured port
- WS1 (nodejs-ws1closio) running on its configured port
  (`flow-verify` starts and stops them itself: `bash scripts/repo-run.sh <repo> start` / `stop`)
- **Migrations and seeders:** started from this Mac with the repo's own `npm run migrate` and `npm run seed` (closio-agent: `bash scripts/repo-run.sh <repo> migrate confirmed`), against the database the repo's `.env` names (today the dev database). **First the user reviews the files (rule A23):** the full migration or seeder (its up and its down), what it changes (tables, columns, rows), the repo, and that it runs against the database the repo's `.env` names. **Then a separate yes in chat, for every run.** The same review comes before the user is asked to run a migration on a server (the deployment doc). No wrong migration reaches a database. They also go into the card's deployment doc ([D12](../docs/design-decisions.md#d12)).
- **Keys and cookies are never pasted into chat** (rule A6). closio-agent runs these checks itself and adds the keys and the session: `flow-verify` on this Mac (`scripts/api-call.sh` for the quick check, `scripts/api-check.sh` for the full check's saved test cases) and `flow-finish` on dev ([D67](../docs/design-decisions.md#d67), [D68](../docs/design-decisions.md#d68), [D72](../docs/design-decisions.md#d72)). The curls below are for running a check by hand.
- **A direct WS2 call sends the caller's client ID and secret** ([D37](../docs/design-decisions.md#d37)): a WS2 checks the pair of whoever calls it, usually WS1's own pair (the values of `WS1_AUTH_CLIENT_ID` and `WS1_AUTH_SECRET_KEY` in WS1's `.env`), saved once under WS1 with `/flow-configure-repo nodejs-ws1closio key ws1-client-id` and `… key ws1-client-secret`. The pricing engine gets another pair from WS1; save that one under the pricing engine repo (`ws2-client-id`, `ws2-client-secret`).
- **WS1 calls use a session from the dev login** (rule A24, [D71](../docs/design-decisions.md#d71)): log in on the dev WS1 with your WS1 login (in the Keychain, [D20](../docs/design-decisions.md#d20)); the session cookie it returns goes to the WS1 on this Mac, first under its own name, then as `closio_session_local` if that WS1 doesn't take it. A web login returns no token.

### WS2 Direct Tests (S2S)

```bash
# AC 1 — Happy path: Get all buckets
curl -s -X GET http://localhost:<WS2_PORT>/api/incentives/v1/ageing-deduction-configs/options \
  -H "x-client-id: <WS1 client ID>" \
  -H "x-client-secret: <WS1 client secret>" \
  -H "X-Partner-Id: e3d8f926-a1bf-4890-9524-cc2d610152f9" \
  | jq .

# Expected: 200 { status: "success", data: { buckets: [5 items, ordered by overdue_days ASC] } }

# AC 7 — Missing X-Partner-Id header
curl -s -X GET http://localhost:<WS2_PORT>/api/incentives/v1/ageing-deduction-configs/options \
  -H "x-client-id: <WS1 client ID>" \
  -H "x-client-secret: <WS1 client secret>" \
  | jq .

# Expected: 400 { status: "error", error_code: "PARTNER_ID_MISSING" }

# AC 8 — Malformed X-Partner-Id
curl -s -X GET http://localhost:<WS2_PORT>/api/incentives/v1/ageing-deduction-configs/options \
  -H "x-client-id: <WS1 client ID>" \
  -H "x-client-secret: <WS1 client secret>" \
  -H "X-Partner-Id: abc" \
  | jq .

# Expected: 400 { status: "error", error_code: "VALIDATION_ERROR", details: { missing_or_invalid: ["X-Partner-Id"] } }

# AC 9 — Wrong S2S credentials
curl -s -X GET http://localhost:<WS2_PORT>/api/incentives/v1/ageing-deduction-configs/options \
  -H "x-client-id: wrong-id" \
  -H "x-client-secret: wrong-secret" \
  -H "X-Partner-Id: e3d8f926-a1bf-4890-9524-cc2d610152f9" \
  | jq .

# Expected: 401 { status: "error", error_code: "INVALID_CLIENT_AUTH" }

# AC 9 — Missing S2S credentials entirely
curl -s -X GET http://localhost:<WS2_PORT>/api/incentives/v1/ageing-deduction-configs/options \
  -H "X-Partner-Id: e3d8f926-a1bf-4890-9524-cc2d610152f9" \
  | jq .

# Expected: 401 { status: "error", error_code: "MISSING_CLIENT_CREDENTIALS" }

# AC 3 — Different partner, same result
curl -s -X GET http://localhost:<WS2_PORT>/api/incentives/v1/ageing-deduction-configs/options \
  -H "x-client-id: <WS1 client ID>" \
  -H "x-client-secret: <WS1 client secret>" \
  -H "X-Partner-Id: f4444444-4444-4444-8444-444444444444" \
  | jq .

# Expected: 200 — same 5 buckets as above
```

### WS1 Tests (via session)

```bash
# Log in on the dev WS1 (rule A24); keep the session cookie it sets
curl -s -c ws1-cookies.txt -X POST https://dev-closio-ws1-apiprivate.japfacomfeed.co.id/api/v1/login \
  -H "Content-Type: application/json" \
  -H "X-Secure-Transmission-Type: x" \
  -H "X-Application-Version: 1.0.0+1" \
  -d '{"userid":"<your userid>","password":"<your password>","napp_pk":4,"client_type":"web"}'

# AC 1 — Happy path through the WS1 on this Mac, with that session
curl -s -X GET http://localhost:<WS1_PORT>/api/incentives/v1/ageing-deduction-configs/options \
  -H "Content-Type: application/json" \
  -H "X-Secure-Transmission-Type: x" \
  -H "X-Application-Version: 1.0.0+1" \
  -H "Cookie: <cookie name>=<session cookie>" \
  | jq .

# Expected: 200 { status: "success", data: { buckets: [...] } }
# If it answers 401, send the same value as: -H "Cookie: closio_session_local=<session cookie>"

# AC 5 — No valid session
curl -s -X GET http://localhost:<WS1_PORT>/api/incentives/v1/ageing-deduction-configs/options \
  -H "X-Secure-Transmission-Type: x" \
  -H "Content-Type: application/json" \
  | jq .

# Expected: 401 (token invalid or session expired)
```

### Verification checklist
- [ ] WS2: 200 returns exactly 5 buckets
- [ ] WS2: Buckets ordered by overdue_days: 0, 7, 14, 21, 30
- [ ] WS2: All default_deduction_percentage = 0
- [ ] WS2: 400 on missing X-Partner-Id
- [ ] WS2: 400 on malformed X-Partner-Id
- [ ] WS2: 401 on wrong/missing S2S creds
- [ ] WS2: Same response for different partners
- [ ] WS1: 200 through full BFF chain (with valid session)
- [ ] WS1: 401 without session

---

## Step 9 — Verify

**Goal:** Confirm all registrations are correct and MRs are ready.

```
Read: WS2 models/incentives/index.js   → model registered?
Read: WS2 routes/incentives/index.js   → route registered?
Read: WS1 routes/incentives/index.js   → route registered?
```

**MR description** (`flow-push` sets it through the GitLab API, [D32](../docs/design-decisions.md#d32); only these, [D70](../docs/design-decisions.md#d70)):
- The Jira card: its key, title and link (e.g., `[SCRUM-517: <card title>](https://productclosio.atlassian.net/browse/SCRUM-517)`)
- The migrations and seeders to run, in order (or none)

**Commits and the MR** (`flow-push`, [D70](../docs/design-decisions.md#d70)): first the rebase onto the latest base branch; when it had a conflict or brought newer commits, every AC is checked again the quick way before any commit, and a failure goes back to develop ([D83](../docs/design-decisions.md#d83)); then atomic commits, each layer's code with its own tests, messages `SCRUM-517: <what this commit does>`; the repo's git hooks always run; one push per repo creates the MR, titled `SCRUM-517: <card title>`, ready for review, assigned to you.

**The MR's review** (`flow-review`, [D78](../docs/design-decisions.md#d78)): while the MR waits for the merge, a self-review against [code-review.md](code-review.md) (the story; the basics: no redundant code, the right file for each piece), then the reviewers' comments; fixes as new commits on top, pushed into the same MR after the user's yes (no rebase, never forced).

---

## Checklist (copy for each story)

- [ ] Ticket fetched and ACs summarized
- [ ] The four exploration questions answered
- [ ] Closest existing endpoint read end-to-end
- [ ] Shared utilities read (createError, headerUtils, etc.)
- [ ] Error codes and messages read in the code (constants, WS1 message files)
- [ ] Index files read (where to register)
- [ ] Plan presented and approved
- [ ] WS2 migration created
- [ ] WS2 seeder created (if needed)
- [ ] WS2 model created and registered
- [ ] WS2 service created
- [ ] WS2 controller created
- [ ] WS2 route created and registered
- [ ] WS1 controller created
- [ ] WS1 schema created: presence, type and format only; every response field, optional ones nullable (rules A20, A22)
- [ ] Business-logic checks in WS2: controller (inline or utils) or service (database) (rule A20)
- [ ] Every new function searched for first; nothing duplicated (rule A21)
- [ ] WS1 route created and registered (`validateSchema` first, then `isAuthenticated`)
- [ ] All index files verified
- [ ] WS2 controller unit test written
- [ ] WS2 service unit test written
- [ ] WS2 API integration test written
- [ ] Tests pass (the repo's commands, on its Node version)
- [ ] Lint on the card's changed files looked at (warnings only; older lint errors in the repo are left alone)
- [ ] Coverage gate passes (`npm run coverage:check`)
- [ ] Migrations and seeders reviewed by the user, then run only after a separate yes (rule A23)
- [ ] Curl verification — WS2 happy path (200)
- [ ] Curl verification — WS2 error cases (400, 401)
- [ ] Curl verification — WS1 through BFF (200)
- [ ] Curl verification — WS1 no session (401)
- [ ] MR descriptions added (Jira link, migrations and seeders to run)
- [ ] JIRA error reference matches actual middleware codes
- [ ] MR self-reviewed with `flow-review` (`code-review.md`: no redundant code, the right files, the basics) and reviewed on GitLab

---

## Setup

- **Jira:** your AI tool reads cards through Claude's Atlassian connector (Claude Code) or the Atlassian app (Codex); see the [setup guide, section 3](../docs/setup-guide.md).
- **GitLab:** closio-agent creates the MRs with git push options in the one push and sets their description through the GitLab API with your token from the Keychain ([D31](../docs/design-decisions.md#d31), [D32](../docs/design-decisions.md#d32)). Nothing else to set up here.
