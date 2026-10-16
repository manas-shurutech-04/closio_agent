# Project Context

## Goal

Build an **automated AI agent** that covers the software delivery flow:

**Pick up a specified JIRA card → … → MR (Merge Request) review → Deployment doc creation**

- The stages in between were defined on 2026-10-09: the 10 phases in `docs/architecture.md` (D18).
- The agent will be refined step by step over several days through the user's commands.

## Users

People across the organisation, both existing and new team members. That's why everything must be documented and easy to pick up.

## Requirements (from user, 2026-10-09)

- Runs as **Claude Code commands or skills** (D7).
- Needs a **repository configuration** command.
- Needs a **repository code setup** command.
- The whole process can be **paused and restarted**. Memory is logged and files are created at every step.
- Supports both **Codex and Claude Code**: the **same commands must run in both** (user, 2026-10-09).
- Supports both **FE and BE** tickets.
- **MRs the agent creates are assigned to the user.**
- Approach: structure the whole flow first, then build **one piece at a time**.

## Agent Git Rules (from user)

- G1: Always pull from the base branch configured for the repository.
- G2: Always rebase the branch onto that base branch before every push. Order (user, 2026-10-09): **stash changes → rebase → stash pop → then atomic commits**.
- G3: Develop together first, then follow the atomic-commit rules. Never push everything as one commit.
- G4: Only one push to the remote, after connecting to GitLab (from rough step 14).

## Agent Behaviour Rules (from user)

These are the rules for the **agent** (closio-agent when it runs). The team copy, with each rule's decision and where it's applied, is `docs/agent-rules.md` (G1–G4 too); the ones the AI must follow in every session are also in `AGENTS.md`. Update all three together. The rules for **building** the agent are R1–R16 in `rules.md`.

- A1: For every Jira card, **each step creates a history entry**. If the run is paused midway, the context must be saved in files so it can resume from there.
- A2: Any GitLab operation (pull, fetch, push, MR) connects to the VPN **automatically** if it isn't connected. The user never connects manually. They only type the `sudo` password, plus the SSO login if the browser session has expired.
- A3: The agent never moves a card to **Blocked**. That status is for QA only.
- A4: Every command must run in **both Claude Code and Codex**, and **explicit command invocation is mandatory** in both.
- A5: At the **start of each phase that needs it**, a **custom agent (subagent)** runs the commands to connect the **VPN**, then checks GitLab is reachable (the GitLab MCP check was removed by D32) (user, clarified 2026-10-09). **Manual intervention is acceptable** where needed (e.g. password, SSO login, MCP reconnect); push and similar commands also need manual intervention. Runs at the start of Phases 1–9 (no longer in `flow-setup-repo`, which needs no VPN: user, 2026-10-15, D54); Mac password via a macOS dialog. See D30 (GitLab MCP check removed by D32).
- A6: Scripts and apps load `.env` themselves; **the AI never reads or prints `.env` values in the conversation** (user: "hold onto this rule for now", 2026-10-09, read as adopted provisionally; to be confirmed and revisited).
- A7: **Every time any closio-agent command runs, the current user's memory (user-specific runtime context memory, D40) must be loaded and taken into account. If it's present, the agent's actions depend on it.** (user, 2026-10-10)
- A8: **Team rules always take priority over user memory.** On conflict, the agent points it out and follows the team rule. (user, 2026-10-10)
- A9: **Always run `nvm use v22` before starting Claude Code. Node v22 is used for the entire project** (user, 2026-10-10). This also applies to Codex sessions and closio-agent's own scripts. Code repos run on their own Node version instead (A13, D52). See D41.
- A10: **Always start Claude Code / Codex in the closio-agent folder.** The code repos are added as extra folders. This must be clearly stated everywhere and **strictly built into the setup commands** (user, 2026-10-10). See D42.
- A11: **Whenever anything fails (a check, a step, a command), always tell the user the exact steps to fix it, in setup and in the entire execution** (user, 2026-10-10). Written into `AGENTS.md` (rule 4).
- A12: **Branch names strictly follow `SCRUM-<number>/<short-description>`** (lowercase words joined by `-`, only a-z/0-9, **at most 5 words**, same name in every repo of a card). Stored as a rule (user, 2026-10-14): `AGENTS.md` rule 5, D50, `scripts/branch-name.sh`.
- A13: **Each code repo runs on the Node version it is built for** (`node_version` from its Dockerfile, in `config/repos/<repo>.yaml`); before running anything in a repo, `nvm use <version>`, and `nvm install <version>` if nvm doesn't have it (user, 2026-10-14; first written the same day as "all repos on Node 22"). closio-agent, Claude Code and Codex stay on 22 (A9). `AGENTS.md` rule 6, D52.
- A14: **Cloning a repo is always manual** (user, 2026-10-14). The agent never clones; it gives the `git clone` command. `AGENTS.md` rule 7, D53.
- A15: **Ask for folder access first** (user, 2026-10-16: "if the access is not there for the folders then you need to ask the user about the access and then move forward"). Before working in a code repo, check that the session can use its folder; if not, stop, ask the user to give access (with the exact way), and go on only after they have. `AGENTS.md` rule 8, D55.

