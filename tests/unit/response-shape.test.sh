# scripts/response-shape.sh: an API's real response compared with the structure in the card (keys and JSON types).

# A card with two APIs in its "## API request and response"
write_card() {
  cat > "$T/card.md" <<'MD'
# SCRUM-9 — Scheme list

## Context
The list of schemes.

## API request and response

### `GET /api/v1/schemes`

**Request** (query)
```json
{ "status": "string" }
```

**Response (200)**
```json
{
  "status": "string",
  "data": [ { "id": "uuid", "name": "string", "rate": "number", "active": "boolean", "updated_at": null,
              "meta": { "tags": "array", "extra": "any" } } ],
  "total": 0
}
```

**Error response (400)**
```json
{ "error_code": "string" }
```

### POST /api/v1/schemes

**Request**
```json
{ "name": "string" }
```

## Acceptance criteria
1. Given …
MD
}
setup_shape() { sandbox; write_card; }
good_body='{"status": "success", "data": [{"id": "6f1c", "name": "A", "rate": 2.5, "active": true, "updated_at": "2026-10-20", "meta": {"tags": [], "extra": 5}}], "total": 1}'

test_wrong_usage_shows_the_usage() {
  setup_shape
  run response-shape.sh "$T/card.md" "GET /api/v1/schemes"
  assert_rc 2; assert_eq "$OUT" 'Usage: bash scripts/response-shape.sh <card file> "<METHOD> <path>" <response file>'
  run response-shape.sh "$T/card.md" "" "$T/r.json"
  assert_rc 2; assert_contains "$OUT" "Usage:"
}

test_a_file_that_cannot_be_read() {
  setup_shape
  run response-shape.sh "$T/card.md" "GET /api/v1/schemes" "$T/none.json"
  assert_rc 2; assert_eq "$OUT" "❌ Can't read $T/none.json
   Fix: give the path of an existing file."
  run response-shape.sh "$T/nocard.md" "GET /api/v1/schemes" "$T/card.md"
  assert_rc 2; assert_contains "$OUT" "❌ Can't read $T/nocard.md"
}

test_the_same_structure_from_a_saved_call() {
  setup_shape
  printf 'status: 200\n%s' "$good_body" > "$T/saved.txt"
  run response-shape.sh "$T/card.md" "get   /api/v1/schemes" "$T/saved.txt"
  assert_rc 0
  assert_eq "$OUT" "✅ get   /api/v1/schemes (HTTP 200): the response has the card's structure"
}

test_the_same_structure_from_a_plain_json_file_with_nulls_and_empty_arrays() {
  setup_shape
  printf '{"status": "ok", "data": [], "total": null}' > "$T/r.json"
  run response-shape.sh "$T/card.md" '`GET /api/v1/schemes`' "$T/r.json"
  assert_rc 1
  assert_eq "$OUT" "❌ \`GET /api/v1/schemes\`: 1 difference(s) from the card's structure
   ❌ null in the response at total: card number
   The user decides: fix the code, or confirm the card's structure (rule A28)."
  printf '{"status": null, "data": [], "total": 3}' > "$T/r.json"
  run response-shape.sh "$T/card.md" 'GET /api/v1/schemes' "$T/r.json"
  assert_rc 0
}

test_every_kind_of_difference_is_listed() {
  setup_shape
  printf 'status: 200\n%s' '{"status": 1, "data": [{"id": 5, "name": "A", "rate": "2", "active": true, "updated_at": {"any": "thing"}, "meta": {"tags": "x"}, "secret": "s"}, {"name": "B"}], "total": "1", "page": 1}' > "$T/saved.txt"
  run response-shape.sh "$T/card.md" "GET /api/v1/schemes" "$T/saved.txt"
  assert_rc 1
  assert_eq "$OUT" "❌ GET /api/v1/schemes (HTTP 200): 13 difference(s) from the card's structure
   ❌ type differs at status: card string, response number
   ❌ type differs at data[0].id: card string, response number
   ❌ type differs at data[0].rate: card number, response string
   ❌ type differs at data[0].meta.tags: card array, response string
   ❌ missing in the response: data[0].meta.extra
   ❌ not in the card: data[0].secret
   ❌ missing in the response: data[1].id
   ❌ missing in the response: data[1].rate
   ❌ missing in the response: data[1].active
   ❌ missing in the response: data[1].updated_at
   ❌ missing in the response: data[1].meta
   ❌ type differs at total: card number, response string
   ❌ not in the card: page
   The user decides: fix the code, or confirm the card's structure (rule A28)."
}

