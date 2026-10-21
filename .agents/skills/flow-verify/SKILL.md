---
name: flow-verify
description: "Checks a developed Jira card in one of two ways you pick: A, a full check (test cases saved for every acceptance criterion, run with the repo tests and a story check), or B, a quick check (every acceptance criterion checked directly against the running code, nothing saved but the record of the run). Then it moves the card to the push or tells you what's wrong. Runs only when the user types /flow-verify (Claude Code) or $flow-verify (Codex)."
argument-hint: '<CARD-KEY> [full|quick] [<QMetry export.xlsx>]'
disable-model-invocation: true
---

# flow-verify

Checks one card that's been developed and reviewed (C4; Phases 5 and 6 of [architecture.md](../../../docs/architecture.md); D18, D19, D65, D67, D68). It runs the card's repos on this Mac and checks every AC in one of two ways the user picks:

- **A — Full check:** the `flow-ac-checker` agent writes every AC's test cases and saves them in the run folder (backend: API checks; web: Playwright tests; a QMetry export is the base when given), then the cases run, the repo tests run again and the `flow-story-check` agent checks the build against the story.
- **B — Quick check:** every AC is checked directly against the running code: the statuses, error codes, messages and response structure it returns (backend: API calls, and the database read after a call that writes; web: one-off Playwright tests). No test cases are saved, no QMetry, no story check; the repo tests run again.

Every run is recorded in `runs/<CARD-KEY>/verify.md`: what was tested and the results, one section per run, never overwritten. Everything passes: the card moves to the push phase. Something fails: it tells the user what's wrong and what it suggests, and **the user decides** what to do next. Nothing in Jira changes.

## Usage

- `/flow-verify SCRUM-567`: check the card SCRUM-567 (developed and reviewed), or check it again; it asks which way: A full check or B quick check.
- `/flow-verify SCRUM-567 full`: A, the full check, without the question: test cases written and saved for every AC, run with the repo tests and the story check.
- `/flow-verify SCRUM-567 quick`: B, the quick check, without the question: every AC checked directly against the running code; nothing saved but the record of the run.
- `/flow-verify SCRUM-567 full <export.xlsx>`: the full check with the card's QMetry test cases (optional; one or more exports) as the base; at the end, how many of them were covered.
- Codex: `$flow-verify SCRUM-567 …` (approve the scripts outside the sandbox: servers, the API calls, Playwright, the database).

## Before every step: rules and user memory (rules A17, A7, A8; D62)

Do this before **each** numbered step below, not only at the start:

1. Re-read `AGENTS.md` and `docs/agent-rules.md`. Note the rules the step touches (e.g. `A6`, `A16`, `A23`).
2. Run `bash scripts/memory.sh for ac-check <repos>` (for steps 7 to 10: `bash scripts/memory.sh for testing <repos>`), with the card's repos (`all` before you know them). Read the **user-created memory** entries it prints and apply them. Team rules always win (A8): on a conflict, say so and follow the team rule.
3. After the step, write it in the card's history: `bash scripts/run.sh log <KEY> "verify <n>" "<what happened>" "rules: A6, A16 · memory: M2"` (use `—` when nothing applied). Skip nothing.
4. **Ask and decide the grilling way (rule A26, D76; `rulesets/grilling.md`):** every question this command asks you, and every prompt you give during it that changes the card's plan, code, tests, data, Jira or GitLab: look up the facts first and show them as "Found" lines (never ask what the code or the files answer); ask only the real decisions, in numbered rounds, each with a recommended answer that "yes" accepts; follow-up rounds until nothing is open; sum up what was agreed and wait for the confirmation before changing anything; record them as item 5 says, with a one-line pointer in `verify.md`, in this run's section (`### Decided while grilling`). Short answers, approvals and the user's questions go straight through. The safety stops below stay their own plain yes/no.
5. **Every decision is recorded (rule A27, D77):** the moment a decision is confirmed (an answer to a question, an approval or a refusal at a stop, a memory entry that answered for the user, a change the user asked for), run `bash scripts/run.sh decide <KEY> "<step and its number>" "<question>" "<decided>" "<who / why>"` (who: `you`, `you: recommended`, `memory M2`); it prints the decision's number. Where this step keeps notes, write only a one-line pointer, e.g. `- Error code for a bad status: VALIDATION_ERROR (decision 3)`.

The first memory step runs here automatically:

!`bash scripts/memory.sh for ac-check all`

**If the block above still shows the command instead of its output** (e.g. in Codex), run `bash scripts/memory.sh for ac-check all` yourself first.

