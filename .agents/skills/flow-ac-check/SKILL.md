---
name: flow-ac-check
description: Adds or changes the test cases of one acceptance criterion of a card (an API check or a Playwright test), runs that AC's cases once and saves them in the card's folder. Runs only when the user types /flow-ac-check (Claude Code) or $flow-ac-check (Codex).
argument-hint: '<CARD-KEY> <AC number> ["what to change"]'
disable-model-invocation: true
---

# flow-ac-check

Adds, changes or rewrites the test cases of **one AC** of a card (C4; D67). `flow-verify` writes every AC's cases by default; this command is for the user who wants a new case, a changed case, or a case written again. It runs only that AC's cases once and saves them in `runs/<CARD-KEY>/` (`api-checks/ac-<n>.json` for backend cards, `e2e/ac-<n>.spec.ts` for web cards). The next `/flow-verify` runs them with the rest. It doesn't change the card's phase or Jira.

## Usage

- `/flow-ac-check SCRUM-567 3`: write AC 3's test cases again from the card and the code.
- `/flow-ac-check SCRUM-567 3 "add a case for ?status=foo"`: add or change AC 3's cases as asked.
- Codex: `$flow-ac-check SCRUM-567 3 "…"` (approve the scripts outside the sandbox).

## Before every step: rules and user memory (rules A17, A7, A8; D62, D91)

When the command starts: read `AGENTS.md` and `docs/agent-rules.md` in full, then `bash scripts/run.sh rules <KEY> read` (rule A17, D91). Before **each** step below: apply the rules it touches and the **user-created memory** entries (the first step's are printed below; team rules win, A8). After each step, **one call**: `bash scripts/run.sh step <KEY> "ac-check <n>" "<what happened>" "rules: … · memory: …" --memory ac-check <repos>`: the history line, a check of the rules files (⚠️ changed or summarized: say so in one line, read them again, `rules <KEY> read`, go on) and your memory for the next step. Skip nothing.

**Ask and decide the grilling way (rule A26, D76; `rulesets/grilling.md`):** every question this command asks you, and every prompt you give during it that changes the AC's cases, test data or code: look up the facts first and show them as "Found" lines (never ask what the code or the files answer); ask only the real decisions, in numbered rounds, each with a recommended answer that "yes" accepts; follow-up rounds until nothing is open; sum up what was agreed and wait for the confirmation before changing anything; record each decision with `bash scripts/run.sh decide <KEY> "ac-check <n>" "<question>" "<decided>" "<who / why>"` (rule A27, D77: every answer, every approval or refusal of test data and write calls, every memory answer; the full record in `runs/<KEY>/decisions.md`) and point to it in one line in `verify.md`, in this run's section (`### Decided while grilling`, e.g. `- Mock the partners API: yes (decision 7)`). Short answers, approvals and the user's questions go straight through. Test data and calls that write stay their own plain yes/no.

The first memory step runs here automatically:

!`bash scripts/memory.sh for ac-check all`

**If the block above still shows the command instead of its output** (e.g. in Codex), run `bash scripts/memory.sh for ac-check all` yourself first.

## Steps

**1. Start.** `bash scripts/run.sh check-folder` (on ❌ show the fix and stop). Read the card key, the AC number and the optional request after the command (Claude Code may also show them as `ARGUMENTS: …`); no key or no number: show the usage and stop. `bash scripts/run.sh branch <KEY>` (brings the run folder onto this Mac), then `bash scripts/run.sh state <KEY>`: the card must be developed (`phase: verify` or later); otherwise say `/flow-develop <KEY>` comes first and stop. The AC must exist in `runs/<KEY>/card.md`; if not, list the card's ACs and stop. Connect the VPN with the `flow-connectivity` agent (rule A5): the checks log in on the dev WS1 and the dev services need it; if it fails, show its fix and stop. If the user gives QMetry exports, save them: `bash scripts/qmetry-import.sh <KEY> <file>`.

**2. Write the cases.** Web card: first the APIs this AC's screens call, as `flow-verify` step 4 does (D69): add any new one to `runs/<KEY>/e2e/api-list.json`, ask the user which are available on dev right now, and for each one that isn't, use its mock (if `runs/<KEY>/e2e/api-mocks.ts` has none: offer the card's Response (200) for that API when its `## API request and response` has one, a response the card marks `unchanged`: save the real one from dev with `bash scripts/api-call.sh <WS1 repo> GET <path> --env dev --save …` and use its body, nothing asked, D94; otherwise ask for the exact 200 response object; never make one up, rule A28). If the agent says an API needs a structure the card doesn't have, ask the user for it. Then save each repo's changes for the agent, which has no shell (D94): `bash scripts/repo-git.sh <repo> save-diff <KEY> <base branch>` for every repo of the card (`base_branch` in `config/repos/<repo>.yaml`); and use the **`flow-ac-checker` agent**: give it the key, this one AC, the kind of card (web when its repos include `WEB_REPO`, backend otherwise) and the user's request word for word (none: write the AC's cases again). Show the user what changed in the AC's file (the cases added, changed or removed, one line each).

**3. Run them.** Start the servers the AC needs (`bash scripts/repo-run.sh <repo> start`, WS2 first; it reuses the ones `/flow-verify` left running while the code is the same, D90; web: also `bash scripts/e2e.sh check`). If the cases need test data, or a case's call writes (`POST`, `PUT`, `PATCH`, `DELETE`), the first time in this session: show `runs/<KEY>/test-data.sql` and its cleanup (which also removes the rows the write calls create) with `bash scripts/db-run.sh <repo> show …`, list every call that writes, and add the data or send them only after a **clear yes** (rule A23). After that yes, the session's next ones run without asking (D94): say in one line what ran. Web: `bash scripts/e2e.sh probe <KEY>` first (`--mock <mocked>` when something is mocked; a flagged API is asked about as in `flow-verify` step 6). Then run only this AC: backend `bash scripts/api-check.sh <KEY> <AC>`, web `bash scripts/e2e.sh run <KEY> <AC>` (with `--mock <mocked>`), and show the result; failed API calls listed under a failing test are asked about the same way.

**4. Clean up, record and save.** Test data added or write calls sent: run the cleanup (the user said yes to it with the test data in this session, D94; with no yes in this session yet, show it and ask for a **clear yes** first). The servers stay running for a re-run (D90; `/flow-push` stops them); if WS1 was called, `bash scripts/api-call.sh <WS1 repo> logout`. Record the run at the top of `runs/<KEY>/verify.md` like `flow-verify` does (D68): `## Run <n> — <date and time> · flow-ac-check AC <AC>`, with `### AC checks` (every case run, ✅ / ❌, each failure with what was expected and what came back), `### Test data` and `### Result`; earlier runs stay as they are. Then `bash scripts/run.sh save <KEY> "AC <n> test cases updated"`. End with one line: the AC's result, and `Next: /flow-verify <KEY> runs every AC with these cases.`

## Rules
- Only this AC's cases change; the phase and Jira don't.
- Test data, calls that write and the cleanup only after the user's clear yes, the first time in a session; the session's next ones run without asking, each said in one line (A23, D94). Every run is recorded in `verify.md`, never overwritten (D68). Keys, passwords and sessions never shown (A6).
- Run the scripts exactly as written here (`bash scripts/…` from the closio-agent folder). They're pre-approved in Claude Code and Codex (D57).
