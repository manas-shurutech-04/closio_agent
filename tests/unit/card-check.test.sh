# scripts/card-check.sh: a Jira card's markdown against the card template (docs/jira-card-template.md).
# card-check starts several small programs per line of the card, so the cards here are short and each one checks many
# findings in one run.

# A short card in the template's shape, with every part card-check looks at
good_card() {
  cat <<'EOF'
## Context
The scheme list ignores the status filter. Set `token: <your token here>`; MAX_ROWS_PER_PAGE_IN_THE_SCHEME_LIST_EXPORT stays.
## API request and response
### GET /api/v1/schemes
**Response (200)**
```json
{ "data": [] }
```
### POST /api/v1/schemes
**Request**
```json
{ "name": "A" }
```
**Response (201)**
```json
{ "id": "1" }
```
## How QA can test this
1. Call `GET /api/v1/schemes?status=active`. Expect `200` with only active schemes (AC 1).
2. Call `POST /api/v1/schemes` with `{}`.
   Expect `400` with `error_code: "VALIDATION_ERROR"` (AC 2).
## Acceptance Criteria
**AC 1 — The status filter works**
* **Given** active and inactive schemes * **When** GET is called * **Then** only active ones are returned
**AC 2 — A missing name is refused**
* **Given** a body without `name` * **When** POST is called * **Then** `400` with `error_code: "VALIDATION_ERROR"`
**Error reference**
| HTTP | error_code | message | Raised by |
| 400 | `VALIDATION_ERROR` | name is required | WS2 |
## Out of Scope
* Sorting is out of scope.
EOF
}
check() { # <card text>: writes it to $T/card.md and runs card-check on it
  printf '%s\n' "$1" > "$T/card.md"
  run card-check.sh "$T/card.md"
}
count_of() { printf '%s\n' "$OUT" | grep -c "^$1"; }

