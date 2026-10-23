---
name: flow-finish
description: "Finishes a Jira card after its merge requests are merged: checks the merge, checks every acceptance criterion on the dev environment once you say it's deployed, writes the deployment doc (in the run folder and on the Jira card), and moves the card to Ready for Test. Runs only when the user types /flow-finish (Claude Code) or $flow-finish (Codex)."
argument-hint: '<CARD-KEY>'
disable-model-invocation: true
---

# flow-finish

Finishes one card after the merge (C6; Phase 9 of [architecture.md](../../../docs/architecture.md); D11, D12, D22, D37, D71, D72). It checks that every MR of the card is merged, asks the user whether the card is deployed on dev, checks every AC on **dev** the quick way (B), writes `runs/<CARD-KEY>/deployment.md` and puts it on the Jira card as one comment, then moves the card to **Ready for Test**. A failure: it tells the user what's wrong and suggests what to do; the user decides. The run branch `runs/<CARD-KEY>` is kept as the card's record (never merged into `main`, D38, D72).

## Usage

- `/flow-finish SCRUM-567`: finish the card SCRUM-567 once its MRs are merged: the dev checks, the deployment doc, Ready for Test; or continue where it stopped.
- Codex: `$flow-finish SCRUM-567` (approve the scripts outside the sandbox: GitLab and dev over the VPN, the database).

## Before every step: rules and user memory (rules A17, A7, A8; D62)

Do this before **each** numbered step below, not only at the start:

1. Re-read `AGENTS.md` and `docs/agent-rules.md`. Note the rules the step touches (e.g. `A3`, `A23`, `A24`).
2. Run `bash scripts/memory.sh for after-merge <repos>` with the card's repos (`all` before you know them). Read the **user-created memory** entries it prints and apply them. Team rules always win (A8): on a conflict, say so and follow the team rule.
3. After the step, write it in the card's history: `bash scripts/run.sh log <KEY> "finish <n>" "<what happened>" "rules: A3, A23 · memory: M2"` (use `—` when nothing applied). Skip nothing.
4. **Ask and decide the grilling way (rule A26, D76; `rulesets/grilling.md`):** every question this command asks you, and every prompt you give during it that changes the card's plan, code, tests, data, Jira or GitLab: look up the facts first and show them as "Found" lines (never ask what the code or the files answer); ask only the real decisions, in numbered rounds, each with a recommended answer that "yes" accepts; follow-up rounds until nothing is open; sum up what was agreed and wait for the confirmation before changing anything; record them as item 5 says, with a one-line pointer in the card's `history.md` (the special instructions still go in `deployment.md`). Short answers, approvals and the user's questions go straight through. The safety stops below stay their own plain yes/no.
5. **Every decision is recorded (rule A27, D77):** the moment a decision is confirmed (an answer to a question, an approval or a refusal at a stop, a memory entry that answered for the user, a change the user asked for), run `bash scripts/run.sh decide <KEY> "<step and its number>" "<question>" "<decided>" "<who / why>"` (who: `you`, `you: recommended`, `memory M2`); it prints the decision's number. Where this step keeps notes, write only a one-line pointer, e.g. `- Error code for a bad status: VALIDATION_ERROR (decision 3)`.

The first memory step runs here automatically:

!`bash scripts/memory.sh for after-merge all`

**If the block above still shows the command instead of its output** (e.g. in Codex), run `bash scripts/memory.sh for after-merge all` yourself first.

## Steps

**1. Start.** Run `bash scripts/run.sh check-folder`; if it fails, show the fix and stop. Read the card key typed after the command (in Claude Code it may also appear as `ARGUMENTS: …`); if it isn't like `SCRUM-567`, show the usage and stop. `bash scripts/run.sh state <KEY>`:
   - No run folder, or an earlier phase (`pick-up` … `ship`): say which command comes first (`/flow-start`, `/flow-develop`, `/flow-verify` or `/flow-push <KEY>`) and stop.
   - `phase: done`: say the card is already finished (Ready for Test) and stop.
   - `phase: after-merge`: go on; a card that stopped part-way continues at its saved `step:`.
   Then `bash scripts/run.sh branch <KEY>` (brings the run folder onto this Mac; this folder stays on `main`) and connect the VPN with the `flow-connectivity` agent (rule A5): GitLab and dev need it. For every repo of the card, check this session can use its folder (rule A15). `bash scripts/run.sh set <KEY> step 2`.

**2. Merged?** For each repo: `bash scripts/gitlab-mr.sh <repo> status <branch>` (the branch from `state.md`). Exit 3 (still open, or closed without merging): show it and stop: run `/flow-finish <KEY>` again once it's merged. ❌: show the fix and stop. Keep each MR's merge commit for the doc. Log the step; `set <KEY> step 3`.

**3. Deployed on dev?** Ask the user in the chat: "Is <KEY> deployed on the dev environment (every repo: <repos>)?" Wait for the answer; nothing checks it by itself. Not yet: stop; run `/flow-finish <KEY>` again once it is. Log the step; `set <KEY> step 4`.

