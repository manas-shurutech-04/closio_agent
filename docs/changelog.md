# Changelog

Dated list of what changed in closio-agent. Newest first.

## 2026-10-17

- **New rule A16** ([D59](design-decisions.md#d59), `AGENTS.md` rule 10): error codes, statuses and messages always come from the code. Before developing a card, the agent reads the existing ones in every repo involved, checks the card's error reference against them, points out every difference and never invents new ones.
- **Jira card template (F7, [D58](design-decisions.md#d58)):** new [jira-card-template.md](jira-card-template.md), the single place for the card rules (the sections, the AC and QA rules, code alignment, how a card is drafted, the ready checklist), and [jira-card-examples.md](jira-card-examples.md) (SCRUM-559 and SCRUM-567 in full). Cards are written by people, later also by a separate pipeline; closio-agent never creates them.
- **`flow-check-card` (F7):** checks a Jira card, or a card in a `.md` file, against the template with the new `scripts/card-check.sh` (❌ not ready, ⚠️ worth a look, every ❌ with its fix), and tells you about Spikes (not picked up) and Bugs (missing sections are explained at pick-up). It only reads; the card's text is saved privately in `local/cards/`. Pre-approved in both tools ([D57](design-decisions.md#d57)).
- **No prompts for Jira reads in Claude Code:** the shared `.claude/settings.json` now also pre-approves the read-only Jira tools the commands use (a project, an issue, a search, your account), so `flow-doctor`, `flow-configure-user` and `flow-check-card` don't ask each session ([D57](design-decisions.md#d57)). Changing Jira still asks.

## 2026-10-16

- `flow-memory clear` (all your entries) and `flow-memory clear <repo>` (one repo's): it lists what it would remove and asks before removing anything.
- `flow-memory` tested by the user; working.
- Fixed: `/flow-memory` (and every command, once you had a memory entry) stopped with "Shell command failed" because the memory step broke on the space in the folder name. It now works with any folder name and never stops a command: a problem shows as ⚠️ and the command goes on.
- **`flow-memory` (F6b):** your private user memory (`local/memory/`): list, add (everywhere or for one repo), edit, change phases, remove. Every command now starts with the memory step, which Claude Code runs by itself when the command loads (Codex: the first step); the AI says which entries it used and offers to save your corrections ([D56](design-decisions.md#d56), `AGENTS.md` rule 9).
- **No approval prompts for our own scripts** in Claude Code (`.claude/settings.json`, now incl. the git name/email change) and in Codex (`.codex/rules/closio-agent.rules`) ([D57](design-decisions.md#d57)).
- `flow-doctor`: user memory line; `docker info` gets a 10-second limit (it could hang while Docker Desktop was stuck), shown as ⚠️ "Docker Desktop doesn't answer".
- `flow-setup-repo` also compares the variable names in a repo's `.env` with `.env.example` (never the values) and lists the missing ones, with the file opened for you.
- **New rule A15** ([D55](design-decisions.md#d55), `AGENTS.md` rule 8): before working in a code repo, the AI checks it can use the repo's folder; if not, it asks you to give access and waits.
- `flow-setup-repo` tested by the user; working.
- `flow-setup-repo` runs without an approval prompt in Claude Code (`bash scripts/setup-repo.sh run …` pre-approved in `.claude/settings.json`).
- **`flow-setup-repo` (F6):** gets a repo you've cloned ready to work on: the repo's own Node version (installed with nvm if missing), packages (only when needed), the local Redis and RabbitMQ (checks both Homebrew and Docker; one → used, both → you choose once and the other is stopped, none → it suggests one), a check that the repo's `.env` points to them (never showing a value; it opens the file with the lines to set), the tests once (15-minute limit, log in `local/logs/`), and folder access for Claude Code (Codex: a start command). `all` does every cloned repo. No VPN needed; it never changes branches ([D54](design-decisions.md#d54)).
- `flow-doctor`: new "Repo setup" section (packages, folder access, local Redis/RabbitMQ answering). Docker is no longer required: it's only checked if you chose Docker for Redis or RabbitMQ.
- New shared file `config/local-services.yml` (Docker copies of Redis 7 and RabbitMQ 4) and new settings in `config/project-settings.sh` (time limits, local ports).
- `flow-configure-user` keeps your saved Redis/RabbitMQ choice when it rewrites `local/user-settings.sh`.

## 2026-10-15

- `closio-web-v2` repo file: test command `npm test -- --run` (one run, never watch mode) and env file `.env.development` ([D54](design-decisions.md#d54)).
- `flow-setup-repo` (F6) designed ([D54](design-decisions.md#d54)); the `flow-connectivity` agent no longer runs in it (no VPN needed).
- `flow-configure-repo` tested by the user; working.
- New [agent-rules.md](agent-rules.md): every rule the agent follows (git rules G1–G4, behaviour rules A1–A14) in one place, each with its decision, its `AGENTS.md` number and where it's applied today.

## 2026-10-14

- **Each repo runs on its own Node version** (rule A13 changed, [D52](design-decisions.md#d52)): `node_version` from the repo's Dockerfile; `nvm install <version>` if it's missing (`flow-doctor` and `flow-configure-repo` warn). Claude Code, Codex and closio-agent stay on Node 22. `AGENTS.md` rule 6 updated.
- **Cloning stays manual** ([D53](design-decisions.md#d53)): the agent never clones; it gives you the `git clone` command. `AGENTS.md` rule 7. `flow-setup-repo` (F6) won't clone.
- `commands.md`: new sections listing every helper script and the agents.
- `flow-configure-repo`: step-by-step for adding a brand-new repo later (commands.md); repos that aren't Node can be added too (Go suggestions, others by your answers; new `language` field); new `… <repo> path <new path>` to change where a clone is.
- `flow-doctor` and `flow-configure-repo`: a repo's missing dev keys now show ⚠️ (worth a look) instead of ❌; they're only needed to test that repo on dev.
- **Every repo runs on Node 22 (rule A13):** the agent checks `node -v` and runs `nvm use v22` before running anything in a repo; `AGENTS.md` rule 6; each repo file records `node_version: 22`.
- MR labels and reviewers: optional defaults in each repo file (`none` for now), confirmed or changed each time an MR is created.
- **The 7 repos are registered** in `config/repos/` (base branch `develop`, web `development`; ports come from each repo's `.env`; health URL `/api/v1/health-checker` for every backend repo and `/` for the web app, now required for every repo; MR labels and reviewers none for now; dev database details to be added later).
- **`flow-configure-repo` (F5):** registers a repo (the AI suggests the values from the repo, you confirm; shared file `config/repos/<repo>.yaml`) or sets it up on your Mac (clone path in `local/repos/`, dev keys in the Keychain: WS2 client ID/secret, optional dev database user/password, extra keys). `flow-doctor` has a new Repos section ([D51](design-decisions.md#d51)).
- **Strict branch names (rule A12, [D50](design-decisions.md#d50)):** `SCRUM-<number>/<short-description>`, at most 5 words, same name in every repo; `scripts/branch-name.sh`. Added to `AGENTS.md` (rule 5).
- Secret dialogs moved to `scripts/lib/secret-dialogs.sh`, shared by both setup commands.

## 2026-10-13

- Jira check in `flow-doctor` and `flow-configure-user`: waits and retries up to 3 times (about 30 s) while the Atlassian connector loads, and the fix now says how to reconnect it (`/mcp`). New `scripts/wait-seconds.sh`.
- `flow-configure-user` tested by the user; working.
- `flow-configure-user` asks all missing secrets in one go. New shared `.claude/settings.json` lets Claude Code run our own setup scripts without an approval prompt each time; changing git name/email still asks ([D49](design-decisions.md#d49)).

## 2026-10-12

- **`flow-configure-user` (F4):** sets up your personal settings (`local/user-settings.sh`) and your 5 secrets (heads-up message, then a hidden macOS box, straight into the Keychain). The VPN profile is kept as optional. `flow-doctor` now checks your personal settings and uses your AI tools setting.
- Agents get their own limits ([D47](design-decisions.md#d47)); `flow-connectivity` now has a step limit of 3. One GitLab token for everything ([D48](design-decisions.md#d48)).

## 2026-10-11

- **`flow-vpn` (F3):** `connect`, `status`, `disconnect` the Japfa VPN with one macOS password dialog; the SSO page opens by itself; cleans up after a timeout or a changed certificate; removes the old GitLab-only DNS file; the VPN stays on until you disconnect. New `flow-connectivity` agent (Claude Code and Codex) for the phases. `flow-doctor` tips now point to `flow-vpn` ([D30](design-decisions.md#d30)). All live tests passed in both tools.
- **closio-agent is on GitHub** (private): `https://github.com/manas-shurutech-04/closio_agent.git`. Clone steps in the README and the setup guide.
- `flow-doctor` tested by the user in Claude Code and Codex. Fixed: inside Codex's sandbox, the Codex background service check now says "can't check from here" instead of a wrong ✅. Jira in Codex works through the Atlassian app on your ChatGPT account (setup guide, section 3).

## 2026-10-10

- **`flow-doctor` full version (F2):** checks tools (git, Claude Code, Codex and its background service, openfortivpn, Docker), VPN and GitLab (incl. your GitLab token), leftover DNS files, the VPN certificate pin, the 5 Keychain items (names only) and Jira (by the AI). New symbol ⚠️ for "worth a look". Every problem comes with the steps to fix it (rule A11). Shared settings moved to `config/project-settings.sh` ([D46](design-decisions.md#d46)).
- `AGENTS.md`: new rule 4, always give the steps to fix anything that fails.
- `flow-doctor`: when Node is wrong, the fix now also says how to restart Codex's background service. The setup guide explains Codex's updater process, which can bring back the wrong Node.
- **Codex** is now installed with npm inside Node v22, like Claude Code. Its background service must be started from Node v22 (`codex app-server daemon restart`), or `flow-doctor` shows the wrong Node ([setup guide](setup-guide.md#install-claude-code-and-codex-inside-node-v22--verified), [D41](design-decisions.md#d41)).
- **`AGENTS.md`** added: rules both Claude Code and Codex read in every session, so the AI doesn't do a command's steps unless you type the command ([D45](design-decisions.md#d45)).
- **First commands (F1):** [`flow-ping`](commands.md#flow-ping) and the first version of [`flow-doctor`](commands.md#flow-doctor) (checks: started in the closio-agent folder, Node v22 active, Claude Code links in place).
- Commands are written once in `.agents/skills/` and linked for Claude Code by `scripts/link-claude-skills.sh` ([D8](design-decisions.md#d8)).
- Every command name starts with `flow-` ([D43](design-decisions.md#d43)) and only runs when you type it ([D44](design-decisions.md#d44)).
- The whole project uses **Node v22**; run `nvm use v22` before starting Claude Code or Codex ([D41](design-decisions.md#d41)). Claude Code is installed with npm inside Node v22.
- Always start Claude Code or Codex **in the closio-agent folder** ([D42](design-decisions.md#d42)).
- `.claude/settings.local.json` (personal Claude Code settings) is now git-ignored.

## 2026-10-09

- Project folder set up as a git repository with its folder layout (F0, [D39](design-decisions.md#d39)). No commands yet.
