# Architecture — Pipeline Flow

> Status: the phase structure was approved on 2026-10-09 and updated the same day with the developer-testing phase ([D18](design-decisions.md#d18)). Built so far (foundation, Phase 0): `flow-ping`, `flow-doctor`, `flow-vpn`, `flow-configure-user`, `flow-configure-repo`, `flow-setup-repo`, `flow-memory`, `flow-check-card`, `flow-help`, the `flow-connectivity` agent ([commands.md](commands.md)), the Jira card template ([jira-card-template.md](jira-card-template.md)) and the step-by-step guide ([user-guide.md](user-guide.md)). **Of the card phases: `flow-status`, `flow-start` (Phases 1 and 2, built 2026-10-17, C1 + C2) `flow-develop` (Phases 3 and 4, built 2026-10-17, C3) `flow-verify` + `flow-ac-check` (Phases 5 and 6, built 2026-10-18, C4) `flow-push` (Phases 7 and 8, built 2026-10-18, C5) and `flow-finish` (Phase 9, built 2026-10-18, C6): every card phase has its command.** The card phases' commands and the order of building are decided in [D61](design-decisions.md#d61) (2026-10-17): `flow-start` (Phases 1–2, **built**), `flow-develop` (3–4, **built**), `flow-verify` (5–6, **built**), `flow-push` (7–8, **built**), `flow-finish` (9, **built**), plus `flow-status` (**built**). Every command starts with **`flow-`** ([D43](design-decisions.md#d43)). In Claude Code a command is typed as `/flow-…`; in Codex as `$flow-…` ([D16](design-decisions.md#d16)). Commands only run when the user types them ([D44](design-decisions.md#d44)).

## Overview

```
Phase 0  Setup (one-time)        flow-ping · flow-doctor · flow-configure-user · flow-configure-repo · flow-setup-repo · flow-memory · flow-check-card · flow-help · Jira card template · user guide
Phase 1  Pick up the card        flow-start <CARD-KEY>            (C2, built 2026-10-17)
Phase 2  Understand & plan       part of flow-start · ✋ user approves the plan
Phase 3  Develop                 flow-develop <CARD-KEY>          (C3, built 2026-10-17) agent + user together: code + unit tests; also from plain words once the plan is approved
Phase 4  Human review            part of flow-develop · ✋
Phase 5  Check against ACs       flow-verify <CARD-KEY>           (C4, built 2026-10-18) every AC's test cases; flow-ac-check <CARD-KEY> <AC> edits one AC's
Phase 6  Developer testing       part of flow-verify · the repo tests again + the story check; a failure: the user decides (e.g. back to Phase 3)
Phase 7  Ship                    flow-push <CARD-KEY>             (C5, built 2026-10-18) rebase (every AC again when new code came in, D83), the commits you approve, one push (also creates, assigns and describes the MRs)
Phase 8  Merge Request           part of flow-push · MRs linked on Jira → card to Code Review · then flow-review <CARD-KEY> (D78) for a self-review and the reviewers' comments
Phase 9  After merge             flow-finish <CARD-KEY>           (C6, built 2026-10-18) merged? → you say it's deployed → every AC on dev → deployment doc (run folder + Jira card) → Ready for Test
QA       QA's questions          flow-qa <CARD-KEY>               (D81, built 2026-10-19) QA's Jira comments checked against the card and dev → a reply; a real bug → a Bug card
Any time flow-status [<CARD-KEY>]  (C1, built 2026-10-17) where a card stands; the run folder runs/<CARD-KEY>/ remembers it
```

✋ = the agent stops and waits for a person.

## Jira

- Project: **Closio**, key **`SCRUM`**.
- Status flow used by the agent: **To Do → In Development → Code Review → Ready for Test**.
- The agent never uses **Blocked** (QA only), **Testing**, **QA - Passed** or **Production**.
- "Backlog" is a tab in the project, not a status. Cards in it have the status To Do.

## Tech stack (repos the agent works on)

- **BE:** Node.js, PostgreSQL, Redis, RabbitMQ, BullMQ.
- **FE:** Vue.js.

Repos in scope ([D23](design-decisions.md#d23)). Each is registered with `flow-configure-repo` ([D35](design-decisions.md#d35)), and new repos are added the same way. Out of scope for now: `sfa-service-gitlab`, `sfa-dashboard-web`, `qa-testcraft`.

| Repo (GitLab path) | Type | Tests today |
|---|---|---|
| `nodejs-ws1closio` (`closio/backend/…`) | BE (BFF; uses the session cookie) | **No test suite**, so no committed tests ([D25](design-decisions.md#d25)) |
| `nodejs-ws2closio` (`closio/backend/…`) | BE | mocha + chai + sinon + supertest; nyc coverage gate 80% statements / 70% branches / 80% functions / 80% lines |
| `nodejs-ws2notification` (`closio/backend/…`) | BE (RabbitMQ via amqplib) | Same as above; husky hooks run the coverage check on commit and push |
| `nodejs-ws2pricingengine` (`pricing-engine/backend/…`) | BE | Same as above, with husky hooks |
| `nodejs-ws2targetsalesincentive` (`target-sales/backend/…`) | BE (BullMQ + ioredis) | Same as above, with husky hooks |
| `ws2jauth` (`genesis-framework/backend-node/…`) | BE | **No test suite**, so no committed tests ([D25](design-decisions.md#d25)) |
| `closio-web-v2` (`closio/frontend-web/…`) | FE (Vue 3 + Vite) | Vitest + @vue/test-utils (about 200 test files); threshold 70% configured; Playwright lives **outside the repo** in closio-agent's workspace ([D24](design-decisions.md#d24)) |

## Phases

### Phase 0 — Setup (one-time)
- **Strict rule for every setup command ([D42](design-decisions.md#d42)):** tell the user that sessions always start in the closio-agent folder, and check that this session did.
- **VPN** (built, [commands.md](commands.md#flow-vpn)): `flow-vpn connect | status | disconnect`.
- **Install checks** (built, [commands.md](commands.md)): `flow-ping` (are the commands loaded in this tool?) and `flow-doctor` (is the setup right? project, tools, VPN and GitLab, Keychain names, Jira; later pieces add their own checks).
- **Per user** (`flow-configure-user`, built in F4, [D15](design-decisions.md#d15), [commands.md](commands.md#flow-configure-user)):
  - in `local/user-settings.sh` (private): Jira account ID (fetched by the AI), GitLab username, workspace folder, the AI tool(s) used, and an **optional** VPN username (not needed today; gateway and port are shared settings)
  - git name and email (global git settings)
  - in the macOS Keychain, through a heads-up message and a hidden input box: the GitLab personal access token (`api` scope, one token for everything, [D32](design-decisions.md#d32), [D48](design-decisions.md#d48)) and the test credentials (FE login, WS1 login, which are different; [D20](design-decisions.md#d20), [D33](design-decisions.md#d33), [D34](design-decisions.md#d34))
  - the per-repo dev WS2 keys come with `flow-configure-repo` ([D37](design-decisions.md#d37))
- **Per repository** (`flow-configure-repo`, built in F5, [D35](design-decisions.md#d35), [D51](design-decisions.md#d51), [commands.md](commands.md#flow-configure-repo)): the **only way to add a repo**. Shared facts in `config/repos/<repo>.yaml` (committed): GitLab address and path, FE/BE and role, base branch (can differ per repo), install/run/check/test commands, port and health URL, test format and coverage rules, migrations and seeders (existing Sequelize pattern), queues, local services (Redis, RabbitMQ, BullMQ), the repos it calls, the `.env` file name, dev keys, language (node, go or other), Node version (from its Dockerfile), MR target branch, optional default MR labels and reviewers (finalised at MR creation). Detected values are only suggestions; the user confirms. Personal facts in `local/repos/<repo>.yaml`: where the clone is. Dev keys in the Keychain.
- **Repository code setup** (`flow-setup-repo`, built in F6, [D54](design-decisions.md#d54), [commands.md](commands.md#flow-setup-repo)): **on a clone the user already made** (cloning is manual, [D53](design-decisions.md#d53)), switches to the repo's own Node version (installing it with nvm if needed, [D52](design-decisions.md#d52)), installs dependencies when needed, finds or starts the local Redis and RabbitMQ (Homebrew or Docker; checks both, asks once if both are there and stops the other), says whether the repo's `.env` points to them, runs the tests once and gives Claude Code and Codex access to the repo folder. It needs no VPN.
- **Help and the guide** (built in F8, [D60](design-decisions.md#d60)): `flow-help` shows every command from the commands' own `## Usage` blocks; [user-guide.md](user-guide.md) walks through everything step by step and is mirrored into a Claude artifact. Rule R17: every new command is added to both, checked by `flow-doctor`.
- **Jira card template** ([D58](design-decisions.md#d58), built in F7 on 2026-10-17): the structure card writers follow, kept in `docs/jira-card-template.md`, with three full example cards in `docs/jira-card-examples.md` (two backend, one web; [D82](design-decisions.md#d82)). closio-agent never creates cards (people, and the card-writing pipeline in the sibling folder `Ticket creation pipeline`, do); it checks each picked-up card against the template in Phase 1 with `scripts/card-check.sh` (❌ not ready, ⚠️ worth a look), and anyone can test a card before that with `flow-check-card <CARD-KEY>`. Required sections: Context, How QA can test this, Acceptance Criteria (every AC in Given / When / Then).

### Phase 1 — Pick up the card (`flow-start <CARD-KEY>`, built in C2)
`flow-start` does Phases 1 and 2 and ends at the plan approval ([D61](design-decisions.md#d61); the step-by-step is in [commands.md](commands.md#flow-start)). Before the plan, it re-reads the user's memory entries for the `plan` phase and the repos involved, and lists the ones it applied in `plan.md` (rule A7).
1. Fetch the card. If its status isn't **To Do**, or it's assigned to someone else, say so and ask whether to go on.
2. Check the card against the template ([D58](design-decisions.md#d58)): Spikes aren't picked up; Subtasks and Bugs are. On ❌ gaps the agent lists them and waits for the dev to fix the card or explain the gap in chat (saved with the card), then goes on.
3. If the card is in the backlog, move it into the active sprint ([D13](design-decisions.md#d13)).
4. Move the card to **In Development** and assign it to the user running the command.
5. Work out which repos are needed from the card's Scope section, and ask the user to confirm.
6. Pull the latest base branch and create a branch in each repo, named by the strict rule `SCRUM-<number>/<short-description>` (at most 5 words, same name in every repo; rule A12, [D50](design-decisions.md#d50)).
7. Create the card's run folder `runs/<CARD-KEY>/` ([D61](design-decisions.md#d61)): `state.md`, `history.md`, `card.md`, `decisions.md` (every decision in full, [D77](design-decisions.md#d77)), later `plan.md`, `develop.md`, `verify.md`, `ship.md`, `deployment.md` (`scripts/run.sh`). Every command saves its run-folder changes at the end of its phase to the card's branch of closio-agent, `runs/<CARD-KEY>`, and pushes them, never on `main`. The closio-agent folder itself never switches to that branch: it stays on `main` with the current commands and scripts, and only the `runs/<CARD-KEY>/` folder is committed to the branch (a temporary git index; run folders are git-ignored on `main`). A teammate's pushed run folder is brought onto their Mac by `run.sh branch`.

### Phase 2 — Understand & plan
1. Rules and memory first (rule A17), before this and every later step.
2. **The code first** (rule A18, [D63](design-decisions.md#d63)): pull the base branches, bring the latest one into the card's branch (`scripts/card-branch.sh update`), and read the current code of every repo involved (routes, controllers, services, utils, constants, middlewares, migrations, locale files). A plan is never made from the card alone. A plan continued later goes back to this step first.
3. Summarise the card and list its acceptance criteria (ACs). Detect special cases: migrations, consumers/queues, setups.
4. **Every difference between the card and the code goes to the user first** (rules A16 and A18): error codes, statuses and messages that exist in the code (nothing new is invented), fields, anything the card names that isn't in the code. Ask, wait for the answers.
5. Read each repo's ruleset (rule A19, [D64](design-decisions.md#d64), [D80](design-decisions.md#d80); backend repos: `rulesets/story-implementation-workflow.md`, the web app: `rulesets/frontend-story-workflow.md`) and the user-created memory for the `plan` phase (rule A7).
6. Draft the development plan. ✋ **The user approves it in chat; strictly necessary.** Only then it's saved to the run folder and pushed on the card's branch.

### Phase 3 — Develop (`flow-develop <CARD-KEY>`)
The agent and the user develop together, following the approved plan and the ruleset (with the user's memory and the card files). `flow-develop` does Phases 3 and 4. It's the one command that also starts from plain words: when the user asks to develop a card whose plan is approved, the AI runs it for that card ([D61](design-decisions.md#d61), the exception to [D44](design-decisions.md#d44)). **Built in C3 ([D65](design-decisions.md#d65)):** repo by repo, in the plan's order, it writes the code (following the closest existing files, creating new files where needed, asking first about anything new or not in the plan, rule A16) and **the committed unit tests** (moved here from Phase 6), runs the repo's tests with the coverage gate and its checks (`scripts/repo-run.sh`, on the repo's Node version, A13) until they pass, runs migrations or seeders only after the user's yes ([D21](design-decisions.md#d21)), and shows a summary after each repo. Nothing is committed here (G3). Its notes go in `runs/<CARD-KEY>/develop.md`.

### Phase 4 — Human review ✋
Part of `flow-develop`. Per repo, the agent shows the changed files, what each plan item became and every change from the plan; the user reviews the changes in their editor. "Change X" goes back to Phase 3; "review approved" (in so many words) ends `flow-develop`, and the card moves on to `flow-verify`.

### Phase 5 — Check against ACs (`flow-verify <CARD-KEY>`, Phases 5 and 6)
Built in C4 ([D67](design-decisions.md#d67)). `flow-verify` starts the card's repos on this Mac (`scripts/repo-run.sh <repo> start`) and checks every AC in one of **two ways the user picks** ([D68](design-decisions.md#d68)): **A — Full check** (below) or **B — Quick check**: every AC checked directly against the running code (the statuses, error codes, messages and response structure it returns, through `scripts/api-call.sh`, and the database read with `scripts/db-run.sh … query` after a call that writes; web: one-off Playwright tests in `local/quick-checks/<CARD-KEY>/`, run by `scripts/e2e.sh quick`), with no saved test cases, no QMetry and no story check. Every run, either way, is recorded in `verify.md` (newest first, never overwritten), and test data or calls that write run only after the user's yes. **Web cards, the APIs first** ([D69](design-decisions.md#d69)): before any test is written, the APIs the screens call are listed (`api-list.json`) and the user says which are available on dev, every run; an unavailable one is mocked with the exact 200 response the user sends (`api-mocks.ts`, switched on per run with `e2e.sh … --mock`); `e2e.sh probe` checks the GET APIs on dev right before the run; `e2e/fixtures.ts` notes API calls that fail during a test, and those of the card's APIs are asked about after the run. In the full check, the `flow-ac-checker` agent ([D19](design-decisions.md#d19)) writes the test cases of every AC that has none, in the card's run folder: **API checks** for backend cards (`runs/<CARD-KEY>/api-checks/ac-<n>.json`: the call and what must come back; run by `scripts/api-check.sh`, through `scripts/api-call.sh`, which adds the WS1 login or the WS2 keys itself) and **Playwright tests** for web cards (`runs/<CARD-KEY>/e2e/ac-<n>.spec.ts`; run by `scripts/e2e.sh` against the web app on this Mac, logged in with the FE login; a test that needs an answer the dev data or the server can't give on demand, such as a 500 or more than 5 items, answers the screen's one API call itself with `page.route`, shaped from the code, and is named `… (answer from the test)`). QMetry is optional and never asked for: a QMetry export of the card, when the user gives one, is the base for its test cases (`scripts/qmetry-import.sh`; each case named with its QMetry key), and the result says how many of its cases were covered (`qmetry-import.sh coverage`); without one, the cases are written from the card and the code. Test data the cases need, and its cleanup, are shown to the user and run only after a clear yes (`scripts/db-run.sh`, rule A23). `flow-ac-check <CARD-KEY> <AC> ["…"]` adds or changes one AC's cases.

**API structures ([D84](design-decisions.md#d84), rule A28):** in both ways, every API in the card's `## API request and response` gets one success call (web cards: its GETs on dev), and `scripts/response-shape.sh` compares the real response with the structure the user gave in the card. Each difference is shown, and the user decides. Request and response structures always come from the card or the user, never from the AI or the code.

### Phase 6 — Developer testing ([D18](design-decisions.md#d18))
Runs **before the push**, so a failure never needs a second push (G4).

1. **Repository tests (committed to the repo):** written in Phase 3 by `flow-develop`, in the format registered for the repo ([D65](design-decisions.md#d65)); here they run again, and the repo's strict **coverage rules** must pass. Skipped for repos without a test suite ([D25](design-decisions.md#d25)).
   - **FE end-to-end:** Playwright, written and run here by `flow-verify`, kept **outside the repo in closio-agent's own workspace** and run against the locally running app; never pushed ([D24](design-decisions.md#d24)).
2. **Story verification** (full check only): the `flow-story-check` agent checks the build against the card's story (every AC and the objective built, nothing out of scope, error codes from the code, rules A20–A22).
3. Save the results in the card's run folder (`verify.md`).
4. **All passed:** the card moves to Phase 7. **A failure:** the agent tells the user what's wrong and suggests what to do (fix the code with `flow-develop`, which then offers to go back; change a test case with `flow-ac-check`; or a setup fix). **The user decides** how to go on (D67).

Local test environment ([D21](design-decisions.md#d21)):
- **PostgreSQL:** the dev database, used directly. Credentials from the repo's `.env` ([D34](design-decisions.md#d34)).
- **Redis:** local, for everything (BullMQ and any other use).
- **RabbitMQ:** local.
- None of the repos' `docker-compose.yml` files include Redis or RabbitMQ, so `flow-setup-repo` finds a local copy (Homebrew or Docker) or suggests one ([D54](design-decisions.md#d54)).

Test credentials ([D20](design-decisions.md#d20)): per person, asked once in setup, stored in the macOS Keychain under `closio-agent.<name>` ([D33](design-decisions.md#d33)), and read by scripts at run time.
- **FE:** login ID and password (different from the WS1 login).
- **BE, WS1:** session cookie, fetched from the **dev** login API with the stored login ID and password, always, also for the checks on this Mac; the cookie is then sent to the WS1 on this Mac (rule A24, [D71](design-decisions.md#d71)):
  - `POST https://dev-closio-ws1-apiprivate.japfacomfeed.co.id/api/v1/login`
  - Headers: `accept: application/json`, `X-Secure-Transmission-Type: x`, `X-Application-Version: 1.0.0+1`, `Content-Type: application/json`
  - Body: `userid` and `password` (per person), `napp_pk: 4` and `client_type: "web"` (the same for everyone)
- **BE, WS2:** the **caller's** client ID and secret (`x-client-id` / `x-client-secret` headers): WS1 sends its own pair (`WS1_AUTH_CLIENT_ID` / `WS1_AUTH_SECRET_KEY` in its `.env`, `src/utils/axiosInstances.js`) to target sales and notifications, and its `PRICING_ENGINE_*` pair to the pricing engine; the WS2 checks it against its `SERVICE_CREDENTIALS`. For the checks on this Mac, `api-call.sh` sends WS1's pair saved with `/flow-configure-repo nodejs-ws1closio key ws1-client-id` and `… ws1-client-secret` (Keychain, [D37](design-decisions.md#d37)); a pair saved under a WS2 repo (`ws2-client-*`) is used instead for that WS2 (the pricing engine).

The coverage gate that husky runs on every commit (ws2targetsalesincentive, ws2notification, ws2pricingengine) runs on each atomic commit in Phase 7: slower, never skipped ([D70](design-decisions.md#d70)).

### Phase 7 — Ship (`flow-push <CARD-KEY>`, Phases 7 and 8)
Built in C5 ([D70](design-decisions.md#d70)); the step-by-step is in [commands.md](commands.md#flow-push).
1. The connectivity agent connects the VPN if needed ([D30](design-decisions.md#d30)); the card must be verified.
2. Per repo, `scripts/card-branch.sh <repo> rebase <branch>`: stash the changes (new files too), fetch the base branch and rebase onto it, pop the stash ([D10](design-decisions.md#d10), G2).
3. ✋ If the rebase or the stash pop causes a conflict, the user resolves it in their editor, then `rebase-continue` carries on. Each repo's rebase says what came in from the base branch.
4. Re-run the repo's tests and checks.
5. When the rebase had a conflict or brought newer commits, **every AC is checked again the quick way** (as in Phase 5, B), before any commit ([D83](design-decisions.md#d83)). A failure in 4 or 5 stops the push before any commit: it's written as a failed run in `verify.md`, and `flow-develop` takes the card back to Phase 3.
6. ✋ The AI proposes the atomic commits per repo, each layer's code with its own tests, messages `SCRUM-<n>: <what this commit does>`; the user approves the list; `scripts/ship.sh <repo> commit` makes them, the repo's git hooks running every time (G3).
7. The MRs: title `SCRUM-<n>: <card title>`, ready for review, into `mr_target_branch`, assigned to the user; the repo's default **labels and reviewers** confirmed or changed by the user ([D51](design-decisions.md#d51)); the description: the Jira link and the migrations and seeders to run (nothing more, D70).
8. ✋ Everything shown; pushed only after the user's explicit yes.
9. Push once per repo, never forced (G4): `scripts/ship.sh <repo> push` **creates the MR and assigns it to the user** with git push options ([D31](design-decisions.md#d31)). Right after, `scripts/gitlab-mr.sh <repo> describe` sets the **full description and the reviewers** through the GitLab REST API, using the token from the Keychain ([D32](design-decisions.md#d32)).

### Phase 8 — Merge Request
Part of `flow-push`.
1. The MRs exist, created, assigned and described in Phase 7.
2. The Jira card shows each MR (GitLab's Jira link usually adds it); a missing one gets one comment with the links.
3. Move the card to **Code Review** ([D11](design-decisions.md#d11)). The run folder's `ship.md` keeps the commits and the MR links; the card waits for the merge (phase `after-merge`).
4. While the MRs wait for the merge: `flow-review <CARD-KEY>` ([D78](design-decisions.md#d78)): the MRs' state (approvals, conflicts, the pipeline), a self-review of the code against [`rulesets/code-review.md`](../rulesets/code-review.md) (the story level; the micro level: no redundant code, the right file for each piece, the basics; plus the tool's own reviewer), findings in chat only, at most 3 rounds per run and 2 tries per failing fix; the reviewers' new comments with drafted replies and tested fixes; after the user's yes, the fixes pushed into the same MR (`ship.sh push-update`: the one exception to "rebase before every push" and "one push", never forced) and the replies posted as the user. `flow-review <CARD-KEY> check` only lists what's new. Jira stays in Code Review; threads are never resolved by the agent.

### Phase 9 — After merge (`flow-finish <CARD-KEY>`)
Built in C6 ([D72](design-decisions.md#d72)); the step-by-step is in [commands.md](commands.md#flow-finish).
1. Check that every MR of the card is merged (`scripts/gitlab-mr.sh <repo> status`); one still open: stop.
2. The user says the card is deployed on the **dev environment** (nothing checks it by itself).
3. Test the change on dev ([D22](design-decisions.md#d22)): the quick check (B) with `--env dev`: through dev WS1 with the dev login (rule A24), directly against each WS2 with WS1's client pair ([D37](design-decisions.md#d37)), web cards on the dev web app; each repo's dev address (`dev_base_url`) is asked once by `flow-setup-repo`. Test data and calls that write only after a yes (A23); a new run in `verify.md`.
4. Create the deployment doc in the card's run folder, `deployment.md` ([D12](design-decisions.md#d12)), in plain words for two readers: for QA, what the card adds, how to try it (an API card's ready-to-run curls with placeholders for logins and keys, a web card's menu path, a consumer card's test in words) and what was checked on dev; for the person deploying, the order with each MR, the database changes and default data in words (by file name, reviewed by the user first, A23), new settings, after-deploy steps; then the user's special instructions. No code, commands or raw JSON in it, except the curls. The same doc goes on the Jira card as one comment, whose id is kept in `state.md`.
5. Move the card to **Ready for Test**. The run branch `runs/<CARD-KEY>` stays as the card's record; it isn't merged into `main` (D72).

### After Ready for Test — QA's questions (`flow-qa <CARD-KEY>`)
Built 2026-10-19 ([D81](design-decisions.md#d81)); the step-by-step is in [commands.md](commands.md#flow-qa).
1. Read QA's new comments on the Jira card (everyone's except the user's own) since the last round.
2. For each one, the facts first: the AC it's about, the card's `decisions.md`, the deployment doc, the merged code, and that exact scenario checked on dev the quick way.
3. Sort it: works as the card says (a drafted answer with the evidence); a real bug (a separate Bug card, drafted, created after the user's yes, then worked with `flow-start`); something the card never asked for (a reply and a new card draft); unclear (a question back).
4. Jira: the story moves only Blocked → In Development (a Bug card approved) and In Development → Ready for Test once its Bug cards are done (from `flow-qa`, or `flow-finish` on the last Bug card), each after the user's yes; never to Blocked.
5. One reply comment per round, posted as the user after their yes; the round is kept in `runs/<CARD-KEY>/qa.md`.

## Applies across all phases

- **The card rules at every prompt (rule A29, [D86](design-decisions.md#d86)):** a prompt hook adds [`rulesets/card-rules.md`](../rulesets/card-rules.md) to every card command, every prompt that names a card key and every later prompt in that session, in Claude Code and Codex; its first rule is that every decision is recorded in the card's `decisions.md` the moment it's made.
- **The card's folder saved after every reply (rule A30, [D87](design-decisions.md#d87)):** an end-of-reply hook commits and pushes the card's folder to its branch `runs/<CARD-KEY>` whenever it changed, so the card's saved copy on GitHub is always current; the commands' own save steps stay.
- **The Jira API backup (rule A31, [D88](design-decisions.md#d88)):** every phase that uses Jira (pick-up, the push, the after-merge step, QA's comments, and the setup checks) uses its connector first; when the connector's tools aren't there after 3 tries, or a Jira tool fails, the command switches by itself to Jira's REST API (`scripts/jira-api.sh`, the user's Atlassian email and API token, optional), says so, and does the same there. The card and its comments come back as Markdown, so `card.md` and the card check see the same text; yes stops stay; never a move to Blocked.
- **Faster, with the same checks ([D90](design-decisions.md#d90)):** pick-up asks the card's gaps and the repos in one round, and planning has no separate summary round (the draft plan lists the answers; its approval confirms them). A small card (a Bug or a Task with one repo, at most 4 ACs, no migration or seeder) gets a shorter plan and, in Phase 5, the quick check by default. Phase 5 starts the servers in the background and leaves them running for a re-run (reused only while the code is the same; the push stops them); a one-repo backend card skips the live call only for a scenario a committed API test checks without stubbing what it depends on. A repo's git is read with `scripts/repo-git.sh`. The card check, the code-first questions, every approval and yes, and every API's structure check stay as they were.
- **All agent rules in one place:** [agent-rules.md](agent-rules.md) lists every rule (G1–G4, A1–A31), with its decision and where it's applied today. The bullets below explain the ones that shape every phase.
- **Where sessions start (rule A10, [D42](design-decisions.md#d42)):** Claude Code and Codex are **always started in the closio-agent folder**, never inside a code repo. The agent adds the code repos a card needs as extra folders and finds its own files (`runs/`, `config/`, `scripts/`, `local/`) by relative path. The setup commands state and check this.
- **Always give the fix (rule A11):** whenever anything fails (a check, a step, a command), in setup and in every phase, the agent tells the user the exact steps to fix it.
- **Branch names (rule A12, [D50](design-decisions.md#d50)):** strictly `SCRUM-<number>/<short-description>`, lowercase words joined by `-`, at most 5 words, the same name in every repo of a card. `scripts/branch-name.sh` makes and checks them.
- **Shared settings ([D46](design-decisions.md#d46)):** values that are the same for everyone and aren't secret (Jira site, GitLab address, VPN gateway and certificate pin, Keychain item names) live in `config/project-settings.sh`.
- **Rules file (`AGENTS.md`, [D45](design-decisions.md#d45)):** both tools read it at the start of every session. It stops the AI doing a command's steps unless the user typed the command (the one exception: `flow-develop` from plain words for a card whose plan is approved, D61), and repeats the folder, Node v22 and secrets rules.
- **Node versions (rules A9 and A13, [D41](design-decisions.md#d41), [D52](design-decisions.md#d52)):** closio-agent itself, Claude Code and Codex run on Node 22: run `nvm use v22` before starting either (Codex's background service must also be started from Node 22, [setup guide](setup-guide.md#install-claude-code-and-codex-inside-node-v22--verified)). **Each code repo runs on its own Node version** (`node_version` in its registry file, from its Dockerfile): before running anything in a repo, the agent runs `nvm use <version>` in the same command, and `nvm install <version>` first if it's missing.
- **Cloning is manual ([D53](design-decisions.md#d53)):** the user clones repos by hand; the agent never clones.
- **Folder access first (rule A15, [D55](design-decisions.md#d55)):** before working in a code repo, the agent checks that the session can use the repo's folder. If it can't, it asks the user to give access and waits.
- **Plans come from the code, with questions first and a manual approval (rule A18, [D63](design-decisions.md#d63)):** before planning, the agent pulls the base branches and reads the current code of every repo involved, asks the user about every difference between the card and the code, and saves nothing before the user approves the plan in chat.
- **Rules and memory before every step of a card phase (rule A17, [D62](design-decisions.md#d62)):** every card-phase command re-reads the team rules and the user-created memory (`local/memory/`, made with `flow-memory`) before each step, applies them, and writes in the card's `history.md` which ones it applied.
- **Decisions asked the grilling way (rule A26, [D76](design-decisions.md#d76)):** while a card command runs, every question it asks and every prompt during it that changes the card's plan, code, tests, data, Jira or GitLab follow [`rulesets/grilling.md`](../rulesets/grilling.md): facts found first and shown (never asked), only real decisions in numbered rounds with a recommended answer each, follow-ups until nothing is open, the user's confirmation before any change, the decisions recorded in the card's `decisions.md`; safety stops stay plain yes/no; memory can't soften it. `flow-grill` does the same on a plan, an idea or a card, on request.
- **Every decision recorded in full (rule A27, [D77](design-decisions.md#d77)):** each card has `runs/<CARD-KEY>/decisions.md`, one numbered row per decision (answers, approvals and refusals at a stop, memory answers, the user's mid-command changes), written with `scripts/run.sh decide`; the card's other files point to it in one line, the way the docs and the build memory point to a decision's full record.
- **The ruleset (rule A19, [D64](design-decisions.md#d64)):** every card follows `rulesets/story-implementation-workflow.md`, kept by the closio-agent builders; no command adds or changes it. A user changes its points for themselves only through their memory, and the plan says which entry changed which point. Migrations and seeders are started from this Mac with the repo's own scripts, only after the user's yes, every run ([D21](design-decisions.md#d21)).
- **Error codes from the code (rule A16, [D59](design-decisions.md#d59)):** before developing, the agent reads the error codes, statuses and messages that already exist in the code and uses them. A card's error reference is checked against the code and every difference is pointed out. Nothing new is invented without the user's approval.
- **How a card's code is written (rules A20–A23, [D66](design-decisions.md#d66)):** WS1 is a proxy: its schema checks only presence, type and format; WS2 checks everything again and owns every business-logic check (in the controller when it needs only the request, inline or in a utils function when large; in the service when it needs the database). Before writing any function the agent searches for an existing one and reuses it (no redundant code), WS1 schema blocks included (common blocks from a shared helper, [D85](design-decisions.md#d85)). A WS1 schema holds every key of the card's request and response structure, with its type. New queries follow the ruleset's query list ([D85](design-decisions.md#d85)): one query instead of several, only the columns needed, the database filtering and counting, indexes, transactions. A migration or seeder runs only after the user has reviewed it and said yes.
- **User memory (rules A7/A8, [D40](design-decisions.md#d40)):** every closio-agent command, in every phase and the setup commands, **loads the current user's memory from `local/memory/` and acts on it if present**. It's private, local-only and git-ignored. **Team rules always take priority (A8):** on a conflict the agent says so and follows the team rule. Users manage entries with `flow-memory`, or accept the agent's offer to save a correction. The memory **grows over time and may not exist at all** (even at the first card); it's created on the first saved entry, and its absence is normal. **Built (F6b, [D56](design-decisions.md#d56)):** every command starts with `bash scripts/memory.sh for <phase> all`, which Claude Code runs by itself when the command loads (Codex: the command's first step). The card phases will also write the entry IDs they used into the card's history.
- **Pause and resume (built in C1):** every step of every card writes a history entry, and its context is saved in files in the card's run folder, `runs/<CARD-KEY>/` inside this project folder (`state.md`, `history.md`, `card.md`, `plan.md`, `verify.md`, `ship.md`, `deployment.md`; `scripts/run.sh`; [D61](design-decisions.md#d61)). The folder is saved to the branch `runs/<CARD-KEY>` of closio-agent and pushed after every phase; the closio-agent folder itself always stays on `main` ([D61](design-decisions.md#d61)). Each phase command carries on from where the card stopped; `flow-status` shows it. It's **committed and shared**, so **any teammate can pick up a paused card**, and it's **kept** after the card is done ([D36](design-decisions.md#d36), [D38](design-decisions.md#d38)). A paused run continues from the last completed step. Run folders never contain secrets.
- **VPN:** any GitLab or internal-host operation (fetch, pull, push, MR, dev API, dev DB) connects to the VPN automatically through openfortivpn with SAML login ([D14](design-decisions.md#d14)). On connect, the agent adds a DNS resolver file for `japfacomfeed.co.id` and removes it on disconnect ([D27](design-decisions.md#d27)). The user only types their Mac password into a macOS dialog (`sudo -A`) and completes the SSO login in the browser if they aren't already signed in ([D30](design-decisions.md#d30)). **Built (F3):** `scripts/vpn.sh` (also behind the `flow-vpn` command and the `flow-connectivity` agent). If GitLab already answers (openfortivpn or the FortiClient app), nothing happens; the VPN stays on until the user disconnects.
- **Secrets:** personal secrets live in the macOS Keychain ([D33](design-decisions.md#d33)); service credentials come from each repo's `.env`, which holds **local values only** ([D34](design-decisions.md#d34)). Scripts and apps load `.env` themselves, and the AI never reads or prints `.env` values in the conversation (rule A6, adopted for now).
- **FE and BE:** each repo is tagged FE or BE, and that tag decides which ruleset applies (BE: `rulesets/story-implementation-workflow.md`; FE: `rulesets/frontend-story-workflow.md`) and the run/test commands.
- **Claude Code and Codex:** every command runs in both tools ([D8](design-decisions.md#d8), [D16](design-decisions.md#d16)).
- **Custom agents:** decided phase by phase ([D16](design-decisions.md#d16)). So far: the AC-check agent in Phase 5, the story-verification agent in Phase 6 ([D19](design-decisions.md#d19)), and the **connectivity agent** at the start of **every phase from 1 to 9** ([D30](design-decisions.md#d30); not in `flow-setup-repo`, [D54](design-decisions.md#d54)).
- **Agent limits ([D47](design-decisions.md#d47)):** each agent has its own limits: a time limit in the script it runs (works in both tools) and, in Claude Code, a step limit (`maxTurns`). On a limit it reports ❌ with what to do next.

  | Agent | Time limit (in its script) | Step limit (Claude Code) |
  |---|---|---|
  | `flow-connectivity` | 180 s for the SSO login (`VPN_CONNECT_TIMEOUT`) | 3 |
  | `flow-ac-checker` | Each call it makes is a script with its own limit (`API_CALL_TIMEOUT` 30 s, `E2E_TIMEOUT` 900 s) | 60 |
  | `flow-story-check` | Only reads | 15 |
  | Later agents | Set when each is built | Set when each is built |

## Not covered yet

- Split cards (set aside for now).
- Production deployment.
