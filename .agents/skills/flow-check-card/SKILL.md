---
name: flow-check-card
description: Checks a Jira card (by key, or a local markdown file) against the team's card template and shows what to fix. Runs only when the user types /flow-check-card (Claude Code) or $flow-check-card (Codex).
argument-hint: '<CARD-KEY> | local/cards/<file>.md'
disable-model-invocation: true
---

# flow-check-card

Checks one card against the Jira card template (`docs/jira-card-template.md`, F7, D58): the required sections, the AC format, the QA steps, placeholders, forbidden tables, secrets. ❌ = not ready (the agent's pick-up would stop here and wait), ⚠️ = worth a look. It only reads; it never changes the card in Jira.

## Usage

- `/flow-check-card SCRUM-567`: the card from Jira.
- `/flow-check-card local/cards/my-draft.md`: a card that isn't in Jira yet (any `.md` file with the card's text).
- Codex: `$flow-check-card …`

## Steps

1. **User memory (rule A7), never skipped:** your memory entries for this command are loaded here automatically:

   !`bash scripts/memory.sh for pick-up all`

   Apply what's above: the general entries, and repo entries only for the repo(s) this command works on. Say in one line which entries you used (e.g. "Using your memory: M2, M3"); say nothing if none apply. Team rules always win (rule A8): if an entry conflicts with one, say so and follow the team rule. **If the block above still shows the command instead of its output** (e.g. in Codex, which doesn't run it by itself), run `bash scripts/memory.sh for pick-up all` yourself first, before anything else.
2. Read what the user typed after the command (in Claude Code it may also appear as `ARGUMENTS: …`):
   - A card key like `SCRUM-567` (letters, a dash, a number): go to "From Jira".
   - A path ending in `.md`: go to "From a file".
   - Nothing or anything else: show the usage above and stop.

### From Jira

3. Read the card with your Jira (Atlassian) tools: key, summary, issue type, status and description. **Read only; never change anything in Jira.**
   - The Jira tools can take a while to load at the start of a session. If you can't find them, or the tool says the Atlassian connector is still connecting: run `bash scripts/wait-seconds.sh 10`, then try again. Try **up to 3 times** (about 30 seconds). If it still doesn't work: `❌ Jira isn't connected in <Claude Code or Codex>`, with the same fix lines as `flow-doctor` (Claude Code: `/mcp` → "claude.ai Atlassian MCP" → Reconnect; Codex: connect the Atlassian app to the ChatGPT account you use for Codex). Stop.
   - The card doesn't exist: `❌ SCRUM-… isn't in Jira (project SCRUM)` and `Fix: check the card key.` Stop.
4. Save the card's text to `local/cards/<CARD-KEY>.md` **with your file-writing tool** (Claude Code: Write; Codex: apply_patch). It creates the folder `local/cards/` itself: **don't run `mkdir` or any other shell command for this**, it would ask the user for permission. `local/` is private and never pushed. Write it as markdown, **exactly as Jira returns it**: don't reword, reorder, shorten or "fix" anything, so the check sees the real card. Use this layout:

   ```
   # SCRUM-567 — <summary>
   _Type: <issue type> · Status: <status> · Read from Jira on <today, YYYY-MM-DD>_

   <the description, as returned>
   ```

   If the description comes back in another format (e.g. a JSON document instead of markdown), convert only the format (headings → `## …`, bold → `**…**`, bullet lists → `*`, numbered lists → `1.`, tables → markdown tables), never the words.
5. Go to "Check".

### From a file

3. Use the file as given. Don't change it. If it doesn't exist, the script says so; stop after showing that.

### Check

6. Run `bash scripts/card-check.sh "<file>"` (the path in double quotes) and show its output exactly as printed.
7. Add one line about the card type (from Jira; for a file, only if its `_Type: …_` line says it):
   - Spike: `ℹ️ Spike: the agent doesn't pick up Spikes (D58).`
   - Bug: `ℹ️ Bug card: missing sections are fine for a Bug; you'll explain them when the card is picked up (D58).`
   - Subtask: `ℹ️ Subtask: picked up like a Story or Task.`
   - Story or Task: nothing.
8. End with one line:
   - any ❌: `Not ready: fix the ❌ lines above, then run /flow-check-card <key or file> again.` (For a Bug: `Not ready as a Story/Task would be; for a Bug, be ready to explain the missing parts at pick-up.`)
   - only ⚠️: `Ready, with <N> thing(s) worth a look.`
   - nothing: `Ready: the card follows the template.`

## Rules
- Never change the card in Jira. This command only reads and reports. Use only the Jira read tools (get an issue, search issues); in Claude Code they're pre-approved in `.claude/settings.json`, like the script and the card file (D57), so nothing here should ask the user for permission.
- Never put a secret in the saved file or in the chat. If the script says a line looks like a secret, tell the user to remove it from the card and change that secret; don't repeat the line.
- Don't add your own judgement of the content here (alignment with the code, scope, the WS1 rules): that's done when the card is picked up and planned (Phase 2, rule A16). Only report what the script and the type line say.
- Run the script exactly as written here (`bash scripts/…` from the closio-agent folder, no `cd`, nothing joined with `&&`). It's pre-approved in Claude Code and Codex, so it runs without a prompt (D57).
