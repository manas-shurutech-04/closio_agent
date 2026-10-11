# Build Memory — Index

Memory for **building** `closio-agent` (JIRA card → … → MR review → deployment doc).

- This is **not** the team documentation; that lives in `docs/` (see D5).
- This is **not** the agent's own memory while it runs; that lives in `runs/<CARD-KEY>/` in this same project folder (D36).
- This is **not** the user memory (each user's private preferences across runs, `local/memory/`, git-ignored; D40, rules A7/A8).

## Files

| File | What it holds | When to read |
|------|---------------|--------------|
| `README.md` | This index | **Every step** |
| `rules.md` | Strict working rules | **Every step** |
| `project-context.md` | Goal, users, scope, pipeline stages, docs to maintain | When the step touches scope, stages or docs |
| `environment.md` | Tools, connectors and hosts that have been checked | When the step uses a tool, connector or external system |
| `decisions.md` | One-line index of decisions, each linking to its full record | Before proposing anything that might overlap with an earlier decision |
| `open-questions.md` | Unresolved questions; answered ones become decisions and are listed briefly under "Resolved" | When planning a step or when asking the user something |
| `history.md` | Step log, one row per step | When the step needs past context; always append after a step |
| `full-chat-transcript.md` | The entire build conversation (2026-10-09 → 2026-10-10), exported from the Claude Code sessions; GitLab tokens redacted; long tool output truncated | When exact past wording or context is needed (large file) |
