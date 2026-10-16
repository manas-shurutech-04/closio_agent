# Jira card template (project SCRUM)

What a card looks like, so that everyone writing cards and closio-agent work from the same shape ([D58](design-decisions.md#d58)).

- **Who writes cards:** people, and later a separate pipeline. **closio-agent never creates cards.**
- **What closio-agent does with this:** it checks a card against this template when it picks it up (Phase 1), and anyone can check a card any time with `/flow-check-card <CARD-KEY>` (Codex: `$flow-check-card …`, [commands.md](commands.md#flow-check-card)). The script `scripts/card-check.sh` does the part a script can check reliably (section 10); the rest stays with people and with the AI when it plans the card.
- **Where the rules come from:** the team's own cards (SCRUM-542 to SCRUM-568) and past chats, collected on 2026-10-17 (`build-memory/jira-card-rules-input.md`). This file is the single place for them; when a rule changes, it changes here.
- **Two full examples:** [jira-card-examples.md](jira-card-examples.md) (SCRUM-559 and SCRUM-567).

## 1. The skeleton

Copy this into the card's description and fill it in. Three sections are **required**; the rest are used when the card needs them.

```
**Blocked by:** SCRUM-…                                   (only when another card must land first)

## Context                                                 REQUIRED
**Current gap:** …   **What changes:** …   **Why:** …   (plain language; a short real-life example helps)

## Scope                                                   optional: when several repos or APIs change
### WS2 (nodejs-ws2targetsalesincentive)
### Web (closio-web-v2)
### WS1 (nodejs-ws1closio)

### Dev notes                                              optional
### Data cleanup (dev runs this once on the dev DB; not a migration)   optional
## Error responses                                         optional: API → error code, plus the JSON body of a new code

## How QA can test this                                    REQUIRED
**Setup** …
1. … Expect …
2. … Expect …

## Acceptance Criteria                                     REQUIRED
**AC 1 — Title**

* **Given** …
* **When** …
* **Then** …

**Error reference**                                        optional: a table after the last AC
| HTTP | error_code | message | details | Trigger |

## Out of Scope                                            optional: the ONLY place for out-of-scope
* …
```

## 2. What goes in each section

| Section | Heading, exactly | Required? | What goes in it |
|---|---|---|---|
| Blocked by | `**Blocked by:** SCRUM-559` as the first line | Only when blocked | The card that must land first. Also link the cards in Jira ("relates to", "is blocked by"). |
| Summary (the Jira title) | the title field | Required | No fixed format. The newest cards use `<Layer> [Business 1] - <what changes> (<repos or APIs>)`, e.g. `Backend - Add details.missing_or_invalid to every channel validation error (Slab, Ageing, Target APIs)`. |
| Context | `## Context` | **Required** | The current behaviour and the gap. What changes. Why: the business reason and what goes wrong without it. Dependencies. A short real-life example ("On Oct 2 the cron calculates September… on Oct 5 an admin deactivates it"). Plain language, not formal. Bold labels (`**Current gap:**`, `**What changes:**`, `**Why:**`, `**Already in place today:**`, `**What's missing:**`, `**Example:**`, `**Good to know for QA:**`) and `###` sub-headings are both fine. **No out-of-scope lines here**: they go in `## Out of Scope`. |
| Scope | `## Scope`, one sub-heading per repo: `### WS2 (nodejs-ws2targetsalesincentive)`, `### Web (closio-web-v2)`, `### WS1 (nodejs-ws1closio)` | Optional (several repos or APIs change) | What changes in each repo, what is "Not changed", the check order. File or function names **only when necessary** to pin the exact spot, in the text. Never a "files changed" table. |
| Dev notes | `### Dev notes` or `**Dev notes**` | Optional | Notes for the developer: blocking cards, exact message strings, what WS1 does, "the implementation approach is up to the developer". |
| Data cleanup | `### Data cleanup (dev runs this once on the dev DB; not a migration)` | Optional | One-off SQL the dev runs. |
| Error responses | `## Error responses` | Optional | A table of API → error code, plus the JSON error body for a new code. |
| How QA can test this | `## How QA can test this` | **Required** | Section 5. |
| Acceptance Criteria | `## Acceptance Criteria` | **Required** | Section 4. |
| Error reference | `**Error reference**` (a table after the last AC) | Optional | HTTP, error_code, message, details, which AC it belongs to. Say "existing codes; no new ones". The code is the source of truth for every code and message (section 7, rule A16). |
| Out of Scope | `## Out of Scope` | Optional | What this card does not do, and where that work goes. **The only place for out-of-scope** in the whole card. |

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

For any card: if something is missing, the dev can explain it in chat when the card is picked up. The agent lists the gaps and waits for that; the explanation is saved with the card (Phase 1, [architecture.md](architecture.md#phase-1--pick-up-the-card-flow-start-card-key)).

## 4. Acceptance criteria

**Rules**
- **Every card has ACs, always.**
- **Every AC uses Given / When / Then, and no other style.**
  - Given = the starting state (data, config, user, headers)
  - When = the action (API call, upload, job run)
  - Then = the result (HTTP status, error code, message, details, DB change)
- **The heading line is `**AC 1 — Title**`:** bold, a space after "AC", an em dash (—), numbered 1, 2, 3… in order.
- **Every AC must be testable by QA on its own.** No "not testable by QA yet" ACs, and no dev unit test standing in for a QA check. If something isn't built yet, the QA steps give a workaround.
- **Write ACs as behaviour QA can see,** not technical shorthand. Failing: "sets isLocked flag on the account service". Passing: "user can no longer log in once the account is locked".
- **Boundary ACs state the real numbers and values,** not "within limits".
- **Negative ACs name the exact error,** not "handled" or "validated". The codes, statuses and messages come from the code (section 7).
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
- **Every AC is covered by a QA step.** No AC is left to a dev unit test.
- **Leave out steps the dev always does:** deploying, migrations, restarts. Start from the data QA needs.
- **Build the steps from the real endpoints, headers and CSV columns in the code.**

**What the newest cards do**
- A `**Setup**` block first: the partner to use (the Business 1 partner; its ID is written in the card, never in these docs), the headers (`x-client-id`, `x-client-secret`, `X-Partner-Id`, plus `X-User-Id` and `X-User-Name` for creates and updates), seeded IDs (e.g. `NT_VOLUME_ACHIEVEMENT` = `10000000-0000-4000-8000-000000000001`), SQL to look up IDs, and which month to use and why (to avoid `CONFIG_OVERLAP`, `SLABS_NOT_EDITABLE` or `EDIT_NOT_PERMITTED`).
- Steps grouped by letter (`**A. …**`, `**B. …**`); the numbers carry on across groups.
- "Call WS2 directly", with the reason, when WS1 would reject the request earlier.
- Temporary config changes use SQL, with a revert step right after. Cleanup SQL at the end.
- A DB check that the failed calls saved nothing.
- A regression group ("Nothing else changed", "Ageing (regression; should already pass)").
- No API? Test directly on the DB, plus one regression run. Fake a response with Chrome DevTools "Override content" when the real API can't return the case.
- `<SP_ID>`-style placeholders for values QA picks themselves are fine.

## 6. Technical details to include

- **API endpoints:** method plus full path in backticks, e.g. `PATCH /api/incentives/v1/incentive-points/:incentive_point_metric_id/slab-configs/:slab_config_id`. Flags like `is_slabs_updated` are named. Request bodies appear as JSON in the QA steps.
- **Headers:** the S2S headers in the QA setup; the WS1 → WS2 contract (params, S2S headers, `X-Partner-Id`, `X-User-Id`, `X-User-Name`) in the ACs.
- **Response values** go in the ACs and the QA expectations (older cards had a `## Response (200)` section).
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
2. **Re-read the code** (section 7).
3. **Ask the open questions first, on their own, and wait.** Short, each with what was found and a recommended default. Never a full draft with questions at the end. Never "Assumption: … confirm before development" in a card.
4. **Run the 12-point AC check in chat** (section 4).
5. **Post the full draft in chat:** summary, description, ACs. "Let's create the card" or "fix this" still means draft first.
6. **If the replies change anything, post the full final draft again.** Wait for an explicit "update it" or "go ahead". Answering questions or approving single points is not approval.
7. **Only then create or edit the card in Jira.**

Also: change only what was asked, plus lines that would contradict it; keep earlier decisions when rewriting (showing trade-offs is not permission to change something); include only the issues the user stated; show the changes in chat before rewriting a card; make all requested changes in one go; when mapping a plan doc to Jira, use one row per doc section in doc order; overwrite a dummy or existing card only when told; the card is self-contained ("no other ticket required"); the output is ready to paste into Jira, and must display properly there (no literal `\n`).

## 9. Jira fields

- **Site:** `productclosio.atlassian.net`, project **SCRUM**.
- **Set by the agent:** only the **status** (To Do → In Development → Code Review → Ready for Test, [D11](design-decisions.md#d11)) and the **assignee** (the person running the command), in Phase 1. It never uses Blocked (QA only).
- **Set by people:** epic / parent (most cards: SCRUM-355 "Incentive Engine"), story points (they measure complexity; AI cuts the time, not the complexity), sprint, labels, components, priority.
- **Links:** "relates to" between related cards; "Blocked by" also written as the first line of the description.

## 10. Ready checklist

Checked by `scripts/card-check.sh` (❌ = not ready, the pick-up stops and waits; ⚠️ = worth a look):

| ❌ not ready | ⚠️ worth a look |
|---|---|
| `## Context`, `## How QA can test this` or `## Acceptance Criteria` missing | a QA step without "Expect" |
| no ACs; an AC heading not `**AC 1 — Title**`; AC numbers not 1, 2, 3… | deploy, migrate or restart steps in the QA section |
| an AC without Given, When and Then | "test after SCRUM-… lands"-style wording |
| an "Assumption:" line, `⟦…⟧`, TODO or TBD | a literal `\n` in the text |
| a "Files changed" or "AC self-check" table | out-of-scope lines outside `## Out of Scope` |
| QA section with no numbered steps; anything that looks like a secret | |

Checked by people, and by the AI when it plans the card (Phase 2):

- [ ] Was the code re-read in every repo involved, right before drafting?
- [ ] Were the open questions asked and answered before the draft?
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
- [ ] Does every temporary DB change in the QA steps have a revert step?
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
