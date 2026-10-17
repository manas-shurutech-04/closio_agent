# Commands

Every closio-agent command starts with **`flow-`** ([D43](design-decisions.md#d43)).

- **Claude Code:** type `/flow-<name>`
- **Codex:** type `$flow-<name>`, or pick it from `/skills`

Before you start: open a terminal **in the closio-agent folder**, run `nvm use v22`, then start `claude` or `codex` ([setup guide](setup-guide.md#how-to-start-claude-code-or-codex-every-time)).

## How the commands work

- **Written once, used by both tools ([D8](design-decisions.md#d8)).** Each command lives in `.agents/skills/<name>/SKILL.md`, where Codex reads it. Claude Code reads `.claude/skills/<name>`, which is a link to the same folder. `scripts/link-claude-skills.sh` creates any missing links.
- **They only run when you type them ([D44](design-decisions.md#d44)).** The tool never starts a command by itself. Claude Code: `disable-model-invocation: true` in `SKILL.md`. Codex: `agents/openai.yaml` in the command's folder. Also, the rules file `AGENTS.md` tells the AI not to do a command's steps by hand: if you ask for what a command does (e.g. "check my setup"), it tells you which command to type ([D45](design-decisions.md#d45)). Tested in both tools on 2026-10-10. This is an instruction, not a hard lock, so the tool still asks before running a script. **One exception ([D61](design-decisions.md#d61), [D65](design-decisions.md#d65)):** `flow-develop` also starts when you ask in plain words to develop a card whose plan is approved (you name it, or it's the only card in the develop phase): `disable-model-invocation: false` in its `SKILL.md`, `allow_implicit_invocation: true` in its Codex file, and `AGENTS.md` rule 1 says when.
- **Your user memory is applied, every time ([D40](design-decisions.md#d40), [D56](design-decisions.md#d56), rules A7/A8).** Every command starts with `bash scripts/memory.sh for setup all`: Claude Code runs it by itself when the command loads; in Codex it's the command's first step. Team rules always win. See [`flow-memory`](#flow-memory).
- **Shared logic lives in `scripts/`.** The command tells the AI which script to run, so both tools do the same thing.
- **Every command follows the agent rules** in [agent-rules.md](agent-rules.md), e.g. every problem comes with the steps to fix it (A11).
- **Every command is in the help and in the guide (rule R17, [D60](design-decisions.md#d60)).** `flow-help` reads each command's `## Usage` block, [user-guide.md](user-guide.md) walks through every command in order (and is mirrored into a Claude artifact), and `flow-doctor` checks that nothing is missing.

**No approval prompts for our own scripts ([D49](design-decisions.md#d49), [D57](design-decisions.md#d57)):** every script the commands run (`configure-user.sh`, `configure-repo.sh`, `setup-repo.sh`, `memory.sh`, `doctor.sh`, `vpn.sh`, `wait-seconds.sh`, `branch-name.sh`, `card-check.sh`, `help.sh`, `run.sh`, `card-branch.sh`, `repo-run.sh`, `api-call.sh`, `api-check.sh`, `db-run.sh`, `e2e.sh`, `qmetry-import.sh`, all their steps) runs without asking, and so does saving a card's text to `local/cards/` for `flow-check-card` and writing a card's run folder `runs/<CARD-KEY>/` for the card phases. **Claude Code:** the shared file `.claude/settings.json` (it applies once you've trusted the folder). It also pre-approves the **read-only Jira tools** the commands use through Claude's Atlassian connector (read a project or an issue, search issues, your account), so `flow-doctor`, `flow-configure-user`, `flow-check-card` and `flow-start` don't ask each session, and the two changes `flow-start` makes to a card (its status and its assignee, plus the sprint field) are pre-approved too ([D61](design-decisions.md#d61)). Those rules name the connector as claude.ai registers it (`mcp__claude_ai_Atlassian_MCP__…`, setup guide section 3); any other change to Jira still asks. **Codex:** the shared file `.codex/rules/closio-agent.rules` (Codex's "rules", still experimental; they apply when Codex trusts this folder, and the scripts then run outside its sandbox). Anything else still asks.

## Command list

| Command | What it does | Status |
|---|---|---|
| [`flow-ping`](#flow-ping) | Checks that the flow commands are loaded in your tool | Built 2026-10-10 (F1). Works in Claude Code (CLI and desktop app) and Codex |
| [`flow-doctor`](#flow-doctor) | Checks your setup and tells you how to fix each problem | Built 2026-10-10 (F1, F2). Works in Claude Code and Codex. Later pieces add their own checks |
| [`flow-vpn`](#flow-vpn) | Connects, checks or disconnects the Japfa VPN | Built 2026-10-11 (F3). Tested in Claude Code and Codex |
| [`flow-configure-user`](#flow-configure-user) | Sets up your personal settings and your 5 secrets | Built 2026-10-12 (F4). Tested by the user |
| [`flow-configure-repo`](#flow-configure-repo) | Registers a repo, or sets it up on your Mac (path, dev keys) | Built 2026-10-14 (F5). Tested by the user (2026-10-15) |
| [`flow-setup-repo`](#flow-setup-repo) | Gets a repo ready to work on: Node version, packages, local Redis/RabbitMQ, `.env` check, tests, folder access | Built 2026-10-16 (F6). Tested by the user (2026-10-16) |
| [`flow-memory`](#flow-memory) | Shows and manages your user memory: the preferences and corrections every command follows | Built 2026-10-16 (F6b). Tested by the user (2026-10-16) |
| [`flow-check-card`](#flow-check-card) | Checks a Jira card (or a card in a `.md` file) against the team's card template and shows what to fix | Built 2026-10-17 (F7). Tested by the user (2026-10-17) |
| [`flow-help`](#flow-help) | Shows every flow command with what it does and how it's typed, or one command in full | Built 2026-10-17 (F8). Tested by the user (2026-10-17) |
| [`flow-status`](#flow-status) | Where a card stands (phase, step, branch, what to type next), or every card in progress | Built 2026-10-17 (C1). Tested by the user (2026-10-17, on SCRUM-540) |
| [`flow-start`](#flow-start) | Picks up a Jira card and plans it: the card checked, In Development and assigned to you, a branch in every repo, the plan made from the code and approved by you | Built 2026-10-17 (C2). Tested by the user (2026-10-17, on SCRUM-540) |
| [`flow-develop`](#flow-develop) | Develops a planned card with you: the code and its unit tests from the approved plan, the repo checks, then your review | Built 2026-10-17 (C3). Tested by the user (2026-10-17, on SCRUM-540) |
| [`flow-verify`](#flow-verify) | Checks a developed card: every AC with its test cases (API checks or Playwright), the repo tests again and the story check; then the push, or what's wrong for you to decide | Built 2026-10-18 (C4). Not yet tested by the user |
| [`flow-ac-check`](#flow-ac-check) | Adds or changes the test cases of one AC and runs them once | Built 2026-10-18 (C4). Not yet tested by the user |

**Coming, in this order ([D61](design-decisions.md#d61), not built yet):** `flow-push`, `flow-finish`. See [architecture.md](architecture.md).

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
| Repos | The ruleset file every card follows is there (`rulesets/story-implementation-workflow.md`, rule A19); each registered repo: clone exists and points at the right GitLab project; its Node version is installed in nvm; its dev keys are stored | ⚠️ for repos not set up on this Mac, and ⚠️ (not ❌) for missing dev keys: they're only needed to test on dev. Fix: `/flow-configure-repo <repo>` |
| User memory | How many entries you have (never a warning when you have none); ⚠️ for lines in your memory files that aren't in the format | Fix: `/flow-memory` |
| Commands documented | Every flow command has its `## Usage` block, is in a `flow-help` group, its section in this file, its row in [user-guide.md](user-guide.md), and is covered by the guide's Claude artifact ("mirrored" line) | Rule R17, [D60](design-decisions.md#d60). Fix: add what's missing; update the artifact in Claude Code |
| Cards in progress | How many cards have a run folder or a run branch; ❌ for a broken run folder (no `state.md`, a missing line, a folder that isn't a card key) | [D61](design-decisions.md#d61). See them with `/flow-status` |
| Checking web cards | Playwright is set up (`bash scripts/e2e.sh check`) | ⚠️ when it isn't: run `/flow-configure-user playwright` |
| Repo setup | Each repo set up with `flow-setup-repo`: packages still installed, Claude Code can use its folder; one ⚠️ listing cloned repos not set up yet; the local Redis and RabbitMQ answer (when a set-up repo needs them) | Fix: `/flow-setup-repo <repo>` |
| Keychain | The 5 personal items exist | Names only; values are never read ([D33](design-decisions.md#d33)). Fix: `/flow-configure-user <item>` |
| Jira | The AI reads project SCRUM | Done by the AI, because only the AI tool has the Jira connection. The Jira connector can take a while to load when a session starts, so the AI waits and retries up to 3 times (about 30 s) before reporting ❌ |

**In Codex:** Codex runs commands in a sandbox (a closed box). There, the GitLab checks and the Codex background service check may show ⚠️ "can't check from inside Codex's sandbox". The tip says what to do: approve network access, or run `bash scripts/doctor.sh` in a normal terminal. Everything else works the same in both tools (tested 2026-10-11).

Later pieces add their own checks when they're built.

The fixed values it uses (GitLab address, VPN gateway, certificate pin, Keychain names…) come from `config/project-settings.sh` ([D46](design-decisions.md#d46)).

**Output example (shortened):**
```
flow-doctor — checking your setup

Project
✅ Started in the closio-agent folder
✅ Node v22.14.0 is active
✅ Every flow command has its Claude Code link
✅ Rules file AGENTS.md is in place

Tools
✅ Claude Code 2.1.296, installed inside Node 22
⚠️ Docker is installed but not running
   Tip: Open Docker Desktop before running backend tests.

VPN and GitLab
✅ VPN is on (another VPN client, e.g. the FortiClient app) and GitLab is reachable
⚠️ Can't check the GitLab token: it isn't in the Keychain yet
   Tip: See the Keychain section below.

Keychain (names only, values are never read)
❌ closio-agent.gitlab-token is missing
   Fix: In your own terminal (not the AI chat) run: security add-generic-password -U -a "$USER" -s "closio-agent.gitlab-token" -l "closio-agent: gitlab-token" -w
        It asks for the value twice, hidden (setup guide, section 5).

Jira
✅ Jira works: project SCRUM can be read

Result: 1 to fix, 2 to look at.
Checked in Claude Code
```

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
| `ws2-client-id`, `ws2-client-secret` | Calling a WS2 service directly on dev | Yes, for WS2 services |
| `db-user`, `db-password` | Reading the repo's dev database (check migrations, write QA steps) | Optional |
| Any extra named key (e.g. a partner API key) | Whatever the repo needs | As registered |

**Each repo's own Node version (rule A13, [D52](design-decisions.md#d52)):** each repo file records `node_version` from the repo's Dockerfile (all 7 current repos: 22). The agent runs nothing in a repo before `nvm use <that version>`; if nvm doesn't have it, `flow-doctor` and `flow-configure-repo` show ⚠️ with `nvm install <version>`.

**Cloning is manual ([D53](design-decisions.md#d53)):** the agent never clones. If a repo isn't on your Mac, it gives you the `git clone` command and, afterwards, `/flow-configure-repo <repo> path <folder>`.

**Branch names** are one strict rule for every repo, not a repo setting (rule A12, [D50](design-decisions.md#d50)): `SCRUM-<number>/<short-description>`, at most 5 words. `bash scripts/branch-name.sh make SCRUM-519 "<card title>"` builds one; `check` checks one.

**`flow-doctor`** now has a **Repos** section: each repo's clone exists and points at the right GitLab project, and its required dev keys are stored. Repos you haven't set up show ⚠️, not ❌ (you may not work on all of them).

**Files:** `.agents/skills/flow-configure-repo/`, `scripts/configure-repo.sh`, `scripts/branch-name.sh`, `scripts/lib/secret-dialogs.sh` (shared with `flow-configure-user`), `config/repos/<repo>.yaml` (shared), `local/repos/<repo>.yaml` (yours).

---

### `flow-setup-repo`

**Purpose:** gets a registered repo ready to work on, on your Mac ([D54](design-decisions.md#d54)). It works only on a clone you made yourself (cloning is manual, [D53](design-decisions.md#d53)). It never switches branches, pulls, stashes or changes tracked files: the card phases do that. It needs no VPN.

**Usage:**
```
/flow-setup-repo                             each repo's setup state on this Mac
/flow-setup-repo nodejs-ws2closio            set up one repo
/flow-setup-repo all                         every repo cloned on this Mac, one after another
/flow-setup-repo nodejs-ws2closio install    the same, but always reinstall the packages
/flow-setup-repo nodejs-ws2closio services   choose Homebrew or Docker again for Redis and RabbitMQ
$flow-setup-repo …                           (Codex: approve running it outside the sandbox)
```

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

**How every command uses it (never skipped):** each command starts with `bash scripts/memory.sh for setup all`, which prints only the entries that apply. **Claude Code runs it by itself when the command loads** (before the AI even reads the command); in Codex the command's first step tells the AI to run it, and `AGENTS.md` rule 9 repeats it. The AI follows the entries and says in one line which ones it used, e.g. "Using your memory: M2, M3". Later, the card phases will also write those IDs into the card's history.

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
| QA section with no numbered steps; anything that looks like a secret | |

3. Adds one line for the card type: a Spike isn't picked up by the agent; for a Bug, missing sections are fine (you explain them at pick-up); a Subtask is picked up like a Story or Task.
4. Ends with "Ready", "Ready, with N things worth a look" or "Not ready: fix the ❌ lines above".

What the script can't judge (alignment with the code, the WS1 rules, ACs inside the card's scope, real boundary values, every AC covered by a QA step) is checked by the AI when the card is picked up and planned (Phase 2, rule A16). Cards are written by people, later also by a separate pipeline; closio-agent never creates them.

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

**The check behind it (rule R17):** `bash scripts/help.sh check`, run by `flow-doctor` ("Commands documented"), shows ❌ with the fix when any command folder has no `## Usage` block, isn't in a `flow-help` group (the `GROUP_` lines at the top of `scripts/help.sh`; it would show under "Other"), has no section in this file, no row in the user guide's command index, or isn't covered by the guide's "mirrored" line (the Claude artifact is behind).

**Files:** `.agents/skills/flow-help/`, `scripts/help.sh` (you can run `bash scripts/help.sh` in a terminal too), [user-guide.md](user-guide.md).

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
| 6 AC checks | `api-check.sh <KEY>` (backend) or, web: `e2e.sh probe <KEY>` (the API check), then `e2e.sh run <KEY> [--mock <names>]`; failed calls of the card's APIs in failing tests are asked about | Each scenario with `api-call.sh`, compared with the AC and the code (status, error code, message, every response field); after a call that writes, the database is read with `db-run.sh <repo> query` (read only, no yes needed). Web: `e2e.sh probe <KEY> --quick`, then `e2e.sh quick <KEY> [--mock <names>]`, failed API calls asked about as in A |
| 7 Repo tests | `repo-run.sh <repo> test` and `check` again (lint only warns) | same |
| 8 Story check | The `flow-story-check` agent: every AC and the objective built, nothing out of scope, error codes from the code, rules A20–A22 | skipped |
| 9 Clean up | The cleanup SQL shown again and run after your clear yes; the servers stopped; the WS1 session forgotten | The same, then `run.sh quick-clean <KEY>` removes `local/quick-checks/<KEY>/` |
| 10 Result | With QMetry cases only: one line first, `QMetry: <n> of <total> test cases covered (<percent>%)` (`qmetry-import.sh coverage`). All passed: the card moves to the ship phase, next `/flow-push`. Something failed: each failure with a suggestion (`/flow-develop <KEY>` to fix the code, `/flow-ac-check <KEY> <AC> "…"` for a wrong case, or the exact fix for a setup problem); you decide; the card stays in verify | The same without a QMetry line; a scenario checked the wrong way: tell the AI what to check instead and run `/flow-verify <KEY> quick` again |

**`runs/<CARD-KEY>/verify.md`:** one section per run, newest first, earlier runs never overwritten ([D68](design-decisions.md#d68)): `## Run <n> — <date and time> · A full check | B quick check` (or `· flow-ac-check AC <n>`), then (web cards) the APIs, each real or mocked with your answer ([D69](design-decisions.md#d69)), the AC checks (every case or scenario tested with ✅ / ❌, each failure with what was expected and what came back), the repo tests and checks, the story check (A), the test data, and the result.

**Files:** `.agents/skills/flow-verify/`, the agents `flow-ac-checker` and `flow-story-check`, `scripts/repo-run.sh`, `scripts/api-call.sh`, `scripts/api-check.sh`, `scripts/db-run.sh`, `scripts/e2e.sh`, `scripts/qmetry-import.sh`, `scripts/run.sh` (`quick-clean`), `e2e/` (the shared Playwright project).

---

### `flow-ac-check`

**Purpose:** adds, changes or rewrites the test cases of **one AC** of a card (option A's saved cases), runs them once and saves them in its run folder ([D67](design-decisions.md#d67)). `flow-verify`'s full check writes every AC's cases by default; this command is for a new case, a changed case, or a case written again. The next `/flow-verify` (full check) runs them with the rest. The card's phase and Jira don't change.

**Usage:**
```
/flow-ac-check SCRUM-567 3                              write AC 3's cases again from the card and the code
/flow-ac-check SCRUM-567 3 "add a case for ?status=foo"   add or change AC 3's cases as asked
$flow-ac-check …                                        (Codex)
```

**What it does:** checks the card is developed and the AC exists; the `flow-ac-checker` agent writes or changes the AC's cases and shows what changed; for a web card it first asks which of the AC's APIs are available on dev and mocks the others (your exact 200 response, [D69](design-decisions.md#d69)), then runs the API check; it starts the servers the AC needs, adds test data and sends calls that write only after your clear yes, runs just that AC (`api-check.sh <KEY> <AC>` or `e2e.sh run <KEY> <AC>`), cleans up after your yes, records the run in `verify.md` (`## Run <n> — … · flow-ac-check AC <n>`), stops the servers and saves the run folder.

**Files:** `.agents/skills/flow-ac-check/`, the `flow-ac-checker` agent, the scripts above.

---

### `flow-status`

**Purpose:** shows where a card stands in closio-agent, from its run folder `runs/<CARD-KEY>/` ([D61](design-decisions.md#d61), rule A1). It only reads.

**Usage:**
```
/flow-status                 every card in progress (on this Mac and pushed by teammates)   (Claude Code)
/flow-status SCRUM-567       that card's state and the exact command to type next
$flow-status …               (Codex)
```

**What it shows:** the card's phase and step, its Jira status, the repos and the branch, when it was last updated, what to type next, and where the state comes from: this Mac, a run branch on this Mac that isn't checked out, or `origin` (a teammate pushed it; `/flow-start <CARD-KEY>` brings it here).

**Output example:**
```
SCRUM-567 · phase plan, step 7 · next: /flow-start SCRUM-567 · updated 2026-10-17 15:32 · from this Mac
```

**Files:** `.agents/skills/flow-status/`, `scripts/run.sh` (`list`, `state`; you can run `bash scripts/run.sh list` in a terminal too).

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
| 8 Questions first | Lists every difference between the card and the code (error codes, statuses, messages, fields, anything the card names that isn't in the code) and asks you, in one message, with a recommended answer each; waits. Your answers go into `card.md` (A16, A18). When continuing, it asks only what isn't answered there yet; when the card has a WS1 schema, it also asks you to confirm every field the response can return, optional ones included (rule A22) |
| 9 The draft plan | From the ruleset, your memory for the `plan` phase (an entry may change a ruleset point), the card files (`card.md` with your explanations and answers) and the code ([D64](design-decisions.md#d64)), in the ruleset's plan format: `Ruleset: … · Memory applied: …` at the top, the changes as a numbered file list per repo, and an AC → implementation table. Shown in chat; nothing saved yet. It has a `## Validation, reuse and response fields` part: where each request check goes (rule A20), the existing functions it will reuse and each new one (rule A21), and the WS1 response fields (rule A22) |
| 10 ✋ Approval | You approve the plan in chat, or ask for changes until it's right. Strictly necessary (A18) |
| 11 Save | `plan.md` written, the run folder saved and pushed; the next command is [`flow-develop`](#flow-develop) |

**The run folder** `runs/<CARD-KEY>/` ([D61](design-decisions.md#d61)): `state.md` (phase, step, Jira status, repos, branch, next command), `history.md` (one line per step with the rules and memory applied), `card.md`, `plan.md`; later `verify.md`, `ship.md`, `deployment.md`. Plain markdown, never a secret. It's saved to the card's branch of closio-agent and pushed after every phase, so a teammate can continue ([D38](design-decisions.md#d38)): `bash scripts/run.sh branch <CARD-KEY>` brings it onto their Mac. This folder itself never switches to that branch: it stays on `main`, with the current commands and scripts ([D61](design-decisions.md#d61)): `save` commits just the `runs/<CARD-KEY>/` folder to the branch, through a temporary git index, so your working tree and its changes are never touched. On `main` the run folders are git-ignored (`/runs/*/`). `flow-finish` will merge the branch into `main`.

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
| 1 Start | Checks the folder; the card must be in the develop phase (its plan approved), otherwise it says what to type; brings the card's run folder onto this Mac (`run.sh branch`; this folder stays on `main`); connects the VPN; a card that stopped part-way continues at its saved step |
| 2 Repos ready | Folder access first (A15); on the first start `scripts/card-branch.sh update` brings the latest base branch in; when continuing with your uncommitted work it only checks the branch |
| 3 Read | `plan.md`, `card.md`, the ruleset (A19), your memory for `develop`, and the files the plan names plus their neighbours |
| 4 Develop | Repo by repo, in the plan's order (WS2 before WS1): the code follows the closest existing files; it creates the new files the plan lists and any other the work needs; error codes, statuses, messages, fields and constants come from the code, and anything new or different from the plan is asked first (A16). Nothing is committed (G3). Request checks: presence, type and format in the WS1 schema, everything again plus all business logic in WS2 (controller, or a utils function when large; service when it needs the database; rule A20). Before writing any function it searches the repo and reuses an exact match, asking you about a close one (rule A21). The WS1 schema lists every response field (rule A22) |
| 5 Tests | The committed tests, in the repo's own layout: backend unit tests (controller, service) and API tests; Vitest unit tests for the web app; none where a repo has no test suite ([D25](design-decisions.md#d25)). Then `bash scripts/repo-run.sh <repo> test` (every test and the coverage gate, on the repo's Node version, A13), fixing until it passes |
| 6 Checks | `bash scripts/repo-run.sh <repo> check`: **lint** checks only the files the card changed and shows its problems as ⚠️ warnings, never stopping (the repos have older lint errors: about 80 in ws2targetsalesincentive, 550 in ws1closio); the other checks (circular imports) are fixed until they pass |
| 7 Migrations and seeders | First you review the files (the full up and down, what they change, the repo, the database the `.env` names; rule A23), then a separate yes in chat, every run ([D21](design-decisions.md#d21)): `bash scripts/repo-run.sh <repo> migrate confirmed` (or `seed confirmed`); each run is written in `develop.md` for the deployment doc |
| 8 Summary | A short summary of the repo (new and changed files, tests, checks, anything not in the plan), then it carries straight on with the next repo |
| 9 Save | `develop.md` complete; the run folder saved and pushed |
| 10 ✋ Review | Per repo: the changed files, what each plan item became, every change from the plan, and every new function with the search behind it. You review in your editor: "change X" goes back to step 4; "review approved" goes on |
| 11 Finish | The review result in `develop.md`; the card moves to the verify phase; saved and pushed; next: [`flow-verify`](#flow-verify) |

**`runs/<CARD-KEY>/develop.md`:** the plan and ruleset it followed and the memory applied; one section per repo (new and changed files, tests and their result, checks, everything not in the plan with your answer); the migrations and seeders run; the review.

**Files:** `.agents/skills/flow-develop/`, `scripts/repo-run.sh`, `scripts/card-branch.sh`, `scripts/configure-repo.sh` (`ruleset`), `scripts/run.sh`, [rulesets/story-implementation-workflow.md](../rulesets/story-implementation-workflow.md), `runs/<CARD-KEY>/develop.md`.

---

## Helper scripts

The commands run these scripts (in `scripts/`). You can run them yourself in a terminal from the closio-agent folder, after `nvm use v22`. Shared values come from `config/project-settings.sh`.

| Script | What it does | Used by |
|---|---|---|
| `doctor.sh` | All the setup checks (reads only) | `flow-doctor` |
| `vpn.sh connect \| status \| disconnect` | The VPN steps | `flow-vpn`, the `flow-connectivity` agent |
| `vpn-admin-steps.sh` | The few VPN steps that need admin rights (one password dialog). Runs as admin: review changes carefully | `vpn.sh` |
| `password-dialog.sh` | The macOS password dialog for those admin steps | `vpn.sh` |
| `configure-user.sh check-folder \| show \| set \| secrets \| secret \| gitlab-username-from-token` | Personal settings and the 5 secrets | `flow-configure-user` |
| `configure-repo.sh check-folder \| list \| detect \| validate \| set-path \| keys \| key \| show \| ruleset` | The repo registry, clone paths and dev keys; `ruleset <repo>` says which ruleset the repo follows (rule A19) | `flow-configure-repo`; `flow-start` (`ruleset`) |
| `setup-repo.sh check-folder \| list \| run <repo\|all> [install\|services]` | Gets repos ready to work on (Node, packages, local Redis/RabbitMQ, `.env` check, tests, folder access) | `flow-setup-repo` |
| `memory.sh for <phase> [words] \| list \| add \| edit \| set-phases \| remove \| clear-preview \| clear \| count \| problems` | Your user memory: the entries for a command, and managing them | Every command (first step), `flow-memory`, `flow-doctor` |
| `branch-name.sh make <CARD-KEY> "<title>" \| check <name>` | Builds and checks branch names (strict rule A12) | Later phases (Phase 1); you can use it any time |
| `card-check.sh <card file>` | Checks a card's text against the card template: ❌ not ready (with the fix), ⚠️ worth a look; exit code 0 when there's no ❌ | `flow-check-card`; Phase 1 later |
| `help.sh list \| show <command> \| check` | The command help, read from each command's `SKILL.md` (formatted text for the AI, colors in a terminal); `check` = rule R17 (Usage block, `commands.md` section, user-guide row, Claude artifact covering every command) | `flow-help`, `flow-doctor` |
| `run.sh branch \| create \| state \| get \| set \| log \| save \| list \| quick-clean \| count \| problems` | The card's run folder `runs/<CARD-KEY>/`: create it, read and change its state, write its history, and save it to its branch `runs/<CARD-KEY>` of closio-agent and push (never `main`), without ever switching this folder to that branch; `branch` brings the folder onto this Mac (a teammate's too); `quick-clean` removes the quick check's scratch folder `local/quick-checks/<CARD-KEY>/` | `flow-start`, `flow-status`, `flow-doctor`; the later card phases |
| `card-branch.sh check <repo> \| create <repo> <branch> \| update <repo> <branch>` | In a code repo: fetch, pull the base branch and create the card's branch (or reuse it); `update` brings the latest base branch into it (a fast-forward while it has no commits of its own; with its own commits it's left for the rebase in `flow-push`); stops with exit code 3 on uncommitted changes | `flow-start` |
| `repo-run.sh <repo> check \| test \| migrate confirmed \| seed confirmed \| start \| stop \| status` (and `all stop`) | A repo's own commands, in its folder, on its Node version (A13): its check commands (lint only on the files the card changed, as ⚠️ warnings); its tests and coverage gate; `npm run migrate` / `seed` only with the word `confirmed`, after the user's yes ([D21](design-decisions.md#d21)). `start` runs the repo's server in the background and waits for its health URL; `stop` only stops what it started. Output in `local/logs/` | `flow-develop` |
| `api-call.sh <repo> login \| logout \| <METHOD> <path> [--json \| --body] [--header] [--auth user\|none] [--client ok\|none\|id-only\|secret-only\|unknown\|wrong-secret] [--save]` | One API call to a repo running on this Mac. WS1 calls go logged in as you (your WS1 login from the Keychain; the session stays in `local/sessions/`); WS2 calls carry the keys saved with `/flow-configure-repo <repo> key …`, or missing or wrong keys on purpose. Keys, passwords and sessions are never shown | `flow-verify`, `flow-ac-check` (through `api-check.sh`) |
| `api-check.sh <CARD-KEY> [<AC>]` | Runs the card's API test cases (`runs/<CARD-KEY>/api-checks/ac-<n>.json`: the call and what must come back) and says per case and per AC whether they pass | `flow-verify`, `flow-ac-check` |
| `db-run.sh <repo> show <sql> \| run <sql> confirmed \| query <sql>` | A card's test data on the database the repo's `.env` names: `show` prints the SQL to review; `run … confirmed` runs it in one transaction with the repo's own config, only after your yes (A23); `query` only reads (a read-only transaction: the database refuses any change; no COMMIT, SET and the like) and prints the rows, no yes needed | `flow-verify`, `flow-ac-check` |
| `e2e.sh check \| setup \| run <CARD-KEY> [<AC>] [--mock <names>] \| quick <CARD-KEY> [<AC>] [--mock <names>] \| probe <CARD-KEY> [--quick] [--mock <names>]` | Playwright: is it set up; set it up (`e2e/` packages and Chromium); run a card's tests (`runs/<CARD-KEY>/e2e/`; `quick`: the quick check's one-off tests in `local/quick-checks/<CARD-KEY>/`) against the web app on this Mac, logged in with your FE login; `--mock` turns on those mocks of the card's `api-mocks.ts`. No test run at all is a ❌. Under failing tests it lists the API calls that got no answer or a 5xx from dev (the card's APIs first, other screens' calls apart). `probe`: the API check before the run (logs in once, calls each GET API of the card's `api-list.json` that isn't mocked; ⚠️ for one that looks unavailable) | `flow-configure-user`, `flow-verify`, `flow-ac-check`, `flow-doctor` |
| `qmetry-import.sh <CARD-KEY> <export.xlsx> \| coverage <CARD-KEY>` | Saves a QMetry test-case export of a card as markdown in `runs/<CARD-KEY>/qmetry/`, the base for its test cases (QMetry can't be read through the Jira tools); `coverage` counts how many of its cases the card's test cases cover (a case's QMetry key in a test's name) | `flow-verify`, `flow-ac-check` |
| `link-claude-skills.sh` | Adds the Claude Code link for every command (run it after adding a command) | Setup; `flow-doctor` tells you when |
| `wait-seconds.sh <1-30>` | Waits a few seconds (e.g. while Jira loads) | `flow-doctor`, `flow-configure-user` |
| `lib/secret-dialogs.sh` | The heads-up and hidden box for secrets | `configure-user.sh`, `configure-repo.sh` |

## Agents

Agents are helpers that commands start; you don't type them.

| Agent | What it does | Files |
|---|---|---|
| `flow-connectivity` | Connects the VPN if needed and checks GitLab, at the start of every phase that needs it (Phases 1–9). Limits: 3 steps in Claude Code, 180 s for the SSO login ([D47](design-decisions.md#d47)) | `.claude/agents/flow-connectivity.md`, `.codex/agents/flow-connectivity.toml` |
| `flow-ac-checker` | Writes or updates a card's test cases, one file per AC, in its run folder (API checks for backend cards, Playwright tests for web cards), from the card's QMetry export when there is one (the base, each case with its QMetry key), otherwise from the card and the code. A web test that needs an answer the dev data or the server can't give on demand (a 500, more than 5 items, a fixed order) answers the screen's one API call itself (`page.route`, the response shape and error codes from the code) and ends its name with `(answer from the test)`. Never runs them. Limit: 60 steps ([D47](design-decisions.md#d47)) | `.claude/agents/flow-ac-checker.md`, `.codex/agents/flow-ac-checker.toml` |
| `flow-story-check` | Checks the build against the card's story (ACs, out of scope, error codes, rules A20–A22) and lists what's missing or extra. Only reads. Limit: 15 steps | `.claude/agents/flow-story-check.md`, `.codex/agents/flow-story-check.toml` |

