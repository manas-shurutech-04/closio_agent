---
name: flow-push
description: "Ships a verified Jira card: rebases each repo onto the latest base branch (and checks every AC again when that brought newer code or a conflict), makes the atomic commits you approve, pushes once per repo and creates the merge requests (assigned to you, with their description and reviewers), checks the card shows them and moves it to Code Review. Runs only when the user types /flow-push (Claude Code) or $flow-push (Codex)."
argument-hint: '<CARD-KEY>'
disable-model-invocation: true
---

# flow-push

Ships one card that's been verified (C5; Phases 7 and 8 of [architecture.md](../../../docs/architecture.md); rules G2, G3, G4; D10, D11, D31, D32, D51, D70, D83). Per repo: the card's work is rebased onto the latest base branch (stash, rebase, stash pop), the tests run again, every AC is checked again the quick way when the rebase brought newer code or had a conflict, the atomic commits the user approved are made, and **one push** creates the merge request, assigned to the user; its full description and reviewers are set right after through the GitLab API. Then the card shows its MRs and moves to **Code Review**. Nothing is pushed before the user's explicit yes.

## Usage

- `/flow-push SCRUM-567`: ship the card SCRUM-567 (verified): commits, one push per repo, the MRs, Code Review; or continue where it stopped.
- Codex: `$flow-push SCRUM-567` (approve the scripts outside the sandbox: git, GitLab over the VPN, the push).

## Before every step: rules and user memory (rules A17, A7, A8; D62, D91)

For **each** numbered step below:

1. **The rules, read in full when the command starts (rule A17, D91):** at its start (also when it continues a card), read `AGENTS.md` and `docs/agent-rules.md` in full, then run `bash scripts/run.sh rules <KEY> read`. Read them again whenever the call in item 3 says they changed or that the conversation was summarized: say so in one line, read them, run `bash scripts/run.sh rules <KEY> read` again and go on (no stop to wait). Before each step, note the rules it touches (e.g. `G2`, `G4`, `A3`).
2. **Your memory, for every step:** the first step's is printed below when the command loads; every next step's is printed by the call in item 3 (`--memory ship <repos>`; from step 11 on: `--memory mr <repos>`), with the card's repos (`all` before you know them). Read the **user-created memory** entries it prints and apply them. Team rules always win (A8): on a conflict, say so and follow the team rule.
3. **After every step, one call (D91):** `bash scripts/run.sh step <KEY> "push <n>" "<what happened>" "rules: G2, G4 · memory: M2" --next <the next step> --memory <the next step's phase> <repos>` (use `—` when nothing applied). It writes the step in the card's history, moves to the next step (where a step below says "log the step; `set <KEY> step <n>`", this one call with `--next <n>` does both), checks whether the rules files changed since you read them (⚠️: read them again, item 1) and prints your memory for the next step. Where the phase changes at the end, use it without `--next` and run the `set` lines as written. Skip nothing.
4. **Ask and decide the grilling way (rule A26, D76; `rulesets/grilling.md`):** every question this command asks you, and every prompt you give during it that changes the card's plan, code, tests, data, Jira or GitLab: look up the facts first and show them as "Found" lines (never ask what the code or the files answer); ask only the real decisions, in numbered rounds, each with a recommended answer that "yes" accepts; follow-up rounds until nothing is open; sum up what was agreed and wait for the confirmation before changing anything; record them as item 5 says, with a one-line pointer in `ship.md` (`## Decided while grilling`). Short answers, approvals and the user's questions go straight through. The safety stops below stay their own plain yes/no.
5. **Every decision is recorded (rule A27, D77):** the moment a decision is confirmed (an answer to a question, an approval or a refusal at a stop, a memory entry that answered for the user, a change the user asked for), run `bash scripts/run.sh decide <KEY> "<step and its number>" "<question>" "<decided>" "<who / why>"` (who: `you`, `you: recommended`, `memory M2`); it prints the decision's number. Where this step keeps notes, write only a one-line pointer, e.g. `- Error code for a bad status: VALIDATION_ERROR (decision 3)`.

The first memory step runs here automatically:

!`bash scripts/memory.sh for ship all`

**If the block above still shows the command instead of its output** (e.g. in Codex), run `bash scripts/memory.sh for ship all` yourself first.

## Steps

