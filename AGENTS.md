# Rules for AI tools in closio-agent

Claude Code and Codex both read this file at the start of every session in this folder (D45).
The full list of agent rules, with the reasons, is in `docs/agent-rules.md`.

1. Flow commands run only when the user types them (`/flow-…` or `$flow-…`).
   Don't do a command's steps or run its scripts on your own.
   If the user asks for something a command does (e.g. "check my setup"),
   tell them which command to type (e.g. `/flow-doctor` or `$flow-doctor`) and stop.
   Exceptions: the user clearly asks you to run or test a specific script; and `flow-develop` (D61, D65) also starts when the
   user asks in plain words to develop a card whose plan is approved (they name the card, or exactly one card is in the develop
   phase). Never any other command from plain words.
2. Sessions start in this folder, after `nvm use v22`.
3. Never read or print secrets, `.env` values or Keychain values.
4. When anything fails (a check, a step, a command), always tell the user the exact steps to fix it (rule A11).
5. Branch names, in every repo, strictly follow `SCRUM-<number>/<short-description>`: the card key as in Jira, then a description of
   lowercase words joined by `-` (only a-z and 0-9), at most 5 words, e.g. `SCRUM-519/add-filter-status`. Use the same name in every
   repo of a card. Make and check names with `bash scripts/branch-name.sh` (rule A12, D50).
6. Every code repo runs on the Node version it is built for: `node_version` in `config/repos/<repo>.yaml` (from its Dockerfile).
   Before running anything in a repo (install, run, test, lint, migrate, seed), switch to that version in the same shell command:
   `source "${NVM_DIR:-$HOME/.nvm}/nvm.sh" && nvm use <version>`. If nvm doesn't have it yet, run `nvm install <version>` first
   (rule A13, D52). closio-agent itself and Claude Code / Codex stay on Node 22 (rule A9).
7. Cloning a repo is always done by the user, by hand. Never clone a repo yourself (D53).
8. Before working in a code repo, check that this session can use its folder. If it can't, stop and ask the user to give access,
   with the exact way (Claude Code: `/add-dir <folder>` or a new session; Codex: restart with `codex --add-dir <folder>` or approve
   its request). Go on only after the user has given access (rule A15, D55).
9. User memory (rules A7, A8; D40, D56): every flow command loads it first with `bash scripts/memory.sh for <phase> …`: the setup
   commands `for setup all`, `flow-check-card` and `flow-status` `for pick-up all`, each card command its own phase (and again before
   every step, rule 12). Claude Code runs the first one by itself when the command loads; in Codex, run it yourself first. Apply the
   entries that fit. Team rules always win over memory.
   When the user corrects you during a flow command, offer once to save it to their memory; save it only after a clear yes,
   with `bash scripts/memory.sh add …` (the same steps as `/flow-memory add`).
10. Error codes, HTTP statuses and messages always come from the code (rule A16, D59). Before developing a card, read the ones that
    already exist in every repo the card touches (constants, utils, controllers, middlewares, WS1 locale files). If the card lists
    error codes, check each one against the code and point out every difference; use the code's exact errors and messages for the
    right conditions. Never invent a new error code, status, message, field or constant; a truly new one needs the user's approval.
