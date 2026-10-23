# scripts/api-check.sh: a card's API test cases (runs/<KEY>/api-checks/ac-<n>.json), each call made through
# scripts/api-call.sh to a fake WS2 (tests/fakes/http.py): LOCAL on this Mac, DEV on the dev environment.

register_repo() { # <name> <folder> [<yaml line>…]
  local name="$1" dir="$2" l; shift 2
  mkdir -p "$dir" "$A/local/repos"
  printf 'name: %s\n' "$name" > "$A/config/repos/$name.yaml"
  for l in "$@"; do printf '%s\n' "$l" >> "$A/config/repos/$name.yaml"; done
  printf 'local_path: %s\n' "$dir" > "$A/local/repos/$name.yaml"
}

setup_checks() {
  sandbox
  cat > "$T/local.json" <<'JSON'
[
 {"method": "GET", "path": "^/api/configs$", "query": "status=active", "json": {"status": "success", "data": [{"id": 1}]}},
 {"method": "POST", "path": "^/api/configs$", "status": 201, "json": {"status": "success", "data": {"id": 2}}},
 {"method": "GET", "path": "^/api/broken$", "status": 500, "json": {"status": "error", "error_code": "INTERNAL_ERROR"}},
 {"method": "GET", "path": "^/api/text$", "text": "plain words"}
]
JSON
  printf '[{"path": ".", "json": {"status": "success", "where": "dev"}}]\n' > "$T/dev.json"
  start_fake LOCAL http "$T/local.json"
  start_fake DEV http "$T/dev.json"
  register_repo fake-ws2 "$T/repos/fake ws2" "language: node" "port: from the repo's .env (PORT)" "dev_base_url: $DEV"
  printf 'PORT=%s\n' "${LOCAL##*:}" > "$T/repos/fake ws2/.env"
  keychain_set closio-agent.nodejs-ws1closio.ws1-client-id.dev ws1-id-123
  keychain_set closio-agent.nodejs-ws1closio.ws1-client-secret.dev ws1-secret-xyz
  CHECKS="$A/runs/SCRUM-7/api-checks"
  mkdir -p "$CHECKS"
  export API_CALL_TIMEOUT=3
}
local_requests() { fake_requests LOCAL; }

# The cases of a passing AC 1: a GET with a check and a header, and a POST with a body and no keys
write_passing_ac1() {
  cat > "$CHECKS/ac-1.json" <<'JSON'
{ "ac": 1, "title": "List and create configs",
  "cases": [
    { "name": "list the active configs → 200", "repo": "fake-ws2", "method": "GET", "path": "/api/configs?status=active",
      "headers": { "X-Partner-Id": "p-1" }, "body": null,
      "expect": { "status": 200, "checks": [ ".status == \"success\"", ".data | length == 1" ] } },
    { "name": "create a config → 201", "repo": "fake-ws2", "method": "POST", "path": "/api/configs",
      "body": { "name": "A", "rate": 2 }, "client": "none",
      "expect": { "status": 201 } } ] }
JSON
}

test_wrong_usage_shows_the_usage() {
  setup_checks
  local args
  for args in "" "SCRUM" "OTHER-1" "SCRUM-7 x" "SCRUM-7 1 2" "SCRUM-7 --env" "SCRUM-7 --env prod"; do
    run api-check.sh $args
    assert_rc 2; assert_eq "$OUT" "Usage: bash scripts/api-check.sh <CARD-KEY> [<AC number>] [--env dev]" "usage for: $args"
  done
}