## Steps

**1. Start and the choice.** Run `bash scripts/run.sh check-folder`; if it fails, show the fix and stop. Read what's typed after the command (in Claude Code it may also appear as `ARGUMENTS: …`): the card key, then optionally the word `full` or `quick`, then optionally QMetry exports (`.xlsx` paths). If the key isn't like `SCRUM-567`, show the usage and stop. `bash scripts/run.sh state <KEY>`:
   - No run folder, or `phase: pick-up` / `plan` / `develop`: say which command comes first (`/flow-start <KEY>` or `/flow-develop <KEY>`) and stop.
   - `phase: ship` or later: say the card is already verified and what to type next (its `next:` line), and stop.
   - `phase: verify`: go on (a card checked before is checked again from step 2).
   Then `bash scripts/run.sh branch <KEY>` (brings the run folder onto this Mac; this folder stays on `main`) and connect the VPN with the `flow-connectivity` agent (rule A5): the dev services need it. If either fails, show its fix and stop.
   **The choice.** `full` typed = A, `quick` typed = B. Neither: if the user's memory answers it (an entry such as "Always use the quick check in flow-verify"), use that and say so in one line ("Using your memory M3: B quick check"); the user can still say otherwise (D74). Else ask, and wait for the answer:
   > How do you want to verify <KEY>?
   > **A — Full check:** writes and saves test cases for every AC (QMetry if you gave an export), runs them, the repo tests and the story check.
   > **B — Quick check:** checks every AC directly against the running code: the statuses, error codes, messages and response structure the code returns. Nothing is saved except the record of this run.

   With B, QMetry exports typed after the key aren't used: say so (B reports no percentage). Log the step with the way chosen ("A full check" or "B quick check"); `set <KEY> step 2`.

**2. Read.** `runs/<KEY>/card.md` (the ACs and "How QA can test this"), `plan.md`, `develop.md`, an earlier `verify.md` if there is one, and the repos from `state.md`. The card is a **web card** when its repos include the web app (`WEB_REPO` in `config/project-settings.sh`), a **backend card** otherwise (both kinds when it has both).
   - **A, QMetry (optional; never ask the user for it):** save each export typed after the key with `bash scripts/qmetry-import.sh <KEY> <file>` (❌ = show the fix and stop; ⚠️ the export doesn't mention the card = show the warning and ask whether it's the right file before going on). The card **has QMetry cases** when `runs/<KEY>/qmetry/` holds an export, given now or in an earlier run: they're the base for its test cases. **No export:** don't ask for one; the test cases are written from the card and the code, and they're the base. Say which of the two it is.
   - **B:** also read the code the card changed in each repo (`git -C <repo folder> diff <base branch>...HEAD` and `git -C <repo folder> diff`; the folder is `local_path` in `local/repos/<repo>.yaml`): routes, controllers, services, schemas, error codes and messages, response shapes, and the web app's views.
   Log the step; `set <KEY> step 3`.

**3. Start the servers.** For each of the card's repos, WS2 first, then WS1, then the web app: `bash scripts/repo-run.sh <repo> start` (its `dev_command`, on its Node version; waits until its health URL answers). For a web card, the Playwright setup must be there: `bash scripts/e2e.sh check` (⚠️ = say "run `/flow-configure-user playwright` first" and stop). ❌ = show the fix and stop (then `bash scripts/repo-run.sh all stop`). Log the step; `set <KEY> step 4`.

