<!-- Input for F7 (Jira card template): the document the user collected on their personal Claude account and pasted
     into the build chat on 2026-10-17. Kept as given (only this comment added), so later sessions have the source. -->

# Jira card rules: Japfa Closio (project SCRUM)

Collected on 2026-10-17, with your decisions from the same day applied.

**Sources**
- [CLAUDE]: global instructions file `~/.claude/CLAUDE.md`, JIRA sections (QA and code-alignment rules added on 2026-10-13)
- [MEM-backend]: Claude memory for the `japfa/backend` folder (2026-10-02 to 2026-10-17)
- [MEM-Shuru]: Claude memory for the `Shuru` folder (2026-10-14 to 2026-10-15)
- [MEM-incentive]: Claude memory for `nodejs-ws2targetsalesincentive`, the "Establish Good Acceptance Criteria" standard (2026-09-21)
- [MEM-sfa]: Claude memory for `sfa-service-gitlab` (2026-09-29)
- [CHAT date, folder]: your own messages in past Claude Code chats
- [DECIDED 2026-10-17]: your answers on 2026-10-17 to the conflicts found in the first version of this document
- [CARDS]: the latest cards on the board (SCRUM-542 to SCRUM-568, read on 2026-10-17). Only these were used as templates.

**Removed:** partner IDs, session cookies, people's names, private sheet links.

---

## 0. Decisions made on 2026-10-17

| # | Question | Decision |
|---|---|---|
| C1 | File and function names in the card? | Only when necessary (e.g. to pin the exact spot a dev must change), in the text of Scope or Dev notes. Not by default, and never as a "files changed" table. |
| C2 | AC style and heading? | Given / When / Then only. Heading line: `**AC 1 — Title**` (bold, a space after "AC", an em dash). |
| C3 | Can an AC be left to a dev unit test? | No. Every AC must be testable by QA on its own. |
| C4 | WS1 proxy: same card or separate? | Mostly the same card as the WS2 API. |
| C5 | AC self-check table in the card? | No table. The 12-point AC check is done in chat before the draft. |

All five are saved in [MEM-backend].

---

## 1. Card structure

Order used in the newest cards written with Claude (SCRUM-558, 559, 564, 567). [CARDS]

| # | Section | Exact heading | Required? | What goes in it | Source |
|---|---|---|---|---|---|
| 0 | Blocked-by line | `**Blocked by:** SCRUM-559` (first line) | Optional, only when blocked | The card that must land first | [CARDS] 567 |
| 1 | Summary (Jira title field) | (none) | Required | See section 2 | [CARDS] |
| 2 | Context | `## Context` | **Required** | The current behaviour and the gap. What changes. Why: the business reason and what goes wrong without it. What's in and out of scope. Dependencies. Write it in plain language with a short real-life example (e.g. "On Oct 2 the cron calculates September… on Oct 5 an admin deactivates it"). Bold labels used inside: `**Current gap:**`, `**What changes:**` / `**What we're changing:**`, `**Why:**`, `**Already in place today:**`, `**What's missing:**`, `**Not in scope:**` / `**Not in this card:**`, `**Example:**`, `**Good to know for QA:**` | [MEM-backend 2026-10-12], [CHAT 2026-10-12, backend], [CARDS] |
| 3 | Scope | `## Scope`, with one sub-heading per repo: `### WS2 (nodejs-ws2targetsalesincentive)`, `### Web (closio-web-v2)`, `### WS1 (nodejs-ws1closio)` | Optional (when several repos or APIs change) | What changes in each repo, what is "Not changed", the check order. File or function names only when necessary (C1). | [CARDS] 564, 567, [DECIDED 2026-10-17] |
| 4 | Dev notes | `### Dev notes` or `**Dev notes**` | Optional | Notes for the developer: blocking cards, exact message strings, what WS1 does, "the implementation approach is up to the developer" | [CARDS] 559, 564, 567 |
| 5 | Data cleanup | `### Data cleanup (dev runs this once on the dev DB; not a migration)` | Optional | One-off SQL the dev runs | [CARDS] 564 |
| 6 | Error responses | `## Error responses` | Optional | A table of API → error code, plus the JSON error body for a new code | [CARDS] 557 |
| 7 | How QA can test this | `## How QA can test this` | **Required** | See section 5 | [CLAUDE], [CHAT 2026-10-13, backend] |
| 8 | Acceptance Criteria | `## Acceptance Criteria` | **Required, always** | See section 4 | [MEM-backend 2026-10-16], [CHAT 2026-09-23, incentive], [CHAT 2026-10-01, backend], [DECIDED 2026-10-17] |
| 9 | Error reference | `**Error reference**` (a table after the last AC) | Optional | HTTP, error_code, message, details, which AC it belongs to. Says "all existing codes; no new ones" | [CARDS] 564, 567 |
| 10 | Out of Scope | `## Out of Scope` | Optional (in 564 and 567). An older card used "What This Card Deliberately Does NOT Do" | What this card does not do, and where that work goes | [CARDS], [CHAT 2026-09-28, qa-testcraft] |

- **Where the QA section goes:** after Context and before the ACs, or right after the ACs. [CLAUDE] The newest cards put it before the ACs. [CARDS]
- **Not allowed:**
  - "Files changed" or "Files in scope" tables. [MEM-backend 2026-10-12], [CHAT 2026-10-12, backend], [CHAT 2026-10-14, Shuru], [DECIDED 2026-10-17]
  - An "AC self-check" table. [DECIDED 2026-10-17] (It appeared in 564 and 567 before this decision.)
- **Older shapes (not used as the template):**
  - SCRUM-543 (Oct 5): Objective / Implementation Scope / WS1 and WS2 Responsibilities / Method & Path / Path Parameters / Request Body / Validation Rules / Response (200) / ACs / QA / Dependencies / Files
  - SCRUM-555 (Oct 12): Summary / Scope / ACs grouped under the checklist headings
  - SCRUM-556 (Oct 12): Context / Expected Behaviour / ACs / Dependencies / QA Test Data Setup

## 2. Title / summary format

**Rule: Not found.** No instruction in chats, memory or instructions.

Pattern in the newest cards written with Claude: `<Layer> [Business 1] - <what changes> (<repos or APIs>)` [CARDS]
- `Backend Business 1 - Enforce current-month period rules and block activate/deactivate once a month is calculated (CALCULATION_WINDOW_CLOSED) (WS2 + WS1)` (SCRUM-557)
- `Backend Business 1 - Return VALIDATION_ERROR for channel errors on PATCH Incentive Point Slab Set` (SCRUM-559)
- `Backend - Add details.missing_or_invalid to every channel validation error (Slab, Ageing, Target APIs)` (SCRUM-567)
- `Business 1 - Normalise HORE_EAST / HORE_WEST channel to HORE (Backend + Web)` (SCRUM-564)
- `Frontend - Remove mock data and mock fallbacks from Pricing, Notification, Target, Incentive and Users tabs` (SCRUM-549)
- `Backend — PATCH Trader Stock Days Multiplier Config (WS1 + WS2)` (SCRUM-542, uses an em dash)

