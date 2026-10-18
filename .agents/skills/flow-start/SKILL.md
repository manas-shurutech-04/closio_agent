---
name: flow-start
description: "Picks up a Jira card and plans it: the card checked, moved to In Development and assigned to you, a branch in every repo it needs, the plan made from the code and approved by you. Runs only when the user types /flow-start (Claude Code) or $flow-start (Codex)."
argument-hint: '<CARD-KEY>'
disable-model-invocation: true
---

# flow-start

Picks up one card and plans it (C2; Phases 1 and 2 of [architecture.md](../../../docs/architecture.md); D61). It ends when the user has approved the plan. Everything it does is remembered in `runs/<CARD-KEY>/`, saved to the card's branch of closio-agent (`runs/<CARD-KEY>`, never `main`; this folder itself stays on `main`), so it can be paused and continued: run it again and it carries on from the last finished step.

## Usage

- `/flow-start SCRUM-567`: pick up the card SCRUM-567 and plan it, or continue where it stopped.
- Codex: `$flow-start SCRUM-567` (approve the scripts outside the sandbox: git, GitLab over the VPN, pushes).

## Before every step: rules and user memory (rules A17, A7, A8; D62)

Do this before **each** numbered step below, not only at the start:

1. Re-read `AGENTS.md` and `docs/agent-rules.md`. Note the rules the step touches (e.g. `A3`, `A12`, `A15`).
2. Run `bash scripts/memory.sh for pick-up <repos>` (for steps 7 to 11: `bash scripts/memory.sh for plan <repos>`), with the repos the card needs once you know them (`all` before that). Read the **user-created memory** entries it prints (the ones the user made with `flow-memory`, in `local/memory/`) and apply them. Team rules always win (A8): on a conflict, say so and follow the team rule.
3. After the step, write it in the card's history with what you applied: `bash scripts/run.sh log <KEY> "pick-up <n>" "<what happened>" "rules: A3, A12 · memory: M2"` (use `—` when nothing applied). Skip nothing.

The first memory step runs here automatically:

!`bash scripts/memory.sh for pick-up all`

**If the block above still shows the command instead of its output** (e.g. in Codex), run `bash scripts/memory.sh for pick-up all` yourself first.

## Steps

**1. Start.** Run `bash scripts/run.sh check-folder`; if it fails, show the fix and stop. Read the card key typed after the command (in Claude Code it may also appear as `ARGUMENTS: …`); if it isn't like `SCRUM-567`, show the usage and stop. If `bash scripts/run.sh state <KEY>` shows a run folder, this is a continuation: run `bash scripts/run.sh branch <KEY>` first (it brings the card's run folder onto this Mac without switching this folder; ❌ = show the fix and stop), then read its `step:` line and **go straight to that step** (the steps before are done). **If that step is 8, 9 or 10 (planning), go to step 7 first:** the latest code is always read again before planning goes on (rule A18), and a draft plan is never saved before the approval, so it's made again. Then connect the VPN with the `flow-connectivity` agent (rule A5): GitLab is needed in step 5. If it fails, show its fix and stop.

**2. The card.** Read the card from Jira with your Jira tools (key, summary, issue type, status, assignee, sprint, description). Read only here.
   - A **Spike**: say "the agent doesn't pick up Spikes (D58)" and stop. Nothing is created.
   - Status **not To Do**, or **assigned to someone else**: say so and ask whether to go on. Stop until the user answers; on no, stop.
   - Then: `bash scripts/run.sh branch <KEY>` (makes the card's branch of closio-agent ready without switching this folder; a teammate's run folder comes along if there is one), `bash scripts/run.sh create <KEY> "<summary>"`, and `bash scripts/run.sh set <KEY> type <issue type>`, `… set <KEY> jira_status <status>`.
   - Save the card's text to `runs/<KEY>/card.md` with your file-writing tool, exactly as Jira returns it (the same layout as `flow-check-card`: a title line, a `_Type · Status · Read on <date>_` line, then the description). Then run `bash scripts/card-check.sh runs/<KEY>/card.md` and show its output.
   - On any ❌: list the gaps and **wait**. The user fixes the card in Jira (then read it again) or explains in chat; write what they explain under a heading `## Explained at pick-up` at the end of `card.md`. A **Bug** may keep its gaps after the explanation (D58). Go on only when the user says so.
   - Log the step; `bash scripts/run.sh set <KEY> step 3`.