**4. What will be checked.**
   - **Web cards, the APIs first (D69; before any test is written, in A and B, on every run).**
     1. Find every API the card's screens call: the views the card changed, then the `src/api/` functions they call; for each, its method, its path and the name of the variable its base comes from (e.g. `VITE_INCENTIVE_BASE_URL`, read from the code, never its value; rule A6). Write them to `api-list.json` (A: `runs/<KEY>/e2e/api-list.json`; B: `local/quick-checks/<KEY>/api-list.json`): `{ "apis": [ { "name": "config-detail", "method": "GET", "base": "VITE_INCENTIVE_BASE_URL", "path": "/ageing-deduction-configs/<a made-up UUID>", "used_by": "OverdueDateConfigDetail.vue" } ] }` (short lowercase names; a path that needs an id gets a made-up UUID: the check only asks whether the route answers). On a later run, reuse the file and add any new API.
     2. **Ask the user once, listing every API (name, method, path): "Which of these APIs are available on the dev environment right now?"** Wait for the answer. Ask on every run, also for the APIs mocked last time.
     3. Each API the user says isn't available is **mocked in this run**. Its mock needs the exact 200 response: if `api-mocks.ts` (A: `runs/<KEY>/e2e/api-mocks.ts`; B: `local/quick-checks/<KEY>/api-mocks.ts`) has none for it yet and the card's `## API request and response` has this API's Response (200), show it and ask whether to use it; otherwise **ask the user to send the exact 200 response object** (never assume or make one up; rule A28) and write it there: `import type { ApiMock } from '../../../e2e/fixtures';` then `export const apiMocks: Record<string, ApiMock> = { 'config-detail': { method: 'GET', path: /\/ageing-deduction-configs\/[0-9a-f-]{36}$/, status: 200, body: <the user's object> } };`. Error answers come from the web app's code, as before. Keep the names mocked in this run (`<mocked>`).
   - **A, the test cases (written by default).** Use the **`flow-ac-checker` agent** to write the test cases of every AC that has none yet (existing ones are kept: they may have been changed with `/flow-ac-check`): backend cards `runs/<KEY>/api-checks/ac-<n>.json`, web cards `runs/<KEY>/e2e/ac-<n>.spec.ts`. Tell it the key, the kind of card, and either **"QMetry cases in runs/<KEY>/qmetry/ are the base: every QMetry case not in a case file yet, and the cases of every AC that has none"** or **"no QMetry cases: your own cases for every AC that has none"**; for a web card also the API list, `api-mocks.ts` and the names mocked in this run. Show the user one line per case under its AC.
   - **B, the scenarios (nothing saved).** Work them out yourself, AC by AC, from the card, the plan, `develop.md` and the code changes: each AC's positive path and every error the code returns for it, with its exact status, `error_code` and message from the code (rule A16); a call through WS1 gets WS1's status and message (WS1's `src/middlewares/errorHandler.js`: a WS2 404 reaches the caller as 597, same `error_code`); the response structure from the card's `## API request and response` (rule A28; the WS1 schema's `responses`, rule A22, must match it; an API the card has no structure for: ask the user); for the web app, what the AC says the user sees. Show one line per scenario under its AC, then go on (no wait here). For a web card, write the web scenarios as **one-off Playwright tests** in `local/quick-checks/<KEY>/ac-<n>.spec.ts` (on this Mac only, git-ignored; removed in step 9), the same way the `flow-ac-checker` agent writes them: `import { test, expect } from '../../../e2e/fixtures';`, each test titled `AC <n> — …` and started with `async ({ loggedIn: page })`; an answer the dev side can't give on demand (a 500, more than 5 items, a fixed order) comes from the test itself with `page.route`, shaped as the card's response structure for that API (rule A28; none in the card: ask the user, never shape it from the code), and the title ends with ` (answer from the test)`. Each test calls `await useApiMocks(page, apiMocks)` (from the fixtures and `./api-mocks`) before the screen opens, and checks the screen against whatever the API answered (caught with `page.waitForResponse`), so it works with the real API and with the mock.
   Log the step; `set <KEY> step 5`.

