# Architecture — Pipeline Flow

> Status: the phase structure was approved on 2026-10-09 and updated the same day with the developer-testing phase ([D18](design-decisions.md#d18)). Built so far (foundation, Phase 0): `flow-ping`, `flow-doctor`, `flow-vpn`, `flow-configure-user`, `flow-configure-repo`, `flow-setup-repo`, `flow-memory`, `flow-check-card`, `flow-help`, the `flow-connectivity` agent ([commands.md](commands.md)), the Jira card template ([jira-card-template.md](jira-card-template.md)) and the step-by-step guide ([user-guide.md](user-guide.md)). The card phases (1–9) are **not built yet**. Every command starts with **`flow-`** ([D43](design-decisions.md#d43)); the rest of each name is a placeholder until that command is built. In Claude Code a command is typed as `/flow-…`; in Codex as `$flow-…` ([D16](design-decisions.md#d16)). Commands only run when the user types them ([D44](design-decisions.md#d44)).

## Overview

```
Phase 0  Setup (one-time)        flow-ping · flow-doctor · flow-configure-user · flow-configure-repo · flow-setup-repo · flow-memory · flow-check-card · flow-help · Jira card template · user guide
Phase 1  Pick up the card        flow-start <CARD-KEY>
Phase 2  Understand & plan       ✋ user approves the plan
Phase 3  Develop                 agent + user together
Phase 4  Human review            ✋
Phase 5  Check against ACs       loops back to Phase 3 if logic changes are needed
Phase 6  Developer testing       repo tests + story verification; loops back to Phase 3 on failure
Phase 7  Ship                    push (also creates, assigns and describes the MRs)
Phase 8  Merge Request           MRs linked on Jira → card to Code Review
Phase 9  After merge             user runs a command → deployment doc → test on dev → card to Ready for Test
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
- **Per repository** (`flow-configure-repo`, built in F5, [D35](design-decisions.md#d35), [D51](design-decisions.md#d51), [commands.md](commands.md#flow-configure-repo)): the **only way to add a repo**. Shared facts in `config/repos/<repo>.yaml` (committed): GitLab address and path, FE/BE and role, base branch (can differ per repo), install/run/check/test commands, port and health URL, test format and coverage rules, migrations and seeders (existing Sequelize pattern), queues, local services (Redis, RabbitMQ, BullMQ), the repos it calls, the `.env` file name, dev keys, language (node, go or other), Node version (from its Dockerfile), MR target branch, optional default MR labels and reviewers (finalised at MR creation), rulesets (to be refined later). Detected values are only suggestions; the user confirms. Personal facts in `local/repos/<repo>.yaml`: where the clone is. Dev keys in the Keychain.
- **Repository code setup** (`flow-setup-repo`, built in F6, [D54](design-decisions.md#d54), [commands.md](commands.md#flow-setup-repo)): **on a clone the user already made** (cloning is manual, [D53](design-decisions.md#d53)), switches to the repo's own Node version (installing it with nvm if needed, [D52](design-decisions.md#d52)), installs dependencies when needed, finds or starts the local Redis and RabbitMQ (Homebrew or Docker; checks both, asks once if both are there and stops the other), says whether the repo's `.env` points to them, runs the tests once and gives Claude Code and Codex access to the repo folder. It needs no VPN.
- **Help and the guide** (built in F8, [D60](design-decisions.md#d60)): `flow-help` shows every command from the commands' own `## Usage` blocks; [user-guide.md](user-guide.md) walks through everything step by step and is mirrored into a Claude artifact. Rule R17: every new command is added to both, checked by `flow-doctor`.
- **Jira card template** ([D58](design-decisions.md#d58), built in F7 on 2026-10-17): the structure card writers follow, kept in `docs/jira-card-template.md`, with two full example cards in `docs/jira-card-examples.md`. closio-agent never creates cards (people, and later a separate pipeline, do); it checks each picked-up card against the template in Phase 1 with `scripts/card-check.sh` (❌ not ready, ⚠️ worth a look), and anyone can test a card before that with `flow-check-card <CARD-KEY>`. Required sections: Context, How QA can test this, Acceptance Criteria (every AC in Given / When / Then).

### Phase 1 — Pick up the card (`flow-start <CARD-KEY>`)
1. Fetch the card. Stop if its status isn't **To Do**.
2. Check the card against the template ([D58](design-decisions.md#d58)): Spikes aren't picked up; Subtasks and Bugs are. On ❌ gaps the agent lists them and waits for the dev to fix the card or explain the gap in chat (saved with the card), then goes on.
3. If the card is in the backlog, move it into the active sprint ([D13](design-decisions.md#d13)).
4. Move the card to **In Development** and assign it to the user running the command.
5. Work out which repos are needed (FE, BE or both).
6. Pull the latest base branch and create a branch in each repo, named by the strict rule `SCRUM-<number>/<short-description>` (at most 5 words, same name in every repo; rule A12, [D50](design-decisions.md#d50)).
7. Create the card's run folder.

### Phase 2 — Understand & plan
1. Summarise the card and list its acceptance criteria (ACs).
2. Detect special cases: migrations, consumers/queues, setups.
3. **Error codes come from the code** (rule A16, [D59](design-decisions.md#d59)): read the error codes, statuses and messages that already exist in every repo the card touches; check the card's error reference against them and point out every difference. Nothing new is invented.
4. Load the rulesets for each repo type. Baseline: `backend/story-implementation-workflow.md`, with Express 5 ([D26](design-decisions.md#d26)).
5. Write a development plan. ✋ The user approves the plan.

### Phase 3 — Develop
The agent and the user develop together.

### Phase 4 — Human review ✋

### Phase 5 — Check against ACs
Run the code and check each AC, using its own specialised custom agent ([D19](design-decisions.md#d19)). If logic changes are needed, go back to Phase 3.

### Phase 6 — Developer testing ([D18](design-decisions.md#d18))
Runs **before the push**, so a failure never needs a second push (G4).

1. **Repository tests (committed to the repo):** write test cases in the format registered for the repo and run them. The repo's strict **coverage rules** must pass. Skipped for repos without a test suite ([D25](design-decisions.md#d25)).
   - **FE end-to-end:** Playwright, kept **outside the repo in closio-agent's own workspace** and run against the locally running app; never pushed ([D24](design-decisions.md#d24)).
2. **Story verification:** a specialised **custom agent** tests the implementation against the card's story description.
3. Save the results in the card's run folder.
4. On any failure, go back to Phase 3.

Local test environment ([D21](design-decisions.md#d21)):
- **PostgreSQL:** the dev database, used directly. Credentials from the repo's `.env` ([D34](design-decisions.md#d34)).
- **Redis:** local, for everything (BullMQ and any other use).
- **RabbitMQ:** local.
- None of the repos' `docker-compose.yml` files include Redis or RabbitMQ, so `flow-setup-repo` finds a local copy (Homebrew or Docker) or suggests one ([D54](design-decisions.md#d54)).

Test credentials ([D20](design-decisions.md#d20)): per person, asked once in setup, stored in the macOS Keychain under `closio-agent.<name>` ([D33](design-decisions.md#d33)), and read by scripts at run time.
- **FE:** login ID and password (different from the WS1 login).
- **BE, WS1:** session cookie, fetched from the login API with the stored login ID and password:
  - `POST https://dev-closio-ws1-apiprivate.japfacomfeed.co.id/api/v1/login`
  - Headers: `accept: application/json`, `X-Secure-Transmission-Type: x`, `X-Application-Version: 1.0.0+1`, `Content-Type: application/json`
  - Body: `userid` and `password` (per person), `napp_pk: 4` and `client_type: "web"` (the same for everyone)
- **BE, WS2:** each service's own client ID and secret (`x-client-id` / `x-client-secret` headers), **taken from that repo's `.env`**, not the Keychain ([D34](design-decisions.md#d34)).

_Details still open: how the coverage check that runs on every commit affects atomic commits._

### Phase 7 — Ship (`flow-push`)
1. The connectivity agent connects the VPN if needed ([D30](design-decisions.md#d30)).
2. Stash the changes.
3. Fetch the base branch and rebase onto it.
4. Pop the stash.
5. ✋ If the rebase or stash pop causes a conflict, a person resolves it, then the agent continues.
6. Re-run the checks.
7. Create atomic commits.
8. Show the repo's default MR **labels and reviewers** (optional, from `config/repos/<repo>.yaml`) and let the user confirm or change them ([D51](design-decisions.md#d51)).
9. Push once per repo. The same push **creates the MR and assigns it to the user** with git push options ([D31](design-decisions.md#d31)). Right after, a script sets the **full description** through the GitLab REST API, using the token from the Keychain ([D32](design-decisions.md#d32)).

### Phase 8 — Merge Request
1. The MRs already exist, created, assigned and fully described in Phase 7 ([D31](design-decisions.md#d31), [D32](design-decisions.md#d32)).
2. Link the MRs on the Jira card.
3. Move the card to **Code Review**.

### Phase 9 — After merge (user runs a command)
1. Create the deployment doc in the card's run folder: migrations, seeders, API calls, etc.
2. Once deployed, test the change on the **dev environment** ([D22](design-decisions.md#d22)): through dev WS1 with the login cookie, and directly against each WS2 service with its dev client ID/secret from the Keychain ([D37](design-decisions.md#d37)).
3. Move the card to **Ready for Test**.

## Applies across all phases

- **All agent rules in one place:** [agent-rules.md](agent-rules.md) lists every rule (G1–G4, A1–A16), with its decision and where it's applied today. The bullets below explain the ones that shape every phase.
- **Where sessions start (rule A10, [D42](design-decisions.md#d42)):** Claude Code and Codex are **always started in the closio-agent folder**, never inside a code repo. The agent adds the code repos a card needs as extra folders and finds its own files (`runs/`, `config/`, `scripts/`, `local/`) by relative path. The setup commands state and check this.
- **Always give the fix (rule A11):** whenever anything fails (a check, a step, a command), in setup and in every phase, the agent tells the user the exact steps to fix it.
- **Branch names (rule A12, [D50](design-decisions.md#d50)):** strictly `SCRUM-<number>/<short-description>`, lowercase words joined by `-`, at most 5 words, the same name in every repo of a card. `scripts/branch-name.sh` makes and checks them.
- **Shared settings ([D46](design-decisions.md#d46)):** values that are the same for everyone and aren't secret (Jira site, GitLab address, VPN gateway and certificate pin, Keychain item names) live in `config/project-settings.sh`.
- **Rules file (`AGENTS.md`, [D45](design-decisions.md#d45)):** both tools read it at the start of every session. It stops the AI doing a command's steps unless the user typed the command, and repeats the folder, Node v22 and secrets rules.
- **Node versions (rules A9 and A13, [D41](design-decisions.md#d41), [D52](design-decisions.md#d52)):** closio-agent itself, Claude Code and Codex run on Node 22: run `nvm use v22` before starting either (Codex's background service must also be started from Node 22, [setup guide](setup-guide.md#install-claude-code-and-codex-inside-node-v22--verified)). **Each code repo runs on its own Node version** (`node_version` in its registry file, from its Dockerfile): before running anything in a repo, the agent runs `nvm use <version>` in the same command, and `nvm install <version>` first if it's missing.
- **Cloning is manual ([D53](design-decisions.md#d53)):** the user clones repos by hand; the agent never clones.
- **Folder access first (rule A15, [D55](design-decisions.md#d55)):** before working in a code repo, the agent checks that the session can use the repo's folder. If it can't, it asks the user to give access and waits.
- **Error codes from the code (rule A16, [D59](design-decisions.md#d59)):** before developing, the agent reads the error codes, statuses and messages that already exist in the code and uses them. A card's error reference is checked against the code and every difference is pointed out. Nothing new is invented without the user's approval.
- **User memory (rules A7/A8, [D40](design-decisions.md#d40)):** every closio-agent command, in every phase and the setup commands, **loads the current user's memory from `local/memory/` and acts on it if present**. It's private, local-only and git-ignored. **Team rules always take priority (A8):** on a conflict the agent says so and follows the team rule. Users manage entries with `flow-memory`, or accept the agent's offer to save a correction. The memory **grows over time and may not exist at all** (even at the first card); it's created on the first saved entry, and its absence is normal. **Built (F6b, [D56](design-decisions.md#d56)):** every command starts with `bash scripts/memory.sh for <phase> all`, which Claude Code runs by itself when the command loads (Codex: the command's first step). The card phases will also write the entry IDs they used into the card's history.
- **Pause and resume:** every step of every card writes a history entry, and its context is saved in files in the card's run folder, `runs/<CARD-KEY>/` inside this project folder. It's **committed and shared**, so **any teammate can pick up a paused card**, and it's **kept** after the card is done ([D36](design-decisions.md#d36), [D38](design-decisions.md#d38)). A paused run continues from the last completed step. Run folders never contain secrets.
- **VPN:** any GitLab or internal-host operation (fetch, pull, push, MR, dev API, dev DB) connects to the VPN automatically through openfortivpn with SAML login ([D14](design-decisions.md#d14)). On connect, the agent adds a DNS resolver file for `japfacomfeed.co.id` and removes it on disconnect ([D27](design-decisions.md#d27)). The user only types their Mac password into a macOS dialog (`sudo -A`) and completes the SSO login in the browser if they aren't already signed in ([D30](design-decisions.md#d30)). **Built (F3):** `scripts/vpn.sh` (also behind the `flow-vpn` command and the `flow-connectivity` agent). If GitLab already answers (openfortivpn or the FortiClient app), nothing happens; the VPN stays on until the user disconnects.
- **Secrets:** personal secrets live in the macOS Keychain ([D33](design-decisions.md#d33)); service credentials come from each repo's `.env`, which holds **local values only** ([D34](design-decisions.md#d34)). Scripts and apps load `.env` themselves, and the AI never reads or prints `.env` values in the conversation (rule A6, adopted for now).
- **FE and BE:** each repo is tagged FE or BE, and that tag decides the rulesets and run/test commands.
- **Claude Code and Codex:** every command runs in both tools ([D8](design-decisions.md#d8), [D16](design-decisions.md#d16)).
- **Custom agents:** decided phase by phase ([D16](design-decisions.md#d16)). So far: the AC-check agent in Phase 5, the story-verification agent in Phase 6 ([D19](design-decisions.md#d19)), and the **connectivity agent** at the start of **every phase from 1 to 9** ([D30](design-decisions.md#d30); not in `flow-setup-repo`, [D54](design-decisions.md#d54)).
- **Agent limits ([D47](design-decisions.md#d47)):** each agent has its own limits: a time limit in the script it runs (works in both tools) and, in Claude Code, a step limit (`maxTurns`). On a limit it reports ❌ with what to do next.

  | Agent | Time limit (in its script) | Step limit (Claude Code) |
  |---|---|---|
  | `flow-connectivity` | 180 s for the SSO login (`VPN_CONNECT_TIMEOUT`) | 3 |
  | Later agents | Set when each is built | Set when each is built |

## Not covered yet

- Split cards (set aside for now).
- Production deployment.
