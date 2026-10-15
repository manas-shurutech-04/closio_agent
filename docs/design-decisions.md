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
- **Status:** Accepted. **`agent-rules.md` added on 2026-10-15** (user): every agent rule (G1–G4, A1–A14) in one table, so colleagues find them in one place.
- **Context:** Team documentation needs a fixed home and structure for existing and new team members.
- **Decision:** `docs/` contains `README.md`, `setup-guide.md`, `commands.md`, `design-decisions.md`, `architecture.md` and `changelog.md` (all six exist since 2026-10-10), plus `agent-rules.md` (since 2026-10-15). Each file is created only once there is real content for it. `docs/README.md` lists all of them with their status.
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
- **Status:** Accepted
- **Context:** G2 requires rebasing onto the base branch before every push, and git won't rebase with uncommitted changes.
- **Decision:** VPN → stash → fetch and rebase → stash pop → conflicts resolved by a person → re-run checks → atomic commits → single push.
- **Why:** User decision.
- **Rejected options:**
  - Atomic commits first, then rebase (suggested by Claude): not chosen by the user.

<a id="d11"></a>
### D11 — Jira statuses used by the agent
- **Date:** 2026-10-09
- **Status:** Accepted
- **Context:** Project `SCRUM` (Closio) has the statuses To Do, In Development, Code Review, Blocked, Ready for Test, Testing, QA - Passed and Production (checked through Jira).
- **Decision:** The agent uses only To Do (pickup), In Development, Code Review and Ready for Test. "Backlog" is a tab, not a status, so a card in it counts as To Do.
- **Why:** Blocked is for QA only. Production is excluded for now. Testing and QA - Passed are QA's stages.
- **Rejected options:**
  - Moving the card to Blocked on a merge conflict: Blocked is for QA only.

<a id="d12"></a>
### D12 — The deployment doc is a file in the card's run folder, created by a user-run command
- **Date:** 2026-10-09
- **Status:** Accepted
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
- **Status:** Accepted. The details of the testing phase are partly open.
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
- **Status:** Accepted
- **Context:** The story-verification agent in Phase 6 overlaps with the Phase 5 AC check. Claude suggested merging them into one phase.
- **Decision:** Keep two phases. Each uses its own specialised custom agent(s).
- **Why:** User decision.
- **Rejected options:**
  - Merging Phases 5 and 6 into one "Verify & test" phase (suggested by Claude).