What the pattern shows:
- The layer comes first: `Backend`, `Frontend`, or `Business 1 - … (Backend + Web)`.
- Repos go at the end in brackets: `(WS2 + WS1)`, `(Backend + Web)`, or the APIs touched.
- If the card is about one error code, the title names it.

Bug cards on the board are a plain sentence describing the problem (SCRUM-562, 563, 565).

## 3. Card types

**Rule for when to pick which type: Not found.** You choose per card:
- "push this to JIRA, a new ticket which is a task" [CHAT 2026-10-01, backend, slab validation changes]
- "create it in JIRA, this will be a story not a task" [CHAT 2026-10-02, backend, new APIs with migration]

What the board shows [CARDS]:

| Type | Seen in | Shape |
|---|---|---|
| Story | 564, 556, 543, 542 | Same sections as Task |
| Task | 567, 559, 558, 557, 555, 549 | Same sections as Story |
| Bug | 563, 565 | Screenshots plus 1–2 lines. No Context, QA or AC sections. A "relates to" link to the story (563 and 565 → SCRUM-524) |
| Spike | Not found | |
| Subtask | Not found | |

Field differences between types: **Not found.**

## 4. Acceptance criteria

**Rules**
- **ACs are in every card, always.** [MEM-backend 2026-10-16], [CHAT 2026-10-01, backend: "where is the acceptance criteria for this ticket"]
- **Every AC uses Given / When / Then, and no other style.** [CHAT 2026-09-23, incentive: "the new way we discussed, which includes given when then"], [CHAT 2026-09-25 and 2026-10-01, backend: "where is the given when then format ?"], [MEM-backend 2026-10-16], [DECIDED 2026-10-17]
  - Given = the starting state (data, config, user, headers)
  - When = the action (API call, upload, job run)
  - Then = the result (HTTP status, error code, message, details, DB change)
- **The heading line is always `**AC 1 — Title**`.** [DECIDED 2026-10-17]
- **Every AC must be testable by QA on its own.** No "not testable by QA yet" ACs, and no dev unit test standing in for a QA check. If something isn't built yet, the QA steps give a workaround. [DECIDED 2026-10-17], [CLAUDE]
- **Write ACs as behaviour QA can see, not technical shorthand.** QA must be able to check them without reading the code. A failing example is "sets isLocked flag on the account service". A passing one is "user can no longer log in once the account is locked". [MEM-incentive 2026-09-21]
- **The 12-point check is done in chat before the draft, not shown in the card.** [MEM-incentive 2026-09-21], [DECIDED 2026-10-17]
  - The points: Business Outcome, Expected Behaviour, Business Rules / Conditions, Positive, Negative / Error, Boundary / Limits, Roles / Permissions, Dependencies / Preconditions, Data Conditions, Failure / Recovery, Expected Result, Testability.
  - Always required: Business Outcome, Expected Behaviour, Positive, Expected Result, Testability.
  - The others are required when their trigger is true:
    - Business Rules: there's a calculation or decision logic.
    - Negative: there's user input, an external call or a failure mode.
    - Boundary: there are ranges, limits, dates or pagination.
    - Roles: the action is limited by role.
    - Dependencies: it needs prior state or data.
    - Data Conditions: the result changes with the data's state.
    - Failure / Recovery: it's multi-step, an integration or async.
  - A point that doesn't apply gets a one-line N/A reason.
- **Boundary ACs state the real numbers and values,** not "within limits". [MEM-incentive]
- **Negative ACs name the exact error,** not "handled" or "validated". [MEM-incentive] The codes, statuses and messages come from the code. [CLAUDE]
- **ACs stay inside this card's scope.** [CHAT 2026-10-02, backend: "the scope of this ticket is only creation of the migration file, table creation in the db and the model file creation thats it"]
- **When removing an AC, renumber the rest and change nothing else.** [CHAT 2026-10-15, closio-web-v2, SCRUM-532]
- **On a minimal edit, don't rewrite existing ACs into Given/When/Then** unless asked. [MEM-backend 2026-10-16]
- For WS1 ACs, see section 7.

**Format** [DECIDED 2026-10-17], [CARDS 549, 564, 567]

```
**AC 1 — Slab: channel required**

* **Given** an incentive point with `requires_channel = true`
* **When** slab POST ... has a group whose `channel` is missing, null, blank or not a string
* **Then** HTTP 400 `VALIDATION_ERROR`, message `...`, `details.missing_or_invalid: [...]`. Nothing is saved.
```

Habits in the newest cards [CARDS]:
- **Extra branches:** `* **And when** …`, `* **And given** …`, or a second When/Then pair. (558, 564)
- **Letter groups when there are many ACs:** `**A. Web**`, `**B. WS2 matching rule**`, … (549, 564)
- **A shared line before the ACs:** `_Shared Given:_ …` (549, 564)
- **A fixed date for date rules:** "Today is assumed to be **Oct 12, 2026**…" (557)
- **Rejections say "Nothing is saved" or "the config is unchanged".** (557, 559, 567)
- **The last AC usually says existing checks and their order are unchanged;** earlier errors still win. (557, 559, 567)
- **Detail level:** each AC names the exact HTTP status, `error_code`, message text and `details`. (564, 567)

## 5. "How QA can test this"

**Rules** [CLAUDE] (from [CHAT 2026-10-13, backend]: "always add a section in the JIRA tickets for the QA in simple language of how we can execute the story - this should be independent from every other story")
- Every card has it, in simple language, as numbered steps (not formal).
- **Setup:** data to seed, SQL to insert, config to create, which environment or headers.
- **Exact steps:** which API to call with what body, or what to check in the DB.
- **What to expect at each step.**
- **QA can test the story without any other story being done.** If a dependency isn't built yet, give a workaround: SQL to seed rows, a manual trigger, or a direct API call. Never write "test after X lands".
- **Every AC is covered by a QA step.** No AC is left to a dev unit test. [DECIDED 2026-10-17]
- **Leave out dev-only steps:** deploying, migrations, restarts.
- **Build the steps from the real endpoints, headers and CSV columns in the code.** [MEM-Shuru 2026-10-14]

**Habits in the newest cards** [CARDS 558, 559, 564, 567]
- **A `**Setup**` block comes first:**
  - the partner to use (the Business 1 partner)
  - headers: `x-client-id`, `x-client-secret`, `X-Partner-Id`, plus `X-User-Id` and `X-User-Name` for creates and updates
  - seeded IDs (e.g. `NT_VOLUME_ACHIEVEMENT` = `10000000-0000-4000-8000-000000000001`)
  - SQL to look up IDs
  - which month to use and why (to avoid `CONFIG_OVERLAP`, `SLABS_NOT_EDITABLE` or `EDIT_NOT_PERMITTED`)
