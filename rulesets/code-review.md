# Code review: what `/flow-review` checks in a card's code

> **closio-agent's review checklist** ([D78](../docs/design-decisions.md#d78)), used by `flow-review`'s self-review of a card's MRs, before the reviewers look.
>
> - **Who changes it:** the closio-agent builders, in this folder. No command adds or changes it.
> - **Team rules win** (A8): a user's memory can add a check for that user, never remove one of these.
> - **Every check is made against how that repo already does it** (the closest existing file of the same kind, its utils, constants and middlewares, rule A16), never against a new style. A check whose answer the repo doesn't settle is a question for the user, not a finding.
> - Works the same in Claude Code and Codex; the story ruleset ([story-implementation-workflow.md](story-implementation-workflow.md)) and the grilling way ([grilling.md](grilling.md)) apply too.

---

## What is reviewed

Each of the card's repos: its changes on the card's branch against the MR's target branch (`git diff origin/<target>...HEAD`, the target from `mr_target_branch`, else `base_branch`, in `config/repos/<repo>.yaml`), the files read whole where a change needs its context.

## Three passes

1. **The story level** (below), with the `flow-story-check` agent for the card against the code.
2. **The micro level, the basics** (below): every changed file, line by line.
3. **The tool's own bug hunter, as a second pair of eyes:** in Claude Code its built-in `code-review` skill on the card's branch; in Codex `codex review --base <target>` run in the repo's folder. Its findings are checked against the code before they're shown (no finding is passed on unchecked).

## The story level

- Every AC of the card is covered by the code **and** by a test (unit, API), error paths included.
- The error codes, HTTP statuses and messages are the ones the code already has (rule A16); a new one was decided by the user (its decision in `decisions.md`).
- What the card's `decisions.md` says was decided is what was built; nothing decided is missing, nothing undecided was added.
- The plan's file list (`plan.md`) matches the changed files; a file changed outside the plan has a reason in `develop.md`.

## The micro level: the basics

**No redundant code (rule A21), a must-fix when broken:**
- Every new function, helper, constant, regex or query: search the repo for one that already does the same job (by name, by what it does, in the `utils`, `helpers`, `constants`, `middlewares` folders and the closest services; e.g. `isValidUuid` in `pgDbUtils.js`, `isUuid` in `dataTypeUtils.js`, WS1's `isValidUUID` in `helperFunctions.js`, `createError`). One that does the same job and was written again: **must fix**, reuse the existing one.
- The same logic written twice within the change (two handlers with the same checks, a copied block): **should fix**, one function in the right file.

**The right place** (the repo's own layout, rules A20, A21):
- Business logic in services; request-only checks in the controller (small) or the repo's domain utils file (over about 30 lines, used by more than one handler, or a nested body); checks that need the database in the service.
- Database access only in services and models; never in a controller or a route.
- Constants in the repo's constants files; shared helpers in its utils; error codes where the repo keeps them.
- Routes registered in their index files; WS1 holds no business logic (a proxy: schema checks of presence, type and format; a URL ID through `isValidUUID`); new WS1 routes run `validateSchema` before `isAuthenticated`.
- Every field the WS2 response can return listed in the WS1 schema, optional ones nullable and not required (A22).
- The request each API accepts and the response it returns match the card's `## API request and response`, the user's structure (A28, D84); any difference was asked about, not decided.

**The basics:**
- Names say what the thing does, in the repo's naming style.
- No unused imports, variables or parameters; no dead or commented-out code.
- No debug output left in (`console.log` and the like); the repo's logger where it has one.
- No hard-coded value that exists as a constant, a setting or an env variable name; no key, password or token in the code (A6).
- Errors through the repo's own error helper and error handler, with existing codes; async errors handled the way the repo's closest route does (Express 5).
- No database call inside a loop where one query would do; request input never put straight into SQL (the repo's ORM or its replacements).
- A function does one job; one over about 30 lines is flagged.
- Tests: the new branches and error paths covered; no skipped or focus-only test (`.skip`, `.only`); the repo's coverage gate passes (`bash scripts/repo-run.sh <repo> test`).
- Lint warnings on the changed files (`bash scripts/repo-run.sh <repo> check`): shown, never older ones elsewhere.
- Migrations and seeders follow the repo's existing pattern and were reviewed by the user (A23).
- Every changed file ends with a newline.

**In the web app** (`type: FE`; [frontend-story-workflow.md](frontend-story-workflow.md), [D80](../docs/design-decisions.md#d80)), the right place and the basics are the frontend ruleset's Step 5; in short:
- A new component, composable or helper that one in `src/components/`, `src/composables/`, `src/utils/` or the module already provides (e.g. a table instead of `BaseDataTable`, a loading or error block instead of `LoadingSpinner` / `MessageCard`, a date format instead of `formatDate`): **must fix**, reuse it.
- Files in the module's layout (`src/views/<module>/` with `components/`, `types/`, `utils/`, `__tests__/`; API functions in `src/api/<module>.ts`); checks, payload and error mapping as plain functions in the module's `utils/`; create and edit sharing one form.
- API functions return an `ErrorResponse` (a cancel thrown again), send `'X-Secure-Transmission-Type': 'x'` on writes, take an `AbortSignal` on loads.
- Messages through `useAppToast` (never `BaseToast`); dates through `formatDate` (never `formatDateShort`); numbers through `BaseInputNumber`.
- Loading, error, empty and not-found states on every page that loads data; routes with `meta.permissions` and guards; a new screen's test ids.
- Tests: `__tests__/<File>.test.ts`, the page, API and utils patterns of the frontend ruleset's Step 6; every AC and its error paths.

## How a finding is shown (chat only, never on the MR)

One line each, plain words, grouped by repo:

```
[must fix]   src/controllers/xController.js:42   isValidUuid is written again here; reuse it from src/utils/pgDbUtils.js
[should fix] src/services/xService.js:88         a database call inside the loop; one findAll with the ids would do
[small]      src/routes/xRoutes.js:3             unused import of asyncHandler
```

- **must fix:** breaks a team rule, the story, or works wrongly (a bug).
- **should fix:** the basics above (quality).
- **small:** style the repo does differently.

Which ones to fix is decided with the user the grilling way ([grilling.md](grilling.md)); each decision goes in the card's `decisions.md` (rule A27).

## Rounds: a fixed number, so it never loops

- **At most 3 self-review rounds per run:** round 1 reviews everything; after the fixes the user agreed, rounds 2 and 3 re-check only the changed parts. After round 3, whatever is still open is listed for the user, and the run goes on to the reviewers' comments without another round.
- **At most 2 tries per failing fix:** a fix whose tests or checks still fail after 2 tries goes to the user with what failed; nothing is pushed for it.
- A finding the user decided to leave is recorded (`decisions.md`) and not raised again in later rounds or runs.