test_no_cases_at_all_or_for_one_ac() {
  setup_checks
  run api-check.sh SCRUM-7
  assert_rc 2
  assert_eq "$OUT" "❌ No API test cases in runs/SCRUM-7/api-checks/
   Fix: /flow-verify SCRUM-7 writes them (or /flow-ac-check SCRUM-7 <AC> for one AC)."
  run api-check.sh SCRUM-7 3
  assert_rc 2
  assert_eq "$OUT" "❌ No API test cases for AC 3: runs/SCRUM-7/api-checks/ac-3.json
   Fix: write them with /flow-ac-check SCRUM-7 3 (or /flow-verify SCRUM-7 writes every AC's)."
}

test_every_case_passing() {
  setup_checks; write_passing_ac1
  run api-check.sh SCRUM-7
  assert_rc 0
  assert_eq "$OUT" "
AC 1 — List and create configs
  ✅ list the active configs → 200
  ✅ create a config → 201
  ✅ AC 1 passed (2 case(s))

✅ API checks: every AC passed (1)"
  local get post
  get="$(local_requests | jq -c 'select(.m == "GET")')"; post="$(local_requests | jq -c 'select(.m == "POST")')"
  assert_eq "$(printf '%s' "$get" | jq -r '.q + " " + .h["X-Partner-Id"] + " " + .h["x-client-id"]')" "status=active p-1 ws1-id-123"
  assert_eq "$(printf '%s' "$get" | jq -r '.b')" "null" "a null body sends nothing"
  assert_eq "$(printf '%s' "$post" | jq -c '.b')" '{"name":"A","rate":2}'
  assert_eq "$(printf '%s' "$post" | jq -r '.h["x-client-id"] // "no keys"')" "no keys" "client none"
  assert_not_contains "$OUT" "ws1-secret-xyz"
}

test_failing_cases_show_why_and_the_response() {
  setup_checks; write_passing_ac1
  cat > "$CHECKS/ac-2.json" <<'JSON'
{ "ac": 2, "title": "Errors",
  "cases": [
    { "name": "broken → 200", "repo": "fake-ws2", "path": "/api/broken",
      "expect": { "status": 200, "checks": [ ".status == \"success\"", ".error_code == \"INTERNAL_ERROR\"" ] } },
    { "name": "text answer", "repo": "fake-ws2", "path": "/api/text", "expect": { "checks": [ ".a == 1" ] } } ] }
JSON
  run api-check.sh SCRUM-7
  assert_rc 1
  # (a JSON response is followed by an empty line today: jq's own newline, then the script's echo)
  assert_contains "$OUT" "AC 2 — Errors
  ❌ broken → 200
     status 500, expected 200; not true: .status == \"success\"
     response: {\"status\":\"error\",\"error_code\":\"INTERNAL_ERROR\"}

  ❌ text answer
     not true: .a == 1
     response: plain words
  ❌ AC 2: 2 of 2 case(s) failed"
  assert_eq "$(printf '%s\n' "$OUT" | tail -1)" "❌ API checks: 1 AC(s) failed (AC 2), 1 passed"
}

test_one_ac_only() {
  setup_checks; write_passing_ac1
  printf '{"ac": 2, "title": "x", "cases": [{"name": "c", "repo": "fake-ws2", "path": "/api/broken", "expect": {"status": 200}}]}\n' > "$CHECKS/ac-2.json"
  run api-check.sh SCRUM-7 1
  assert_rc 0
  assert_not_contains "$OUT" "AC 2"
  assert_contains "$OUT" "✅ API checks: every AC passed (1)"
}

test_the_acs_run_in_number_order_and_without_an_ac_field_the_file_names_it() {
  setup_checks
  local n
  for n in 10 2; do
    printf '{"title": "AC file %s", "cases": [{"repo": "fake-ws2", "path": "/api/configs?status=active", "expect": {"status": 200}}]}\n' "$n" > "$CHECKS/ac-$n.json"
  done
  run api-check.sh SCRUM-7
  assert_rc 0
  assert_eq "$(printf '%s\n' "$OUT" | grep '^AC ' | tr '\n' '|')" "AC 2 — AC file 2|AC 10 — AC file 10|"
  assert_contains "$OUT" "  ✅ case"
  assert_contains "$OUT" "✅ API checks: every AC passed (2)"
}

test_a_file_that_is_not_json_and_an_ac_without_cases() {
  setup_checks; write_passing_ac1
  printf '{ "ac": 2, "cases": [ \n' > "$CHECKS/ac-2.json"
  printf '{ "ac": 3, "title": "Empty", "cases": [] }\n' > "$CHECKS/ac-3.json"
  run api-check.sh SCRUM-7
  assert_rc 1
  assert_contains "$OUT" "❌ ac-2.json isn't valid JSON
   Fix: correct it with /flow-ac-check SCRUM-7 <AC>."
  assert_contains "$OUT" "  ❌ AC 3: 0 of 0 case(s) failed"
  assert_eq "$(printf '%s\n' "$OUT" | tail -1)" "❌ API checks: 2 AC(s) failed (AC 3), 1 passed"
}

test_a_call_that_fails_is_a_failed_case() {
  setup_checks; write_passing_ac1
  printf 'PORT=1\n' > "$T/repos/fake ws2/.env"; export API_CALL_TIMEOUT=2
  run api-check.sh SCRUM-7 1
  assert_rc 1
  assert_contains "$OUT" "  ❌ list the active configs → 200
     the call failed: ❌ fake-ws2 didn't answer (no response within 2 s)    Fix: Is it running?"
  assert_contains "$OUT" "❌ AC 1: 2 of 2 case(s) failed"
}

test_env_dev_runs_the_same_cases_on_dev() {
  setup_checks
  printf '{"ac": 4, "title": "On dev", "cases": [{"name": "dev answers", "repo": "fake-ws2", "path": "/api/configs", "auth": "user", "expect": {"status": 200, "checks": [".where == \\"dev\\""]}}]}\n' > "$CHECKS/ac-4.json"
  run api-check.sh SCRUM-7 --env dev
  assert_rc 0
  assert_contains "$OUT" "  ✅ dev answers"
  assert_eq "$(local_requests)" "" "nothing on this Mac"
  assert_eq "$(fake_requests DEV | jq -r .p)" "/api/configs"
  run api-check.sh SCRUM-7 4 --env local
  assert_rc 1
  assert_contains "$OUT" "not true: .where == \"dev\""
}
