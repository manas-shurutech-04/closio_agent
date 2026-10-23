# scripts/api-call.sh: one API call to a repo's server on this Mac (or on dev), against fake HTTP servers
# (tests/fakes/http.py): LOCAL = the repo's server on this Mac, DEV = the dev WS1 login (WS1_LOGIN_URL) and dev addresses.
# Keys and logins come from the fake Keychain.

register_repo() { # <name> <folder> [<yaml line>…]
  local name="$1" dir="$2" l; shift 2
  mkdir -p "$dir" "$A/local/repos"
  printf 'name: %s\n' "$name" > "$A/config/repos/$name.yaml"
  for l in "$@"; do printf '%s\n' "$l" >> "$A/config/repos/$name.yaml"; done
  printf 'local_path: %s\n' "$dir" > "$A/local/repos/$name.yaml"
}
port_of() { local u="$1"; printf '%s' "${u##*:}"; }
local_routes() { printf '%s\n' "$1" > "$T/local.json"; }
dev_routes() { printf '%s\n' "$1" > "$T/dev.json"; }
local_requests() { fake_requests LOCAL; }
dev_requests() { fake_requests DEV; }

# A WS2 repo whose server on this Mac is LOCAL; WS1's own S2S pair in the Keychain
setup_ws2() {
  sandbox
  local_routes '[{"path": ".", "json": {"data": [1]}}]'
  dev_routes '[{"path": ".", "json": {"on": "dev"}}]'
  start_fake LOCAL http "$T/local.json"
  start_fake DEV http "$T/dev.json"
  WS2="$T/repos/fake ws2"
  register_repo fake-ws2 "$WS2" "language: node" "port: from the repo's .env (PORT)" "health_url: /health" "dev_base_url: $DEV/   # on dev"
  printf '# the port\nPORT=%s   # local\n' "$(port_of "$LOCAL")" > "$WS2/.env"
  keychain_set closio-agent.nodejs-ws1closio.ws1-client-id.dev ws1-id-123
  keychain_set closio-agent.nodejs-ws1closio.ws1-client-secret.dev ws1-secret-xyz
  export API_CALL_TIMEOUT=5
}