test_wrong_usage_shows_the_usage() {
  sandbox
  run card-check.sh
  assert_rc 2; assert_contains "$OUT" "Usage: bash scripts/card-check.sh <card file>"
  run card-check.sh -h
  assert_rc 2; assert_contains "$OUT" "or any .md file with a card that isn't in Jira yet."
  run card-check.sh a.md b.md
  assert_rc 2
  run card-check.sh ""
  assert_rc 2
}
test_a_missing_unreadable_or_empty_file() {
  sandbox
  run card-check.sh "$T/none.md"
  assert_rc 2; assert_contains "$OUT" "❌ Can't find the card file: $T/none.md"; assert_contains "$OUT" "   Fix: Give the path of a .md file"
  echo "## Context" > "$T/locked.md"; chmod 000 "$T/locked.md"
  run card-check.sh "$T/locked.md"
  assert_rc 2; assert_contains "$OUT" "❌ Can't read the card file: $T/locked.md"; assert_contains "$OUT" "Fix: Check the file's permissions."
  : > "$T/empty.md"
  run card-check.sh "$T/empty.md"
  assert_rc 1; assert_contains "$OUT" "❌ The card file is empty: $T/empty.md"
}
test_a_card_in_the_template_shape_passes() {
  sandbox
  check "$(good_card)"
  assert_rc 0
  assert_eq "$OUT" "card-check — $T/card.md (31 lines)
✅ Required sections are there: Context, How QA can test this, Acceptance Criteria
✅ 2 acceptance criteria, numbered 1–2, each with Given / When / Then
✅ Error reference table with a Raised by column
✅ API request and response: 2 API(s), each with its structure
✅ QA steps: 2 numbered steps, each with what to expect
✅ Every AC is named by a QA step
✅ No assumptions, placeholders, forbidden tables or secrets

Result: 0 to fix, 0 to look at.
Not checked by this script (the AI does it when it plans the card): alignment with the code, the WS1 rules, ACs inside the card's scope, real boundary values, whether the QA step that names an AC really proves it."
}
test_sections_without_anything_in_them() {
  sandbox
  check "Just a line of text."
  assert_rc 1
  assert_contains "$OUT" "❌ Required section(s) missing: ## Context, ## How QA can test this, ## Acceptance Criteria"
  assert_contains "$OUT" "   Fix: Add them with exactly these headings (docs/jira-card-template.md, section 1)."
  assert_contains "$OUT" "❌ No acceptance criteria found"
  assert_contains "$OUT" "Result: 2 to fix, 0 to look at."
}
# One card with a finding of nearly every kind; the secret's value must never be shown
test_a_card_with_many_problems_lists_each_with_its_line() {
  sandbox
  check '## How QA can test this
1. Call `GET /api/v1/schemes`. Expect 200 (AC 1).
2. Run the migration and restart the server.
3. Once SCRUM-12 is merged, call it again. Expect 200.
## Acceptance Criteria
**AC 1 — Filter**
* **Given** schemes * **When** GET is called * **Then** `404` with `error_code: "NOT_FOUND"`
**AC 3 — Out of order**
* **Given** nothing
**AC1: Bad heading**
Assumption: the list is small.
Owner: TBD, limit ⟦max⟧
### Files changed
The password: Zx9vQ2mL7pR4tK8w
Shown as one\ntwo. This is checked in code review only.
Export is not in this card.'
  assert_rc 1
  assert_contains "$OUT" "card-check — $T/card.md (16 lines)"
  assert_contains "$OUT" "❌ Required section(s) missing: ## Context"
  assert_not_contains "$OUT" "missing: ## Context, "
  assert_contains "$OUT" "❌ AC heading not in the format on line 10: **AC1: Bad heading**"
  assert_contains "$OUT" "   Fix: Write it as **AC <number> — <title>** (bold, a space after AC, an em dash —, then the title; docs/jira-card-template.md, section 4)."
  assert_contains "$OUT" "❌ AC numbers are 1, 3, not 1, 2, 3…"
  assert_contains "$OUT" "❌ AC 3 has no When, Then (line 8)"
  assert_contains "$OUT" "❌ AC 1 names an error, but the card has no **Error reference** table"
  assert_contains "$OUT" "❌ The card names an API (line 2) but has no ## API request and response"
  assert_contains "$OUT" "⚠️ QA step 2 has no \"Expect\" (line 3)"
  assert_contains "$OUT" "   Tip: Say what QA should see after this step: \"Expect …\"."
  assert_contains "$OUT" "⚠️ QA step mentions deploying, a migration or a restart (line 3): 2. Run the migration and restart the server."
  assert_contains "$OUT" "⚠️ QA step depends on other work being done first (line 4): 3. Once SCRUM-12 is merged, call it again. Expect 200."
  assert_contains "$OUT" "⚠️ No QA step names AC 3"
  assert_contains "$OUT" "❌ Assumption written into the card (line 11): Assumption: the list is small."
  assert_contains "$OUT" "❌ Unfilled placeholder (line 12): Owner: TBD, limit ⟦max⟧"
  assert_contains "$OUT" "❌ Forbidden table or heading (line 13): ### Files changed"
  assert_contains "$OUT" "❌ Line 14 looks like it holds a secret (a token, key, password or cookie); the line isn't shown here"
  assert_not_contains "$OUT" "Zx9vQ2mL7pR4tK8w"
  assert_contains "$OUT" "⚠️ Literal \\n in the text (line 15)"
  assert_contains "$OUT" "⚠️ An AC left out of QA's testing (line 15): Shown as one\\ntwo. This is checked in code review only."
  assert_contains "$OUT" "⚠️ Out-of-scope line outside the Out of Scope section (line 16): Export is not in this card."
  assert_eq "$(count_of ❌)" "10"; assert_eq "$(count_of ⚠️)" "7"
  assert_contains "$OUT" "Result: 10 to fix, 7 to look at."
  assert_not_contains "$OUT" "✅"
}
# The findings the card above can't show at the same time: an Error reference without a table, an empty API section,
# QA steps without numbers (and a last line without a newline)
test_an_empty_error_reference_api_section_and_unnumbered_qa_steps() {
  sandbox
  printf '%s' '## Context
x
## API request and response
Will come.
## How QA can test this
- Call GET /api/v1/x. Expect 400 (AC 1).
## Acceptance Criteria
**AC 1 — Refused**
* **Given** x * **When** y * **Then** HTTP 400
**Error reference**
See the code.' > "$T/card.md"
  run card-check.sh "$T/card.md"
  assert_rc 1
  assert_contains "$OUT" "(11 lines)"
  assert_contains "$OUT" "❌ **Error reference** has no table (line 10)"
  assert_contains "$OUT" "❌ ## API request and response has no API in it (line 3)"
  assert_contains "$OUT" "❌ The QA section has no numbered steps"
  assert_contains "$OUT" "✅ 1 acceptance criteria, numbered 1–1, each with Given / When / Then"
  assert_eq "$(count_of ❌)" "3"
}
test_an_error_table_without_raised_by_and_apis_without_their_json() {
  sandbox
  check '## Context
x
## API request and response
### GET /api/v1/x
**Error response (404)**
```json
{}
```
### `PATCH /api/v1/x/:id`
**Response (200)**
```json
{}
```
### DELETE /api/v1/x/:id
## How QA can test this
1. Call it. Expect 404 (AC 1).
## Acceptance Criteria
**AC 1 — Not found**
* **Given** x * **When** y * **Then** `404` `NOT_FOUND`
**Error reference**
| HTTP | error_code | Who |
| 404 | NOT_FOUND | WS2 |
## Out of Scope
* Out of scope: the rest.'
  assert_rc 1
  assert_contains "$OUT" "❌ The Error reference table has no \"Raised by\" column (line 21)"
  assert_contains "$OUT" "   Fix: Add a Raised by column: WS2, WS1, or Web for a screen-only message (docs/jira-card-template.md, section 2)."
  assert_contains "$OUT" "❌ No Response JSON for GET /api/v1/x (line 4)"
  assert_contains "$OUT" "❌ No Request JSON for \`PATCH /api/v1/x/:id\` (line 9)"
  assert_contains "$OUT" "❌ No Response JSON for DELETE /api/v1/x/:id (line 14)"
  assert_contains "$OUT" "   Fix: Add **Request** with the JSON body the user gave for this API (rule A28)."
  assert_not_contains "$OUT" "API request and response:"
  assert_eq "$(count_of ❌)" "4"; assert_eq "$(count_of ⚠️)" "0" "out of scope inside its own section is fine"
}
