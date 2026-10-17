---
name: flow-status
description: Shows where a Jira card stands in closio-agent (phase, step, branch, what to type next), or every card in progress. Runs only when the user types /flow-status (Claude Code) or $flow-status (Codex).
disable-model-invocation: true
---

# flow-status

Shows where a card stands, from its run folder `runs/<CARD-KEY>/` (C1, rule A1, D61). It only reads.

## Usage

- `/flow-status`: every card in progress (on this Mac and pushed by teammates), one line each.
- `/flow-status SCRUM-567`: that card's state and the exact command to type next.
- Codex: `$flow-status …`

## Steps

1. **Rules and user memory (rules A7, A17), never skipped:** your memory entries for this command are loaded here automatically:

   !`bash scripts/memory.sh for pick-up all`

   Apply what's above: the general entries, and repo entries only for the repo(s) this command works on. Say in one line which entries you used (e.g. "Using your memory: M2, M3"); say nothing if none apply. Team rules always win (rule A8): if an entry conflicts with one, say so and follow the team rule. **If the block above still shows the command instead of its output** (e.g. in Codex, which doesn't run it by itself), run `bash scripts/memory.sh for pick-up all` yourself first, before anything else. Also re-read `AGENTS.md` and `docs/agent-rules.md` before going on (rule A17).
2. Run `bash scripts/run.sh check-folder`. If it fails, or the script isn't found, show the fix and stop.
3. Read what the user typed after the command (in Claude Code it may also appear as `ARGUMENTS: …`):
   - **Nothing:** run `bash scripts/run.sh list` and show its output exactly as printed.
   - **A card key** like `SCRUM-567`: run `bash scripts/run.sh state <KEY>` and show its output exactly as printed. Its last lines say where the state comes from and what to type next.
   - Anything else: show the usage above and stop.

## Rules
- Only read. Never change a run folder, a branch or the card in Jira here.
- Show only what the script prints; don't add or reword.
- Run the script exactly as written here (`bash scripts/…` from the closio-agent folder, no `cd`, nothing joined with `&&`). It's pre-approved in Claude Code and Codex (D57).
