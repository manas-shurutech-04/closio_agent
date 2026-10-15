# Commands

Every closio-agent command starts with **`flow-`** ([D43](design-decisions.md#d43)).

- **Claude Code:** type `/flow-<name>`
- **Codex:** type `$flow-<name>`, or pick it from `/skills`

Before you start: open a terminal **in the closio-agent folder**, run `nvm use v22`, then start `claude` or `codex` ([setup guide](setup-guide.md#how-to-start-claude-code-or-codex-every-time)).

## How the commands work

- **Written once, used by both tools ([D8](design-decisions.md#d8)).** Each command lives in `.agents/skills/<name>/SKILL.md`, where Codex reads it. Claude Code reads `.claude/skills/<name>`, which is a link to the same folder. `scripts/link-claude-skills.sh` creates any missing links.
- **They only run when you type them ([D44](design-decisions.md#d44)).** The tool never starts a command by itself. Claude Code: `disable-model-invocation: true` in `SKILL.md`. Codex: `agents/openai.yaml` in the command's folder. Also, the rules file `AGENTS.md` tells the AI not to do a command's steps by hand: if you ask for what a command does (e.g. "check my setup"), it tells you which command to type ([D45](design-decisions.md#d45)). Tested in both tools on 2026-10-10. This is an instruction, not a hard lock, so the tool still asks before running a script.
- **Your user memory is applied ([D40](design-decisions.md#d40), rules A7/A8).** Every command first reads `local/memory/general.md` if it exists. Team rules always win.
- **Shared logic lives in `scripts/`.** The command tells the AI which script to run, so both tools do the same thing.

**Fewer approval prompts (Claude Code, [D49](design-decisions.md#d49)):** the shared file `.claude/settings.json` lets Claude Code run our own scripts without asking, but only the parts that just read or ask you themselves in a macOS dialog: `configure-user.sh` (not the git name/email change), `configure-repo.sh` (all its steps), `branch-name.sh`, `doctor.sh`, `vpn.sh`, `wait-seconds.sh`, and writing files in `config/repos/`. Everything else still asks.

## Command list

| Command | What it does | Status |
|---|---|---|
| [`flow-ping`](#flow-ping) | Checks that the flow commands are loaded in your tool | Built 2026-10-10 (F1). Works in Claude Code (CLI and desktop app) and Codex |
| [`flow-doctor`](#flow-doctor) | Checks your setup and tells you how to fix each problem | Built 2026-10-10 (F1, F2). Works in Claude Code and Codex. Later pieces add their own checks |
| [`flow-vpn`](#flow-vpn) | Connects, checks or disconnects the Japfa VPN | Built 2026-10-11 (F3). Tested in Claude Code and Codex |
| [`flow-configure-user`](#flow-configure-user) | Sets up your personal settings and your 5 secrets | Built 2026-10-12 (F4). Tested by the user |
| [`flow-configure-repo`](#flow-configure-repo) | Registers a repo, or sets it up on your Mac (path, dev keys) | Built 2026-10-14 (F5). Live tests pending |

---

### `flow-ping`

**Purpose:** the quickest way to see that closio-agent is installed and its commands load in your tool. It changes nothing and runs no commands.

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
| | Docker installed (and running) | ⚠️ if not running: only needed for backend tests |
| VPN and GitLab | VPN on and GitLab reachable | "On" means GitLab answers, through openfortivpn **or** another VPN client such as the FortiClient app. ⚠️ if off: fine until you need GitLab |
| | GitLab token works (shows your GitLab username) | Only when the VPN is on. The token is read from the Keychain by the script and never shown |
| | VPN DNS file: present when openfortivpn is on, **gone** when the VPN is off | A leftover file stops the next connection ([D27](design-decisions.md#d27)) |
| | Old GitLab-only DNS file | ⚠️ "no longer needed" |
| | VPN certificate pin still valid | ⚠️ in the last 30 days, ❌ after 2027-02-03 |
| Personal settings | Jira account ID, GitLab username, workspace folder (exists), AI tools | Fix: `/flow-configure-user` ([D15](design-decisions.md#d15)) |
| Repos | Each registered repo: clone exists and points at the right GitLab project; its Node version is installed in nvm; its dev keys are stored | ⚠️ for repos not set up on this Mac, and ⚠️ (not ❌) for missing dev keys: they're only needed to test on dev. Fix: `/flow-configure-repo <repo>` |
| Keychain | The 5 personal items exist | Names only; values are never read ([D33](design-decisions.md#d33)). Fix: `/flow-configure-user <item>` |
| Jira | The AI reads project SCRUM | Done by the AI, because only the AI tool has the Jira connection. The Jira connector can take a while to load when a session starts, so the AI waits and retries up to 3 times (about 30 s) before reporting ❌ |

**In Codex:** Codex runs commands in a sandbox (a closed box). There, the GitLab checks and the Codex background service check may show ⚠️ "can't check from inside Codex's sandbox". The tip says what to do: approve network access, or run `bash scripts/doctor.sh` in a normal terminal. Everything else works the same in both tools (tested 2026-10-11).

Checks for pieces not built yet are added by those pieces: installed dependencies and local Redis/RabbitMQ/BullMQ (F6).

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

**The connectivity agent:** `flow-connectivity` (`.claude/agents/flow-connectivity.md`, `.codex/agents/flow-connectivity.toml`) runs the same `connect` at the start of every phase that needs GitLab (Phases 1–9, `flow-setup-repo`) and reports one line ([D30](design-decisions.md#d30)). You don't call it yourself.

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

## Helper scripts

The commands run these scripts (in `scripts/`). You can run them yourself in a terminal from the closio-agent folder, after `nvm use v22`. Shared values come from `config/project-settings.sh`.

| Script | What it does | Used by |
|---|---|---|
| `doctor.sh` | All the setup checks (reads only) | `flow-doctor` |
| `vpn.sh connect \| status \| disconnect` | The VPN steps | `flow-vpn`, the `flow-connectivity` agent |
| `vpn-admin-steps.sh` | The few VPN steps that need admin rights (one password dialog). Runs as admin: review changes carefully | `vpn.sh` |
| `password-dialog.sh` | The macOS password dialog for those admin steps | `vpn.sh` |
| `configure-user.sh check-folder \| show \| set \| secrets \| secret \| gitlab-username-from-token` | Personal settings and the 5 secrets | `flow-configure-user` |
| `configure-repo.sh check-folder \| list \| detect \| validate \| set-path \| keys \| key \| show` | The repo registry, clone paths and dev keys | `flow-configure-repo` |
| `branch-name.sh make <CARD-KEY> "<title>" \| check <name>` | Builds and checks branch names (strict rule A12) | Later phases (Phase 1); you can use it any time |
| `link-claude-skills.sh` | Adds the Claude Code link for every command (run it after adding a command) | Setup; `flow-doctor` tells you when |
| `wait-seconds.sh <1-30>` | Waits a few seconds (e.g. while Jira loads) | `flow-doctor`, `flow-configure-user` |
| `lib/secret-dialogs.sh` | The heads-up and hidden box for secrets | `configure-user.sh`, `configure-repo.sh` |

## Agents

Agents are helpers that commands start; you don't type them.

| Agent | What it does | Files |
|---|---|---|
| `flow-connectivity` | Connects the VPN if needed and checks GitLab, at the start of every phase that needs it (Phases 1–9, `flow-setup-repo`). Limits: 3 steps in Claude Code, 180 s for the SSO login ([D47](design-decisions.md#d47)) | `.claude/agents/flow-connectivity.md`, `.codex/agents/flow-connectivity.toml` |

