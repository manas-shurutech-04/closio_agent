# closio-agent — Documentation

## What the agent does

`closio-agent` is an automated AI agent that takes a specified JIRA card through the delivery flow:

**Pick up the JIRA card → … → MR (Merge Request) review → Deployment doc creation**

> Status: every command is built, the setup commands and every card phase (2026-10-19; see [architecture.md](architecture.md)); they're being tried on real cards. Commands: `flow-ping`, `flow-doctor`, `flow-vpn`, `flow-configure-user`, `flow-configure-repo`, `flow-setup-repo`, `flow-memory`, `flow-check-card`, `flow-help`, `flow-grill`, `flow-status`, `flow-start`, `flow-develop`, `flow-verify`, `flow-ac-check`, `flow-push`, `flow-review`, `flow-finish`, `flow-qa`, see [commands.md](commands.md). When the Jira connector isn't there, the commands switch by themselves to the Jira API backup ([setup guide, section 3.1](setup-guide.md#31-the-jira-api-backup-optional), [D88](design-decisions.md#d88)).

> **New to closio-agent?** Start with [user-guide.md](user-guide.md): the whole process step by step, in plain words. The same guide in pictures, starting with every command in order and what each one needs: https://claude.ai/code/artifact/a83b1e2a-0e5a-4378-b791-26b9f34e8b7a (a Claude artifact). To show the team, there's a presentation, [closio-agent at a glance](https://claude.ai/artifact/TvNhSGz3gP8YdxkqHXJPaZ): 21 slides with flowcharts and the reasons behind each decision, private until it's shared from its Share menu. The details of each setup step are in [setup-guide.md](setup-guide.md); the whole flow is in [architecture.md](architecture.md).
>
> **Every time:** start Claude Code or Codex **in the closio-agent folder**, after `nvm use v22` ([setup guide](setup-guide.md#how-to-start-claude-code-or-codex-every-time), [D41](design-decisions.md#d41), [D42](design-decisions.md#d42)).

## Where to find things

| Doc | What it covers | Status |
|-----|----------------|--------|
| [user-guide.md](user-guide.md) | closio-agent step by step: which command to type, in what order, what each one asks, every option. Mirrored into a Claude artifact ([D60](design-decisions.md#d60)) | Available (added 2026-10-17, F8) |
| [design-decisions.md](design-decisions.md) | Every decision taken, including the options we rejected and why | Available |
| [setup-guide.md](setup-guide.md) | Access needed, installation, configuration, first run | Available: setup with the commands (`flow-doctor`, `flow-vpn`, `flow-configure-user`, `flow-configure-repo`, `flow-setup-repo`), with the manual steps kept as a backup |
| [commands.md](commands.md) | Every agent command: purpose, usage, inputs, outputs, example | Available: `flow-ping`, `flow-doctor`, `flow-vpn`, `flow-configure-user`, `flow-configure-repo`, `flow-setup-repo`, `flow-memory`, `flow-check-card`, `flow-help`, `flow-grill`, `flow-status`, `flow-start`, `flow-develop`, `flow-verify`, `flow-ac-check`, `flow-push`, `flow-review`, `flow-finish`, `flow-qa` |
| [architecture.md](architecture.md) | How the pipeline stages connect and what each one takes in and produces | Available (phases approved; first commands built) |
| [agent-rules.md](agent-rules.md) | Every rule the agent follows when it runs (G1–G4, A1–A31), each with its decision and where it's applied today | Available (added 2026-10-15) |
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
| `tests/` | closio-agent's own tests (`bash tests/run.sh`; `--coverage` for the share of the scripts they ran, 90% or more): one file per script in `tests/unit/`, the commands and rules in `tests/static/`, a card's journey through the scripts in `tests/flows/`, the fakes in `tests/fakes/` ([D92](design-decisions.md#d92)) | ✅ |
| `rulesets/` | The ruleset every card follows, kept by the closio-agent builders; users change its points for themselves only with `flow-memory` ([D64](design-decisions.md#d64), rule A19). And `frontend-story-workflow.md`: the web app's own ruleset: how a screen, its API calls and its tests are built ([D80](design-decisions.md#d80)). And `grilling.md`: how decisions are asked during a card, in rounds with recommended answers, facts found first ([D76](design-decisions.md#d76), rule A26; memory can't change it). And `code-review.md`: what `flow-review` checks in a card's code: the story, and the basics such as no redundant code and the right file for each piece ([D78](design-decisions.md#d78)). And `card-rules.md`: the rules a hook adds to every prompt about a card, first of all that every decision is recorded the moment it's made ([D86](design-decisions.md#d86), rule A29) | ✅ |
| `e2e/` | Playwright project ([D24](design-decisions.md#d24)) | ✅ (dependencies and outputs ignored) |
| `runs/<CARD-KEY>/` | The agent's own memory per card, saved to the card's branch `runs/<CARD-KEY>` without switching this folder (git-ignored on `main`), **committed and pushed to GitHub automatically** after every reply while you work on the card ([D87](design-decisions.md#d87)); shared ([D36](design-decisions.md#d36), [D38](design-decisions.md#d38), [D61](design-decisions.md#d61)) | ✅ on the card's branch |
| `local/` | Personal settings, local repo paths ([D39](design-decisions.md#d39)), the **user memory** `local/memory/` ([D40](design-decisions.md#d40)) and the text of cards checked with `flow-check-card` (`local/cards/`, [D58](design-decisions.md#d58)), and the texts the Jira API backup posts (`local/jira/`, [D88](design-decisions.md#d88)) | ❌ git-ignored |
| `docs/` | Team documentation (this folder) | ✅ |
| `build-memory/` | Working memory used while building the agent | ✅ |