- **Steps are grouped by letter** (`**A. …**`, `**B. …**`), and the numbers carry on across groups (1–19).
- **Every step ends with "Expect …".**
- **JSON bodies and SQL go in code blocks.** A "base body" is defined once and reused.
- **"Call WS2 directly", with the reason,** when WS1 would reject the request earlier. (567)
- **Temporary config changes use SQL, with a revert step right after.** (559, 567)
- **A DB check that the failed calls saved nothing.** (567)
- **Cleanup SQL at the end.** (558)
- **Fake a response with Chrome DevTools "Override content"** when the real API can't return the case. (564)
- **No API?** Test directly on the DB, plus one regression run. (558)
- **A regression group,** e.g. "Nothing else changed" or "Ageing (regression; should already pass)". (559, 567)

## 6. Technical details I include

From [CARDS] unless marked otherwise.

- **API endpoints:** method plus full path in backticks, e.g. `PATCH /api/incentives/v1/incentive-points/:incentive_point_metric_id/slab-configs/:slab_config_id`. Flags like `is_slabs_updated` are named. Request bodies appear as JSON in the QA steps.
- **Headers:**
  - S2S headers are listed in the QA setup.
  - The WS1 → WS2 contract is covered in the ACs: params plus S2S headers plus `X-Partner-Id`, `X-User-Id`, `X-User-Name`. [MEM-backend, SCRUM-518 notes]
- **Response shape:**
  - Older cards had a `## Response (200)` section (543).
  - The newest cards put response values in the ACs and the QA expectations.
- **Errors:**
  - Each error has an HTTP status, `error_code`, the exact message and the `details` shape (e.g. `details.missing_or_invalid: ["groups[<i>].channel"]`, `details.closed_months`).
  - An Error reference table, and the JSON body for a new code (557).
- **Validation order:** "Check order is unchanged everywhere. Earlier errors still win:" followed by the earlier codes (567), plus an AC for the order (557, 559).
- **Database:**
  - table and column names, constraints (e.g. `chk_ire_role`), seeded IDs
  - migration ACs: "runs safely on existing data" and "can be rolled back" (558)
  - one-off cleanup SQL (564)
- **Config:** config flags (e.g. `requires_channel`) and the periods to use.
- **Queues:** **Not found** as a rule. Webhook processing is tested by checking the processed tables "after a few seconds". (564)
- **Repos:**
  - The Scope section names each repo: `nodejs-ws2targetsalesincentive`, `nodejs-ws1closio`, `closio-web-v2`.
  - It says "WS1 is unchanged" when that's true. (564, 567)
- **File and function names:** only when necessary, in the text of Scope or Dev notes, never as a table. [DECIDED 2026-10-17]
- **WS1 proxy:** a new or changed WS2 API's WS1 proxy and its WS1 ACs usually go in the same card, with "(WS2 + WS1)" in the title. A separate WS1 card is the exception. [CHAT 2026-10-02, backend], [DECIDED 2026-10-17]
- **Dependencies:**
  - the `**Blocked by:**` line (567)
  - Dev notes naming related cards (SCRUM-521, 538, 564)
  - "Not in this card" pointing to the card or doc section that covers it (557, 558: "§14")
  - Jira "relates to" links (559 → 538)
- **Translations:** check that `nodejs-ws1closio/locales/{en,id}` has the message. The exact message string matters, e.g. "no trailing space". [MEM-Shuru 2026-10-15], [CARDS 567]
- **Dev-only module (as of 2026-10-14):** prefer a data fix or deleting dev rows over legacy-compatibility code. [MEM-Shuru]
- **After development:** you attach a working WS1 curl to the card. [CHAT 2026-10-05 and 2026-10-10, backend]

## 7. Code-alignment rules

- **Read the code before drafting or editing:** controllers, services, utils, constants, middlewares and migrations, in every repo involved (WS1 and WS2). [CLAUDE], [CHAT 2026-10-13, backend: "you always have to look into the code as well to maintain the similarity with the code itself… Make it a strict rule"]
- **Re-read it every time, right before drafting,** even if you read it earlier in the chat. Cover WS2, WS1 (routes, schemas, proxying) and the web app. [MEM-Shuru 2026-10-14]
- **Do this before asking open questions,** so the questions rest on facts. [MEM-Shuru 2026-10-15]
- **Mirror what's there:**
  - error codes, HTTP statuses, messages and error-body shapes
  - field, column, header and variable names
  - validation rules, check order and edit-case rules
  - the closest sibling module's pattern
  [CLAUDE]
- **Never invent anything new:** no error codes, fields, columns, variables, statuses or constants that aren't in the code. If one is truly needed, ask, give the reason, and get approval. [CLAUDE], [CHAT 2026-10-13, backend]
- **If the code and a card or doc disagree,** point it out and use what the code does. [CLAUDE] Plan docs are "not the source of truth". [CHAT 2026-09-29, sfa]
- **Align ACs with both the WS2 and WS1 code,** including rules that already exist (e.g. the block on past-month configs). [CHAT 2026-10-12, backend]
- **Sync all error messages with the existing implementation.** [CHAT 2026-10-05, backend]
- **For error or validation cards, also check:** [MEM-Shuru 2026-10-15]
  - **How WS1 relays WS2 errors.** The incentives controllers rebuild errors with `createError` (translated message plus `upstream_*` keys in `details`). The target-sales controllers pass the body through.
  - **The WS1 locale files.**
  - **The error shape each sibling API really uses.** Count them, and never call one "the standard" without checking.
  - **Related To Do / In Development cards** that touch the same code.
- **WS1 rules** [MEM-backend 2026-10-05], [CHAT 2026-10-05, backend: "i dont want any validation to happen in ws1… use the codes which are available in the ws1"]:

| Scenario | Code | HTTP | Message |
|---|---|---|---|
| Missing or invalid mobile token | `INVALID_TOKEN` | 401 | "invalid or expired token" |
| Web session expired | `SESSION_EXPIRED` | 401 | "your session has expired" |
| No partner_id | `PARTNER_ID_MISSING` | 400 | "X-Partner-Id header is required." |
| Bad UUID path param | `VALIDATION_ERROR` | 400 | "[param] must be a valid UUID" |
| AJV envelope check fails | `GENERAL_ERROR` | 400 | the AJV message ("general error from ws1 always") |
| WS2 success response is malformed | `INTERNAL_SERVER_ERROR` | 500 | "Something went wrong. Please try again later." |
| WS2 unreachable or timed out | `UPSTREAM_REQUEST_FAILED` | 502 | "Failed to reach Target Sales WS2" |

  - **WS1 does no input validation.** It only checks UUID path params and that AJV required fields are present.
  - **WS1 errors never include `details.missing_or_invalid`.** That's WS2 only.
  - **WS2 errors pass through WS1 unchanged.**
  - **WS2 credential errors:** `MISSING_CLIENT_CREDENTIALS` and `INVALID_CLIENT_AUTH`, both 401. `SIGNATURE_INVALID`, `TOKEN_INVALID` and `VALID_PERIOD_RANGE_INVALID` don't exist.

