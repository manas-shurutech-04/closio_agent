# closio-agent — Documentation

## What the agent does

`closio-agent` is an automated AI agent that takes a specified JIRA card through the delivery flow:

**Pick up the JIRA card → … → MR (Merge Request) review → Deployment doc creation**

> Status: in design. The phases are approved (see [architecture.md](architecture.md)). Commands built so far: `flow-ping`, `flow-doctor`, `flow-vpn`, `flow-configure-user`, `flow-configure-repo`, `flow-setup-repo`, see [commands.md](commands.md).

> **New to closio-agent?** Start with [setup-guide.md](setup-guide.md) to prepare your Mac (VPN, GitLab token, Keychain secrets, repos), then read [architecture.md](architecture.md).
>
> **Every time:** start Claude Code or Codex **in the closio-agent folder**, after `nvm use v22` ([setup guide](setup-guide.md#how-to-start-claude-code-or-codex-every-time), [D41](design-decisions.md#d41), [D42](design-decisions.md#d42)).

## Where to find things

| Doc | What it covers | Status |
|-----|----------------|--------|
| [design-decisions.md](design-decisions.md) | Every decision taken, including the options we rejected and why | Available |
| [setup-guide.md](setup-guide.md) | Access needed, installation, configuration, first run | Available: setup with the commands (`flow-doctor`, `flow-vpn`, `flow-configure-user`, `flow-configure-repo`, `flow-setup-repo`), with the manual steps kept as a backup |
| [commands.md](commands.md) | Every agent command: purpose, usage, inputs, outputs, example | Available: `flow-ping`, `flow-doctor`, `flow-vpn`, `flow-configure-user`, `flow-configure-repo`, `flow-setup-repo` |
| [architecture.md](architecture.md) | How the pipeline stages connect and what each one takes in and produces | Available (phases approved; first commands built) |
| [agent-rules.md](agent-rules.md) | Every rule the agent follows when it runs (G1–G4, A1–A15), each with its decision and where it's applied today | Available (added 2026-10-15) |
| [changelog.md](changelog.md) | Dated list of what changed in the agent | Available |

## Repository layout

This project folder is the `closio-agent` repository that the team clones ([D36](design-decisions.md#d36)). The top-level [README](../README.md) is the entry point.

| Folder | Purpose | Committed? |
|--------|---------|------------|
| `AGENTS.md` | Rules the AI follows in every session here, read by both Claude Code and Codex ([D45](design-decisions.md#d45)). Don't add a `CLAUDE.md` | ✅ |
| `.agents/skills/` | The agent's commands (skills), one source for Claude Code and Codex ([D8](design-decisions.md#d8)) | ✅ |
| `.claude/agents/`, `.codex/agents/` | Custom agents, one file per tool (e.g. `flow-connectivity`, [D30](design-decisions.md#d30)) | ✅ |
| `config/repos/` | Shared repo registry, one file per repo ([D35](design-decisions.md#d35), [D39](design-decisions.md#d39)) | ✅ |
| `scripts/` | Helper scripts the commands run | ✅ |
| `e2e/` | Playwright project ([D24](design-decisions.md#d24)) | ✅ (dependencies and outputs ignored) |
| `runs/<CARD-KEY>/` | The agent's own memory per card; shared ([D36](design-decisions.md#d36), [D38](design-decisions.md#d38)) | ✅ |
| `local/` | Personal settings, local repo paths ([D39](design-decisions.md#d39)) and the **user memory** `local/memory/` ([D40](design-decisions.md#d40)) | ❌ git-ignored |
| `docs/` | Team documentation (this folder) | ✅ |
| `build-memory/` | Working memory used while building the agent | ✅ |
