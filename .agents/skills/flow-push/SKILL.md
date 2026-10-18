---
name: flow-push
description: "Ships a verified Jira card (Phases 7 and 8): rebases each repo onto the latest base branch, makes the atomic commits you approve, pushes once per repo and creates the merge requests (assigned to you, with their description and reviewers), checks the card shows them and moves it to Code Review. Runs only when the user types /flow-push (Claude Code) or $flow-push (Codex)."
argument-hint: '<CARD-KEY>'
disable-model-invocation: true
---

# flow-push

Ships one card that's been verified (C5; Phases 7 and 8 of [architecture.md](../../../docs/architecture.md); rules G2, G3, G4; D10, D11, D31, D32, D51, D70). Per repo: the card's work is rebased onto the latest base branch (stash, rebase, stash pop), the tests run again, the atomic commits the user approved are made, and **one push** creates the merge request, assigned to the user; its full description and reviewers are set right after through the GitLab API. Then the card shows its MRs and moves to **Code Review**. Nothing is pushed before the user's explicit yes.

## Usage

- `/flow-push SCRUM-567`: ship the card SCRUM-567 (verified): commits, one push per repo, the MRs, Code Review; or continue where it stopped.
- Codex: `$flow-push SCRUM-567` (approve the scripts outside the sandbox: git, GitLab over the VPN, the push).

## Before every step: rules and user memory (rules A17, A7, A8; D62)

Do this before **each** numbered step below, not only at the start:

1. Re-read `AGENTS.md` and `docs/agent-rules.md`. Note the rules the step touches (e.g. `G2`, `G4`, `A3`).
2. Run `bash scripts/memory.sh for ship <repos>` (for steps 10 and 11: `bash scripts/memory.sh for mr <repos>`), with the card's repos (`all` before you know them). Read the **user-created memory** entries it prints and apply them. Team rules always win (A8): on a conflict, say so and follow the team rule.
3. After the step, write it in the card's history: `bash scripts/run.sh log <KEY> "push <n>" "<what happened>" "rules: G2, G4 · memory: M2"` (use `—` when nothing applied). Skip nothing.

The first memory step runs here automatically:

!`bash scripts/memory.sh for ship all`

**If the block above still shows the command instead of its output** (e.g. in Codex), run `bash scripts/memory.sh for ship all` yourself first.

## Steps

**1. Start.** Run `bash scripts/run.sh check-folder`; if it fails, show the fix and stop. Read the card key typed after the command (in Claude Code it may also appear as `ARGUMENTS: …`); if it isn't like `SCRUM-567`, show the usage and stop. `bash scripts/run.sh state <KEY>`:
   - No run folder, or `phase: pick-up` / `plan` / `develop` / `verify`: say which command comes first (`/flow-start`, `/flow-develop` or `/flow-verify <KEY>`) and stop.
   - `phase: after-merge` or later: say the card is already pushed and what to type next (its `next:` line), and stop.
   - `phase: ship`: go on. A card that stopped part-way continues at its saved `step:` (after a conflict at step 4: first `bash scripts/card-branch.sh rebase-continue <repo> <branch>`; commits already made stay).
   Then `bash scripts/run.sh branch <KEY>` (brings the run folder onto this Mac; this folder stays on `main`) and connect the VPN with the `flow-connectivity` agent (rule A5): GitLab needs it. For every repo of the card, check this session can use its folder (rule A15); if it can't, stop and ask for access. If anything fails, show its fix and stop. `bash scripts/run.sh set <KEY> step 2`.

**2. Read.** `runs/<KEY>/card.md` (the key and title), `plan.md`, `develop.md` (the files of each repo, the migrations and seeders run), the newest run in `verify.md` (the top `## Run` section: its `### Result` must say everything passed; if it lists failures, say `/flow-verify <KEY>` comes first and stop), and the repos and branch from `state.md`. Log the step; `set <KEY> step 3`.