## 8. The process I follow with you

1. **Card before code.** After a design or plan, create the card first. Only write code when you say to implement. [MEM-backend, undated]
2. **Re-read the code** (section 7).
3. **Ask the open questions first, on their own, and wait.** Keep them short, each with what I found and a recommended default. Never post a full draft with questions at the end. Never put "Assumption: … confirm before development" in a card. [MEM-backend 2026-10-12], [MEM-Shuru 2026-10-15], [CHAT 2026-10-12, backend], [CHAT 2026-10-15, Shuru]
4. **Run the 12-point AC check in chat** (section 4). [DECIDED 2026-10-17]
5. **Post the full draft in chat:** summary, description, ACs. "Let's create the card" or "fix this" still means draft first. [CLAUDE], [CHAT 2026-09-29, sfa], [CHAT 2026-10-12, backend], [CHAT 2026-10-14, Shuru], [CHAT 2026-10-15, closio-web-v2]
6. **If your replies change anything, post the full final draft again.** Wait for an explicit "update it" or "go ahead". Answering questions or approving single points is not approval. [CLAUDE]
7. **Only then create or edit the card in Jira.**

Also:
- **Change only what was asked,** plus lines that would contradict it. Keep the rest. Don't widen into queries, ACs or logic, or ask follow-ups about them. [CLAUDE], [MEM-backend 2026-10-12]
- **Keep your decisions when rewriting.** Showing trade-offs is not permission to change something. [MEM-sfa 2026-09-29]
- **Only include the issues you stated,** not extra ones I found. [CHAT 2026-09-23, incentive]
- **Show the changes in chat before rewriting a card.** [CHAT 2026-09-29, sfa]
- **Make all requested changes in one go, without missing details.** [CHAT 2026-09-29, sfa]
- **When mapping a plan doc to Jira,** use one row per doc § in doc order, each with a status. Never use my own numbering. [MEM-backend 2026-10-12]
- **Overwrite a dummy or existing card when told,** e.g. "update already dummy card - scrum-533", "override SCRUM-549". [CHAT 2026-09-29, sfa], [CHAT 2026-10-12, closio-web-v2]
- **The card is self-contained:** "what you need to know — no other ticket required". [CHAT 2026-09-21, incentive]
- **Output is ready to copy and paste into Jira.** [CHAT 2026-09-21, incentive]

## 9. Jira fields and conventions

- **Site:** productclosio.atlassian.net, project SCRUM. [MEM-sfa]
- **Epic / parent:** SCRUM-355 "Incentive Engine" on 22 of the 25 latest cards. [CARDS], [MEM-sfa]
- **Story points ("Story point estimate"):**
  - Set on a few cards (564: 4, 543: 4, 549: 3, 566: 1.5) and empty on most Claude-drafted tasks.
  - Asked whether to set story points, an epic or a sprint for SCRUM-549, you said "no". [CHAT 2026-10-12, closio-web-v2]
  - Points measure complexity: AI cuts the time, not the complexity. [CHAT 2026-10-01, backend, estimation]
- **Sprint:** Sprint 28 on some cards. No rule for setting it. [CARDS]
- **Labels:** only `frontend` and `tech-debt`, on SCRUM-549. **Rule: Not found.**
- **Components:** none used. **Not found.**
- **Priority:** all Medium. **Rule: Not found.**
- **Assignee:** **Not found** as a card rule. (In the AI agent design, the agent assigns the card to itself when it picks it up.) [CHAT 2026-10-09, AI Pipeline]
- **Statuses:**
  - Flow: To Do → In Development → Code Review → Ready for Test. [CHAT 2026-10-09, AI Pipeline]
  - Backlog also exists. QA - Passed is used. [CARDS]
  - Blocked is only for QA. [CHAT 2026-10-09, AI Pipeline: "that is just for the QA's"]
- **Linking:**
  - Link related cards when updating them: "update both cards and add the links". [CHAT 2026-10-13, backend]
  - "relates to" links are used. [CARDS]
  - "Blocked by" is written in the description. (567)
- **Formatting:** the description must display properly in Jira. A card pushed with literal `\n` text was "not properly formatted". [CHAT 2026-09-29, sfa]

## 10. "Ready" checklist (yes / no)

- [ ] Was the code re-read in every repo involved, right before drafting?
- [ ] Were the open questions asked and answered before the draft?
- [ ] Was the 12-point AC check done in chat, with an N/A reason for each point that doesn't apply?
- [ ] Is the card free of "Assumption: …" lines and unfilled placeholders (e.g. ⟦…⟧)? [CHAT 2026-09-28, qa-testcraft: "go ahead and fill the placeholders"]
- [ ] Was the full final draft shown in chat, with an explicit "go ahead" or "update it"?
- [ ] Did you pick the card type (Story or Task)?
- [ ] Does Context cover the current behaviour and gap, what changes, why, in and out of scope, and dependencies?
- [ ] Is Context in plain language, not formal?
- [ ] Is there no "files changed" table, and are file or function names used only where necessary?
- [ ] Is there no AC self-check table?
- [ ] Does every error code, status, message, field, column and header exist in the code, or was it approved as new?
- [ ] Do WS1 ACs use only real WS1 codes, with no validation in WS1, no `details.missing_or_invalid`, and 502 for unreachable?
- [ ] If a WS2 API is reached through WS1, is the WS1 proxy work in the same card (unless agreed otherwise)?
- [ ] Is the check order stated (earlier errors still win)?
- [ ] Is there an Acceptance Criteria section, with every AC in Given / When / Then under a `**AC 1 — Title**` heading?
- [ ] Does every "Then" name the exact HTTP status, error_code, message, details or DB result?
- [ ] Do all ACs stay inside this card's scope?
- [ ] Do boundary ACs state the real values?
- [ ] Is there a "How QA can test this" section with simple numbered steps?
- [ ] Does the QA setup list the partner, headers, IDs, lookup SQL and which period to use?
- [ ] Does every QA step have an expected result?
- [ ] Is every AC covered by a QA step, with none left to a dev unit test?
- [ ] Can QA run it without any other story being done (with a workaround given)?
- [ ] Are there no deploy, migrate or restart steps in the QA section?
- [ ] Does every temporary DB change in the QA steps have a revert step?
- [ ] Are blocked-by and related cards named in the card and linked in Jira?
- [ ] Is out-of-scope work listed?
- [ ] Is the card free of secrets (tokens, cookies, passwords)?
- [ ] Does the description display correctly in Jira (no literal `\n`)?

