---
name: flow-develop
description: "Develops a planned Jira card together with the user: the code and its unit tests from the approved plan, the ruleset and the user's memory, the repo checks, then the user's review. Starts when the user types /flow-develop (Claude Code) or $flow-develop (Codex), or when they ask in plain words to develop a card whose plan is approved (they name the card, or exactly one card is in development). Never for any other request."
argument-hint: '<CARD-KEY>'
disable-model-invocation: false
---

# flow-develop

Develops one card whose plan is approved (C3; Phases 3 and 4 of [architecture.md](../../../docs/architecture.md); D61, D65): the code and its unit tests, with the user, then the user's review ✋. It ends when the user approves the review; the next command is `flow-verify`. Everything is remembered in `runs/<CARD-KEY>/`, saved to the card's branch of closio-agent (`runs/<CARD-KEY>`, never `main`; this folder stays on `main`), so it can be paused and continued. The code itself stays uncommitted in the repos until `flow-push` (rule G3), so a card paused here can only be continued on this Mac.

## Usage

- `/flow-develop SCRUM-567`: develop the card SCRUM-567 from its approved plan, or continue where it stopped.
- Plain words: "develop SCRUM-567" or "start developing the card" also start it, but only for a card whose plan is approved (you name it, or it's the only card in development).
- Codex: `$flow-develop SCRUM-567` (approve the scripts outside the sandbox: git, GitLab over the VPN, the repo's own commands).

## Started from plain words? Check first (D61, the one exception to D44 and `AGENTS.md` rule 1)

If the user didn't type `/flow-develop` or `$flow-develop`, go on **only** when one of these is true:
- they named a card, and `bash scripts/run.sh state <KEY>` shows `phase: develop` (its plan is approved); or
- they named no card, and `bash scripts/run.sh list` shows **exactly one** card in `phase develop`: use that one, and say which.

Otherwise don't start: show `bash scripts/run.sh list` and say what to type (`/flow-start <KEY>` to plan a card first, or `/flow-develop <KEY>` for the card they mean). Never start any other flow command from plain words.

## Before every step: rules and user memory (rules A17, A7, A8; D62)

Do this before **each** numbered step below, not only at the start:

1. Re-read `AGENTS.md` and `docs/agent-rules.md`. Note the rules the step touches (e.g. `A13`, `A16`, `G3`).
2. Run `bash scripts/memory.sh for develop <repos>` (for steps 10 and 11: `bash scripts/memory.sh for review <repos>`), with the card's repos (`all` before you know them). Read the **user-created memory** entries it prints (the ones the user made with `flow-memory`, in `local/memory/`) and apply them. An entry may change a point of the ruleset for this user (A19); team rules always win (A8): on a conflict, say so and follow the team rule.
3. After the step, write it in the card's history with what you applied: `bash scripts/run.sh log <KEY> "develop <n>" "<what happened>" "rules: A13, A16 · memory: M2"` (use `—` when nothing applied; steps 10–11: `"review <n>"`). Skip nothing.
4. **Ask and decide the grilling way (rule A26, D76; `rulesets/grilling.md`):** every question this command asks you, and every prompt you give during it that changes the card's plan, code, tests, data, Jira or GitLab: look up the facts first and show them as "Found" lines (never ask what the code or the files answer); ask only the real decisions, in numbered rounds, each with a recommended answer that "yes" accepts; follow-up rounds until nothing is open; sum up what was agreed and wait for the confirmation before changing anything; record them as item 5 says, with a one-line pointer in `develop.md` (`## Decided while grilling`). Short answers, approvals and the user's questions go straight through. The safety stops below stay their own plain yes/no.
5. **Every decision is recorded (rule A27, D77):** the moment a decision is confirmed (an answer to a question, an approval or a refusal at a stop, a memory entry that answered for the user, a change the user asked for), run `bash scripts/run.sh decide <KEY> "<step and its number>" "<question>" "<decided>" "<who / why>"` (who: `you`, `you: recommended`, `memory M2`); it prints the decision's number. Where this step keeps notes, write only a one-line pointer, e.g. `- Error code for a bad status: VALIDATION_ERROR (decision 3)`.

The first memory step runs here automatically:

!`bash scripts/memory.sh for develop all`

**If the block above still shows the command instead of its output** (e.g. in Codex), run `bash scripts/memory.sh for develop all` yourself first.

## Steps

**1. Start.** Run `bash scripts/run.sh check-folder`; if it fails, show the fix and stop. Read the card key typed after the command (in Claude Code it may also appear as `ARGUMENTS: …`) or the one from the plain-words check; if it isn't like `SCRUM-567`, show the usage and stop. `bash scripts/run.sh state <KEY>`:
   - No run folder, or `phase: pick-up` / `plan`: the plan isn't approved yet. Say "finish with `/flow-start <KEY>` first" and stop.
   - `phase: verify` or `ship`, and the newest run in `runs/<KEY>/verify.md` (the top `## Run` section) lists failures under its `### Result` (after `bash scripts/run.sh branch <KEY>`, which brings the folder here; for `ship`, the checks `/flow-push` ran after its rebase, D83): **the user decides** (D67). Show the failures and ask whether to go back to develop to fix them. On a clear yes: `bash scripts/run.sh set <KEY> phase develop`, `set <KEY> step 4`, `set <KEY> next "/flow-develop <KEY>"`, add a `## Back from verify` section (from `ship`: `## Back from the push`) to `develop.md` listing them, log "back from verify" (or "back from the push"), and continue as a continuation (step 2, then step 4 works through that list; the summary and the review show what was fixed). Coming back from the push, the rebase stays and any commits already made stay; the next `/flow-push` builds on them. On no: stop.
   - Any other later phase (`verify` or `ship` with nothing failed, `after-merge`, …): say where the card is and what to type next (its `next:` line), and stop.
   - `phase: develop`: go on.
   Then `bash scripts/run.sh branch <KEY>` (brings the card's run folder onto this Mac without switching this folder, which stays on `main`) and connect the VPN with the `flow-connectivity` agent (rule A5). If either fails, show its fix and stop. If `step:` is above 1, this is a continuation: do step 2, read what step 3 reads (plus `develop.md` so far and each repo's uncommitted changes with `bash scripts/repo-git.sh <repo> diff`), then **go to the saved step**.

**2. Repos ready.** The repos are in the `repos:` line of `state.md`; the card's branch in its `branch:` line. For each repo, in order:
   - **Folder access first (rule A15):** this session can use the repo's folder (`local_path` in `local/repos/<repo>.yaml`). If not, stop and ask the user to give access (Claude Code: `/add-dir <folder>` or a new session; Codex: start again with `codex --add-dir <folder>`).
   - **First start** (no `develop.md` yet): `bash scripts/card-branch.sh update <repo> <branch>` brings the latest base branch in (exit code 3 = uncommitted changes: stop and ask; ❌ = show the fix and stop).
   - **Continuing** (`develop.md` exists): `bash scripts/card-branch.sh check <repo>` only, and make sure the clone is on the card's branch. The card's own work is uncommitted on purpose; the newer base branch comes in with the rebase in `flow-push` (rule G2).
   - Log the step; `bash scripts/run.sh set <KEY> step 3`.

**3. Read.** `runs/<KEY>/plan.md` (the approved plan: what to build, in which order), `runs/<KEY>/card.md` (with `## Explained at pick-up` and `## Decided before planning`), `runs/<KEY>/decisions.md` (every decision so far, in full), the ruleset (`bash scripts/configure-repo.sh ruleset <repo>`, then read the file; backend repos follow `rulesets/story-implementation-workflow.md`, the web app `rulesets/frontend-story-workflow.md`; rule A19), the memory entries from the check above, and in every repo the files the plan names and the files next to them (the closest existing module). Never read or print `.env` values (A6). Log the step; `set <KEY> step 4`.

Steps 4 to 8 are done **repo by repo, in the plan's order** (WS2 before WS1, D26). Write `runs/<KEY>/develop.md` as you go (its shape is in step 9), so a later session can continue.

**4. Develop.** Build this repo's part of the plan, following the ruleset (its Step 5: the order, the tips, the pitfalls):
   - Code follows the closest existing files: their structure, names, error handling, logging, response shape.
   - **The request the code accepts and the response it returns follow the card's `## API request and response`** (the user's structure, rule A28). A field the card doesn't have, or a different type, is asked about, never decided; the tests use the same structures. An API with no structure in the card: ask the user for it before building it.
   - **Create the new files** the plan lists, and any other new file the work needs; each one goes in the summary (step 8) and in `develop.md`.
   - **Request validation (rule A20):** WS1 is a proxy: its schema checks only presence (`required`), type and format, with messages through `replaceMessagePlaceholders` and keys already in its locale files; a URL ID's format is checked in the WS1 controller with the existing `isValidUUID`; no business rule in WS1. WS2 checks everything it receives again and owns every business-logic check: in the controller when it needs only the request (inline when small; a function in the repo's domain utils file when it's over about 30 lines, used by more than one handler, or checks a nested body), in the service when it needs the database. Follow the plan's `## Validation, reuse and response fields`.
   - **No redundant code (rule A21):** before creating any function, helper, constant or regex, search the repo for one that does exactly the same job (by name, by what it does, in `utils`, `helpers`, `constants`, `middlewares`). The same: import and reuse it. Close but not the same: **ask the user** (reuse, extend or new) and wait. None: create it. Write each search in `develop.md` under "Reused and new".
   - **The WS1 schema from the card's structure (rule A22, D85):** every key of the card's request and response structure, with its type, under `request`, `queryParameter` and `responses.<status>`; `null` ones nullable (`['string', 'null']`) and not in `required`. A block a shared schema helper gives is reused; common blocks (pagination, the audit fields) come from the shared helper the plan names, never copied.
   - **Queries (D85; the ruleset's "Queries" list):** every new query follows the list (one query instead of several, only the columns needed, filtering, sorting, paging and counting in the database, existence checks and counts, an index for an unindexed `WHERE` or join column, one transaction for writes that belong together). A better version of an existing query the card touches: **ask the user**, never change it silently.
   - **Error codes, HTTP statuses, messages, fields, columns, headers and constants come from the code** (rule A16). Anything the code doesn't have yet, or anything that differs from the plan: **ask the user first** and wait; write their answer under "Not in the plan" in `develop.md`.
   - **Never commit, stash, rebase or push** in the repo (rule G3: the atomic commits come in `flow-push`). Never clone (D53).
   - Log the step with the files created and changed; `set <KEY> step 5`.

**5. Tests.** Write the repo's committed tests, in the format the repo registered (`test_framework`, `test_layout` in `config/repos/<repo>.yaml`; the ruleset's Step 6):
   - Backend repo with a test suite: unit tests for the controller and the service, and the API tests (supertest), each mapped to the card's ACs.
   - The web app: Vitest unit tests in the repo (the end-to-end Playwright tests are written later by `flow-verify`, outside the repo, D24).
   - A repo with `test_command: none` (today `nodejs-ws1closio`, `ws2jauth`) gets none (D25).
   Then run them: `bash scripts/repo-run.sh <repo> test` (every test and the coverage gate, on the repo's Node version, rule A13). On ❌, fix the code or the tests and run it again until it's ✅. Log the step with the result line; `set <KEY> step 6`.

**6. Checks.** `bash scripts/repo-run.sh <repo> check` (the repo's lint and circular-import checks). **Lint** checks only the files the card changed and shows its problems as ⚠️ warnings (D65): tidy them in the card's own files if you can, never touch older lint errors elsewhere, and go on either way; list the warnings in the summary. **Any other check** on ❌: fix and run it again. Log the step; `set <KEY> step 7`.

**7. Migrations and seeders.** Only if this repo's part of the plan has them and they need to run now. **First the review (rule A23):** show the user the full migration or seeder file(s) (the up and the down), what each changes (tables, columns, rows), the repo, and what will run (`npm run migrate` or `npm run seed`, against the database the repo's `.env` names, today the dev database; D21); ask them to review it. **Only after a separate yes**, every run: `bash scripts/repo-run.sh <repo> migrate confirmed` (or `seed confirmed`). Write each run in `develop.md` (for the deployment doc, D12). If the user says no, or there's nothing to run, go on. Log the step; `set <KEY> step 8`.

**8. Summary, then the next repo.** Show a short summary of this repo and **carry straight on** with the next repo (back to step 4); the user can stop or steer any time. The same summary goes in `develop.md`:
```
<repo>: done (repo 1 of 2)
New:      <new files, short>
Changed:  <changed files>
Tests:    <the result line of repo-run.sh test, or "no test suite">
Checks:   <passed / what was fixed> · lint: <passed, or ⚠️ N problems in the card's files>
Not in the plan: <each item with the user's answer, or none>
Reused and new: <reused X from <file> · new Y (searched, none found)>
Queries:  <each new query, one line each: what it does · why it's written this way>
Next:     <the next repo, or "your review">
```
After the last repo: log the step; `set <KEY> step 9`.

**9. Save.** Make sure `runs/<KEY>/develop.md` is complete, in this shape (written with your file-writing tool):
```
# <KEY> — development
Plan: plan.md (approved on <date>) · Ruleset: <the ruleset file of each repo> · Memory applied: M2 (changes: …) or none

## <repo>            (one section per repo, the summary of step 8)
## Migrations and seeders run     (each run: repo, command, date, result; or none)
## Review            (filled in at steps 10 and 11)
```
Then `bash scripts/run.sh set <KEY> next "/flow-develop <KEY>"`, `bash scripts/run.sh save <KEY> "developed, waiting for the review"`. Show its output (on ❌ the push failed: show the fix and stop; the commit is kept). Log the step; `set <KEY> step 10`.

**10. ✋ The user's review (Phase 4).** Show, per repo: the files changed (`bash scripts/repo-git.sh <repo> diff --stat` and the new files), what each item of the plan became, every change from the plan, and every new function with the search behind it (rule A21). Ask the user to review the changes in their editor and say "review approved", or what to change.
   - Changes asked: write them under `## Review` in `develop.md`, go back to step 4 for the repos involved (tests and checks again), then show the review again.
   - Approved **in so many words**: write "Approved by the user on <date>" under `## Review`. Log the step; `set <KEY> step 11`.

**11. Finish.** `bash scripts/run.sh set <KEY> phase verify`, `set <KEY> step 1`, `set <KEY> next "/flow-verify <KEY>"`, log "review approved", and `bash scripts/run.sh save <KEY> "developed and reviewed"`. Show the save's output and end with one line: `Done: <KEY> is developed and reviewed. Next: /flow-verify <KEY> (Codex: $flow-verify <KEY>).`

## Before a long step, say how long (D74)

Before you start each step below, say its line in one sentence, so the user knows what's happening and roughly for how long. The times come from real runs; "several minutes" where none was timed yet. Plain words (rule A25).

- Step 5, running the tests: "⏳ Running <repo>'s tests with its coverage check: about a minute for nodejs-ws2targetsalesincentive; several minutes for a repo not timed yet." (a repo with no tests: nothing to say)

## Rules
- Every step writes its history line with the rules and memory applied (A1, A17). Pausing is just stopping; the next `/flow-develop <KEY>` carries on (on this Mac: the code isn't pushed yet).
- The plan, the ruleset (A19), the user's memory and the card files together decide what is built; anything new or different is asked first (A16).
- No commits, stashes, rebases or pushes in the repos here (G2, G3). Cloning is manual (D53); folder access is asked first (A15).
- Every command in a repo runs through `bash scripts/repo-run.sh` (the repo's own commands, on its Node version, A13); migrations and seeders only after the user's yes, every run (D21).
- Never read, print or store secrets, `.env` values or Keychain values (A6). The run folder never holds them.
- Run the scripts exactly as written here (`bash scripts/…` from the closio-agent folder, no `cd`, nothing joined with `&&`). They're pre-approved in Claude Code and Codex (D57). Code edits in the repo folders ask as usual in Claude Code, so the user sees every change.
