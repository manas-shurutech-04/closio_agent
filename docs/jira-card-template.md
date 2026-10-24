# Jira card template (project SCRUM)

What a card looks like, so that everyone writing cards and closio-agent work from the same shape ([D58](design-decisions.md#d58)).

- **Who writes cards:** people, and the card-writing pipeline in the sibling folder `Ticket creation pipeline` (it imports this file; [D82](design-decisions.md#d82)). **closio-agent never creates cards.**
- **What closio-agent does with this:** it checks a card against this template when it picks it up (Phase 1), and anyone can check a card any time with `/flow-check-card <CARD-KEY>` (Codex: `$flow-check-card …`, [commands.md](commands.md#flow-check-card)). The script `scripts/card-check.sh` does the part a script can check reliably (section 10); the rest stays with people and with the AI when it plans the card.
- **Where the rules come from:** the team's own cards (SCRUM-542 to SCRUM-568) and past chats, collected on 2026-10-17 (`build-memory/jira-card-rules-input.md`). This file is the single place for them; when a rule changes, it changes here.
- **Three full examples:** [jira-card-examples.md](jira-card-examples.md) (SCRUM-559 and SCRUM-567, backend; SCRUM-532, web).

## 1. The skeleton

Copy this into the card's description and fill it in. Three sections are **required**; the rest are used when the card needs them.

```
**Blocked by:** SCRUM-…                                   (only when another card must land first)

As a <who>, I want <what>, so that <why>.                  every new card: one line (D82)

## Context                                                 REQUIRED
Plain language QA can follow, in any order: the current gap, what changes, why; a short real-life example helps
### Screens in Scope                                       web cards: Screen | Route
### Screen Changes                                        web cards: #### <screen>, then an Element | Current | New table

## API request and response                              REQUIRED when the card names an API (D84)
### <METHOD> <path>                                       one per API: backend, every API added or changed; web, every API the card relies on
**Request**   ```json … ```                                exactly as the user gave it (a GET: "no body" + its query parameters)
**Response (200)**   ```json … ```                         exactly as the user gave it
                     or: **Response (200)**: unchanged (AC <n>)   when the card says the response stays as it is today (D94)
**Error response**   ```json … ```                         optional, only if the user gives one

## Scope                                                   optional: when several repos or APIs change
### WS2 (nodejs-ws2targetsalesincentive)
### Web (closio-web-v2)
### WS1 (nodejs-ws1closio)

### Dev notes                                              optional
### Data cleanup (dev runs this once on the dev DB; not a migration)   optional
## Error responses                                         optional: API → error code, plus the JSON body of a new code

## How QA can test this                                    REQUIRED
**Setup** …
1. … Expect … (AC 1)
2. … Expect … (AC 2)
n. Cleanup …                                               when the steps leave test data behind

## Acceptance Criteria                                     REQUIRED
**AC 1 — Title**

* **Given** …
* **When** …
* **Then** …

**Error reference**                                        REQUIRED when any AC is an error (D82): a table after the last AC
| HTTP | error_code | message | details | Raised by | Trigger |

## Out of Scope                                            optional: the ONLY place for out-of-scope
* …
```

## 2. What goes in each section

| Section | Heading, exactly | Required? | What goes in it |
|---|---|---|---|
| Blocked by | `**Blocked by:** SCRUM-559` as the first line | Only when blocked | The card that must land first. Also link the cards in Jira ("relates to", "is blocked by"). |
| Summary (the Jira title) | the title field | Required | No fixed format. The newest cards use `<Layer> [Business 1] - <what changes> (<repos or APIs>)`, e.g. `Backend - Add details.missing_or_invalid to every channel validation error (Slab, Ageing, Target APIs)`. |
| User Story | one line before `## Context`: `As a <who>, I want <what>, so that <why>.` | Every new card ([D82](design-decisions.md#d82)); not checked by the script | The real actor (an admin, a salesperson, the web app, a WS1 caller), the capability, and the outcome. One line; the explanation goes in Context. |
| Context | `## Context` | **Required** | The current behaviour and the gap. What changes. Why: the business reason and what goes wrong without it. Dependencies. A short real-life example ("On Oct 2 the cron calculates September… on Oct 5 an admin deactivates it"). **Simple language that QA can follow without reading the code, in no fixed order** (user, 2026-10-20): bold labels (`**Current gap:**`, `**What changes:**`, `**Why:**`, `**Already in place today:**`, `**What's missing:**`, `**Example:**`, `**Good to know for QA:**`) and `###` sub-headings are optional helpers. A table helps for reference data (e.g. "API \| Today \| After"). Web cards: the screen tables below. **No out-of-scope lines here**: they go in `## Out of Scope`. |
| API request and response | `## API request and response`, then `### <METHOD> <path>` per API, each with `**Request**` and `**Response (200)**` (and optionally `**Error response**`) as ```json blocks | **Required when the card names an API** ([D84](design-decisions.md#d84)) | **Backend cards:** every API the card adds or changes. **Web cards:** every API the card relies on (new or changed, or whose fields the ACs or QA steps check); APIs the screens call unchanged stay as a method + path line in Dev notes. **The structures always come from the user, exactly as given; the AI never writes, derives or completes one** (rule A28). A GET's Request says "no body" plus the query parameters the user gives. A response the card says stays as it is today: `**Response (200)**: unchanged (AC <n>)`, no JSON; it's checked against the real response before the change ([D94](design-decisions.md#d94)). Where the code returns something else, that's shown to the user, who decides. |
| Scope | `## Scope`, one sub-heading per repo: `### WS2 (nodejs-ws2targetsalesincentive)`, `### Web (closio-web-v2)`, `### WS1 (nodejs-ws1closio)` | Optional (several repos or APIs change) | What changes in each repo, what is "Not changed", the check order. File or function names **only when necessary** to pin the exact spot, in the text. Never a "files changed" table. |
| Dev notes | `### Dev notes` or `**Dev notes**` | Optional | Notes for the developer: blocking cards, exact message strings, what WS1 does, "the implementation approach is up to the developer". |
| Data cleanup | `### Data cleanup (dev runs this once on the dev DB; not a migration)` | Optional | One-off SQL the dev runs. |
| Error responses | `## Error responses` | Optional | A table of API → error code, plus the JSON error body for a new code. |
| How QA can test this | `## How QA can test this` | **Required** | Section 5. |
| Acceptance Criteria | `## Acceptance Criteria` | **Required** | Section 4. |
| Error reference | `**Error reference**` (a table after the last AC) | **Required when any AC is an error** ([D82](design-decisions.md#d82); was optional in D58) | One row per error the ACs name: HTTP, error_code, the exact message, details, **Raised by** (WS2, WS1, or Web for a screen-only message; a WS2 error that WS1 passes through is "WS2"), and the trigger with its AC. The codes match the ACs exactly. Say "existing codes; no new ones" when that's true. The code is the source of truth for every code and message (section 7, rule A16). |
| Out of Scope | `## Out of Scope` | Optional | What this card does not do, and where that work goes. **The only place for out-of-scope** in the whole card. |

**Web cards (`closio-web-v2`)** ([D82](design-decisions.md#d82); the shape of SCRUM-532, Example C):
- `### Screens in Scope` inside Context: a `Screen | Route` table.
- `### Screen Changes`: one `#### <screen name>` per screen, each with an `Element | Current | New` table. Use the exact on-screen labels (Indonesian, as shown) and say "No change" where something stays.
- **Every response the screen can get:** the success, each error code and **each warning** (e.g. `NON_MONOTONIC_PAYOUT`), and for each one what the screen shows and **which field or block** shows it. QA asked about a missing warning on SCRUM-503, which led to SCRUM-569, and found errors on the wrong field in SCRUM-562 and SCRUM-563. The codes come from the backend code (rule A16).
- **The APIs each screen calls** (method and WS1 path) go in `### Dev notes`. The ones the card relies on also get their request and response in `## API request and response`, as the user gives them (D84).
- **Figma or screenshots:** open them, and put the real link in the card. Never only a link with no text.
- **Screen sizes aren't in the card.** QA has a fixed set of checks for every screen.

**Never in a card:**
- a "Files changed" / "Files in scope" / "File Change" table;
- an "AC self-check" table (the 12-point check is done in chat, section 4);
- "Assumption: … confirm before development" lines, or unfilled placeholders (`⟦…⟧`, TODO, TBD);
- a secret (token, cookie, password, key).

## 3. Card types

| Type | Shape | Picked up by closio-agent? |
|---|---|---|
| Story | This template | Yes |
| Task | This template. Story or Task is the card writer's choice; there's no rule | Yes |
| Subtask | This template, or the dev explains what to do | Yes |
| Bug | No fixed shape (on the board: screenshots plus a line or two, with a "relates to" link to the story). The dev explains the gaps when the card is picked up | Yes |
| Spike | — | **No** |

**Backend and web for the same change** ([D82](design-decisions.md#d82)): one card when the change is small on both sides (like SCRUM-564); otherwise two cards. Two cards don't have to be linked in Jira; a `**Blocked by:**` line names the other card when it must land first.

For any card: if something is missing, the dev can explain it in chat when the card is picked up. The agent lists the gaps and waits for that; the explanation is saved with the card (Phase 1, [architecture.md](architecture.md#phase-1--pick-up-the-card-flow-start-card-key-built-in-c2)).

## 4. Acceptance criteria

**Rules**
- **Every card has ACs, always.**
- **Every AC uses Given / When / Then, and no other style.**
  - Given = the starting state (data, config, user, headers)
  - When = the action (API call, upload, job run)
  - Then = the result (HTTP status, error code, message, details, DB change)
- **The heading line is `**AC 1 — Title**`:** bold, a space after "AC", an em dash (—), numbered 1, 2, 3… in order.
- **Every AC must be testable by QA on its own.** No "not testable by QA yet", "QA can't trigger this" or "checked in code review only" ACs, and no dev unit test standing in for a QA check. If something isn't built yet, or QA can't cause the case, the QA steps give a workaround: seed SQL, a manual trigger, a direct API call, or a mocked response with its exact body (section 5).
- **Write ACs as behaviour QA can see,** not technical shorthand. Failing: "sets isLocked flag on the account service". Passing: "user can no longer log in once the account is locked".
- **Boundary ACs state the real numbers and values,** not "within limits". An edge value that's allowed on purpose is noted in the AC: "Also accepted: …" ([D82](design-decisions.md#d82)).
- **Negative ACs name the exact error,** not "handled" or "validated". The codes, statuses and messages come from the code (section 7). **A card with any error AC has the Error reference table** (section 2, D82).
- **Cover the full set, not only the success** (D82, from the Shuru skill review):
  - the success and its exact response;
  - each validation error with its code;
  - rules that depend on the record's state;
  - boundaries;
  - "a run is in progress" and concurrent requests;
  - the WS1 ↔ WS2 failures (502 `UPSTREAM_REQUEST_FAILED`, 500 for a malformed WS2 reply), when WS1 is involved;
  - all-or-nothing ("Nothing is saved").
  - Web cards: every response the screen can get, warnings too, and which field shows each error (section 2).
- **ACs stay inside this card's scope.** Work from other cards gets no AC here.
- **The last AC usually says that existing checks and their order are unchanged;** earlier errors still win.
- **Rejections say "Nothing is saved" or "the config is unchanged".**
- **When removing an AC, renumber the rest and change nothing else.** On a minimal edit, don't rewrite existing ACs into Given / When / Then unless asked.

**Format**

```
**AC 1 — Slab: channel required**

* **Given** an incentive point with `requires_channel = true`
* **When** slab POST ... has a group whose `channel` is missing, null, blank or not a string
* **Then** HTTP 400 `VALIDATION_ERROR`, message `...`, `details.missing_or_invalid: [...]`. Nothing is saved.
```

Also used: `* **And when** …`, `* **And given** …`, or a second When / Then pair; letter groups when there are many ACs (`**A. Web**`, `**B. WS2 matching rule**`); a shared line before the ACs (`_Shared Given:_ …`); a fixed date for date rules ("Today is assumed to be **Oct 12, 2026**…").

**Each AC is also checked in chat** (D82): it has one clear outcome, uses concrete values, and can be checked without reading the Context first.

**The 12-point AC check** is done **in chat before the draft**, never shown in the card. The points: Business Outcome, Expected Behaviour, Business Rules / Conditions, Positive, Negative / Error, Boundary / Limits, Roles / Permissions, Dependencies / Preconditions, Data Conditions, Failure / Recovery, Expected Result, Testability.
- Always required: Business Outcome, Expected Behaviour, Positive, Expected Result, Testability.
- Required when their trigger is true: Business Rules (a calculation or decision logic); Negative (user input, an external call or a failure mode); Boundary (ranges, limits, dates or pagination); Roles (the action is limited by role); Dependencies (it needs prior state or data); Data Conditions (the result changes with the data's state); Failure / Recovery (multi-step, an integration or async).
- A point that doesn't apply gets a one-line N/A reason.

## 5. "How QA can test this"

**Rules**
- Every card has it, in simple language, as **numbered steps** (not formal).
- **Setup first:** data to seed, SQL to insert, config to create, which environment and headers.
- **Exact steps:** which API to call with what body, or what to check in the DB. JSON bodies and SQL go in code blocks; a "base body" is defined once and reused.
- **Every step ends with what to expect** ("Expect …").
- **QA can test the story without any other story being done.** If a dependency isn't built yet, give a workaround: SQL to seed rows, a manual trigger, or a direct API call. Never write "test after X lands".
- **Every AC is covered by a QA step, and the step names it**, e.g. "Expect … (AC 3)" ([D82](design-decisions.md#d82)). No AC is left to a dev unit test or to code review.
- **A response QA can't get from dev** (the API isn't deployed yet, or the case can't be caused): the card gives the **exact body** (200, error or warning), from the backend card or the code, or says "copy the real response of `<call>` and change `<field>` to `<value>`". **QA mocks it with their own tool** (they use Playwright, or the browser). Never a made-up body (D69, D82).
- **Cleanup at the end** when the steps leave test data behind (SQL on the tables the steps used, or the API that deactivates it).
- **Leave out steps the dev always does:** deploying, migrations, restarts. Start from the data QA needs.
- **Build the steps from the real endpoints, headers and CSV columns in the code.**

**Web cards** (D82): the setup says who to log in as (e.g. "a web admin who can create and update Target Sales") and which data must exist, and how to check or create it. The steps open the screen by its route or menu, use the exact labels, toasts and dialog texts, and end with "Expect …". Screen sizes aren't listed; QA has its own checks for every screen.

**What the newest cards do**
- A `**Setup**` block first: the partner to use (the Business 1 partner; its ID is written in the card, never in these docs), the headers (`x-client-id`, `x-client-secret`, `X-Partner-Id`, plus `X-User-Id` and `X-User-Name` for creates and updates), seeded IDs (e.g. `NT_VOLUME_ACHIEVEMENT` = `10000000-0000-4000-8000-000000000001`), SQL to look up IDs, and which month to use and why (to avoid `CONFIG_OVERLAP`, `SLABS_NOT_EDITABLE` or `EDIT_NOT_PERMITTED`).
- Steps grouped by letter (`**A. …**`, `**B. …**`); the numbers carry on across groups.
- "Call WS2 directly", with the reason, when WS1 would reject the request earlier.
- Temporary config changes use SQL, with a revert step right after. Cleanup SQL at the end.
- A DB check that the failed calls saved nothing.
- A regression group ("Nothing else changed", "Ageing (regression; should already pass)").
- No API? Test directly on the DB, plus one regression run. A case the real API can't return is mocked with the exact body (see above).
- `<SP_ID>`-style placeholders for values QA picks themselves are fine.

## 6. Technical details to include

- **API endpoints:** method plus full path in backticks, e.g. `PATCH /api/incentives/v1/incentive-points/:incentive_point_metric_id/slab-configs/:slab_config_id`. Flags like `is_slabs_updated` are named. Request bodies appear as JSON in the QA steps.
- **Headers:** the S2S headers in the QA setup; the WS1 → WS2 contract (params, S2S headers, `X-Partner-Id`, `X-User-Id`, `X-User-Name`) in the ACs.
- **Request and response structures** go in `## API request and response`, exactly as the user gives them: **never written, derived from the code or completed by the AI** (rule A28, [D84](design-decisions.md#d84)). If the user hasn't given one, ask. The values the ACs check go in the ACs and the QA expectations.
- **Errors:** each error has an HTTP status, `error_code`, the exact message and the `details` shape (e.g. `details.missing_or_invalid: ["groups[<i>].channel"]`). An Error reference table, and the JSON body for a new code.
- **Validation order:** "Check order is unchanged everywhere. Earlier errors still win:" followed by the earlier codes, plus an AC for the order.
- **Database:** table and column names, constraints, seeded IDs; migration ACs ("runs safely on existing data", "can be rolled back"); one-off cleanup SQL.
- **Config:** config flags (e.g. `requires_channel`) and the periods to use.
- **Queues:** no rule yet. Webhook processing is tested by checking the processed tables "after a few seconds".
- **Repos:** the Scope section names each repo (`nodejs-ws2targetsalesincentive`, `nodejs-ws1closio`, `closio-web-v2`) and says "WS1 is unchanged" when that's true.
- **WS1 proxy:** a new or changed WS2 API's WS1 proxy and its WS1 ACs go in the **same card**, with "(WS2 + WS1)" in the title. A separate WS1 card is the exception.
- **Dependencies:** the `**Blocked by:**` line; Dev notes naming related cards; "Not in this card" pointing to the card or doc section that covers it; Jira "relates to" links.
- **Translations:** check that `nodejs-ws1closio/locales/{en,id}` has the message. The exact string matters (e.g. "no trailing space").
- **Dev-only module (as of 2026-10-14):** prefer a data fix or deleting dev rows over legacy-compatibility code.
- **After development:** a working WS1 curl is attached to the card.

## 7. Code-alignment rules

- **Read the code before drafting or editing a card:** controllers, services, utils, constants, middlewares and migrations, in every repo involved (WS2, WS1 incl. routes, schemas and proxying, and the web app). Re-read it right before drafting, even if it was read earlier in the chat, and before asking open questions, so the questions rest on facts.
- **Mirror what's there:** error codes, HTTP statuses, messages and error-body shapes; field, column, header and variable names; validation rules, check order and edit-case rules; the closest sibling module's pattern.
- **Never invent anything new:** no error codes, fields, columns, variables, statuses or constants that aren't in the code. If one is truly needed, ask, give the reason, and get approval.
- **If the code and a card or doc disagree,** point it out and use what the code does. Plan docs are not the source of truth.
- **What decides what** ([D82](design-decisions.md#d82), user, 2026-10-20):
  - **The code decides anything that already exists** (codes, messages, fields, check order).
  - **The tech spec or plan section decides what's new;** a spec beats a PRD.
  - **A clash between them is shown to the user, who decides.** It's never settled silently.
  - **With no spec,** the user's description plus the code is enough.
  - **Request and response structures are the exception: they always come from the user,** never from the code or the AI (rule A28, [D84](design-decisions.md#d84)). Where the code differs, show it; the user decides.
- **Error codes always come from the code (rule A16, [D59](design-decisions.md#d59), hard rule):** before developing a card, the agent reads the error codes, statuses and messages that already exist in every repo the card touches. If the card has no Error reference, it uses those. If the card lists error codes, it checks each one against the code, points out every difference, and uses the code's exact errors and messages for the right conditions.
- **For error or validation cards, also check:** how WS1 relays WS2 errors (the incentives controllers rebuild errors with `createError`: translated message plus `upstream_*` keys in `details`; the target-sales controllers pass the body through); the WS1 locale files; the error shape each sibling API really uses (count them; never call one "the standard" without checking); related To Do / In Development cards that touch the same code.

**WS1 rules**

| Scenario | Code | HTTP | Message |
|---|---|---|---|
| Missing or invalid mobile token | `INVALID_TOKEN` | 401 | "invalid or expired token" |
| Web session expired | `SESSION_EXPIRED` | 401 | "your session has expired" |
| No partner_id | `PARTNER_ID_MISSING` | 400 | "X-Partner-Id header is required." |
| Bad UUID path param | `VALIDATION_ERROR` | 400 | "[param] must be a valid UUID" |
| AJV envelope check fails | `GENERAL_ERROR` | 400 | the AJV message |
| WS2 success response is malformed | `INTERNAL_SERVER_ERROR` | 500 | "Something went wrong. Please try again later." |
| WS2 unreachable or timed out | `UPSTREAM_REQUEST_FAILED` | 502 | "Failed to reach Target Sales WS2" |

- WS1 does no input validation. It only checks UUID path params and that AJV required fields are present.
- WS1 errors never include `details.missing_or_invalid`. That's WS2 only.
- WS2 errors pass through WS1 unchanged.
- WS2 credential errors: `MISSING_CLIENT_CREDENTIALS` and `INVALID_CLIENT_AUTH`, both 401. `SIGNATURE_INVALID`, `TOKEN_INVALID` and `VALID_PERIOD_RANGE_INVALID` don't exist.

## 8. How a card is drafted with the AI

1. **Card before code.** After a design or plan, create the card first. Code is written only when the user says to implement.
2. **Name the sources** ([D82](design-decisions.md#d82)). Open them before drafting, and say which were used; never claim one that wasn't opened:
   - the spec or plan section (and a PRD);
   - Figma or screenshots for a web card;
   - the code;
   - **a Jira search for a card that already covers it.** If one exists, edit that card instead of creating a duplicate. (The plan doc's §17 already asked for the payout warnings; SCRUM-503 missed them, and SCRUM-569 had to be raised.)
3. **Re-read the code** (section 7).
4. **Ask the open questions first, on their own, and wait.** Short, each with what was found and a recommended default. Never a full draft with questions at the end. Never "Assumption: … confirm before development" in a card.
   - **Every open point is asked,** blocking (an AC depends on it) or not.
   - **Every API's request and response structure is one of them:** "paste the request and the response of `<METHOD> <path>`". It's copied into the card exactly as given, never written or completed by the AI (rule A28, D84).
   - **Nothing moves forward until each one has an answer** (user, 2026-10-20, D82).
   - **Open points never go into the card or into a Jira comment.**
5. **Run the 12-point AC check and the per-AC check in chat** (section 4).
6. **Post the full draft in chat:** summary, description, ACs. "Let's create the card" or "fix this" still means draft first.
7. **If the replies change anything, post the full final draft again.** Wait for an explicit "update it" or "go ahead". Answering questions, approving single points, or "review it" is not approval.
8. **Only then create or edit the card in Jira.** Set only the fields the user confirmed (epic, sprint, story points); never guess one. Then report the link and whether the card was created or updated.

Also: change only what was asked, plus lines that would contradict it; keep earlier decisions when rewriting (showing trade-offs is not permission to change something); include only the issues the user stated; show the changes in chat before rewriting a card; make all requested changes in one go; when mapping a plan doc to Jira, use one row per doc section in doc order; overwrite a dummy or existing card only when told; the card is self-contained ("no other ticket required"); the output is ready to paste into Jira, and must display properly there (no literal `\n`).

## 9. Jira fields

- **Site:** `productclosio.atlassian.net`, project **SCRUM**.
- **Set by the agent:** only the **status** (To Do → In Development → Code Review → Ready for Test, [D11](design-decisions.md#d11)) and the **assignee** (the person running the command), in Phase 1. It never uses Blocked (QA only).
- **Set by people:** epic / parent (most cards: SCRUM-355 "Incentive Engine"), story points (they measure complexity; AI cuts the time, not the complexity), sprint, labels, components, priority.
- **Links:** "relates to" between related cards when it helps; a backend and a web card for the same change don't have to be linked ([D82](design-decisions.md#d82)). "Blocked by" is written as the first line of the description.
- **Links in the text:** only real ones (spec, PRD, Figma, epic). No placeholder link; leave the line out if there's none.

## 10. Ready checklist

Checked by `scripts/card-check.sh` (❌ = not ready, the pick-up stops and waits; ⚠️ = worth a look):

| ❌ not ready | ⚠️ worth a look |
|---|---|
| `## Context`, `## How QA can test this` or `## Acceptance Criteria` missing | a QA step without "Expect" |
| no ACs; an AC heading not `**AC 1 — Title**`; AC numbers not 1, 2, 3… | deploy, migrate or restart steps in the QA section |
| an AC without Given, When and Then | "test after SCRUM-… lands"-style wording |
| an "Assumption:" line, `⟦…⟧`, TODO or TBD | a literal `\n` in the text |
| a "Files changed" or "AC self-check" table | out-of-scope lines outside `## Out of Scope` |
| QA section with no numbered steps; anything that looks like a secret | an AC that no QA step names ("(AC 3)") (D82) |
| an AC names an error (an HTTP 4xx/5xx status or `error_code`) but there's no `**Error reference**`; an Error reference without a "Raised by" column (D82) | "can't trigger", "code review only" or "not testable by QA" wording (D82) |
| the card names an API (`GET`/`POST`/`PUT`/`PATCH`/`DELETE` and a path) but has no `## API request and response`; an API there with no Response JSON, or a POST/PUT/PATCH with no Request JSON (D84) | |

Checked by people, and by the AI when it plans the card (Phase 2):

- [ ] Were the sources named (spec or plan section, PRD, Figma, code), and was Jira searched for a card that already covers it?
- [ ] Was the code re-read in every repo involved, right before drafting?
- [ ] Was every open point, blocking or not, asked and answered before the draft?
- [ ] Is there a one-line User Story before Context?
- [ ] Does every API the card adds, changes or relies on have its request and response, exactly as the user gave them (none written by the AI)?
- [ ] Was the 12-point AC check done in chat, with an N/A reason for each point that doesn't apply?
- [ ] Was the full final draft shown in chat, with an explicit "go ahead" or "update it"?
- [ ] Does Context cover the current behaviour and gap, what changes, why, and dependencies, in plain language?
- [ ] Are file or function names used only where necessary?
- [ ] Does every error code, status, message, field, column and header exist in the code, or was it approved as new?
- [ ] Do WS1 ACs use only real WS1 codes, with no validation in WS1, no `details.missing_or_invalid`, and 502 for unreachable?
- [ ] If a WS2 API is reached through WS1, is the WS1 proxy work in the same card (unless agreed otherwise)?
- [ ] Is the check order stated (earlier errors still win)?
- [ ] Does every "Then" name the exact HTTP status, error_code, message, details or DB result?
- [ ] Do all ACs stay inside this card's scope? Do boundary ACs state the real values?
- [ ] Does the QA setup list the partner, headers, IDs, lookup SQL and which period to use?
- [ ] Is every AC covered by a QA step, with none left to a dev unit test?
- [ ] Can QA run it without any other story being done (with a workaround given)?
- [ ] Does every temporary DB change in the QA steps have a revert step, and is there a cleanup for the test data?
- [ ] Web card: are the screens, their element changes, every response (warnings too) and the field each error shows all in the card?
- [ ] Are blocked-by and related cards named in the card and linked in Jira?
- [ ] Is out-of-scope work listed, in `## Out of Scope` only?

## 11. Mistakes to avoid

Corrections the team has given before; each is now a rule above.

| Mistake | Rule |
|---|---|
| A card created or updated directly, with no draft | Draft first; wait for "go ahead" (section 8) |
| An assumption written into the card instead of asked | Ask the open questions first (section 8) |
| A full draft posted with questions at the end | Questions first, on their own (section 8) |
| Questions asked before checking the WS1 code | Re-read the code first (section 7) |
| A "files changed" table | Never; names only where necessary, in the text (section 2) |
| An AC left to a dev unit test ("Not testable by QA yet") | Every AC is testable by QA on its own (section 4) |
| A Context written too formally | Plain language the reader can relate to (section 2) |
| A simple column add over-engineered | Keep the scope to what was asked |
| Invented WS1 codes, or validation put in WS1 | Only real WS1 codes; WS1 validates nothing (section 7) |
| `details.missing_or_invalid` on a WS1 error | WS2 only (section 7) |
| ACs written for work in other cards | ACs stay inside this card's scope (section 4) |
| ACs missing, or not in Given / When / Then | Always, and only that style (section 4) |
| Issues added that the user didn't state | Only what was stated (section 8) |
| A decision changed silently in a rewrite | Keep earlier decisions (section 8) |
| Details missed across updates | All requested changes in one go (section 8) |
| A card pushed with literal `\n` text | It must display properly in Jira (section 8) |
| Other ACs touched when asked to remove one | Remove it, renumber, change nothing else (section 4) |
| Plan-doc sections renumbered | One row per doc section, in doc order (section 8) |
| A web card that didn't say what the screen does with an API warning (SCRUM-503, then SCRUM-569) | Every response, warnings too (section 2, web cards) |
| An error shown on the wrong field (SCRUM-562, SCRUM-563) | Name the field or block for each error (section 2, web cards) |
| An AC left to code review: "QA can't trigger this" (SCRUM-532 AC 11) | A QA workaround, e.g. a mocked response (sections 4 and 5) |
| A card for something a plan section had already asked for, but missed | Search Jira and the plan first (section 8) |
| A request or response structure written by the AI | Never: the user gives it, and it's copied exactly (section 2, rule A28) |