## 11. Things to avoid (mistakes you corrected)

| Mistake | Your correction | When / where |
|---|---|---|
| Created a card directly, with no draft | "who told you to directly create the story, i wanted a draft first, always create a draft before creating it directly" | 2026-10-12, backend |
| Updated a card directly again | "phele draft dena tha na, kisne kaha tha seedha update karne ko" ("you should have given a draft first; who told you to update directly?") | 2026-10-15, closio-web-v2 (SCRUM-532) |
| Put an assumption in the card instead of asking | "you didn't even asked questions from me… you just created a card with assumption, ask questions before drafting anything should be the key rule" | 2026-10-12, backend |
| Posted a full draft with questions at the end | "always give open questions first always, dont output the entire story and then give me open questions" | 2026-10-15, Shuru |
| Asked questions before checking the WS1 code | You called it out | 2026-10-15, Shuru [MEM-Shuru] |
| Put a files-changed table in the card | "remove the files changed from the card"; "remove the file tables like # File Change" | 2026-10-12, backend; 2026-10-14, Shuru |
| Left an AC to a dev unit test ("Not testable by QA yet") | "all the AC's should be independently testable by the QA's" | 2026-10-17, backend (about SCRUM-558) |
| Wrote the context too formally | "you dont have to make it this formal, i want the description / context in such a way that the user can relate to it easily" | 2026-10-12, backend |
| Over-engineered a simple column add | "You are over engineering right now dont do that at all" | 2026-10-12, backend (SCRUM-533/534) |
| Used invented WS1 codes and put validation in WS1 | "i dont want any validation to happen in ws1 and also the error code like SIGNATURE_INVALID is not present" | 2026-10-05, backend (SCRUM-516 to 519) |
| Put `details.missing_or_invalid` on a WS1 error | "This missing_or_invalid list will not be possible from ws1 since it returns general error" | 2026-10-05, backend |
| Wrote ACs for work in other cards | "thats a part of other tickets, the scope of this ticket is only…" | 2026-10-02, backend |
| Left out ACs, or didn't use Given/When/Then | "where is the acceptance criteria for this ticket"; "where is the given when then format ?" | 2026-10-01, backend |
| Added issues you didn't state | "in the card, only include the issue what i stated dont include what you mentioned" | 2026-09-23, incentive |
| Changed a decision silently in a rewrite | Moved an insert from "after Gate 2" to "before Gate 1" without approval | 2026-09-29, sfa [MEM-sfa] |
| Missed details across updates | "make changes in one go and not miss such important details" | 2026-09-29, sfa |
| Pushed a badly formatted card | "the last card is not properly formatted" | 2026-09-29, sfa |
| Wrote an AC that didn't make sense | "are you even reading what you are presenting in AC-8" | 2026-10-15, closio-web-v2 (SCRUM-532) |
| Touched other ACs when asked to remove one | "strictly just remove this AC-6 from the card and renumber all the AC's thats all don't touch anything else" | 2026-10-15, closio-web-v2 |
| Renumbered plan-doc sections | You couldn't trace doc §4–§8 | 2026-10-12, backend [MEM-backend] |

## 12. Examples

Both are real cards. They were edited only to match the decisions above; the edits are listed under each title.

### Example A: SCRUM-559 (Task, compact)

Edits: AC headings changed from `**AC1: …**` to `**AC 1 — …**`. The partner ID is replaced.

**Summary:** Backend Business 1 - Return VALIDATION_ERROR for channel errors on PATCH Incentive Point Slab Set
**Link:** relates to SCRUM-538

## Context

**Current gap:** POST and PATCH Incentive Point Slab Set return different error codes for the same channel mistake.

* **POST** `/api/incentives/v1/incentive-points/:incentive_point_metric_id/slab-configs` returns `400 VALIDATION_ERROR`.
* **PATCH** `/api/incentives/v1/incentive-points/:incentive_point_metric_id/slab-configs/:slab_config_id` (with `is_slabs_updated = true`) returns `400 INVALID_CHANNEL`.

The messages are already the same on both endpoints:

* `channel is required for this incentive point`: when the incentive point has `requires_channel = true` and a group's `channel` is missing, null, not a string or blank.
* `channel must not be provided for this incentive point`: when the incentive point has `requires_channel = false` and a group includes a `channel` key.

**What changes:** PATCH returns `VALIDATION_ERROR` for both cases, the same as POST. The messages stay the same. After this change, neither endpoint returns `INVALID_CHANNEL`. This replaces the `INVALID_CHANNEL` rows in SCRUM-484's validation rules and error table.

**Why:** the frontend and QA should see one error code for a channel mistake, whichever endpoint the user saves from. Channel whitelist errors (SCRUM-538) will also use `VALIDATION_ERROR`.

**Not in scope:** no other validation, check order, message or response shape changes. The implementation approach is up to the developer.

## How QA can test this

Use the Business 1 partner (`<B1_PARTNER_ID>`) with the usual headers/token for the incentive APIs. Seeded incentive points:

* `NT_VOLUME_ACHIEVEMENT`, id `10000000-0000-4000-8000-000000000001` (`requires_channel = true`)
* `TR_STOCK_BY_PRODUCT`, id `10000000-0000-4000-8000-000000000006`

The config must be in a future period. Otherwise PATCH stops earlier with `SLABS_NOT_EDITABLE` or `EDIT_NOT_PERMITTED` and never reaches the channel check. Pick a month with no active config for that incentive point; otherwise POST returns `CONFIG_OVERLAP`. The steps below use `2026-12`.

**A. Channel missing on a channel-required incentive point**

Body used in step 1 (call it the _base body_):

```json
{
  "valid_from": "2026-12",
  "valid_to": "2026-12",
  "groups": [
    { "channel": "CATERING", "salesperson_type": "NON_TRADER", "level": 1,
      "slabs": [ { "band_order": 1, "operator": ">=", "value": 90, "points": 1 } ] }
  ]
}
```

1. Create a config: `POST /api/incentives/v1/incentive-points/10000000-0000-4000-8000-000000000001/slab-configs` with the base body. Expect `201` with a `slab_config_id`. Note it down.
2. `PATCH /api/incentives/v1/incentive-points/10000000-0000-4000-8000-000000000001/slab-configs/<slab_config_id>` with `"is_config_updated": false, "is_slabs_updated": true` and the base body's group but **without** the `channel` key. Expect `400`, `error_code: "VALIDATION_ERROR"`, message `channel is required for this incentive point`.
3. Repeat step 2 with `"channel": ""`, then `"channel": "   "`, then `"channel": null`. Expect the same 400 `VALIDATION_ERROR` each time.
4. Call `GET /api/incentives/v1/incentive-points/10000000-0000-4000-8000-000000000001/slab-configs/<slab_config_id>`. Expect the slabs from step 1, unchanged.
5. Send the base body to POST again, but without the `channel` key. Expect the same 400 `VALIDATION_ERROR` and message as PATCH. The channel check runs before the overlap check, so reusing `2026-12` is fine here.

