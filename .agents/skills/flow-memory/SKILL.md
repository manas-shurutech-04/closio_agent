---
name: flow-memory
description: Shows and manages your user memory, the private preferences and corrections every flow command follows (list, add, edit, remove). Runs only when the user types /flow-memory (Claude Code) or $flow-memory (Codex).
disable-model-invocation: true
---

# flow-memory

Your user memory (F6b, D40, D56): short entries the agent follows in every flow command (rule A7). It's private: it lives in `local/memory/` on this Mac and is never pushed. Team rules always win over it (rule A8). It starts empty and is created with the first entry; having none is normal.

## Usage

- `/flow-memory`: list all your entries.
- `/flow-memory add <text>`: add one that applies everywhere.
- `/flow-memory add <repo> <text>`: add one for one repo only (e.g. `nodejs-ws2closio`).
- `/flow-memory edit <id> <new text>`: change an entry's text (e.g. `M3`).
- `/flow-memory edit <id> phases <phases>`: change where it applies.
- `/flow-memory remove <id>`: remove an entry.
- `/flow-memory clear`: remove all your entries (it shows them and asks first).
- `/flow-memory clear <repo>`: remove only that repo's entries.
- Codex: `$flow-memory …`

## Steps

1. **User memory (rule A7), never skipped:** your memory entries for this command are loaded here automatically:

   !`bash scripts/memory.sh for setup all`

   Apply what's above: the general entries, and repo entries only for the repo(s) this command works on. Say in one line which entries you used (e.g. "Using your memory: M2, M3"); say nothing if none apply. Team rules always win (rule A8): if an entry conflicts with one, say so and follow the team rule. **If the block above still shows the command instead of its output** (e.g. in Codex, which doesn't run it by itself), run `bash scripts/memory.sh for setup all` yourself first, before anything else.
2. Read what the user typed after the command (in Claude Code it may also appear as `ARGUMENTS: …`):
   - **Nothing or `list`:** run `bash scripts/memory.sh list`, show it, and stop.
   - **`add …`:** go to "Add an entry".
   - **`edit <id> phases <phases>`:** run `bash scripts/memory.sh set-phases <id> <phases>`, show the output, and stop.
   - **`edit <id> <text>`:** check the new text like in "Add an entry" (steps 3–4), then run `bash scripts/memory.sh edit <id> '<text>'`, show the output, and stop.
   - **`remove <id>`:** run `bash scripts/memory.sh remove <id>`, show the output, and stop.
   - **`clear` or `clear <repo>`:** go to "Clear the memory".
   - Anything else: show the usage above and stop.

### Add an entry

1. **Where it applies:** if the first word after `add` is a registered repo (a file `config/repos/<word>.yaml` exists), the entry is for that repo only; otherwise it applies everywhere (`general`).
2. **Ask once, in one short message**, showing your suggestion so the user can just confirm:
   - the **phases** it applies to: `all`, or some of `setup`, `pick-up`, `plan`, `develop`, `review`, `ac-check`, `testing`, `ship`, `mr`, `after-merge`. Suggest the ones that fit the text (or `all`);
   - the **card** it came from, if any (e.g. `SCRUM-519`), or none.
3. **Team rules first (rule A8):** compare the entry with the team rules: `AGENTS.md`, `docs/agent-rules.md` (G1–G4, A1–A15) and the repo's file in `config/repos/`. If it goes against one, tell the user which rule, and that the entry would never override it. Save it only if they still want it.
4. **No secrets:** if the text holds a password, token, key or `.env` value, don't save it, don't repeat it, and tell the user to change that secret. The script refuses anything that looks like a secret too.
5. Run `bash scripts/memory.sh add <general|repo> <phases> <card or -> '<text>'`. Put the text in single quotes; write a `'` inside it as `'\''`. Show the output.

### Clear the memory

1. Run `bash scripts/memory.sh clear-preview all` (or `… clear-preview <repo>`) and show its output. If there's nothing to clear, stop.
2. Ask the user exactly: "Remove these N entries? This can't be undone." (N from the output.)
3. **Only after a clear yes**, run `bash scripts/memory.sh clear all confirmed` (or `… clear <repo> confirmed`) and show the output. On anything else, say nothing was removed and stop.

## Rules
- Only change memory through `bash scripts/memory.sh` (it keeps the format and refuses secrets). The user may also edit the files by hand; `list` shows any line that isn't in the format.
- Never read, print or store secrets, `.env` values or Keychain values.
- Run the script exactly as written here (`bash scripts/…` from the closio-agent folder, no `cd`, nothing joined with `&&`). It's pre-approved in Claude Code, so it runs without a prompt (D49).
