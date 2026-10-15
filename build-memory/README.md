# Build Memory — Index

Memory for **building** `closio-agent` (JIRA card → … → MR review → deployment doc).

- This is **not** the team documentation; that lives in `docs/` (see D5).
- This is **not** the agent's own memory while it runs; that lives in `runs/<CARD-KEY>/` in this same project folder (D36).
- This is **not** the user memory (each user's private preferences across runs, `local/memory/`, git-ignored; D40, rules A7/A8).

## Files

| File | What it holds | When to read |
|------|---------------|--------------|
| `README.md` | This index | **Every step** |
| `rules.md` | Strict working rules for building (R1–R16), followed at every step; points to the agent's own rules (G1–G4, A1–A14) in `project-context.md` (team copy: `docs/agent-rules.md`) | **Every step** |
| `project-context.md` | Goal, users, scope, pipeline stages, docs to maintain | When the step touches scope, stages or docs |
| `environment.md` | Tools, connectors and hosts that have been checked | When the step uses a tool, connector or external system |
| `decisions.md` | One-line index of decisions, each linking to its full record | Before proposing anything that might overlap with an earlier decision |
| `open-questions.md` | Unresolved questions; answered ones become decisions and are listed briefly under "Resolved" | When planning a step or when asking the user something |
| `history.md` | Step log, one row per step | When the step needs past context; always append after a step |
| `full-chat-transcript.md` | The entire conversation (2026-10-08 → 2026-10-15), from the Claude Code and Codex session files. **Part 1:** the build conversation (the first five sessions on the first Claude account, then session `a60e8ec2` on the second). **Part 2:** the 12 Claude Code side sessions (sign-ins, command tests). **Part 3:** the 9 Codex side sessions (command tests). **Part 4** (appended 2026-10-15, parts 1–3 unchanged): 2 more Claude Code side sessions (4a), 1 more Codex side session (4b), and last the build conversation after 2026-10-14 11:48 UTC up to the latest message (4c), so the file always ends with the latest chat. GitLab tokens and the WS1 login user ID redacted; auto-injected instructions left out; long tool output truncated; times in UTC | When exact past wording or context is needed (large file, ~1.9 MB) |
