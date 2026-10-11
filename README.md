# closio-agent

An AI agent for the Japfa **Closio** team. It takes a Jira card from **SCRUM** through the whole delivery flow: pick up the card, plan, develop with you, test, push with atomic commits, create the merge requests, and write the deployment doc.

It runs as commands inside **Claude Code** (`/flow-start`) and **Codex** (`$flow-start`). Every command starts with `flow-` and only runs when you type it ([D43](docs/design-decisions.md#d43), [D44](docs/design-decisions.md#d44)).

> **Status:** in design. The foundation (setup commands) is being built first; see the build plan in [build-memory/project-context.md](build-memory/project-context.md). First commands: `flow-ping` and `flow-doctor` ([docs/commands.md](docs/commands.md)).

## Start here

> **Every time you use it:** open a terminal in **this folder**, run `nvm use v22`, then start `claude` or `codex`. Never start it inside a code repo; the agent adds the repos it needs itself ([D41](docs/design-decisions.md#d41), [D42](docs/design-decisions.md#d42)).

1. **Set up your Mac:** [docs/setup-guide.md](docs/setup-guide.md) (VPN, GitLab token, Keychain secrets, repos).
2. **Understand the flow:** [docs/architecture.md](docs/architecture.md).
3. **Check it works:** type `/flow-ping`, then `/flow-doctor` (Codex: `$flow-ping`, `$flow-doctor`). See [docs/commands.md](docs/commands.md).
4. **Why things are the way they are:** [docs/design-decisions.md](docs/design-decisions.md).

## What's in this folder

| Path | What it is | Committed? |
|---|---|---|
| `AGENTS.md` | Rules the AI follows in every session here, read by both Claude Code and Codex ([D45](docs/design-decisions.md#d45)) | ✅ |
| `.agents/skills/` | The agent's commands (skills), one source for Claude Code and Codex ([D8](docs/design-decisions.md#d8)) | ✅ |
| `config/repos/` | Shared repo registry: one file per repo with the facts that are the same for everyone ([D35](docs/design-decisions.md#d35)) | ✅ |
| `scripts/` | Helper scripts the commands run (VPN, Keychain, Git, …) | ✅ |
| `e2e/` | Playwright project for front-end end-to-end tests, kept outside the code repos ([D24](docs/design-decisions.md#d24)) | ✅ (dependencies and outputs ignored) |
| `runs/<CARD-KEY>/` | The agent's memory per Jira card: history, plan, state. Shared, so a teammate can pick up a paused card ([D36](docs/design-decisions.md#d36), [D38](docs/design-decisions.md#d38)) | ✅ |
| `local/` | **Your** personal settings, where the repos are cloned on **your** Mac, and **your user memory** (`local/memory/`: your preferences and corrections, which every command loads and applies; [D40](docs/design-decisions.md#d40)) | ❌ never (git-ignored) |
| `docs/` | Team documentation | ✅ |
| `build-memory/` | Working memory used while building the agent | ✅ |

## Golden rules

- **Never paste passwords, tokens or `.env` contents into the AI chat.** Secrets live in the macOS Keychain ([setup guide §5](docs/setup-guide.md#5-store-your-secrets-in-the-macos-keychain)).
- **Nothing secret is ever committed:** `.env` files, `local/` and keys are git-ignored.
