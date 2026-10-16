# Rules for AI tools in closio-agent

Claude Code and Codex both read this file at the start of every session in this folder (D45).
The full list of agent rules, with the reasons, is in `docs/agent-rules.md`.

1. Flow commands run only when the user types them (`/flow-…` or `$flow-…`).
   Don't do a command's steps or run its scripts on your own.
   If the user asks for something a command does (e.g. "check my setup"),
   tell them which command to type (e.g. `/flow-doctor` or `$flow-doctor`) and stop.
   Only exception: the user clearly asks you to run or test a specific script.
2. Sessions start in this folder, after `nvm use v22`.
3. Never read or print secrets, `.env` values or Keychain values.
4. When anything fails (a check, a step, a command), always tell the user the exact steps to fix it (rule A11).
5. Branch names, in every repo, strictly follow `SCRUM-<number>/<short-description>`: the card key as in Jira, then a description of
   lowercase words joined by `-` (only a-z and 0-9), at most 5 words, e.g. `SCRUM-519/add-filter-status`. Use the same name in every
   repo of a card. Make and check names with `bash scripts/branch-name.sh` (rule A12, D50).
6. Every code repo runs on the Node version it is built for: `node_version` in `config/repos/<repo>.yaml` (from its Dockerfile).
   Before running anything in a repo (install, run, test, lint, migrate, seed), switch to that version in the same shell command:
   `source "${NVM_DIR:-$HOME/.nvm}/nvm.sh" && nvm use <version>`. If nvm doesn't have it yet, run `nvm install <version>` first
   (rule A13, D52). closio-agent itself and Claude Code / Codex stay on Node 22 (rule A9).
7. Cloning a repo is always done by the user, by hand. Never clone a repo yourself (D53).
8. Before working in a code repo, check that this session can use its folder. If it can't, stop and ask the user to give access,
   with the exact way (Claude Code: `/add-dir <folder>` or a new session; Codex: restart with `codex --add-dir <folder>` or approve
   its request). Go on only after the user has given access (rule A15, D55).
9. User memory (rules A7, A8; D40, D56): every flow command starts with `bash scripts/memory.sh for setup all` (Claude Code runs it by
   itself when the command loads; in Codex, run it yourself first) and applies the entries that fit. Team rules always win over memory.
   When the user corrects you during a flow command, offer once to save it to their memory; save it only after a clear yes,
   with `bash scripts/memory.sh add …` (the same steps as `/flow-memory add`).
10. Error codes, HTTP statuses and messages always come from the code (rule A16, D59). Before developing a card, read the ones that
    already exist in every repo the card touches (constants, utils, controllers, middlewares, WS1 locale files). If the card lists
    error codes, check each one against the code and point out every difference; use the code's exact errors and messages for the
    right conditions. Never invent a new error code, status, message, field or constant; a truly new one needs the user's approval.
11. Adding or changing a flow command (rule R17, D60): in the same step, give it a `## Usage` block in its `SKILL.md`, a section in
    `docs/commands.md`, a section and an index row in `docs/user-guide.md`, and update the Claude artifact of the guide from
    `docs/user-guide.md` (its link is at the top of the guide), then set the guide's "mirrored" line (the date and every command).
    Only Claude Code can reach the artifact: a change made in Codex is finished in Claude Code. `bash scripts/help.sh check`
    (also run by flow-doctor) fails until all of this is done.