**3. Jira.** With your Jira tools (these two changes are pre-approved, D57; never move a card to Blocked, A3):
   - If the card isn't in the active sprint: find the active sprint (one issue from `project = SCRUM AND sprint in openSprints()` shows the Sprint field and its id) and set that sprint on the card (the Sprint field; on the first run, check the field's id on the card you read and note it in the history). If the sprint can't be set, say so with what you tried and go on; the user can move the card by hand (D13).
   - Move the card to **In Development** (if a tool needs the transition id, read the card's transitions first, read only).
   - Assign it to the user: the account ID is `JIRA_ACCOUNT_ID` in `local/user-settings.sh` (not a secret; if it's empty, say "run /flow-configure-user jira-account-id" and stop).
   - `bash scripts/run.sh set <KEY> jira_status "In Development"`; log the step; `set <KEY> step 4`.

**4. The repos.** From the card's Scope section (and its title, e.g. "(WS2 + WS1)"), work out which registered repos the card needs (`config/repos/*.yaml`; the Scope sub-headings name them). Show the list and ask the user to confirm, add or remove; wait. Then `bash scripts/run.sh set <KEY> repos "<repo1>, <repo2>"`; log the step; `set <KEY> step 5`.

**5. The branches.** For each repo, in order:
   - **Folder access first (rule A15):** check this session can use the repo's folder (`local_path` in `local/repos/<repo>.yaml`): it's one of this session's folders, or reading a file in it works. If not, stop and ask the user to give access (Claude Code: `/add-dir <folder>` or a new session; Codex: start again with `codex --add-dir <folder>`), and go on only after they have.
   - The branch name: `bash scripts/branch-name.sh make <KEY> "<summary>"` suggests one (rule A12, at most 5 words, the same name in every repo). Show it and ask the user to confirm or change it (check a changed one with `bash scripts/branch-name.sh check <name>`); wait. Once, for all repos.
   - `bash scripts/card-branch.sh create <repo> <name>`: it fetches, pulls the repo's base branch (G1) and creates the branch, or reuses one that exists. Exit code 3 = uncommitted changes in that clone: **stop and ask** the user to commit or stash them, then run it again. ❌ = show the fix and stop. Never clone (D53); never run anything else in a repo here.
   - `bash scripts/run.sh set <KEY> branch <name>`; log the step with every repo's result; `set <KEY> step 6`.

**6. Save.** `bash scripts/run.sh set <KEY> phase plan`, `set <KEY> next "/flow-start <KEY>"` (the step lives only in the `step:` line), then `bash scripts/run.sh save <KEY> "picked up: In Development, branches created"`. Show its output. On ❌ (the push failed), show the fix and stop; the commit is kept.

**7. The code first (rule A18), never skipped.** Phase 2 starts here.
   - **The latest base branch:** for every repo, `bash scripts/card-branch.sh update <repo> <branch>`. Show its output. Exit code 3 = uncommitted changes in that clone: **stop and ask** the user to commit or stash them, then run it again. ❌ = show the fix and stop. ⚠️ (the branch has commits of its own) = go on, and also read the newer base code with the `git diff` it names.
   - **The ruleset (rule A19):** for every repo, `bash scripts/configure-repo.sh ruleset <repo>` and read the file it names (❌ = show the fix and stop). Backend repos follow all of it; the web app follows its common practices (the note at its top). It's read, never changed.
   - **The code:** in every repo the card needs, read the current code on the card's branch: routes, controllers, services, utils, constants, middlewares, migrations and seeders, and the WS1 locale files for messages (the ruleset's Step 3 lists the must-read files). Read what the card touches and its sibling modules. Never read or print `.env` values (A6). A plan is never made from the card alone.
   - Log the step with each repo's update result and the files you read; `set <KEY> step 8`.

**8. Questions first (rules A16, A18).** Compare the card with the code and list **every difference**, each with what the code has today and what the card says: error codes, HTTP statuses, messages and error-body shapes (the code is the source of truth; nothing new is invented); field, column, header and variable names; tables or things the card names that aren't in the code; validation order and edit rules; anything in the card that's unclear or incomplete. **Also, when the card has a WS1 schema (rule A22):** the full list of fields the WS2 response can return (from the WS2 model and service), each marked required or optional, optional ones included (e.g. `updated_at`, `updated_by`, `updated_by_name`); ask the user to confirm the list. Ask the user about them **in one message, each with a recommended answer**, and **wait**. Write the answers under `## Decided before planning` at the end of `runs/<KEY>/card.md`. **When continuing:** read `runs/<KEY>/card.md` first (its `## Explained at pick-up` and `## Decided before planning`) and ask only what isn't answered there, plus any new difference the newer code brings. If there's nothing to ask, say so and go on. Log the step; `set <KEY> step 9`.

**9. The draft plan.** Build it from these together: the ruleset (Step 7), the user's memory (re-read for the `plan` phase: `bash scripts/memory.sh for plan <repos>`; an entry may change a ruleset point, and the agent rules always win, A8), the card files (`card.md` with its `## Explained at pick-up` and `## Decided before planning`), the code, the ACs and the special cases (migrations and seeders: the existing pattern, D51; queues; setups). Show the plan **in chat**, in the ruleset's plan format (its Step 4):
   - `Ruleset: rulesets/story-implementation-workflow.md · Memory applied: M2 (changes: <the ruleset point it changes, if any>)` (or `none`)
   - `## Summary` (the card in a few lines) · `## Acceptance criteria` (as in the card) · `## Decided before planning` (the answers from step 8)
   - `## Changes`: one `###` part per repo, in the order to build it (WS2 before WS1, D26), each a numbered list of the files: what changes, where
   - `## AC → Implementation Mapping` (a table: AC · where · how)
   - `## Validation, reuse and response fields`: each request check and where it goes (rule A20: WS1 schema for presence, type and format; WS2 controller inline or a utils function for request-only business checks; WS2 service for database checks); the existing functions to reuse and where they are, and each new function with "searched, none found" (rule A21); the WS1 response fields as confirmed, required or optional (rule A22)
   - `## Error codes` (the existing ones used, from the code) · `## Migrations, seeders, queues` (or "none"; migrations and seeders are reviewed by the user and run only after a separate yes, every run, rule A23) · `## Tests` (what gets committed, the coverage gate) · `## Out of scope`
   Nothing is saved yet. Log the step; `set <KEY> step 10`.

**10. ✋ Manual approval (rule A18), strictly necessary.** Ask the user to approve the plan. On changes, change it and show it again, until they say yes in so many words. Nothing is written to the run folder and nothing is pushed before that. Log the step.

**11. Save and finish.** Write the approved plan to `runs/<KEY>/plan.md` with your file-writing tool (the shape above, `# <KEY> — plan` as its title, "Approved by the user on <date>" under it). Then `bash scripts/run.sh set <KEY> phase develop`, `set <KEY> step 1`, `set <KEY> next "/flow-develop <KEY>"`, log "plan approved and saved", and `bash scripts/run.sh save <KEY> "plan approved"`. Show the save's output and end with one line: `Done: <KEY> is planned. Next: /flow-develop <KEY> (Codex: $flow-develop <KEY>), or say "develop <KEY>".`

## Before a long step, say how long (D74)

Before you start each step below, say its line in one sentence, so the user knows what's happening and roughly for how long. The times come from real runs; "several minutes" where none was timed yet. Plain words (rule A25).

- Step 7: "⏳ Bringing the latest code into the card's branches and reading it: about 5 minutes for 2 repos."

## Rules
- Every step writes its history line with the rules and memory applied (A1, A17). Pausing is just stopping; the next `/flow-start <KEY>` carries on.
- The card in Jira: only its sprint, its status and its assignee change (D58); never Blocked (A3).
- Branch names follow the strict rule (A12); cloning is manual (D53); folder access is asked first (A15); nothing runs in a repo here except `card-branch.sh`.
- The code is read before the plan (with the latest base branch brought in first), every difference is asked about first, and the plan is saved only after the user's manual approval (A16, A18).
- The ruleset (`rulesets/`) is read, never changed (A19). The user changes its points only through their memory, and the plan says which entry changed which point.
- Never read, print or store secrets, `.env` values or Keychain values (A6). The run folder never holds them.
- Run the scripts exactly as written here (`bash scripts/…` from the closio-agent folder, no `cd`, nothing joined with `&&`). They're pre-approved in Claude Code and Codex, as are the Jira reads and the two Jira changes (D57).