<a id="d20"></a>
### D20 — Test credentials are per person and stored in the macOS Keychain
- **Date:** 2026-10-09
- **Status:** Accepted; **amended by [D34](#d34)** (WS2 client ID/secret come from each repo's `.env`, not the Keychain; the FE and WS1 logins are confirmed to be different).
- **Context:** Testing needs credentials. FE: a login ID and password. BE: the WS1 session cookie (from the login API) and WS2 client ID and secret, for local and for the dev environment.
- **Decision:** Asked for once during setup and stored **per person in the macOS Keychain**. Scripts read the values at run time, so they never enter the AI conversation or any file. The BE cookie is fetched from the WS1 login API using the stored login ID and password (endpoint in [architecture.md](architecture.md#phase-6--developer-testing-d18)).
- **Why:** User decision. Same secret-handling principle as D15.
- **Rejected options:**
  - Shared team credentials: the credentials are per person.
  - Storing them in config files: they could leak or be committed.

<a id="d21"></a>
### D21 — Local test environment: local Redis and RabbitMQ, dev PostgreSQL
- **Date:** 2026-10-09
- **Status:** Accepted; **amended by [D34](#d34)** (dev PostgreSQL credentials come from the repository's `.env`).
- **Context:** BE tests and local runs need PostgreSQL, Redis (also used by BullMQ) and RabbitMQ.
- **Decision:** **All Redis use** (BullMQ and anything else) points to a **local Redis**. **RabbitMQ** runs **locally**. **PostgreSQL** is the **dev database**, used directly.
- **Why:** User decision.
- **Rejected options:**
  - Tests cleaning up after themselves or running in rolled-back transactions on the dev DB (suggested by Claude): the user said this isn't a concern.
  - Using the dev Redis for caching: everything goes to the local Redis.

<a id="d22"></a>
### D22 — Testing on the dev environment happens after merge (Phase 9)
- **Date:** 2026-10-09
- **Status:** Accepted; **extended by [D37](#d37)** (dev-environment WS2 credentials per service in the Keychain).
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
- **Status:** Accepted
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
- **Status:** Accepted. **To be refined later** (user, 2026-10-14), when the Phase 2–6 rulesets are written. Each backend repo's registry file points to it; the web app has no rulesets yet ([D51](#d51)).
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
- **Status:** Accepted. Details confirmed by the user on 2026-10-09; feasibility tests passed the same day. **Built and tested in F3 (2026-10-11)**: all 12 live tests passed in Claude Code and Codex. Limits added by [D47](#d47).
- **Context:** GitLab, the dev API and the dev DB are only reachable over the VPN (D14, D27). The GitLab MCP server only connects if the VPN is up when Claude Code/Codex starts, and Claude Code can't reconnect a failed server without the user typing `/mcp` (D28).
- **Decision:** A dedicated **custom agent (subagent)** runs at the **start of every phase that needs the VPN or GitLab**. It connects the VPN and checks that GitLab is reachable. (Originally it also checked the GitLab MCP server; that check was removed by [D32](#d32).) Where something can't be automated, it asks the user (manual intervention is acceptable); push and similar commands also involve the user.
- **Why:** User decision. It keeps connection handling in one place and runs only when a phase needs it.
- **Confirmed details (user, 2026-10-09):**
  - **Phases:** it runs at the start of **every phase from Phase 1 to Phase 9**, and also within **`setup-repo`** in Phase 0. (Originally because `setup-repo` would clone the repos; cloning is now manual, [D53](#d53), but `setup-repo` still needs GitLab and the dev servers.)
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
- **Status:** Accepted; **amended by [D32](#d32)** (the full description is set through the REST API; GitLab MCP is no longer used).
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
- **Status:** Accepted
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
- **Status:** Accepted
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
- **Status:** Accepted. **Built in F5 (2026-10-14)** as `flow-configure-repo`; the details and format are in [D51](#d51).
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
- **Status:** Accepted
- **Context:** Claude proposed a per-user home folder `~/.closio-agent/` for the agent's memory, settings and Playwright project. The user wants **everything kept in this project folder**. It will be pushed to a git remote and cloned by the team, and the memory must be directly available to whoever clones it.
- **Decision:**
  - The skills, scripts, shared configuration, docs, build memory, the Playwright project (D24) and the **per-card run folders (`runs/<CARD-KEY>/`)** all live in this project folder.
  - Run folders are **committed and shared** through git, so a teammate who pulls can see, and continue, a card's history.
  - **Never-commit rule:** nothing in a run folder or any committed file may contain secrets or `.env` values (D33, D34, A6).
  - Per-user settings (e.g. GitLab username, local repo paths) can't be shared, so they go in the git-ignored `local/` folder (confirmed in [D39](#d39); built: `local/user-settings.sh` in F4, `local/repos/` in F5).
- **Why:** User decision. One place for everything; new joiners get the full context by cloning.
- **Rejected options:**
  - `~/.closio-agent/` per-user home folder (suggested by Claude): memory wouldn't travel with the clone.

<a id="d37"></a>
### D37 — Dev-environment WS2 client credentials are stored per service in the Keychain
- **Date:** 2026-10-09
- **Status:** Accepted
- **Context:** The repos' `.env` files hold **local** credentials only (D34), but Phase 9 tests on the dev environment (D22).
- **Extended by [D51](#d51) (2026-10-14):** each repo's registry file now lists which dev keys it needs, including optional dev database user and password and extra named keys, all named `closio-agent.<repo>.<key>.dev`.
- **Decision (option b):** for each WS2 service, the **dev** client ID and secret are personal Keychain items named `closio-agent.<repo>.ws2-client-id.dev` and `closio-agent.<repo>.ws2-client-secret.dev`, added the same way as other secrets (D33). Phase 9 can then test both through dev WS1 (login cookie) and directly against each WS2 service.
- **Why:** User decision. Allows direct WS2 checks on dev.
- **Rejected options:**
  - (a) Testing on dev only through WS1 with the login cookie (recommended by Claude as simpler): no direct WS2 checks.

<a id="d38"></a>
### D38 — Run folders are kept after the card is done, and any teammate can pick up a paused card
- **Date:** 2026-10-09
- **Status:** Accepted
- **Context:** The run-folder draft asked what happens after Ready for Test, and whether a card belongs to one person.
- **Decision:** A card's run folder is **kept** (not archived or deleted) after the card reaches Ready for Test. **For now, any teammate may pick up another person's paused card**, continuing from its shared run folder (D36).
- **Why:** User decision.
- **Rejected options:**
  - Archiving to `runs/_archive/` or deleting finished run folders.
  - Restricting a card to the person who started it.

<a id="d39"></a>
### D39 — Repository layout of closio-agent (foundation step F0)
- **Date:** 2026-10-09
- **Status:** Accepted (created 2026-10-09). Local-path handling **approved by the user on 2026-10-10**. First commit and push on 2026-10-11 (see below). Built since: `config/repos/<repo>.yaml` (F5); in `local/`: `user-settings.sh` (F4), `repos/` (F5), `vpn/` (the openfortivpn log, F3); `local/memory/` comes with F6b.
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
- **Status:** Accepted (design approved by the user on 2026-10-10). Built as foundation step **F6b**, right after `setup-repo` (confirmed by the user on 2026-10-10). Not built yet.
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
- **Note:** the Claude desktop app doesn't start from a terminal, so nobody can type `nvm use v22` first there. The agent's scripts will have to switch to v22 themselves. This is handled when the scripts are built.
- **Finding (F1 test T3, 2026-10-10): Codex ignores `nvm use v22`.** Codex runs its commands through a **background service** (`codex app-server` daemon) that keeps running between sessions. On this Mac it was started at 12:48 with Node v18 first in its PATH, while the `codex` window itself had v22. So `$flow-doctor` reported v18 even after `nvm use v22`. **Fixed (user, 2026-10-10):** Codex was reinstalled **with npm inside Node v22** (`@openai/codex` 0.162.1), the Homebrew copy was removed, and the background service was restarted from a Node v22 terminal (`codex app-server daemon restart`). `$flow-doctor` in Codex then showed Node v22 ✅. Checked: the service now has Node v22 first in its PATH. Its separate updater process (running since 2026-10-09) still has v18, so if Codex ever falls back to v18 (e.g. after it updates itself), restart the service again. Not done: making Node 22 the Mac's default (`nvm alias default 22`), because it changes Node for every other project; kept as a fallback.

<a id="d42"></a>
### D42 — Claude Code and Codex are always started in the closio-agent folder; code repos are added as extra folders
- **Date:** 2026-10-10
- **Status:** Accepted. **Built:** `flow-configure-user`, `flow-configure-repo` and `flow-doctor` check that the session started in the closio-agent folder and stop with the fix if not (F2, F4, F5). **Still open:** how the code repos get added as extra folders (a launch option or a saved setting), decided with `flow-setup-repo` (F6).
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
- **Status:** Accepted. **Tested in F1 (2026-10-10):** Codex accepts the Claude-only line. The typed-only check (T4) first failed because the AI did the steps by hand; fixed by `AGENTS.md` ([D45](#d45)) and passed on re-test.
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
- **Status:** Accepted. **F1 T4 re-tested by the user on 2026-10-10 in new sessions: passed** in Claude Code and Codex (asked "check my setup", the AI pointed to the command instead of running the steps).
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
- **Status:** Accepted
- **Context:** `flow-doctor` (F2) and the coming VPN script (F3) need the same fixed values: Jira site and project key, GitLab address, VPN gateway, certificate pin and its expiry date, VPN DNS servers, Keychain item names. [D15](#d15) already said shared settings belong in the project config, not in each user's settings.
- **Decision:**
  - One committed file, `config/project-settings.sh`, holds these values. Scripts load it with `. config/project-settings.sh`.
  - It **never holds secrets** (those stay in the Keychain, [D33](#d33)).
  - Each value can be overridden from outside, which is how the scripts are tested without touching the Mac.
  - When a value changes (e.g. the VPN certificate is renewed), it's changed here once.
- **Why:** User decision. One place to change a value, so scripts can't disagree.
- **Added since:** `VPN_CONNECT_TIMEOUT` (F3, [D47](#d47)), `BRANCH_DESC_MAX_WORDS` (F5, [D50](#d50)).
- **Rejected options:**
  - Writing the values into every script: they would drift apart.
  - A `.env`-style file: those names are git-ignored and the AI must not read them (A6), which would be confusing for a file that is meant to be shared.

<a id="d47"></a>
### D47 — Each agent has its own limits, set in what it runs
- **Date:** 2026-10-12
- **Status:** Accepted
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
  - **Still asks:** changing the global git name or email (`set git-name`, `set git-email`) and every other command.
  - The commands must run the scripts exactly as written (`bash scripts/…`, no `cd`, nothing joined with `&&`), or the rules don't match.
  - Checked in Claude Code's docs (2026-10-13): a rule like `Bash(safe-cmd *)` doesn't approve `safe-cmd && other-cmd`, because each part of a joined command must match a rule on its own. Project allow rules only apply after the user trusts the folder.
- **Why:** User decision. Fewer interruptions without giving the AI a free hand: only our own scripts, and only the safe parts.
- **Rejected options:**
  - Auto mode: the user doesn't want it.
  - `allowed-tools` inside the command file: Claude Code clears that permission when the user sends their next message, and `flow-configure-user` asks questions in between, so the prompts would come back.
- **Not covered:** Codex's own way to pre-approve commands hasn't been checked yet.

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
- **Status:** Accepted. Built in F5.
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
  - **If nvm doesn't have that version, it is installed** (`nvm install <version>`). `flow-doctor` and `flow-configure-repo` warn (⚠️) with that command; `flow-setup-repo` (F6) will install it.
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
