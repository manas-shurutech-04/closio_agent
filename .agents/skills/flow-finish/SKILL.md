---
name: flow-finish
description: "Finishes a Jira card after its merge requests are merged (Phase 9): checks the merge, checks every acceptance criterion on the dev environment once you say it's deployed, writes the deployment doc (in the run folder and on the Jira card), and moves the card to Ready for Test. Runs only when the user types /flow-finish (Claude Code) or $flow-finish (Codex)."
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

**5. Special instructions.** Ask the user once: "Anything special for the deployment doc (an order, a flag, a manual step)?" Their answer goes in as they wrote it ("none" is fine). Log the step; `set <KEY> step 6`.

**6. The deployment doc (D12, D72): `runs/<KEY>/deployment.md`.** From `ship.md`, `develop.md`, `card.md`, the code and the dev check:
```
# <KEY> — deployment
Card: [<KEY>: <card title>](https://<JIRA_SITE>/browse/<KEY>) · Jira comment: <id, once posted>

## Deploy order
1. <repo> — MR !<n> (merge commit <sha>)        (WS2 repos first, then WS1, then the web app)

## <repo>
- MR: <link> · merge commit `<sha>`
- Migrations to run, in order: `<file>` — `npm run migrate`; rollback: `npx sequelize-cli db:migrate:undo --name <file>`   (or: none)
- Seeders to run: `<file>` — `npx sequelize-cli db:seed --seed <file>` (never `db:seed:all`); rollback: `npx sequelize-cli db:seed:undo --seed <file>`   (or: none)
- New .env variables: `<NAME>` (names only, from the card's diff of `.env.example`)   (or: none)
- After deploying: <from develop.md>   (or: none)

## APIs                                   (an API card: a backend repo changed a route)
For each API: the method and path, its **WS1 dev URL** and **WS2 dev URL** (each repo's dev address + path), the headers it needs (names only), the query parameters, and a sample success response from the dev check.

## Where to find it                       (a web card)
The breadcrumb to the screen in the app (e.g. Manajemen Insentif › Tipe Insentif › Lihat Detail), from the web app's menu labels in its code (its router and menu files); the user may correct it.

## How to test it                         (a consumer card: a repo with queues changed a consumer or worker)
The queue, a sample message, and what to look for, from the code.

## Special instructions
<the user's words from step 5>   (or: none)
```
   `JIRA_SITE` is in `config/project-settings.sh`; the commands come from the repo file (`migration_commands`, `seed_commands`). Leave out a section that doesn't apply. **Before the doc is handed over, show every migration and seeder it names for review (rule A23):** the full file (up and down), what it changes (tables, columns, rows), the repo; then a **separate yes** that it may go out (the doc asks someone to run them on a server). Log the step; `set <KEY> step 7`.

**7. Jira (rules A3, D11, D72).** Post the deployment doc on the card as **one comment** (`addOrEditJiraIssueComment`); write the comment's id at the top of `deployment.md` (`Jira comment: <id>`). On a later run, **edit that comment** instead of posting a new one. Then, the dev checks having passed, move the card to **Ready for Test** (if a tool needs the transition id, read the card's transitions first, read only); never anywhere else (never Blocked, A3). `bash scripts/run.sh set <KEY> jira_status "Ready for Test"`. Log the step; `set <KEY> step 8`.

**8. Save.** `bash scripts/run.sh set <KEY> phase done`, `set <KEY> step 1`, `set <KEY> next "finished"`, log "finished: deployment doc on the card, Ready for Test", `bash scripts/run.sh save <KEY> "finished: Ready for Test"`. The run branch `runs/<KEY>` stays as the card's record (`/flow-status` lists it under Finished); it's never merged into `main`. End with: `Done: <KEY> is in Ready for Test. Deployment doc: runs/<KEY>/deployment.md and on the card.`

## Rules
- Every step writes its history line with the rules and memory applied (A1, A17).
- Nothing is assumed deployed: the user says so (D72). The dev checks are the quick check (B) with `--env dev`; test data, calls that write and the cleanup only after a clear yes (A23).
- Migrations and seeders named in the deployment doc are shown for review first, then a separate yes (A23).
- The deployment doc lives in the run folder and on the Jira card as one comment, edited on a re-run (D12, D72). The card moves only to Ready for Test here (D11, A3).
- Keys, passwords, sessions and `.env` values are never shown (A6). Never read `.env` values.
- Run the scripts exactly as written here (`bash scripts/…` from the closio-agent folder, no `cd`, nothing joined with `&&`). They're pre-approved in Claude Code and Codex (D57).
