---
name: flow-configure-repo
description: Registers a repo with closio-agent (shared facts in config/repos/), or sets it up on your Mac (local path and dev keys). The only way to add a repo. Runs only when the user types /flow-configure-repo (Claude Code) or $flow-configure-repo (Codex).
disable-model-invocation: true
---

# flow-configure-repo

The only way to add a repo to closio-agent (D35). Usage:
- `/flow-configure-repo`: list the registered repos and their status on this Mac.
- `/flow-configure-repo <repo-name>`: set up a registered repo on this Mac (local path, dev keys).
- `/flow-configure-repo <full path of a local clone>`: register a new repo for the whole team.
- `/flow-configure-repo <repo-name> key <name>`: add or replace one dev key (e.g. `db-password`, or an extra key).
- `/flow-configure-repo <repo-name> path <full path | not-cloned>`: change where the repo is on this Mac (e.g. after moving the clone).

In Codex: the key steps open macOS dialogs and write to the Keychain. Ask the user to approve running those commands outside the sandbox.

## Steps

1. **User memory (rule A7):** if `local/memory/general.md` exists, read it and apply any entry meant for this command. Team rules always win (rule A8). If it doesn't exist, carry on; that's normal.
2. **Start folder (strict rule, D42):** tell the user in one line: "Always start Claude Code or Codex in the closio-agent folder, after `nvm use v22`." Then run `bash scripts/configure-repo.sh check-folder`. If it fails, or the script isn't found, show the fix and **stop**.
3. Read what the user typed after the command (in Claude Code it may also appear as `ARGUMENTS: …`):
   - **Nothing:** run `bash scripts/configure-repo.sh list`, show it, and ask which repo to set up, or the path of a new repo to register. Stop until they answer.
   - **A repo name with a file `config/repos/<name>.yaml`:** go to "Set up on this Mac".
   - **A path:** go to "Register a new repo".
   - **`<repo> key <name>`:** run `bash scripts/configure-repo.sh key <repo> <name>`, show the output, and stop.
   - **`<repo> path <path or not-cloned>`:** run `bash scripts/configure-repo.sh set-path <repo> "<path>"` (or `not-cloned`), show the output, and stop. A clone of a different GitLab project is refused and the old path is kept.

### Register a new repo (once, for the whole team)

1. If the user gave a GitLab address instead of a path, ask them to clone it themselves first (cloning is manual, D53; on the VPN: `/flow-vpn connect`, then `git clone <address> <workspace folder>/<repo>`) and give the path. Then run `bash scripts/configure-repo.sh detect "<path>"`. Its lines are **suggestions** read from the repo. It never reads what's inside `.env` files, and neither do you (rule A6).
2. If `config/repos/<name>.yaml` already exists, the repo is registered: tell the user and go to "Set up on this Mac" instead.
3. Ask the user for everything the suggestions can't know, and show the suggestion next to each question so they can just confirm or change it. Ask in **one message**, as a short numbered list:
   - **role** (one line, e.g. "WS2 service: pricing APIs")
   - **base branch**: show the remote branches the script listed; it can differ per repo
   - **port** and **health URL** for running it locally. The port is in the repo's `.env`, which you don't read: record it as `from the repo's .env (PORT)` unless the user gives a number. **Every repo must have a health URL** (user, 2026-10-14): suggest the one the script found (it reads the repo's docker-compose health check and the routes, e.g. `/api/v1/health-checker`); for a web app with none, suggest `/` (the dev server's start page)
   - **run and check commands**: confirm the suggested `dev_command`, `start_command`, `check_commands`. For a repo that isn't Node (`language: go` or `other`), there are fewer suggestions: ask for the install, run, check and test commands
   - **Node version** (Node repos): confirm the suggested `node_version` (from the Dockerfile or `.nvmrc`). Everything in this repo will run on that version (rule A13, D52); if nvm doesn't have it, the check tells the user to run `nvm install <version>`
   - **migrations and seeders**: confirm the suggested folders, name pattern and commands. Say that **the existing pattern is kept** (no new pattern); ask only whether this repo differs
   - **queues** and **local services** (Redis, RabbitMQ, BullMQ): confirm
   - **calls**: which repos it calls (WS1, WS2 services, frontend); confirm the guess
   - **MR target branch** (default: the base branch), and **optional default labels and reviewers** (GitLab usernames, or "none"). Say they're only defaults: the user confirms or changes them each time an MR is created
   - **dev keys**: confirm the list. Optional dev database user and password, plus any extra named key the user wants (e.g. a partner API key). For the dev database, also ask the non-secret host, port, database name and schema, or "skip"
4. Write the full file `config/repos/<name>.yaml` in the same "key: value" format as the suggestions: **one value per line, lists comma-separated, no secrets**. Start it with the line `# Shared repo facts for <name> (F5, D35). Committed: no secrets here.` Add `registered_on: <today>`.
5. **Show the file to the user and ask them to confirm.** Change it as they say. Don't go on until they say it's right.
6. Run `bash scripts/configure-repo.sh validate <name>`. Fix any ❌ with the user.
7. Tell the user the new file should be committed so the team gets it (they decide when).
8. Then do "Set up on this Mac" for the same repo; the local path is the path they gave.

### Set up on this Mac

1. Ask: "Where is <repo> on your Mac? Give the full path of your clone, or say 'not cloned yet'." If you already know the path (from registering), use it without asking.
2. Run `bash scripts/configure-repo.sh set-path <repo> "<path>"`, or `bash scripts/configure-repo.sh set-path <repo> not-cloned`.
3. If the repo needs dev keys: first tell the user in the chat which keys will be asked, that optional ones can be skipped, and that for each one a macOS message appears first ("Copy it now, then click Continue"), then a hidden box to paste it into. **Never ask for a key in the chat, and never accept one there.** If the user pastes a secret in the chat anyway, don't repeat it; tell them to change it. Then run `bash scripts/configure-repo.sh keys <repo>` once for all missing keys (allow up to 10 minutes; Claude Code: timeout 600000 ms).
4. Finish: run `bash scripts/configure-repo.sh show <repo>` and show it. Tell the user to run `/flow-doctor` (Codex: `$flow-doctor`) for the full check.

## Rules
- **Branch names** are the same for every repo and strict (rule A12, D50): `SCRUM-<number>/<short-description>`, at most 5 words. They are not a per-repo setting.
- **Each repo's own Node version (rule A13, D52):** record `node_version` from the repo's Dockerfile; later steps run anything in the repo only after `nvm use <that version>` (and `nvm install <version>` if it's missing).
- **Cloning is manual (D53):** never clone a repo yourself. If the user has no clone yet, tell them the `git clone` command (from the repo's GitLab address) and to run `/flow-configure-repo <repo> path <folder>` afterwards.
- Detected values are only suggestions: always let the user confirm or correct them.
- Every ❌ comes with the steps to fix it (rule A11). Show the script's fix lines as they are.
- Run the scripts exactly as written here (`bash scripts/…` from the closio-agent folder, no `cd`, nothing joined with `&&`), so Claude Code recognises them as pre-approved (D49).
- Never read or print secret values, `.env` contents or Keychain values.
