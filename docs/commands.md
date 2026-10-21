# Commands

Every closio-agent command starts with **`flow-`** ([D43](design-decisions.md#d43)).

- **Claude Code:** type `/flow-<name>`
- **Codex:** type `$flow-<name>`, or pick it from `/skills`

Before you start: open a terminal **in the closio-agent folder**, run `nvm use v22`, then start `claude` or `codex` ([setup guide](setup-guide.md#how-to-start-claude-code-or-codex-every-time)).

## How the commands work

- **Written once, used by both tools ([D8](design-decisions.md#d8)).** Each command lives in `.agents/skills/<name>/SKILL.md`, where Codex reads it. Claude Code reads `.claude/skills/<name>`, which is a link to the same folder. `scripts/link-claude-skills.sh` creates any missing links.
- **They only run when you type them ([D44](design-decisions.md#d44)).** The tool never starts a command by itself. Claude Code: `disable-model-invocation: true` in `SKILL.md`. Codex: `agents/openai.yaml` in the command's folder. Also, the rules file `AGENTS.md` tells the AI not to do a command's steps by hand: if you ask for what a command does (e.g. "check my setup"), it tells you which command to type ([D45](design-decisions.md#d45)). Tested in both tools on 2026-10-10. This is an instruction, not a hard lock, so the tool still asks before running a script. **One exception ([D61](design-decisions.md#d61), [D65](design-decisions.md#d65)):** `flow-develop` also starts when you ask in plain words to develop a card whose plan is approved (you name it, or it's the only card in the develop phase): `disable-model-invocation: false` in its `SKILL.md`, `allow_implicit_invocation: true` in its Codex file, and `AGENTS.md` rule 1 says when.
- **Your user memory is applied, every time ([D40](design-decisions.md#d40), [D56](design-decisions.md#d56), rules A7/A8).** Every command loads it first: the setup commands with `bash scripts/memory.sh for setup all`, `flow-check-card` and `flow-status` with `for pick-up all`, each card command with its own phase (`pick-up`, `develop`, `ac-check`, `ship`, `after-merge`) and again before every step, for the card's repos. Claude Code runs the first one by itself when the command loads; in Codex it's the command's first step. Team rules always win. See [`flow-memory`](#flow-memory).
- **Decisions during a card are asked the grilling way ([D76](design-decisions.md#d76), rule A26, `AGENTS.md` rule 22).** While a card command runs (`flow-start`, `flow-develop`, `flow-verify`, `flow-ac-check`, `flow-push`, `flow-review`, `flow-finish`, `flow-qa`), every question it asks you, and every prompt you give during it that changes the card's plan, code, tests, data, Jira or GitLab, follows [`rulesets/grilling.md`](../rulesets/grilling.md): the facts it can find are shown as "Found" lines (never asked); only real decisions are asked, in numbered rounds, each with a recommended answer that "yes" (or "yes to all") accepts; follow-up rounds until nothing is open; a summary and your confirmation before anything changes; the decisions recorded in the card's `decisions.md` (next bullet). Short answers, approvals and your questions go straight. Safety stops (migrations, test data, commits and push, Jira and GitLab changes) stay their own plain yes/no. Your memory can't soften it. `flow-grill` does the same on request.
- **Every decision on a card is recorded in its `decisions.md` ([D77](design-decisions.md#d77), rule A27, `AGENTS.md` rule 23).** One numbered row per decision (when, step, question, decided, who or why), written with `bash scripts/run.sh decide` the moment it's confirmed: your answers, your approvals and refusals at a stop, a memory entry that answered for you, a change you asked for. The card's other files keep only a one-line pointer ("decision 3"). Cards started before 2026-10-19 don't have the file.
- **Shared logic lives in `scripts/`.** The command tells the AI which script to run, so both tools do the same thing.
- **Every command follows the agent rules** in [agent-rules.md](agent-rules.md), e.g. every problem comes with the steps to fix it (A11).
- **Every command is in the help and in the guide (rule R17, [D60](design-decisions.md#d60)).** `flow-help` reads each command's `## Usage` block, Claude Code's `/` menu shows each command's `argument-hint` (its options, e.g. `[<repo-name>|all] [install | services | dev-address [<url>]]`) and, from the first letter of an option, suggests the words that fit, read live from closio-agent (`.claude/skills/flow-autocomplete/`, [D73](design-decisions.md#d73): the Usage block's options, repos, card keys, items, memory ids, dev keys, card files), [user-guide.md](user-guide.md) walks through every command in order (and is mirrored into a Claude artifact), and `flow-doctor` checks that nothing is missing.

**No approval prompts for our own scripts ([D49](design-decisions.md#d49), [D57](design-decisions.md#d57)):** every script the commands run (`configure-user.sh`, `configure-repo.sh`, `setup-repo.sh`, `memory.sh`, `doctor.sh`, `vpn.sh`, `wait-seconds.sh`, `branch-name.sh`, `card-check.sh`, `help.sh`, `run.sh`, `card-branch.sh`, `repo-run.sh`, `api-call.sh`, `api-check.sh`, `db-run.sh`, `e2e.sh`, `qmetry-import.sh`, `ship.sh`, `gitlab-mr.sh`, all their steps) runs without asking, and so does saving a card's text to `local/cards/` for `flow-check-card` and writing a card's run folder `runs/<CARD-KEY>/` for the card phases. **Claude Code:** the shared file `.claude/settings.json` (it applies once you've trusted the folder). It also pre-approves the **read-only Jira tools** the commands use through Claude's Atlassian connector (read a project or an issue, search issues, your account), so `flow-doctor`, `flow-configure-user`, `flow-check-card` and `flow-start` don't ask each session, and the two changes `flow-start` makes to a card (its status and its assignee, plus the sprint field) are pre-approved too ([D61](design-decisions.md#d61)), and so are `flow-push`'s move to Code Review and its comment with missing MR links ([D70](design-decisions.md#d70)), and `flow-finish`'s comment with the deployment doc (posted once, edited on a re-run) and its move to Ready for Test ([D72](design-decisions.md#d72)). Those rules name the connector as claude.ai registers it (`mcp__claude_ai_Atlassian_MCP__…`, setup guide section 3); any other change to Jira still asks. **Codex:** the shared file `.codex/rules/closio-agent.rules` (Codex's "rules", still experimental; they apply when Codex trusts this folder, and the scripts then run outside its sandbox). Anything else still asks.

## Command list

| Command | What it does | Status |
|---|---|---|
| [`flow-ping`](#flow-ping) | Checks that the flow commands are loaded in your tool | Built 2026-10-10 (F1). Works in Claude Code (CLI and desktop app) and Codex |
| [`flow-doctor`](#flow-doctor) | Checks your setup and tells you how to fix each problem | Built 2026-10-10 (F1, F2). Works in Claude Code and Codex. Later pieces add their own checks |
| [`flow-vpn`](#flow-vpn) | Connects, checks or disconnects the Japfa VPN | Built 2026-10-11 (F3). Tested in Claude Code and Codex |
| [`flow-configure-user`](#flow-configure-user) | Sets up your personal settings and your 5 secrets | Built 2026-10-12 (F4). Tested by the user |
| [`flow-configure-repo`](#flow-configure-repo) | Registers a repo, or sets it up on your Mac (path, dev keys) | Built 2026-10-14 (F5). Tested by the user (2026-10-15) |
| [`flow-setup-repo`](#flow-setup-repo) | Gets a repo ready to work on: Node version, packages, local Redis/RabbitMQ, `.env` check, tests, folder access, its dev address (or only the dev address: `dev-address`) | Built 2026-10-16 (F6). Tested by the user (2026-10-16) |
| [`flow-memory`](#flow-memory) | Shows and manages your user memory: the preferences and corrections every command follows | Built 2026-10-16 (F6b). Tested by the user (2026-10-16) |
| [`flow-check-card`](#flow-check-card) | Checks a Jira card (or a card in a `.md` file) against the team's card template and shows what to fix | Built 2026-10-17 (F7). Tested by the user (2026-10-17) |
| [`flow-help`](#flow-help) | Shows every flow command with what it does and how it's typed, or one command in full | Built 2026-10-17 (F8). Tested by the user (2026-10-17) |
| [`flow-grill`](#flow-grill) | Grills a plan, an idea or a card with you: facts found first, then rounds of real decisions with a recommended answer each, until nothing is open | Built 2026-10-19 (D76). Not yet tested by the user |
| [`flow-status`](#flow-status) | Where a card stands (phase, step, branch, what to type next), or every card in progress | Built 2026-10-17 (C1). Tested by the user (2026-10-17, on SCRUM-540) |
| [`flow-start`](#flow-start) | Picks up a Jira card and plans it: the card checked, In Development and assigned to you, a branch in every repo, the plan made from the code and approved by you | Built 2026-10-17 (C2). Tested by the user (2026-10-17, on SCRUM-540) |
| [`flow-develop`](#flow-develop) | Develops a planned card with you: the code and its unit tests from the approved plan, the repo checks, then your review | Built 2026-10-17 (C3). Tested by the user (2026-10-17, on SCRUM-540) |
| [`flow-verify`](#flow-verify) | Checks a developed card, a full check (saved test cases, the story check) or a quick check (straight against the code): every AC, the repo tests again; then the push, or what's wrong for you to decide | Built 2026-10-18 (C4, D68, D69). Tested by the user (2026-10-18, on SCRUM-540: the quick check); the full check and a web card's API questions not yet |
| [`flow-ac-check`](#flow-ac-check) | Adds or changes the test cases of one AC and runs them once | Built 2026-10-18 (C4). Not yet tested by the user |
| [`flow-push`](#flow-push) | Ships a verified card: rebase, the atomic commits you approve, one push per repo creating the MRs (description and reviewers set), the card to Code Review | Built 2026-10-18 (C5, D70). Tested by the user (2026-10-18, on SCRUM-540: MRs !248 and !561) |
| [`flow-review`](#flow-review) | While a pushed card's MRs wait for the merge: their state (approvals, conflicts, pipeline), a self-review of the code (the story and the basics: no redundant code, the right files), the reviewers' comments with drafted replies and tested fixes, sent only after your yes | Built 2026-10-19 (D78). Not yet tested by the user |
| [`flow-finish`](#flow-finish) | Finishes a card after its merge: the merge checked, every AC checked on dev once you say it's deployed, the deployment doc (run folder and Jira card), Ready for Test | Built 2026-10-18 (C6, D72). Tested by the user (2026-10-19, on SCRUM-540) |
| [`flow-qa`](#flow-qa) | QA's questions on a finished card: each checked against the card, its decisions, the merged code and dev; a drafted reply, a Bug card for a real bug, a new card for something the card never asked for; nothing posted or created without your yes | Built 2026-10-19 (D81). Not yet tested by the user |

**Every card phase now has its command** ([D61](design-decisions.md#d61)): `flow-start`, `flow-develop`, `flow-verify`, `flow-push`, `flow-review`, `flow-finish`, `flow-qa`, plus `flow-status`. See [architecture.md](architecture.md).

---

### `flow-ping`

**Purpose:** the quickest way to see that closio-agent is installed and its commands load in your tool. It changes nothing; the only thing it runs is the memory step every command starts with.

**Usage:**
```
/flow-ping SCRUM-123      (Claude Code)
$flow-ping SCRUM-123      (Codex)
```
The text after the command is optional. It's only echoed back, to show that typed text reaches the command.

**Output:**
```
flow commands are loaded in Claude Code
You typed: SCRUM-123
```

**If it doesn't work:** the command isn't in the `/` menu (Claude Code) or in `/skills` (Codex). Check that you started the tool in the closio-agent folder, then run `bash scripts/link-claude-skills.sh` (Claude Code only).

**Files:** `.agents/skills/flow-ping/`

---

### `flow-doctor`

**Purpose:** checks your setup and tells you exactly how to fix each problem. It only reads: it never changes anything, never asks for a password and never shows a secret.

**Usage:**
```
/flow-doctor      (Claude Code)
$flow-doctor      (Codex: approve running it with network access, so the GitLab checks can run)
```

**Symbols:** ✅ fine · ⚠️ worth a look (doesn't fail) · ❌ must fix. Every ⚠️ and ❌ comes with the steps to fix it (rule A11). Run it again after each fix.

**Checks:**

| Group | Check | Notes |
|---|---|---|
| Project | Started in the closio-agent folder | [D42](design-decisions.md#d42) |
| | Node v22 is active | [D41](design-decisions.md#d41). In Codex the fix also says to restart its background service |
| | Every flow command has its Claude Code link | [D8](design-decisions.md#d8) |
| | The suggestions while you type are in place (`.claude/skills/flow-autocomplete/`) | [D73](design-decisions.md#d73). Fix: `git checkout -- .claude/skills/flow-autocomplete` |
| | Rules file `AGENTS.md` is in place, and no `CLAUDE.md` stops Claude Code reading it | [D45](design-decisions.md#d45) |
| Tools | git installed, your name and email set | |
| | Claude Code installed inside Node 22, no other copy | ❌ if missing |
| | Codex installed inside Node 22, no other copy | Required only if your AI tools setting includes Codex; otherwise ⚠️ or "you don't use it" |
| | Codex background service runs on Node 22 | Only when it's running |
| | openfortivpn installed | [D14](design-decisions.md#d14) |
| | Docker installed (and running) | Only needed if you chose Docker for Redis or RabbitMQ ([D54](design-decisions.md#d54)): then ❌ if missing, ⚠️ if not running. Otherwise ✅ either way |
| VPN and GitLab | VPN on and GitLab reachable | "On" means GitLab answers, through openfortivpn **or** another VPN client such as the FortiClient app. ⚠️ if off: fine until you need GitLab |
| | GitLab token works (shows your GitLab username) | Only when the VPN is on. The token is read from the Keychain by the script and never shown |
| | VPN DNS file: present when openfortivpn is on, **gone** when the VPN is off | A leftover file stops the next connection ([D27](design-decisions.md#d27)) |
| | Old GitLab-only DNS file | ⚠️ "no longer needed" |
| | VPN certificate pin still valid | ⚠️ in the last 30 days, ❌ after 2027-02-03 |
| Personal settings | Jira account ID, GitLab username, workspace folder (exists), AI tools | Fix: `/flow-configure-user` ([D15](design-decisions.md#d15)) |
| Repos | The ruleset files are there (`rulesets/story-implementation-workflow.md` for backend cards, `rulesets/frontend-story-workflow.md` for web-app cards, rule A19); each registered repo: clone exists and points at the right GitLab project; its Node version is installed in nvm; its dev keys are stored | ⚠️ for repos not set up on this Mac, and ⚠️ (not ❌) for missing dev keys: they're only needed to test on dev. Fix: `/flow-configure-repo <repo>` |
| User memory | How many entries you have (never a warning when you have none); ⚠️ for lines in your memory files that aren't in the format | Fix: `/flow-memory` |
| Commands documented | Every flow command has its `## Usage` block (and its `argument-hint` when it takes arguments, and its Codex menu line), is in a `flow-help` group, its section in this file, its row in [user-guide.md](user-guide.md), and is covered by the guide's Claude artifact ("mirrored" line); and no rule file (`rulesets/`, `AGENTS.md`, `docs/agent-rules.md`) calls a built command "coming" or "not built yet" | Rule R17, [D60](design-decisions.md#d60), [D75](design-decisions.md#d75). Fix: add what's missing; update the artifact in Claude Code; change the line to say what's built now |
| Cards in progress | How many cards have a run folder or a run branch; ❌ for a broken run folder (no `state.md`, a missing line, a folder that isn't a card key) | [D61](design-decisions.md#d61). See them with `/flow-status` |
| Checking web cards | Playwright is set up (`bash scripts/e2e.sh check`) | ⚠️ when it isn't: run `/flow-configure-user playwright` |
| Repo setup | Each repo set up with `flow-setup-repo`: packages still installed, Claude Code can use its folder; one ⚠️ listing cloned repos not set up yet; the local Redis and RabbitMQ answer (when a set-up repo needs them) | Fix: `/flow-setup-repo <repo>` |
| Keychain | The 5 personal items exist | Names only; values are never read ([D33](design-decisions.md#d33)). Fix: `/flow-configure-user <item>` |
| Jira | The AI reads project SCRUM | Done by the AI, because only the AI tool has the Jira connection. The Jira connector can take a while to load when a session starts, so the AI waits and retries up to 3 times (about 30 s) before reporting ❌ |

**In Codex:** Codex runs commands in a sandbox (a closed box). There, the GitLab checks and the Codex background service check may show ⚠️ "can't check from inside Codex's sandbox". The tip says what to do: approve network access, or run `bash scripts/doctor.sh` in a normal terminal. Everything else works the same in both tools (tested 2026-10-11).

Later pieces add their own checks when they're built.

The fixed values it uses (GitLab address, VPN gateway, certificate pin, Keychain names…) come from `config/project-settings.sh` ([D46](design-decisions.md#d46)).

**Output example (shortened).** In Claude Code or Codex, the AI puts the script's formatted text (markdown) in its reply, and the tool draws it: a heading per section, one line per check, each problem in bold with its **Fix:** or **Tip:** under it, and commands in the tool's code color. The AI adds the Jira section and the last line. The text behind it:
```
## flow-doctor: checking your setup

### Project

- ✅ Started in the closio-agent folder
- ✅ Node v22.14.0 is active

### Tools

- ✅ Claude Code 2.1.302, installed inside Node 22
- ✅ Docker is installed (not running; you don't use it for Redis or RabbitMQ)

### VPN and GitLab

- ✅ VPN is on (openfortivpn) and GitLab is reachable
- ⚠️ **Can't check the GitLab token: it isn't in the Keychain yet**
  - **Tip:** See the Keychain section below.

### Keychain · names only, values are never read

- ❌ **`closio-agent.gitlab-token` is missing**
  - **Fix:** Run `/flow-configure-user gitlab-token` (Codex: `$flow-configure-user gitlab-token`). It asks for the value in a hidden macOS box.
  - Backup, in your own terminal (not the AI chat): `security add-generic-password -U -a "$USER" -s "closio-agent.gitlab-token" -w`

### Jira

- ✅ Jira works: project SCRUM can be read

**Result: 1 to fix, 1 to look at.** · Checked in Claude Code
```

**In a terminal** (`bash scripts/doctor.sh` typed by you): the same checks with real colors (cyan section headings, ⚠️ lines in yellow, ❌ lines in red, commands in yellow, the Result line red when something must be fixed, else green), each Fix or Tip wrapped under its line to the terminal's width (at most 100 characters). No colors with `NO_COLOR` set; when the output goes to a file or another program, it's the markdown text above (`DOCTOR_FORMAT=markdown`, `terminal` or `plain` picks one). The Jira check isn't there: only the AI can do it.

**If something is wrong with the check itself:** see the [setup guide](setup-guide.md#check-that-the-flow-commands-work) (for example, restarting Codex's background service; watch out for Codex's updater).

**Files:** `.agents/skills/flow-doctor/`, `scripts/doctor.sh` (you can also run it yourself in a terminal: `bash scripts/doctor.sh`; it then shows everything except the Jira check), `config/project-settings.sh`

---

### `flow-vpn`

**Purpose:** connects, checks or disconnects the Japfa VPN, so GitLab and the dev servers can be reached ([D14](design-decisions.md#d14), [D27](design-decisions.md#d27), [D30](design-decisions.md#d30)).

**Usage:**
```
/flow-vpn connect | status | disconnect      (Claude Code)
$flow-vpn connect | status | disconnect      (Codex: approve running it outside the sandbox)
```

| Action | What happens |
|---|---|
| `connect` | If GitLab already answers (through openfortivpn **or** the FortiClient app), it does nothing. Otherwise: **one** macOS password dialog, then the SSO login page opens in your browser (it may finish by itself). All admin steps happen in that one go: remove a leftover DNS file and the old GitLab-only one, start openfortivpn, wait for the tunnel, add the VPN DNS file. Then it checks GitLab. **The VPN stays on** until you disconnect |
| `status` | Only reads: on (and through which client), off, or a problem with its fix |
| `disconnect` | One password dialog: stops openfortivpn and removes the VPN DNS file. If you're on the FortiClient app instead, it tells you to disconnect there |

**If something goes wrong** it cleans up by itself and tells you what to do (rule A11):
- SSO login not finished in 3 minutes: openfortivpn is stopped and the DNS file removed.
- The VPN gateway's certificate changed (the current pin expires 2027-02-03): it shows the new fingerprint, to confirm with IT and put in `config/project-settings.sh`.
- Password dialog cancelled: nothing is changed.

**Output example:**
```
✅ VPN connected (openfortivpn). GitLab is reachable. It stays on until you run /flow-vpn disconnect
```

**Files:** `.agents/skills/flow-vpn/`, `scripts/vpn.sh` (you can also run it in a terminal: `bash scripts/vpn.sh connect`), `scripts/vpn-admin-steps.sh` (the only part that runs with admin rights; review changes to it carefully), `scripts/password-dialog.sh`. The openfortivpn log is `local/vpn/openfortivpn.log` (private, git-ignored).

**The connectivity agent:** `flow-connectivity` (`.claude/agents/flow-connectivity.md`, `.codex/agents/flow-connectivity.toml`) runs the same `connect` at the start of every phase that needs GitLab (Phases 1–9) and reports one line ([D30](design-decisions.md#d30)). You don't call it yourself.

---

### `flow-configure-user`

**Purpose:** sets up everything personal, step by step ([D15](design-decisions.md#d15)). It asks **only for what's missing**. Run it again any time.

**Usage:**
```
/flow-configure-user                (Claude Code)  everything that's missing
/flow-configure-user gitlab-token   just one item, e.g. after renewing your token
$flow-configure-user …              (Codex: approve running the secret steps outside the sandbox)
```

**What it sets up:**

| Item | How | Stored in |
|---|---|---|
| `jira-account-id` | Fetched by the AI from Jira, nothing to type | `local/user-settings.sh` |
| `gitlab-username` | Read with your GitLab token when the VPN is on; otherwise you type it | `local/user-settings.sh` |
| `workspace-dir` | You type the full path of an existing folder (no suggestion given) | `local/user-settings.sh` |
| `ai-tools` | Claude Code, Codex or both (`flow-doctor` uses it) | `local/user-settings.sh` |
| `vpn-username` | **Optional, not needed today** (the VPN uses SSO); skip it if you like | `local/user-settings.sh` |
| `git-name`, `git-email` | Read from git; asked only if missing | Your global git settings |
| `gitlab-token`, `fe-login-id`, `fe-login-password`, `ws1-login-userid`, `ws1-login-password` | A macOS message first says which one is next ("Copy it now, then click Continue"), then a hidden box opens to paste it into | macOS Keychain |
| `playwright` | **Asks you first** (a download of about 150 MB: the `@playwright/test` packages and the Chromium browser), then sets up closio-agent's `e2e/` folder; needed to check web cards with `flow-verify` ([D67](design-decisions.md#d67)). Say no and `/flow-doctor` reminds you | `e2e/node_modules/` (git-ignored) and your user's browser cache |

- **All missing secrets are asked in one go,** one after another (heads-up, then hidden box), so you approve only once, or not at all in Claude Code (see below).
- **Secrets never go through the AI chat,** a file or a visible command. Only "✅ stored" is shown. If you paste a secret in the chat by mistake, change that secret.
- **Start-folder rule:** it first checks that you started the tool in the closio-agent folder (D42) and stops if not.
- **Per-repo dev keys** for WS2 services come with `flow-configure-repo` (F5).
- At the end it shows your settings again; then run `/flow-doctor` for the full check.

**Output example (shortened):**
```
Personal settings (local/user-settings.sh, never pushed)
✅ Jira account ID: 712020:…
✅ Workspace folder: /Users/you/work
✅ VPN username: not set (optional, not needed today)
Keychain (names only, values are never shown)
✅ closio-agent.gitlab-token stored
❌ closio-agent.fe-login-id missing
   Fix: Run /flow-configure-user fe-login-id (Codex: $flow-configure-user fe-login-id)
Result: 1 to set up.
```

**Files:** `.agents/skills/flow-configure-user/`, `scripts/configure-user.sh` (you can run `bash scripts/configure-user.sh show` in a terminal too).

---

### `flow-configure-repo`

**Purpose:** the only way to add a repo to closio-agent ([D35](design-decisions.md#d35), [D51](design-decisions.md#d51)), and to set a registered repo up on your Mac. **The list of repos isn't fixed:** anyone can add a new repo at any time by giving the path of its clone; the 7 current repos are just the first ones.

**Usage:**
```
/flow-configure-repo                                 list the repos and their status on this Mac
/flow-configure-repo /full/path/to/a/clone           register a new repo for the whole team
/flow-configure-repo nodejs-ws2closio                set up a registered repo on this Mac
/flow-configure-repo nodejs-ws2closio key db-user    add or replace one dev key
/flow-configure-repo nodejs-ws2closio path /new/path   change where the clone is (a clone of another project is refused)
$flow-configure-repo …                               (Codex: approve the key steps outside the sandbox)
```

**Adding a brand-new repo later, step by step:**
1. Clone it yourself (cloning is always manual, [D53](design-decisions.md#d53)): on the VPN (`/flow-vpn connect`), run `git clone <GitLab address> <your workspace folder>/<repo>`. Or use a clone you already have.
2. Run `/flow-configure-repo <full path of that clone>`.
3. Answer the questions (one message); check the file the AI shows you and confirm.
4. Add your dev keys when it asks (optional ones can be skipped).
5. Commit the new `config/repos/<repo>.yaml` so the team gets it. From then on it shows in `/flow-configure-repo`, in `/flow-doctor`, and every later phase can use it.

Node repos get the most suggestions (read from `package.json`). Go repos get Go suggestions (`go mod download`, `go vet`, `go test`); any other kind of repo can still be added, with more answers typed by you.

**Registering a repo (once, for the team):** the AI reads the clone and **suggests** values (it never reads what's inside `.env` files). It asks you, in one message, for what it can't know and shows its suggestion next to each question:
- role, base branch (it can differ per repo), port and health URL (**required for every repo**; suggested from the repo's own health check)
- run and check commands
- migrations and seeders (the existing Sequelize pattern is kept; you say only if this repo differs)
- queues, local services (Redis, RabbitMQ, BullMQ)
- which repos it calls
- MR target branch, and optional default labels and reviewers (you confirm or change them each time an MR is created)
- dev keys, plus the optional dev database details

It shows you the whole file `config/repos/<repo>.yaml` and saves it only after you confirm. Then commit that file, so the team gets it.

**Setting it up on your Mac:** where your clone is (or "not cloned yet"), then the repo's dev keys. For each key, a macOS message first says which one is next ("Copy it now, then click Continue"), then a hidden box opens to paste it into. Optional keys can be skipped.

| Dev key (Keychain: `closio-agent.<repo>.<key>.dev`) | For | Required? |
|---|---|---|
| `ws1-client-id`, `ws1-client-secret` (WS1 only) | WS1's own pair, which it sends to the WS2s (`WS1_AUTH_CLIENT_ID` / `WS1_AUTH_SECRET_KEY` in WS1's `.env`); every direct WS2 call in the checks sends it, as WS1 does | Yes, for WS1 |
| `ws2-client-id`, `ws2-client-secret` | Only for a WS2 to which WS1 sends another pair (the pricing engine: WS1's `PRICING_ENGINE_*` pair); used instead of WS1's pair for that WS2 | Optional |
| `db-user`, `db-password` | Reading the repo's dev database (check migrations, write QA steps) | Optional |
| Any extra named key (e.g. a partner API key) | Whatever the repo needs | As registered |

**Each repo's own Node version (rule A13, [D52](design-decisions.md#d52)):** each repo file records `node_version` from the repo's Dockerfile (all 7 current repos: 22). The agent runs nothing in a repo before `nvm use <that version>`; if nvm doesn't have it, `flow-doctor` and `flow-configure-repo` show ⚠️ with `nvm install <version>`.

**Cloning is manual ([D53](design-decisions.md#d53)):** the agent never clones. If a repo isn't on your Mac, it gives you the `git clone` command and, afterwards, `/flow-configure-repo <repo> path <folder>`.

**Branch names** are one strict rule for every repo, not a repo setting (rule A12, [D50](design-decisions.md#d50)): `SCRUM-<number>/<short-description>`, at most 5 words. `bash scripts/branch-name.sh make SCRUM-519 "<card title>"` builds one; `check` checks one.

**`flow-doctor`** now has a **Repos** section: each repo's clone exists and points at the right GitLab project, and its required dev keys are stored. Repos you haven't set up show ⚠️, not ❌ (you may not work on all of them).

**Files:** `.agents/skills/flow-configure-repo/`, `scripts/configure-repo.sh`, `scripts/branch-name.sh`, `scripts/lib/secret-dialogs.sh` (shared with `flow-configure-user`), `config/repos/<repo>.yaml` (shared), `local/repos/<repo>.yaml` (yours).

---

### `flow-setup-repo`

**Purpose:** gets a registered repo ready to work on, on your Mac ([D54](design-decisions.md#d54)), or only sets a repo's dev address ([D72](design-decisions.md#d72)). It works only on a clone you made yourself (cloning is manual, [D53](design-decisions.md#d53)). It never switches branches, pulls, stashes or changes tracked files: the card phases do that. It needs no VPN.

**Usage:**
```
/flow-setup-repo                             each repo's setup state on this Mac
/flow-setup-repo nodejs-ws2closio            set up one repo
/flow-setup-repo all                         every repo cloned on this Mac, one after another
/flow-setup-repo nodejs-ws2closio install    the same, but always reinstall the packages
/flow-setup-repo nodejs-ws2closio services   choose Homebrew or Docker again for Redis and RabbitMQ
/flow-setup-repo nodejs-ws1closio dev-address          only the dev address: shows it, asks for the new one
/flow-setup-repo nodejs-ws1closio dev-address <url>    only the dev address: saves that one straight away
/flow-setup-repo all dev-address                       every repo's dev address at once; change the ones you want
$flow-setup-repo …                           (Codex: approve running it outside the sandbox)
```

**Only the dev address (`dev-address`, [D72](design-decisions.md#d72)):** sets or changes a repo's address on the dev environment (what `/flow-finish` checks on) in seconds: nothing else runs (no packages, tests, services, `.env` or folder access), and the repo needn't be cloned on this Mac, only registered. With a URL it's saved straight away; without one, the AI shows the current address and asks for the new one ("keep" leaves it). `all dev-address` shows every registered repo's address (or "not set"), and you send the new ones as `<repo>: <url>` lines; a repo you leave out keeps its address. You see `✅ <repo>: dev address saved …` or `… changed …, from <old> to <new>` (or "unchanged"); a URL that isn't a plain web address (or has a user or password in it) gets ❌ with an example, and nothing is saved. It's a shared file: commit `config/repos/<repo>.yaml` so the whole team gets it.

**What it does for each repo:**

| Step | What happens |
|---|---|
| Clone | Checks the clone is where you said, and is the right GitLab project. Shows its branch and uncommitted changes (only shows them) |
| Node | Switches to the repo's own Node version (`node_version`), and installs it with nvm if it's missing (rule A13). The script does this itself, so it also works in the Claude desktop app |
| Env file | Checks the repo's env file is there, by name only. If it's missing: where to get it, and the `cp .env.example …` way to start one. Then compares its variable **names** with `.env.example` (never the values): any missing ones are shown, the file opens in your editor, and you add them with the values from your team |
| Packages | Installs them (`install_command`) only when needed: no `node_modules`, or `package-lock.json` changed since the last install. `install` forces it |
| Redis, RabbitMQ | For repos that need them. Checks **both** a Homebrew and a Docker copy (starts Docker Desktop to look if it isn't running). One copy → uses it and tells you. Both → asks you once in a macOS dialog (the choice is saved in `local/user-settings.sh`) and stops the other one by itself. None → suggests Docker (`config/local-services.yml`; Homebrew if there's no Docker) and starts it only after your yes. For BullMQ repos it also checks Redis's `noeviction` memory setting |
| `.env` check | Reads `REDIS_HOST` / `REDIS_PORT` / `REDIS_USE_TLS` or `RABBITMQ_URL` from the repo's `.env` **itself** and says only whether they point to this Mac and whether that answers; **never a value**. If something doesn't match, it opens the file in your text editor and shows the exact lines to set. You change the file yourself ([setup guide §7](setup-guide.md#7-local-services-for-backend-tests)) |
| Tests | Runs the repo's test command once (not the coverage check), with a 15-minute limit (`SETUP_TEST_TIMEOUT`). Full output in `local/logs/setup-<repo>.log`; you see a short summary. Skipped for repos without tests ([D25](design-decisions.md#d25)) |
| Folder access | Adds the repo folder to your personal `.claude/settings.local.json` (`permissions.additionalDirectories`), so Claude Code can work in it. For Codex it shows the start command: `codex --add-dir "<repo>" …`. Then the AI checks that this session can really use the folder; if not, it asks you to give access (`/add-dir <folder>`, a new session, or Codex's start command) and waits (rule A15) |
| Dev address | When the repo file has no `dev_base_url`, the AI asks you for the repo's address on the dev environment and saves it with `configure-repo.sh set-dev-url` (a shared file: commit it so the team gets it; [D72](design-decisions.md#d72)). `/flow-finish` uses it for the dev checks. To change it later: `dev-address` (above) |
| Result | Saved in your private `local/repos/<repo>.yaml` (date and test result), so the status list shows it |

At the end, if it started Docker Desktop only to look and nothing uses it, it quits Docker again.

**Output example (shortened):**
```
━━ nodejs-ws2closio
✅ Clone: /Users/you/work/nodejs-ws2closio
   Branch: develop · 0 uncommitted change(s). Left as they are: the card phases handle branches.
✅ Node v22.14.0 (what nodejs-ws2closio is built for: 22)
✅ Env file: .env is there (its values are never shown)
✅ Packages already installed and up to date
✅ Local Redis: using Homebrew Redis 7.2.7, answering on port 6379
⚠️ nodejs-ws2closio/.env: REDIS_HOST points somewhere else, not to this Mac
   How to fix it (you change the file yourself; the AI never sees it):
   1. It's open in your text editor now: /Users/you/work/nodejs-ws2closio/.env
   2. Note down the old values first, if you'll need them again (e.g. for the dev server).
   3. Set these lines for your local copies:
        REDIS_HOST=127.0.0.1
        REDIS_PORT=6379
        REDIS_USER=
        REDIS_PASSWORD=
   4. Save, then run /flow-setup-repo nodejs-ws2closio again.
✅ Tests passed
   412 passing
✅ Claude Code can now use /Users/you/work/nodejs-ws2closio (added to your personal .claude/settings.local.json)
Result for nodejs-ws2closio: 0 to fix, 1 to look at.
```

**In Claude Code** it runs in the background, because it can take longer than the 10-minute limit of one command, and without an approval prompt (pre-approved, [D49](design-decisions.md#d49)). **In Codex**, approve it outside the sandbox (network for packages, Homebrew, Docker, macOS dialogs).

**Files:** `.agents/skills/flow-setup-repo/`, `scripts/setup-repo.sh` (you can run `bash scripts/setup-repo.sh list` in a terminal too), `config/local-services.yml` (Docker copies), settings in `config/project-settings.sh` (time limits, ports).

### `flow-memory`

**Purpose:** shows and manages your **user memory**: short entries with your preferences and corrections, which every flow command follows ([D40](design-decisions.md#d40), [D56](design-decisions.md#d56), rules A7/A8). It's private (`local/memory/`, never pushed), starts empty, and is created with your first entry. **Team rules always win over it.**

**Usage:**
```
/flow-memory                                   list all your entries
/flow-memory add Write plans as short numbered steps.          one entry for everywhere
/flow-memory add nodejs-ws2closio Put new tests in test/unit.  one entry for one repo
/flow-memory edit M3 <new text>                change an entry's text
/flow-memory edit M3 phases plan,develop       change where it applies
/flow-memory remove M3                         remove an entry
/flow-memory clear                             remove all your entries (shows them and asks first)
/flow-memory clear nodejs-ws2closio            remove only that repo's entries
$flow-memory …                                 (Codex)
```

When you add an entry, the AI asks once which **phases** it applies to (`all`, or some of `setup`, `pick-up`, `plan`, `develop`, `review`, `ac-check`, `testing`, `ship`, `mr`, `after-merge`) and the **card** it came from, if any, with a suggestion you can just confirm. If the entry goes against a team rule, it tells you which one and saves it only if you still want it (it never overrides the rule). Anything that looks like a secret is refused.

**Clearing:** `clear` first lists every entry it would remove and asks "Remove these N entries? This can't be undone." Only after your yes does it remove them (the files are deleted). Having no memory is normal; your next `add` starts it again.

**How it's stored:** `local/memory/general.md` (everywhere) and `local/memory/repos/<repo>.md` (one repo), one entry per line:
```
- [M3] 2026-10-16 · phases: plan, develop · from: SCRUM-519 · Write plans as short numbered steps.
```
You can also edit these files by hand; lines that aren't in this format are shown as ⚠️ and ignored.

**How every command uses it (never skipped):** each command starts with `bash scripts/memory.sh for <phase> all` (`setup` for the setup commands, `pick-up` for `flow-check-card` and `flow-status`, each card command its own phase), which prints only the entries that apply. **Claude Code runs it by itself when the command loads** (before the AI even reads the command); in Codex the command's first step tells the AI to run it, and `AGENTS.md` rule 9 repeats it. The AI follows the entries and says in one line which ones it used, e.g. "Using your memory: M2, M3". The card commands also run it again before every step, for the card's repos, and write the IDs they used in the card's `history.md`.

**Offered saves:** when you correct the AI during a flow command, it offers once to save the correction to your memory, and saves it only after your yes (`AGENTS.md` rule 9).

**Files:** `.agents/skills/flow-memory/`, `scripts/memory.sh` (you can run `bash scripts/memory.sh list` in a terminal too), `local/memory/` (yours).

---

### `flow-check-card`

**Purpose:** checks one Jira card against the team's card template ([jira-card-template.md](jira-card-template.md), [D58](design-decisions.md#d58)), so a card can be fixed before the agent picks it up. It only reads; it never changes the card in Jira.

**Usage:**
```
/flow-check-card SCRUM-567                  the card from Jira                      (Claude Code)
/flow-check-card local/cards/my-draft.md    a card that isn't in Jira yet (any .md file)
$flow-check-card …                          (Codex)
```

**What it does:**
1. Reads the card from Jira (key, summary, type, status, description) with the AI's Jira tools and saves its text, unchanged, to `local/cards/<CARD-KEY>.md` (private, never pushed). With a file, it uses the file as it is. No prompt in Claude Code: the Jira read tools, the script and the card file are pre-approved ([D57](design-decisions.md#d57)). In Codex, Jira is read through the Atlassian app on your ChatGPT account.
2. Runs `bash scripts/card-check.sh` on it and shows the result. Every ❌ comes with its fix (rule A11):

| ❌ not ready (the agent's pick-up stops and waits) | ⚠️ worth a look |
|---|---|
| `## Context`, `## How QA can test this` or `## Acceptance Criteria` missing | a QA step without "Expect" |
| no ACs; an AC heading not `**AC 1 — Title**`; AC numbers not 1, 2, 3… | deploy, migrate or restart steps in the QA section |
| an AC without Given, When and Then | "test after SCRUM-… lands"-style wording |
| an "Assumption:" line, `⟦…⟧`, TODO or TBD | a literal `\n` in the text |
| a "Files changed" or "AC self-check" table | out-of-scope lines outside `## Out of Scope` |
| QA section with no numbered steps; anything that looks like a secret | an AC that no QA step names ("(AC 3)") |
| an AC names an error (an HTTP 4xx/5xx status or `error_code`) but there's no `**Error reference**`; an Error reference without a "Raised by" column ([D82](design-decisions.md#d82)) | "can't trigger", "code review only" or "not testable by QA" wording |
| the card names an API (a method and a path) but has no `## API request and response`; an API there with no Response JSON, or a POST/PUT/PATCH with no Request JSON ([D84](design-decisions.md#d84)) | |

3. Adds one line for the card type: a Spike isn't picked up by the agent; for a Bug, missing sections are fine (you explain them at pick-up); a Subtask is picked up like a Story or Task.
4. Ends with "Ready", "Ready, with N things worth a look" or "Not ready: fix the ❌ lines above".

What the script can't judge (alignment with the code, the WS1 rules, ACs inside the card's scope, real boundary values, whether the QA step that names an AC really proves it, an error AC that names no status or code) is checked by the AI when the card is picked up and planned (Phase 2, rule A16). Cards are written by people, later also by a separate pipeline; closio-agent never creates them.

**Output example (shortened):**
```
card-check — local/cards/SCRUM-567.md (208 lines)
✅ Required sections are there: Context, How QA can test this, Acceptance Criteria
✅ 8 acceptance criteria, numbered 1–8, each with Given / When / Then
⚠️ QA step 8 has no "Expect" (line 98)
   Tip: Say what QA should see after this step: "Expect …".
✅ No assumptions, placeholders, forbidden tables or secrets

Result: 0 to fix, 1 to look at.
Ready, with 1 thing worth a look.
```

**Files:** `.agents/skills/flow-check-card/`, `scripts/card-check.sh` (you can run `bash scripts/card-check.sh <file>` in a terminal too; exit code 0 when there's no ❌), [jira-card-template.md](jira-card-template.md), [jira-card-examples.md](jira-card-examples.md), `local/cards/` (yours).

---

### `flow-help`

**Purpose:** shows every flow command, what it does and how it's typed, or one command in full ([D60](design-decisions.md#d60)). It only reads. The text comes from the commands' own files (each `SKILL.md`'s `description` and `## Usage` block), so a new command can't be missing (rule R17).

**Usage:**
```
/flow-help                   every flow command, grouped, with how it's typed      (Claude Code)
/flow-help flow-memory       one command in full (the flow- part can be left out: /flow-help memory)
$flow-help …                 (Codex)
```

**Output example (shortened).** In Claude Code or Codex, the AI puts the script's formatted text (markdown) in its reply, and the tool draws it: a heading per group, each command's name in bold with a one-line summary, and each way to type it on its own line in the tool's code color. The text behind it:
```
### Setup, once, in this order

**flow-ping** · Checks that the flow commands are installed and loading in this tool.
- `/flow-ping`
- `/flow-ping <any text>`

**flow-doctor** · Checks that this Mac is set up correctly for the flow commands and shows how to fix each problem.
- `/flow-doctor`
…
Step by step: `docs/user-guide.md` · Claude artifact: https://claude.ai/code/artifact/… · every detail: `docs/commands.md`
```
`/flow-help <command>` shows the full description and every line of the command's `## Usage` block. **In a terminal** (`bash scripts/help.sh` typed by you): the same layout with real colors (cyan group headings, green names, yellow commands), wrapped to the terminal's width (at most 100 characters); no colors with `NO_COLOR` set, or when the output goes to a file.

**The check behind it (rule R17):** `bash scripts/help.sh check`, run by `flow-doctor` ("Commands documented"), shows ❌ with the fix when any command folder has no `## Usage` block, takes arguments but has no `argument-hint` line (what Claude Code's `/` menu shows after the name), has no up-to-date Codex menu line in its `agents/openai.yaml` (`bash scripts/help.sh codex-line <command>` prints it), isn't in a `flow-help` group (the `GROUP_` lines at the top of `scripts/help.sh`; it would show under "Other"), has no section in this file, no row in the user guide's command index, or isn't covered by the guide's "mirrored" line (the Claude artifact is behind). It also fails while a rule file (`rulesets/*.md`, `AGENTS.md`, `docs/agent-rules.md`) still calls a built command "coming" or "not built yet", with the file and line ([D75](design-decisions.md#d75)).

**Files:** `.agents/skills/flow-help/`, `scripts/help.sh` (you can run `bash scripts/help.sh` in a terminal too), [user-guide.md](user-guide.md).

---

### `flow-grill`

**Purpose:** grills a plan, an idea or a card with you, the way [`rulesets/grilling.md`](../rulesets/grilling.md) says ([D76](design-decisions.md#d76), rule A26): what it can find is shown as found, never asked; only real decisions are asked, in numbered rounds, each with a recommended answer that "yes" accepts; follow-up rounds until nothing is open; then what was agreed, and your confirmation. It only reads: it never changes code, a branch, Jira or GitLab. During a card, the card commands already ask this way by themselves; use this when you want something grilled on its own (adapted from Matt Pocock's `grill-me`, MIT; the licence is in the method file).

**Usage:**
```
/flow-grill "<plan or idea>"     grills what you wrote; the answers stay in the chat, with a summary at the end
/flow-grill SCRUM-567            grills a card: picked up → its folder and the code read, the answers saved in its card.md;
                                 not picked up yet → the card read from Jira, the answers stay in the chat
$flow-grill …                    (Codex)
```

**What it does:** your memory (phase `plan`; it can't soften the grilling); checks the folder; reads the method file and the rules. A card: `run.sh state` says whether it's picked up; if so, `run.sh branch` brings its folder here, and it reads `card.md`, `plan.md`, `develop.md`, `verify.md`, `ship.md` and the code of the card's repos (asking for folder access first if a repo's folder isn't open to the session); if not, it reads the card from Jira (read only). Then the facts as "Found" lines, the rounds, the follow-ups, the summary and your confirmation. A card that's picked up: the decisions go into `card.md` under `## Decided while grilling`, a history line, and the card's folder is saved (`run.sh save`).

**Files:** `.agents/skills/flow-grill/`, `rulesets/grilling.md`, `scripts/run.sh`, `scripts/memory.sh`.

---

### `flow-verify`

**Purpose:** checks one card that's been developed and reviewed: Phases 5 and 6 of [architecture.md](architecture.md) ([D67](design-decisions.md#d67), [D68](design-decisions.md#d68)). It runs the card's repos on your Mac and checks every AC in one of **two ways you pick**:

- **A — Full check:** writes and saves every AC's test cases in the run folder (API checks for the backend, Playwright tests for the web app; a QMetry export is the base when you give one), runs them, runs the repo tests again and checks the build against the story.
- **B — Quick check:** checks every AC directly against the running code: the statuses, error codes, messages and response structure it returns (backend: API calls, and the database read after a call that writes; web: one-off Playwright tests). No test cases are saved, no QMetry, no story check; the repo tests run again. Faster, and fewer tokens.

Every run is recorded in `verify.md` (what was tested and the results), never overwritten. Everything passes: the card moves to the push phase. Something fails: it tells you what's wrong with a suggestion for each failure, and **you decide** how to go on. Nothing changes in Jira, and nothing is committed in the repos.

**Usage:**
```
/flow-verify SCRUM-567                      check the card, or check it again; asks: A full check or B quick check   (Claude Code)
/flow-verify SCRUM-567 full                 A without the question
/flow-verify SCRUM-567 quick                B without the question
/flow-verify SCRUM-567 full <export.xlsx>   A with the card's QMetry test cases as the base (optional; one or more exports)
$flow-verify SCRUM-567 …                    (Codex: approve the scripts outside the sandbox)
```

**QMetry is optional, and only for A** ([D67](design-decisions.md#d67)). `flow-verify` never asks for it. With an export (typed after the key, or saved in an earlier run), the QMetry cases are the base: every case that can be automated becomes a test, with its QMetry key in the test's name, and an AC without a QMetry case still gets cases of its own. At the end, one line says how many were covered, e.g. `QMetry: 18 of 22 test cases covered (82%)`: nothing more (no table, no list). Without an export, the test cases are written from the card and the code, and there's no QMetry line. With B, an export typed after the key isn't used, and it says so.

**Web cards: the APIs first** ([D69](design-decisions.md#d69)). Before any test is written, in both ways and on every run, the AI lists the APIs the card's screens call (from the web app's code: method, path, and the name of the variable its base comes from) in `api-list.json`, and asks you once: **"Which of these APIs are available on the dev environment right now?"** Each API you say isn't available is mocked in that run, with the **exact 200 response object you send** (asked for once, kept in `api-mocks.ts`; never made up; error answers come from the web app's code). Right before the tests run, `e2e.sh probe` logs in once and calls each GET API that isn't mocked; one that looks unavailable (no answer, 502/503/504, WS1 can't reach the service behind it, or WS1 doesn't know the route: 597 with `GENERAL_ERROR`) is asked about again. After the run, a call of the card's APIs that failed in a failing test is asked about too. The tests themselves compare the screen with whatever the API answered, so the same test runs against the real API or the mock (`e2e.sh … --mock <names>` turns mocks on for that run). `verify.md` records, per run, which APIs were real and which were mocked, with your answer.

**What it does, step by step** (before every step: the team rules and your memory for `ac-check`, then `testing`; rule A17):

| Step | A — Full check | B — Quick check |
|---|---|---|
| 1 Start and the choice | The card must be in the verify phase (otherwise it says what to type); brings in its run folder; connects the VPN; asks A or B (unless you typed `full` or `quick`) | same |
| 2 Read | The card's ACs and QA steps, the plan, `develop.md`; a web card when its repos include the web app. A QMetry export typed after the key is saved with `scripts/qmetry-import.sh` (one that doesn't mention the card: it asks whether it's the right file); never asked for | The same, plus the code the card changed in each repo; no QMetry |
| 3 Servers | `repo-run.sh <repo> start` for each repo (WS2, then WS1, then the web app), waiting for each health URL; web cards also need Playwright set up | same |
| 4 What's checked | Web cards first: the APIs listed and asked about, the mocks set (see above). Then the `flow-ac-checker` agent writes the cases of every AC that has none: `runs/<KEY>/api-checks/ac-<n>.json` (backend) or `runs/<KEY>/e2e/ac-<n>.spec.ts` (web). With QMetry cases they're the base; without, its own from the card and the code. Cases you changed with `/flow-ac-check` are kept | Web cards first: the APIs listed and asked about, the mocks set (see above). The AI works out each AC's scenarios from the card and the code (every error the code returns, with its status, `error_code` and message; through WS1, WS1's statuses; the response fields) and shows one line each. Web: one-off Playwright tests in `local/quick-checks/<KEY>/` (this Mac only) |
| 5 Test data and calls that write | Test data and every call that writes (`POST`, `PUT`, `PATCH`, `DELETE`) are shown first with their cleanup (which removes the test data and the rows the calls create), and run only after your clear yes (A23) | same (its SQL in `local/quick-checks/<KEY>/`) |
| 6 AC checks | `api-check.sh <KEY>` (backend) or, web: `e2e.sh probe <KEY>` (the API check), then `e2e.sh run <KEY> [--mock <names>]`; failed calls of the card's APIs in failing tests are asked about | Each scenario with `api-call.sh`, compared with the AC and the code (status, error code, message, every response field); after a call that writes, the database is read with `db-run.sh <repo> query` (read only, no yes needed). Web: `e2e.sh probe <KEY> --quick`, then `e2e.sh quick <KEY> [--mock <names>]`, failed API calls asked about as in A. **Both ways:** every API in the card's `## API request and response` gets one success call (web cards: only its GETs on dev), and `response-shape.sh` compares the response with the card's structure: each missing, extra or wrongly typed field is listed, and you decide (rule A28, [D84](design-decisions.md#d84)) |
| 7 Repo tests | `repo-run.sh <repo> test` and `check` again (lint only warns) | same |
| 8 Story check | The `flow-story-check` agent: every AC and the objective built, nothing out of scope, error codes from the code, rules A20–A22 | skipped |
| 9 Clean up | The cleanup SQL shown again and run after your clear yes; the servers stopped; the WS1 session forgotten | The same, then `run.sh quick-clean <KEY>` removes `local/quick-checks/<KEY>/` |
| 10 Result | With QMetry cases only: one line first, `QMetry: <n> of <total> test cases covered (<percent>%)` (`qmetry-import.sh coverage`). All passed: the card moves to the ship phase, next `/flow-push`. Something failed: each failure with a suggestion (`/flow-develop <KEY>` to fix the code, `/flow-ac-check <KEY> <AC> "…"` for a wrong case, or the exact fix for a setup problem); you decide; the card stays in verify | The same without a QMetry line; a scenario checked the wrong way: tell the AI what to check instead and run `/flow-verify <KEY> quick` again |

**`runs/<CARD-KEY>/verify.md`:** one section per run, newest first, earlier runs never overwritten ([D68](design-decisions.md#d68)): `## Run <n> — <date and time> · A full check | B quick check` (or `· flow-ac-check AC <n>`), then (web cards) the APIs, each real or mocked with your answer ([D69](design-decisions.md#d69)), the AC checks, the API structures (✅, or ❌ with each difference; D84) (every case or scenario tested with ✅ / ❌, each failure with what was expected and what came back), the repo tests and checks, the story check (A), the test data, and the result.

**Files:** `.agents/skills/flow-verify/`, the agents `flow-ac-checker` and `flow-story-check`, `scripts/repo-run.sh`, `scripts/api-call.sh`, `scripts/api-check.sh`, `scripts/response-shape.sh`, `scripts/db-run.sh`, `scripts/e2e.sh`, `scripts/qmetry-import.sh`, `scripts/run.sh` (`quick-clean`), `e2e/` (the shared Playwright project).

---

### `flow-ac-check`

**Purpose:** adds, changes or rewrites the test cases of **one AC** of a card (option A's saved cases), runs them once and saves them in its run folder ([D67](design-decisions.md#d67)). `flow-verify`'s full check writes every AC's cases by default; this command is for a new case, a changed case, or a case written again. The next `/flow-verify` (full check) runs them with the rest. The card's phase and Jira don't change.

**Usage:**
```
/flow-ac-check SCRUM-567 3                              write AC 3's cases again from the card and the code
/flow-ac-check SCRUM-567 3 "add a case for ?status=foo"   add or change AC 3's cases as asked
$flow-ac-check …                                        (Codex)
```

**What it does:** checks the card is developed and the AC exists; connects the VPN (the checks log in on the dev WS1); the `flow-ac-checker` agent writes or changes the AC's cases and shows what changed; for a web card it first asks which of the AC's APIs are available on dev and mocks the others (your exact 200 response, [D69](design-decisions.md#d69)), then runs the API check; it starts the servers the AC needs, adds test data and sends calls that write only after your clear yes, runs just that AC (`api-check.sh <KEY> <AC>` or `e2e.sh run <KEY> <AC>`), cleans up after your yes, records the run in `verify.md` (`## Run <n> — … · flow-ac-check AC <n>`), stops the servers and saves the run folder.

**Files:** `.agents/skills/flow-ac-check/`, the `flow-ac-checker` agent, the scripts above.

---

### `flow-push`

**Purpose:** ships one card that's been verified: Phases 7 and 8 of [architecture.md](architecture.md) ([D70](design-decisions.md#d70)). Per repo: the card's work is rebased onto the latest base branch, the tests run again, every AC is checked again the quick way when the rebase brought newer code or had a conflict ([D83](design-decisions.md#d83)), the atomic commits you approved are made, and **one push** creates the merge request, assigned to you; its description and reviewers are set right after through the GitLab API. Then the card shows its MRs and moves to **Code Review**. Nothing is pushed before your explicit yes, and a push is never forced.

**Usage:**
```
/flow-push SCRUM-567        ship the card, or continue where it stopped   (Claude Code)
$flow-push SCRUM-567        (Codex: approve the scripts outside the sandbox: git, GitLab over the VPN, the push)
```

**What it does, step by step** (before every step: the team rules and your memory for `ship`, then `mr`; rule A17):

| Step | What happens |
|---|---|
| 1 Start | The card must be in the ship phase (verified); brings in its run folder; connects the VPN; folder access for every repo (A15); continues at a saved step |
| 2 Read | `card.md`, `plan.md`, `develop.md` (files, migrations and seeders run), the newest run in `verify.md` (it must have passed; failures, e.g. from the checks after the rebase: `/flow-develop` takes the card back to develop) |
| 3 What will ship | `ship.sh <repo> status`: the branch, the uncommitted files, the commits not yet in the MR target; a file `develop.md` doesn't name is asked about |
| 4 Rebase (G2, D10) | `card-branch.sh <repo> rebase <branch>`: stash (new files too), fetch, rebase onto the latest base branch, stash pop. A conflict (exit 4): you resolve the files in your editor ✋, then `card-branch.sh <repo> rebase-continue <branch>`. Each repo's last ✅ line says what came in: "3 newer commit(s) from develop came in" or "nothing new on develop"; one line per repo goes in `ship.md` |
| 5 Tests again | `repo-run.sh <repo> test` and `check` (lint only warns). A failure stops it before any commit: it's written as a failed run in `verify.md`, and `/flow-develop` takes the card back to develop (then `/flow-verify`, `/flow-push` again; D83) |
| 6 The ACs again (D83) | Only when the rebase had a conflict or brought newer commits; else one line: the earlier AC checks still hold. Every AC checked again **the quick way**, whichever way the card was checked before (`/flow-verify`'s steps 3–6 and 9 for B; test data and calls that write only after your yes; no story check), written as a new run in `verify.md`. A failure stops it before any commit; `/flow-develop` takes the card back |
| 7 Commits (G3) | Per repo, the AI proposes the commits: each layer's code with its own tests, messages `SCRUM-567: <what this commit does>`. ✋ You approve the list, then `ship.sh <repo> commit "<message>" <files>` makes each one; the git hooks run (husky's coverage gate on every commit in ws2targetsalesincentive, ws2notification, ws2pricingengine); a failed hook is written as a failed run in `verify.md`, and `/flow-develop` takes the card back |
| 8 The MRs | Per repo: title `SCRUM-567: <card title>`, target `mr_target_branch`, assigned to you, labels and reviewers you confirm (D51), and the description in `runs/<KEY>/mr-<repo>.md`: the Jira link, the migrations and seeders to run. Nothing more |
| 9 ✋ Final yes | Everything shown per repo; pushed only after your clear yes |
| 10 One push per repo (G4) | `ship.sh <repo> push "<title>"`: the push options create the MR, ready for review, assigned to you (D31); then `gitlab-mr.sh <repo> describe <branch> <file> [--reviewers …]` sets the description and reviewers through the GitLab API (D32). Never forced |
| 11 Jira | The card's MR links checked (GitLab's Jira link usually adds them); a missing one: one comment with the links; then the card to **Code Review** (never Blocked, A3) |
| 12 Save | `ship.md` (commits, pushes, MR links); phase `after-merge`; next `/flow-finish` once the MRs are merged |

**`runs/<CARD-KEY>/ship.md`:** per repo, what the rebase brought in (and any conflict), a pointer to the AC checks after it, the commits (hash and message), the push and the MR link, the labels and reviewers. **`runs/<CARD-KEY>/mr-<repo>.md`:** each MR's description.

**Files:** `.agents/skills/flow-push/`, `scripts/card-branch.sh` (`rebase`, `rebase-continue`), `scripts/ship.sh`, `scripts/gitlab-mr.sh`, `scripts/repo-run.sh`, the `flow-connectivity` agent.

---

### `flow-review`

**Purpose:** reviews a pushed card's merge requests while they wait for the merge ([D78](design-decisions.md#d78)): their state, a self-review of the card's code against [`rulesets/code-review.md`](../rulesets/code-review.md), and the reviewers' new comments. Fixes go as new commits into the same MR (the one exception to "one push" and "rebase before every push"); replies are posted as you. Nothing reaches GitLab without your yes; it never resolves a thread and never moves the Jira card.

**Usage:**
```
/flow-review SCRUM-567           a full run: the MRs' state, the self-review, the new comments, the fixes and replies you approve
/flow-review SCRUM-567 check     only lists what's new (comments, approvals, pipeline, conflicts); writes nothing
                                 (repeat it, e.g. Claude Code's /loop 30m /flow-review SCRUM-567 check)
$flow-review …                   (Codex)
```

**What it does** (a card in the "waiting for the merge" state, its MRs open; the grilling way, every decision in `decisions.md`):

| Step | What happens |
|---|---|
| 1 Start | Checks the folder and the card's state; brings the card's folder onto this Mac; connects the VPN; checks folder access to each repo |
| 2 The MRs' state | Per repo: `gitlab-mr.sh status` (all merged → "next: /flow-finish"), `pipeline` (failed jobs), `comments --since <last seen note>` (approvals, conflicts, unresolved threads, new notes). Conflicts are shown; nothing is rebased. The `check` form stops here and writes nothing |
| 3 Self-review | On the first run and after any change: the story level (with the `flow-story-check` agent), the micro level (no redundant code: a re-created helper is a must-fix, a WS1 schema block copied instead of from a shared helper too; the right file for each piece; the WS1 schema against the card's structure, every key and type: a missing one is a must-fix; better queries, each a should fix with a "Why" line, from the code only, [D85](design-decisions.md#d85); the basics), and the tool's own reviewer (Claude Code's `code-review`; Codex: `repo-run.sh <repo> review`). Findings in chat only: must fix / should fix / small. You decide which to fix; each fix is tested (`repo-run.sh test` and `check`). **At most 3 rounds per run, 2 tries per failing fix**; then it's your call |
| 4 Comments | One pass over the new and unresolved threads: a question → a drafted reply; a change request → a tested fix and a reply; unclear or disagreement → your call |
| 5 Commits | The fixes as atomic commits you approve (`SCRUM-<n>: address review: …`, each layer with its tests) |
| 6 ✋ Final yes | The commits to push and every reply to post, per repo |
| 7 Push, reply | `ship.sh push-update` (into the same MR; no rebase, never forced), then `gitlab-mr.sh reply` per approved reply; threads stay open for the reviewer |
| 8 Save | `runs/<KEY>/review.md` (a section per round: MR state, findings, comments, what was pushed and posted, the last seen note per repo), the card's folder saved; Jira stays in Code Review |

**Files:** `.agents/skills/flow-review/`, `rulesets/code-review.md`, `scripts/gitlab-mr.sh` (`comments`, `reply`, `pipeline`), `scripts/ship.sh` (`push-update`), `scripts/repo-run.sh` (`review`), `scripts/run.sh`, the `flow-connectivity` and `flow-story-check` agents.

---

### `flow-finish`

**Purpose:** finishes one card after its merge requests are merged: Phase 9 of [architecture.md](architecture.md) ([D72](design-decisions.md#d72)). It checks the merge, checks every AC on the **dev** environment once you say the card is deployed (the quick check, B), writes the deployment doc in the run folder and on the Jira card, and moves the card to **Ready for Test**. A failure: what's wrong with a suggestion, and you decide. The card's run branch stays as its record (never merged into `main`).

**Usage:**
```
/flow-finish SCRUM-567        finish the card once its MRs are merged, or continue where it stopped   (Claude Code)
$flow-finish SCRUM-567        (Codex: approve the scripts outside the sandbox)
```

**What it does, step by step** (before every step: the team rules and your memory for `after-merge`; rule A17):

| Step | What happens |
|---|---|
| 1 Start | The card must be in the after-merge phase (pushed); brings in its run folder; connects the VPN; folder access for every repo |
| 2 Merged? | `gitlab-mr.sh <repo> status <branch>` for each repo: merged (with its merge commit), or it stops and says which MR is still open |
| 3 Deployed on dev? | It asks you in the chat; nothing checks it by itself |
| 4 Checks on dev | The quick check (B, as in `/flow-verify`) with `--env dev`: WS1 with the dev login (rule A24), a direct WS2 call with WS1's pair ([D37](design-decisions.md#d37)), web cards on the dev web app; each repo's dev address from its repo file (asked if missing). Test data and calls that write only after your clear yes (A23). A new run in `verify.md`, `· dev check (B)` |
| 5 Special instructions | It asks you once what's special for the deployment doc |
| 6 Deployment doc | `runs/<KEY>/deployment.md`, in plain words for two readers. **For QA:** what the card adds; how to try it (an API card: ready-to-run curls for the dev login, the API through WS1 and straight to WS2, with placeholders for every login, cookie and key, then the filters, errors and a table of what comes back; a web card: the menu path to the screen; a consumer card: in words, which event sends the message and what to look for); what was already checked on dev. **For the person deploying:** the order with each MR's number and link; per repo the database changes and default data (file names, what each changes in words, safe to run twice or not, how to undo it), new settings (names and what they're for), after-deploy steps. Then your special instructions. No code, commands or raw JSON in it, except the curls. The migrations and seeders it names are shown to you first, in full, then a separate yes (A23) |
| 7 Jira | The deployment doc on the card as one comment (its id kept in the card's notes, `jira_comment` in `state.md`, so a later run edits the same comment); the card to **Ready for Test** (never Blocked, A3) |
| 8 Save | Phase `done`; `/flow-status` lists the card under Finished; the run branch `runs/<KEY>` stays as the record |

**`runs/<CARD-KEY>/deployment.md`:** the deployment doc (its Jira comment's id is in `state.md`, `jira_comment`).

**Files:** `.agents/skills/flow-finish/`, `scripts/gitlab-mr.sh` (`status`), `scripts/api-call.sh` / `api-check.sh` / `e2e.sh` (`--env dev`), `scripts/configure-repo.sh` (`set-dev-url`), `scripts/run.sh`, the `flow-connectivity` agent.

---

### `flow-qa`

**Purpose:** handles QA's questions on a finished card ([D81](design-decisions.md#d81)): reads QA's new comments on the Jira card, checks each one against the card's ACs, its `decisions.md`, the deployment doc, the merged code and the dev environment, and drafts the answer. A real bug becomes a separate Bug card; something the card never asked for becomes a draft of a new card. Nothing is posted, created or moved without your yes.

**Usage:**
```
/flow-qa SCRUM-567           a full run: QA's new comments checked; the reply, Bug cards and new cards after your yes
/flow-qa SCRUM-567 check     only lists QA's new comments and the card's status; writes nothing (repeat it, e.g. /loop 30m)
$flow-qa …                   (Codex)
```

**What it does** (a finished card; the grilling way; every decision in `decisions.md`):

| Step | What happens |
|---|---|
| 1 Start | Checks the folder and that the card is finished; brings the card's folder onto this Mac; your Jira account from your settings |
| 2 QA's new comments | Reads the card's status, comments and links (read only); the new comments since the last round, everyone's except yours (your deployment doc and replies are yours). QA's own Bug cards are named, to work with `/flow-start`. The `check` form stops here |
| 3 The facts | Per comment, as "Found" lines: the AC it's about, the card's decisions, the deployment doc, the merged code, and that scenario checked on dev the quick way (`--env dev`; writes and test data only after your yes) |
| 4 Sorted | Works as the card says → a drafted answer with the evidence; a real bug → a Bug card draft; not asked for by the card → a drafted reply and a new card draft; unclear → a question back |
| 5 Bug cards | Shown in full (what QA saw, what the AC expects, what dev shows, How QA can test this, relates to the story); created as a Bug in To Do, unassigned, only after your yes. If QA had put the story in Blocked: it asks to move it to In Development |
| 6 Back to Ready for Test | When the story is In Development and every Bug card raised for it is in Ready for Test or later: it asks to move the story back to Ready for Test |
| 7 ✋ The reply | One comment for the round: each of QA's points, quoted, then the answer; posted as you after your yes |
| 8 Save | `runs/<KEY>/qa.md` (a section per round: the comments seen, what dev showed, the Bug cards, the reply, the Jira moves); the card's folder saved |

`/flow-finish` on a Bug card raised this way also checks its story: once every Bug card of the story is in Ready for Test or later, it asks to move the story back to Ready for Test.

**Files:** `.agents/skills/flow-qa/`, `scripts/run.sh`, `scripts/api-call.sh` and `scripts/e2e.sh` (`--env dev`), `scripts/memory.sh`, the `flow-connectivity` agent; `runs/<KEY>/qa.md`.

---

### `flow-status`

**Purpose:** shows where a card stands in closio-agent, from its run folder `runs/<CARD-KEY>/` ([D61](design-decisions.md#d61), rule A1). It only reads.

**Usage:**
```
/flow-status                 every card in progress (on this Mac and pushed by teammates)   (Claude Code)
/flow-status SCRUM-567       that card's state and the exact command to type next
$flow-status …               (Codex)
```

**What it shows, in plain words ([D74](design-decisions.md#d74)):** where the card stands (being picked up · planning · in development · being checked · ready to push · waiting for the merge · finished), what to type next, its Jira status, the repos and the branch, and when it was last updated. A card that isn't on this Mac says where its saved copy is (`/flow-start <CARD-KEY>` brings it here)..

**Output example:**
```
SCRUM-567 · planning · next: /flow-start SCRUM-567 · updated 2026-10-17 15:32
SCRUM-540 · waiting for the merge · next: /flow-finish SCRUM-540 · updated 2026-10-18 23:46
```
`/flow-status SCRUM-540` shows one card the same way, a line each: State, Next, Jira, Repos, Branch, Updated.

**Files:** `.agents/skills/flow-status/`, `scripts/run.sh` (`list`, `status`; you can run `bash scripts/run.sh list` in a terminal too).

---

### `flow-start`

**Purpose:** picks up one Jira card and plans it: Phases 1 and 2 of [architecture.md](architecture.md) ([D61](design-decisions.md#d61)). It ends when you've approved the plan. Everything it does is remembered in `runs/<CARD-KEY>/`, saved to the card's branch of closio-agent (`runs/<CARD-KEY>`, never `main`; this folder itself never switches to that branch: it stays on `main`, with the current commands and scripts), so it can be paused and continued: run it again and it carries on from the last finished step (in a new session too: it first brings the card's run folder onto this Mac).

**Usage:**
```
/flow-start SCRUM-567        pick up the card and plan it, or continue where it stopped   (Claude Code)
$flow-start SCRUM-567        (Codex: approve the scripts outside the sandbox: git, GitLab over the VPN, pushes)
```

**Before every step (rule A17, [D62](design-decisions.md#d62)):** the AI re-reads `AGENTS.md` and [agent-rules.md](agent-rules.md) and your memory for the phase (`bash scripts/memory.sh for pick-up …`, later `for plan …`), applies both, and writes in the card's `history.md` which rules and entries it applied.

**What it does, step by step:**

| Step | What happens |
|---|---|
| 1 Start | Checks the folder; if the card already has a run folder, jumps to the step it stopped at (at steps 8–10 it goes back to step 7 first: the latest code is read again, and an unsaved draft is made again); connects the VPN (the `flow-connectivity` agent, rule A5) |
| 2 The card | Reads it from Jira. A Spike stops here (D58). Not To Do, or assigned to someone else: asks whether to go on. Creates the card's branch `runs/<CARD-KEY>` of closio-agent and the run folder; saves the card's text to `runs/<CARD-KEY>/card.md`; runs `scripts/card-check.sh` on it. On ❌ it lists the gaps and waits: you fix the card or explain in chat (written under "Explained at pick-up") |
| 3 Jira | Moves the card into the active sprint if it's in the backlog ([D13](design-decisions.md#d13)), to **In Development**, and assigns it to you (your account ID from `local/user-settings.sh`). Never Blocked (A3) |
| 4 The repos | Reads them from the card's Scope section and asks you to confirm |
| 5 The branches | For each repo: folder access first (A15); the branch name suggested by `scripts/branch-name.sh` and confirmed by you (A12, the same name in every repo); `scripts/card-branch.sh` fetches, pulls the repo's base branch (G1) and creates the branch, or reuses one that exists. Uncommitted changes in a clone: it stops and asks |
| 6 Save | `scripts/run.sh save`: the run folder committed and pushed on `runs/<CARD-KEY>` |
| 7 The code first | First brings the latest base branch into the card's branch in every repo (`scripts/card-branch.sh update`: a fast-forward while the branch has no commits of its own; uncommitted changes: it stops and asks). Then reads the ruleset (`scripts/configure-repo.sh ruleset <repo>`, rule A19) and the current code of every repo involved (routes, controllers, services, utils, constants, middlewares, migrations, locale files). Never from the card alone (A18) |
| 8 Questions first | Lists every difference between the card and the code (error codes, statuses, messages, fields, anything the card names that isn't in the code) and asks you the grilling way: the facts found in the code first, then the real decisions in numbered rounds, a recommended answer each, follow-ups until nothing is open; waits for your confirmation (rule A26). Your answers go into `card.md` (A16, A18). When continuing, it asks only what isn't answered there yet; an API the card names without its request and response structure: it asks you to paste them, never writes one (rule A28, D84); when the card has a WS1 schema, its keys are every key of the card's request and response structure, and any field the WS2 code has that the structure doesn't is shown for you to decide (rule A22); a common block (pagination, the audit fields) with no shared schema helper yet: it asks where the helper goes and its name ([D85](design-decisions.md#d85)) |
| 9 The draft plan | From the ruleset, your memory for the `plan` phase (an entry may change a ruleset point), the card files (`card.md` with your explanations and answers) and the code ([D64](design-decisions.md#d64)), in the ruleset's plan format: `Ruleset: … · Memory applied: …` at the top, the changes as a numbered file list per repo, and an AC → implementation table. Shown in chat; nothing saved yet. It has a `## Validation, reuse and response fields` part: where each request check goes (rule A20), the existing functions it will reuse and each new one (rule A21), and the WS1 response fields (rule A22) |
| 10 ✋ Approval | You approve the plan in chat, or ask for changes until it's right. Strictly necessary (A18) |
| 11 Save | `plan.md` written, the run folder saved and pushed; the next command is [`flow-develop`](#flow-develop) |

**The run folder** `runs/<CARD-KEY>/` ([D61](design-decisions.md#d61)): `state.md` (phase, step, Jira status, the deployment doc's Jira comment, repos, branch, next command), `history.md` (one line per step with the rules and memory applied), `decisions.md` (every decision on the card, in full, numbered: answers, approvals and refusals at a stop, memory answers, your mid-command changes; the other files only point to it, "decision 3"; rule A27, [D77](design-decisions.md#d77)), `card.md`, `plan.md`; later `develop.md`, `verify.md`, `ship.md`, `deployment.md`. Plain markdown, never a secret. It's saved to the card's branch of closio-agent and pushed after every phase, so a teammate can continue ([D38](design-decisions.md#d38)): `bash scripts/run.sh branch <CARD-KEY>` brings it onto their Mac. This folder itself never switches to that branch: it stays on `main`, with the current commands and scripts ([D61](design-decisions.md#d61)): `save` commits just the `runs/<CARD-KEY>/` folder to the branch, through a temporary git index, so your working tree and its changes are never touched. On `main` the run folders are git-ignored (`/runs/*/`). The branch is never merged into `main`: it stays as the card's record. The card's code is merged through its MRs into each repo's target branch from its repo file (`mr_target_branch`, else `base_branch`, e.g. `develop`), and `flow-finish` checks that they're merged.

**Files:** `.agents/skills/flow-start/`, `scripts/run.sh`, `scripts/card-branch.sh`, `scripts/branch-name.sh`, `scripts/card-check.sh`, the `flow-connectivity` agent, `runs/<CARD-KEY>/`.

---

### `flow-develop`

**Purpose:** develops one card whose plan is approved, together with you: Phases 3 and 4 of [architecture.md](architecture.md) ([D61](design-decisions.md#d61), [D65](design-decisions.md#d65)). It writes the code and its unit tests, runs the repo's tests and checks, then stops for your review ✋. It ends when you approve the review; the next command is `flow-verify`. Its progress is remembered in `runs/<CARD-KEY>/` (with the new `develop.md`) on the card's branch of closio-agent. The code itself stays uncommitted in the repos until `flow-push` (rule G3), so a card paused here can only be continued on the same Mac.

**Usage:**
```
/flow-develop SCRUM-567        develop the card from its approved plan, or continue where it stopped   (Claude Code)
"develop SCRUM-567"            plain words work too, only for a card whose plan is approved
$flow-develop SCRUM-567        (Codex: approve the scripts outside the sandbox)
```

**Plain words (the one exception to [D44](design-decisions.md#d44)):** it starts from plain words only when you name a card whose run folder is in the develop phase, or when exactly one card is in that phase. Otherwise the AI shows the cards in progress and tells you what to type. No other command ever starts from plain words.

**Before every step (rule A17):** the AI re-reads `AGENTS.md` and [agent-rules.md](agent-rules.md) and your memory for the phase (`bash scripts/memory.sh for develop …`, then `for review …`), applies both, and writes in the card's `history.md` which rules and entries it applied.

**What it does, step by step:**

| Step | What happens |
|---|---|
| 1 Start | Checks the folder; the card must be in the develop phase (its plan approved), or in the verify or ship phase with failures in its last check (for ship: the checks `/flow-push` ran after its rebase, [D83](design-decisions.md#d83)): then it shows them and asks whether to go back to development to fix them (on a yes it adds a "Back from verify" or "Back from the push" list to `develop.md` and works through it; after the push, the rebase and any commits stay); otherwise it says what to type; brings the card's run folder onto this Mac (`run.sh branch`; this folder stays on `main`); connects the VPN; a card that stopped part-way continues at its saved step |
| 2 Repos ready | Folder access first (A15); on the first start `scripts/card-branch.sh update` brings the latest base branch in; when continuing with your uncommitted work it only checks the branch |
| 3 Read | `plan.md`, `card.md`, the ruleset (A19), your memory for `develop`, and the files the plan names plus their neighbours |
| 4 Develop | Repo by repo, in the plan's order (WS2 before WS1): the code follows the closest existing files; it creates the new files the plan lists and any other the work needs; error codes, statuses, messages, fields and constants come from the code, and anything new or different from the plan is asked first (A16). Nothing is committed (G3). Request checks: presence, type and format in the WS1 schema, everything again plus all business logic in WS2 (controller, or a utils function when large; service when it needs the database; rule A20). Before writing any function it searches the repo and reuses an exact match, asking you about a close one (rule A21). The WS1 schema holds every key of the card's request and response structure, with its type (rule A22); common blocks (pagination, the audit fields) come from a shared schema helper, never copied; new queries follow the ruleset's query list, and a better version of an existing one is asked about ([D85](design-decisions.md#d85)) |
| 5 Tests | The committed tests, in the repo's own layout: backend unit tests (controller, service) and API tests; Vitest unit tests for the web app; none where a repo has no test suite ([D25](design-decisions.md#d25)). Then `bash scripts/repo-run.sh <repo> test` (every test and the coverage gate, on the repo's Node version, A13), fixing until it passes |
| 6 Checks | `bash scripts/repo-run.sh <repo> check`: **lint** checks only the files the card changed and shows its problems as ⚠️ warnings, never stopping (the repos have older lint errors: about 80 in ws2targetsalesincentive, 550 in ws1closio); the other checks (circular imports) are fixed until they pass |
| 7 Migrations and seeders | First you review the files (the full up and down, what they change, the repo, the database the `.env` names; rule A23), then a separate yes in chat, every run ([D21](design-decisions.md#d21)): `bash scripts/repo-run.sh <repo> migrate confirmed` (or `seed confirmed`); each run is written in `develop.md` for the deployment doc |
| 8 Summary | A short summary of the repo (new and changed files, tests, checks, anything not in the plan, and each new query with a one-line why, D85), then it carries straight on with the next repo |
| 9 Save | `develop.md` complete; the run folder saved and pushed |
| 10 ✋ Review | Per repo: the changed files, what each plan item became, every change from the plan, and every new function with the search behind it. You review in your editor: "change X" goes back to step 4; "review approved" goes on |
| 11 Finish | The review result in `develop.md`; the card moves to the verify phase; saved and pushed; next: [`flow-verify`](#flow-verify) |

**`runs/<CARD-KEY>/develop.md`:** the plan and ruleset it followed and the memory applied; one section per repo (new and changed files, tests and their result, checks, everything not in the plan with your answer); the migrations and seeders run; the review.

**Files:** `.agents/skills/flow-develop/`, `scripts/repo-run.sh`, `scripts/card-branch.sh`, `scripts/configure-repo.sh` (`ruleset`), `scripts/run.sh`, [rulesets/story-implementation-workflow.md](../rulesets/story-implementation-workflow.md) (backend) and [rulesets/frontend-story-workflow.md](../rulesets/frontend-story-workflow.md) (the web app), `runs/<CARD-KEY>/develop.md`.

---

## Helper scripts

The commands run these scripts (in `scripts/`). You can run them yourself in a terminal from the closio-agent folder, after `nvm use v22`. Shared values come from `config/project-settings.sh`.

| Script | What it does | Used by |
|---|---|---|
| `doctor.sh` | All the setup checks (reads only; formatted text for the AI, colors in a terminal) | `flow-doctor` |
| `vpn.sh connect \| status \| disconnect` | The VPN steps | `flow-vpn`, the `flow-connectivity` agent |
| `vpn-admin-steps.sh` | The few VPN steps that need admin rights (one password dialog). Runs as admin: review changes carefully | `vpn.sh` |
| `password-dialog.sh` | The macOS password dialog for those admin steps | `vpn.sh` |
| `configure-user.sh check-folder \| show \| set \| secrets \| secret \| gitlab-username-from-token` | Personal settings and the 5 secrets | `flow-configure-user` |
| `configure-repo.sh check-folder \| list \| detect \| validate \| set-path \| keys \| key \| show \| ruleset \| set-dev-url \| dev-url` | The repo registry, clone paths and dev keys; `ruleset <repo>` says which ruleset the repo follows: a backend repo the story ruleset, the web app the frontend one (rule A19, D80); `set-dev-url <repo> <url>` saves the repo's address on dev in its shared file (`dev_base_url`, D72; it says the old and the new one); `dev-url <repo\|all>` prints it, one line per repo | `flow-configure-repo`; `flow-start` and `flow-develop` (`ruleset`); `flow-setup-repo` (`dev-address`), `flow-finish` |
| `setup-repo.sh check-folder \| list \| run <repo\|all> [install\|services]` | Gets repos ready to work on (Node, packages, local Redis/RabbitMQ, `.env` check, tests, folder access) | `flow-setup-repo` |
| `memory.sh for <phase> [words] \| list \| add \| edit \| set-phases \| remove \| clear-preview \| clear \| count \| problems` | Your user memory: the entries for a command, and managing them | Every command (first step), `flow-memory`, `flow-doctor` |
| `branch-name.sh make <CARD-KEY> "<title>" \| check <name>` | Builds and checks branch names (strict rule A12) | Later phases (Phase 1); you can use it any time |
| `card-check.sh <card file>` | Checks a card's text against the card template: ❌ not ready (with the fix), ⚠️ worth a look; exit code 0 when there's no ❌ | `flow-check-card`; Phase 1 later |
| `help.sh list \| show <command> \| codex-line <command> \| check` | The command help, read from each command's `SKILL.md` (formatted text for the AI, colors in a terminal); `codex-line` = the lines for the command's `agents/openai.yaml` that Codex's `$` menu shows (its options and a one-line summary, D74); `check` = rule R17 (Usage block, argument hint, Codex menu line, `commands.md` section, user-guide row, Claude artifact covering every command) and no rule file calling a built command "coming" or "not built yet" (D75) | `flow-help`, `flow-doctor` |
| `run.sh branch \| create \| state \| status \| get \| set \| log \| decide \| save \| list \| quick-clean \| count \| problems` | The card's run folder `runs/<CARD-KEY>/`: create it, read and change its state, write its history, record a decision in `decisions.md` (`decide <KEY> "<step>" "<question>" "<decided>" "<who / why>"`: numbered, prints the number; D77), and save it to its branch `runs/<CARD-KEY>` of closio-agent and push (never `main`), without ever switching this folder to that branch; `branch` brings the folder onto this Mac (a teammate's too); `quick-clean` removes the quick check's scratch folder `local/quick-checks/<CARD-KEY>/`; `list` shows finished cards (phase `done`) apart | `flow-start`, `flow-status`, `flow-doctor`; the later card phases |
| `card-branch.sh check <repo> \| create <repo> <branch> \| update <repo> <branch> \| rebase <repo> <branch> \| rebase-continue <repo> <branch>` | In a code repo: fetch, pull the base branch and create the card's branch (or reuse it); `update` brings the latest base branch into it (a fast-forward while it has no commits of its own; with its own commits it's left for the rebase in `flow-push`); stops with exit code 3 on uncommitted changes; `rebase` = flow-push's stash, rebase onto the latest base branch, stash pop (G2), exit code 4 on a conflict the user resolves, then `rebase-continue`; both end by saying what came in from the base branch ("<n> newer commit(s) from <base> came in" or "nothing new on <base>"; [D83](design-decisions.md#d83)) | `flow-start`, `flow-develop`, `flow-push` |
| `repo-run.sh <repo> check \| test \| migrate confirmed \| seed confirmed \| start \| stop \| status \| review` (and `all stop`) | A repo's own commands, in its folder, on its Node version (A13): its check commands (lint only on the files the card changed, as ⚠️ warnings); its tests and coverage gate; `npm run migrate` / `seed` only with the word `confirmed`, after the user's yes ([D21](design-decisions.md#d21)). `start` runs the repo's server in the background and waits for its health URL; `stop` only stops what it started. Output in `local/logs/`; `review`: Codex's own reviewer on the card's changes (`codex review --base origin/<target>`, in the repo's folder; flow-review in Codex, D78) | `flow-develop`, `flow-verify`, `flow-ac-check`, `flow-push`, `flow-review` |
| `api-call.sh <repo> login \| logout \| <METHOD> <path> [--json \| --body] [--header] [--auth user\|none] [--client ok\|none\|id-only\|secret-only\|unknown\|wrong-secret] [--save] [--env dev]` | One API call to a repo running on this Mac. WS1 calls go logged in as you: the login always goes to the **dev** WS1 login URL with your WS1 login from the Keychain (rule A24, [D71](design-decisions.md#d71)), and its session cookie is sent to the WS1 on this Mac (under its own name, else as `closio_session_local`; kept in `local/sessions/`); WS2 calls carry the keys saved with `/flow-configure-repo <repo> key …`, or missing or wrong keys on purpose. Keys, passwords and sessions are never shown; `--env dev` calls the repo on dev (its `dev_base_url`) instead of the copy on this Mac | `flow-verify`, `flow-ac-check`, `flow-finish` (through `api-check.sh` or directly) |
| `response-shape.sh <card file> "<METHOD> <path>" <response file>` | Compares an API's real response (saved with `api-call.sh … --save`) with the response structure in the card's `## API request and response`: the same keys and JSON types at every level, values not compared; `null` in the card = may be null; type words ("string", "number", …) count as that type. ✅, or ❌ per difference; exit 2 when the card has no valid structure for it (ask the user, rule A28) | `flow-verify` |
| `api-check.sh <CARD-KEY> [<AC>] [--env dev]` | Runs the card's API test cases (`runs/<CARD-KEY>/api-checks/ac-<n>.json`: the call and what must come back) and says per case and per AC whether they pass ; `--env dev` runs them on dev | `flow-verify`, `flow-ac-check` |
| `db-run.sh <repo> show <sql> \| run <sql> confirmed \| query <sql>` | A card's test data on the database the repo's `.env` names: `show` prints the SQL to review; `run … confirmed` runs it in one transaction with the repo's own config, only after your yes (A23); `query` only reads (a read-only transaction: the database refuses any change; no COMMIT, SET and the like) and prints the rows, no yes needed | `flow-verify`, `flow-ac-check` |
| `e2e.sh check \| setup \| run <CARD-KEY> [<AC>] [--mock <names>] \| quick <CARD-KEY> [<AC>] [--mock <names>] \| probe <CARD-KEY> [--quick] [--mock <names>]` (each with `[--env dev]`) | Playwright: is it set up; set it up (`e2e/` packages and Chromium); run a card's tests (`runs/<CARD-KEY>/e2e/`; `quick`: the quick check's one-off tests in `local/quick-checks/<CARD-KEY>/`) against the web app on this Mac, logged in with your FE login; `--mock` turns on those mocks of the card's `api-mocks.ts`. No test run at all is a ❌. Under failing tests it lists the API calls that got no answer or a 5xx from dev (the card's APIs first, other screens' calls apart). `probe`: the API check before the run (logs in once, calls each GET API of the card's `api-list.json` that isn't mocked; ⚠️ for one that looks unavailable) ; `--env dev`: against the dev web app (its `dev_base_url`) | `flow-configure-user`, `flow-verify`, `flow-ac-check`, `flow-finish`, `flow-doctor` |
| `qmetry-import.sh <CARD-KEY> <export.xlsx> \| coverage <CARD-KEY>` | Saves a QMetry test-case export of a card as markdown in `runs/<CARD-KEY>/qmetry/`, the base for its test cases (QMetry can't be read through the Jira tools); `coverage` counts how many of its cases the card's test cases cover (a case's QMetry key in a test's name) | `flow-verify`, `flow-ac-check` |
| `ship.sh <repo> status \| commit "<message>" <file>... \| push "<MR title>" [--label <label>]... \| push-update` | A card's commits and its one push: `status` shows what would ship; `commit` stages exactly those files and commits with a `SCRUM-<n>: …` message, the git hooks running on the repo's Node version (a failing hook: nothing committed); `push` pushes the card's branch once, its push options creating the MR into `mr_target_branch`, assigned to you, and prints the MR link; never forced; `push-update`: review fixes on top of the pushed branch, into the same MR (no rebase, never forced; D78) | `flow-push`, `flow-review` |
| `gitlab-mr.sh <repo> find <branch> \| status <branch> \| describe <branch> <file> [--reviewers <names>] \| comments <branch> [--since <note id>] \| reply <branch> <thread id> <file> \| pipeline <branch>` | The MR through the GitLab API: find the branch's open MR; set its full description and reviewers (looked up by username). Your token is read from the Keychain and handed to curl on stdin, never shown ; `status`: merged (with the merge commit), still open or closed; `comments`: the MR's approvals, conflicts and its unresolved or new threads (with the newest note id); `reply`: posts a reply in a thread, as you (never resolves it); `pipeline`: the latest pipeline and its failed jobs (D78) | `flow-push`, `flow-review`, `flow-finish` |
| `link-claude-skills.sh` | Adds the Claude Code link for every command (run it after adding a command) | Setup; `flow-doctor` tells you when |
| `wait-seconds.sh <1-30>` | Waits a few seconds (e.g. while Jira loads) | `flow-doctor`, `flow-configure-user`, `flow-check-card` |
| `lib/secret-dialogs.sh` | The heads-up and hidden box for secrets | `configure-user.sh`, `configure-repo.sh` |

## Agents

Agents are helpers that commands start; you don't type them.

| Agent | What it does | Files |
|---|---|---|
| `flow-connectivity` | Connects the VPN if needed and checks GitLab, at the start of every phase that needs it (Phases 1–9). Limits: 3 steps in Claude Code, 180 s for the SSO login ([D47](design-decisions.md#d47)) | `.claude/agents/flow-connectivity.md`, `.codex/agents/flow-connectivity.toml` |
| `flow-ac-checker` | Writes or updates a card's test cases, one file per AC, in its run folder (API checks for backend cards, Playwright tests for web cards), from the card's QMetry export when there is one (the base, each case with its QMetry key), otherwise from the card and the code. A web test that needs an answer the dev data or the server can't give on demand (a 500, more than 5 items, a fixed order) answers the screen's one API call itself (`page.route`, the response shape and error codes from the code) and ends its name with `(answer from the test)`. Never runs them. Limit: 60 steps ([D47](design-decisions.md#d47)) | `.claude/agents/flow-ac-checker.md`, `.codex/agents/flow-ac-checker.toml` |
| `flow-story-check` | Checks the build against the card's story (ACs, out of scope, error codes, rules A20–A22) and lists what's missing or extra. Only reads. Limit: 15 steps | `.claude/agents/flow-story-check.md`, `.codex/agents/flow-story-check.toml` |