**1. Start.** Run `bash scripts/run.sh check-folder`; if it fails, show the fix and stop. Read the card key typed after the command (in Claude Code it may also appear as `ARGUMENTS: …`); if it isn't like `SCRUM-567`, show the usage and stop. `bash scripts/run.sh state <KEY>`:
   - No run folder, or `phase: pick-up` / `plan` / `develop` / `verify`: say which command comes first (`/flow-start`, `/flow-develop` or `/flow-verify <KEY>`) and stop.
   - `phase: after-merge` or later: say the card is already pushed and what to type next (its `next:` line), and stop.
   - `phase: ship`: go on. A card that stopped part-way continues at its saved `step:` (after a conflict at step 4: first `bash scripts/card-branch.sh rebase-continue <repo> <branch>`; commits already made stay).
   Then `bash scripts/run.sh branch <KEY>` (brings the run folder onto this Mac; this folder stays on `main`) and connect the VPN with the `flow-connectivity` agent (rule A5): GitLab needs it. For every repo of the card, check this session can use its folder (rule A15); if it can't, stop and ask for access. If anything fails, show its fix and stop. `bash scripts/run.sh set <KEY> step 2`.

**2. Read.** `runs/<KEY>/card.md` (the key and title), `plan.md`, `develop.md` (the files of each repo, the migrations and seeders run), the newest run in `verify.md` (the top `## Run` section: its `### Result` must say everything passed; if it lists failures, e.g. from the checks after the rebase (steps 5 to 7), say `/flow-develop <KEY>` comes first: it takes the card back to develop to fix them, then `/flow-verify <KEY>` and `/flow-push <KEY>` again; and stop), and the repos and branch from `state.md`. Log the step; `set <KEY> step 3`.