**3. What will ship.** For each repo: `bash scripts/ship.sh <repo> status` (the branch, the uncommitted files, the commits the MR target doesn't have yet). Compare the files with `develop.md`: a file it doesn't name is asked about (does it belong to the card?); it's committed only when the user says so. Log the step; `set <KEY> step 4`.

**4. Stash, rebase, stash pop (rule G2, D10).** For each repo: `bash scripts/card-branch.sh rebase <repo> <branch>` (it stashes the card's work, new files too, fetches, rebases the branch onto the latest base branch and pops the stash).
   - **Exit 4, a conflict:** show the files it lists and ask the user to resolve them in their editor ✋ (keep the right code, remove the conflict lines); wait until they say it's done, then `bash scripts/card-branch.sh rebase-continue <repo> <branch>` (exit 4 again: still conflicts, ask again).
   - ⚠️ "the rebase was undone": ask the user how to go on. ❌: show the fix and stop.
   Log the step; `set <KEY> step 5`.

**5. The tests and checks again.** For each repo: `bash scripts/repo-run.sh <repo> test` and `bash scripts/repo-run.sh <repo> check` (lint only warns, D65): the rebase may have brought newer code. A failure: stop, show it, and suggest `/flow-develop <KEY>`; the user decides. Log the step; `set <KEY> step 6`.

**6. The atomic commits (rule G3, D70).** For each repo, propose the commits: the card's files grouped by layer, **each layer's code with its own tests**, in an order where each commit stands on its own. For example: the migration, model and seeder; then the service with its tests; then the controller and route with their tests; WS1's schema, controller and route; a web view or component with its tests. An index or registration file goes with the layer it registers. Each message reads `<KEY>: <what this commit does>` (one line, e.g. `SCRUM-567: Add the ageing config model and migration`). Show the list per repo (message and files) ✋ and wait for the user's approval; "change X" adjusts it. Then make them in order: `bash scripts/ship.sh <repo> commit "<message>" <file>…`. In the repos with husky (ws2targetsalesincentive, ws2notification, ws2pricingengine), the coverage gate runs on every commit: say it takes a while. A ❌ (a hook failed): nothing of that commit is made; show its output and suggest `/flow-develop <KEY>`; the user decides (commits already made stay). Write each commit (hash and message) per repo in `runs/<KEY>/ship.md`. Log the step; `set <KEY> step 7`.

**7. The merge requests.** For each repo:
   - **Title:** `<KEY>: <card title>` (one line, D70).
   - **Target:** its `mr_target_branch` (shown by `ship.sh status`). **Assignee:** the user (their GitLab username; `ship.sh push` reads it).
   - **Labels and reviewers:** the repo file's `mr_labels` and `mr_reviewers` (D51); ask the user to confirm or change them (labels optional; reviewers as GitLab usernames, or none).
   - **Description**, written to `runs/<KEY>/mr-<repo>.md`:
```
**Jira:** [<KEY>: <card title>](https://<JIRA_SITE>/browse/<KEY>)

**Migrations to run:** <file names from develop.md, in order> (or none)
**Seeders to run:** <file names from develop.md, in order> (or none)
```
   (`JIRA_SITE` is in `config/project-settings.sh`.) Nothing more goes in it (D70). Log the step; `set <KEY> step 8`.

**8. ✋ The final yes.** Show, per repo: the commits, the MR title, target, assignee, labels, reviewers and the description. Ask: "Push and create these merge requests?" Go on only after a clear yes: this publishes the work on GitLab. A change asked for: adjust and show it again. Log the step; `set <KEY> step 9`.

**9. One push per repo (rule G4, D31, D32).** For each repo: `bash scripts/ship.sh <repo> push "<title>"` (add `--label <label>` per label): the push creates the MR, assigned to the user, and prints its link (the pre-push hook runs the gate again in the husky repos). Then `bash scripts/gitlab-mr.sh <repo> describe <branch> runs/<KEY>/mr-<repo>.md` (add `--reviewers <username,username>` when there are reviewers): the full description and the reviewers, through the GitLab API with the user's token from the Keychain (never shown, A6).
   - A ❌ push: stop with its fix; **never force a push**. The next run continues here (the commits are there).
   - A ❌ describe: the push is done; show the fix and run only the describe again.
   Write each push and MR link in `ship.md`. Log the step; `set <KEY> step 10`.

**10. Jira (rule A3, D11).** Read the card's links (`getJiraIssue`, or `executeRead` for its remote links): GitLab's Jira link usually adds each MR by itself. For every MR the card doesn't show, add **one** comment listing the missing MR links (`addOrEditJiraIssueComment`, e.g. "Merge requests: nodejs-ws2targetsalesincentive: <link>"). Then move the card to **Code Review** (if a tool needs the transition id, read the card's transitions first, read only). Never move it anywhere else (never Blocked, A3). `bash scripts/run.sh set <KEY> jira_status "Code Review"`. Log the step; `set <KEY> step 11`.

**11. Save.** `ship.md` complete (per repo: the commits, the push, the MR link, the reviewers). `bash scripts/run.sh set <KEY> phase after-merge`, `set <KEY> step 1`, `set <KEY> next "/flow-finish <KEY>"`, log "pushed, MRs created, Code Review", `bash scripts/run.sh save <KEY> "pushed: MRs created, Code Review"`. End with: `Done: <KEY> is pushed and in Code Review. MRs: <links>. Next, once the MRs are merged: /flow-finish <KEY> (Codex: $flow-finish <KEY>).`

## Rules
- Every step writes its history line with the rules and memory applied (A1, A17).
- Stash, rebase, stash pop, then the commits (G2, D10); a conflict is resolved by the user, never by guessing.
- The commits are atomic and approved by the user before they're made (G3); each layer's code with its tests; messages `<KEY>: …` (D70). The repos' git hooks always run; never skip them.
- One push per repo, never forced, only after the user's explicit yes (G4). The MR is created by the push (D31); its description and reviewers are set through the GitLab API (D32); the token is read by the script and never shown (A6).
- The card moves only to Code Review here (D11, A3).
- Run the scripts exactly as written here (`bash scripts/…` from the closio-agent folder, no `cd`, nothing joined with `&&`). They're pre-approved in Claude Code and Codex (D57).
