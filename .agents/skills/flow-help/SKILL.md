---
name: flow-help
description: Lists every flow command with what it does and how it's typed, or shows one command in full. Runs only when the user types /flow-help (Claude Code) or $flow-help (Codex).
disable-model-invocation: true
---

# flow-help

Shows every flow command, what it does and how it's typed. The text is read from the commands' own files, so a new command can't be missing (F8, D60, rule R17). It only reads.

## Usage

- `/flow-help`: every flow command, grouped, with what it does and how it's typed.
- `/flow-help <command>`: one command in full, e.g. `/flow-help flow-memory` (the `flow-` part can be left out: `/flow-help memory`).
- Codex: `$flow-help …`

## Steps

1. **User memory (rule A7), never skipped:** your memory entries for this command are loaded here automatically:

   !`bash scripts/memory.sh for setup all`

   Apply what's above: the general entries, and repo entries only for the repo(s) this command works on. Say in one line which entries you used (e.g. "Using your memory: M2, M3"); say nothing if none apply. Team rules always win (rule A8): if an entry conflicts with one, say so and follow the team rule. **If the block above still shows the command instead of its output** (e.g. in Codex, which doesn't run it by itself), run `bash scripts/memory.sh for setup all` yourself first, before anything else.
2. Read what the user typed after the command (in Claude Code it may also appear as `ARGUMENTS: …`):
   - **Nothing:** run `bash scripts/help.sh list` and show its output exactly as printed.
   - **One word:** run `bash scripts/help.sh show <word>` and show its output exactly as printed. If the script says there's no such command, show that; don't guess.
   - Anything else: show the usage above and stop.
3. If `scripts/help.sh` isn't found, this session wasn't started in the closio-agent folder. Tell the user: "Quit, open a terminal in the closio-agent folder, run `nvm use v22`, then start Claude Code or Codex again." Stop there.

## Rules
- Show only what the script prints; don't add, shorten or reword it. The script reads each command's `## Usage` block, so help and behaviour can't drift apart.
- Run the script exactly as written here (`bash scripts/…` from the closio-agent folder, no `cd`, nothing joined with `&&`). It's pre-approved in Claude Code and Codex, so it runs without a prompt (D57).
- Never read or print secrets, `.env` values or Keychain values.
