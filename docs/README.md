# closio-agent — Documentation

## What the agent does

`closio-agent` is an automated AI agent that takes a specified JIRA card through the delivery flow:

**Pick up the JIRA card → … → MR (Merge Request) review → Deployment doc creation**

> Status: in design. The phases are approved (see [architecture.md](architecture.md)). Commands built so far: `flow-ping`, `flow-doctor`, `flow-vpn`, `flow-configure-user`, `flow-configure-repo`, `flow-setup-repo`, `flow-memory`, `flow-check-card`, `flow-help`, `flow-status`, `flow-start`, `flow-develop`, `flow-verify`, `flow-ac-check`, see [commands.md](commands.md).

> **New to closio-agent?** Start with [user-guide.md](user-guide.md): the whole process step by step, in plain words (also as a Claude artifact, link at its top). The details of each setup step are in [setup-guide.md](setup-guide.md); the whole flow is in [architecture.md](architecture.md).
>
> **Every time:** start Claude Code or Codex **in the closio-agent folder**, after `nvm use v22` ([setup guide](setup-guide.md#how-to-start-claude-code-or-codex-every-time), [D41](design-decisions.md#d41), [D42](design-decisions.md#d42)).

## Where to find things

| Doc | What it covers | Status |
|-----|----------------|--------|
| [user-guide.md](user-guide.md) | closio-agent step by step: which command to type, in what order, what each one asks, every option. Mirrored into a Claude artifact ([D60](design-decisions.md#d60)) | Available (added 2026-10-17, F8) |
| [design-decisions.md](design-decisions.md) | Every decision taken, including the options we rejected and why | Available |
| [setup-guide.md](setup-guide.md) | Access needed, installation, configuration, first run | Available: setup with the commands (`flow-doctor`, `flow-vpn`, `flow-configure-user`, `flow-configure-repo`, `flow-setup-repo`), with the manual steps kept as a backup |
| [commands.md](commands.md) | Every agent command: purpose, usage, inputs, outputs, example | Available: `flow-ping`, `flow-doctor`, `flow-vpn`, `flow-configure-user`, `flow-configure-repo`, `flow-setup-repo`, `flow-memory`, `flow-check-card`, `flow-help`, `flow-status`, `flow-start`, `flow-develop`, `flow-verify`, `flow-ac-check` |
| [architecture.md](architecture.md) | How the pipeline stages connect and what each one takes in and produces | Available (phases approved; first commands built) |
| [agent-rules.md](agent-rules.md) | Every rule the agent follows when it runs (G1–G4, A1–A23), each with its decision and where it's applied today | Available (added 2026-10-15) |
| [jira-card-template.md](jira-card-template.md) | What a Jira card looks like: the sections, the AC and QA rules, code alignment, how a card is drafted, the ready checklist | Available (added 2026-10-17, F7) |
| [jira-card-examples.md](jira-card-examples.md) | Two real cards (SCRUM-559, SCRUM-567) in the template's shape | Available (added 2026-10-17, F7) |
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
| `rulesets/` | The ruleset every card follows, kept by the closio-agent builders; users change its points for themselves only with `flow-memory` ([D64](design-decisions.md#d64), rule A19) | ✅ |
| `e2e/` | Playwright project ([D24](design-decisions.md#d24)) | ✅ (dependencies and outputs ignored) |
| `runs/<CARD-KEY>/` | The agent's own memory per card, saved to the card's branch `runs/<CARD-KEY>` without switching this folder (git-ignored on `main`); shared ([D36](design-decisions.md#d36), [D38](design-decisions.md#d38), [D61](design-decisions.md#d61)) | ✅ on the card's branch |
| `local/` | Personal settings, local repo paths ([D39](design-decisions.md#d39)), the **user memory** `local/memory/` ([D40](design-decisions.md#d40)) and the text of cards checked with `flow-check-card` (`local/cards/`, [D58](design-decisions.md#d58)) | ❌ git-ignored |
| `docs/` | Team documentation (this folder) | ✅ |
| `build-memory/` | Working memory used while building the agent | ✅ |