11. Adding or changing a flow command (rule R17, D60): in the same step, give it a `## Usage` block in its `SKILL.md` (and, when it
    takes arguments, an `argument-hint` line in its frontmatter: what Claude Code's `/` menu shows), a place in a `flow-help` group (the `GROUP_` lines in `scripts/help.sh`), a section in `docs/commands.md`, a section and an index row in
    `docs/user-guide.md`, and update the Claude artifact of the guide from `docs/user-guide.md` (its link is at the top of the
    guide), then set the guide's "mirrored" line (the date and every command).
    Only Claude Code can reach the artifact: a change made in Codex is finished in Claude Code. `bash scripts/help.sh check`
    (also run by flow-doctor) fails until all of this is done.
12. In the card phases (flow-status, flow-start, flow-develop, flow-verify, flow-ac-check, flow-push, flow-review, flow-finish, flow-qa; rule A17,
    D62): before every step, re-read this file and `docs/agent-rules.md`, and read the user-created memory (the entries the
    user made with flow-memory, in `local/memory/`): `bash scripts/memory.sh for <phase> <repos>`. Apply both, and write in
    the card's `runs/<CARD-KEY>/history.md` which rules and entries you applied; flow-status only reads, so it writes
    nothing. Skip nothing.
13. Planning a card (rule A18, D63): first pull the base branches and read the current code of every repo involved (routes,
    controllers, services, utils, constants, middlewares, migrations, locale files); never plan from the card alone. List every
    difference between the card and the code (error codes, statuses, messages, fields, anything the card names that isn't in the
    code) and ask the user about them first; wait for the answers. Only then draft the plan. Nothing is saved or pushed before
    the user approves the plan in chat; that approval is strictly necessary.
14. Rulesets (rule A19, D64, D80): every card follows its repo's ruleset: backend repos `rulesets/story-implementation-workflow.md`,
    the web app `rulesets/frontend-story-workflow.md`. The closio-agent builders keep them; no command adds or changes them.
    A user changes its points for themselves only through their user memory (`flow-memory`), and the plan names which entry
    changed which point. The rules in this file always win over both.
15. Request validation (rule A20, D66): WS1 is a proxy. Its schema file (`schemas/v1/...`) checks only presence (`required`),
    type and format, with messages through `replaceMessagePlaceholders` and keys already in its locale files; a URL ID's format is
    checked in the WS1 controller with the existing `isValidUUID`. WS1 checks no business rule. WS2 checks everything it receives
    again and owns every business-logic check: in the controller when it needs only the request (inline when small; a function in
    the repo's domain utils file when large: over about 30 lines, used by more than one handler, or a nested body), in the service
    when it needs the database. New code only; existing code isn't moved.
16. No redundant code (rule A21, D66): before creating any function, helper, constant or regex, search the repo for one that does
    exactly the same and reuse it. Close but not the same: ask the user (reuse, extend or new). Record each search in the card's
    `develop.md`. Never add another copy of a helper that already exists.
17. WS1 schema keys (rule A22, D66, D85): a WS1 schema holds every key of the card's request and response structure (rule
    24), at every level, with its JSON type: the body under `request`, the query under `queryParameter`, each response under
    `responses.<status>`; `null` in the structure = nullable and not required (e.g. `updated_at`, `updated_by`,
    `updated_by_name`). A field the WS2 code has that the structure doesn't is shown to the user, who decides. Common blocks
    (pagination, the audit fields) come from a shared schema helper, never copied (rule 16).
18. Migration review (rule A23, D66): before any migration or seeder runs, or the user is asked to run one on a server, show the
    files for review (the full up and down, what it changes, the repo, the database its `.env` names), then wait for a separate
    yes. Never run one without it.
19. WS1 login (rule A24, D71): every WS1 login for a check goes to the dev WS1 login URL (`WS1_LOGIN_URL` in
    `config/project-settings.sh`) with the WS1 login saved in the Keychain; `scripts/api-call.sh` does it. The session cookie it
    returns is used for the calls to the WS1 on this Mac (under its own name, else as `closio_session_local`). Never log in on the
    WS1 running on this Mac.
20. Plain words on screen (rule A25, D74): in what you show the user, use plain words. No decision or rule codes (D53, A19,
    R17): they stay in the docs and in the card's `history.md`. Say "the card's folder" (`runs/<CARD-KEY>/`), "the card's saved
    copy" (its branch `runs/<CARD-KEY>`) and the card's state in words ("waiting for the merge"), not the phase names.
21. Rule files and status words stay in sync, in Claude Code and in Codex (build rule R15, steps 6 and 7; D75): any change
    to closio-agent (a command, a script, a setting, a decision, a doc) also updates, in the same step, every line it touches
    in the rule files: `rulesets/`, this file, `docs/agent-rules.md`, `build-memory/project-context.md`,
    `build-memory/rules.md`, `.claude/settings.json` and `.codex/rules/closio-agent.rules`. When something is built or tested
    by the user, update its status everywhere it's named (the command list in `docs/commands.md`, its decision's status line,
    the build plan, the status line of `docs/agent-rules.md`). Say which files were changed and which were only checked.
    `bash scripts/help.sh check` fails while a rule file still calls a built command "coming" or "not built yet".
22. Grilling during a card (rule A26, D76): while a card command runs (flow-start, flow-develop, flow-verify, flow-ac-check,
    flow-push, flow-review, flow-finish, flow-qa), and for any prompt during it that changes the card's plan, code, tests, data, Jira or GitLab,
    ask and decide the way `rulesets/grilling.md` says: look up every fact first and show it as found (never ask what the
    code or the files answer); ask only real decisions, in numbered rounds, each with a recommended answer that "yes"
    accepts; follow-up rounds until nothing is open; sum up what was agreed and wait for the confirmation before changing
    anything; record the decisions as rule 23 says. Short answers, approvals and the user's questions go straight
    through. Safety stops (migrations, test data, commits and push, Jira and GitLab changes) stay their own plain yes/no.
    The user's memory can't soften this rule.
23. Every decision on a card is recorded in full, in one place (rule A27, D77): `runs/<CARD-KEY>/decisions.md`, one numbered
    row per decision, written with `bash scripts/run.sh decide <KEY> "<step>" "<question>" "<decided>" "<who / why>"` the
    moment it's confirmed: every answer to a question, every approval or refusal at a safety stop (the plan, a migration,
    test data, the commits, the push, a Jira move), every memory entry that answered for the user ("memory M2"), every
    change the user asked for during a command. The card's other files (card.md, plan.md, develop.md, verify.md, ship.md)
    only point to it in one line, e.g. "- Error code for a bad status: VALIDATION_ERROR (decision 3)".
24. Request and response structures come only from the user (rule A28, D84): every API request or response structure
    in a plan, the code's expected response, a mock, a test case, a page.route answer or a doc comes from the card's
    `## API request and response` (written from the user's own structure) or from what the user pastes in chat. Never
    write one yourself, never derive one from the code, never fill in a missing field. If it's missing, ask the user for it
    and record their answer (rule 23). Where the code returns something different, show the difference as a "Found" line
    and let the user decide. Error codes and messages still come from the code (rule 10).
25. The card rules (rule A29, D86): `rulesets/card-rules.md` holds the rules to apply at every prompt about a card. The
    card-rules hook (`scripts/card-rules-hook.sh`, set in `.claude/settings.json` and `.codex/hooks.json`) adds it to every
    card command, every prompt that names a card key and every later prompt in that session. Follow it every time; its
    rule 1: every decision on the card goes into `runs/<CARD-KEY>/decisions.md` the moment it's confirmed (rule 23).
    Codex runs the hook only after the user has trusted it once.
26. The card's folder is saved after every reply (rule A30, D87): the auto-save hook (`scripts/card-autosave-hook.sh`, set
    as an end-of-turn hook in `.claude/settings.json` and `.codex/hooks.json`) commits and pushes the card's folder
    (`runs/<CARD-KEY>/`) to its own branch `runs/<CARD-KEY>` at the end of every reply in a session working on a card, when it
    changed: "<KEY>: auto-saved after /flow-<command>" (or "after a reply"). Only that branch: never `main`, never a code repo,
    never forced. The commands' own `run.sh save` steps stay. A failed push shows one warning with its fix; tell the user.