**3. What will ship.** For each repo: `bash scripts/ship.sh <repo> status` (the branch, the uncommitted files, the commits the MR target doesn't have yet). Compare the files with `develop.md`: a file it doesn't name is asked about (does it belong to the card?); it's committed only when the user says so. Log the step; `set <KEY> step 4`.

**4. Stash, rebase, stash pop (rule G2, D10).** For each repo: `bash scripts/card-branch.sh rebase <repo> <branch>` (it stashes the card's work, new files too, fetches, rebases the branch onto the latest base branch and pops the stash).
   - **Exit 4, a conflict:** show the files it lists and ask the user to resolve them in their editor ✋ (keep the right code, remove the conflict lines); wait until they say it's done, then `bash scripts/card-branch.sh rebase-continue <repo> <branch>` (exit 4 again: still conflicts, ask again).
   - ⚠️ "the rebase was undone": ask the user how to go on. ❌: show the fix and stop.
   - **What came in (D83):** the last ✅ lines of each repo say whether a conflict was resolved and what came in ("<n> newer commit(s) from <base> came in" or "nothing new on <base>"). Write one line per repo in `ship.md` (`Rebase: <repo>: <n> newer commit(s) from <base>; conflict in <files>, resolved by you` or `…; no conflict`): step 6 needs it.
   Log the step; `set <KEY> step 5`.

**5. The tests and checks again.** For each repo: `bash scripts/repo-run.sh <repo> test` and `bash scripts/repo-run.sh <repo> check` (lint only warns, D65): the rebase may have brought newer code. **A failure: stop before any commit** and show it; write it as a new run at the top of `verify.md` (`## Run <n> — <date and time> · repo tests after the rebase onto <base>`, with `### Repo tests and checks` and a `### Result` that lists the failure), `bash scripts/run.sh save <KEY> "tests failed after the rebase"`, and say `/flow-develop <KEY>` takes the card back to develop to fix it (then `/flow-verify <KEY>` and `/flow-push <KEY>` again; D83). Log the step; `set <KEY> step 6`.

**6. The ACs again after the rebase (D83).** Only when step 4 had a conflict in any repo, or brought newer commits from the base branch into any repo (its `ship.md` lines). Otherwise say "Nothing new came in with the rebase; the AC checks of <the newest `verify.md` run's date> still hold." and go on.
   - Check every AC again **the quick way (B)**, whichever way the card was checked before, against the rebased code: `/flow-verify`'s steps 3 to 6 and 9 for B (start the servers, the scenarios, test data and calls that write only after a clear yes (rule A23), the AC checks, clean up). No story check. A one-repo backend card: the scenarios covered by a test (`/flow-verify` step 4, D90) are decided by step 5's test run.
   - Write it as a new run at the top of `verify.md`: `## Run <n> — <date and time> · B quick check after the rebase onto <base> (<what came in per repo; the conflicts>)`, with `### AC checks`, `### Test data` and `### Result`; a one-line pointer in `ship.md`; `bash scripts/run.sh save <KEY> "ACs checked again after the rebase"`.
   - **Every AC passes:** go on.
   - **Something fails: stop before any commit.** Show each failure with what was expected, what came back and a suggestion, and say `/flow-develop <KEY>` takes the card back to develop to fix it (then `/flow-verify <KEY>` and `/flow-push <KEY>` again). Nothing is committed or pushed.
   - **Then, checked again or not:** `bash scripts/repo-run.sh all stop` (the servers `/flow-verify` left running; nothing after this step needs them, D90).
   Log the step; `set <KEY> step 7`.

**7. The atomic commits (rule G3, D70).** For each repo, propose the commits: the card's files grouped by layer, **each layer's code with its own tests**, in an order where each commit stands on its own. For example: the migration, model and seeder; then the service with its tests; then the controller and route with their tests; WS1's schema, controller and route; a web view or component with its tests. An index or registration file goes with the layer it registers. Each message reads `<KEY>: <what this commit does>` (one line, e.g. `SCRUM-567: Add the ageing config model and migration`). Show the list per repo (message and files) ✋ and wait for the user's approval; "change X" adjusts it. Then make them in order: `bash scripts/ship.sh <repo> commit "<message>" <file>…`. In the repos with husky (ws2targetsalesincentive, ws2notification, ws2pricingengine), the coverage gate runs on every commit: say it takes a while. A ❌ (a hook failed): nothing of that commit is made; show its output, write it as a failed run at the top of `verify.md` (as in step 5, `· commit check failed`), save, and say `/flow-develop <KEY>` takes the card back to develop to fix it (commits already made stay; D83). Write each commit (hash and message) per repo in `runs/<KEY>/ship.md`. Log the step; `set <KEY> step 8`.

**8. The merge requests.** For each repo:
   - **Title:** `<KEY>: <card title>` (one line, D70).
   - **Target:** its `mr_target_branch` (shown by `ship.sh status`). **Assignee:** the user (their GitLab username; `ship.sh push` reads it).
   - **Labels and reviewers:** the repo file's `mr_labels` and `mr_reviewers` (D51). If the user's memory names their labels or reviewers (e.g. "My MR reviewers are ana.s and budi"), use those and say so in one line ("Using your memory M4: reviewers ana.s, budi"); they're still shown at the final yes (step 9) and can be changed there (D74). Else ask the user to confirm or change them (labels optional; reviewers as GitLab usernames, or none).
   - **Description**, written to `runs/<KEY>/mr-<repo>.md`:
```
**Jira:** [<KEY>: <card title>](https://<JIRA_SITE>/browse/<KEY>)

**Migrations to run:** <file names from develop.md, in order> (or none)
**Seeders to run:** <file names from develop.md, in order> (or none)
```
   (`JIRA_SITE` is in `config/project-settings.sh`.) Nothing more goes in it (D70). Log the step; `set <KEY> step 9`.

**9. ✋ The final yes.** Show, per repo: the commits, the MR title, target, assignee, labels, reviewers and the description. Ask: "Push and create these merge requests?" Go on only after a clear yes: this publishes the work on GitLab. A change asked for: adjust and show it again. Log the step; `set <KEY> step 10`.

**10. One push per repo (rule G4, D31, D32).** For each repo: `bash scripts/ship.sh <repo> push "<title>"` (add `--label <label>` per label): the push creates the MR, assigned to the user, and prints its link (the pre-push hook runs the gate again in the husky repos). Then `bash scripts/gitlab-mr.sh <repo> describe <branch> runs/<KEY>/mr-<repo>.md` (add `--reviewers <username,username>` when there are reviewers): the full description and the reviewers, through the GitLab API with the user's token from the Keychain (never shown, A6).
   - A ❌ push: stop with its fix; **never force a push**. The next run continues here (the commits are there).
   - A ❌ describe: the push is done; show the fix and run only the describe again.
   Write each push and MR link in `ship.md`. Log the step; `set <KEY> step 11`.

**11. Jira (rule A3, D11).** Read the card's links (`getJiraIssue`, or `executeRead` for its remote links): GitLab's Jira link usually adds each MR by itself. For every MR the card doesn't show, add **one** comment listing the missing MR links (`addOrEditJiraIssueComment`, e.g. "Merge requests: nodejs-ws2targetsalesincentive: <link>"). Then move the card to **Code Review** (if a tool needs the transition id, read the card's transitions first, read only). Never move it anywhere else (never Blocked, A3). With the Jira API backup (see Rules): `get <KEY>` (its issue links and web links), `comment <KEY> <file>`, `move <KEY> "Code Review"`. `bash scripts/run.sh set <KEY> jira_status "Code Review"`. Log the step; `set <KEY> step 12`.

**12. Save.** `ship.md` complete (per repo: the commits, the push, the MR link, the reviewers). `bash scripts/run.sh set <KEY> phase after-merge`, `set <KEY> step 1`, `set <KEY> next "/flow-finish <KEY>"`, log "pushed, MRs created, Code Review", `bash scripts/run.sh save <KEY> "pushed: MRs created, Code Review"`. End with: `Done: <KEY> is pushed and in Code Review. MRs: <links>. While they wait for the merge: /flow-review <KEY> (a self-review and the reviewers' comments). Once they're merged: /flow-finish <KEY> (Codex: $flow-finish <KEY>).`

## Before a long step, say how long (D74)

Before you start each step below, say its line in one sentence, so the user knows what's happening and roughly for how long. The times come from real runs; "several minutes" where none was timed yet. Plain words (rule A25).

- Step 5: "⏳ Running the tests again after the rebase: about a minute for nodejs-ws2targetsalesincentive; several minutes for a repo not timed yet."
- Step 6, when something came in: "⏳ Checking every AC again after the rebase, the quick way: about a minute to start the servers, then about a minute for 22 scenarios."
- Step 7, in the repos with a coverage check on every commit (nodejs-ws2targetsalesincentive, nodejs-ws2notification, nodejs-ws2pricingengine): "⏳ Making the commits: each one runs the repo's coverage check first; 5 commits took about 2 minutes."
- Step 10: "⏳ Pushing and creating the merge requests: about a minute (the coverage check runs once more in those repos)."

## Rules
- Every step writes its history line with the rules and memory applied (A1, A17).
- Stash, rebase, stash pop, then the commits (G2, D10); a conflict is resolved by the user, never by guessing.
- When the rebase brought newer code or had a conflict, every AC is checked again the quick way before any commit; a failure stops the push and goes back to develop through `/flow-develop` (D83).
- The commits are atomic and approved by the user before they're made (G3); each layer's code with its tests; messages `<KEY>: …` (D70). The repos' git hooks always run; never skip them.
- One push per repo, never forced, only after the user's explicit yes (G4). The MR is created by the push (D31); its description and reviewers are set through the GitLab API (D32); the token is read by the script and never shown (A6).
- The card moves only to Code Review here (D11, A3).
- Run the scripts exactly as written here (`bash scripts/…` from the closio-agent folder, no `cd`, nothing joined with `&&`). They're pre-approved in Claude Code and Codex (D57).
- **The Jira API backup (D88, rule A31).** The Jira connector comes first. If its tools still aren't there after 3 tries (`bash scripts/wait-seconds.sh 10` between them), or a Jira tool fails or can't do what's needed, switch to the API by yourself, without asking: say once `Jira connector not available: using the Jira API backup.` and use `bash scripts/jira-api.sh` for the rest of this command: `get <KEY>` (the card's issue links and web links), `comment <KEY> <file>` and `move <KEY> "Code Review"` (step 11). Text it posts is first written with your file-writing tool to `local/jira/<KEY>-<what>.md` (private, never pushed), unless the step names a file. Before you redo a change that failed through the connector, read the card again (`get`, `comments`), so nothing is done twice. Every yes stop stays exactly as with the connector. Exit code 3 means the backup isn't set up either: show `❌ Jira isn't connected in <Claude Code or Codex>` with the connector's fix (as in `/flow-doctor`) and `Or set up the Jira API backup: /flow-configure-user jira-email, then /flow-configure-user jira-api-token`, and stop.