**B. Channel sent on an incentive point that does not take one**

If `TR_STOCK_BY_PRODUCT` already has `requires_channel = true` (after SCRUM-538), switch it off for this test and switch it back at the end:

```sql
UPDATE incentive_point_metrics SET requires_channel = false
WHERE id = '10000000-0000-4000-8000-000000000006';
```

6. Create a config: `POST /api/incentives/v1/incentive-points/10000000-0000-4000-8000-000000000006/slab-configs` with `valid_from`/`valid_to` `2026-12` and a group `{ "salesperson_type": "TRADER", "level": 1, "slabs": [ { "band_order": 1, "operator": ">=", "value": 50, "points": 5 } ] }` (no `channel` key). Expect `201` and note the `slab_config_id`.
7. PATCH that config with `"is_config_updated": false, "is_slabs_updated": true` and the same group plus `"channel": "TRADER"`. Expect `400`, `error_code: "VALIDATION_ERROR"`, message `channel must not be provided for this incentive point`.
8. Repeat step 7 with `"channel": null`. Expect the same error: the key being present is enough.
9. If you ran the SQL above, revert it:

```sql
UPDATE incentive_point_metrics SET requires_channel = true
WHERE id = '10000000-0000-4000-8000-000000000006';
```

**C. Nothing else changed**

10. PATCH the config from step 1 with `"is_config_updated": true, "is_slabs_updated": false, "updated_valid_from": "2026-12", "updated_valid_to": "2026-12"` and no `groups`. Expect `200`: the channel is not checked when slabs are not being updated.
11. PATCH the config from step 1 with `"is_slabs_updated": true`, a valid `channel` (`CATERING`) and new slabs. Expect `200`, and the response groups show the new slabs.
12. Check every response above: `INVALID_CHANNEL` should never appear.

## Acceptance Criteria

**AC 1 — Missing channel on PATCH returns VALIDATION_ERROR**

* **Given** an incentive point with `requires_channel = true` and a slab config in a future period
* **When** PATCH is called with `is_slabs_updated = true` and a group whose `channel` is missing, null, not a string or blank
* **Then** the API returns `400` with `error_code: "VALIDATION_ERROR"` and message `channel is required for this incentive point`, and no slab rows are changed

**AC 2 — Channel provided on PATCH when not applicable returns VALIDATION_ERROR**

* **Given** an incentive point with `requires_channel = false` and a slab config in a future period
* **When** PATCH is called with `is_slabs_updated = true` and any group includes a `channel` key (any value, including null)
* **Then** the API returns `400` with `error_code: "VALIDATION_ERROR"` and message `channel must not be provided for this incentive point`, and no slab rows are changed

**AC 3 — POST and PATCH match**

* **Given** the same invalid `groups` payload
* **When** it is sent to POST and to PATCH (`is_slabs_updated = true`)
* **Then** both return the same `400 VALIDATION_ERROR` and the same message

**AC 4 — INVALID_CHANNEL is no longer returned**

* **Given** any channel mistake on POST or PATCH Incentive Point Slab Set
* **When** the request is rejected
* **Then** `error_code` is never `INVALID_CHANNEL`

**AC 5 — Channel not checked when slabs are not updated**

* **Given** a PATCH with `is_slabs_updated = false`
* **When** the request is processed
* **Then** no channel check runs and the request behaves exactly as today

**AC 6 — Existing checks and their order are unchanged**

* **Given** a PATCH that would also fail an earlier check (`INCENTIVE_POINT_NOT_FOUND`, `SLAB_SET_NOT_FOUND`, `EDIT_NOT_PERMITTED`, `SLABS_NOT_EDITABLE`, `VALID_FROM_NOT_EDITABLE`, `SLAB_NOT_ALLOWED_FOR_DEDUCTION_COMPONENT`)
* **When** the request is processed
* **Then** that earlier error is returned, as today, and the rest of the validation behaves as it does now

---

### Example B: SCRUM-567 (Task, every section of the newest template)

Edits:
- The AC self-check table is removed (C5).
- The "Where" column with file and function names is removed from the first Context table (C1: names go in the text, and only when needed). The Scope and Dev notes still name files where the dev needs the exact spot.
- The partner ID is replaced.

**Summary:** Backend - Add details.missing_or_invalid to every channel validation error (Slab, Ageing, Target APIs)

**Blocked by:** SCRUM-559

## Context

**Current gap:** the same channel mistake (missing, null, blank or not a string) gets a different error shape depending on the API. QA found this while testing SCRUM-564.

| API | Today |
| --- | --- |
| Slab POST `/api/incentives/v1/incentive-points/:incentive_point_metric_id/slab-configs` | `400 VALIDATION_ERROR`, message `channel is required for this incentive point` / `channel must not be provided for this incentive point`, **no** `details` |
| Slab PATCH `.../slab-configs/:slab_config_id` (`is_slabs_updated: true`) | `400 INVALID_CHANNEL`, same messages, no `details`. **SCRUM-559 changes the code to** `VALIDATION_ERROR`. |
| Ageing POST `/api/incentives/v1/ageing-deduction-configs` (PATCH: SCRUM-521) | `400 VALIDATION_ERROR`, message `Request validation failed`, `details.missing_or_invalid: ["channels[<i>].channel"]` |
| Target create/update `/api/target/v1/target-type/:targetTypeId/target-value[/:recordId]` (T1/T2) | Missing, null or blank: `400 MISSING_REQUIRED_DIMENSIONS`, `details.missing_fields: ["channel"]`. **Not a string: no check, so it ends in** `500 INTERNAL_ERROR` ("Could not validate target uniqueness") |

**What changes:** every channel validation error on these APIs returns `400 VALIDATION_ERROR` with `details.missing_or_invalid` naming the channel field. Each API **keeps its own existing message** and its own field naming:

| API | message (unchanged, already translated in WS1) | `details.missing_or_invalid` |
| --- | --- | --- |
| Slab POST and PATCH | `channel is required for this incentive point` / `channel must not be provided for this incentive point` | `["groups[<i>].channel"]` (new; `<i>` = index of the failing group in the request) |
| Ageing POST and PATCH | `Request validation failed` | `["channels[<i>].channel"]` (no change) |
| Target create/update (T1/T2), channel not a string | `Request body validation failed` | `["channel"]` (new check) |

The SCRUM-538 channel whitelist error (not built yet) has already been updated to carry `missing_or_invalid: ["groups[<i>].channel"]` too.

**Why:** the Web and QA can read the failing field the same way on every API, without depending on the message text.

## Scope (WS2 only)

**1. Slabs** (`incentivePointSlabUtils.js`)

