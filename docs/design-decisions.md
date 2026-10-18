# Design Decisions

Every decision taken while building the agent, including the options we rejected and why.

- Decisions are never deleted. When one is replaced, its status changes to `Superseded by Dx` and the new decision explains what changed.
- Entry format: Date, Status, Context, Decision, Why, Rejected options.

---

<a id="d1"></a>
### D1 — Build memory is split into separate files in a visible `build-memory/` folder
- **Date:** 2026-10-09
- **Status:** Accepted
- **Context:** Memory for building the agent started as one file, `BUILD_MEMORY.md`, which would keep growing over the project.
- **Decision:** Split it into separate files (index, rules, project context, environment, decisions, open questions, history) in a visible `build-memory/` folder.
- **Why:** Partitioning now scales for the future. A visible folder means colleagues can see it.
- **Rejected options:**
  - A single `BUILD_MEMORY.md`: it would grow too big.
  - A hidden `.build-memory/` folder: colleagues couldn't see it as easily.

<a id="d2"></a>
### D2 — Build memory, team docs and the agent's own memory are kept in three separate places
- **Date:** 2026-10-09
- **Status:** Accepted; the agent's memory location is set by [D36](#d36) (inside this project folder, `runs/`).
- **Context:** The project has three kinds of stored information with different purposes and audiences.
- **Decision:** `build-memory/` holds working memory for building the agent. `docs/` holds what colleagues read. The agent's own memory while it runs gets its own location (to be designed).
- **Why:** The memory for building the agent must be completely separate from the agent's memory while it runs (project requirement). Team docs serve a different audience than either.
- **Rejected options:** None considered.

<a id="d3"></a>
### D3 — Each decision is recorded in full in one place only
- **Date:** 2026-10-09
- **Status:** Accepted
- **Context:** Decisions need to appear both in the team docs and in build memory.
- **Decision:** The full record lives here, in `docs/design-decisions.md`. `build-memory/decisions.md` holds one line per decision plus a link to it.
- **Why:** If both files held the full text, one could be edited and the other not, and they would contradict each other.
- **Rejected options:**
  - Full text in both places: the two copies would drift apart.

<a id="d4"></a>
### D4 — The step log is one single file
- **Date:** 2026-10-09
- **Status:** Accepted
- **Context:** Build memory keeps a log with one row per step, which is its fastest-growing part.
- **Decision:** Keep it as one file, `build-memory/history.md`.
- **Why:** User preference.
- **Rejected options:**
  - Monthly files (e.g. `history/2026-10.md`).
  - Weekly files (e.g. `history/2026-W41.md`).