# The WS1 repo (nodejs-ws1closio) on LOCAL; its dev login on DEV; your WS1 login in the Keychain
setup_ws1() {
  sandbox
  local_routes '[{"path": ".", "json": {"status": "success", "data": {"rows": []}}}]'
  dev_routes '[{"method": "POST", "path": "^/api/v1/login$", "json": {"status": "success", "data": {"user": "qa"}}, "headers": {"Set-Cookie": "connect.sid=s%3Aabc.def; Path=/; HttpOnly"}}]'
  start_fake LOCAL http "$T/local.json"
  start_fake DEV http "$T/dev.json"
  export WS1_LOGIN_URL="$DEV/api/v1/login" API_CALL_TIMEOUT=5
  WS1="$T/repos/ws1"
  register_repo nodejs-ws1closio "$WS1" "language: node" "port: from the repo's .env (PORT)" "health_url: /api/v1/health-checker"
  printf 'PORT=%s\n' "$(port_of "$LOCAL")" > "$WS1/.env"
  keychain_set closio-agent.ws1-login-userid qa.user
  keychain_set closio-agent.ws1-login-password 'pa ss"word!'
  SDIR="$A/local/sessions/nodejs-ws1closio"
}
# write_jar <name> <value> [<name> <value>…]: a saved dev session (curl's cookie jar), without a login
write_jar() {
  mkdir -p "$SDIR"
  printf '# Netscape HTTP Cookie File\n\n' > "$SDIR/cookies"
  while [ $# -ge 2 ]; do printf '#HttpOnly_127.0.0.1\tFALSE\t/\tFALSE\t0\t%s\t%s\n' "$1" "$2" >> "$SDIR/cookies"; shift 2; done
}

# ---------------------------------------------------------------- usage

test_wrong_usage_shows_the_usage_and_sends_nothing() {
  setup_ws2
  local args
  for args in "" "fake-ws2" "fake-ws2 FETCH /x" "fake-ws2 get" "fake-ws2 get /x --json" "fake-ws2 get /x --body" "fake-ws2 get /x --header" \
    "fake-ws2 get /x --auth" "fake-ws2 get /x --client" "fake-ws2 get /x --save" "fake-ws2 get /x --env" "fake-ws2 get /x --env prod" \
    "fake-ws2 get /x --verbose" "fake-ws2 get /x --client everything"; do
    run api-call.sh $args
    assert_rc 2
  done
  assert_contains "$OUT" "Usage: bash scripts/api-call.sh <repo> login | logout | <METHOD> <path>"
  assert_eq "$(local_requests)" "" "nothing sent"
}

test_a_path_must_start_with_a_slash() {
  setup_ws2
  run api-call.sh fake-ws2 get api/x
  assert_rc 2; assert_eq "$OUT" "❌ The path must start with /
   Fix: e.g. /api/incentives/v1/…"
}

test_an_unregistered_repo() {
  setup_ws2
  run api-call.sh nope get /x
  assert_rc 1; assert_eq "$OUT" "❌ nope isn't registered
   Fix: Register it with /flow-configure-repo <path of your clone>, then run this again."
}

# ---------------------------------------------------------------- WS2 calls

test_a_ws2_call_sends_ws1s_keys_in_headers_and_never_prints_them() {
  setup_ws2
  run api-call.sh fake-ws2 get "/api/incentives/v1/configs?status=active"
  assert_rc 0
  assert_eq "$OUT" 'HTTP 200
{
  "data": [
    1
  ]
}'
  local r; r="$(local_requests)"
  assert_eq "$(printf '%s' "$r" | jq -r '[.m, .p, .q] | join(" ")')" "GET /api/incentives/v1/configs status=active"
  assert_eq "$(printf '%s' "$r" | jq -r '.h["x-client-id"] + " " + .h["x-client-secret"]')" "ws1-id-123 ws1-secret-xyz"
  assert_eq "$(printf '%s' "$r" | jq -r '.h["Content-Type"] + " " + .h["accept"]')" "application/json application/json"
  assert_not_contains "$OUT" "ws1-secret-xyz"
}

test_a_pair_saved_under_the_ws2_repo_wins() {
  setup_ws2
  keychain_set closio-agent.fake-ws2.ws2-client-id.dev own-id
  keychain_set closio-agent.fake-ws2.ws2-client-secret.dev own-secret
  run api-call.sh fake-ws2 GET /x
  assert_rc 0
  assert_eq "$(local_requests | jq -r '.h["x-client-id"] + " " + .h["x-client-secret"]')" "own-id own-secret"
}

test_without_ws1s_keys_a_ws2_call_is_refused() {
  setup_ws2; rm -f "$FAKE_KEYCHAIN/closio-agent.nodejs-ws1closio.ws1-client-secret.dev"
  run api-call.sh fake-ws2 get /x
  assert_rc 1
  assert_contains "$OUT" "❌ WS1's client ID and secret aren't saved in the Keychain"
  assert_contains "$OUT" "/flow-configure-repo nodejs-ws1closio key ws1-client-id"
  assert_eq "$(local_requests)" "" "nothing sent"
}

test_missing_or_wrong_keys_on_purpose_for_the_negative_acs() {
  setup_ws2
  run api-call.sh fake-ws2 get /x --client id-only
  run api-call.sh fake-ws2 get /x --client secret-only
  run api-call.sh fake-ws2 get /x --client unknown
  run api-call.sh fake-ws2 get /x --client wrong-secret
  run api-call.sh fake-ws2 get /x --client none
  assert_rc 0
  local seen; seen="$(local_requests | jq -r '"id=" + (.h["x-client-id"] // "-") + " secret=" + (.h["x-client-secret"] // "-")')"
  assert_eq "$(printf '%s\n' "$seen" | sed -n 1p)" "id=ws1-id-123 secret=-"
  assert_eq "$(printf '%s\n' "$seen" | sed -n 2p)" "id=- secret=ws1-secret-xyz"
  assert_eq "$(printf '%s\n' "$seen" | sed -n 3p)" "id=closio-agent-unknown-client secret=not-a-real-secret"
  assert_match "$(printf '%s\n' "$seen" | sed -n 4p)" "^id=ws1-id-123 secret=not-the-right-secret-[0-9]+$"
  assert_eq "$(printf '%s\n' "$seen" | sed -n 5p)" "id=- secret=-"
}

test_none_and_unknown_need_no_saved_keys() {
  setup_ws2; rm -f "$FAKE_KEYCHAIN"/*
  run api-call.sh fake-ws2 get /x --client unknown
  assert_rc 0; assert_contains "$OUT" "HTTP 200"
}

test_a_post_with_a_json_body_an_extra_header_and_a_saved_copy() {
  setup_ws2
  local_routes '[{"method": "POST", "path": "^/api/x$", "status": 201, "json": {"id": "n1", "status": "active"}}]'
  run api-call.sh fake-ws2 post /api/x --json '{"name": "A", "rate": 2}' --header 'X-Partner-Id: p-1' --save "$T/saved.txt"
  assert_rc 0
  assert_contains "$OUT" "HTTP 201"
  local r; r="$(local_requests)"
  assert_eq "$(printf '%s' "$r" | jq -c .b)" '{"name":"A","rate":2}'
  assert_eq "$(printf '%s' "$r" | jq -r '.h["X-Partner-Id"]')" "p-1"
  assert_eq "$(cat "$T/saved.txt")" 'status: 201
{"id": "n1", "status": "active"}'
}

test_a_body_from_a_file_and_the_body_checks() {
  setup_ws2
  printf '{"a": [1, 2]}' > "$T/body.json"
  run api-call.sh fake-ws2 put /api/x/1 --body "$T/body.json"
  assert_rc 0
  assert_eq "$(local_requests | jq -c '[.m, .b]')" '["PUT",{"a":[1,2]}]'
  run api-call.sh fake-ws2 put /api/x/1 --body "$T/none.json"
  assert_rc 2; assert_eq "$OUT" "❌ No body file '$T/none.json'
   Fix: Give the path of a JSON file."
  run api-call.sh fake-ws2 patch /api/x/1 --json '{"a": '
  assert_rc 2; assert_eq "$OUT" "❌ The body isn't valid JSON
   Fix: Fix the JSON, then run this again."
  assert_eq "$(local_requests | grep -c .)" "1" "only the good call was sent"
}

test_keys_tokens_and_cookies_are_never_typed_as_headers() {
  setup_ws2
  local h
  for h in "X-Client-Secret: s" "x-client-id: i" "Authorization: Bearer t" "Cookie: a=b"; do
    run api-call.sh fake-ws2 get /x --header "$h"
    assert_rc 2
    assert_eq "$OUT" "❌ Keys, tokens and cookies are added by the script, never typed
   Fix: Use --client or --auth instead."
  done
  assert_eq "$(local_requests)" "" "nothing sent"
}

test_a_plain_text_answer_and_a_long_one_cut_after_6000_characters() {
  setup_ws2
  local_routes '[{"path": "^/short$", "status": 500, "text": "Internal error"}, {"path": "^/long$", "text": "'"$(printf 'x%.0s' $(seq 1 7000))"'"}]'
  run api-call.sh fake-ws2 delete /short
  assert_rc 0; assert_eq "$OUT" "HTTP 500
Internal error"
  run api-call.sh fake-ws2 get /long
  assert_rc 0
  assert_eq "$(printf '%s\n' "$OUT" | tail -1)" "… (cut after 6000 characters)"
  assert_eq "$(printf '%s\n' "$OUT" | sed -n 2p | tr -d '\n' | wc -c | tr -d ' ')" "6000"
}

test_the_repo_not_answering_on_this_mac() {
  setup_ws2; export API_CALL_TIMEOUT=2
  printf 'PORT=1\n' > "$WS2/.env"
  run api-call.sh fake-ws2 get /x
  assert_rc 1
  assert_eq "$OUT" "❌ fake-ws2 didn't answer (no response within 2 s)
   Fix: Is it running? bash scripts/repo-run.sh fake-ws2 status (start it with: bash scripts/repo-run.sh fake-ws2 start)"
}

test_a_repo_not_cloned_or_without_its_port() {
  setup_ws2
  printf 'OTHER=1\n' > "$WS2/.env"
  run api-call.sh fake-ws2 get /x
  assert_rc 1
  assert_eq "$OUT" "❌ fake-ws2: its port isn't set in its .env (PORT)
   Fix: Set it there (the value isn't shown here), then run this again."
  printf 'local_path: not-cloned\n' > "$A/local/repos/fake-ws2.yaml"
  run api-call.sh fake-ws2 get /x
  assert_rc 1; assert_contains "$OUT" "❌ fake-ws2 isn't cloned on this Mac"
}

test_env_dev_calls_the_repo_on_dev() {
  setup_ws2
  printf 'local_path: not-cloned\n' > "$A/local/repos/fake-ws2.yaml"
  run api-call.sh fake-ws2 get /api/x --env dev
  assert_rc 0
  assert_contains "$OUT" '"on": "dev"'
  assert_eq "$(dev_requests | jq -r '.p + " " + .h["x-client-id"]')" "/api/x ws1-id-123"
  assert_eq "$(local_requests)" "" "nothing to the copy on this Mac"
  run api-call.sh fake-ws2 get /api/x --env local
  assert_rc 1
}

test_env_dev_without_a_dev_address_or_when_dev_does_not_answer() {
  setup_ws2; export API_CALL_TIMEOUT=2
  sed -i '' '/^dev_base_url:/d' "$A/config/repos/fake-ws2.yaml"
  run api-call.sh fake-ws2 get /x --env dev
  assert_rc 1
  assert_eq "$OUT" "❌ fake-ws2 has no dev address (dev_base_url in config/repos/fake-ws2.yaml)
   Fix: Run /flow-setup-repo fake-ws2 dev-address (Codex: \$flow-setup-repo fake-ws2 dev-address)."
  printf 'dev_base_url: none\n' >> "$A/config/repos/fake-ws2.yaml"
  run api-call.sh fake-ws2 get /x --env dev
  assert_rc 1; assert_contains "$OUT" "has no dev address"
  sed -i '' 's#^dev_base_url: none#dev_base_url: http://127.0.0.1:1#' "$A/config/repos/fake-ws2.yaml"
  run api-call.sh fake-ws2 get /x --env dev
  assert_rc 1
  assert_eq "$OUT" "❌ fake-ws2 on dev didn't answer (no response within 2 s)
   Fix: Is the VPN on (/flow-vpn status)? Is fake-ws2 deployed and up on dev?"
}

# ---------------------------------------------------------------- WS1 login

test_only_ws1_has_a_login() {
  setup_ws2
  run api-call.sh fake-ws2 login
  assert_rc 1; assert_eq "$OUT" "❌ Only WS1 (nodejs-ws1closio) has a login
   Fix: Call fake-ws2 directly with its S2S keys (the default --client ok)."
}

test_login_without_your_ws1_login_in_the_keychain() {
  setup_ws1; rm -f "$FAKE_KEYCHAIN/closio-agent.ws1-login-password"
  run api-call.sh nodejs-ws1closio login
  assert_rc 1
  assert_contains "$OUT" "❌ Your WS1 login isn't saved in the Keychain"
  assert_eq "$(dev_requests)" "" "nothing sent"
}

test_login_goes_to_the_dev_ws1_and_keeps_its_session_cookie() {
  setup_ws1
  run api-call.sh nodejs-ws1closio login
  assert_rc 0
  assert_eq "$OUT" "✅ Logged in on the dev WS1 as you; its session cookie is used on the WS1 on this Mac (kept in local/sessions/nodejs-ws1closio/ until: bash scripts/api-call.sh nodejs-ws1closio logout)"
  local r; r="$(dev_requests)"
  assert_eq "$(printf '%s' "$r" | jq -c '.b')" '{"userid":"qa.user","password":"pa ss\"word!","napp_pk":4,"client_type":"web"}'
  assert_eq "$(printf '%s' "$r" | jq -r '.h["X-Application-Version"] + " " + .h["X-Secure-Transmission-Type"]')" "1.0.0+1 x"
  assert_eq "$(local_requests)" "" "never a login on the WS1 on this Mac"
  assert_contains "$(cat "$SDIR/cookies")" "connect.sid	s%3Aabc.def"
  assert_eq "$(stat -f %Lp "$SDIR/cookies") $(stat -f %Lp "$SDIR")" "600 700"
  assert_not_contains "$OUT" "pa ss"
}

test_login_when_dev_does_not_answer() {
  setup_ws1; export WS1_LOGIN_URL="http://127.0.0.1:1/api/v1/login"
  run api-call.sh nodejs-ws1closio login
  assert_rc 1
  assert_eq "$OUT" "❌ The dev WS1 login didn't answer
   Fix: Connect the VPN: /flow-vpn connect (Codex: \$flow-vpn connect), then run this again."
  assert_no_file "$SDIR/cookies"
}

test_login_refused_by_dev() {
  setup_ws1
  dev_routes '[{"method": "POST", "path": "login", "status": 401, "json": {"status": "error", "error_code": "INVALID_CREDENTIALS", "message": "Wrong user id or password"}}]'
  run api-call.sh nodejs-ws1closio login
  assert_rc 1
  assert_contains "$OUT" "❌ The dev WS1 login failed (HTTP 401: Wrong user id or password)"
  assert_contains "$OUT" "Fix: The Keychain login must be your dev WS1 login"
  assert_no_file "$SDIR/cookies"
  dev_routes '[{"method": "POST", "path": "login", "status": 502, "text": "<html>bad gateway</html>"}]'
  run api-call.sh nodejs-ws1closio login
  assert_rc 1; assert_contains "$OUT" "❌ The dev WS1 login failed (HTTP 502: )"
}

test_login_that_asks_for_an_otp() {
  setup_ws1
  dev_routes '[{"method": "POST", "path": "login", "json": {"status": "success", "data": {"use_otp": true}}}]'
  run api-call.sh nodejs-ws1closio login
  assert_rc 1
  assert_eq "$OUT" "❌ Your WS1 login asks for an OTP, which a script can't type
   Fix: Use a test login without OTP: /flow-configure-user ws1-login-userid."
}

test_login_without_a_cookie_or_a_token() {
  setup_ws1
  dev_routes '[{"method": "POST", "path": "login", "json": {"status": "success", "data": {}}}]'
  run api-call.sh nodejs-ws1closio login
  assert_rc 1
  assert_contains "$OUT" "❌ The dev WS1 login answered without a session cookie or a token"
}

test_login_with_a_token_keeps_it_for_the_calls() {
  setup_ws1
  dev_routes '[{"method": "POST", "path": "login", "json": {"status": "success", "data": {"token": "tok-abc"}}}]'
  run api-call.sh nodejs-ws1closio login
  assert_rc 0
  assert_eq "$(cat "$SDIR/token")" "tok-abc"
  write_jar connect.sid "s%3Aabc.def"
  run api-call.sh nodejs-ws1closio get /api/v1/schemes
  assert_rc 0
  assert_eq "$(local_requests | jq -r '.h.Authorization')" "Bearer tok-abc"
  assert_not_contains "$OUT" "tok-abc"
}

test_logout_forgets_the_session() {
  setup_ws1
  run api-call.sh nodejs-ws1closio login
  assert_file "$SDIR/cookies"
  run api-call.sh nodejs-ws1closio logout
  assert_rc 0; assert_eq "$OUT" "✅ Forgot the WS1 session for nodejs-ws1closio"
  assert_no_file "$SDIR"
}

# ---------------------------------------------------------------- WS1 calls

test_a_ws1_call_logs_in_first_and_sends_the_dev_cookie() {
  setup_ws1
  run api-call.sh nodejs-ws1closio get /api/v1/schemes
  assert_rc 0
  assert_contains "$OUT" "HTTP 200"
  assert_eq "$(dev_requests | grep -c .)" "1" "one login on dev"
  local r; r="$(local_requests)"
  assert_eq "$(printf '%s' "$r" | jq -r .h.Cookie)" "connect.sid=s%3Aabc.def"
  assert_eq "$(printf '%s' "$r" | jq -r '.h["X-Application-Version"]')" "1.0.0+1"
  assert_eq "$(printf '%s' "$r" | jq -r '.h["x-client-id"] // "none"')" "none" "no S2S keys on a WS1 call"
  run api-call.sh nodejs-ws1closio get /api/v1/schemes
  assert_eq "$(dev_requests | grep -c .)" "1" "the saved session is reused"
}

test_a_ws1_call_stops_when_the_login_fails() {
  setup_ws1
  dev_routes '[{"method": "POST", "path": "login", "status": 401, "json": {"status": "error", "message": "Wrong password"}}]'
  run api-call.sh nodejs-ws1closio get /api/v1/schemes
  assert_rc 1
  assert_contains "$OUT" "❌ The dev WS1 login failed (HTTP 401: Wrong password)"
  assert_eq "$(local_requests)" "" "no call without a session"
}

test_a_ws1_call_without_login() {
  setup_ws1
  run api-call.sh nodejs-ws1closio get /api/v1/public --auth none
  assert_rc 0
  assert_eq "$(dev_requests)" "" "no login"
  assert_eq "$(local_requests | jq -r '.h.Cookie // "none"')" "none"
  run api-call.sh nodejs-ws1closio get /x --auth admin
  assert_rc 2
}

test_the_local_ws1_refusing_the_cookie_name_gets_the_local_name_and_remembers_it() {
  setup_ws1
  write_jar connect.sid "s%3Aabc.def"
  local_routes '[{"path": ".", "times": 1, "status": 401, "json": {"error_code": "SESSION_EXPIRED"}}, {"path": ".", "json": {"ok": true}}]'
  run api-call.sh nodejs-ws1closio get /api/v1/schemes
  assert_rc 0
  assert_contains "$OUT" "HTTP 200"
  assert_eq "$(local_requests | jq -r .h.Cookie | tr '\n' ' ')" "connect.sid=s%3Aabc.def closio_session_local=s%3Aabc.def "
  assert_eq "$(cat "$SDIR/cookie-mode")" "local"
  run api-call.sh nodejs-ws1closio get /api/v1/schemes
  assert_eq "$(local_requests | tail -1 | jq -r .h.Cookie)" "closio_session_local=s%3Aabc.def" "the way that worked is used first"
  assert_eq "$(dev_requests)" "" "no new login needed"
}

test_the_only_cookie_is_used_as_the_local_session() {
  setup_ws1
  write_jar sid plainvalue
  local_routes '[{"path": ".", "times": 1, "status": 401, "json": {"error_code": "UNAUTHORIZED"}}, {"path": ".", "json": {"ok": true}}]'
  run api-call.sh nodejs-ws1closio get /x
  assert_rc 0
  assert_eq "$(local_requests | tail -1 | jq -r .h.Cookie)" "closio_session_local=plainvalue"
}

test_still_refused_after_a_fresh_login_is_a_warning() {
  setup_ws1
  write_jar a 1 b 2
  local_routes '[{"path": ".", "status": 401, "json": {"error_code": "INVALID_TOKEN"}}]'
  run api-call.sh nodejs-ws1closio get /x
  assert_rc 0
  assert_contains "$OUT" "HTTP 401"
  assert_contains "$OUT" "   ⚠️ The WS1 on this Mac refused the dev session (tried the cookie's own name and closio_session_local, after a fresh dev login)."
  assert_contains "$OUT" "   Tip: it can only read sessions kept where the dev WS1 keeps them"
  assert_eq "$(dev_requests | grep -c .)" "1" "one fresh login"
  assert_eq "$(local_requests | jq -r .h.Cookie | tr '\n' ' ')" "a=1; b=2 connect.sid=s%3Aabc.def closio_session_local=s%3Aabc.def "
  assert_no_file "$SDIR/cookie-mode"
}

test_a_refused_session_and_a_failed_fresh_login() {
  setup_ws1
  write_jar connect.sid "s%3Aold"
  local_routes '[{"path": ".", "status": 401, "json": {"error_code": "SESSION_EXPIRED"}}]'
  dev_routes '[{"method": "POST", "path": "login", "status": 401, "json": {"status": "error", "message": "Locked"}}]'
  run api-call.sh nodejs-ws1closio get /x
  assert_rc 1
  assert_contains "$OUT" "❌ The dev WS1 login failed (HTTP 401: Locked)"
}

test_a_401_that_is_not_about_the_session_is_just_shown() {
  setup_ws1
  write_jar connect.sid "s%3Aabc.def"
  local_routes '[{"path": ".", "status": 401, "json": {"error_code": "MISSING_CLIENT_CREDENTIALS"}}]'
  run api-call.sh nodejs-ws1closio get /x
  assert_rc 0
  assert_contains "$OUT" "HTTP 401"; assert_contains "$OUT" "MISSING_CLIENT_CREDENTIALS"
  assert_eq "$(local_requests | grep -c .)" "1" "no second try"
}

test_the_login_and_the_session_are_never_printed() {
  setup_ws1
  run api-call.sh nodejs-ws1closio login; local all="$OUT"
  run api-call.sh nodejs-ws1closio get /x; all="$all$OUT"
  assert_not_contains "$all" "qa.user"; assert_not_contains "$all" "pa ss"; assert_not_contains "$all" "abc.def"
}