* `validateAndNormalizeGroups`, used by POST and PATCH: both channel errors keep their code and message and add `details: { missing_or_invalid: ["groups[<i>].channel"] }`. The two errors are:
    * `requires_channel = true` with a missing, null, non-string or blank channel
    * `requires_channel = false` with a `channel` key present
* `assertGroupsChannelUsage` (PATCH only): after SCRUM-559 it returns `VALIDATION_ERROR`; this card adds the same `details`. The developer may instead remove it and rely on `validateAndNormalizeGroups`, as long as the response and check order stay the same.

**2. Ageing:** no code change. It already matches. Listed here for regression only.

**3. Targets** (`src/services/targets/targetTypeValuesService.js`, `createTargetValue` and `updateTargetValue`)

* Add a check right after `validateRequiredDimensions`, only for target types whose `requiredDataFields` include `channel` (T1/T2): if `data.channel` is present but not a string, return `400 VALIDATION_ERROR`, message `Request body validation failed`, `details: { missing_or_invalid: ["channel"] }`.
* It runs before the duplicate check, so the 500 goes away.
* Missing, null or blank channel still returns `MISSING_REQUIRED_DIMENSIONS`, unchanged.
* Target types without `channel` (T3–T5) ignore `data.channel`, as today.

**Check order is unchanged everywhere.** Earlier errors still win:

* slab PATCH: `INCENTIVE_POINT_NOT_FOUND`, `SLAB_SET_NOT_FOUND`, `EDIT_NOT_PERMITTED`, `SLABS_NOT_EDITABLE`, `VALID_FROM_NOT_EDITABLE`, `SLAB_NOT_ALLOWED_FOR_DEDUCTION_COMPONENT`
* targets: target type, date and record-not-found errors

A slab PATCH with `is_slabs_updated: false` never checks the channel.

**Dev notes**

* **Blocked by SCRUM-559** (slab PATCH `INVALID_CHANNEL` → `VALIDATION_ERROR`). Build on top of it, or on the same branch if it isn't merged yet.
* **Targets message:** use exactly `Request body validation failed` with **no trailing space**. That is the key WS1 translates (`locales/id/target-sales/messages.json`). The existing controller message `'Request body validation failed '` (`targetTypeValuesController.js:214`) has a trailing space and isn't touched by this card.
* **WS1 is unchanged.**
    * Incentive errors are rebuilt by `createError`: the message is translated and `upstream_*` keys are added to `details`.
    * Target errors are passed through with only the message translated.
    * `missing_or_invalid` reaches Closio in both cases.
    * WS1's slab schemas only allow `string`/`null` for `channel`, so through WS1 a number is rejected earlier with `GENERAL_ERROR`. That's why QA tests on WS2 directly.
* SCRUM-564's HORE normalising is unaffected, because the channel checks run before or on the raw value exactly as today.

## How QA can test this

**Setup**

* Call **WS2 directly**, using partner `<B1_PARTNER_ID>`.
* Headers: `x-client-id`, `x-client-secret`, `X-Partner-Id`, `X-User-Id`, `X-User-Name`.
* Incentive points: `NT_VOLUME_ACHIEVEMENT` = `10000000-0000-4000-8000-000000000001` (`requires_channel = true`), `TR_STOCK_BY_PRODUCT` = `10000000-0000-4000-8000-000000000006`.
* Use future months with no active config for that incentive point (e.g. `2027-04` onwards). Otherwise POST returns `CONFIG_OVERLAP`, and PATCH stops earlier with `SLABS_NOT_EDITABLE` / `EDIT_NOT_PERMITTED`.
* Target type ids:

```sql
SELECT id, table_name FROM target_types
WHERE table_name IN ('target_sales_volume_all_customers','target_sales_volume_new_customers','target_call_plan');
```

* Pick a level-1 salesperson id (`<SP_ID>`).

**A. Slab POST, channel required** (`NT_VOLUME_ACHIEVEMENT`)

Base group: `{ "channel": "CATERING", "salesperson_type": "NON_TRADER", "level": 1, "slabs": [ { "band_order": 1, "operator": ">=", "value": 90, "points": 1 } ] }`

1. POST with the base group but no `channel` key. Expect `400`, `error_code: "VALIDATION_ERROR"`, message `channel is required for this incentive point`, `details.missing_or_invalid: ["groups[0].channel"]`.
2. Repeat with `"channel": null`, `""`, `"   "`, `123`, `true`, `[]`, `{}`. Expect the same each time.
3. Send two groups (`level` 1 and 2), where only the second has `"channel": 123`. Expect `details.missing_or_invalid: ["groups[1].channel"]`.
4. POST with the valid base group. Expect `201`. Note the `slab_config_id`.

**B. Slab PATCH** (the config from step 4, `"is_config_updated": false, "is_slabs_updated": true`)

5. Repeat steps 1–3 as PATCH bodies. Expect the same responses. `INVALID_CHANNEL` never appears.
6. PATCH with `"is_config_updated": true, "is_slabs_updated": false` and the same period (`updated_valid_from` / `updated_valid_to`). Expect `200`: the channel isn't checked.
7. `GET .../slab-configs/<slab_config_id>`. Expect the slabs from step 4, unchanged.

**C. Slab, channel not allowed** (`TR_STOCK_BY_PRODUCT`)

8. If SCRUM-538 has already flipped Trader metrics, switch it back for this test:

```sql
UPDATE incentive_point_metrics SET requires_channel = false WHERE id = '10000000-0000-4000-8000-000000000006';
```

9. POST with `{ "channel": "TRADER", "salesperson_type": "TRADER", "level": 1, "slabs": [ { "band_order": 1, "operator": ">=", "value": 50, "points": 5 } ] }`. Expect `400 VALIDATION_ERROR`, message `channel must not be provided for this incentive point`, `details.missing_or_invalid: ["groups[0].channel"]`. Repeat with `"channel": null` and expect the same; the key being present is enough.
10. POST the same group without `channel`. Expect `201`. PATCH that config (`"is_slabs_updated": true`) with `"channel": "TRADER"`. Expect the same error as step 9.
11. If you ran step 8, revert it:

```sql
UPDATE incentive_point_metrics SET requires_channel = true WHERE id = '10000000-0000-4000-8000-000000000006';
```

**D. Ageing (regression; should already pass)**

12. `POST /api/incentives/v1/ageing-deduction-configs` (free period) with `channels[0].channel` set to `123`, `null`, `""`, missing, and a 101-character string. Expect `400 VALIDATION_ERROR`, message `Request validation failed`, `details.missing_or_invalid: ["channels[0].channel"]` each time.

**E. Targets** (T1, current month)