**4. The checks on dev (D22, B: the quick check, D72).** Every repo needs its dev address: `bash scripts/configure-repo.sh show <repo>` shows `Dev:`; if it's not set, ask the user for it and save it with `bash scripts/configure-repo.sh set-dev-url <repo> <url>` (a shared file: it should be committed). Then check every AC exactly as `/flow-verify`'s quick check does (its steps 4 to 6, B), but **on dev**: add `--env dev` to every `bash scripts/api-call.sh …` call (WS1 with the dev login, rule A24; a direct WS2 call with WS1's pair, D37) and to `bash scripts/e2e.sh probe|quick …` (the dev web app); a web card's APIs are asked about as there (D69). Test data and calls that write are shown first and run only after a clear yes, with their cleanup (rule A23); remove the scratch files at the end with `bash scripts/run.sh quick-clean <KEY>`. Record the run at the top of `verify.md`: `## Run <n> — <date and time> · dev check (B)`, every scenario with ✅ / ❌ (each failure: what was expected, what came back). **A failure:** list each one with what you suggest (a fix after a merge needs a new branch and MR: ask the user whether it's a new card or a follow-up on this one; a setup problem: the exact fix); the card stays in `after-merge`; the user decides; stop. Log the step; `set <KEY> step 5`.

**5. Special instructions.** If the user's memory holds standing instructions for the deployment doc (e.g. "Deployment doc: deploy WS2 repos one at a time"), put them in and say so in one line ("Using your memory M5"), then ask only: "Anything else special for this card?" (D74). Else ask the user once: "Anything special for the deployment doc (an order, a flag, a manual step)?" Their answer goes in as they wrote it ("none" is fine). Log the step; `set <KEY> step 6`.

**6. The deployment doc (D12, D72): `runs/<KEY>/deployment.md`.** Written for two kinds of readers, in plain words: **QA** and **the person deploying**. From `ship.md`, `develop.md`, `card.md`, the code and the dev check:
```
# <KEY> — <card title> (deployment)
Card: [<KEY>: <card title>](https://<JIRA_SITE>/browse/<KEY>)

## For QA
**What it adds:** <two or three plain sentences: what the card adds or changes, and for whom>

**How to try it**
<an API card (a backend repo changed a route): for each API, its name in words, then ready-to-run curls:>
1. The dev login, which gives the session cookie:
   curl -i -X POST '<WS1 dev login URL>' -H 'Content-Type: application/json' -d '{"userid":"<your userid>","password":"<your password>", …}'
   Copy the session cookie it sets.
2. Through WS1: curl '<WS1 dev address><path>?<filters>' -H 'Cookie: <cookie name>=<your session cookie>' …
3. Straight to WS2: curl '<WS2 dev address><path>?<filters>' -H 'x-client-id: <client id>' -H 'x-client-secret: <client secret>' …
<then, in words: the filters and what they accept; the errors (when, and what comes back); and a table of what comes back:>
| Field | What it means | Example from dev |

<a web card> **Where to find it:** the menu path to the screen, e.g. Manajemen Insentif › Tipe Insentif › Lihat Detail
<a consumer card (a repo with queues changed a consumer or worker)> **How to test it:** in words: which event sends the message and from where, what changes once it's handled, and what to look for

**Already checked on dev (<date>):** <the result of step 4, e.g. every acceptance criterion passed>

## For the person deploying
**Order** (WS2 repos first, then WS1, then the web app):
1. <the repo in words> (<repo>): MR [!<n>](<link>)

### <repo>
- **Database changes:** for each migration, in order: its file name; what it changes, in plain words; whether it's safe to run twice; how it's undone, in words.   (or: none)
- **Default data:** for each seeder: its file name; "run it on its own, not with all the others"; what it adds, in plain words; whether it's safe to run twice; how it's undone, in words.   (or: none)
- **New settings:** each new `.env` setting's name (from the card's diff of `.env.example`) and one line on what it's for; never a value.   (or: none)
- **After deploying:** <from develop.md>   (or: nothing)

## Special instructions
<the user's words from step 5>   (or: none)
```
   **Rules for the doc (D72, changed 2026-10-19):**
   - **Plain words, no code:** no migration or seeder code, no commands, no raw JSON (requests, responses, messages). The one exception: the API curls.
   - **The curls come from the calls that passed in the dev check (step 4):** the same paths, headers, filters and login fields that `scripts/api-call.sh` sent (header names and login fields from the code, rule A16). Every userid, password, cookie, key and secret is a placeholder like `<your session cookie>`; never a real value (A6).
   - **MR number and link only**, no merge commit ID. Leave out a part that doesn't apply (e.g. "How to try it" for a card with no API, screen or consumer). The menu path comes from the web app's menu labels in its code (its router and menu files); the user may correct it. `JIRA_SITE` is in `config/project-settings.sh`.

   **Before the doc is handed over, show every migration and seeder it names for review (rule A23):** the full file (up and down), what it changes (tables, columns, rows), the repo; then a **separate yes** that it may go out (the doc asks someone to run them on a server). Log the step; `set <KEY> step 7`.

**7. Jira (rules A3, D11, D72).** Post the deployment doc on the card as **one comment** (`addOrEditJiraIssueComment`) and keep the comment's id in the card's own notes, not in the doc: `bash scripts/run.sh set <KEY> jira_comment <id>`. On a later run, **edit that comment** instead of posting a new one: its id is `bash scripts/run.sh get <KEY> jira_comment` (an older doc may still carry it on a `Jira comment: <id>` line at its top: use that id, save it as above and remove the line from the doc). Then, the dev checks having passed, move the card to **Ready for Test** (if a tool needs the transition id, read the card's transitions first, read only); never anywhere else (never Blocked, A3). With the Jira API backup (see Rules): `comment <KEY> runs/<KEY>/deployment.md` (keep the `Comment id` it prints), on a later run `edit-comment <KEY> <id> runs/<KEY>/deployment.md`, then `move <KEY> "Ready for Test"`. `bash scripts/run.sh set <KEY> jira_status "Ready for Test"`.
   **A Bug card raised for a story** (D81): if this card is a Bug that relates to a story (its "relates to" link, or the story key on its "Relates to" line), read that story's `qa.md` (`bash scripts/run.sh branch <story KEY>`, then `runs/<story KEY>/qa.md`) and the status of the story and of every Bug card listed there (your Jira tools, read only). If the story is **In Development** and every one of its Bug cards is now in **Ready for Test or later**, ask: "Every Bug card of <story KEY> is fixed and on dev. Move <story KEY> back to Ready for Test?" On a clear yes, move it, `bash scripts/run.sh set <story KEY> jira_status "Ready for Test"`, and record it: `bash scripts/run.sh decide <story KEY> "qa (from /flow-finish <KEY>)" "Move back to Ready for Test?" "yes" "you"`, `bash scripts/run.sh save <story KEY> "back to Ready for Test after <KEY>"`. Any other case: leave the story as it is and say why in one line. Log the step; `set <KEY> step 8`.

**8. Save.** `bash scripts/run.sh set <KEY> phase done`, `set <KEY> step 1`, `set <KEY> next "finished"`, log "finished: deployment doc on the card, Ready for Test", `bash scripts/run.sh save <KEY> "finished: Ready for Test"`. The run branch `runs/<KEY>` stays as the card's record (`/flow-status` lists it under Finished); it's never merged into `main`. End with: `Done: <KEY> is in Ready for Test. Deployment doc: runs/<KEY>/deployment.md and on the card.`

## Before a long step, say how long (D74)

Before you start each step below, say its line in one sentence, so the user knows what's happening and roughly for how long. The times come from real runs; "several minutes" where none was timed yet. Plain words (rule A25).

- Step 4: "⏳ Checking every AC on dev: about a minute for 22 scenarios; several minutes more for a web card's browser tests."

## Rules
- Every step writes its history line with the rules and memory applied (A1, A17).
- Nothing is assumed deployed: the user says so (D72). The dev checks are the quick check (B) with `--env dev`; test data, calls that write and the cleanup only after a clear yes (A23).
- Migrations and seeders named in the deployment doc are shown for review first, then a separate yes (A23).
- The deployment doc lives in the card's folder and on the Jira card as one comment, edited on a re-run (D12, D72). It's written in plain words for QA and the person deploying: no code, commands or raw JSON, except the API curls, whose logins, cookies and keys are placeholders. The card moves only to Ready for Test here (D11, A3); for a Bug card raised by `/flow-qa`, its story too, from In Development, after the user's yes (D81).
- Keys, passwords, sessions and `.env` values are never shown (A6). Never read `.env` values.
- Run the scripts exactly as written here (`bash scripts/…` from the closio-agent folder, no `cd`, nothing joined with `&&`). They're pre-approved in Claude Code and Codex (D57).
- **The Jira API backup (D88, rule A31).** The Jira connector comes first. If its tools still aren't there after 3 tries (`bash scripts/wait-seconds.sh 10` between them), or a Jira tool fails or can't do what's needed, switch to the API by yourself, without asking: say once `Jira connector not available: using the Jira API backup.` and use `bash scripts/jira-api.sh` for the rest of this command: `comment <KEY> runs/<KEY>/deployment.md` or `edit-comment <KEY> <id> runs/<KEY>/deployment.md`, `move <KEY> "Ready for Test"`, and `get <KEY>` / `status <KEY> …` for a Bug card's story and its Bug cards (step 7). Text it posts is first written with your file-writing tool to `local/jira/<KEY>-<what>.md` (private, never pushed), unless the step names a file. Before you redo a change that failed through the connector, read the card again (`get`, `comments`), so nothing is done twice. Every yes stop stays exactly as with the connector. Exit code 3 means the backup isn't set up either: show `❌ Jira isn't connected in <Claude Code or Codex>` with the connector's fix (as in `/flow-doctor`) and `Or set up the Jira API backup: /flow-configure-user jira-email, then /flow-configure-user jira-api-token`, and stop.