<a id="d5"></a>
### D5 — Layout of `docs/`, with files created only once they have real content
- **Date:** 2026-10-09
- **Status:** Accepted. **`agent-rules.md` added on 2026-10-15** (user): every agent rule (G1–G4, A1–A14) in one table, so colleagues find them in one place. **`jira-card-template.md` and `jira-card-examples.md` added on 2026-10-17** (F7, [D58](#d58)). **`user-guide.md` added on 2026-10-17** (F8, [D60](#d60)).
- **Context:** Team documentation needs a fixed home and structure for existing and new team members.
- **Decision:** `docs/` contains `README.md`, `setup-guide.md`, `commands.md`, `design-decisions.md`, `architecture.md` and `changelog.md` (all six exist since 2026-10-10), plus `agent-rules.md` (since 2026-10-15), `jira-card-template.md`, `jira-card-examples.md` and `user-guide.md` (since 2026-10-17). Each file is created only once there is real content for it. `docs/README.md` lists all of them with their status.
- **Why:** These cover the required documentation (commands, design decisions, setup guide). `architecture.md` shows how the stages connect, and `changelog.md` lets existing users catch up without reading every doc.
- **Rejected options:**
  - Creating empty placeholder files upfront: they could mislead colleagues into thinking content exists.

<a id="d6"></a>
### D6 — Decision entries have a status, and replaced decisions are kept
- **Date:** 2026-10-09
- **Status:** Accepted
- **Context:** Decisions will change as the agent is refined.
- **Decision:** Each entry has a `Status` field (`Accepted` or `Superseded by Dx`). Replaced decisions stay in the file.
- **Why:** Colleagues can still see why things changed.
- **Rejected options:**
  - Deleting or overwriting old decisions: the reasons behind changes would be lost.

<a id="d7"></a>
### D7 — The agent runs as Claude Code commands or skills
- **Date:** 2026-10-09
- **Status:** Accepted
- **Context:** The agent needs a way to run. Options considered: Claude Code slash commands/skills/subagents, the Claude Agent SDK, or being triggered from CI.
- **Decision:** The agent runs via Claude Code commands or skills.
- **Why:** Easy for the team to read and edit. Fits developing together and the human review steps. Runs on the developer's machine, with their local repos and VPN. The same skills also run in Codex (D8).
- **Rejected options:**
  - Claude Agent SDK: runs Claude models only, so it can't meet the requirement that the same commands run in Codex. It also means writing and maintaining code.
  - Triggering from CI: no live collaboration (conflicts with steps 7–8), and it needs VPN access and secrets stored in CI.

<a id="d8"></a>
### D8 — One shared skill format for Claude Code and Codex
- **Date:** 2026-10-09
- **Status:** Accepted. **Built and tested in F1 (2026-10-10):** one copy per command in `.agents/skills/`, a per-command link in `.claude/skills/`; works in Claude Code (CLI and desktop app) and Codex (`$name`). **Amended by [D44](#d44)**: one Claude-only line (`disable-model-invocation`) in every command file; tested, Codex accepts it.
- **Context:** Every command must run in both Claude Code and Codex. Both tools support the Agent Skills open standard (a folder with a `SKILL.md`), but look in different places: Claude Code in `.claude/skills/`, Codex in `.agents/skills/`.
- **Decision:** Keep one copy of each skill in `.agents/skills/<name>/SKILL.md` and make it visible to Claude Code through `.claude/skills/` (symbolic link, or a sync script if the link doesn't work). Use only the frontmatter fields both tools share (`name`, `description`). Put deterministic logic in `scripts/`.
- **Why:** The instructions are maintained in one place and the two tools behave the same.
- **Rejected options:**
  - Separate copies per tool: they would drift apart.
  - Claude Code `.claude/commands/` files: Codex doesn't read them, and Claude Code has merged commands into skills anyway.
- **Note:** Claude Code runs a skill as a command with `/name`. Codex runs it with `$name` or the `/skills` menu. Codex's `/prompts:name` custom prompts are officially deprecated.
- **Built in F1 (2026-10-10):** one relative link **per command**, `.claude/skills/<name>` → `../../.agents/skills/<name>`, created by `scripts/link-claude-skills.sh`. Claude Code's docs say a skill entry can be a link to a folder; they don't mention linking the whole `.claude/skills` folder, so that was not used. Checked: the links work on disk and git stores them as links (mode 120000). **Tested in the tools (user, 2026-10-10):** Claude Code CLI 2.1.296 (T1) and the Claude desktop app (T2) list and run `flow-ping` and `flow-doctor`. Codex 0.162.0 (T3) runs `$flow-doctor`, so it loads the command with the Claude-only line (D44).

<a id="d9"></a>
### D9 — Pipeline phase structure
- **Date:** 2026-10-09
- **Status:** Superseded by [D18](#d18) (a developer-testing phase was added before Ship)
- **Context:** The user's 19 rough steps needed to be grouped into phases and commands.
- **Decision:** Nine phases (0 Setup → 8 After merge), with a user checkpoint for plan approval and one for human review. Full description in [architecture.md](architecture.md).
- **Why:** Approved by the user.
- **Rejected options:** None considered.

<a id="d10"></a>
### D10 — Ship order: stash, rebase, pop the stash, then atomic commits
- **Date:** 2026-10-09
- **Status:** Accepted **Built 2026-10-18 ([D70](#d70)):** `flow-push` step 4, `scripts/card-branch.sh rebase` (stash with new files, fetch, rebase, stash pop; a conflict stops with exit 4 for the user, then `rebase-continue`).
- **Context:** G2 requires rebasing onto the base branch before every push, and git won't rebase with uncommitted changes.
- **Decision:** VPN → stash → fetch and rebase → stash pop → conflicts resolved by a person → re-run checks → atomic commits → single push.
- **Why:** User decision.
- **Rejected options:**
  - Atomic commits first, then rebase (suggested by Claude): not chosen by the user.

<a id="d11"></a>
### D11 — Jira statuses used by the agent
- **Date:** 2026-10-09
- **Status:** Accepted **2026-10-18 ([D70](#d70)):** `flow-push` moves the card to Code Review.
- **Context:** Project `SCRUM` (Closio) has the statuses To Do, In Development, Code Review, Blocked, Ready for Test, Testing, QA - Passed and Production (checked through Jira).
- **Decision:** The agent uses only To Do (pickup), In Development, Code Review and Ready for Test. "Backlog" is a tab, not a status, so a card in it counts as To Do.
- **Why:** Blocked is for QA only. Production is excluded for now. Testing and QA - Passed are QA's stages.
- **Rejected options:**
  - Moving the card to Blocked on a merge conflict: Blocked is for QA only.

<a id="d12"></a>
### D12 — The deployment doc is a file in the card's run folder, created by a user-run command
- **Date:** 2026-10-09
- **Status:** Accepted **Changed 2026-10-18 ([D72](#d72)):** the doc also goes on the Jira card as one comment (user: "it will go on the JIRA card as well"); built in `flow-finish`.
- **Context:** Step 18 creates a deployment document after the merge.
- **Decision:** The user runs a command after the merge, and the doc is written as a file in the card's run folder.
- **Why:** User decision. A file is enough for now.
- **Rejected options:**
  - Confluence page or Jira comment: not needed for now.
  - The agent detecting merges by itself: the user runs the command instead.

<a id="d13"></a>
### D13 — `start` moves a backlog card into the active sprint
- **Date:** 2026-10-09
- **Status:** Accepted
- **Context:** A To Do card can be in the backlog instead of the active sprint. If it's moved to In Development there, it doesn't appear on the board.
- **Decision:** When picking up a card that isn't in the active sprint, `start` also moves it into the active sprint.
- **Why:** User decision. The card stays visible on the board.
- **Rejected options:**
  - Leaving the card in the backlog: it wouldn't appear on the board.

<a id="d14"></a>
### D14 — The agent connects to the VPN with openfortivpn using SAML (SSO) login
- **Date:** 2026-10-09
- **Status:** Accepted. **Tested end to end on 2026-10-09** (openfortivpn 1.24.1, macOS 26.6.2). **Built into the agent in F3 (2026-10-11)** as `scripts/vpn.sh` and `flow-vpn` ([D30](#d30)); the per-host DNS file in step 3 below was replaced by one domain-wide file ([D27](#d27)).
- **Context:** GitLab (`jcvs.japfacomfeed.co.id`) is only reachable over the VPN, and the agent must connect automatically (A2). The team's FortiClient connection is SSL-VPN, gateway `vpnwm.japfacomfeed.co.id:443/sso`, with SSO through an external browser (SAML) and no client certificate. There is no official FortiClient command line for macOS.
- **Decision:** Use **openfortivpn** (open source, installed with Homebrew) with its `--saml-login` option.
- **Why:** User decision. It's scriptable, so the agent can start the connection itself.
- **Rejected options:**
  - fvpnctl (third-party tool that controls the FortiClient app): FortiClient must be started in a debugging mode for it to work.
  - Connecting manually in the FortiClient app: conflicts with A2.
  - A sudoers rule so openfortivpn runs without a password: it loosens the Mac's security.
  - Storing a VPN password: not needed, because the login is SSO.

**How it works (verified):**

1. **Install:** `brew install openfortivpn`. It uses macOS's built-in `/usr/sbin/pppd`.
2. **Connect:**
   ```
   sudo openfortivpn vpnwm.japfacomfeed.co.id:443 --realm=sso --saml-login --trusted-cert 142458260b4b0b96bad1fd65db4a58b24d02da43be05620efe476bcff71bfa5e
   ```
   - `sudo`: openfortivpn needs administrator rights to set up the network interface, routes and DNS. **The user types their Mac password** each time.
   - `--realm=sso`: matches the `/sso` path of the FortiClient gateway address.
   - `--saml-login`: openfortivpn listens on `127.0.0.1:8020` and prints a login URL (`https://vpnwm.japfacomfeed.co.id:443/remote/saml/start?redirect=1&realm=sso`). The user opens it in the browser and completes the SSO login (automatic if already signed in). The browser hands the session back to openfortivpn, which prints "Tunnel is up and running".
   - `--trusted-cert`: the gateway sends only its own certificate, not the GoDaddy G2 intermediate, so normal validation fails ("unable to verify the first certificate"). The certificate (`CN=*.japfacomfeed.co.id`, GoDaddy Secure CA G2) was checked independently with `openssl`, and its SHA-256 fingerprint is pinned. **It expires on 2027-02-03.** After renewal the pin must be updated, or openfortivpn will refuse to connect and print the new fingerprint.
3. **DNS (one-time setup):** openfortivpn writes the VPN DNS servers into `/etc/resolv.conf`, but macOS apps (git, curl, browsers) don't read that file, so GitLab's name didn't resolve. Fix: a macOS per-domain resolver file that only covers GitLab:
   ```
   sudo mkdir -p /etc/resolver && printf "nameserver 10.90.0.53\nnameserver 10.190.0.55\n" | sudo tee /etc/resolver/jcvs.japfacomfeed.co.id
   ```
   It only affects that one host name, so it does no harm while the VPN is off.
4. **Disconnect:** Ctrl-C in the terminal running openfortivpn.

**Verified results:** "Tunnel is up and running". Internal routes (10.x, 172.17.x) go through `ppp0`. With the resolver file: `curl https://jcvs.japfacomfeed.co.id` → HTTP 200, and `git ls-remote` against the GitLab repos works.

**Designed and built in F3 (2026-10-11):** connects only when GitLab doesn't answer (any VPN client counts); a renewed certificate is reported with its new fingerprint to confirm with IT and put in `config/project-settings.sh`; one domain-wide DNS file covers every internal host ([D27](#d27), [D30](#d30)).

<a id="d15"></a>
### D15 — What the per-user setup (`configure-user`) stores
- **Date:** 2026-10-09
- **Status:** Accepted; amended by [D29](#d29) (GitLab access token removed), then **by [D32](#d32) (GitLab access token restored)**. **Built in F4 (2026-10-12) with changes**, see "Built" below.
- **Context:** Some details differ per person and are needed by several phases.
- **Decision:** `configure-user` stores, outside the code repos:

  | Item | Used for | How it's filled |
  |---|---|---|
  | Jira account ID | Assigning the card (Phase 1) | Fetched automatically from Jira |
  | GitLab host and username | Assigning MRs (Phase 8) | Asked once |
  | GitLab personal access token | Setting the full MR description through the GitLab REST API ([D32](#d32)) | Created by the user in GitLab, entered once outside the AI chat, stored in the macOS Keychain, never in a file. Removed by D29, **restored by D32** |
  | Git name and email | Commit author | Read from git settings; asked only if missing |
  | VPN profile: gateway, port, username (no password) | Automatic VPN connection (D14) | Asked once |
  | AI tool(s): Claude Code, Codex or both | Where skills are installed (D8) | Asked |
  | Workspace folder | Where repos are cloned | Asked once |

  Shared settings (Jira site, project key `SCRUM`) belong in the project config, not the user's.
- **Built (F4, 2026-10-12), command `flow-configure-user`:**
  - Personal settings go to `local/user-settings.sh` (private, git-ignored): Jira account ID (fetched by the AI from Jira), GitLab username (read with the token when the VPN is on, else typed), workspace folder (typed, **no folder suggested**, must exist), AI tools (Claude Code, Codex or both; `flow-doctor` uses it), and the **optional VPN username**.
  - **VPN profile kept, but marked "not needed today"** (user, 2026-10-12): the VPN logs in with SSO in the browser, and the gateway, port, realm and certificate pin are the same for everyone, so they live in `config/project-settings.sh` ([D46](#d46)). Only the optional VPN username is stored per person, for later use.
  - Git name and email: read from git; asked only if missing, then set in the global git settings.
  - The 5 secrets go to the Keychain through **a heads-up message ("Copy it now, then click Continue") followed by a hidden macOS input box** (user, 2026-10-12). The value is passed to `security` on its standard input, never on a command line, and never through the AI chat. The terminal commands in the setup guide stay as a backup.
  - The per-repo dev WS2 keys ([D37](#d37)) are **asked in F5 (`flow-configure-repo`)** instead, where it's known which repos are WS2 services (user, 2026-10-12).
  - Every item can be redone alone (e.g. `/flow-configure-user gitlab-token`).- **Why:** Approved by the user. Personal details and secrets never get committed, and secrets never pass through the AI chat (anything typed there is sent to the AI provider and saved in the session history).
- **Rejected options:**
  - Storing the token in a config file: it could leak or be committed by accident.

<a id="d16"></a>
### D16 — Command form: `/name` in Claude Code, `$name` in Codex; custom agents decided per phase
- **Date:** 2026-10-09
- **Status:** Accepted; **amended by [D43](#d43)** (every command name starts with `flow-`, e.g. `/flow-start`, `$flow-start`)
- **Context:** Every command must be startable explicitly in both tools (A4). Codex 0.162.0 has no user-defined `/` commands; its custom prompts are deprecated. In both tools, custom agents (subagents) can't be started with a slash command.
- **Decision:** Each command is a skill: typed as `/start` in Claude Code and `$start` in Codex. Custom agents are used inside phases where they help, decided as each phase is built.
- **Why:** A skill is the only thing both tools let the user start explicitly. A skill runs in the user's conversation (interactive). A custom agent is a separate worker with a fresh context that returns a summary, which suits self-contained jobs.
- **Rejected options:**
  - Codex custom prompts (`/prompts:name`): deprecated, and absent from the installed Codex 0.162.0.
  - Custom agents as entry points: neither tool can start them with a slash command.

<a id="d17"></a>
### D17 — The agent is named `closio-agent`
- **Date:** 2026-10-09
- **Status:** Accepted
- **Context:** A name is needed for folders, config files and skill names.
- **Decision:** `closio-agent`.
- **Why:** User choice. It's unambiguous within the Closio project.
- **Rejected options:** `cardpilot`, `cardflow`, `ticketpilot` (suggested by Claude).

<a id="d18"></a>
### D18 — Ten-phase structure: developer testing added before Ship
- **Date:** 2026-10-09
- **Status:** Accepted. The details of the testing phase are partly open. **Changed by [D65](#d65) (2026-10-17):** the committed repo tests are now written and run in Phase 3 (`flow-develop`); Phase 6 (`flow-verify`) runs them again with the AC checks, Playwright for the web app and the story check. **2026-10-18 ([D67](#d67)):** a failure in Phase 6 no longer loops back by itself: the user is told what's wrong and decides.
- **Context:** The user asked for a phase where everything created is tested from the developer's perspective, with an FE (mostly Playwright) and BE test setup.
- **Decision:** New **Phase 6 — Developer testing** between the AC check and Ship. Ship, Merge Request and After merge become Phases 7, 8 and 9. The phase contains:
  - Test cases written for the repo and **committed** with the change; the repo's strict line-coverage rules must pass. FE end-to-end tests mostly use Playwright.
  - A specialised **custom agent** that tests the implementation against the card's story description.
  - Failures loop back to Phase 3.
  - Local environment: BE tests use the dev database directly; RabbitMQ and BullMQ run as local instances.
- **Why:** Testing before the push means a failure never needs a second push (G4). A separate agent that didn't write the code gives an independent check against the story.
- **Rejected options:**
  - Testing after the push (the user's first idea): a failure would need a second push, which breaks G4.
  - Keeping the tests only in the card's run folder: the repos have coverage rules, so tests belong in the repo.

<a id="d19"></a>
### D19 — AC check (Phase 5) and developer testing (Phase 6) stay separate, each with its own custom agent(s)
- **Date:** 2026-10-09
- **Status:** Accepted **Built 2026-10-18 ([D67](#d67)):** Phase 5's agent is `flow-ac-checker` (writes the test cases), Phase 6's is `flow-story-check`.
- **Context:** The story-verification agent in Phase 6 overlaps with the Phase 5 AC check. Claude suggested merging them into one phase.
- **Decision:** Keep two phases. Each uses its own specialised custom agent(s).
- **Why:** User decision.
- **Rejected options:**
  - Merging Phases 5 and 6 into one "Verify & test" phase (suggested by Claude).

<a id="d20"></a>
### D20 — Test credentials are per person and stored in the macOS Keychain
- **Date:** 2026-10-09
- **Status:** Accepted; **amended by [D34](#d34)** (WS2 client ID/secret come from each repo's `.env`, not the Keychain; the FE and WS1 logins are confirmed to be different). **2026-10-18 ([D71](#d71)):** every WS1 login for a check goes to the dev WS1 login URL; the session cookie it returns is used on the WS1 on this Mac.
- **Context:** Testing needs credentials. FE: a login ID and password. BE: the WS1 session cookie (from the login API) and WS2 client ID and secret, for local and for the dev environment.
- **Decision:** Asked for once during setup and stored **per person in the macOS Keychain**. Scripts read the values at run time, so they never enter the AI conversation or any file. The BE cookie is fetched from the WS1 login API using the stored login ID and password (endpoint in [architecture.md](architecture.md#phase-6--developer-testing-d18)).
- **Why:** User decision. Same secret-handling principle as D15.
- **Rejected options:**
  - Shared team credentials: the credentials are per person.
  - Storing them in config files: they could leak or be committed.

<a id="d21"></a>
### D21 — Local test environment: local Redis and RabbitMQ, dev PostgreSQL
- **Date:** 2026-10-09
- **Status:** Accepted; **amended by [D34](#d34)** (dev PostgreSQL credentials come from the repository's `.env`). How the local Redis and RabbitMQ are found or started (Homebrew or Docker) is set by [D54](#d54) (2026-10-15). **Amended by [D64](#d64) (2026-10-17):** migrations and seeders are started from this Mac with the repo's own `npm run migrate` / `npm run seed`, against the database its `.env` names (today the dev database), and only after the user's yes in chat, every run. **2026-10-17 ([D65](#d65)):** the runs go through `bash scripts/repo-run.sh <repo> migrate confirmed` / `seed confirmed`, which refuses without the word `confirmed`. **2026-10-17 ([D66](#d66), rule A23):** before any run, the user reviews the migration or seeder files, then gives a separate yes.
- **Context:** BE tests and local runs need PostgreSQL, Redis (also used by BullMQ) and RabbitMQ.
- **Decision:** **All Redis use** (BullMQ and anything else) points to a **local Redis**. **RabbitMQ** runs **locally**. **PostgreSQL** is the **dev database**, used directly.
- **Why:** User decision.
- **Rejected options:**
  - Tests cleaning up after themselves or running in rolled-back transactions on the dev DB (suggested by Claude): the user said this isn't a concern.
  - Using the dev Redis for caching: everything goes to the local Redis.

<a id="d22"></a>
### D22 — Testing on the dev environment happens after merge (Phase 9)
- **Date:** 2026-10-09
- **Status:** Accepted; **extended by [D37](#d37)** (dev-environment WS2 credentials per service in the Keychain). **Built 2026-10-18 ([D72](#d72)):** `flow-finish` runs the quick check (B) on dev (`--env dev`) once the user says the card is deployed.
- **Context:** Changes also need testing once they're deployed on the dev environment.
- **Decision:** It's part of Phase 9 (After merge), before the card moves to Ready for Test. It uses the dev-environment credentials from D20.
- **Why:** User decision.
- **Rejected options:** None considered.

<a id="d23"></a>
### D23 — Repositories in scope, each registered with `configure-repo`
- **Date:** 2026-10-09
- **Status:** Accepted; **extended by [D35](#d35)** (dedicated command to register any repo with the full set of details). **All 7 repos registered on 2026-10-14** in `config/repos/` ([D51](#d51)). **Not a fixed list** (user, 2026-10-14): more repos can be added at any time with `flow-configure-repo`.
- **Context:** The local `japfa` folder contains more repos than the agent should work on.
- **Decision:** In scope for now: `nodejs-ws1closio`, `nodejs-ws2closio`, `nodejs-ws2notification`, `nodejs-ws2pricingengine`, `nodejs-ws2targetsalesincentive`, `ws2jauth` (BE) and `closio-web-v2` (FE). Each repo is **registered with the repository setup command (`configure-repo`)**, which also records the repo's **test-case format** (framework, file layout, patterns, coverage rules).
- **Why:** User decision.
- **Rejected options (out of scope for now):** `sfa-service-gitlab` (Go), `sfa-dashboard-web` (Next.js + Cypress), `qa-testcraft`.

<a id="d24"></a>
### D24 — Playwright tests live outside the repo, in closio-agent's own workspace
- **Date:** 2026-10-09
- **Status:** Accepted **2026-10-17 ([D65](#d65)):** the Playwright tests are written and run by `flow-verify`, not by `flow-develop`. **Built 2026-10-18 ([D67](#d67)):** `e2e/` holds the shared project (package.json, config, login helper); each card's tests live in `runs/<CARD-KEY>/e2e/`; the setup is an item of `flow-configure-user`. **2026-10-18 ([D69](#d69)):** `e2e/fixtures.ts` also watches each test's API calls and switches API mocks on per run; `e2e/probe/` holds the API check run before a card's tests.
- **Context:** `closio-web-v2` has Vitest unit tests but no Playwright. The user wants Playwright used without it ever being pushed. Adding Playwright to the repo's `package.json` or `.gitignore` would itself change shared files that get pushed.
- **Decision:** The Playwright project (its own `package.json`, config and end-to-end tests) lives **outside the repo, in closio-agent's own workspace**, and tests the locally running `closio-web-v2` app over its local URL. The repo isn't touched. Vitest unit tests are still committed in the repo (D18).
- **Why:** User decision. No shared file changes, so nothing Playwright-related can be pushed by accident.
- **Rejected options:**
  - Adding Playwright to the repo for the whole team.
  - A folder inside the repo hidden with `.git/info/exclude` (local-only ignore): it works, but the files still sit in the repo folder and can be mixed up with repo changes.
  - Adding entries to the repo's `.gitignore`: that changes a shared file that gets pushed.

<a id="d25"></a>
### D25 — No committed tests for repos without a test suite
- **Date:** 2026-10-09
- **Status:** Accepted
- **Context:** `nodejs-ws1closio` and `ws2jauth` have no test suite (`npm test` only prints "no test specified").
- **Decision:** Phase 6 skips writing committed tests for these repos.
- **Why:** User decision.
- **Rejected options:**
  - Setting up a new test suite in those repos.

<a id="d26"></a>
### D26 — `story-implementation-workflow.md` is the baseline for the Phase 2–6 rules (with Express 5)
- **Date:** 2026-10-09
- **Status:** Accepted. **To be refined later** (user, 2026-10-14), when the Phase 2–6 rulesets are written. Each backend repo's registry file points to it; the web app has no rulesets yet ([D51](#d51)). **Changed by [D64](#d64) (2026-10-17):** the baseline now lives in closio-agent as `rulesets/story-implementation-workflow.md`, for every card (the web app follows its common practices), kept by the closio-agent builders and aligned with closio-agent's rules and decisions; the repo files no longer name it, and the copy in `japfa/backend/` isn't used any more. **2026-10-17:** the ruleset carries rules A20–A23 ([D66](#d66)).
- **Context:** `backend/story-implementation-workflow.md` (from the SCRUM-517 session) already describes exploration, planning, implementation order, test patterns, curl checks and MR checklists for these repos.
- **Decision:** Use it as the baseline when the Phase 2–6 rulesets are written. Correction: the repos use **Express 5** (`express ^5.1.0`), not Express 4 as the document says.
- **Why:** User decision. It reflects how the team already works on these repos.
- **Rejected options:**
  - Writing the rulesets from scratch.

<a id="d27"></a>
### D27 — VPN DNS: one resolver file for the whole `japfacomfeed.co.id` domain, added on connect and removed on disconnect
- **Date:** 2026-10-09
- **Status:** Accepted. **Built in F3 (2026-10-11)**, see "Built" below.
- **Context:** Besides GitLab, other internal hosts don't resolve on macOS over the VPN. Verified: the dev API `dev-closio-ws1-apiprivate.japfacomfeed.co.id`, which points to an internal AWS load balancer and is reachable over `ppp0`. The dev database and other dev hosts are probably the same. macOS ignores the DNS servers openfortivpn writes to `/etc/resolv.conf` (D14).
- **Decision:** The agent's VPN connect step writes `/etc/resolver/japfacomfeed.co.id` (nameservers `10.90.0.53`, `10.190.0.55`) once the tunnel is up, and removes it on disconnect. It uses the same `sudo` prompt as openfortivpn.
- **Why:** User decision. One file covers every internal host, so no per-host list to maintain.
- **Rejected options:**
  - One resolver file per internal host: the list keeps growing.
  - A permanent domain-wide file: while the VPN is off it would send lookups for the public VPN gateway `vpnwm.japfacomfeed.co.id` to unreachable internal DNS servers, so the VPN couldn't connect.
- **Design note:** if the VPN drops without a clean disconnect, the file can be left behind. The connect step must remove any stale file **before** connecting.
- **Built (F3, 2026-10-11):** connect removes a leftover file first, and also the old GitLab-only file `/etc/resolver/jcvs.japfacomfeed.co.id` (user, 2026-10-11), all in the same password dialog.

<a id="d28"></a>
### D28 — GitLab operations use the GitLab MCP server (set up during setup)
- **Date:** 2026-10-09
- **Status:** **Superseded by [D32](#d32)**: GitLab MCP removed entirely (2026-10-09). It had been amended by [D31](#d31). After a successful OAuth sign-in, the Japfa GitLab answered the MCP endpoint with 404 (see the D30 T4 result).
- **Context:** The agent must create MRs, assign them to the user, and do other GitLab operations. Two options were found in `backend/story-implementation-workflow.md`: the GitLab MCP server and the `glab` command line.
- **Decision:** Use the self-hosted **GitLab MCP server** at `https://jcvs.japfacomfeed.co.id/api/v4/mcp` (it answered HTTP 401 over the VPN, i.e. it exists and needs a login). Connecting it is a **setup step** for each user, signing in with their GitLab account (OAuth):
  - Claude Code: `claude mcp add -s user --transport http GitLab https://jcvs.japfacomfeed.co.id/api/v4/mcp`, then sign in via `/mcp`.
  - Codex: an `[mcp_servers.<name>]` entry with `url = "https://jcvs.japfacomfeed.co.id/api/v4/mcp"` in `~/.codex/config.toml`, then `codex mcp login <name>`. Codex's official docs say it supports streamable-HTTP MCP servers with OAuth. Not yet tested with this server.
- **Why:** User decision. Works the same way in Claude Code and Codex, and uses each user's own GitLab sign-in.
- **Rejected options:**
  - `glab` (GitLab command line): not chosen by the user.
- **Observed constraint:** Claude Code connects MCP servers when a session starts. In this project, every session started with the VPN down showed GitLab as failed: `ENOTFOUND`, and once a timeout. So **the VPN must be up before the Claude Code/Codex session starts**, or the GitLab server has to be reconnected (`/mcp`) after the VPN comes up.
- **Capabilities (GitLab docs, MCP server tools):** `save_merge_request` (aliases `create_merge_request` / `update_merge_request`) creates an MR (`title`, `source_branch`, `target_branch`) or updates one (with `merge_request_iid`), and accepts **`assignees` (usernames) or `assignee_ids`**. So the "assign MRs to the user" requirement is covered. `get_user` with `me: true` returns the signed-in user.
- **One-time sign-in:** each user must complete the GitLab OAuth sign-in once via `/mcp` → GitLab → Authenticate (Claude Code CLI 2.1.85 has no `claude mcp login`).

<a id="d29"></a>
### D29 — No GitLab access token in the per-user setup
- **Date:** 2026-10-09
- **Status:** **Superseded by [D32](#d32)** (the token is needed again for the REST API).
- **Context:** D15 planned a GitLab access token in the macOS Keychain for creating MRs. Since then, GitLab operations moved to the GitLab MCP server with each user's own OAuth sign-in (D28), and git already works with the user's saved credentials (`git ls-remote` over the VPN succeeded without prompting).
- **Decision:** Remove the GitLab access token from `configure-user` ([D15](#d15) amended).
- **Why:** User decision: drop it if it isn't required. Nothing in the current design uses it, and one less secret to store.
- **Rejected options:**
  - Keeping the token "just in case".
- **Revisit if:** checking the GitLab MCP server's tools shows something the agent needs (e.g. setting the MR assignee) isn't available there.

<a id="d30"></a>
### D30 — A connectivity custom agent runs at the start of each phase that needs the VPN or GitLab
- **Date:** 2026-10-09
- **Status:** Accepted. Details confirmed by the user on 2026-10-09; feasibility tests passed the same day. **Built and tested in F3 (2026-10-11)**: all 12 live tests passed in Claude Code and Codex. Limits added by [D47](#d47). **Amended by [D54](#d54) (2026-10-15):** it no longer runs in `flow-setup-repo`, which needs no VPN.
- **Context:** GitLab, the dev API and the dev DB are only reachable over the VPN (D14, D27). The GitLab MCP server only connects if the VPN is up when Claude Code/Codex starts, and Claude Code can't reconnect a failed server without the user typing `/mcp` (D28).
- **Decision:** A dedicated **custom agent (subagent)** runs at the **start of every phase that needs the VPN or GitLab**. It connects the VPN and checks that GitLab is reachable. (Originally it also checked the GitLab MCP server; that check was removed by [D32](#d32).) Where something can't be automated, it asks the user (manual intervention is acceptable); push and similar commands also involve the user.
- **Why:** User decision. It keeps connection handling in one place and runs only when a phase needs it.
- **Confirmed details (user, 2026-10-09):**
  - **Phases:** it runs at the start of **every phase from Phase 1 to Phase 9**. ~~It also ran within `setup-repo` in Phase 0~~, because `setup-repo` would clone the repos; cloning is now manual ([D53](#d53)), installing uses the public npm registry and the tests don't seem to need the dev servers, so **`flow-setup-repo` doesn't use it** ([D54](#d54), user 2026-10-15). If a repo's tests do need the dev database, the fix says `/flow-vpn connect`.
  - **Mac password:** entered in a **macOS password dialog** (`sudo -A` with an askpass helper). The password goes straight to `sudo` and never passes through the AI. Rejected: printing the command for the user to run in their own terminal.
  - **GitLab MCP not connected (Claude Code or Codex):** the agent **prompts the user to establish the connection and doesn't proceed** until the check passes.
- **Rejected options:**
  - A local stand-in program that re-announces GitLab's tools once the VPN is up (W2): more moving parts; unknown support in Codex.
  - The agent's own scripts calling the GitLab MCP server directly (W1): the scripts would have to handle the GitLab sign-in.
  - A launcher that connects the VPN before starting Claude Code/Codex (W3): the VPN would be on for the whole session instead of being checked per phase.
- **Draft steps (to be tested):**
  1. **Already connected?** If the VPN tunnel is up and GitLab answers, skip to step 4.
  2. **Connect:** remove any stale `/etc/resolver/japfacomfeed.co.id`, start openfortivpn (D14) in the background, open the SSO login URL in the browser, and wait for "Tunnel is up and running". The user enters their Mac password in a macOS dialog and completes the SSO login if needed.
  3. **DNS:** add `/etc/resolver/japfacomfeed.co.id` (D27), then check GitLab answers and `git ls-remote` works.
  4. ~~**GitLab MCP check**~~: removed by [D32](#d32), since GitLab MCP is no longer used.
  5. **Record** the result in the card's history (A1).
- **Feasibility test (2026-10-09):** tests T1–T5 (password dialog, background VPN, DNS file, GitLab MCP check, disconnect) approved and run; results below. **T6 (Codex GitLab MCP setup) deferred by the user** to a later step.
  - **T1 Password dialog: PASS.** An askpass helper shows a macOS dialog (`osascript … display dialog … with hidden answer`). `sudo -A` accepted the password. **Finding:** sudo remembers the password only within one command; each separate agent command shows the dialog again. **So the real agent must do all admin steps (remove stale DNS file → start openfortivpn → write DNS file) in one `sudo` call with one dialog.**
  - **T2 Background VPN: PASS.** `sudo -A -b openfortivpn … >> log` ran in the background and kept running after the command returned. The agent read the SSO URL from the log and opened it with `open`. The log reached "Tunnel is up and running"; `ppp0` is up.
  - **T3 DNS: PASS.** Wrote `/etc/resolver/japfacomfeed.co.id`. With it, GitLab → 10.253.31.33, dev API → 10.254.153.109, and the public gateway `vpnwm` still → 202.51.108.234. GitLab HTTP 200, dev API answers (HTTP 597 on `/`), `git ls-remote` on nodejs-ws1closio OK.
  - **T4 GitLab MCP check: BLOCKED (GitLab-side).**
    - The one-time **OAuth sign-in** had never been done. The user did it in an interactive `claude` session (`/mcp` → GitLab → Authenticate): "Authentication successful".
    - With the token, GitLab answers the MCP endpoint with **`404 Not Found`** (Claude Code debug log: `Streamable HTTP error: Error POSTing to endpoint: {"message":"404 Not Found"}`).
    - GitLab's docs list an instance prerequisite: an administrator must **"Allow access to the MCP server"** (Admin → Settings → Visibility and access controls). The tier was Premium before 19.2; Free from 19.2. Most likely cause: that setting is off, or the instance's version/tier doesn't include it. **Not confirmed**; needs the GitLab admin.
    - The prompt step learned something: the user first reconnected **Atlassian** by mistake, so the agent's message must name **GitLab** explicitly (or suggest `/mcp reconnect all`).
  - **T5 Disconnect: PASS.** One `sudo -A` call (one dialog) stopped openfortivpn (`pkill -INT`; log: "Terminated pppd", "Logged out") and removed `/etc/resolver/japfacomfeed.co.id`. `ppp0` is gone, and the public gateway `vpnwm` still resolves (202.51.108.234).
- **Amendment (D32, 2026-10-09):** GitLab MCP is removed entirely, so the step-4 MCP check is **removed**.
- **Built (F3, 2026-10-11):**
  - `scripts/vpn.sh connect | status | disconnect`. "Connected" means GitLab answers, through openfortivpn or another VPN client such as the FortiClient app; then nothing is done.
  - All admin steps run in **one** `sudo -A` call (one macOS password dialog, `scripts/password-dialog.sh`): `scripts/vpn-admin-steps.sh` removes a leftover DNS file and the old GitLab-only one, stops any stuck openfortivpn, starts openfortivpn in its own session (so it outlives the AI tool's command), waits for the tunnel, writes the DNS file. It checks every input. On a timeout (180 s) or a refused certificate it cleans up by itself.
  - The SSO page is opened as the user (`open`), only if the URL starts with the VPN gateway's address.
  - **The VPN stays on** until the user runs `flow-vpn disconnect` (user, 2026-10-11): disconnecting after every phase would mean a password dialog each time.
  - The agent: `flow-connectivity` (`.claude/agents/flow-connectivity.md` and `.codex/agents/flow-connectivity.toml`), a thin wrapper that runs `connect` and returns one result line. User command: `flow-vpn` (user, 2026-10-11).
  - In Codex, the command must be approved to run outside the sandbox (admin rights and network).
  - **Tested by the user on 2026-10-11, all passed:** connect (one dialog + SSO), stays on after the command ends, connect again (no dialog), disconnect, leftover DNS file cleaned up, cancelled dialog, SSO timeout cleanup, wrong certificate pin message, FortiClient already connected, `flow-vpn` in Claude Code and Codex, and the `flow-connectivity` agent in both tools.

<a id="d31"></a>
### D31 — MRs are created and assigned with git push options during the single push; GitLab MCP is added once it works
- **Date:** 2026-10-09
- **Status:** Accepted; **amended by [D32](#d32)** (the full description is set through the REST API; GitLab MCP is no longer used). **Built 2026-10-18 ([D70](#d70)):** `scripts/ship.sh push` (create, target, title, assign, labels); not yet seen on the Japfa GitLab: the user's first `/flow-push`.
- **Context:** The Japfa GitLab MCP server answers 404 after sign-in (D28, D30 T4), although it worked for reading MRs on 2026-10-02. On 2026-10-08, MRs were created with git push options. GitLab's push options include `merge_request.create`, `.target`, `.title`, `.description`, `.assign="<user>"`, `.label` and `.draft`.
- **Decision (option 3, recommended by Claude):**
  - In **Phase 7 (Ship)**, the single push per repo (G4) also **creates the MR and assigns it to the user**: `git push -o merge_request.create -o merge_request.target=<base branch> -o merge_request.title="…" -o merge_request.assign="<GitLab username>" -o merge_request.description="…"`.
  - Once the GitLab MCP server works again, use it for what push options can't do (e.g. a full multi-line description, reading MRs). The GitLab admin is to be asked about the 404.
- **Why:** User decision. It needs no MCP and no token, works the same in Claude Code and Codex, and fits the single-push rule.
- **Rejected options:**
  - (1) Waiting for MCP only: blocks MR creation until the GitLab admin fixes the 404.
  - (2) Push options plus MCP for the description, as a fixed split: replaced by option 3, which uses MCP once it's available.
  - REST API with a personal access token (used on 2026-10-08): needs a token, and that token ended up in plain text in a transcript.
- **Verified limit:** git refuses push-option values containing a newline (git 2.56.0, tested locally against a bare repo: `fatal: push options must not have new line characters`). **MR descriptions set at push time must be a single line.**
- **Amendment (user, 2026-10-09):** the GitLab MCP check in step 4 is **a warning only, not blocking**, because MRs are now created with push options (D31) and no phase currently needs MCP. If GitLab MCP is removed entirely (under discussion), the check goes too.

<a id="d32"></a>
### D32 — GitLab MCP removed; the full MR description is set through the GitLab REST API with a personal access token from the macOS Keychain
- **Date:** 2026-10-09
- **Status:** Accepted **Built 2026-10-18 ([D70](#d70)):** `scripts/gitlab-mr.sh` (find the MR, set the description and the reviewers; the token goes to curl on stdin); tested against a fake GitLab server, the real one with the first `/flow-push`.
- **Context:**
  - Push options can't carry a multi-line description: git refuses newlines (verified locally; the same error happened on 2026-10-08).
  - The user wants the full description and to **remove GitLab MCP entirely**. It returns 404 on the Japfa GitLab (D28).
  - On 2026-10-08, full multi-line descriptions were set with the REST API and a personal access token, but the token was written in plain text in the command.
- **Decision (option a):**
  - **Phase 7:** the single push per repo still **creates the MR and assigns it to the user** with push options (D31): create, target, title, assign.
  - **Labels and reviewers** (user, 2026-10-14): the repo file holds optional defaults; the user confirms or changes them when the MR is created; labels are optional ([D51](#d51)).
  - **Right after the push:** a script sets the **full multi-line description** through the **GitLab REST API**: `PUT /api/v4/projects/:id/merge_requests/:merge_request_iid` with `description`.
  - **Token:** the script reads the user's **personal access token from the macOS Keychain** at run time. It's never typed into the AI chat, written to a file, or put on a command line where it would show up in transcripts or the process list.
  - **GitLab MCP is removed entirely:** from the design, the setup and the connectivity agent's checks.
  - **`configure-user`:** the GitLab token is restored (D15 amended; D29 superseded).
- **Why:** User decision. Full markdown descriptions (headings, lists, tables), as on 2026-10-08, without depending on the GitLab MCP server, and without exposing the token.
- **Rejected options:**
  - (b) A one-line description using `<br>` HTML line breaks: no tables or markdown lists, and rendering untested.
  - (c) A short one-line description only.
  - Keeping GitLab MCP (D28): it returns 404 on the Japfa GitLab.
- **Token requirements:** a GitLab **personal access token** with the **`api`** scope (`read_api` can't modify MRs). It's per person, with an expiry date set by the user. Calls go to `jcvs.japfacomfeed.co.id`, so they need the VPN (D30).

<a id="d33"></a>
### D33 — Secrets in the macOS Keychain: one item per secret, named `closio-agent.<name>`
- **Date:** 2026-10-09
- **Status:** Accepted; amended by [D34](#d34) (shared `ws2-client-*` items removed; local values come from each repo's `.env`), **by [D37](#d37)** (per-repo **dev** WS2 items added) and **by [D51](#d51)** (optional per-repo `db-user`/`db-password` and extra keys). Since F4/F5 the items are added by `flow-configure-user` and `flow-configure-repo` through a heads-up and a hidden macOS box ([D15](#d15)); the terminal command below stays as a backup.
- **Context:** D15, D20 and D32 keep secrets (GitLab token, test logins, WS2 client credentials) in the macOS Keychain. A new team member needs exact, repeatable steps, and the agent's scripts need fixed names to read from.
- **Decision:**
  - Each secret is a **generic password** in the user's **login Keychain**: **account** = the Mac username (`$USER`), **service** = `closio-agent.<name>`.
  - Items: `gitlab-token`, `fe-login-id`, `fe-login-password`, `ws1-login-userid`, `ws1-login-password`. (Originally also `ws2-client-id/secret.local/.dev`; removed by D34.)
  - **Adding:** `security add-generic-password -U -a "$USER" -s "closio-agent.<name>" -l "<label>" -w`, with `-w` **last**, so `security` prompts for the value instead of taking it on the command line (Apple's own help text: "Use of the -p or -w options is insecure. Specify -w as the last option to be prompted.").
  - **Reading (scripts):** `security find-generic-password -a "$USER" -s "closio-agent.<name>" -w`. Items created with the `security` tool can be read by it without a macOS access prompt (default: "the application which creates an item is trusted to access its data").
  - Until `configure-user` exists, users add the items by hand following [setup-guide.md §5](setup-guide.md#5-store-your-secrets-in-the-macos-keychain).
- **Why:** a predictable prefix makes items easy to find, update and remove. One item per secret keeps each one separately replaceable (e.g. a token rotation).
- **Rejected options:**
  - One combined item holding all secrets (e.g. JSON): harder to update one value, and every read exposes all of them.
  - `-A` (any app can read without a prompt): Apple marks it "insecure, not recommended".
  - Secrets in `.env`/config files: could leak or be committed.

<a id="d34"></a>
### D34 — Service credentials (WS2 client ID/secret, dev PostgreSQL) come from each repo's `.env`, not the Keychain
- **Date:** 2026-10-09
- **Status:** Accepted **Clarified 2026-10-18 (user):** a WS2's "client ID and secret" are the **caller's**: each repo that calls a WS2 sends its own pair in `x-client-id` / `x-client-secret`, and the WS2 checks it against the callers in its `SERVICE_CREDENTIALS`. **So the pair is saved once under WS1** (`closio-agent.nodejs-ws1closio.ws1-client-id.dev` / `…ws1-client-secret.dev`: WS1's `WS1_AUTH_CLIENT_ID` / `WS1_AUTH_SECRET_KEY`, what WS1 sends to target sales and notifications per its `src/utils/axiosInstances.js`) and `api-call.sh` sends it on every direct WS2 call; a WS2 repo needs no keys of its own (user: "I have already added them in WS1. You need to just use them to send the things to WS2 API calls"). A pair saved under a WS2 repo (`ws2-client-*`, optional) is used instead for that WS2: the pricing engine, to which WS1 sends its `PRICING_ENGINE_*` pair. `INCENTIVE_S2S_*` in WS1 are inbound keys. A note, not a rule (user: "just a note"); some WS2 APIs are called by other services, then that caller's pair.
- **Context:** D20 and D33 planned to store WS2 client IDs/secrets in the Keychain. The user clarified:
  - **every service has its own** client ID/secret, already in that repo's `.env` file;
  - the **dev PostgreSQL** credentials are also in the repository's `.env`;
  - the **Closio web-app (FE) login and the WS1 login-API credentials are different**.
- **Decision:**
  - WS2 client IDs/secrets and dev PostgreSQL credentials are **used from each repository's `.env` directly**, and are **not** stored in the Keychain.
  - The Keychain keeps only personal secrets: `gitlab-token`, `fe-login-id`/`fe-login-password`, `ws1-login-userid`/`ws1-login-password` ([D33](#d33)), with FE and WS1 kept separate.
- **Why:** User decision. The values already live with each service. Duplicating them would mean two places to update.
- **Rejected options:**
  - One shared WS2 client ID/secret per environment in the Keychain: each service has its own.
  - Merging the FE and WS1 login items: they're different credentials.
- **Safeguard (agent rule A6, adopted for now on 2026-10-09):** agent scripts and the apps load `.env` themselves; the AI never reads or prints `.env` values into the conversation (anything shown there is sent to the AI provider).
- **Answered (user, 2026-10-09):** the repos' `.env` files hold **local credentials only**. The **dev-environment** WS2 credentials are stored per service in the Keychain ([D37](#d37)).

<a id="d35"></a>
### D35 — A dedicated command registers each repository with the full set of details
- **Date:** 2026-10-09
- **Status:** Accepted. **Built in F5 (2026-10-14)** as `flow-configure-repo`, tested by the user on 2026-10-15; the details and format are in [D51](#d51).
- **Context:** The 7 in-scope repos (D23) are listed in the docs for now, but the user wants every repo, current and future, **added through a dedicated command**, capturing the same full details documented for the current repos.
- **Decision:** The repository configuration command (`configure-repo`, name is a placeholder) is **the only way to add a repo** to closio-agent. The 7 current repos are registered through it once it's built, and any new repo the same way. It records, per repo:
  - name, local path, GitLab remote URL and project path;
  - type (FE/BE) and a short role note (e.g. "BFF", "RabbitMQ consumer");
  - base branch and branch-naming rule;
  - install, run and test commands; the test framework, test file layout and patterns; coverage rules and where they're enforced (e.g. husky hooks, `nyc`, Vitest thresholds); "no test suite" if applicable (D25);
  - which `.env` file to use, for dev PostgreSQL and service credentials ([D34](#d34));
  - local services needed (Redis, RabbitMQ) ([D21](#d21));
  - the rulesets to apply (baseline [D26](#d26)).
- **Why:** User decision. Every repo is described the same way, new repos need no doc edits by hand, and the agent reads one consistent registry.
- **Rejected options:**
  - Keeping the repo list only as hand-edited docs.

<a id="d36"></a>
### D36 — Everything lives in this project folder, which the team clones; the agent's memory (`runs/`) is shared through it
- **Date:** 2026-10-09
- **Status:** Accepted **2026-10-17 ([D61](#d61)):** run folders are committed only to their card's branch, without checking it out; git-ignored on `main`.
- **Context:** Claude proposed a per-user home folder `~/.closio-agent/` for the agent's memory, settings and Playwright project. The user wants **everything kept in this project folder**. It will be pushed to a git remote and cloned by the team, and the memory must be directly available to whoever clones it.
- **Decision:**
  - The skills, scripts, shared configuration, docs, build memory, the Playwright project (D24) and the **per-card run folders (`runs/<CARD-KEY>/`)** all live in this project folder.
  - Run folders are **committed and shared** through git, so a teammate who pulls can see, and continue, a card's history. **[D61](#d61) (2026-10-17):** every change to a run folder is committed and pushed right away, on a branch of closio-agent (one per card, proposed `runs/<CARD-KEY>`), never on `main`.
  - **Never-commit rule:** nothing in a run folder or any committed file may contain secrets or `.env` values (D33, D34, A6).
  - Per-user settings (e.g. GitLab username, local repo paths) can't be shared, so they go in the git-ignored `local/` folder (confirmed in [D39](#d39); built: `local/user-settings.sh` in F4, `local/repos/` in F5).
- **Why:** User decision. One place for everything; new joiners get the full context by cloning.
- **Rejected options:**
  - `~/.closio-agent/` per-user home folder (suggested by Claude): memory wouldn't travel with the clone.

<a id="d37"></a>
### D37 — Dev-environment WS2 client credentials are stored per service in the Keychain
- **Date:** 2026-10-09
- **Status:** Accepted **Clarified 2026-10-18 (user):** a WS2's "client ID and secret" are the **caller's**: each repo that calls a WS2 sends its own pair in `x-client-id` / `x-client-secret`, and the WS2 checks it against the callers in its `SERVICE_CREDENTIALS`. **So the pair is saved once under WS1** (`closio-agent.nodejs-ws1closio.ws1-client-id.dev` / `…ws1-client-secret.dev`: WS1's `WS1_AUTH_CLIENT_ID` / `WS1_AUTH_SECRET_KEY`, what WS1 sends to target sales and notifications per its `src/utils/axiosInstances.js`) and `api-call.sh` sends it on every direct WS2 call; a WS2 repo needs no keys of its own (user: "I have already added them in WS1. You need to just use them to send the things to WS2 API calls"). A pair saved under a WS2 repo (`ws2-client-*`, optional) is used instead for that WS2: the pricing engine, to which WS1 sends its `PRICING_ENGINE_*` pair. `INCENTIVE_S2S_*` in WS1 are inbound keys. A note, not a rule (user: "just a note"); some WS2 APIs are called by other services, then that caller's pair.
- **Context:** The repos' `.env` files hold **local** credentials only (D34), but Phase 9 tests on the dev environment (D22).
- **Extended by [D51](#d51) (2026-10-14):** each repo's registry file now lists which dev keys it needs, including optional dev database user and password and extra named keys, all named `closio-agent.<repo>.<key>.dev`.
- **Decision (option b):** for each WS2 service, the **dev** client ID and secret are personal Keychain items named `closio-agent.<repo>.ws2-client-id.dev` and `closio-agent.<repo>.ws2-client-secret.dev`, added the same way as other secrets (D33). Phase 9 can then test both through dev WS1 (login cookie) and directly against each WS2 service.
- **Why:** User decision. Allows direct WS2 checks on dev.
- **Rejected options:**
  - (a) Testing on dev only through WS1 with the login cookie (recommended by Claude as simpler): no direct WS2 checks.

<a id="d38"></a>
### D38 — Run folders are kept after the card is done, and any teammate can pick up a paused card
- **Date:** 2026-10-09
- **Status:** Accepted **2026-10-18 ([D72](#d72)):** the run branch `runs/<CARD-KEY>` is the finished card's record; it isn't merged into `main`.
- **Context:** The run-folder draft asked what happens after Ready for Test, and whether a card belongs to one person.
- **Decision:** A card's run folder is **kept** (not archived or deleted) after the card reaches Ready for Test. **For now, any teammate may pick up another person's paused card**, continuing from its shared run folder (D36).
- **Why:** User decision.
- **Rejected options:**
  - Archiving to `runs/_archive/` or deleting finished run folders.
  - Restricting a card to the person who started it.

<a id="d39"></a>
### D39 — Repository layout of closio-agent (foundation step F0)
- **Date:** 2026-10-09
- **Status:** Accepted (created 2026-10-09). Local-path handling **approved by the user on 2026-10-10**. First commit and push on 2026-10-11 (see below). Built since: `config/repos/<repo>.yaml` (F5); in `local/`: `user-settings.sh` (F4), `repos/` (F5), `vpn/` (the openfortivpn log, F3), `logs/` (setup and test output, F6), `memory/` (user memory, F6b, created on the first entry), `cards/` (the text of cards checked with `flow-check-card`, F7).
- **Context:** Everything lives in this project folder, which the team clones (D36). The user approved `git init` and creating the structure.
- **Decision:**
  - `git init` (branch `main`). **First commit and push on 2026-10-11** (user): remote **`https://github.com/manas-shurutech-04/closio_agent.git`** (private GitHub repo). Teammates clone it with `git clone https://github.com/manas-shurutech-04/closio_agent.git closio-agent`. Before the push, the chat transcript's WS1 login user ID was blanked out, like the GitLab token.
  - **Folder rename:** the project folder will be renamed from `AI Pipeline` to `closio-agent` (user agreed 2026-10-10). **The user will rename it themselves later** (2026-10-10). Note: Claude Code ties its session history and memory to the folder path.
  - Folders: `.agents/skills/`, `config/repos/`, `scripts/`, `e2e/`, `runs/` (each with a `.gitkeep`), plus the existing `docs/` and `build-memory/`, and a top-level `README.md`.
  - `.gitignore` excludes: `/local/` (personal settings and local repo paths), `.env` and `.env.*`, `*.pem`/`*.key`, Playwright dependencies and outputs under `e2e/`, `node_modules/`, `.DS_Store`, `*.log`.
  - `.claude/skills` (the link to `.agents/skills`, D8) is created in F1, where it gets tested.
- **Where each person's local repo paths are stored (approved):**
  - **Shared** facts per repo: `config/repos/<repo>.yaml` (committed).
  - **Personal** facts (workspace folder, and the path of each repo on that Mac): `local/` (git-ignored, never pushed), filled by `configure-user` and `configure-repo`.
  - **Default path:** `<workspace>/<repo>`. The person can point to an existing clone instead.
  - If a repo's local path is missing (e.g. right after cloning closio-agent), `doctor` reports it. ~~`setup-repo` clones it to the default path~~: **cloning is manual** ([D53](#d53)); the user clones it and sets the path with `flow-configure-repo <repo> path <folder>`.
- **Why:** Shared facts travel with the clone; personal paths never leak into the shared repo or break someone else's setup.
- **Rejected options:** a per-user `~/.closio-agent/` home (rejected in D36).

<a id="d40"></a>
### D40 — User-specific runtime context memory ("user memory")
- **Date:** 2026-10-10
- **Status:** Accepted (design approved by the user on 2026-10-10). Built as foundation step **F6b**, right after `setup-repo` (confirmed by the user on 2026-10-10). **Built on 2026-10-16** as `flow-memory` and `scripts/memory.sh`; the details are in [D56](#d56).
- **Context:** The project has build memory (for building the agent) and per-card memory (`runs/<CARD-KEY>/`, D36). There was **no memory that carries a user's preferences and corrections across cards and runs**.
- **Requirement (user, 2026-10-10):**
  - When people use closio-agent's workflows, they may want to **store changes or preferences for the current and future runs**.
  - It's an **additional memory**, **user-specific** and **maintained by each user**.
  - It's kept in this project folder.
  - It's used in **coding and in all the other phases**, to make the agent's work more precise to that user's description.
- **Rules:**
  - **A7 (user, 2026-10-10):** **every time any closio-agent command runs**, for any card and in any phase (setup commands included), the agent **must load and take into account the current user's memory**. **If memory is present, the agent's actions depend on it.** The command records in the card's history which memory entries it applied (entry IDs only).
  - **A8 (user, 2026-10-10):** **team rules always take priority over user memory.** That means the git rules G1–G4, the agent rules A1–A8, coverage and other repo rules, and the decisions in this document. When a memory entry conflicts with a team rule, the agent **points out the conflict and follows the team rule**.
- **How it differs from the other memories:**

  | Memory | Scope | Who maintains it | Where | Shared? |
  |---|---|---|---|---|
  | Build memory | Building closio-agent | Claude + the builder | `build-memory/` | ✅ committed |
  | Card memory | One Jira card's progress and context | The agent | `runs/<CARD-KEY>/` | ✅ committed |
  | **User memory** | **One user, across all cards and runs** | **That user**, with the agent's help | **`local/memory/`** | ❌ **local only** (git-ignored) |

- **Design (approved 2026-10-10):**
  - **Location (option b):** `local/memory/`, inside the git-ignored `local/` folder (D39). **Private, only on that person's Mac, never committed.** Because it's per machine, there's **no user-name folder**.
    - `local/memory/general.md`: applies everywhere (e.g. coding style, how they like plans written).
    - `local/memory/repos/<repo>.md`: applies only to that repo.
  - **Entries:** short items, each with a date, its scope (general / repo), the phases it applies to (or "all"), and the card it came from, if any.
  - **A dedicated memory command** (name is a placeholder: `memory`) to **add, edit, remove and list** entries. Entries get into memory in **both** ways:
    - (1) the user asks explicitly through the command;
    - (2) when the user corrects the agent during any phase, the agent **offers** to save it and **writes only after the user confirms**.
  - **Loading (A7):** at the start of every command, the agent loads `general.md` plus the files for the repos involved, and applies the relevant entries within the team rules (A8). With no memory yet, it carries on normally.
  - **An ever-growing memory that may not exist yet (user, 2026-10-10):** user memory grows over time as the user adds entries. It **may not exist at all**, even at the start of the very first card. So nothing is pre-created: `local/memory/` and its files are **created on the first saved entry**. Every command treats "no memory" as normal. `doctor` and setup do **not** report missing memory as a problem.
  - **Safety:** never stores secrets or `.env` values (A6, D33).
- **Consequence to note:** when a teammate picks up a paused card (D38), **their own** memory applies, not the original person's.
- **Why:** User decision. The agent gets more precise for each user over time, and private preferences stay on the user's machine.
- **Rejected options:**
  - (a) A committed `memory/users/<user>/` folder visible to the team: the user wants it private and local.
  - Per-user subfolders named by GitLab username: not needed, because the memory never leaves the machine.
  - Adding entries only through the command, or only through agent offers: both are required.

<a id="d41"></a>
### D41 — Node.js v22 for the whole project; run `nvm use v22` before starting Claude Code
- **Date:** 2026-10-10
- **Status:** Accepted. Claude Code install method agreed and done on 2026-10-10 (see the install note below). **Amended by [D52](#d52)** (2026-10-14): Node 22 stays for closio-agent itself and for Claude Code / Codex; each code repo runs on its own Node version.
- **Context:**
  - The Mac has several Node versions through nvm. The default is v18.20.8; v22.14.0 is installed.
  - All 7 repos in scope build on `node:22-alpine` in their Dockerfiles (checked 2026-10-10).
  - Claude Code's docs say its npm package needs Node.js 22 or later.
- **Decision:**
  - **Node v22 is used for the entire project**: Claude Code, closio-agent's scripts, the Playwright project, and installing, running and testing the code repos on the Mac.
  - **Rule A13 (user, 2026-10-14), changed the same day by [D52](#d52):** ~~all the code repos run under Node 22~~ → each repo runs on **its own** Node version. Original wording: all the code repos run under Node 22 (nvm). **Before running anything in a repo** (install, run, test, lint, migrate, seed), the agent checks `node -v` and, if it isn't v22, runs `nvm use v22` first, in the same shell command. Written into `AGENTS.md` (rule 6); each repo's registry file records `node_version: 22`.
  - **Rule A9:** always run `nvm use v22` in the terminal **before starting Claude Code**. Because the whole project uses v22, the same goes for Codex: the commands it runs (npm, tests, git hooks) use whichever Node is active.
- **Why:** User decision. It matches the Node version the repos ship with.
- **Rejected options:** None considered.
- **Note (checked 2026-10-09 and 2026-10-10):** `nvm use v22` on its own does **not** change which Claude Code runs. Today `claude` is the Homebrew install (2.1.85) whatever Node is active, and Node v22 has no working Claude Code inside it. The npm package's `claude` doesn't use Node when it runs. So how Claude Code gets installed under v22 had to be agreed.
- **Install (user, 2026-10-10):** Claude Code is installed **inside Node v22 with npm** (`npm install -g @anthropic-ai/claude-code`; Claude's docs say this package needs Node 22 or later), and the **Homebrew copy was removed**, so there is only one Claude Code. Done on this Mac: version 2.1.296 at `~/.nvm/versions/node/v22.14.0/bin/claude`. **Codex the same way** (user, 2026-10-10): `npm install -g @openai/codex` inside Node v22 (0.162.1), Homebrew copy removed. Steps in [setup-guide.md](setup-guide.md#install-claude-code-and-codex-inside-node-v22--verified). Rejected: upgrading the Homebrew copy (it doesn't follow Node v22, and two copies cause confusion).
- **Note (checked 2026-10-10):** on this Mac the shell's PATH lists the `bin` folder of every nvm Node version, so `claude` is found even without `nvm use v22`. But Node itself then stays at the default v18, so the commands the session runs would use the wrong Node. That's why A9 still matters.
- **Note:** the Claude desktop app doesn't start from a terminal, so nobody can type `nvm use v22` first there. The agent's scripts will have to switch Node themselves. **Done for the code repos in F6** (2026-10-16): `flow-setup-repo` switches to each repo's version itself ([D54](#d54)).
- **Finding (F1 test T3, 2026-10-10): Codex ignores `nvm use v22`.** Codex runs its commands through a **background service** (`codex app-server` daemon) that keeps running between sessions. On this Mac it was started at 12:48 with Node v18 first in its PATH, while the `codex` window itself had v22. So `$flow-doctor` reported v18 even after `nvm use v22`. **Fixed (user, 2026-10-10):** Codex was reinstalled **with npm inside Node v22** (`@openai/codex` 0.162.1), the Homebrew copy was removed, and the background service was restarted from a Node v22 terminal (`codex app-server daemon restart`). `$flow-doctor` in Codex then showed Node v22 ✅. Checked: the service now has Node v22 first in its PATH. Its separate updater process (running since 2026-10-09) still has v18, so if Codex ever falls back to v18 (e.g. after it updates itself), restart the service again. Not done: making Node 22 the Mac's default (`nvm alias default 22`), because it changes Node for every other project; kept as a fallback.

<a id="d42"></a>
### D42 — Claude Code and Codex are always started in the closio-agent folder; code repos are added as extra folders
- **Date:** 2026-10-10
- **Status:** Accepted. **Built:** `flow-configure-user`, `flow-configure-repo` and `flow-doctor` check that the session started in the closio-agent folder and stop with the fix if not (F2, F4, F5). **Extra folders decided in [D54](#d54) (2026-10-15):** `flow-setup-repo` adds each repo it sets up to Claude Code's personal `.claude/settings.local.json` (`permissions.additionalDirectories`) and shows Codex's start command with `--add-dir`. **Built in F6 (2026-10-16).**
- **Context:**
  - The agent's commands are project skills, and both tools only load them when the session starts in the folder that holds them (or a folder inside it).
  - The code repos live somewhere else on each Mac (`<workspace>/<repo>`, [D39](#d39)).
- **Decision (option a):**
  - **Rule A10:** people always start Claude Code or Codex **in the closio-agent folder**, never inside a code repo.
  - The agent adds the code repos a card needs as **extra folders**. Both tools support this: Codex 0.162.0 has `--add-dir` (checked), and Claude Code's docs mention `--add-dir`.
  - The agent finds its own files (`runs/`, `config/`, `scripts/`, `local/`) by plain relative paths.
  - This must be **stated clearly everywhere** (README, setup guide, architecture) and **strictly built into the setup commands** (user, 2026-10-10): they tell the user and check that the session started in the closio-agent folder.
- **Why:** User decision. The agent's files are always in one known place, and no stored path is needed.
- **Rejected options:**
  - (b) Linking the skills into each user's home folder (`~/.claude/skills`, `~/.agents/skills`) so commands work from any folder: every skill would need a stored path to find the closio-agent folder, and every user's home would get extra links.

<a id="d43"></a>
### D43 — Every command name starts with `flow-`
- **Date:** 2026-10-10
- **Status:** Accepted
- **Context:**
  - Planned names such as `doctor` and `memory` are already Claude Code commands. Claude Code's docs say a project command with the same name **replaces** the built-in one.
  - People's personal skills win over project skills, so a common name could be hidden by someone's own skill.
  - The user wants relevant names (rule R13) and no "closio" in command names.
- **Decision:** every closio-agent command starts with **`flow-`**: `/flow-start` in Claude Code, `$flow-start` in Codex. The first two commands are:
  - **`flow-ping`**: a tiny command that only answers "are the flow commands installed and loading in this tool?"
  - **`flow-doctor`**: checks your setup. F1 builds its first checks; F2 adds the rest.
- **Why:** User decision. Avoids clashes, and every name reads well (`flow-start`, `flow-push`, `flow-doctor`, `flow-memory`).
- **Rejected options:**
  - `closio-` (suggested by Claude): the user doesn't want "closio" in command names.
  - `card-`: reads badly for setup commands (`card-doctor`).
  - `dev-`: very common, likely to clash.
  - No prefix: clashes with built-in commands.

<a id="d44"></a>
### D44 — Commands only run when the user types them
- **Date:** 2026-10-10
- **Status:** Accepted. **Tested in F1 (2026-10-10):** Codex accepts the Claude-only line. The typed-only check (T4) first failed because the AI did the steps by hand; fixed by `AGENTS.md` ([D45](#d45)) and passed on re-test. **One exception decided in [D61](#d61) (2026-10-17):** `flow-develop` also starts when the user asks in plain words to develop a card with an approved plan. **Built 2026-10-17 (C3, [D65](#d65)):** `flow-develop` has `disable-model-invocation: false` and `allow_implicit_invocation: true`, with the guard in its own file and in `AGENTS.md` rule 1; every other command stays typed-only.
- **Context:** Both tools can start a command by themselves if they think it matches what the user said (e.g. "looks good, ship it" could start the push command). That is risky for commands that push code or move Jira cards.
- **Decision:** every command is set so **only the user can start it**, by typing it:
  - Claude Code: the line `disable-model-invocation: true` in the command's `SKILL.md`.
  - Codex: a small file `agents/openai.yaml` in the command's folder with `allow_implicit_invocation: false`.
  - This goes beyond D8's "shared fields only" ([D8](#d8) amended). If the F1 test shows Codex rejects the Claude-only line, this is revisited.
- **Why:** User decision. No command runs by surprise.
- **F1 test T4 (user, 2026-10-10):** asked "check my setup" without typing the command. **Claude Code** didn't start `flow-doctor`, but read the files and ran `scripts/doctor.sh` itself after the user approved the script. **Codex** (same session, right after `$flow-doctor`) ran the same steps again. So the setting stops the tool from starting the command by itself, but **it doesn't stop the AI from doing the same steps by hand**. The user's approval prompt was the last safety net. **Fix (user-approved, 2026-10-10):** a shared rules file `AGENTS.md` tells the AI not to do a command's steps unless the user typed it ([D45](#d45)). T4 is re-run in new sessions.
- **Rejected options:**
  - Letting the tools start commands by themselves (the default in both).

<a id="d45"></a>
### D45 — One shared rules file, `AGENTS.md`, for both tools
- **Date:** 2026-10-10
- **Status:** Accepted. **F1 T4 re-tested by the user on 2026-10-10 in new sessions: passed** in Claude Code and Codex (asked "check my setup", the AI pointed to the command instead of running the steps). Rules 5–11 added since: branch names ([D50](#d50)), repo Node versions ([D52](#d52)), manual cloning ([D53](#d53)), folder access ([D55](#d55)), user memory ([D56](#d56)), error codes from the code ([D59](#d59)), every command listed everywhere ([D60](#d60)). **2026-10-17:** rule 1 names its one plain-words exception, `flow-develop` ([D65](#d65)).
- **Context:**
  - In F1 test T4, both tools did `flow-doctor`'s steps by hand when the user asked "check my setup" without typing the command ([D44](#d44)).
  - Codex reads `AGENTS.md` from the project root at the start of every session. Claude Code reads `AGENTS.md` too, **as long as there is no `CLAUDE.md`** in the folder or above it (both checked in the official docs on 2026-10-10).
- **Decision:**
  - One file, `AGENTS.md`, in the closio-agent folder, read by both tools. It says:
    1. Flow commands run only when the user types them. If the user asks for something a command does, the AI tells them which command to type and stops. Only exception: the user clearly asks to run or test a specific script.
    2. Sessions start in this folder, after `nvm use v22` ([D41](#d41), [D42](#d42)).
    3. Never read or print secrets, `.env` values or Keychain values (A6).
    4. When anything fails, always tell the user the exact steps to fix it (rule A11, added 2026-10-10).
  - **Don't add a `CLAUDE.md`** to this folder. If one is ever needed, it must import `AGENTS.md` (`@AGENTS.md`), or Claude Code would stop reading `AGENTS.md`.
  - Changes to `AGENTS.md` take effect in new sessions.
- **Why:** User decision. One file for both tools, so the rules never drift apart.
- **Limit:** the docs say these files are instructions the AI follows, **not a hard lock**. The approval prompt before a script runs stays the last safety net. A hard lock for risky commands (e.g. push) is looked at when those are built.
- **Rejected options:**
  - Separate `CLAUDE.md` and `AGENTS.md` with the same text: two copies would drift apart.

<a id="d46"></a>
### D46 — Shared settings that aren't secret live in one file, `config/project-settings.sh`
- **Date:** 2026-10-10
- **Status:** Accepted Added 2026-10-17: `RULESET_FILE` (the ruleset every card follows, [D64](#d64)). Added 2026-10-17: `REPO_RUN_TIMEOUT` ([D65](#d65)).
- **Context:** `flow-doctor` (F2) and the coming VPN script (F3) need the same fixed values: Jira site and project key, GitLab address, VPN gateway, certificate pin and its expiry date, VPN DNS servers, Keychain item names. [D15](#d15) already said shared settings belong in the project config, not in each user's settings.
- **Decision:**
  - One committed file, `config/project-settings.sh`, holds these values. Scripts load it with `. config/project-settings.sh`.
  - It **never holds secrets** (those stay in the Keychain, [D33](#d33)).
  - Each value can be overridden from outside, which is how the scripts are tested without touching the Mac.
  - When a value changes (e.g. the VPN certificate is renewed), it's changed here once.
- **Why:** User decision. One place to change a value, so scripts can't disagree.
- **Added since:** `VPN_CONNECT_TIMEOUT` (F3, [D47](#d47)), `BRANCH_DESC_MAX_WORDS` (F5, [D50](#d50)), for `flow-setup-repo` (F6, [D54](#d54)): `SETUP_INSTALL_TIMEOUT`, `SETUP_TEST_TIMEOUT`, `DOCKER_START_TIMEOUT`, `SERVICE_START_TIMEOUT`, `LOCAL_REDIS_PORT`, `LOCAL_RABBITMQ_PORT`; for the card run folders (C1, [D61](#d61)): `RUN_BRANCH_PREFIX`, `GIT_REMOTE`.
- **Rejected options:**
  - Writing the values into every script: they would drift apart.
  - A `.env`-style file: those names are git-ignored and the AI must not read them (A6), which would be confusing for a file that is meant to be shared.

<a id="d47"></a>
### D47 — Each agent has its own limits, set in what it runs
- **Date:** 2026-10-12
- **Status:** Accepted **2026-10-18:** `flow-ac-checker` 40 steps, `flow-story-check` 15 steps; script limits `API_CALL_TIMEOUT` 30 s, `SERVER_START_TIMEOUT` 120 s, `E2E_TIMEOUT` 900 s ([D67](#d67)). **2026-10-18 ([D68](#d68)):** `flow-ac-checker` raised to 60 steps: on SCRUM-523 (5 ACs, 22 QMetry cases) it used all 40 (user: "okay this works").
- **Context:** The user asked for time limits on the separate agents, so one that doesn't finish doesn't hang the work. Checked in the official docs (2026-10-12): **Claude Code** agents can have a step limit (`maxTurns`) but no time limit; **Codex** agents have neither.
- **Decision:**
  - **Time limits live in the scripts each agent runs**, so they work the same in both tools. The values are in `config/project-settings.sh`.
  - **In Claude Code, each agent also gets a step limit** (`maxTurns`) as a safety net.
  - **Different agents get different limits** (user, 2026-10-12), decided when each agent is built and listed in [architecture.md](architecture.md#applies-across-all-phases).
  - When a limit is hit, the agent reports ❌ with what to do next (rule A11).
  - First agent: `flow-connectivity`: script limit 180 s for the SSO login (`VPN_CONNECT_TIMEOUT`), `maxTurns: 3`.
- **Limit:** for agents that mostly think (e.g. the AC-check and story-verification agents), a script can't limit their time; only Claude Code's step limit applies. Codex has nothing for them.
- **Why:** User decision. It's the only approach that works in both tools.
- **Rejected options:**
  - A time limit on the agent itself: neither tool supports it.

<a id="d48"></a>
### D48 — One GitLab token for everything, including the review agent
- **Date:** 2026-10-12
- **Status:** Accepted
- **Context:** The user asked whether the review agent and the other agents should have separate GitLab tokens. GitLab tokens come in two strengths: `api` (read and change) and `read_api` (read only).
- **Decision:** keep **one** personal token (`closio-agent.gitlab-token`, scope `api`, [D32](#d32)) for all agents.
- **Why:** User decision. The review agent will also comment on MRs when needed, so it needs `api` anyway. A second token would then add setup work without limiting anything.
- **Rejected options:**
  - A separate read-only (`read_api`) token for the review agent: only useful if it never writes.

<a id="d49"></a>
### D49 — Claude Code runs our own setup scripts without asking, through a shared project settings file
- **Date:** 2026-10-13
- **Status:** Accepted
- **Context:** During `/flow-configure-user` the user had to come back to the Claude window and approve the script after every secret. They don't want auto mode.
- **Decision:**
  - `flow-configure-user` asks for **all missing secrets in one script run** (`configure-user.sh secrets`), so there's one approval instead of five. This helps in Codex too.
  - A committed project settings file, **`.claude/settings.json`**, pre-approves only our own script calls that either just read or ask the user themselves through a macOS dialog:
    - `configure-user.sh`: `show`, `check-folder`, `secrets`, `secret <item>`, `gitlab-username-from-token`, and `set` for `jira-account-id`, `gitlab-username`, `workspace-dir`, `ai-tools`, `vpn-username` (these only write the private `local/` settings file)
    - `doctor.sh` (only reads)
    - `vpn.sh status`, `connect`, `disconnect` (connect and disconnect still need the Mac password in the macOS dialog)
    - `wait-seconds.sh` (waits 1–30 s; used while the Jira connector loads; added 2026-10-13)
    - `configure-repo.sh` (all its steps), `branch-name.sh` (make, check), and writing files in `config/repos/` (`Edit(/config/repos/**)`) (added 2026-10-14, F5)
    - `setup-repo.sh check-folder`, `list` and `run *` (added 2026-10-16, F6, [D54](#d54)). The setup run was first left to ask once; the user asked the same day for no prompt there. It installs the repo's packages (their install scripts run) and runs the repo's tests, which are the team's own repos
  - **Still asks:** changing the global git name or email (`set git-name`, `set git-email`) and every other command. **Changed by [D57](#d57) (2026-10-16):** every script the commands run is now pre-approved, git name and email included, in Claude Code and in Codex.
  - The commands must run the scripts exactly as written (`bash scripts/…`, no `cd`, nothing joined with `&&`), or the rules don't match.
  - Checked in Claude Code's docs (2026-10-13): a rule like `Bash(safe-cmd *)` doesn't approve `safe-cmd && other-cmd`, because each part of a joined command must match a rule on its own. Project allow rules only apply after the user trusts the folder.
- **Why:** User decision. Fewer interruptions without giving the AI a free hand: only our own scripts, and only the safe parts.
- **Rejected options:**
  - Auto mode: the user doesn't want it.
  - `allowed-tools` inside the command file: Claude Code clears that permission when the user sends their next message, and `flow-configure-user` asks questions in between, so the prompts would come back.
- **Not covered:** Codex's own way to pre-approve commands hasn't been checked yet. **Done in [D57](#d57)** (Codex rules file).

<a id="d50"></a>
### D50 — One strict branch-naming rule for every repo
- **Date:** 2026-10-14
- **Status:** Accepted
- **Context:** The existing branches don't follow one pattern (`SCRUM-101`, `SCRUM-126/add-filter-status`, `SCRUM-271-create-db-schema-…`, `scrum-512`). The user asked for a standard, kept as a strict rule, with a word limit on the description.
- **Decision (rule A12):**
  - Every branch the agent creates, in every repo, is named **`SCRUM-<number>/<short-description>`**, e.g. `SCRUM-519/add-filter-status`.
  - The card key exactly as in Jira; the description is lowercase words joined by `-`, only a-z and 0-9, **at most 5 words** (`BRANCH_DESC_MAX_WORDS` in `config/project-settings.sh`).
  - **The same branch name in every repo** the card touches.
  - It's one rule for all repos, **not** a per-repo setting.
  - `scripts/branch-name.sh make <CARD-KEY> "<title>"` builds a name from the card title (filler words like "the", "to" are dropped); `check <name>` says whether a name follows the rule and how to fix it.
  - Written into `AGENTS.md` (rule 5), so both tools always follow it.
- **Why:** User decision. Most existing branches already start with `SCRUM-<number>`, and the slash form keeps one card's branches together. If the Jira–GitLab link is on, Jira can also show branches containing the card key (not checked for Japfa).
- **Rejected options:**
  - A rule per repo: one rule is simpler and was asked to be strict.
  - A character limit instead of words: the user asked for a word limit.

<a id="d51"></a>
### D51 — Repo registry: flat YAML files, detected values confirmed by the user, per-repo dev keys
- **Date:** 2026-10-14
- **Status:** Accepted. Built in F5; tested by the user on 2026-10-15. **Changed by [D64](#d64) (2026-10-17):** the `rulesets` field is removed from the repo files and from what `flow-configure-repo` writes; the ruleset comes from closio-agent itself, by the repo's type. **2026-10-18 ([D70](#d70)):** `flow-push` asks the user to confirm or change the labels and reviewers each time; reviewers are set through the API. **2026-10-18 ([D72](#d72)):** new field `dev_base_url` (the repo on dev), asked by `flow-setup-repo`, saved in the shared repo file.
- **Context:** [D35](#d35) made one command the only way to add a repo; [D39](#d39) split shared and personal facts. The user asked for more details per repo, and for detected values to be only suggestions.
- **Decision:**
  - **Shared facts** in `config/repos/<repo>.yaml` (committed, no secrets), one `key: value` per line, lists comma-separated: name, GitLab URL and path, FE/BE, role, base branch (can differ per repo), install/dev/start commands, port, health URL, check commands (lint, circular), test command, framework, layout, coverage command, rules and where they're enforced, migration tool, folders, name patterns and commands, seed commands, queues, local services (Redis, RabbitMQ, **BullMQ**), the repos it calls, `.env` file **name**, dev keys (required and optional), optional dev database host/port/name/schema, MR target branch, labels and reviewers, rulesets (baseline [D26](#d26), **to be refined later**; FE: none yet), date registered.
  - **Personal facts** in `local/repos/<repo>.yaml` (git-ignored): where the clone is on this Mac, or "not cloned yet".
  - **Detection:** `scripts/configure-repo.sh detect` reads the clone (git remote, `package.json`, `.sequelizerc`, husky hooks, coverage config, the code for queues and health routes, and only the **names** of variables in `.env.example`; never what's inside `.env`). Everything it finds is a **suggestion**; the user confirms or corrects each value before the file is saved.
  - **Migrations and seeders follow the existing pattern** (user, 2026-10-14): Sequelize CLI, `src/migrations` and `src/seeders` (from `.sequelizerc`), names `YYYYMMDDHHMMSS-<short-description>.js` (always `-`, never `_`), seeders `YYYYMMDDHHMMSS-seed-<name>.js`, the repo's `migrate`/`seed` scripts. No new pattern; the user is asked only whether a repo differs.
  - **Dev keys per repo** (Keychain, `closio-agent.<repo>.<key>.dev`): `ws2-client-id`, `ws2-client-secret` for WS2 services ([D37](#d37)); **optional** `db-user`, `db-password` for repos with their own database (user, 2026-10-14), to check migrations on dev and write QA steps; and **extra named keys** when needed (e.g. a partner API key). Asked through the same heads-up and hidden box as `flow-configure-user`. WS1 uses the login cookie instead ([D20](#d20)).
  - `validate` checks the format, required fields, that no token or password is written in, and that the base and MR branches exist.
  - **Any kind of repo can be added later** (user, 2026-10-14): `detect` records `language` (node, go or other). Node repos get the most suggestions; Go repos get Go ones (`go mod download`, `go vet ./...`, `go test ./...`); other repos are added with the user's answers. `node_version` is required only for Node repos. A Node repo built for another Node version (e.g. `sfa-dashboard-web` uses `node:18`) keeps that version ([D52](#d52)); the check only warns if nvm doesn't have it installed.
  - **Changing a clone's path:** `/flow-configure-repo <repo> path <new path>`; a clone of another GitLab project is refused and the old path is kept.
  - **Missing dev keys show ⚠️, not ❌** (user, 2026-10-14), in `flow-doctor` and `flow-configure-repo`: they're only needed to test a repo on dev, so they don't block anything.
  - **MR labels and reviewers are optional defaults** (user, 2026-10-14): stored in the repo file (`none` until set), and **finalised each time an MR is created** (Phase 7): the agent shows the defaults and the user confirms or changes them. Labels are optional.
  - **`node_version`** per repo (from its Dockerfile; all 7 are `node:22`). Every repo runs on Node 22 (rule A13, [D41](#d41)).
  - **Every repo must have a health URL** (user, 2026-10-14). `detect` reads it from the repo's own docker-compose health check, then from the routes; all 6 backend repos use `/api/v1/health-checker` (ws2closio also has `/api/v1/health-checker/external`). The web app has no health endpoint, so its dev server's start page `/` is used. `validate` refuses `none`.
- **Why:** User decision. Easy for people, the AI and the scripts to read; suggestions save typing without guessing wrong.
- **Rejected options:**
  - Nested YAML: harder for the shell scripts to read without extra tools.
  - Saving detected values without asking: some can't be detected (base branch, port), and some guesses can be wrong.

<a id="d52"></a>
### D52 — Each code repo runs on its own Node version; missing versions are installed with nvm
- **Date:** 2026-10-14
- **Status:** Accepted. Changes rule A13 (first written the same day as "every repo runs on Node 22").
- **Context:** All 7 current repos are built on `node:22`, but `sfa-dashboard-web` (a repo that may be added later) is built on `node:18`. Forcing Node 22 on it could break it.
- **Decision (rule A13, new wording):**
  - **Every code repo runs on the Node version it is built for**: `node_version` in `config/repos/<repo>.yaml`, read from the repo's Dockerfile (or `.nvmrc`) when it's registered.
  - Before running anything in a repo (install, run, test, lint, migrate, seed), the agent switches to that version in the same shell command: `nvm use <version>`.
  - **If nvm doesn't have that version, it is installed** (`nvm install <version>`). `flow-doctor` and `flow-configure-repo` warn (⚠️) with that command; `flow-setup-repo` installs it (built 2026-10-16, [D54](#d54)).
  - **closio-agent itself, Claude Code and Codex stay on Node 22** (rule A9, [D41](#d41)).
  - Written into `AGENTS.md` (rule 6).
- **Why:** User decision. A repo must run on the Node version it's built and deployed with.
- **Rejected options:**
  - Node 22 for every repo (the first wording of A13): could break repos built on another version.

<a id="d53"></a>
### D53 — Cloning a repo stays a manual step
- **Date:** 2026-10-14
- **Status:** Accepted
- **Context:** The plan was for `flow-setup-repo` (F6) to clone repos that aren't on the Mac yet ([D39](#d39)), and Claude suggested also registering a repo straight from its GitLab address.
- **Decision:**
  - **The user always clones repos by hand** (on the VPN: `git clone <GitLab address> <folder>`). The agent never clones.
  - The agent tells the user the exact `git clone` command (from the repo's registered GitLab address) and, afterwards, `flow-configure-repo <repo> path <folder>`.
  - `flow-setup-repo` (F6) works on clones that already exist: install, local services, tests.
  - Registering a new repo still starts from a local clone.
  - Written into `AGENTS.md` (rule 7).
- **Why:** User decision.
- **Rejected options:**
  - `flow-setup-repo` cloning missing repos (the earlier plan, D39).
  - Registering a repo from its GitLab address with an automatic clone (suggested by Claude).

<a id="d54"></a>
### D54 — How `flow-setup-repo` (F6) prepares a repo
- **Date:** 2026-10-15
- **Status:** Accepted (user's answers to the F6 draft, 2026-10-15 and 2026-10-16). **Built 2026-10-16** after the user's yes to the final draft (incl. the `.env` help steps, opening the `.env` in the editor, and quitting Docker again). My tests passed; **the user's tests passed on 2026-10-16** (all repos set up; the Claude desktop app picked up the repo folders from `.claude/settings.local.json`). Amends [D30](#d30), settles the open part of [D42](#d42), adds to [D21](#d21). **2026-10-18 ([D72](#d72)):** `flow-setup-repo` also asks for each repo's dev address when it's missing.
- **Context:** F6 gets a registered repo ready to work on, on a clone the user made ([D53](#d53)). The checks on 2026-10-15 found: Homebrew Redis 7.2.7 and RabbitMQ 4.0.7 already running on the first Mac, Docker installed but not running; every repo installs from the public npm registry; the backend tests use stubs; the web app's `npm test` stays in watch mode in a terminal; the web app has `.env.development` but no `.env`.
- **Decision:**
  - **Usage:** `/flow-setup-repo` (each repo's setup state), `/flow-setup-repo <repo>` (one repo), `/flow-setup-repo all` (every repo cloned on this Mac, one after another).
  - **No VPN step:** the connectivity agent doesn't run in `flow-setup-repo` ([D30](#d30) amended; agent rule A5).
  - **Branches stay with the card phases** (user, 2026-10-16): `flow-setup-repo` never switches branches, pulls, stashes or changes tracked files. The agent does those in the card phases: Phase 1 pulls the base branch and creates the card's branch, Phase 3 changes the code, Phase 7 does stash → rebase → stash pop → atomic commits → one push (G1–G4).
  - **Node:** the script switches to the repo's `node_version` itself and installs it with nvm if missing ([D52](#d52)), so it also works in the Claude desktop app.
  - **Env file:** checked by name only; if missing, the user is told to get it from the team. Never created or read by the AI (A6).
  - **`.env` points to this Mac?** The script reads `REDIS_HOST` / `RABBITMQ_URL` from the repo's `.env` itself and says only "points to this Mac" or "points somewhere else", never a value. The user changes the values themselves. **With step-by-step help** (user, 2026-10-16): when something doesn't match, the setup shows which file to open, the exact lines to set for the local copy in use, and to run the setup again (details in the final draft, waiting on approval).
  - **Missing variables** (user, 2026-10-16): the script compares the variable **names** in the repo's env file with `.env.example` (or `.env.sample`), never the values. Missing names → ⚠️, the file opens in the editor, and the lines to add are listed (the user fills in the values). Found after `nodejs-ws2closio`'s tests stopped on a missing `SERVICE_CREDENTIALS`.
  - **Install only when needed:** no `node_modules`, or `package-lock.json` changed since the last install. `/flow-setup-repo <repo> install` forces it.
  - **Local Redis and RabbitMQ** (user's rules, 2026-10-15 and 2026-10-16), for each service the repo needs:
    - **Check both before choosing:** a **Homebrew** copy (installed with Homebrew) and a **Docker** copy (a container made from the official `redis` or `rabbitmq` image). If Docker Desktop is installed but not running, the setup starts it so it can look.
    - **Only one copy:** use it and tell the user.
    - **Both:** ask the user which to use, once (the choice is saved in `local/user-settings.sh`; `/flow-setup-repo <repo> services` asks again). If the other copy is running, the setup **stops it by itself** and says so (`brew services stop …` or `docker stop …`; no password needed). No other user step.
    - **None:** suggest Docker (one shared file in closio-agent, same versions for everyone), or Homebrew if Docker isn't installed. Install or start only after the user's yes.
    - A stopped copy is started only when it's the one being used.
    - Versions: Redis 7 and RabbitMQ 4 (the dev servers' versions aren't known; BullMQ needs Redis 6.2 or newer).
  - **Tests once at setup:** the repo's test command, not the coverage check (that's Phase 6); time limit 15 minutes (a shared setting); full output in a private log in `local/logs/`; the AI shows a short summary. Skipped for repos without a test suite ([D25](#d25)).
  - **Folder access ([D42](#d42)):** Claude Code: the repo's folder is added to the personal `.claude/settings.local.json` (`permissions.additionalDirectories`; file access only, the repo's own Claude files don't load). Codex: the setup shows the start command `codex --add-dir <repo paths>`.
  - **Approval prompts ([D49](#d49)):** in Claude Code the whole command is pre-approved, the setup run included (user, 2026-10-16: "dont ask the user permission here"; first decided as "only the status list"). In Codex the user still approves it outside the sandbox.
  - **Web app repo file:** test command `npm test -- --run` (one run, never watch mode) and env file `.env.development` (changed 2026-10-15).
- **Why:** User decisions.
- **Rejected options:**
  - Running the connectivity agent in `flow-setup-repo` (the earlier D30 plan).
  - Always running `npm ci` (slower; reinstalls every time).
  - Running the coverage check at setup, or no tests at setup.
  - Start commands for Claude Code, or typing `/add-dir` by hand.
  - Always starting our own Docker copies of Redis and RabbitMQ (suggested option c), or only using whatever already answers (Claude's first suggestion, before the user's rule).
  - Pre-approving only the status list, so the setup run asks once (chosen first on 2026-10-15, replaced on 2026-10-16).
  - Asking the user before stopping the other copy of Redis or RabbitMQ (user: no user step there).
  - The setup switching to the base branch and pulling it (option b, 2026-10-16).
- **Built (F6, 2026-10-16):** `scripts/setup-repo.sh` (`check-folder`, `list`, `run <repo|all> [install|services]`) and the `flow-setup-repo` command.
  - Choices between two copies are asked in a **macOS dialog** (closed or unanswered after 5 minutes = no choice), so the setup stays one script run with one approval.
  - Docker copy = a container whose image is the official `redis` / `rabbitmq` one (any tag). Docker Desktop is started with `open -g -a Docker` (up to 90 s) only to look, and quit again at the end if no service uses it.
  - Stopping the other copy: `docker stop <container>` or `brew services stop <name>` (no password). Starting: `brew services start` / `docker start`, or `docker compose -f config/local-services.yml up -d <service>` for a new Docker copy (`redis:7-alpine`, `rabbitmq:4-management`, ports bound to 127.0.0.1).
  - The saved choices are `LOCAL_REDIS_FROM` / `LOCAL_RABBITMQ_FROM` in `local/user-settings.sh`; `flow-configure-user` keeps them when it rewrites that file. A choice is saved only when both copies exist (so a later second copy still triggers the question).
  - `.env` check: the script parses the lines itself (never `source`), checks host, port, TLS, and whether what the file points to answers (Redis `PING`, RabbitMQ port), and on a mismatch opens the file with `open -t` and prints the lines to set. Values are never printed or logged.
  - Installing and tests run in the repo folder on the repo's Node version, in their own process group with a time limit (install 15 min, tests 15 min); output goes to `local/logs/setup-<repo>.log`.
  - Claude Code folder access: `jq` adds the path to `permissions.additionalDirectories` in `.claude/settings.local.json`, keeping everything else; a broken file is left untouched (❌ with the fix).
  - `flow-doctor`: new "Repo setup" section; Docker is no longer ❌ when missing unless you chose Docker.
  - Added 2026-10-16: the `.env` names check (above), and the folder-access check in the command file (rule A15, [D55](#d55)). The env file opens at most once per repo.
  - Fixed 2026-10-16: `docker info` can hang while Docker Desktop is starting or stuck (seen on the first Mac), so `flow-setup-repo` and `flow-doctor` give it 10 seconds; `flow-doctor` then shows ⚠️ "Docker Desktop doesn't answer".

<a id="d55"></a>
### D55 — Ask for folder access before working in a code repo
- **Date:** 2026-10-16
- **Status:** Accepted. Built into `flow-setup-repo` (its command file) and `AGENTS.md` rule 8; the card phases will follow it too.
- **Context:** `flow-setup-repo` gives Claude Code access to each repo folder through `.claude/settings.local.json`, and shows Codex's start command with `--add-dir` ([D42](#d42), [D54](#d54)). On 2026-10-16 the Claude desktop app picked the folders up by itself. But a session can still lack access, e.g. Codex started without `--add-dir`, or a setting that hasn't been picked up yet.
- **Decision (rule A15, user 2026-10-16: "if the access is not there for the folders then you need to ask the user about the access and then move forward"):**
  - Before working in a code repo, the AI checks that this session can use the repo's folder (it's one of the session's folders, or reading a file in it works).
  - If it can't, it **stops and asks the user to give access**, with the exact way: Claude Code: `/add-dir <folder>`, or a new session; Codex: start again with `codex --add-dir <folder>`, or approve Codex's request.
  - It goes on only after the user has given access.
  - Written into `AGENTS.md` (rule 8), so both tools follow it in every session.
- **Why:** User decision. The agent never works around missing access, and the user always knows why it stopped.
- **Rejected options:** None considered.

<a id="d56"></a>
### D56 — User memory is built as `flow-memory`, and every command loads it first
- **Date:** 2026-10-16
- **Status:** Accepted (user's answers to the F6b draft, 2026-10-16). Built in F6b on 2026-10-16. **Tested by the user on 2026-10-16.** Builds [D40](#d40).
- **Context:** [D40](#d40) approved a private, local user memory with a dedicated command, agent-offered saves, rule A7 (load it in every command) and A8 (team rules win). The user asked that the loading script "runs before every command without a miss".
- **Decision:**
  - **Command `flow-memory`** (list, add, add for one repo, edit, change phases, remove). All changes go through `scripts/memory.sh`, which keeps the format and refuses anything that looks like a secret.
  - **Files:** `local/memory/general.md` and `local/memory/repos/<repo>.md`, created on the first entry. One entry per line: `- [M3] 2026-10-16 · phases: plan, develop · from: SCRUM-519 · <text>`. IDs `M1`, `M2`… are unique across the files.
  - **Phases:** `all`, or some of `setup`, `pick-up`, `plan`, `develop`, `review`, `ac-check`, `testing`, `ship`, `mr`, `after-merge`. The setup commands use `setup`; `flow-check-card` uses `pick-up`.
  - **Loading, never skipped:** every command's step 1 holds `!`bash scripts/memory.sh for setup all``. **Claude Code runs it by itself when the command loads** (its "dynamic context injection": before the command reaches the AI, never prompts, checked against the permission rules). Codex has no such feature, so the same step tells the AI to run it first, and `AGENTS.md` rule 9 repeats it. The output lists general entries and every repo's entries (labelled), and the AI applies the repo ones only for the repos the command works on (so no arguments are needed in the command line, which Claude Code doesn't document for this feature). The AI says in one line which entries it used.
  - **Team rules win (A8):** when an entry conflicts, the AI says so and follows the team rule. When a new entry goes against a team rule, `flow-memory` warns and saves it only if the user still wants it.
  - **Offered saves:** `AGENTS.md` rule 9: when the user corrects the AI during a flow command, it offers once to save it, and saves only after a clear yes.
  - **Clearing** (user, 2026-10-16): `/flow-memory clear` (everything) or `/flow-memory clear <repo>`: the AI shows what would be removed (`memory.sh clear-preview`), asks "Remove these N entries? This can't be undone.", and only after a yes runs `memory.sh clear <all|repo> confirmed` (without `confirmed` the script refuses). The files are deleted; an empty memory is normal.
  - **Hand edits allowed:** lines that aren't in the format are shown as ⚠️ (in the memory step, `/flow-memory` and `flow-doctor`) and ignored.
  - **`flow-doctor`:** one ✅ line with the entry count, or "none yet (that's normal)"; ⚠️ only for lines in the wrong format.
  - **The memory step never fails** (fixed 2026-10-16, after the user's first `/flow-memory` stopped with "Shell command failed"): the script read the memory files with a loop that broke on the space in the folder name (`AI Pipeline`) and ended with an error, and Claude Code stops the whole command when this step fails. Now the files are read safely, and `memory.sh for …` always ends without an error: any problem is shown as a ⚠️ line and the command goes on.
- **Why:** User decisions. The memory step can't be forgotten in Claude Code, and the same commands still work in Codex.
- **Rejected options:**
  - Each command reading `local/memory/general.md` itself (the first version): the AI could skip it, and it ignored repo memory.
  - Refusing an entry that goes against a team rule (option b): the user chose a warning instead.
  - A Claude Code hook (`UserPromptExpansion`) for the loading: it works too, but the line inside each command travels with the command and needs no extra settings.

<a id="d57"></a>
### D57 — Every script the flow commands run is pre-approved, in Claude Code and in Codex
- **Date:** 2026-10-16
- **Status:** Accepted. Changes [D49](#d49). **Extended 2026-10-17:** `card-check.sh`, the `local/cards/` card files and the read-only Jira tools (see the decision). **[D61](#d61):** the Jira tools that move a card and set its assignee (`transitionJiraIssue`, `editJiraIssue`, plus the read-only `executeRead`) are pre-approved too, and so are `run.sh`, `card-branch.sh` and writing `runs/**` (built 2026-10-17). **2026-10-17:** the two `Write(/local/cards/**)` and `Write(/runs/**)` lines were removed from `.claude/settings.json`: Claude Code ignores `Write` rules for files (it warned at every start) and the `Edit` rules next to them already cover writing new files. **2026-10-17:** `repo-run.sh` pre-approved too ([D65](#d65)). **2026-10-18:** `api-call.sh`, `api-check.sh`, `db-run.sh`, `e2e.sh`, `qmetry-import.sh` ([D67](#d67)). **2026-10-18:** `ship.sh`, `gitlab-mr.sh` and the Atlassian comment tool `addOrEditJiraIssueComment` ([D70](#d70)).
- **Context:** [D49](#d49) pre-approved only the safe parts of our scripts in Claude Code (not the git name/email change), and Codex's way wasn't checked. The user: "all the scripts written in the commands should run automatically without user permission".
- **Decision:**
  - **Claude Code:** `.claude/settings.json` allows every action of each script the commands use: `Bash(bash scripts/<script>.sh *)` for `configure-user.sh`, `configure-repo.sh`, `setup-repo.sh`, `memory.sh`, `doctor.sh`, `vpn.sh`, `wait-seconds.sh`, `branch-name.sh`, `card-check.sh` (added 2026-10-17, F7), `help.sh` (added 2026-10-17, F8) (the rule also matches the script with no arguments), plus writing files in `config/repos/` and, for `flow-check-card`, the card files in `local/cards/`. **Added 2026-10-17** (user: the scripts must never ask for permission each time): the **read-only Jira tools** the commands use through Claude's Atlassian connector: `mcp__claude_ai_Atlassian_MCP__getAccessibleAtlassianResources`, `…atlassianUserInfo`, `…searchJiraIssuesUsingJql`, `…getJiraIssue`. Until then only the search tool was allowed, and only in the user's personal settings, so the account lookup (`flow-configure-user`) and any issue read asked in every session. Tools that change Jira (transition, edit, create, comment) are **not** pre-approved; Phase 1 decides those when it's built. The names follow the claude.ai connector ("claude.ai Atlassian MCP"); someone who connects Atlassian another way gets the prompts.
  - **Codex:** a committed rules file, `.codex/rules/closio-agent.rules`, with one `prefix_rule(pattern = ["bash", "scripts/<script>.sh"], decision = "allow")` per script. Codex's rules are experimental; they load only when Codex trusts this folder (it does on the first Mac), and an allowed command runs outside Codex's sandbox. Checked with `codex execpolicy check`: our scripts → allow, anything else → no rule (Codex asks as usual).
  - The commands still run the scripts exactly as written (`bash scripts/…`, no `cd`, nothing joined with `&&`), or the rules don't match.
- **Why:** User decision. No interruptions for our own scripts in either tool.
- **Rejected options:**
  - Keeping the git name/email change behind a prompt (the [D49](#d49) choice).
  - Auto mode / a looser Codex approval policy for everything: it would also approve commands that aren't ours.


<a id="d58"></a>
### D58 — Jira card template (F7): a template doc, two example cards, a structure checker and a `flow-check-card` command
- **Date:** 2026-10-17
- **Status:** Accepted (the user's answers to the F7 draft and to the final draft, both 2026-10-17). **Built 2026-10-17** after the user's yes; my tests passed (see "Built" below); **tested by the user the same day** ("F7 cases are tested already"). The `Write(/local/cards/**)` pre-approval was removed on 2026-10-17; the `Edit` rule covers writing the card file ([D57](#d57)).
- **Context:** Phase 1 checks each card against a template ([architecture.md](architecture.md#phase-1--pick-up-the-card-flow-start-card-key)). On 2026-10-17 the user pasted the card rules collected from their past chats (`build-memory/jira-card-rules-input.md`): the sections, the AC and QA rules, the code-alignment rules and two full example cards (SCRUM-559, SCRUM-567). Cards are written by people, and later by a separate pipeline; **closio-agent never creates cards**.
- **Decision:**
  - **Purpose (user):** closio-agent knows what a card looks like, so the development phases work in the right format, and it checks that a picked-up card follows the template with little deviation. The template and the examples are stored in the team docs.
  - **`docs/jira-card-template.md`** is the single place for the card rules: the skeleton (sections in order), the rules for each section, the drafting process, the Jira fields and the ready checklist. **`docs/jira-card-examples.md`** holds SCRUM-559 and SCRUM-567 in full.
  - **Required sections:** `## Context`, `## How QA can test this`, `## Acceptance Criteria` (every AC as `**AC 1 — Title**` with Given / When / Then). **Optional:** `## Scope`, `### Dev notes`, `### Data cleanup`, `## Error responses`, the `**Error reference**` table, `## Out of Scope` (stays optional: confirmed by the user, 2026-10-17).
  - **Out of scope** goes in one `## Out of Scope` section and nowhere else in the ticket (no `**Not in scope:**` lines inside Context).
  - **Context formatting:** bold labels (`**Current gap:**`, `**What changes:**`, `**Why:**`…) and `###` sub-headings may both be there; the agent reads what's present. No check.
  - **Title:** no rule and no check.
  - **Story vs Task:** no rule; the same template for both.
  - **Bug cards:** no fixed shape (on the board they are screenshots plus a line or two). The dev explains the gaps when the card is picked up. The same goes for a gap in any other card.
  - **Spike:** not picked up; `flow-start` refuses it with a message. **Subtask:** picked up (same format, or the dev explains).
  - **Jira fields:** the agent sets only the status and the assignee ([D11](#d11), Phase 1). Labels, story points, sprint, epic and priority stay with people.
  - **Error codes:** the `**Error reference**` table stays optional in the card, because the code is the source of truth for error codes, statuses and messages ([D59](#d59), rule A16).
  - **`scripts/card-check.sh`:** a structure check a script can do reliably on a card's text. ❌ = not ready, ⚠️ = worth a look. Pre-approved like every other script ([D57](#d57)).

    | ❌ not ready | ⚠️ worth a look |
    |---|---|
    | `## Context`, `## How QA can test this` or `## Acceptance Criteria` missing | a QA step without "Expect" |
    | no ACs; an AC heading not `**AC 1 — Title**`; AC numbers not 1, 2, 3… | deploy, migrate or restart steps in the QA section |
    | an AC without Given, When and Then | "test after SCRUM-… lands"-style wording |
    | an "Assumption:" line, `⟦…⟧`, TODO or TBD | a literal `\n` in the text |
    | a "Files changed" or "AC self-check" table | out-of-scope lines outside `## Out of Scope` (e.g. `**Not in scope:**` inside Context) |
    | QA section with no numbered steps; anything that looks like a secret | |

    `<SP_ID>`-style placeholders in the QA steps are fine. What a script can't judge (alignment with the code, the WS1 rules, ACs staying in scope, real boundary values, every AC covered by a QA step) is left to the AI in Phase 2.
  - **Command `flow-check-card <CARD-KEY or file>`** (user, 2026-10-17: "create one command for someone to test the card against the template"; their first answer the same day was no command): the AI reads the card from Jira (Claude Code: the Atlassian connector; Codex: the Atlassian app), saves its text to the private `local/cards/<CARD-KEY>.md`, runs `bash scripts/card-check.sh` on it and shows the result with the fix for each line (rule A11). It also names the issue type: a Spike isn't picked up by the agent; for a Bug, missing sections are fine (the dev explains them at pick-up). A path to a `.md` file works too, for a card that isn't in Jira yet. Its memory step uses the phase `pick-up`. Phase 1 (`flow-start`) runs the same check when it's built.
  - **Gaps at pick-up** (confirmed by the user, 2026-10-17): on ❌ the agent doesn't go on by itself: it lists the gaps, and the dev fixes the card or explains in chat; the explanation is saved with the card in its run folder, then the pick-up goes on.
  - The user's personal `~/.claude/CLAUDE.md` and project memories are **not** changed for this (user, 2026-10-17).
- **Why:** User decisions.
- **Rejected options:**
  - No command at all (the user's first answer on 2026-10-17): replaced the same day by `flow-check-card`, so card writers can test a card before it's picked up.
  - The template doc only, without the checker: the user wants the deviation from the template checked.
  - A title format rule with a ⚠️ check (suggested by Claude): not required.
  - Required sections for Bug cards: the dev explains the gaps instead.
  - Refusing Subtasks like Spikes: Subtasks are picked up.
  - Short out-of-scope notes inside Context: one `## Out of Scope` section only.
  - A pointer to the template in the user's personal `CLAUDE.md` (suggested by Claude): nothing there changes for now.
- **Built (F7, 2026-10-17):** `docs/jira-card-template.md`, `docs/jira-card-examples.md` (Example A also got its `**Not in scope:**` line moved into a `## Out of Scope` section, to match this decision; the dev note from the same line stays in Context), `scripts/card-check.sh` and the `flow-check-card` command (+ its Codex policy file and Claude Code link). The script runs in the Mac's own bash 3.2, reads the file once and never prints a line it takes for a secret. Its secret patterns are the ones of `scripts/memory.sh` plus a `key: value` form; the long-run pattern is letters and digits only, because constant names (`SLAB_NOT_ALLOWED_FOR_DEDUCTION_COMPONENT`) and API paths are normal in a card (the first version flagged them). Tests: both example cards → 0 ❌ and 2 ⚠️ each (the SQL revert steps and one check step have no "Expect"); one broken card per ❌ and ⚠️ line, all caught; a value in `<angle brackets>` is not taken for a secret; empty file, missing file and no argument → the right message and exit code; a path with a space works. Pre-approved: `Bash(bash scripts/card-check.sh *)` plus `Write`/`Edit` of `local/cards/**` in `.claude/settings.json`, and a Codex prefix rule ([D57](#d57); `codex execpolicy check` → allow). `flow-doctor`'s link check sees the new command. The command's memory step uses the phase `pick-up` ([D56](#d56)). Hardened the same day (user: no permission prompts, ever): the card file is written with the file-writing tool, never with `mkdir`, and the read-only Jira tools are pre-approved too ([D57](#d57)).

<a id="d59"></a>
### D59 — Error codes, statuses and messages always come from the code (rule A16)
- **Date:** 2026-10-17
- **Status:** Accepted (a hard rule from the user, 2026-10-17). Written into `AGENTS.md` (rule 10). Applied by Phases 2 and 3 once they're built; the card checker ([D58](#d58)) can't check it.
- **Context:** The F7 draft asked whether the card's `**Error reference**` table should be required. The user's answer: the table stays optional, because before developing, the agent must look at the error codes that exist in the code anyway. In their words: "if not present then the development card should first check the existing error codes available and then should start developing. That should be a hard rule. If the error codes are present, then also it should first check whether these codes are available in the code or they are differing from what is present. The exact errors are used for the right conditions."
- **Decision (rule A16):** before developing a card (the plan in Phase 2, the code in Phase 3), in every repo the card touches:
  1. **No error reference in the card:** the agent first reads the error codes, HTTP statuses, messages and error-body shapes that already exist in the code (constants, utils, controllers, middlewares, the WS1 locale files) and uses those.
  2. **The card lists error codes:** the agent checks each one against the code: does it exist, and do its status, message and details match? Any difference is pointed out to the user before development, and **the code's exact errors and messages are used for the right conditions**.
  3. **Nothing new is invented:** no new error code, status, message, field or constant unless the user approves it as new.
- **Why:** User decision ("that should be a hard rule"). It matches the code-alignment rules the user already follows for cards (`build-memory/jira-card-rules-input.md`, section 7).
- **Rejected options:**
  - Taking the card's error table as the truth: cards and code can disagree; the code wins.
  - Making the `**Error reference**` table required in every card: not needed once the agent always checks the code.

<a id="d60"></a>
### D60 — F8: a step-by-step user guide, a Claude artifact of it, a `flow-help` command, and the rule that every command is listed in all of them
- **Date:** 2026-10-17
- **Status:** Accepted (the user's answers to the F8 draft and to the final draft, both 2026-10-17). **Built 2026-10-17** after the user's "Go ahead, create it"; my tests passed (see "Built" below); **tested by the user the same day** ("The testing has been done"). **2026-10-17:** `help.sh check` also fails when a command isn't in a `flow-help` group (`flow-start` and `flow-status` had shown under "Other"); rule R17 and `AGENTS.md` rule 11 name the group. **2026-10-18:** the help's layout changed for readability (user: "make the flow help command a little more readable… can you make it color coded?"): formatted text for the AI to show (headings, bold names with a one-line summary, one `code` line per form), real terminal colors when the script runs in a terminal. **2026-10-18:** `flow-doctor` got the same look (user: "update the flow-doctor command in the same as you updated the flow-help command in terms of beautification"; the draft approved: "Yes, build the new flow-doctor look as drafted"): a heading per section, one line per check, problems in bold with their Fix or Tip under them, `commands`; colors in a terminal; the same checks, words and counts. **2026-10-18:** every command that takes arguments has an `argument-hint` line in its `SKILL.md` frontmatter, written from its `## Usage` block, which Claude Code shows in the `/` menu (user: "Only the commands are given as autocomplete, but the attributes for that command are not suggested"; approved: "Build A as drafted"). Claude Code shows it as a hint only (it has no list of values to pick from, per its docs), and Codex has no such field for skills. `help.sh check` (rule R17, `AGENTS.md` rule 11) fails when one is missing. The five descriptions holding ": " (`flow-develop`, `flow-finish`, `flow-push`, `flow-start`, `flow-verify`) were put in quotes so every frontmatter is valid YAML; `help.sh` drops the quotes. Real suggestions came after, as a Claude Code mod: [D73](#d73).
- **Context:** The setup commands are built (F1–F7), each documented in `commands.md`, but nothing walks a new user through the whole process in order, and nothing lists every command in one place inside the tool. The user asked for "one artifact explaining the entire process step by step", a help command, and a hard rule that every flow command, now and in future, is listed in the help and in the artifact.
- **Decision:**
  - **The guide, `docs/user-guide.md`** ("closio-agent, step by step"): what closio-agent is and how a command is typed; the whole journey in one picture (one-time setup → every day → a card from pick-up to Ready for Test); one section per command in the order it's used (when, what you type, what it asks and every option, what you see, what to do on ❌, where to read more); a **command index** with every flow command and all its options; "what comes next": the card phases with their **placeholder command names** (`flow-start`, `flow-push`, …) marked "coming" (user, 2026-10-17).
  - **A Claude artifact of the guide** (user: "maintain an artifact whose link will be present in the code"; then: "I don't want a published page. I want a Claude artifact, which is always updated using the rules present in the current directory"): a **Claude Doc**, the editable artifact in claude.ai, holding the same text as `docs/user-guide.md`. `docs/user-guide.md` is the source; the artifact mirrors it. **No HTML file and no publishing step.** The artifact's link is written in `README.md`, `docs/README.md` and at the top of the guide, next to a "mirrored" line: the date the artifact was last updated and the commands it covered. **The rule keeps it updated:** whenever the guide changes (a command added or changed), the same Claude Code session updates the artifact from the guide, through Claude's docs connector, and updates the "mirrored" line. Codex can't reach the artifact: a change made in Codex is finished in Claude Code (the doctor check says so until then). The artifact starts private; the user shares it with the team in claude.ai once.
  - **The `flow-help` command** (+ `scripts/help.sh`): `/flow-help` lists every flow command, grouped (Setup once, Every day, Cards; a command not in the script's grouping list shows under "Other"), one line each plus its options; `/flow-help <command>` shows one command in full. The text comes from each command's own folder: the `description` in its `SKILL.md` and a uniform **`## Usage` block** added to every `SKILL.md` (one source: the AI reads the same block when it runs the command). The script lists every `.agents/skills/flow-*` folder it finds, so a new command can't be left out; one without a `## Usage` block shows with ⚠️. It also prints the link to the published page.
  - **The hard rule (user: "that's a hard rule"):** a new or changed flow command isn't done until, in the same step: its `## Usage` block; its section in `docs/commands.md`; its section and index row in `docs/user-guide.md`; the Claude artifact updated from the guide and the "mirrored" line updated. Written as build rule **R17** (`build-memory/rules.md`) and **`AGENTS.md` rule 11**, so any AI session that adds a command follows it.
  - **Checked by a script, not by memory:** `bash scripts/help.sh check` (run by `flow-doctor`, "Commands documented") → ❌ with the fix when a command folder has no `## Usage` block, no `commands.md` section or no guide row, or when the guide's "mirrored" line doesn't list every command (the artifact is behind: update it from the guide in Claude Code).
  - `help.sh` is pre-approved like every other script ([D57](#d57)).
  - **Language (user, 2026-10-17):** the guide is written in very simple language, so anyone can understand it (rule R12).
- **Why:** User decisions. One place to learn the process, one command to see every command, and a rule that can't be forgotten because `flow-doctor` fails when it is.
- **Rejected options:**
  - The guide only as a doc, without an artifact (recommended by Claude for simplicity): the user wants a Claude artifact with its link in the code.
  - An HTML page generated from the guide (`docs/user-guide.html`) and published as a claude.ai page (the first final draft): the user doesn't want a published page; they want the Claude artifact itself, kept updated by the rules.
  - An artifact alone, without the doc in the repo: it can't be checked by a script and wouldn't travel with the repo.
  - Describing the card phases without command names: the user wants the placeholder names listed, marked "coming".
  - Keeping the help text in a separate list file: it would drift from the command files.
- **Built (F8, 2026-10-17):** `docs/user-guide.md` (9 sections: what it is, how to type a command, the journey, one-time setup in 9 steps, every day, working on a card (coming, placeholders), every command and its options, when something goes wrong, where to read more and how the guide stays up to date); the Claude artifact "closio-agent, step by step" (a Claude Doc, filled from the guide; link in the guide's "mirrored" line, in `README.md` and `docs/README.md`); `scripts/help.sh` (`list`, `show`, `check`; bash 3.2; reads every `.agents/skills/flow-*/SKILL.md`); the `flow-help` command (+ Codex policy file, Claude link); a uniform `## Usage` block in all 9 command files; rule R17, `AGENTS.md` rule 11; `flow-doctor`'s "Commands documented" section; `help.sh` pre-approved in both tools ([D57](#d57)). **Pictures (user, 2026-10-17: "add more pictorial representations, more like a flowchart"):** five flowcharts, the same information as the text next to them: how a command runs, the whole journey, the nine setup steps with the final decision, the card phases with the two stops and the two loops, and how the guide stays up to date. In the artifact they are drawn diagrams (editable labels, commentable parts); in `docs/user-guide.md` the same five as Mermaid flowcharts, which GitHub renders. Mirroring rule: a picture changed in one is changed in the other. **Less text, more pictures (user, 2026-10-17: "the document looks very text-heavy… present options and all the points in a pictorial way"):** in the artifact, every command is one picture, a card with three parts: when to use it, every way to type it (one box per form, with what it does), and what you see; plus a footer line (Codex form, a caveat). The three steps before the commands are one card too. The bullet lists under those headings were replaced by the card and one sentence. `docs/user-guide.md` keeps the full text (it's the source and the GitHub-readable version); the artifact is its pictorial version with the same information. Rule R17 therefore means: when a command changes, its card is redrawn.

<a id="d61"></a>
### D61 — The card phases: six commands, the run folder, run folders pushed on a branch, Jira changes without prompts
- **Date:** 2026-10-17
- **Status:** Accepted (the user's answers to the card-phases plan, 2026-10-17). **C1 + C2 built 2026-10-17** after the user's yes (see "Built" below); my tests passed; **tested by the user the same day** on SCRUM-540 (see "Tested" below). C3–C6 follow one by one. F9 (the new-user test) is postponed, not dropped. **Fixes after the user's tests (2026-10-17, built the same day):** `next:` is just `/flow-start <KEY>` (the step lives only in `step:`); continuing at steps 8–10 goes back to step 7 and asks only what's still open; step 7 first brings the latest base branch into the card's branch (`card-branch.sh update`) and reads the ruleset ([D64](#d64)); the plan uses the ruleset's format (with the per-repo file list and the AC → implementation table). **C3 built 2026-10-17 ([D65](#d65)):** `flow-develop`; the run folder gains `develop.md`. **Changed 2026-10-17 (before the C3 test):** the run branch is never checked out. Checking it out swapped the whole closio-agent folder, tools included, for the branch's older copy (`runs/SCRUM-540` was made from `27b72e1` and lacked `run.sh`, `flow-start`…; git also refused the switch over uncommitted files). Now `run.sh save` commits only `runs/<CARD-KEY>/` to the branch through a temporary git index and pushes; `run.sh branch` makes the branch on this Mac and brings the folder onto disk (a teammate's newer save too, when nothing here is unsaved; both changed: ❌, ask the user); run folders are git-ignored on `main` (`/runs/*/`); `flow-doctor` shows ❌ if the folder is on a run branch. `flow-start` continuing from a saved step now runs `run.sh branch` first (user: "sure this works"; design accepted: "this works"). **C4 built 2026-10-18 ([D67](#d67)):** `flow-verify` + `flow-ac-check`; the run folder gains `verify.md`, `api-checks/`, `e2e/`, `qmetry/`, `test-data.sql`. **C5 built 2026-10-18 ([D70](#d70)):** `flow-push`; the run folder gains `ship.md` and `mr-<repo>.md`; after it the phase is `after-merge`. **C6 built 2026-10-18 ([D72](#d72)):** `flow-finish`; the run folder gains `deployment.md`; the run branch is **not** merged into `main` (run folders are kept out of `main` since 2026-10-17): it stays as the record, and `flow-status` lists finished cards from it. Every card phase now has its command.
- **Context:** The foundation (F0–F8) is built and tested. The card phases 1–9 ([architecture.md](architecture.md)) had no commands, no run-folder design and no order of building yet.
- **Decision:**
  - **One command per group of phases,** each started by typing it, each continuing from where the card stopped (the run folder says where): `flow-start <CARD-KEY>` = Phases 1 and 2, ending at the plan approval ✋; `flow-develop <CARD-KEY>` = Phases 3 and 4 (develop together, then the human review ✋); `flow-verify <CARD-KEY>` = Phases 5 and 6 (the AC-check agent, the repo tests, the story-verification agent; a failure goes back to develop); `flow-push <CARD-KEY>` = Phases 7 and 8; `flow-finish <CARD-KEY>` = Phase 9. Plus `flow-status [<CARD-KEY>]`: where a card stands, or every card. The build order: **C1** the run folder + `flow-status` and **C2** `flow-start` together, then C3 `flow-develop`, C4 `flow-verify`, C5 `flow-push`, C6 `flow-finish`.
  - **`flow-develop` also starts from plain words** (user: "anything written in plain language should also trigger flow develop internally and should start the development on that card"). This is the one exception to [D44](#d44) (commands only run when typed) and to `AGENTS.md` rule 1: when the user asks in plain words to develop a card that already has an approved plan in its run folder, the AI runs `flow-develop` for that card. It never starts on its own, never for a card without an approved plan, and never any other command. **Guard confirmed by the user (2026-10-17):** it starts only when the user names a card whose plan is approved, or when exactly one card is at that stage. Written into `AGENTS.md` rule 1 and the command's own file when C3 is built.
  - **The run folder** `runs/<CARD-KEY>/` (rule A1, [D36](#d36), [D38](#d38)): plain markdown, no secrets: `state.md` (phase, step, branch, repos, last update), `history.md` (one line per step: date, step, what happened, the memory entries used), `card.md` (the card as read from Jira, plus what the user explained at pick-up), `plan.md` (the approved plan), `verify.md`, `ship.md`, `deployment.md`. `scripts/run.sh` creates and updates them, so both tools behave the same.
  - **Memory before planning** (user, 2026-10-17: "check the memory before planning anything"): before `flow-start` writes the plan, it re-reads the user's memory entries for the `plan` phase and for the repos involved (rule A7, `bash scripts/memory.sh for plan <repos>`), applies them, and lists the entries it applied at the top of `plan.md`.
  - **Run folders are committed and pushed every time, on a branch of closio-agent, never on `main`** (user, 2026-10-17). Each command commits its run-folder changes at the end of its phase and pushes them to the card's branch. The branch name is chosen at run time; **no naming rule yet** (user). Proposed for the first piece, to confirm: `runs/<CARD-KEY>`, one branch per card, merged into `main` by `flow-finish`.
  - **The repos a card needs:** read from the card's Scope section, then confirmed by the user ("check and then confirm").
  - **A card that isn't To Do, or is assigned to someone else:** the agent says so and asks whether to go on.
  - **Jira changes without prompts** (user: "pre approve these so that they run without asking"): the Jira tools that move a card and set its assignee (`mcp__claude_ai_Atlassian_MCP__transitionJiraIssue`, `…editJiraIssue`) are pre-approved in `.claude/settings.json` like the read tools ([D57](#d57)), when C2 is built. The agent still never moves a card to Blocked (A3) and sets only the status and the assignee ([D58](#d58)).
  - **The sprint move** goes through the issue's Sprint field (`editJiraIssue`); verified on the Japfa Jira when C2 is built. **Verified 2026-10-17:** `transitionJiraIssue` takes the sprint id together with the move to In Development (Sprint 28 = id 734; the Sprint field is `customfield_10020`; the In Development transition is id 21).
- **Why:** User decisions. Fewer, predictable commands; a card can be paused and resumed by anyone; the run folders travel through git without touching `main`; the plan respects what the user taught the agent.
- **Rejected options:**
  - One command per phase: more to type and to remember.
  - A separate `flow-plan` command: the plan approval ends `flow-start`.
  - Committing run folders locally and pushing when the user wants (recommended by Claude): the user wants every change pushed, on a branch.
  - Committing run folders to `main`: the user wants a branch.
  - Asking before every Jira change: the user doesn't want prompts in the commands.
- **Built (C1 + C2, 2026-10-17):** `scripts/run.sh` (`branch`, `create`, `state`, `get`, `set`, `log`, `save`, `list`, `count`, `problems`; bash 3.2), `scripts/card-branch.sh` (`check`, `create`; exit code 3 on uncommitted changes), the `flow-status` and `flow-start` commands (+ Codex policy files, Claude links), `RUN_BRANCH_PREFIX` and `GIT_REMOTE` in `config/project-settings.sh` ([D46](#d46)), `flow-doctor`'s "Cards in progress" section, pre-approvals ([D57](#d57)): both scripts, writing `runs/**`, and the Jira tools `transitionJiraIssue`, `editJiraIssue` and `executeRead`. **The branch for run folders is `runs/<CARD-KEY>`** (confirmed with the yes): `run.sh branch` creates it from `origin/main`, or from `origin/runs/<CARD-KEY>` when a teammate pushed it (the run folder then arrives on this Mac); `save` commits only `runs/<CARD-KEY>/` and pushes; a failed push keeps the commit. `flow-status` reads a card's state from the working tree, else from the branch on this Mac, else from `origin`, without a checkout. Tests (temp repos with a temp origin and a temp GitLab, paths with spaces): branch created from main with uncommitted changes carried along untouched; create, set, log (a `|` in the text escaped), state, get; save and push, nothing-new, save on `main` refused; list and state from `main` and from a teammate's clone; the teammate's `branch` brings the folder; a push failure keeps the commit; count and problems; `card-branch.sh`: pulls the newer base branch before creating, reuses an existing branch (local or on GitLab), refuses a bad name, stops on uncommitted changes, ❌ for an unregistered or not-cloned repo, for a clone of another project, and for an unreachable GitLab (VPN fix). Not tested by me: the live Jira moves (sprint field, transition, assignee) and the VPN step: those are the user's first run on a test card.
- **Tested by the user (2026-10-17):** `/flow-status` with no card, `/flow-doctor` ("Cards in progress"), `/flow-start SCRUM-131` (a Spike: refused, nothing created), `/flow-start SCRUM-521` (In Development and someone else's: asked, "no", nothing created), then `/flow-start SCRUM-540` end to end: VPN, the card read and checked (11 ❌, 6 ⚠️; the user's explanation saved under "Explained at pick-up"), Sprint 28 + In Development + assignee, the two repos confirmed, a bad branch name refused (A12), the branch `SCRUM-540/backend-get-trader-stock-days` in both repos from the latest `develop`, the run folder saved and pushed, the code read in both repos, 17 questions answered before the draft (the user decided this card also builds SCRUM-539's table, model and a seeder), the draft, "plan approved", `plan.md` saved and pushed; `/flow-status` again mid-plan and at the end; every step logged with its rules and memory (A17). Found while testing (open, see `build-memory/open-questions.md`): the repos' `rulesets` path wasn't found (it's relative to the workspace folder), and the `next:` line keeps "(continue at step 7)" while the step moves on.

<a id="d62"></a>
### D62 — Rules and memory are checked before every step of a card phase (rule A17; build rule R18)
- **Date:** 2026-10-17
- **Status:** Accepted (a rule from the user, 2026-10-17). Written into `AGENTS.md` (rule 12) and `build-memory/rules.md` (R18) at once; **applied by `flow-status` and `flow-start` (built 2026-10-17, tested by the user on SCRUM-540: every history line names the rules and memory applied)** and by every later card-phase command as it's built.
- **Context:** The card phases are about to be built ([D61](#d61)). The user: "Before every phase in the card pickup, the phases that are starting with C, you need to always check the memory, the rules, and the user memory, all of that, so that you perform the functions as it is required. No rules are skipped, nothing is left out. So before every step in this phase, starting with C, you need to check this, make it a rule in your build memory as well, and also introduce this step from now on in all the further phases of this particular segment."
- **Decision:**
  - **Rule A17 (the commands):** every card-phase command (`flow-status`, `flow-start`, `flow-develop`, `flow-verify`, `flow-push`, `flow-finish`), before each of its steps, re-reads the team rules (`AGENTS.md`, [agent-rules.md](agent-rules.md)) and the **user-created memory** (the entries the user made with `flow-memory`, in `local/memory/`; named explicitly at the user's request) for that phase and the repos involved (`bash scripts/memory.sh for <phase> <repos>`), applies both, and writes in the card's `runs/<CARD-KEY>/history.md` which rules and memory entries it applied. Nothing is skipped. This extends A7 (memory at the start of a command) to every step, and adds the rules. `AGENTS.md` rule 12.
  - **Rule R18 (building):** before every step of drafting, building, testing or documenting a card piece, the builder re-reads the build rules, the agent rules, the decisions the step touches and the user memory, writes down which apply, and checks them off when the step is done ([build-memory/rules.md](../build-memory/rules.md)).
  - The check is a written step at the top of every card-phase command's file, and the command's history lines are the proof it ran.
- **Why:** User decision: the card phases touch code, branches, Jira and GitLab, so a skipped rule costs more there than in setup.
- **Rejected options:**
  - Checking once at the start of a command only (what A7 does today): a long phase can drift from the rules between steps.

<a id="d63"></a>
### D63 — A plan is made from the code, with questions first and the user's manual approval before it's saved (rule A18)
- **Date:** 2026-10-17
- **Status:** Accepted (a rule from the user, 2026-10-17). Written into `AGENTS.md` (rule 13) at once; **applied by `flow-start` steps 7–11 (built 2026-10-17; tested by the user on SCRUM-540: the code read first, 17 questions answered before the draft, nothing saved before "plan approved")**. **2026-10-17:** step 7 first brings the latest base branch into the card's branch (`card-branch.sh update`: a fast-forward while the branch has no commits of its own), and continuing at steps 8–10 goes back to step 7, so a plan always comes from the latest code.
- **Context:** The C1 + C2 draft planned a card from the card's text, the existing error codes (A16) and the rulesets, then asked for approval. The user: "always make sure that you first check the updated code on the branches and then only you create a plan. You can also mention the differences in the error codes that are present, the things that are not present right now in the code, or things which differ from the code and what is mentioned in the card. For example, for unauthorized access, there is a particular error which is already used in the code, but something else is mentioned in the card: flag that and ask a proper input from the user before creating your final draft of the plan… that manual approval is strictly necessary. And before every step of whenever you create the plan, you need to check the existing code; that cannot be skipped."
- **Decision (rule A18):** when a card is planned:
  1. **The code first, always:** pull the base branches and read the current code of every repo involved (routes, controllers, services, utils, constants, middlewares, migrations, locale files). A plan is never made from the card alone, and this step can't be skipped.
  2. **Questions first:** list every difference between the card and the code (error codes, statuses, messages, fields, anything the card names that isn't in the code, anything in the code the card contradicts), ask the user about them, and wait for the answers.
  3. **Then the draft** of the plan, built on the answers.
  4. **Manual approval, strictly necessary:** the user approves the plan in chat. Nothing is saved to the run folder or pushed before that.
  This is the same way the user already writes Jira cards (code first, questions first, draft, explicit go-ahead), now a rule for the agent's plans. It builds on A16 (error codes from the code) and A17 (rules and memory before every step).
- **Why:** User decision. A plan built on the card alone can contradict the code; the user wants the differences on the table before the plan exists, and the plan never saved behind their back.
- **Rejected options:**
  - Planning from the card and the error codes only, then asking for approval (the first C2 draft).
  - Saving the draft plan before the approval, as a work in progress: the user wants nothing saved before the yes.

<a id="d64"></a>
### D64 — The ruleset lives in closio-agent, is kept by us, and users adjust it only through their memory (rule A19)
- **Date:** 2026-10-17
- **Status:** Accepted (the user's answers, 2026-10-17). **Built 2026-10-17** after "Yes, build the 5 fixes and the ruleset copy as drafted." Written into `AGENTS.md` (rule 14).
- **Context:** The C1 + C2 test on SCRUM-540 showed that `flow-start` couldn't find the ruleset: the repo files named `backend/story-implementation-workflow.md`, a loose file in the user's workspace (`japfa/backend/`, in no git repo). The plan was made without it, and a teammate who clones closio-agent wouldn't have it at all. A review of the file against closio-agent's rules, decisions and code (on `develop` of the 7 repos) also found parts that didn't match.
- **Decision:**
  - **Added by us, kept in closio-agent** (user: "I want the ruleset to be added by us, not by the user and we add it, right now and use this as the baseline; we don't allow user to add it entirely, they can just manipulate it using user memory"): `rulesets/story-implementation-workflow.md`, committed. The copy in `japfa/backend/` isn't used any more. No command adds or changes it; the `rulesets` field is removed from the repo files and from `flow-configure-repo`, and the agent picks the ruleset by the repo's type (`RULESET_FILE` in `config/project-settings.sh`, [D46](#d46)).
  - **For every card** (user: "use this as the baseline right now for all the stories; we will keep on editing this as well while we are creating the closio-agent"): backend repos follow all of it; the web app follows its common practices until a frontend ruleset exists (user: "the common practices will be followed for both until we define a Frontend one").
  - **Users adjust it only through their memory** (user: "yes this is right"): a memory entry may change a ruleset point for that user; the plan names which entry changed which point; the agent rules always win over memory (A8 unchanged).
  - **Paired with the card files** (user: "whatever the user adds in the user memory + all other card related files can be paired with this knowledge can help in development"): plans are built from the ruleset, the user's memory, the card files (`card.md` with the explanations and the answers) and the code; `flow-develop` (C3) will do the same.
  - **Edits made in the copy** (user, 2026-10-17), so it matches closio-agent: Steps 1–9 instead of Phases, each mapped to its command; wording for Claude Code and Codex (parallel helpers only where the tool supports them); Express 5 (user: "use express 5 which is present in the repositories"; copy the closest route file: WS2 routes don't wrap handlers, some WS1 route files do); WS1 routes: `validateSchema` always before `isAuthenticated` (user: "that way we save DB calls in isAuthenticated"); GitLab MCP and `glab` removed (user: "remove Gitlab MCP we wont be using it", "yes remove glab"); migrations and seeders started from this Mac with the repo's own `npm run migrate` / `npm run seed`, against the database its `.env` names (today the dev database), only after the user's yes, every run ([D21](#d21) amended); keys and cookies never pasted into chat (A6), the curl checks run by a closio-agent script in `flow-verify`; each repo's own test commands and Node version (A13), `coverage:check` as the gate, no committed tests where `test_command` is `none` ([D25](#d25)); the card's error reference checked against the code (A16); one plan format shared with `flow-start` (plus the per-repo file list and the AC → implementation table); the must-read files marked as examples, with the constants and the WS1 message files added; the test layout from the repo file; a seeder only when the card needs one; the session stats removed; the Jira setup pointed to the setup guide; the MR description checklist kept as the format `flow-push` will use.
  - **Rule A19**, `AGENTS.md` rule 14.
- **Why:** User decisions. One ruleset that travels with every clone and is versioned with closio-agent, while each user can still tune it for themselves.
- **Rejected options:**
  - Keeping the file in the workspace and reading it from `WORKSPACE_DIR`: teammates wouldn't have it.
  - A `rulesets` field per repo that users set: users don't add rulesets.
  - Copying the file unchanged with a note that closio-agent's rules win where it disagrees (Claude's first recommendation): the user settled each disagreement instead.
  - Asking the person running the command about each disagreement at run time (Claude's first reading of "what the user decides will be used here"): replaced by the user's own decisions.
  - Running migrations and seeders only against a Postgres on this Mac (Claude's recommendation): the user chose to start them from this Mac against the database the `.env` names, with a yes every run.
  - A backend-only ruleset with nothing for the web app: the web app follows the common practices for now.
- **Built (2026-10-17):** `rulesets/story-implementation-workflow.md`; `RULESET_FILE` in `config/project-settings.sh`; `bash scripts/configure-repo.sh ruleset <repo>`; the `rulesets` field removed from the 7 repo files and from `configure-repo.sh detect`; `flow-start` step 7 reads the ruleset and the plan names it with the memory applied; `flow-doctor` checks the file is there; rule A19 in `docs/agent-rules.md`, `AGENTS.md` rule 14, `build-memory/project-context.md`.

<a id="d65"></a>
### D65 — `flow-develop` (C3): the code and its unit tests with the user, then the user's review
- **Date:** 2026-10-17
- **Status:** Accepted (the user's answers to the C3 draft, 2026-10-17). **Built 2026-10-17** after "yes build it"; my tests passed (`scripts/repo-run.sh`); **tested by the user the same day** on SCRUM-540: started from plain words, both repos developed with their tests and checks, the migration run after a yes, two review changes, then "review approved" (the card is now in the verify phase). Found: `npm run seed` runs every seeder of the repo (`db:seed:all`), so it wasn't run; the user ran the card's seeder by hand (open question). **Changed 2026-10-17:** lint checks only the files the card changed and shows its problems as ⚠️ warnings, never ❌ (user: "show lint errors only as warnings"; "lint only the card's changed files (a)"): the repos already have lint errors (ws2targetsalesincentive 80, ws1closio 550, ws2jauth 1). Other checks still must pass. **2026-10-18 ([D67](#d67)):** `flow-develop` offers to go back to a card in the verify phase when `verify.md` lists failures; the user decides.
- **Context:** C1 + C2 pick a card up and plan it; Phases 3 and 4 (develop, human review) had a name (`flow-develop`, [D61](#d61)) and a plain-words start, but no steps.
- **Decision:**
  - **What it does:** repo by repo, in the plan's order (WS2 before WS1): the code (following the closest existing files; **creating the new files the plan lists and any other the work needs**, user: "it should also create the new files when required"; anything new or different from the plan asked first, rule A16), **the committed unit tests**, the repo's tests with the coverage gate and its checks until they pass, migrations and seeders only after the user's yes ([D21](#d21)), a **short summary after each repo, then it carries straight on** (user: "yesss"), then the run folder saved and **the user's review** in their editor ("review approved" in so many words, or changes: back to developing). Nothing is committed (G3).
  - **Tests move to Phase 3** (user: "we should create the unit test cases in develop command itself, flow-verify we just test everything as per the AC's… for FE flow verify will run everything in playwright integration but the test cases creation part goes in develop command"): backend unit tests (controller, service) and API tests; Vitest unit tests for the web app; none where a repo has no test suite ([D25](#d25)). `flow-develop` also **runs them with the coverage gate** until they pass (user: "yes"). `flow-verify` runs them again with the AC checks; it writes and runs the Playwright tests (user: "yess"). [D18](#d18) changed.
  - **`runs/<CARD-KEY>/develop.md`** (user: "this works"): per repo the new and changed files, the tests and their result, the checks, everything not in the plan with the user's answer; the migrations and seeders run; the review.
  - **`scripts/repo-run.sh <repo> check | test | migrate confirmed | seed confirmed`** (user: "yess"): a repo's own commands from its repo file, in its folder, on its Node version (A13); `test` = the coverage command (every test and the gate in one run) or the test command; `migrate` / `seed` = `npm run migrate` / `seed`, refused without `confirmed` and when the repo has no such script; `REPO_RUN_TIMEOUT` (15 minutes), log in `local/logs/`. Pre-approved in both tools ([D57](#d57)).
  - **Code edits** in the repo folders ask as usual in Claude Code (user: "works").
  - **Plain words:** only when the user names a card in the develop phase, or exactly one card is in it ([D61](#d61)); `AGENTS.md` rule 1 names this one exception ([D44](#d44)).
  - **A paused develop continues only on the same Mac:** the code is pushed only by `flow-push`.
  - The artifact gets a card for it (user: "also update the artifact"; rule R17).
- **Why:** User decisions.
- **Rejected options:**
  - Tests written in `flow-verify` (Claude's first draft, following the ruleset's first mapping): the user wants them written with the code.
  - Waiting for the user's OK after each repo: the summary is enough; the review comes at the end.
  - Development notes in `plan.md` and `history.md` only: a separate `develop.md` was chosen.
  - Pre-approving code edits in the repos: edits ask as usual, so the user sees each change.
- **Built (2026-10-17):** `.agents/skills/flow-develop/` (11 steps, the plain-words check, A17 before every step) + its Codex file (`allow_implicit_invocation: true`) and Claude Code link; `scripts/repo-run.sh`; `REPO_RUN_TIMEOUT`; `flow-help` Cards group; `AGENTS.md` rule 1; pre-approvals; the ruleset's Steps 5–7 mapped to `flow-develop`; the docs and the artifact card. Tests (temp repos, paths with spaces, the Mac's bash 3.2): checks passing and failing (the end of the output shown), tests and coverage passing and failing with their result lines, no coverage command: the test command, `test_command: none`: no tests, `migrate` without `confirmed`: refused, with it: run, `seed` without a script: ❌, a missing Node version: one ❌ with `nvm install`, the time limit, an unregistered or not-cloned repo, a wrong action: usage; on the real `ws2jauth`: `check` ran (its code has a lint error today, `appConfig.js`: `path` unused). `help.sh check` ✅ with 12 commands; Codex rule: allow. Not tested by me: the command itself on a card.

<a id="d66"></a>
### D66 — Four develop rules: where request validation goes, no redundant code, every WS1 response field, a review before any migration (rules A20–A23)
- **Date:** 2026-10-17
- **Status:** Accepted (rules from the user, 2026-10-17). **Built 2026-10-17:** `AGENTS.md` rules 15–18, the ruleset, `flow-start` and `flow-develop`.
- **Context:** Before the first `flow-develop` test, the user added rules for how a card's code is written. A look at `develop` in the 6 backend repos ([build-memory/environment.md](../build-memory/environment.md)) showed: simple request checks inline in WS2 controllers, large bodies in domain utils (`validateAgeingDeductionConfigBody`), database checks in services; WS1 schemas check almost nothing in the body (399 of 416), on purpose, while 17 older ones check presence and type with `errorMessage`; helpers already copied many times (`asyncHandler` in 28 WS1 route files, several UUID checkers); SCRUM-540's plan left `updated_at`, `updated_by`, `updated_by_name` out of the WS1 response schema.
- **Decision:**
  - **A20, request validation:** WS1 is a proxy. Its schema file checks presence (`required`), type and format, with messages through `replaceMessagePlaceholders` and keys already in its locale files (as `approval-tools/sfa/approvalApprove/approveRequest.js`); a URL ID's format is checked in the WS1 controller with the existing `isValidUUID`; WS1 checks no business rule (user: "with option A. The type and format checks can also go in WS1. The rest of the checks, business logic validations, will stay in WS2"). WS2 checks everything it receives again, presence, type and format included (it's also called directly; confirmed by the user: "Yes, WS2 keeps checking presence, type and format as well, plus all business logic."), and owns every business-logic check: in the controller when it needs only the request (user: "validations that needs to be done on the request"), inline when small, a function in the repo's domain utils file when large (over about 30 lines, used by more than one handler, or a nested body; it returns an error or nothing and the controller makes the 400); in the service when it needs the database (user: "yes yes this is the right approach"). New code only; existing code isn't moved.
  - **A21, no redundant code:** search before creating any function, helper, constant or regex; reuse an exact match; ask on a close one; record each search in `develop.md`; never another copy of an existing helper. WS1's `asyncHandler`: reuse the file's own; a new route file copies the one line as the others do (user: "this works").
  - **A22, every WS1 response field:** the full list of fields the WS2 response can return is asked of the user when planning; optional ones go in as nullable and not required, as `getAgeingDeductionConfigs.js` does.
  - **A23, migration review:** before any migration or seeder runs, or the user is asked to run one on a server, the agent shows the files (the full up and down, what they change, the repo, the database the `.env` names) and waits for a separate yes ([D21](#d21)). Seeders are included because they change data too.
- **Why:** User decisions: one place for each kind of check, no duplicate code, a complete WS1 response contract, and an extra safety check before a database changes.
- **Rejected options:**
  - All validation in the controller, database checks too: breaks the controller → service layering; the user meant request validation.
  - WS1 checking nothing in the body (option b, today's incentive schemas): the user chose presence, type and format in WS1.
  - WS1 owning business rules: they stay in WS2.
  - A shared `asyncHandler` made by the first card that needs one: it would change 28 files, outside a card.
- **Built (2026-10-17):** the four rules in `AGENTS.md` (15–18), [agent-rules.md](agent-rules.md) and `build-memory/project-context.md`; the ruleset (header note, Step 3 search, Step 4 plan part, Step 5 rules, Step 8 review, checklist); `flow-start` (step 8 asks for the response fields, step 9's plan part `## Validation, reuse and response fields`); `flow-develop` (step 4 applies A20–A22, step 7 the review, the summary and `develop.md` record the searches, the review lists new functions).

<a id="d67"></a>
### D67 — `flow-verify` (C4): every AC's test cases, the tests again and a story check; failures are the user's call
- **Date:** 2026-10-18
- **Status:** Accepted (the user's answers to the C4 drafts, 2026-10-17 and 2026-10-18). **Built 2026-10-18** after "move to C4"; my tests passed (fake WS1 and WS2 servers, a throwaway Postgres); Playwright waits on the user's OK for its download; **the user's tests are pending**. **Changed 2026-10-18 (QMetry):** QMetry is optional and never asked for. With an export (typed after the key, or saved in an earlier run), its cases are the **base** for the test cases (not only a benchmark): every case that can be automated becomes a test named with its QMetry key, and an AC without a QMetry case still gets cases of its own. At the end, only then, one line: how many QMetry cases were covered (`qmetry-import.sh coverage`). Nothing more: no table, no list. Without an export, the test cases come from the card and the code (user: "If they don't, then do not ask the user… create your own test cases and use them as the base"; "you just mention a percentage of how many test cases were covered. That's all"; own cases for an AC without a QMetry case: "sure"). **Changed 2026-10-18 (web tests that answer for the server):** by default a web test talks to the real servers; a case that needs an answer the dev data or the server can't give on demand (a 500, more than 5 items, an empty group, a fixed order, a given status) answers the screen's one API call itself with Playwright's `page.route`, the rest of the test (login too) still on the real servers; the answer's shape and error codes come from the code (A16); its name ends with `(answer from the test)`; each AC keeps a real-server test where possible; only for calls sent as plain JSON (`X-Secure-Transmission-Type` `0` or `x`), otherwise test data through `db-run.sh` or the case is left out (user: "Yes, build the page.route change… with the (answer from the test) tag"). Rejected: test data in the shared dev database for these cases (rows others see, a yes each time, and a 500 can't be made with data). **Changed 2026-10-18 (WS1 statuses, found in the SCRUM-523 test):** a case that calls WS1 (every web test, backend cases through WS1) expects WS1's status and message, read from WS1's `src/middlewares/errorHandler.js` (a WS2 404 reaches the caller as 597, `error_code` kept) (user: "yes"). **Changed 2026-10-18 ([D68](#d68)):** two ways to verify (A full check = this decision, B quick check); the cleanup also removes the rows the cases' write calls create, and those calls are shown first; every run is recorded in `verify.md`. **2026-10-18 ([D71](#d71)):** `api-call.sh` logs in on the dev WS1 and uses its session cookie on the WS1 on this Mac (a web login has no token).
- **Context:** Phases 5 and 6 had decisions (D18, D19, D24) but no command. C3 moved the unit tests into `flow-develop` (D65).
- **Decision:**
  - **`flow-verify <CARD-KEY>`** (typed only): starts the card's repos on this Mac (the script starts and stops them, user: "yess"); the `flow-ac-checker` agent **writes every AC's test cases by default** (user: "works"): API checks for backend cards, Playwright tests for web cards; test data and its cleanup are **shown first and run only after a clear approval** (user: "cleanup scripts and the test data is first shown to the user and asked for there clear approval before even adding or reverting anything"); the AC checks, the repo tests again, the `flow-story-check` agent; `verify.md`.
  - **All passed:** straight to the ship phase (user: "sure"). **A failure:** it tells the user what's wrong and suggests what to do; **the user decides** (user: "it tells the user what is wrong and suggest them, it is the user responsibility to continue further"). `flow-develop` offers to go back to fix the list.
  - **`flow-ac-check <CARD-KEY> <AC> ["…"]`**: adds, changes or rewrites one AC's cases and runs them once (user: "for someone who wants to add new or update… they go for the flow AC check command").
  - **Test cases live in the run folder** (user: "this works"): `runs/<CARD-KEY>/api-checks/ac-<n>.json`, `runs/<CARD-KEY>/e2e/ac-<n>.spec.ts`; the shared Playwright project in `e2e/` on `main`.
  - **WS2 keys:** the ones saved with `flow-configure-repo` (user: "the values we saved in the client id and secret can be used here"); WS1 calls log in with the user's WS1 login (D20). Scripts add them; they're never shown (A6).
  - **Playwright for everyone, inside `flow-configure-user`** (user: "it should be there in the setup of the entire Closio agent itself when we are trying to config the user"; "yess that works"), asked before the download.
  - **QMetry** test cases can't be read through the Jira tools (only the QMetry panels show on the card); an export the user gives is saved as markdown in the run folder and used as a benchmark (user, for SCRUM-523: "use the test cases as the benchmark"). **Changed 2026-10-18:** optional, never asked for; with an export its cases are the base and the result has one coverage line; without, the cases come from the card and the code (see Status).
- **Why:** User decisions.
- **Rejected options:**
  - Writing the Playwright tests in `flow-develop`: they're written and run by `flow-verify` (D65).
  - A separate one-time Playwright setup command: it's part of `flow-configure-user`.
  - Sending the card back to `flow-develop` by itself on a failure (Claude's first draft): the user decides.
  - A new repo-file field naming WS1's `.env` keys for WS2 calls (Claude's first recommendation): the saved keys are used instead.
  - Building the web part later as C4b (Claude's recommendation): the user wanted it now.
  - Test cases on `main`: they live in the card's run folder.
- **Built (2026-10-18):** `.agents/skills/flow-verify/` and `.agents/skills/flow-ac-check/` (+ Codex files, Claude links); agents `flow-ac-checker` and `flow-story-check` (Claude Code and Codex); `scripts/repo-run.sh` `start` / `stop` / `status` / `all stop`; `scripts/api-call.sh`; `scripts/api-check.sh`; `scripts/db-run.sh` + `scripts/lib/db-run.js` (the repo's own sequelize-cli config and `pg`, one transaction); `scripts/e2e.sh`; `scripts/qmetry-import.sh` + `scripts/lib/xlsx-to-md.py`; `scripts/lib/repo-info.sh` (shared repo facts); `e2e/` (`package.json`, `playwright.config.ts`, `fixtures.ts` with the login from the web app's `Login.vue` test IDs); the `playwright` item of `flow-configure-user`; `flow-doctor`'s "Checking web cards"; `flow-develop`'s way back from verify; settings `SERVER_START_TIMEOUT`, `API_CALL_TIMEOUT`, `WS1_REPO`, `WS1_APP_VERSION`, `WS1_NAPP_PK`, `WS1_CLIENT_TYPE`, `WEB_REPO`, `E2E_TIMEOUT`; pre-approvals in both tools.

<a id="d68"></a>
### D68 — `flow-verify` offers two ways: A full check or B quick check; every run is recorded
- **Date:** 2026-10-18
- **Status:** Accepted. **Built 2026-10-18** after "Yes, build the final draft now, with option B also running the repo tests"; my tests passed (see "Built"); the user's tests are pending. **2026-10-18 ([D69](#d69)):** web cards, in both ways, ask which APIs are available on dev before any test is written, and mock the others. **Tested by the user 2026-10-18** on SCRUM-540 with B, the quick check: every AC ✅, a WS1 session from the dev login (D71), direct WS2 calls with WS1's pair, 3 test configs added and removed after a yes, the run recorded in `verify.md`.
- **Context:** the full check (D67) writes and saves test cases with an agent, which takes time and tokens (SCRUM-523: about 12 minutes, 40 steps). The user's own way of checking a card is to call each AC's scenarios directly and compare the errors and the response with the card (user: "I just want that according to what is mentioned in the card acceptance criteria, the code behaves the same way, returns the same errors, returns the same response structure… It doesn't store the test cases… that saves a lot of time and token as well").
- **Decision:**
  - **The choice:** `/flow-verify <KEY>` asks **A — Full check** (D67 as it is) or **B — Quick check**; `full` or `quick` after the key skips the question (user: "works").
  - **B:** the AI works out each AC's scenarios from the card and the code (every error the code returns with its status, `error_code` and message; WS1's statuses through WS1; the response fields) and checks them against the running code with `api-call.sh`; no test cases saved, no QMetry (a typed export isn't used, and it says so; user: "yess"), no story check; **the repo tests run again** (user: "yes").
  - **B on web cards:** one-off Playwright tests in `local/quick-checks/<KEY>/` (on this Mac only, git-ignored), run with `e2e.sh quick`, removed at the end with `run.sh quick-clean` (user: "this works but make sure you record the testing was done and what were the results").
  - **B reads the database** after a call that writes, to check what it wrote: `db-run.sh <repo> query` runs the SQL in a read-only transaction (the database refuses any change; COMMIT, SET and the like are refused first), so it needs no yes (user: "you can connect to the Db and get the results of the test").
  - **Calls that write** (`POST`, `PUT`, `PATCH`, `DELETE`), in A, B and `flow-ac-check`: listed with the cleanup SQL that removes what they create, and sent only after a clear yes (user: "yes this works"); A's cleanup now also removes the rows its write cases create (user: "yesss").
  - **Every run is recorded** in `verify.md`, newest first, never overwritten: `## Run <n> — <date and time> · A full check | B quick check | flow-ac-check AC <n>`, with every case or scenario tested and its result (user: "record the testing was done and what were the results in case of testing or multiple testing"). `flow-develop` reads the newest run's failures.
  - **Fixes found in the SCRUM-523 test, built with it:** `e2e.sh run <KEY> <AC>` filters on `AC <n> — ` (Playwright matches project + file + title, so `^AC <n> ` matched nothing) and shows ❌ when no test ran (it showed ✅); Playwright's color codes are removed from its error lines; `flow-ac-checker` limit 40 → 60 steps (D47).
- **Why:** user decisions; B saves the agent's time and tokens while still checking every AC, and the run record keeps what was tested.
- **Rejected options:**
  - B for backend cards only, the web part through A (Claude's recommendation): the user chose one-off Playwright tests in B too.
  - B without the repo tests: the user wanted them run again.
  - Asking for a yes before every database read: a read-only transaction can't change anything.
  - Overwriting `verify.md` on every run: every run is kept.
- **Built (2026-10-18):** `.agents/skills/flow-verify/SKILL.md` (the choice, B's steps, run sections); `.agents/skills/flow-ac-check/SKILL.md` (write calls, its run recorded); `.agents/skills/flow-develop/SKILL.md` (the newest run); both `flow-ac-checker` files (cleanup of write calls, 60 steps); `scripts/db-run.sh` + `scripts/lib/db-run.js` (`query`); `scripts/e2e.sh` (`quick`, the filter, no tests = ❌, no color codes); `scripts/run.sh` (`quick-clean`).

<a id="d69"></a>
### D69 — Web cards: the APIs first; an API that isn't on dev is mocked with the user's exact 200 response
- **Date:** 2026-10-18
- **Status:** Accepted. **Built 2026-10-18** after "go ahead"; my tests passed (see "Built"); the user's tests are pending.
- **Context:** a web card's screen calls APIs on the dev environment through the web app. When an API isn't there yet (its backend card not merged, a service down), every test on that screen fails or times out, though the screen itself may be right (user: "when the API is not available on the front end, I want you to mock the APIs and then use them directly so that the integration on the front end can be tested end to end without even being dependent upon the APIs that are not working").
- **Decision:**
  - **The APIs first, before any test is written** (A, B and `flow-ac-check`; user: "before writing test cases figure out the api's required and then ask the user about the apis"): the AI lists the APIs the card's screens call from the web app's code (method, path, the name of the variable its base comes from) in `api-list.json`, and asks **"Which of these APIs are available on the dev environment right now?"**; **every run asks again**, the mocked ones too (user: "yes every later check should ask").
  - **An unavailable API is mocked in that run, with the exact 200 response object the user sends** (user: "dont assume anything here just ask the user to send you the exact 200 response object, error responses you can derive from the frontend code itself"); kept in `api-mocks.ts` (A: the run folder; B: `local/quick-checks/<KEY>/`), asked for once per API.
  - **One mock per API, switched on per run** (user: "this works"): tests call `useApiMocks(page, apiMocks)` and compare the screen with whatever the API answered, so the same test runs against the real API or the mock; `e2e.sh run|quick … --mock <names>` turns mocks on for the APIs the user said aren't available.
  - **The API check before the run** (user: "before running the test cases i will prefer you to put these checks so that we save the run time"; "this as suggested works"): `e2e.sh probe` logs in once and calls each GET API that isn't mocked, through the logged-in browser; flagged: no answer, 502/503/504, a 500 whose `error_code` says WS1 can't reach the service behind it (`ECONNREFUSED` and similar), and WS1's "route not found" (its `catch404NotFound` → 597 with `GENERAL_ERROR`); a flagged API is asked about again. APIs that write are never called by the check. The web app's `VITE_` values are read by the check itself and never shown (A6).
  - **After the run:** `e2e/fixtures.ts` notes every API call that got no answer or a 5xx from the real server (calls the test answers itself, and calls the browser cancels, aren't noted); `e2e.sh` lists them under failing tests, the card's APIs first and other screens' calls apart; the AI asks about each of the card's (user: "just this gets flagged"). Not available → mocked and those ACs run again; available → a failure with a suggestion (user: "works").
  - **Recorded in `verify.md`**, per run: each API real or mocked, with the user's answer and the check's result (user: "yess").
- **Why:** user decisions; the screen gets tested end to end even when its backend isn't on dev, and nothing about the API's answer is assumed.
- **Rejected options:**
  - Flagging failed calls only after the tests ran (Claude's first draft): the user wanted the APIs asked about before any test is written, and a check before the run.
  - Realistic made-up mock data (Claude's recommendation): the 200 body is the exact object the user sends.
  - Keeping a saved test's mock for good once set (Claude's recommendation): every later check asks again, so mocks are switched per run.
  - Rewriting the tests on every check to add or drop a mock: slower and more tokens.
  - Calling APIs that write in the check: it could change data; the user's answer covers them.
- **Built (2026-10-18):** `e2e/fixtures.ts` (`useApiMocks`, the `ApiMock` type, the API watcher on the `loggedIn` fixture); `e2e/probe/api-probe.spec.ts` (the check); `scripts/e2e.sh` (`probe`, `--mock`, the failed-call list split by the card's `api-list.json`); `.agents/skills/flow-verify/SKILL.md` (step 4 the APIs first, step 6 the check and the questions after the run, `### APIs` in `verify.md`); `.agents/skills/flow-ac-check/SKILL.md`; both `flow-ac-checker` files.

<a id="d70"></a>
### D70 — `flow-push` (C5): rebase, the commits the user approves, one push per repo creating the MRs, Code Review
- **Date:** 2026-10-18
- **Status:** Accepted. **Built 2026-10-18** after "Yes, build C5 flow-push as drafted, with MRs titled SCRUM-<n>: <card title> and opened ready for review"; my tests passed (temporary git repos, a fake GitLab server); the user's first run is pending (the first real MRs on the Japfa GitLab). **Tested by the user 2026-10-18** on SCRUM-540: rebase without conflicts, the tests again, 5 atomic commits approved (hooks passed), MRs !248 (WS2) and !561 (WS1) created by the push, assigned (`merge_request.assign` works on the Japfa GitLab), descriptions set through the API; GitLab's Jira link did **not** show the MRs on the card, so the comment was added; Code Review (transition id 31).
- **Context:** Phases 7 and 8 had their decisions (G2–G4, D10, D11, D31, D32, D48, D51) but no command; open points were the MR title and description, the husky coverage gate on every commit, and how commits are split.
- **Decision:**
  - **`flow-push <CARD-KEY>`** (typed only; for a verified card): VPN, stash → rebase → stash pop per repo (`card-branch.sh rebase`; a conflict waits for the user, then `rebase-continue`), the repo's tests again, the atomic commits, the MRs, ✋ the final yes, one push per repo, the description and reviewers, Jira, save.
  - **Commits:** proposed by the AI per repo, **each layer's code with its own tests** so each commit stands on its own; ✋ the user approves the list (user: "yess"). Messages `SCRUM-<n>: <what this commit does>`, as the team's recent card commits (user: "yesss").
  - **The husky coverage gate runs on every commit** in ws2targetsalesincentive, ws2notification, ws2pricingengine: slower, never skipped (user: "yess", option a).
  - **MR:** title `SCRUM-<n>: <card title>`, opened **ready for review** (user: "with MRs titled SCRUM-<n>: <card title> and opened ready for review"), target `mr_target_branch`, assigned to the user; labels and reviewers from the repo file, confirmed or changed each time; reviewers set through the API because push options can't (user: "yess").
  - **MR description:** only the Jira card's link and title, and the migrations and seeders to run (user: files by layer, ACs covered, error-code differences "These can be removed"; how it was verified "can be removed as well"). The ruleset's Step 9 and checklist changed to match (A19).
  - **Jira:** GitLab's own Jira link usually shows each MR on the card; `flow-push` checks, adds one comment for any missing MR link, then moves the card to Code Review (user: "this works"); the comment tool is pre-approved.
  - **Scripts:** `scripts/ship.sh <repo> status | commit | push` and `scripts/gitlab-mr.sh <repo> find | describe`; `card-branch.sh rebase | rebase-continue`; `run_in_repo` moved to `scripts/lib/repo-info.sh` so `ship.sh` reuses it (no copy); setting `GITLAB_API_TIMEOUT`.
- **Why:** user decisions; every commit and the push are approved by the user, the hooks always run, and the token never leaves the scripts.
- **Rejected options:**
  - Skipping the hook on all commits but the last (`--no-verify`): it skips a team hook.
  - Tests in a commit of their own at the end: each commit should stand on its own.
  - Conventional messages `feat(SCRUM-<n>): …`: the team's card commits use `SCRUM-<n>: …`.
  - Draft MRs: opened ready for review.
  - A longer MR description (files by layer, ACs covered, error-code differences, how it was verified): removed by the user.
- **Built (2026-10-18):** `.agents/skills/flow-push/` (+ Codex file, Claude link); `scripts/ship.sh`; `scripts/gitlab-mr.sh`; `scripts/card-branch.sh` (`rebase`, `rebase-continue`); `scripts/lib/repo-info.sh` (`run_in_repo`, `last_output`, `result_lines` moved from `repo-run.sh`); `config/project-settings.sh` (`GITLAB_API_TIMEOUT`); pre-approvals in both tools; the `flow-help` Cards group; the ruleset's Step 9 and checklist.

<a id="d71"></a>
### D71 — WS1 logins go to the dev WS1; its session cookie is used on the WS1 on this Mac (rule A24)
- **Date:** 2026-10-18
- **Status:** Accepted. **Built 2026-10-18** after "go ahead and make this change in your code and make this a rule as well for login"; tested with fake servers and live (the dev login with the Keychain login, then SCRUM-540's endpoint on the WS1 on this Mac: the session was accepted under its own cookie name).
- **Context:** in the user's `/flow-verify SCRUM-540` test, the login on the WS1 on this Mac failed (401 INVALID_CREDENTIALS): its `.env` sends logins to another auth service than dev. The same login on the dev WS1 succeeded, with no `data.token` (client_type web = a cookie session), which `api-call.sh` required.
- **Decision:**
  - **Every WS1 login for a check goes to the dev WS1 login URL** (`WS1_LOGIN_URL` = `https://dev-closio-ws1-apiprivate.japfacomfeed.co.id/api/v1/login`) with the WS1 login saved in the Keychain; never to the WS1 on this Mac (user: "Always hit the dev URL with the credentials saved in the keychains"; "Use just the dev URL for login, and then you can just use local ones for testing").
  - **The session cookie it returns is used for the calls to the WS1 on this Mac**: every dev cookie under its own name first; if that WS1 answers that the session isn't there (401 SESSION_EXPIRED, INVALID_TOKEN or UNAUTHORIZED), the session cookie once more as `closio_session_local` (`WS1_LOCAL_SESSION_COOKIE`); the way that works is remembered; still refused: one fresh dev login, both ways again, then a ⚠️ (user: "You need to use the cookie itself, which is returned on the dev URL. It will work. If not, then use closio_session_local the cookie key and try once again").
  - **A login without a token is fine** (web); a token, when a login returns one, is still sent.
  - Rule **A24**, `AGENTS.md` rule 19.
- **Why:** user decision; the user's local WS1 reads the dev sessions, so one dev login serves the checks on this Mac.
- **Rejected options:**
  - Logging in on the WS1 on this Mac (the old way): its auth service differs from dev on the user's Mac.
  - Claude's caution that a dev cookie can't open a session locally (each WS1 keeps sessions in its own Redis): the user's local WS1 shares them; the ⚠️ and the fix line stay for a Mac where it doesn't.
- **Built (2026-10-18):** `scripts/api-call.sh` (`login` on `WS1_LOGIN_URL`, the cookie header per call, the `closio_session_local` retry, the fresh login once); `config/project-settings.sh` (`WS1_LOGIN_URL`, `WS1_LOCAL_SESSION_COOKIE`); `scripts/configure-user.sh` (the WS1 login is the dev login).

<a id="d72"></a>
### D72 — `flow-finish` (C6): merged, deployed on dev (the user says), the checks on dev, the deployment doc in the run folder and on the card, Ready for Test
- **Date:** 2026-10-18
- **Status:** Accepted. **Built 2026-10-18** after "Yes, build C6 flow-finish now, as drafted"; my tests passed (fake servers, a temporary registry); the user's tests are pending. **Added 2026-10-18:** `/flow-setup-repo <repo> dev-address [<url>]` and `/flow-setup-repo all dev-address` set or change only the dev address, in seconds, without the full setup and without a clone (user: "provide a specific attribute for the repository setup command so that I can specifically update that one uh, dev address"; then "the option is called dev-address, and add the all form too"); `configure-repo.sh dev-url <repo|all>` lists them, `set-dev-url` says the old and the new one; the fix lines of `flow-doctor`, `api-call.sh` and `e2e.sh` point to it.
- **Context:** Phase 9 had decisions (D11, D12, D22, D37, D38) but no command; the dev checks need each repo's dev address, which wasn't stored anywhere.
- **Decision:**
  - **`flow-finish <CARD-KEY>`** (typed only; for a pushed card): every MR merged (`gitlab-mr.sh status`; one open: stop); the user says it's deployed on dev ("the user tells in the chat window, no integration for this"); the checks on dev; the user's special instructions; the deployment doc; Jira; save.
  - **The checks on dev are the quick check (B)** with `--env dev` ("go with b"): WS1 with the dev login (A24), direct WS2 calls with WS1's pair (D37), web cards on the dev web app; test data and calls that write after a yes (A23); a new run in `verify.md`.
  - **Dev addresses:** a new field `dev_base_url` in the **shared** repo file ("saved repository file not on local"), asked by `flow-setup-repo` when missing ("ask these as well in the setup repo command for each repo"), saved with `configure-repo.sh set-dev-url`; `api-call.sh`, `api-check.sh`, `e2e.sh` get `--env dev`; `flow-doctor` warns when one is missing.
  - **The deployment doc** (`runs/<KEY>/deployment.md`): the deploy order; per repo the MR and merge commit, migrations (with rollback) and seeders (by file, never `db:seed:all`) to run, new `.env` variable names, after-deploy steps; **an API card: its APIs with the WS1 and WS2 dev URLs; a web card: a breadcrumb to the screen (from the web app's menu labels, the user may correct it: "okayy"); a consumer card: how to test it; the user's special instructions** (user: "it should also contain the api (working with ws1 and ws2 deployed urls) in case of an api card, for FE just a basic breadcrumb where to find the card and in consumer based card how to basically test that card or any special instructions that the user mentions"). The migrations and seeders it names are reviewed first (A23).
  - **It goes on the Jira card as one comment** ("it will go on the JIRA card as well"), **edited in place** on a re-run ("works"); then **Ready for Test** (D11; never Blocked, A3).
  - **The run branch isn't merged into `main`**: it stays as the card's record (D38); `run.sh list` / `flow-status` show finished cards apart (user: "works").
- **Why:** user decisions.
- **Rejected options:**
  - Checking the deploy through GitLab's pipelines or the health URLs: the user says when it's deployed.
  - The dev addresses in each user's local file: they're the same for the team.
  - The full check's saved cases on dev: B is the dev check.
  - Merging the run branch into `main` (D61's first plan): run folders stay out of `main`.
  - The deployment doc only in the run folder (D12's first answer): it goes on the card too.
- **Built (2026-10-18):** `.agents/skills/flow-finish/` (+ Codex file, Claude link, `flow-help` Cards group); `scripts/gitlab-mr.sh` (`status`); `scripts/api-call.sh`, `scripts/api-check.sh`, `scripts/e2e.sh` (`--env dev`; a dev call needs no local clone); `scripts/configure-repo.sh` (`set-dev-url`, the field in `detect`, `validate`, `show`); `scripts/lib/repo-info.sh` (`repo_dev_url`); `scripts/doctor.sh` (a missing dev address); `scripts/run.sh` (finished cards apart, not counted); `flow-setup-repo` (asks the dev address); `flow-push` (its last line).

<a id="d73"></a>
### D73 — `flow-autocomplete`: Claude Code suggests each flow command's options while you type, read live from the project
- **Date:** 2026-10-18
- **Status:** Accepted. **Built 2026-10-18**; my tests passed (see "Built"); the user saw a test version's rows in the desktop app's chat, and **tested the real one in a Claude Code terminal session the same day** ("I restarted claude in the terminal and the suggestions show for the flow commands").
- **Context:** The `argument-hint` lines ([D60](#d60) note) only show a hint; Claude Code has no list of argument values for a skill. A Claude Code mod can add rows to the prompt box's suggestions (`prompt.autocomplete`). A test mod's rows showed in the desktop app's chat (user: "Node was shown in the chat").
- **Decision:**
  - **A mod committed in closio-agent, `.claude/skills/flow-autocomplete/`**, so Claude Code loads it by itself in every session started in this folder, in a terminal or in the desktop app's chat, for everyone who clones closio-agent: no install, only the folder's trust question once (user: "Can you enable these mods uh, always for any session run in this folder?"; "My initial requirement was to work it with Claude code terminal as well as the chat").
  - **Every command** ("yes for all commands it should work"), **live, never a fixed list** ("I want it to be dynamic, not the static"): a command's options come from its own `## Usage` block; repos from `config/repos/`; card keys from `runs/` and the run branches; `flow-configure-user`'s items from its Usage line; command names from `.agents/skills/`; memory ids from `local/memory/`; memory phases from `scripts/memory.sh`; a repo's dev keys from its repo file; card files from `local/cards/`. A new command, repo or card shows at once.
  - **Only the word**, no note beside it ("I don't want the note").
  - `/flow-doctor` checks the mod's files are there.
- **Limits (Claude Code's):** the rows come once a letter of the option is typed (the prompt box asks for the word at the caret, never empty); Codex has nothing like it.
- **Rejected options:**
  - Hints only (`argument-hint`): kept, but they can't be picked.
  - A plugin installed per person (marketplace, project scope) or `CLAUDE_CODE_PLUGIN_DIRS`: an install step for everyone, or not tied to this folder.
  - The dim note beside each row: the user didn't want it.
- **Built (2026-10-18):** `.claude/skills/flow-autocomplete/` (`.claude-plugin/plugin.json`, `hooks/hooks.json`, `hooks/register.ts`, `hooks/register.test.ts`); `.gitignore` (the files Claude Code generates in a mod folder); `scripts/doctor.sh` (one line). `claude plugin validate` passed; `claude plugin test` 8 of 8; `claude plugin list` in this folder: `flow-autocomplete@skills-dir`, project, loaded; a headless session's debug log: `hooks module flow-autocomplete@skills-dir loaded … events: prompt.autocomplete`.