## Rough Steps (user's original list, 2026-10-09)

1. Start: a Jira card exists. Fix a Jira template that card creators can follow.
2. Pick the card named in the command. It must be in To Do or Backlog.
3. Move the card to In Dev and assign it to yourself.
4. Create new branches from the latest base branch in all required repositories. Branch names follow their own rules.
5. Understand the card.
6. Use a set of rulesets to start developing the card.
7. Development happens.
8. A human reviews it.
9. Run the push command. At this point, check whether a rebase onto the latest base branch is needed.
10. On a merge conflict, a human resolves it manually.
11. Check the code against all acceptance criteria (ACs). Run the code and check whether any logic changes are needed.
12. Check that the VPN connection works.
13. Create atomic commits.
14. Once all commits are done, push. Only one push to the remote, after connecting to GitLab.
15. Push succeeds.
16. Create MRs with proper descriptions.
17. Move the card to Code Review.
18. Once merged, create a deployment document covering migration files and other items such as seeders, API calls, etc.
19. Move the card to RFT.

**Special cases:** migration files; consumer code → queues (difficult logic); dealing with setups; split cards.

## Answers on the Flow (user, 2026-10-09)

- **Jira project:** space "Closio", key **`SCRUM`**, site `productclosio.atlassian.net` (verified through Jira; see `environment.md`).
- **Statuses used by the agent** (exact names, verified): **To Do** → **In Development** → **Code Review** → **Ready for Test**.
  - Not used by the agent: **Blocked** (QA only, A3), **Testing**, **QA - Passed**, **Production** (excluded for now).
  - "Backlog" is **not a status**. It's a separate tab in the project, and cards there have the status To Do. Step 2 therefore means: the card's status is To Do, whether it's in the backlog or in a sprint.
- **Deployment doc:** a file in the card's run folder. Created when the user runs a command after the merge.
- **Split cards:** skipped for now.
- **VPN:** required to reach GitLab. The team uses **FortiClient** with **SSL-VPN + SSO (SAML through an external browser)**. The agent will use **openfortivpn** (D14). Setup saves the connection details (gateway, port, username). The agent stores **no VPN password**: the SSO session is kept by the browser or Microsoft sign-in. The user types their **Mac password for `sudo`** on each connect. Connecting is automated (A2).
- **Per-user setup:** `configure-user` contents approved (D15).
- **Name:** `closio-agent` (D17).
- **Command form:** `/name` in Claude Code, `$name` in Codex; custom agents decided per phase (D16). Every name starts with `flow-` (D43); commands only run when typed (D44).
- **Developer testing (Phase 6, D18), user answers 2026-10-09:**
  - Placed before the push.
  - Test cases are **committed to the repo**, and the repos have **strict line-coverage rules**.
  - A specialised **custom agent** verifies the implementation against the story description.
  - **Stacks:** BE = Node.js, PostgreSQL, Redis, RabbitMQ, BullMQ. FE = Vue.js (Playwright for end-to-end).
  - **BE test auth:** a cookie (user provides it, or the agent fetches it from the login API) plus a client ID and secret (user provides them) for **local and for the dev environment** (after deployment).
  - **FE test auth:** login ID and password from the user; it doesn't change, so it's stored in setup.
  - **Local deps:** local BE tests connect directly to the **dev DB**; **RabbitMQ and BullMQ need local instances**.