test_a_body_of_another_type() {
  setup_shape
  printf '[1, 2]' > "$T/r.json"
  run response-shape.sh "$T/card.md" "GET /api/v1/schemes" "$T/r.json"
  assert_rc 1
  assert_contains "$OUT" "   ❌ type differs at (the body): card object, response array"
  printf 'null' > "$T/r.json"
  run response-shape.sh "$T/card.md" "GET /api/v1/schemes" "$T/r.json"
  assert_rc 1
  assert_contains "$OUT" "   ❌ null in the response at (the body): card object"
}

test_more_than_sixty_differences_are_cut() {
  sandbox
  { printf '## API request and response\n\n### GET /big\n\n**Response (200)**\n```json\n'
    jq -n '[range(70) | {key: ("k" + tostring), value: "string"}] | from_entries'
    printf '```\n'; } > "$T/card.md"
  printf '{}' > "$T/r.json"
  run response-shape.sh "$T/card.md" "GET /big" "$T/r.json"
  assert_rc 1
  assert_contains "$OUT" "❌ GET /big: 70 difference(s) from the card's structure"
  assert_eq "$(printf '%s\n' "$OUT" | grep -c '   ❌ missing in the response: k')" "60"
  assert_contains "$OUT" "   … and 10 more"
}

test_a_card_without_the_section_the_api_or_its_response() {
  setup_shape
  printf '{}' > "$T/r.json"
  printf '# Card\n\n## Context\nNothing.\n' > "$T/plain.md"
  run response-shape.sh "$T/plain.md" "GET /api/v1/schemes" "$T/r.json"
  assert_rc 2
  assert_eq "$OUT" "❌ $T/plain.md has no ## API request and response.
   Fix: the card needs the user's structure for this API (rule A28): ask the user for it."
  run response-shape.sh "$T/card.md" "DELETE /api/v1/schemes" "$T/r.json"
  assert_rc 2
  assert_eq "$OUT" "❌ \"DELETE /api/v1/schemes\" isn't in the card's ## API request and response.
   Fix: write the API as in its ### heading, or ask the user for its structure (rule A28)."
  run response-shape.sh "$T/card.md" "POST /api/v1/schemes" "$T/r.json"
  assert_rc 2
  assert_eq "$OUT" "❌ \"POST /api/v1/schemes\" has no Response JSON in the card.
   Fix: ask the user for the response structure and add it to the card (rule A28)."
}

test_an_api_after_the_section_ends_is_not_found() {
  setup_shape
  printf '\n### GET /later\n\n**Response (200)**\n```json\n{}\n```\n' >> "$T/card.md"
  printf '{}' > "$T/r.json"
  run response-shape.sh "$T/card.md" "GET /later" "$T/r.json"
  assert_rc 2; assert_contains "$OUT" "isn't in the card's ## API request and response"
}

test_bad_json_in_the_card_or_the_response() {
  setup_shape
  printf '# API request and response:\n\n### GET /x\n**Response (200)**\n```json\n{ "a": "string", }\n```\n' > "$T/bad.md"
  printf '{}' > "$T/r.json"
  run response-shape.sh "$T/bad.md" "GET /x" "$T/r.json"
  assert_rc 2
  assert_contains "$OUT" "❌ The card's Response for \"GET /x\" isn't valid JSON ("
  assert_contains "$OUT" "Fix: ask the user for a valid structure; never fix it yourself (rule A28)."
  printf 'status: 502\n<html>Bad gateway</html>' > "$T/saved.txt"
  run response-shape.sh "$T/card.md" "GET /api/v1/schemes" "$T/saved.txt"
  assert_rc 2
  assert_eq "$OUT" "❌ The response in $T/saved.txt isn't JSON (HTTP 502).
   Fix: check the call; save it again with api-call.sh … --save."
  printf 'not json' > "$T/r.txt"
  run response-shape.sh "$T/card.md" "GET /api/v1/schemes" "$T/r.txt"
  assert_rc 2; assert_contains "$OUT" "❌ The response in $T/r.txt isn't JSON."
}