13. `POST /api/target/v1/target-type/<T1_ID>/target-value` with `{ "start_date": "2026-10-01", "end_date": "2026-10-31", "target_value": 1000, "data": { "salesperson_id": "<SP_ID>", "salesperson_name": "QA SP", "channel": 123 } }`. Expect `400 VALIDATION_ERROR`, message `Request body validation failed`, `details.missing_or_invalid: ["channel"]` (not 500).
14. Repeat step 13 with `true`, `{}` and `["HORE"]`. Expect the same.
15. Repeat step 13 with no `channel`, then `""`. Expect `400 MISSING_REQUIRED_DIMENSIONS` with `details.missing_fields: ["channel"]` (unchanged).
16. Create a valid T1 target with `"channel": "QSR"`. Expect `201`. PATCH it (`/target-value/<id>`) with the same body and `"channel": 123`. Expect the step 13 error. Then check the original row is still `ACTIVE`:

```sql
SELECT status FROM target_sales_volume_all_customers WHERE id = '<id>';
```

17. Repeat step 13 on `<T2_ID>` with another salesperson. Expect the same.
18. On the `target_call_plan` type, POST a valid body for that type (its own `salesperson_type_id` / `salesperson_type_name`) plus `"channel": 123` inside `data`. Expect the same result as without `channel` (it's ignored).
19. Nothing was saved by the failed calls:

```sql
SELECT count(*) FROM target_sales_volume_all_customers
WHERE salesperson_id = '<SP_ID>' AND created_at > now() - interval '1 hour';
```

Expect only the row(s) from step 16.

## Acceptance Criteria

**AC 1 — Slab: channel required**

* **Given** an incentive point with `requires_channel = true`
* **When** slab POST, or PATCH with `is_slabs_updated: true`, has a group whose `channel` is missing, null, blank or not a string
* **Then** HTTP 400 `VALIDATION_ERROR`, message `channel is required for this incentive point`, `details.missing_or_invalid: ["groups[<i>].channel"]` for the first failing group. Nothing is saved.

**AC 2 — Slab: channel not allowed**

* **Given** an incentive point with `requires_channel = false`
* **When** any group has a `channel` key (any value, including null)
* **Then** HTTP 400 `VALIDATION_ERROR`, message `channel must not be provided for this incentive point`, `details.missing_or_invalid: ["groups[<i>].channel"]`. Nothing is saved.

**AC 3 — Slab: no INVALID_CHANNEL**

* **Given** any channel mistake on slab POST or PATCH
* **When** it is rejected
* **Then** `error_code` is never `INVALID_CHANNEL`.

**AC 4 — Ageing unchanged**

* **Given** ageing POST (or PATCH, SCRUM-521)
* **When** a channel is missing, null, blank, not a string or longer than 100 characters
* **Then** HTTP 400 `VALIDATION_ERROR`, message `Request validation failed`, `details.missing_or_invalid: ["channels[<i>].channel"]`, as today.

**AC 5 — Target: channel not a string**

* **Given** a T1 or T2 target type
* **When** create or update has `data.channel` present but not a string
* **Then** HTTP 400 `VALIDATION_ERROR`, message `Request body validation failed`, `details.missing_or_invalid: ["channel"]`. No 500. Nothing is saved, and on update the existing row stays `ACTIVE`.

**AC 6 — Target: channel missing (unchanged)**

* **Given** a T1 or T2 target type
* **When** `data.channel` is missing, null or blank
* **Then** HTTP 400 `MISSING_REQUIRED_DIMENSIONS` with `details.missing_fields` including `channel`, as today.

**AC 7 — Target types without channel**

* **Given** a target type without `channel` in its required fields (T3–T5)
* **When** `data.channel` is sent with any value
* **Then** it is ignored, as today.

**AC 8 — Order and everything else unchanged**

* **Given** a request that would also fail an earlier check
* **When** it is processed
* **Then** that earlier error is returned, as today. A slab PATCH with `is_slabs_updated: false` never checks the channel. Valid channels behave exactly as today, including SCRUM-564's HORE normalising.

**Error reference** (existing codes and messages; only `details` is added)

| HTTP | error_code | message | details | Trigger |
| --- | --- | --- | --- | --- |
| 400 | `VALIDATION_ERROR` | channel is required for this incentive point | `missing_or_invalid: ["groups[<i>].channel"]` | AC 1 |
| 400 | `VALIDATION_ERROR` | channel must not be provided for this incentive point | `missing_or_invalid: ["groups[<i>].channel"]` | AC 2 |
| 400 | `VALIDATION_ERROR` | Request validation failed | `missing_or_invalid: ["channels[<i>].channel"]` | AC 4 (unchanged) |
| 400 | `VALIDATION_ERROR` | Request body validation failed | `missing_or_invalid: ["channel"]` | AC 5 |
| 400 | `MISSING_REQUIRED_DIMENSIONS` | Missing required dimension fields for this target type | `missing_fields`, `target_type`, `table_name` | AC 6 (unchanged) |

## Out of Scope

* Changing any message text, or adding WS1 locale keys.
* How WS1 relays errors (`createError` wrapping and `upstream_*` keys for incentives, pass-through for targets), and WS1's `GENERAL_ERROR` for a non-string slab channel.
* The trailing space in the existing targets controller message (`'Request body validation failed '`).
* A missing, null or blank target channel, which keeps `MISSING_REQUIRED_DIMENSIONS`.
* Bulk upload's per-row channel error ("Field wajib tidak lengkap (salesperson_id, channel)") and the webhooks' `CSV_ROW_VALIDATION_ERROR`. CSV values are always strings.
* Duplicate-channel errors (`DUPLICATE_AGEING_CHANNEL`, the slab duplicate-group error, `DUPLICATE_OR_OVERLAPPING_TARGET`).
* The target list `?channel=` filter error ("Invalid filter field: channel").
* Non-string values in other target fields (`salesperson_id`, `salesperson_name`, …).
* Any frontend change.

## 13. Open points (for you to decide)

C1 to C5 are resolved (section 0). Still open:

1. **Title format:** no rule. The separator varies (`-` vs `—`), and so does the prefix ("Backend Business 1 -" vs "Backend -").
2. **Story vs Task:** no rule for when to use which.
3. **Bug template:** not found. Bug cards on the board are screenshots plus a line or two.
4. **Spike and Subtask:** not found.
5. **Optional sections:** should Error reference and Out of Scope be required? They appear only in the newest cards.
6. **Where out-of-scope goes:** a separate `## Out of Scope` section (564, 567), or `**Not in scope:**` / `**Not in this card:**` inside Context (557, 558, 559)?
7. **Bold labels in Context:** the memory rule says "no heavy sub-headings" (2026-10-12), yet the newest cards use bold labels in Context (Current gap / What changes / Why). Are those fine?
8. **Jira fields:** who sets labels, components, story points, sprint and assignee, and when? The only rule found is your "no" to Claude setting story points, epic or sprint on SCRUM-549.
9. **Where the rules live:** they're spread over `CLAUDE.md` and memory in 4 project folders. The 12-point AC standard is only in the `nodejs-ws2targetsalesincentive` memory, so sessions in other folders don't see it.