**5. Test data and calls that write (rule A23: the user sees them first).**
   - **What needs a yes:** rows the checks need in the database (the card's QA setup SQL is the starting point), and every call that writes (`POST`, `PUT`, `PATCH`, `DELETE`): they change the database the WS2 repo's `.env` names. A: `runs/<KEY>/test-data.sql` and `runs/<KEY>/test-data-cleanup.sql` from the agent, and the cases whose `method` writes. B: write the SQL to `local/quick-checks/<KEY>/test-data.sql` and `local/quick-checks/<KEY>/test-data-cleanup.sql` yourself, and list your write calls. Either way the cleanup removes the test data **and** the rows the write calls create (fixed, recognizable values in their bodies make them easy to find).
   - Show **both** SQL files with `bash scripts/db-run.sh <repo> show <file>` (`<repo>`: the WS2 repo that owns the tables) and list every call that writes (method, path, what it creates or changes), and ask for a **clear yes**. Nothing is added and no write call is sent before that.
   - On yes: `bash scripts/db-run.sh <repo> run <test-data file> confirmed` (when there's test data) and show its output. On no: say which ACs or scenarios can't be checked without them (they're left out and recorded as not checked) and ask whether to go on or stop.
   Nothing that writes and no test data needed: say so. Log the step; `set <KEY> step 6`.

**6. The AC checks (Phase 5).**
   - **A:** backend `bash scripts/api-check.sh <KEY>`; web `bash scripts/e2e.sh run <KEY>`.
   - **Web cards, the API check before the run (D69):** `bash scripts/e2e.sh probe <KEY>` (B: add `--quick`; add `--mock <mocked>` when something is mocked): it logs in once and calls each GET API that isn't mocked. For every API it flags (⚠️ no answer, a 502/503/504, WS1 can't reach the service behind it, or WS1 doesn't know the route), ask the user whether it's available on dev: not available → mock it as in step 4 (the 200 object asked for if `api-mocks.ts` has none) and add it to `<mocked>`; available → go on (a failure will show it). Then run the web tests with `--mock <mocked>` added when something is mocked.
   - **B, backend:** each scenario with `bash scripts/api-call.sh <repo> <METHOD> <path>` (with `--json`, `--auth`, `--client` as the scenario needs; the script adds the keys and the WS1 login). Compare what comes back with the AC and the code: the status, `error_code`, message, and the response structure (every field, its type and nesting). **After a call that writes, read the database to check what it wrote:** a `SELECT` in `local/quick-checks/<KEY>/check-<n>.sql`, run with `bash scripts/db-run.sh <repo> query local/quick-checks/<KEY>/check-<n>.sql` (a read-only transaction: the database refuses any change, so no yes is needed). **B, web:** `bash scripts/e2e.sh quick <KEY>`.
   - **The API structures (A and B; rule A28, D84).** For every API in the card's `## API request and response`, check that the real response has the card's structure:
     - **Backend cards:** one success call per API, with the body of that API's success case (A: its case in `runs/<KEY>/api-checks/`; B: your positive scenario; never a body you make up): `bash scripts/api-call.sh <repo> <METHOD> <path> [--json …] --save <file>` (`<file>`: A `runs/<KEY>/api-shapes/<n>.txt`, B `local/quick-checks/<KEY>/api-shapes/<n>.txt`). A call that writes must have been in step 5's list.
     - **Web cards:** only the GET APIs in the card's section that are available on dev (not in `<mocked>`): `bash scripts/api-call.sh <WS1 repo> GET <path> --env dev --save <file>`. Calls that write are left to their backend card.
     - Then `bash scripts/response-shape.sh runs/<KEY>/card.md "<METHOD> <path>" <file>` and show its output. ✅ = the same structure; ❌ = each missing, extra or wrongly typed field. Exit 2 (the card's structure is missing or isn't valid JSON) = ask the user for it; never write or fix one.
   **Web cards, after the run:** when `e2e.sh` lists "API calls that failed on dev" under failing tests, ask the user about each of those APIs: not available → mock it (as in step 4) and run those ACs again (`bash scripts/e2e.sh run <KEY> <AC> --mock <mocked>`, B: `quick`); available → it stays a failure, with a suggestion (e.g. check that WS1 and the WS2 behind it are up on dev).
   Show the results (✅ / ❌ per case or scenario, and per AC). Write them in this run's `### AC checks` in `verify.md` (see step 10), and the structure checks under `### API structures` (one line per API: ✅, or ❌ with each difference): every case or scenario tested, one line each (the call or what was checked, and ✅ / ❌), and each failure with what was expected and what came back. Log the step; `set <KEY> step 7`.

**7. The repo tests again (Phase 6, A and B).** For each repo: `bash scripts/repo-run.sh <repo> test` and `bash scripts/repo-run.sh <repo> check` (lint only warns, D65). Write the results under `### Repo tests and checks`. Log the step; `set <KEY> step 8`.

**8. The story check (Phase 6, A only).** A: use the **`flow-story-check` agent** with the key and the repos, and write its findings under `### Story check`. B: skipped; write "skipped (quick check)". Log the step; `set <KEY> step 9`.

**9. Clean up.** If test data was added or write calls were sent: show the cleanup SQL again (`bash scripts/db-run.sh <repo> show <cleanup file>`) and ask for a **clear yes** before removing anything; on yes run it (`… run <cleanup file> confirmed`); on no, say the rows stay and how to remove them later. Then `bash scripts/repo-run.sh all stop` and, if WS1 was called, `bash scripts/api-call.sh <WS1 repo> logout`. B: `bash scripts/run.sh quick-clean <KEY>` (removes `local/quick-checks/<KEY>/`). Write `### Test data` (added, write calls sent, cleaned up, or none). Log the step; `set <KEY> step 10`.

**10. The result.** Write this run's `### Result` in `verify.md` and save. **Only for A, when the card has QMetry cases:** run `bash scripts/qmetry-import.sh coverage <KEY>` and put its one line (`QMetry: <n> of <total> test cases covered (<percent>%)`) at the top of `### Result` and in your last message, before the `Done` or failure lines. Nothing more about QMetry: no table, no list. B, or A without QMetry cases: no QMetry line.
   `verify.md` keeps **every run, newest first**: a new run's section goes at the top (`<n>` = the number of `## Run` sections already there + 1); earlier runs stay as they are, never overwritten (an older `verify.md` without run sections stays below the new section as it is). Its shape:
```
# <KEY> — verification
## Run <n> — <date and time> · A full check | B quick check
Repos: … · Ruleset: <the ruleset file of each repo> · Memory applied: … or none
### APIs (web cards: each API real or mocked, with the user's answer and the check before the run)
### AC checks
### API structures
### Repo tests and checks
### Story check
### Test data
### Result
```
   - **Everything passed** (every AC ✅, every API structure ✅, tests and checks ✅, A: no ❌ in the story check): `bash scripts/run.sh set <KEY> phase ship`, `set <KEY> step 1`, `set <KEY> next "/flow-push <KEY>"`, log "verified (A full check | B quick check)", `bash scripts/run.sh save <KEY> "verified"`. End with: `Done: <KEY> is verified. Next: /flow-push <KEY> (Codex: $flow-push <KEY>).`
   - **Something failed:** the card stays in the verify phase (`set <KEY> step 1`, `set <KEY> next "/flow-verify <KEY>"`). Under `### Result`, and in chat, list **each failure with what's wrong and what you suggest**: a code problem → `/flow-develop <KEY>` (it offers to go back and fix the list in `verify.md`); A, a test case that's wrong → `/flow-ac-check <KEY> <AC> "<what to change>"`; B, a scenario checked the wrong way → the user says what to check instead, then `/flow-verify <KEY> quick` again; missing data or a setup problem → the exact fix (rule A11); an API structure that differs from the card → the user decides: fix the code (`/flow-develop <KEY>`) or confirm the card's structure (recorded as a decision, rule A27). **Don't start any of them: the user decides how to go on.** Log "verify: N failure(s), waiting for the user", `bash scripts/run.sh save <KEY> "verify: N failure(s)"`.

## Before a long step, say how long (D74)

Before you start each step below, say its line in one sentence, so the user knows what's happening and roughly for how long. The times come from real runs; "several minutes" where none was timed yet. Plain words (rule A25).

- Step 3: "⏳ Starting <repos> on this Mac: about a minute."
- Step 4, A: "⏳ Writing the test cases: this can take a while, about 12 minutes for 26 cases on a web card."
- Step 6, A: "⏳ Running the test cases: several minutes." B: "⏳ Checking every scenario: about a minute for 22 scenarios."
- Step 7: "⏳ Running the repo tests again: about a minute for nodejs-ws2targetsalesincentive; several minutes for a repo not timed yet."
- Step 8, A: "⏳ The story check (comparing the code with the card): several minutes."

## Rules
- Every step writes its history line with the rules and memory applied (A1, A17).
- The user picks the way: A full check or B quick check (`full` / `quick` after the key skips the question). B saves no test cases: its scenarios, one-off web tests, test data and queries live in `local/quick-checks/<KEY>/` (this Mac only) and are removed at the end; only the record of the run goes into `verify.md` (D68).
- Every run is recorded in `verify.md`, newest first, never overwritten: what was tested and the results (D68).
- Web cards: before any test is written, the APIs the screens call are listed and the user says which are available on dev, on every run; an unavailable one is mocked with the exact 200 response the user sends (never made up); a GET check runs before the tests, and failed API calls in failing tests are asked about too (D69).
- QMetry (A only) is optional and never asked for: the exports the user types after the key (or saved in an earlier run) are the base for the test cases, and the result has one coverage line; without them the test cases come from the card and the code, and there's no QMetry line (D67). With B, typed exports aren't used, and it says so.
- Request and response structures come only from the card's `## API request and response` or the user (A28): mocks, scenarios, `page.route` answers and the structure check never use a shape written or derived by the AI. Every API in the card's section gets its structure checked with `response-shape.sh` (D84).
- Test data, calls that write and the cleanup are shown to the user and run only after a clear yes, each time (A23). The database is the one the repo's `.env` names. Reading it with `db-run.sh … query` (a read-only transaction) needs no yes.
- Keys, passwords and sessions are added by the scripts and never shown or written to a file (A6). Never read `.env` values.
- Nothing is committed in the repos (G3) and nothing changes in Jira. The servers are stopped at the end, also when a step fails.
- Run the scripts exactly as written here (`bash scripts/…` from the closio-agent folder, no `cd`, nothing joined with `&&`). They're pre-approved in Claude Code and Codex (D57).
