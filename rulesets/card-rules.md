# Card rules: sent with every prompt about a card

> **closio-agent's card rules** ([D86](../docs/design-decisions.md#d86), rule A29). The card-rules hook (`scripts/card-rules-hook.sh`) adds this file to every prompt about a card, in Claude Code and Codex: a card command (`/flow-start`, `/flow-develop`, `/flow-verify`, `/flow-ac-check`, `/flow-push`, `/flow-review`, `/flow-finish`, `/flow-qa`, and `/flow-grill` with a card key), a prompt that names a card key, and every later prompt in that session.
>
> - **Who changes it:** the closio-agent builders, in this folder; a new rule is added here, numbered, in plain words. No command adds or changes it.
> - **The full rules stay in `AGENTS.md` and `docs/agent-rules.md`**; these are the ones to apply at every prompt. On any doubt, those win. A user's memory can't switch one off.

## 1. Every decision is recorded the moment it's made

- When a decision on the card is confirmed (an answer to a question, a yes or a no at a safety stop, a memory entry that answered for the user, a change the user asked for in the middle of a command), record it right then, before going on: `bash scripts/run.sh decide <KEY> "<step>" "<question>" "<decided>" "<who / why>"` (who: `you`, `you: recommended`, `memory M2`). It goes to the card's own `runs/<KEY>/decisions.md` (`AGENTS.md` rule 23).
- Before you end your reply: if a decision was confirmed in this turn and isn't in `runs/<KEY>/decisions.md` yet, write it first.
- The card's other files (`card.md`, `plan.md`, `develop.md`, `verify.md`, `ship.md`, `review.md`, `qa.md`) only point to it in one line, e.g. `- Error code for a bad status: VALIDATION_ERROR (decision 3)`.
- A card that isn't picked up yet has no folder: say what was decided in the chat; it's recorded when the card is picked up.

## 2. Use the ways that don't ask, and never a `.env` file

- Read a repo's code with your tool's own read and search tools. Its git history and changes: `bash scripts/repo-git.sh <repo> log | diff | status | show …` (read-only, never shows a `.env` file). Its tests, checks and servers: `bash scripts/repo-run.sh <repo> …`. These are pre-approved, so they don't stop for a prompt ([D90](../docs/design-decisions.md#d90)).
- Not `cat`, `grep` or `git -C …` on a repo folder through the shell: they ask each time, and `cat` or `grep` could print a `.env` file. Never read or print a `.env` file's values (`AGENTS.md` rule 3).

## 3. Never ask again what the user already answered

- Before you ask the user anything about the card, read what's already decided: `card.md` (its `## API request and response`, `## Explained at pick-up`, `## Decided before planning`) and `runs/<KEY>/decisions.md`. An answer there is used for the rest of the card, in every command; it isn't asked again ([D94](../docs/design-decisions.md#d94); the user, 2026-10-24: "once the structure is provided by the user, you can use it for further process rather than asking again and again").
- A response the card marks `unchanged` (it stays as it is today) isn't asked for: `/flow-verify` compares it with the real response before the change (`bash scripts/response-shape.sh compare …`).
- A question whose answer you'd fill in yourself ("none is fine") isn't a question: write what you found and say it in one line; the user corrects it if needed.
