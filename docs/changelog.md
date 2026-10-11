# Changelog

Dated list of what changed in closio-agent. Newest first.

## 2026-10-11

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
