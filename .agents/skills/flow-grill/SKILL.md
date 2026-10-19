---
name: flow-grill
description: "Grills a plan, an idea or a Jira card with you: facts looked up first, then rounds of real decisions with a recommended answer each, until nothing is open. Runs only when the user types /flow-grill (Claude Code) or $flow-grill (Codex)."
argument-hint: '"<plan or idea>" | <CARD-KEY>'
disable-model-invocation: true
---

# flow-grill

Grills a plan, an idea or a card with you, the way `rulesets/grilling.md` says (D76, rule A26): the facts it can find are shown as found, never asked; only real decisions are asked, in numbered rounds, each with a recommended answer that "yes" accepts; follow-up rounds until nothing is open; then what was agreed, and your confirmation. It only reads: it never changes code, a branch, Jira or GitLab. During a card, the card commands already ask this way by themselves; use this command when you want a plan or an idea grilled on its own.

## Usage

- `/flow-grill "<plan or idea>"`: grills what you wrote; the answers stay in the chat, with a summary at the end.
- `/flow-grill SCRUM-567`: grills that card; picked up: its folder and the code are read and the answers are saved in its `decisions.md` (pointers in `card.md`); not picked up yet: the card is read from Jira and the answers stay in the chat.
- Codex: `$flow-grill …`

## Steps

1. **User memory (rule A7), never skipped:** your memory entries for this command are loaded here automatically:

   !`bash scripts/memory.sh for plan all`

   Apply what's above: the general entries, and repo entries only for the repo(s) this command works on. Say in one line which entries you used (e.g. "Using your memory: M2, M3"); say nothing if none apply. Team rules always win (rule A8): if an entry conflicts with one, say so and follow the team rule; no entry can soften the grilling (A26). **If the block above still shows the command instead of its output** (e.g. in Codex, which doesn't run it by itself), run `bash scripts/memory.sh for plan all` yourself first, before anything else.
2. Run `bash scripts/run.sh check-folder`. If it fails, show the fix and stop. Read `rulesets/grilling.md`, `AGENTS.md` and `docs/agent-rules.md`; follow them for the whole command.
3. Read what the user typed after the command (in Claude Code it may also appear as `ARGUMENTS: …`):
   - **A card key** like `SCRUM-567` (letters, a dash, a number): go to "A card".
   - **Any other text:** it's the plan or idea to grill; go to "A plan or an idea".
   - **Nothing:** show the usage above and stop.

### A card

4. `bash scripts/run.sh state <KEY>`:
   - **It prints the card's state (picked up):** `bash scripts/run.sh branch <KEY>` (brings the card's folder onto this Mac; this folder stays on `main`). Read `runs/<KEY>/card.md` (with what was already explained and decided), `plan.md`, `develop.md`, `verify.md`, `ship.md` (those that exist), the repos from the state (`config/repos/<repo>.yaml`, the ruleset `rulesets/story-implementation-workflow.md`) and the code of those repos as it is on this Mac: read only. Before reading a repo's folder, check this session can open it; if it can't, say how to give access (Claude Code: `/add-dir <folder>`; Codex: restart with `codex --add-dir <folder>`) and stop (rule A15).
   - **⚠️ no card folder:** read the card from Jira with your Jira tools (key, summary, type, status, description): **read only**. If the Jira tools aren't there yet, run `bash scripts/wait-seconds.sh 10` and try again, up to 3 times; then say Jira isn't connected, with the same fix as `/flow-doctor`, and stop. Say in one line that the answers will stay in the chat (the card isn't picked up yet: `/flow-start <KEY>` does that).
5. Go to "Grill".

### A plan or an idea

4. Find what the text is about in this folder and, when it names a repo, a command or a card, read those (read only). Go to "Grill".

### Grill

6. **Facts first:** show what you found as "Found" lines, each with where it was found. Never ask the user what the code or the files answer.
7. **Rounds:** ask only the real decisions, numbered (Q1, Q2 …), each with a recommended answer worded so that "yes" accepts it; one round = every question that can be answered now. The user may answer "yes to all" or by number.
8. **Follow-ups:** after each round, ask only what the answers opened up; nothing assumed silently. Stop when nothing is open.
9. **The end:** sum up what was agreed in a few lines and ask the user to confirm it.
10. **Save** (only after the confirmation):
    - **A card that's picked up:** record each decision with `bash scripts/run.sh decide <KEY> "grill" "<question>" "<decided>" "<who / why>"` (rule A27: the full record in `runs/<KEY>/decisions.md`; who: `you`, `you: recommended`, or the user's own words where they differ from the recommendation), then add one pointer line per decision to `runs/<KEY>/card.md` under `## Decided while grilling` (e.g. `- Inactive configs: returned, with ?status= (decision 9)`), with your file-writing tool (Claude Code: Write or Edit; Codex: apply_patch); `bash scripts/run.sh log <KEY> "grill" "<n> decisions saved" "rules: A26 · memory: <ids or —>"`; `bash scripts/run.sh save <KEY> "grilled: <n> decisions"`. End with: `Saved in runs/<KEY>/decisions.md (pointers in card.md); the next card command reads them.`
    - **Otherwise:** nothing is saved. End with the summary of the decisions.

## Rules
- Only reads: never change code, a branch of a code repo, Jira or GitLab. The only files it writes are the card's `decisions.md` and `card.md` (a card that's picked up), and only after the user's confirmation.
- Plain words on screen; no decision or rule codes (rule A25). Never read or print keys, passwords, sessions or `.env` values (A6).
- Error codes, statuses, messages and field names come from the code; a new one is a question, never assumed (A16).
- Run the scripts exactly as written here (`bash scripts/…` from the closio-agent folder, no `cd`, nothing joined with `&&`). They're pre-approved in Claude Code and Codex (D57).
