---
name: flow-review
description: "Reviews a pushed Jira card's merge requests while they wait for the merge: the MR's state and pipeline, a self-review of the code (the story and the coding basics: no redundant code, the right files), the reviewers' new comments with drafted replies and fixes, nothing sent to GitLab without your yes. Runs only when the user types /flow-review (Claude Code) or $flow-review (Codex)."
argument-hint: '<CARD-KEY> [check]'
disable-model-invocation: true
---

# flow-review

Reviews one card's merge requests while they wait for the merge (after `flow-push`, before `flow-finish`; D78). It shows each MR's state (approvals, conflicts, the pipeline), reviews the card's code against `rulesets/code-review.md` (the story, and the basics: no redundant code, the right files, clean code), and handles the reviewers' new comments: a drafted reply for a question, a tested fix for a change request, your call for the rest. Fixes go as new commits into the same MR (the review exception to "one push" and "rebase before every push", D78). Nothing reaches GitLab without your yes; it never resolves a thread and never moves the Jira card.

## Usage

- `/flow-review SCRUM-567`: a full review run: the MRs' state, the self-review, the reviewers' new comments, the fixes and replies you approve.
- `/flow-review SCRUM-567 check`: only lists what's new (comments, approvals, the pipeline, conflicts); changes nothing, so it can be repeated (e.g. Claude Code's `/loop 30m /flow-review SCRUM-567 check`).
- Codex: `$flow-review …` (approve the scripts outside the sandbox: GitLab over the VPN, the push).

## Before every step: rules and user memory (rules A17, A7, A8; D62, D91)

Do this before **each** numbered step below, not only at the start (the `check` form only reads: it does 1 and 2 and writes nothing):

1. **The rules, read in full when the command starts (rule A17, D91):** at its start (also when it continues a card), read `AGENTS.md` and `docs/agent-rules.md` in full, then run `bash scripts/run.sh rules <KEY> read`. Read them again whenever the call in item 3 says they changed or that the conversation was summarized: say so in one line, read them, run `bash scripts/run.sh rules <KEY> read` again and go on (no stop to wait). Before each step, note the rules it touches (e.g. `A21`, `A26`, `G4`).
2. **Your memory, for every step:** the first step's is printed below when the command loads; every next step's is printed by the call in item 3 (`--memory mr <repos>`), with the card's repos (`all` before you know them). Read the **user-created memory** entries it prints and apply them. Team rules always win (A8): on a conflict, say so and follow the team rule.
3. **After every step, one call (D91):** `bash scripts/run.sh step <KEY> "review <n>" "<what happened>" "rules: A21, A26 · memory: M2" --memory <the next step's phase> <repos>` (use `—` when nothing applied). It writes the step in the card's history (this command keeps no step number: no `--next`), checks whether the rules files changed since you read them (⚠️: read them again, item 1) and prints your memory for the next step. Skip nothing.
4. **Ask and decide the grilling way (rule A26, D76; `rulesets/grilling.md`):** every question this command asks you, and every prompt you give during it that changes the card's code, tests, the MR or a reply: look up the facts first and show them as "Found" lines (never ask what the code, the MR or the files answer); ask only the real decisions, in numbered rounds, each with a recommended answer that "yes" accepts; follow-up rounds until nothing is open; sum up what was agreed and wait for the confirmation before changing anything; record them as item 5 says, with a one-line pointer in `review.md` (`### Decided while grilling` in that round's section). Short answers, approvals and the user's questions go straight through. The safety stops below stay their own plain yes/no.
5. **Every decision is recorded (rule A27, D77):** the moment a decision is confirmed (a finding fixed or left, a reply approved or changed, a commit or push approved or refused, a memory entry that answered for the user, a change the user asked for), run `bash scripts/run.sh decide <KEY> "review <n>" "<question>" "<decided>" "<who / why>"` (who: `you`, `you: recommended`, `memory M2`); it prints the decision's number. Where this step keeps notes, write only a one-line pointer, e.g. `- Reuse isValidUuid in xController: yes (decision 12)`.

The first memory step runs here automatically:

!`bash scripts/memory.sh for mr all`

**If the block above still shows the command instead of its output** (e.g. in Codex), run `bash scripts/memory.sh for mr all` yourself first.

## Steps

**1. Start.** Run `bash scripts/run.sh check-folder`; if it fails, show the fix and stop. Read the card key and an optional `check` after the command (in Claude Code it may also appear as `ARGUMENTS: …`); a key not like `SCRUM-567`, or any other word: show the usage and stop. `bash scripts/run.sh state <KEY>`:
   - No run folder, or `phase:` before `after-merge` (pick-up, plan, develop, verify, ship): say the card isn't pushed yet and which command comes first (its `next:` line), and stop.
   - `phase: done`: say the card is finished, and stop.
   - `phase: after-merge`: go on.
   Then `bash scripts/run.sh branch <KEY>` (brings the card's folder onto this Mac; this folder stays on `main`) and connect the VPN with the `flow-connectivity` agent (rule A5): GitLab needs it. For every repo of the card, check this session can use its folder (rule A15); if it can't, stop and ask for access. If anything fails, show its fix and stop.

**2. The MRs' state** (only reads). Read `runs/<KEY>/ship.md` (the MR links), `review.md` if it exists (the newest round: the last seen note id per repo, the findings left open) and `decisions.md`. For each repo, with the branch from `state.md`:
   - `bash scripts/gitlab-mr.sh <repo> status <branch>`: merged (exit 0) → that MR is done; every MR merged → say `/flow-finish <KEY>` comes next, and stop.
   - `bash scripts/gitlab-mr.sh <repo> pipeline <branch>`: passed, still running, or failed with its failed jobs (exit 3).
   - `bash scripts/gitlab-mr.sh <repo> comments <branch> --since <last seen note id>` (`0` on the first run): who approved, conflicts, and the unresolved threads and new notes.
   Show a short summary per repo. **Merge conflicts:** say so; nothing is rebased by this command (D78): the user decides how (e.g. on GitLab, or `/flow-push` again with them).
   **The `check` form ends here:** list what's new (new comments, each in one line with its file and line and who wrote it; approvals; the pipeline; conflicts), then `Run /flow-review <KEY> to act on them.` Write nothing, save nothing.

**3. The self-review (`rulesets/code-review.md`).** Read the method file, and each repo's ruleset (`bash scripts/configure-repo.sh ruleset <repo>`; the web app's has its own part in the checklist). It runs on the first run of the card and whenever the code changed since the last self-review (new commits on the branch, or this run's fixes); otherwise say there's nothing new to review. For each repo, its changes against the MR's target branch:
   - **The story level**, with the `flow-story-check` agent (the card against the code).
   - **The micro level, the basics:** no redundant code (search the repo for every new function, helper, constant, regex and query; one that already does the same job and was written again is a must-fix), the right place for each piece, the WS1 schema against the card's request and response structure (every key and type, shared schema helpers), better queries (each with a "Why", D85), and the rest of the checklist, each against how that repo already does it.
   - **The tool's own bug hunter:** in Claude Code its built-in `code-review` skill on the card's branch; in Codex `bash scripts/repo-run.sh <repo> review`. Check each point against the code before showing it.
   Show the findings in chat only (never on the MR), grouped by repo, one line each: `[must fix|should fix|small] <file>:<line> <what> — <suggested fix>`; a better query adds a second line, `Why: <the reason, from the code only>` (D85). A finding already decided in `decisions.md` (fixed or left) isn't raised again.
   Then, the grilling way, decide which to fix; make the agreed fixes in the repo, then `bash scripts/repo-run.sh <repo> test` and `bash scripts/repo-run.sh <repo> check`. **A fix whose tests still fail after 2 tries goes to the user** with what failed. **Rounds: at most 3 per run** (round 1 everything; rounds 2 and 3 only the parts changed by the fixes). After round 3, list what's still open for the user and go on.

**4. The reviewers' comments** (one pass over the threads step 2 showed; a comment that arrives later waits for the next run). For each thread, from its file and line and the code there:
   - **A question:** draft the reply (plain words, what the code does and why, with the file and line).
   - **A change request:** propose the change (the grilling way, with "Found" lines); on a yes, make it, then the repo's tests and checks (2 tries at most, as in step 3); draft a reply saying what changed.
   - **Unclear, or you'd disagree:** bring it to the user with a recommendation (change it, or reply why not); the user decides.
   Write each reply the user approves, word for word, in `review.md` (this round's section).

**5. The commits** (only when there are fixes). For each repo, propose the commits like `flow-push` does: grouped by layer, each layer's code with its own tests, messages `<KEY>: address review: <what>` (one line) ✋ and wait for the approval ("change X" adjusts it); then `bash scripts/ship.sh <repo> commit "<message>" <file>…` in order. A ❌ (a hook failed): nothing of that commit is made; show its output; the user decides.

**6. ✋ The final yes.** Show, per repo: the commits to push (the review exception, D78: new commits on top, no rebase, never forced) and every reply to post (its thread, its file and line, the reply). Ask: "Push these commits and post these replies?" Go on only after a clear yes: this publishes on GitLab. A change asked for: adjust and show it again. A refusal: nothing is sent; record it (item 5).

**7. Push, then reply.** For each repo with new commits: `bash scripts/ship.sh <repo> push-update` (the MR shows them; a ❌: stop with its fix; never force a push, never rebase). Then for each approved reply: write it to `runs/<KEY>/review-reply.md` with your file-writing tool, and `bash scripts/gitlab-mr.sh <repo> reply <branch> <thread id> runs/<KEY>/review-reply.md`. **Never resolve a thread:** the reviewer does. Write each push and each posted note id in `review.md`.

**8. Save.** `runs/<KEY>/review.md`, newest round first: `## Round <n> — <date> · <full>`, with `### MR state` (per repo: approvals, pipeline, conflicts), `### Self-review` (each finding and what was done: fixed, left with its decision, or open after 3 rounds), `### Comments` (each thread: what was asked and what was done), `### Pushed and posted` (commits, note ids), `### Decided while grilling` (pointer lines), and `Seen up to note: <repo> <newest note id> · …` (from step 2's comments output). The phase stays `after-merge` and Jira stays in Code Review (rule A3: never moved here). Log "review round <n>", `bash scripts/run.sh save <KEY> "review round <n>"`. End with: `Review round <n> done: <counts>. Run /flow-review <KEY> again after new comments (or /flow-review <KEY> check to look); once the MRs are merged: /flow-finish <KEY>.`

## Before a long step, say how long (D74)

Before you start each step below, say its line in one sentence, so the user knows what's happening and roughly for how long. No step was timed yet: "several minutes". Plain words (rule A25).

- Step 3: "⏳ Reviewing the card's code (the story, the basics, and the tool's own reviewer): several minutes per repo."
- Steps 3 and 4, after a fix: "⏳ Running the repo's tests and checks again: about a minute for nodejs-ws2targetsalesincentive; several minutes for a repo not timed yet."
- Step 7, in the repos with a coverage check on every push: "⏳ Pushing the review fixes: the coverage check runs again first; about a minute."

## Rules
- Every step writes its history line with the rules and memory applied (A1, A17); `check` only reads and writes nothing.
- The checklist is `rulesets/code-review.md`; every check against how that repo already does it (A16). No redundant code (A21) and the right place for each piece (A20) are checked in every review.
- Findings are shown in chat only, never posted on the MR. At most 3 self-review rounds per run and 2 tries per failing fix (D78); then it's the user's call.
- Review fixes: new commits on top, tests first, the user's yes, `ship.sh push-update` (no rebase, never forced; the exception to G2 and G4, D78). Commits are atomic and approved (G3); the repos' git hooks always run.
- Replies are posted as the user, with their token from the Keychain (never shown, A6), only after their yes. Threads are never resolved here. Jira isn't touched (A3).
- Run the scripts exactly as written here (`bash scripts/…` from the closio-agent folder, no `cd`, nothing joined with `&&`). They're pre-approved in Claude Code and Codex (D57).