- **Backlog cards:** `start` moves them into the active sprint (D13).
- **Custom commands:** the user wants custom commands in both Claude Code and Codex. Codex 0.162.0 appears to have no user-defined `/` commands (see `environment.md`).

## Pipeline Stages

**Approved 2026-10-09, updated by D18.** The full description is in `docs/architecture.md`: Phase 0 Setup → 1 Pick up → 2 Understand & plan (plan approval) → 3 Develop → 4 Human review → 5 AC check → 6 Developer testing → 7 Ship → 8 MR → 9 After merge.

## Answers (user, 2026-10-09, later)

- **Repos in scope (D23):** nodejs-ws1closio, nodejs-ws2closio, nodejs-ws2notification, nodejs-ws2pricingengine, nodejs-ws2targetsalesincentive, ws2jauth, closio-web-v2. Each is registered with the repository setup command, which also captures the repo's test-case format. Out of scope for now: sfa-service-gitlab, sfa-dashboard-web, qa-testcraft.
- **Playwright (D24):** OK to use for closio-web-v2, but **never pushed**. Kept outside the repo in closio-agent's own workspace (option a).
- **Repos without a test suite (D25):** skip committed tests (ws1closio, ws2jauth).
- **Rulesets baseline (D26):** `backend/story-implementation-workflow.md`, using Express 5.
- **Login API:** `napp_pk: 4` and `client_type: "web"` are the same for everyone.
- **VPN:** the user ran the `/etc/resolver` command; the full verified setup is in D14 and `docs/setup-guide.md`. DNS for all internal hosts: domain-wide resolver file on connect/disconnect (D27).
- **Secrets:** macOS Keychain items `closio-agent.<name>`, account `$USER` (D33): gitlab-token, fe-login-id/password, ws1-login-userid/password. FE and WS1 logins are **different**. **WS2 client ID/secret (one per service) and dev Postgres creds come from each repo's `.env`**, which holds **local values only** (D34).
- **Repos:** a dedicated repository command (`configure-repo`) is the only way to add a repo, current or new, capturing the full detail set (D35). The 7 listed repos stay documented for now.
- **GitLab:** ~~GitLab MCP server (D28)~~ → **removed** (D32). MRs: push options create + assign (D31); full description via the GitLab REST API with a personal access token from the macOS Keychain (D32).

## Team Documentation To Maintain (in `docs/`, see D5)

| File | Content | Update when |
|------|---------|-------------|
| `docs/README.md` | Entry point and index, with each doc's status | Any doc is added or its status changes |
| `docs/design-decisions.md` | Every decision, *including what we chose not to use and why* | Every decision (D6 format) |
| `docs/setup-guide.md` | Access, installation, configuration, first run | Setup changes (created 2026-10-09 with the VPN section) |
| `docs/commands.md` | Every agent command | A command is added or changed (created 2026-10-10 with `flow-ping`, `flow-doctor`) |
| `docs/architecture.md` | How the stages connect, inputs and outputs | Stages change (created 2026-10-09) |
| `docs/agent-rules.md` | Every agent rule (G1–G4, A1–A15): decision, `AGENTS.md` number, where it's applied today | A rule is added or changed, or a command starts applying one (created 2026-10-15) |
| `docs/changelog.md` | Dated changes to the agent | Every change to the agent (created 2026-10-10) |
| `README.md` (top level) | Entry point for the repo: status, start here, folder table, commands so far | Any command, folder or status change |
| `AGENTS.md` | Rules both AI tools read every session | A rule for the agent is added or changed |
| `config/repos/*.yaml`, `config/project-settings.sh` | Shared repo facts and shared settings | A repo detail or shared value changes |

