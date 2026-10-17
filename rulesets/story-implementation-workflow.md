# Story Implementation Workflow

> **closio-agent's ruleset for every card** ([D26](../docs/design-decisions.md#d26), [D64](../docs/design-decisions.md#d64), rule A19).
>
> - **Who changes it:** the closio-agent builders, in this folder. No command adds or changes it.
> - **Your own changes go in your user memory** (`flow-memory`): an entry may change a point of this ruleset for you, and the plan names which entry changed which point. The agent rules (`AGENTS.md`, [docs/agent-rules.md](../docs/agent-rules.md)) always win over both.
> - **Backend repos** (`type: BE` in `config/repos/`) follow all of it.
> - **The web app** (`type: FE`) follows its common practices until a frontend ruleset exists: read the card, explore and read the closest existing pattern, the plan format, tests mapped to the ACs, verify. It skips the parts about WS1/WS2, mocha, Sequelize and the S2S curl checks. Its tests are Vitest in the repo; Playwright stays outside the repo ([D24](../docs/design-decisions.md#d24)).
> - **Where it came from:** the SCRUM-517 session (2026-10-02), copied from `japfa/backend/story-implementation-workflow.md` on 2026-10-17. Changed since: Steps instead of Phases, each mapped to its command; works in Claude Code and Codex; Express 5; `validateSchema` before `isAuthenticated` in WS1; migrations and seeders only after the user's yes; keys never pasted into chat; each repo's own test commands and Node version; one plan format with `flow-start`; the card's error codes checked against the code; GitLab MCP, `glab` and the session stats removed.

---

## Overview

| Step | What | closio-agent command |
|------|------|----------------------|
| 1. Read the card | Read the Jira card, summarize the ACs | `flow-start` (step 2) |
| 2. Explore | Answer four questions about the codebase | `flow-start` (step 7) |
| 3. Targeted file reads | Read the ~15–20 files to copy patterns from | `flow-start` (step 7) |
| 4. Plan | List all files, map the ACs, get approval | `flow-start` (steps 8–10) |
| 5. Implement | Write new files, edit index files | `flow-develop` (coming) |
| 6. Write tests | Unit tests (controller + service) + API integration tests | `flow-verify` (coming) |
| 7. Run tests | Run the repo's test commands, fix failures | `flow-verify` (coming) |
| 8. Curl checks | API smoke tests against the running servers | `flow-verify` (coming) |
| 9. Verify | Read edited files, sanity check, MR description | `flow-verify`, `flow-push` (coming) |

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

---

## Step 4 — Plan

**Goal:** Get user alignment before writing code. Every difference between the card and the code is asked about first, and nothing is saved before the user's yes in chat (rule A18).

### Plan format (the one `flow-start` shows):

```
Ruleset: rulesets/story-implementation-workflow.md · Memory applied: M2 (changes: …) or none

## Summary
## Acceptance criteria
## Decided before planning

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
2. Schema — AJV validation
3. Route — middleware chain
4. Register in index file

## AC → Implementation Mapping
| AC | Where | How |

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

Run them in the repo's folder, with the repo's own commands (`test_unit_command`, `test_api_command`, `coverage_command` in `config/repos/<repo>.yaml`), after switching to the repo's Node version in the same command (rule A13; `node_version` in the same file):

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
- **Migrations and seeders:** started from this Mac with the repo's own `npm run migrate` and `npm run seed`, against the database the repo's `.env` names (today the dev database). **Only after the user's yes in chat, for every run**, naming the repo and what will run. They also go into the card's deployment doc ([D12](../docs/design-decisions.md#d12)).
- **Keys and cookies are never pasted into chat** (rule A6). The WS2 client ID and secret come from the repo's `.env` ([D34](../docs/design-decisions.md#d34)); the WS1 session comes from the login API with your logins in the Keychain ([D20](../docs/design-decisions.md#d20)). closio-agent runs these checks with its own script in `flow-verify` (coming); until then, the developer runs them in a terminal.

### WS2 Direct Tests (S2S)

```bash
# AC 1 — Happy path: Get all buckets
curl -s -X GET http://localhost:<WS2_PORT>/api/incentives/v1/ageing-deduction-configs/options \
  -H "x-client-id: <CLIENT_ID>" \
  -H "x-client-secret: <CLIENT_SECRET>" \
  -H "X-Partner-Id: e3d8f926-a1bf-4890-9524-cc2d610152f9" \
  | jq .

# Expected: 200 { status: "success", data: { buckets: [5 items, ordered by overdue_days ASC] } }

# AC 7 — Missing X-Partner-Id header
curl -s -X GET http://localhost:<WS2_PORT>/api/incentives/v1/ageing-deduction-configs/options \
  -H "x-client-id: <CLIENT_ID>" \
  -H "x-client-secret: <CLIENT_SECRET>" \
  | jq .

# Expected: 400 { status: "error", error_code: "PARTNER_ID_MISSING" }

# AC 8 — Malformed X-Partner-Id
curl -s -X GET http://localhost:<WS2_PORT>/api/incentives/v1/ageing-deduction-configs/options \
  -H "x-client-id: <CLIENT_ID>" \
  -H "x-client-secret: <CLIENT_SECRET>" \
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
  -H "x-client-id: <CLIENT_ID>" \
  -H "x-client-secret: <CLIENT_SECRET>" \
  -H "X-Partner-Id: f4444444-4444-4444-8444-444444444444" \
  | jq .

# Expected: 200 — same 5 buckets as above
```

### WS1 Tests (via session)

```bash
# AC 1 — Happy path through WS1 (requires valid session)
curl -s -X GET http://localhost:<WS1_PORT>/api/incentives/v1/ageing-deduction-configs/options \
  -H "Authorization: Bearer <VALID_TOKEN>" \
  -H "X-Secure-Transmission-Type: x" \
  -H "Content-Type: application/json" \
  --cookie "connect.sid=<SESSION_COOKIE>" \
  | jq .

# Expected: 200 { status: "success", data: { buckets: [...] } }

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

**MR description** (`flow-push` sets it through the GitLab API, [D32](../docs/design-decisions.md#d32)):
- Reference the JIRA ticket (e.g., SCRUM-517)
- List all new/edited files grouped by layer (migration, model, service, controller, route, tests)
- Map which ACs each MR covers
- Note any error code differences from the JIRA ticket (e.g., middleware uses different codes than originally specified)

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
- [ ] WS1 schema created
- [ ] WS1 route created and registered (`validateSchema` first, then `isAuthenticated`)
- [ ] All index files verified
- [ ] WS2 controller unit test written
- [ ] WS2 service unit test written
- [ ] WS2 API integration test written
- [ ] Tests pass (the repo's commands, on its Node version)
- [ ] Coverage gate passes (`npm run coverage:check`)
- [ ] Migrations and seeders run only after the user's yes
- [ ] Curl verification — WS2 happy path (200)
- [ ] Curl verification — WS2 error cases (400, 401)
- [ ] Curl verification — WS1 through BFF (200)
- [ ] Curl verification — WS1 no session (401)
- [ ] MR descriptions added (JIRA ref, file list, ACs covered)
- [ ] JIRA error reference matches actual middleware codes
- [ ] MR reviewed on GitLab

---

## Setup

- **Jira:** your AI tool reads cards through Claude's Atlassian connector (Claude Code) or the Atlassian app (Codex); see the [setup guide, section 3](../docs/setup-guide.md).
- **GitLab:** closio-agent creates the MRs with git push options in the one push and sets their description through the GitLab API with your token from the Keychain ([D31](../docs/design-decisions.md#d31), [D32](../docs/design-decisions.md#d32)). Nothing else to set up here.
