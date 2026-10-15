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