More docs may be added as the user specifies.

## Answers (user, 2026-10-09, run folder + build approach)

- **Dev WS2 creds:** option (b): per-service dev client ID/secret in the Keychain (D37).
- **Location:** **everything in this project folder.** It will be pushed and cloned by the team, and the agent's memory (`runs/`) must be available to whoever clones it (D36).
- **After Ready for Test:** keep the run folder (D38).
- **Card ownership:** for now, any teammate can pick up a paused card (D38).
- **Build approach (user):** build **from scratch, prerequisites first**: setup command, repository setup command, and so on. Then **test with a completely new user** so no gap is left, before moving to the run folder and the phases. A foundation build plan was drafted 2026-10-09 and is waiting on approval.

## Foundation Build Plan (approved order, user 2026-10-09; more steps may be added)

| # | Piece | Status |
|---|---|---|
| F0 | Project skeleton (`git init`, folders, `.gitignore`, README) | **Done 2026-10-09** (D39). First commit + push 2026-10-11 to GitHub |
| F1 | Skill format check in Claude Code + Codex: `flow-ping` + first version of `flow-doctor` (D8, D43, D44) | **Built 2026-10-10.** T1, T2, T5 passed; T4 passed after `AGENTS.md` (D45); T3 passed after Codex was reinstalled inside Node v22 and its background service restarted. **F1 complete** |
| F2 | Rest of `flow-doctor` (tools, Codex service, VPN state, GitLab + token, Keychain names, Jira via the AI); shared settings file (D46) | **Built 2026-10-10, tested by the user 2026-10-11** in Claude Code and Codex (only the 5 Keychain items missing, as expected). One Codex-sandbox fix. **F2 complete** |
| F3 | Connectivity script + agent (D30): `scripts/vpn.sh` (connect/status/disconnect, one password dialog), `flow-connectivity` agent for both tools, `flow-vpn` command | **Built and tested 2026-10-11** (all 12 live tests passed in Claude Code and Codex). **F3 complete** |
| F4 | `flow-configure-user`: personal settings in `local/user-settings.sh` + 5 Keychain secrets via heads-up + hidden macOS dialogs; doctor check; agent limits (D47) | **Built 2026-10-12; user tests passed 2026-10-13** (plus D49 fewer prompts, Jira wait-and-retry). **F4 complete** |
| F5 | `flow-configure-repo` (shared registry `config/repos/<repo>.yaml` + personal `local/repos/<repo>.yaml`, auto-detect then confirm, per-repo dev WS2 keys, doctor checks) | **Built 2026-10-14.** My tests passed; **7 repos registered** (`config/repos/`, local paths set on this Mac). **Committed and pushed 2026-10-15** (atomic commits, with its docs). User tests passed 2026-10-15. **F5 complete** |
| F6 | `flow-setup-repo` (on a clone the user already made: Node switch + `nvm install` (A13, D52), install only when needed, local Redis/RabbitMQ from Homebrew or Docker, `.env` points-to-this-Mac check, tests once, folder access for Claude Code + Codex start command, `all` option; **no VPN step, no cloning**; D54) | **Built 2026-10-16** after the user's yes (D54). My tests passed (pretend Homebrew/Docker states, temp repos, real `npm ci` on a throwaway copy of ws2jauth). **User tests passed 2026-10-16. F6 complete** |
| F7 | Jira card template | — |
| F8 | Docs (setup guide on commands, `commands.md`, `changelog.md`) | — |
| F9 | Completely-new-user test (separate macOS account) | — |
| F6b | User memory **mechanism** (D40, rules A7/A8): dedicated `memory` command, loading in every command, created on first entry. The **content** starts empty and grows over time (may not exist at the first card) | **Built 2026-10-16** (D56: `flow-memory`, `scripts/memory.sh`, automatic memory step in every command; all command scripts pre-approved in Claude Code and Codex, D57). My tests passed; **user tests passed 2026-10-16. F6b complete** |

## Answers (user, 2026-10-10)

