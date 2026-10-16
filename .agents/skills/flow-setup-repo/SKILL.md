---
name: flow-setup-repo
description: Gets a registered repo ready to work on, on your Mac (Node version, packages, local Redis/RabbitMQ, .env check, tests, folder access). Runs only when the user types /flow-setup-repo (Claude Code) or $flow-setup-repo (Codex).
disable-model-invocation: true
---

# flow-setup-repo

Gets a registered repo ready to work on, on this Mac (F6, D54).

## Usage

- `/flow-setup-repo`: each repo's setup state on this Mac.
- `/flow-setup-repo <repo-name>`: set up one repo.
- `/flow-setup-repo all`: set up every repo cloned on this Mac, one after another.
- `/flow-setup-repo <repo-name|all> install`: the same, but always reinstall the packages.
- `/flow-setup-repo <repo-name|all> services`: the same, but choose Homebrew or Docker again for Redis and RabbitMQ.
- Codex: `$flow-setup-repo …` (approve running it outside the sandbox).

It works only on clones the user made (cloning is manual, D53). It never switches branches, pulls, stashes or changes tracked files: the card phases do that. It needs no VPN.

## Steps

1. **User memory (rule A7), never skipped:** your memory entries for this command are loaded here automatically:

   !`bash scripts/memory.sh for setup all`

   Apply what's above: the general entries, and repo entries only for the repo(s) this command works on. Say in one line which entries you used (e.g. "Using your memory: M2, M3"); say nothing if none apply. Team rules always win (rule A8): if an entry conflicts with one, say so and follow the team rule. **If the block above still shows the command instead of its output** (e.g. in Codex, which doesn't run it by itself), run `bash scripts/memory.sh for setup all` yourself first, before anything else.
2. **Start folder (strict rule, D42):** run `bash scripts/setup-repo.sh check-folder`. If it fails, or the script isn't found, show the fix and **stop**.
3. Read what the user typed after the command (in Claude Code it may also appear as `ARGUMENTS: …`):
   - **Nothing:** run `bash scripts/setup-repo.sh list`, show it, and ask which repo to set up (or `all`). Stop until they answer.
   - **`<repo>`, `all`, optionally followed by `install` or `services`:** go on.
4. Tell the user in a few short lines what will happen:
   - it can take a while (installing packages, then the tests, up to 15 minutes each per repo);
   - macOS dialogs may appear: to choose Homebrew or Docker for Redis or RabbitMQ when both are there, or to start one when none is there;
   - Docker Desktop may start for a moment so Docker copies can be checked (it's quit again if it isn't used);
   - if the repo's `.env` misses variables that `.env.example` has, or doesn't point to the local Redis or RabbitMQ, the file opens in their text editor with the lines to add or set. **They change it themselves; you never read or change it.**
5. Run `bash scripts/setup-repo.sh run <repo|all> [install|services]`.
   - **Claude Code:** run it **in the background** (it can take longer than the 10-minute limit of one command) and wait for it to finish. Don't run anything else in the repo meanwhile.
   - **Codex:** ask the user to approve running it outside the sandbox: it needs the network (packages), Homebrew, Docker and macOS dialogs.
6. Show the script's output as printed. Every ⚠️ and ❌ already includes the steps to fix it (rule A11).
7. **Folder access (rule A15, D55):** for each repo that was set up, check that this session can use its folder: it's one of this session's folders, or reading a file in it (e.g. its `package.json`) works. If it can't, **stop and ask the user to give access**, with the exact way:
   - Claude Code: type `/add-dir <repo folder>`, or start a new session (the folder is saved in `.claude/settings.local.json` now);
   - Codex: start it again from the closio-agent folder with the `codex --add-dir …` command at the end of the output, or approve Codex's request for that folder.
   Wait until they say it's done, check again, then go on.
8. Finish:
   - If the output has `.env` help steps, remind the user to change the file as shown, then run the command again.
   - If they use Codex, point them to the Codex start command at the end of the output.
   - Tell them to run `/flow-doctor` (Codex: `$flow-doctor`) for the full check.

## Rules
- **Never read, print or change a `.env` file** (rule A6). The script reads it itself and only says where it points.
- **Never clone a repo** (D53). If a repo isn't on the Mac, show the script's `git clone` fix.
- **Don't switch branches, pull, stash or commit** here. That's for the card phases (Phase 1 and Phase 7).
- Each repo runs on its own Node version (rule A13): the script switches by itself; don't run anything in a repo yourself.
- Run the script exactly as written here (`bash scripts/…` from the closio-agent folder, no `cd`, nothing joined with `&&`). In Claude Code all of them are pre-approved, the setup run included (D49, D54; user, 2026-10-16), so it runs without an approval prompt.
- Don't fix anything yourself. If something fails, show the fix the script gives.