- F6b result (user, 2026-10-16): "F6b is done and tested". Asked how to clear the memory: explained `/flow-memory remove <id>` and deleting `local/memory/`; suggested a `/flow-memory clear` option (no answer yet).
- F6b answers (user, 2026-10-16): loading "this works, make sure this script runs before every command without a miss"; "all the scripts written in the commands should run automatically without user permission"; name `flow-memory`; fields OK; phase names OK; conflicting entry: warn, save if still wanted (a); offered saves in `AGENTS.md` (became rule 9, since rule 8 is folder access); pre-approve `memory.sh`; hand edits allowed; doctor count line; "commit the F6 changes first, then build this" (7 commits, not pushed).
- After F6 (user, 2026-10-16): yes to checking `.env` names against `.env.example` (built); new rule A15 (ask for folder access when it's missing); "first fix these then we will come to the drafts" (F6b draft waits).
- F6 result (user, 2026-10-16): "all the commands are working we can move to the step F6b".
- F6 first test (user, 2026-10-16, screenshot): `/flow-setup-repo ws2jauth` stopped at Claude Code's approval prompt; "can you please dont ask the user permission here" → `setup-repo.sh run *` pre-approved (D49, D54).
- F6 approval (user, 2026-10-16): "Yes, build F6 with the .env help steps, opening the .env file in my editor, and quitting Docker again when it was only started to look."
- F6 request (user, 2026-10-16): on the `.env` check, "Can we also have steps which can help assisting the user to setup things here" → drafted step-by-step help (file to open, lines to set, check again), recorded in D54.
- F6 answers 2 (user, 2026-10-16): setup leaves branches to the card phases (option a); Redis/RabbitMQ: start a stopped copy only if the user goes with it, check both Homebrew and Docker before proceeding, stop the other copy without user intervention, none → suggest Docker ("sure").
- F6 draft answers (user, 2026-10-15): on "setup never switches branches, pulls, stashes or changes tracked files": "i will need the agent to perform all these things" (asked whether setup should do them or the later phases, as planned); local services: look for both Homebrew and Docker copies, one → use it and say so, none → suggest one, both → ask which; dev server versions unknown; folder access (a), install when needed (a), tests once (a), web repo file fix yes (done), `.env` check yes (user changes values themselves), pre-approve status only, `all` yes, drop the VPN step yes (D30/A5 amended). Recorded as D54.
- F5 result (user, 2026-10-15): "F5 results are fine"; asked for the F6 draft.
- Agent rules doc (user, 2026-10-15): yes to `docs/agent-rules.md` (all agent rules in one table, linked to their decisions); "keep the documents updated with each command" (added to R15). Then: "point me to the right files only" → yes to making it rule R16.
- `local/` approach for local repo paths: **approved** (D39).
- Git remote: **pushed 2026-10-11** to the private GitHub repo `https://github.com/manas-shurutech-04/closio_agent.git` (user). Clone with `... closio-agent` as the folder name.
- Rename the folder `AI Pipeline` → `closio-agent`: **yes** (timing open; renaming loses Claude Code's session history and memory for this path).
- First commit: **not yet** at the time; made and pushed on 2026-10-11 (D39).
- **New requirement, user-specific runtime context memory (D40):** when users run the workflows they may want to store changes/preferences for current and future runs. It's an additional memory, user-specific, maintained by each user, stored in this repository, used in coding and all other phases to make results more precise to the user's description. **Rule A7:** always load and apply it in every command when present.
- User memory decisions (2026-10-10): **local only** (`local/memory/`, git-ignored), no username folder; dedicated memory command plus agent-offered saves; **A8**: team rules always win; folder rename left to the user.
- User memory is ever-growing and may not exist even at the first card; created on first entry, absence is normal (user, 2026-10-10).
- F6b position (after `setup-repo`) confirmed (user, 2026-10-10).
- F5 answers (user, 2026-10-14): run each repo on the Node version in the repo, install it with nvm if missing (A13 changed, D52); cloning remains manual only (D53); asked whether all new commands are documented (added helper-scripts and agents sections to `commands.md`).
- F5 path option approved; user not convinced a brand-new repo can be added later (2026-10-14): showed detection on two never-registered repos, made detection work for non-Node repos (`language`), added a step-by-step to commands.md.
- F5 test feedback (user, 2026-10-14): don't make the repo list static (new repos must stay addable; they are); test 6 couldn't be done because the clone path was already saved (proposed a `path` option); missing dev keys should be ⚠️ not ❌ (done).
- F5 follow-up (user, 2026-10-14): MR labels and reviewers: **stored as optional defaults (`none` for now), finalised when each MR is created** (corrected the same day; first read as "not stored"); rule A13 (Node 22 for every repo); update all docs.
- F5 repo answers (user, 2026-10-14): base branch `develop` for the backend repos, `development` for the web app (their main work branches); port is in each repo's `.env` (recorded as "from the repo's .env (PORT / VITE_PORT)", the AI doesn't read it); no health URL except notification (**wrong: corrected 2026-10-14, the user says every repo must have one; all backend repos use `/api/v1/health-checker`, web `/`**); MR labels optional (none for now), reviewers not given (none for now); dev DB details: "okayy", read as add later.
- F5 answers 2 (user, 2026-10-14): branch rule OK, but **strict, stored in the rules, with a word limit** (set to 5); detected migration values are suggestions, ask if a repo differs; dev DB user/password optional keys: yes; nothing else to add.
- F5 answers (user, 2026-10-14): local services incl. BullMQ; rulesets refined later; per-repo keys can go beyond client ID/secret (e.g. DB connection), shortlist from the repos; migrations/seeders: say whether to follow the existing pattern; queues recorded; run/lint commands suggested from scripts then confirmed; calls between WS1, WS2 and FE; MR target branch, labels, reviewers asked; base branch can differ per repo; Claude to propose a standard branch-naming rule; flat YAML OK; register the 7 repos during testing.
- F4 approved (user, 2026-10-12): build it; different limits for different agents (D47); the review agent will also comment, so **one GitLab token** (D48).
- F4 answers 2 (user, 2026-10-12): keep the VPN profile for future use, marked as not necessary; heads-up + hidden dialog OK. New ideas: time limits for the separate agents; separate GitLab tokens for the review agent and the other agents (thoughts given, waiting on the user).
- F4 answers (user, 2026-10-12): per-repo dev WS2 keys → F5 (F5 will hold many more details); keep "AI tools used"; hidden macOS dialogs for secrets, with a heads-up before each so the value can be copied first; don't suggest a workspace folder; asked why the VPN profile is unused (explained, confirmation pending).
- F3 answers (user, 2026-10-11): add `flow-vpn` (connect/status/disconnect); VPN stays connected until the user disconnects; remove the old `jcvs` DNS file during connect.
- F2 answers (user, 2026-10-10): ⚠️ symbol OK; `config/project-settings.sh` OK; new rule A11 (always give fix steps). Codex Jira: give the fix steps (setup guide §3) rather than a separate plan step.
- Codex installed with npm inside Node v22 like Claude Code, Homebrew copy removed, background service restarted; `$flow-doctor` passes in Codex (user, 2026-10-10). Doctor symbols stay as they are.
- F1 test follow-up (user, 2026-10-10): `AGENTS.md` rules file approved (D45), re-run T4 in new sessions. Doctor output problem is the spacing between ✅/❌ and the words in the Claude app console; Codex chat showed all checks joined on one line (and Node v18).
- F1 answers 2 (user, 2026-10-10): Node v22 also a working rule (R14); install Claude Code with npm inside Node v22 and remove the Homebrew copy (done: 2.1.296); prefix **`flow-`** (D43); keep **both** `flow-ping` and `flow-doctor` (first version in F1); commands only run when typed, for every command (D44).
- F1 feedback (user, 2026-10-10): "hello" names are bad, use relevant names (rule R13); command prefix must **not** be `closio` (find another); keep the install-check command permanently but with a better name; sessions start in the closio-agent folder (A10, D42); rule A9 (`nvm use v22`, D41); keep language simple (rule R12). Asked for a plain explanation of "commands only start when typed".
