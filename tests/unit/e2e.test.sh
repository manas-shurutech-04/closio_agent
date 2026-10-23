# scripts/e2e.sh: closio-agent's Playwright runs for web cards. npm and npx are stand-ins (fake_cmd): the stand-in npx
# copies a prepared Playwright JSON report ($T/results.json) or probe output ($T/probe.txt) where the script expects it,
# and keeps the E2E_ variables it was given ($T/npx-env). The web app on this Mac is a fake HTTP server (WEB).

register_repo() { # <name> <folder> [<yaml line>…]
  local name="$1" dir="$2" l; shift 2
  mkdir -p "$dir" "$A/local/repos"
  printf 'name: %s\n' "$name" > "$A/config/repos/$name.yaml"
  for l in "$@"; do printf '%s\n' "$l" >> "$A/config/repos/$name.yaml"; done
  printf 'local_path: %s\n' "$dir" > "$A/local/repos/$name.yaml"
}

NPX_BODY='d="$FAKE_CMDS/.."
case "$*" in *"install chromium"*) exit "${FAKE_NPX_RC:-0}" ;; esac
env | grep "^E2E_" | sort > "$d/npx-env"
if [ -n "${E2E_PROBE_OUT:-}" ]; then
  [ -f "$d/probe.txt" ] && cp "$d/probe.txt" "$E2E_PROBE_OUT"
else
  [ -f "$d/results.json" ] && cp "$d/results.json" "$E2E_JSON"
fi
echo "playwright says hello"
[ -n "${FAKE_NPX_SLEEP:-}" ] && sleep "$FAKE_NPX_SLEEP"
exit "${FAKE_NPX_RC:-0}"'

# Playwright set up, the web app running on this Mac, your FE login in the Keychain, and one spec for SCRUM-5
setup_e2e() {
  sandbox
  AR="$(cd "$A" && pwd -P)"
  mkdir -p "$A/e2e/node_modules/@playwright/test" "$HOME/Library/Caches/ms-playwright/chromium-1140" "$A/e2e/probe"
  printf '{"name": "closio-agent-e2e"}\n' > "$A/e2e/package.json"
  printf '{"version": "1.48.2"}\n' > "$A/e2e/node_modules/@playwright/test/package.json"
  printf '[{"path": ".", "text": "<html>web app</html>"}]\n' > "$T/web.json"
  start_fake WEB http "$T/web.json"
  W="$T/repos/web app"
  register_repo closio-web-v2 "$W" "type: FE" "language: node" "node_version: 22" "port: from the repo's .env (VITE_PORT)" \
    "health_url: /   # no health endpoint" "env_file: .env.development" "dev_base_url: https://dev-closio.test/home/"
  printf 'VITE_PORT=%s\n' "${WEB##*:}" > "$W/.env.development"
  keychain_set closio-agent.fe-login-id fe.user
  keychain_set closio-agent.fe-login-password fe-pass-9
  mkdir -p "$A/runs/SCRUM-5/e2e"
  printf "test('AC 1 — list', async () => {});\n" > "$A/runs/SCRUM-5/e2e/ac-1.spec.ts"
  fake_cmd npx "$NPX_BODY"
  RESULTS="$A/local/e2e-results"
}
npx_env() { grep "^$1=" "$T/npx-env" | sed "s/^$1=//"; }

# A report: AC 1 passes; AC 2 has a failing test (an error with colours, two failed calls, a mock) and a passing one
# (another mock); AC 3 fails with one of AC 2's failed calls.
write_mixed_results() {
  cat > "$T/results.json" <<'JSON'
{"suites": [
  {"title": "ac-1.spec.ts", "specs": [
    {"title": "AC 1 — list shows schemes", "ok": true, "tests": [{"results": [{"status": "passed"}]}]}],
   "suites": [
    {"title": "filters", "specs": [
      {"title": "AC 2 — filter by status", "ok": false, "tests": [{
        "annotations": [{"type": "api-failed", "description": "GET /api/v1/schemes/6f1c2d3e-aaaa → 500"}, {"type": "api-mocked", "description": "config-list"}],
        "results": [{"error": {"message": "\u001b[31mExpected: 3\u001b[39m\nReceived: 0"}, "annotations": [{"type": "api-failed", "description": "GET /api/v1/other → no answer"}]}]}]},
      {"title": "AC 2 — filter resets", "ok": true, "tests": [{"annotations": [{"type": "api-mocked", "description": "config-detail"}], "results": []}]},
      {"title": "AC 3 — export", "ok": false, "tests": [{"results": [{"error": {"message": "Timeout"},
        "annotations": [{"type": "api-failed", "description": "GET /api/v1/other → no answer"}]}]}]}]}]}]}
JSON
}

# ---------------------------------------------------------------- check and setup

test_check_when_playwright_is_set_up_or_not() {
  setup_e2e
  run e2e.sh check
  assert_rc 0; assert_eq "$OUT" "✅ Playwright is set up (e2e/ packages and the Chromium browser)"
  rm -rf "$HOME/Library/Caches/ms-playwright/chromium-1140"
  run e2e.sh check
  assert_rc 1
  assert_eq "$OUT" "⚠️ Playwright isn't set up yet (needed to check web cards)
   Tip: Run /flow-configure-user playwright (Codex: \$flow-configure-user playwright); it asks before the download."
  PLAYWRIGHT_BROWSERS_PATH="$T/browsers" run e2e.sh check
  assert_rc 1
  mkdir -p "$T/browsers/chromium-1"
  PLAYWRIGHT_BROWSERS_PATH="$T/browsers" run e2e.sh check
  assert_rc 0
}

test_setup_installs_the_packages_and_chromium_on_node_22() {
  setup_e2e
  printf '{}\n' > "$A/e2e/package-lock.json"
  run e2e.sh setup
  assert_rc 0
  assert_eq "$OUT" "   Installing the e2e/ packages (npm ci) and the Chromium browser, time limit 900 s...
✅ Playwright is set up (e2e/ packages and the Chromium browser)"
  assert_eq "$(fake_calls npm)" "npm ci"
  assert_eq "$(fake_calls npx)" "npx playwright install chromium"
  assert_contains "$(fake_calls nvm)" "nvm use 22"
  assert_match "$(cat "$A/local/logs/e2e-setup.log")" '\$ npm ci && npx playwright install chromium   \([0-9-]+ [0-9:]+\)'
}

test_setup_without_a_lock_file_uses_npm_install() {
  setup_e2e
  run e2e.sh setup
  assert_rc 0
  assert_contains "$OUT" "(npm install)"
  assert_eq "$(fake_calls npm)" "npm install"
}

test_setup_without_the_e2e_project() {
  setup_e2e; rm "$A/e2e/package.json"
  run e2e.sh setup
  assert_rc 1
  assert_eq "$OUT" "❌ e2e/package.json is missing
   Fix: It's part of closio-agent: git checkout -- e2e/ (or pull the latest closio-agent)."
}

test_setup_that_fails_shows_the_end_of_its_log() {
  setup_e2e
  fake_cmd npm 'echo "npm ERR! network ETIMEDOUT"; exit 1'
  run e2e.sh setup
  assert_rc 1
  assert_contains "$OUT" "❌ The setup failed
   Fix: Read local/logs/e2e-setup.log (end below), fix the cause (often the network), then run /flow-configure-user playwright again."
  assert_contains "$OUT" "        npm ERR! network ETIMEDOUT"
  assert_eq "$(fake_calls npx)" "" "chromium is not installed after a failed npm"
}

test_setup_without_node_22() {
  setup_e2e
  FAKE_NVM_MISSING=22 run e2e.sh setup
  assert_rc 1
  assert_contains "$OUT" "❌ nvm or Node 22 isn't available"
  assert_eq "$(fake_calls npm)" "" "nothing installed"
}

test_setup_stopped_at_its_time_limit() {
  setup_e2e
  fake_cmd npm 'sleep 20'
  E2E_TIMEOUT=1 run e2e.sh setup
  assert_rc 1
  assert_contains "$OUT" "❌ The setup took longer than 1 seconds and was stopped"
  assert_contains "$(cat "$A/local/logs/e2e-setup.log")" "closio-agent: stopped after 1 seconds (time limit)"
}

# ---------------------------------------------------------------- the arguments

test_wrong_usage_shows_the_usage() {
  setup_e2e
  local args
  for args in "" "nothing" "run" "run SCRUM-5 1 2" "run SCRUM-5 --mock" "run SCRUM-5 --env prod" "run SCRUM-5 --quick" \
    "probe SCRUM-5 1" "quick" "run OTHER-5" "run SCRUM-5 x" "probe SCRUM" ; do
    run e2e.sh $args
    assert_rc 2
    assert_contains "$OUT" "Usage: bash scripts/e2e.sh check | setup | run <CARD-KEY>" "usage for: $args"
  done
  assert_eq "$(fake_calls npx)" "" "nothing ran"
}

test_mock_names_are_checked() {
  setup_e2e
  run e2e.sh run SCRUM-5 --mock 'a;b'
  assert_rc 2
  assert_eq "$OUT" "❌ Mock names may only have letters, digits, - and _ (comma between names)
   Fix: Use the names in the card's api-mocks.ts, e.g. --mock config-detail,config-list"
}

# ---------------------------------------------------------------- run and quick

test_run_when_playwright_is_not_set_up() {
  setup_e2e; rm -rf "$A/e2e/node_modules"
  run e2e.sh run SCRUM-5
  assert_rc 1; assert_contains "$OUT" "⚠️ Playwright isn't set up yet"
  run e2e.sh probe SCRUM-5
  assert_rc 1; assert_contains "$OUT" "⚠️ Playwright isn't set up yet"
}

test_run_without_tests() {
  setup_e2e; rm "$A/runs/SCRUM-5/e2e/ac-1.spec.ts"
  run e2e.sh run SCRUM-5
  assert_rc 2
  assert_eq "$OUT" "❌ No Playwright tests in runs/SCRUM-5/e2e/
   Fix: /flow-verify SCRUM-5 writes them (or /flow-ac-check SCRUM-5 <AC> for one AC)."
  run e2e.sh quick SCRUM-5
  assert_rc 2
  assert_eq "$OUT" "❌ No one-off Playwright tests in local/quick-checks/SCRUM-5/
   Fix: flow-verify's quick check writes them there first (/flow-verify SCRUM-5 quick)."
}

test_run_needs_the_web_app_and_your_fe_login() {
  setup_e2e
  mv "$A/local/repos/closio-web-v2.yaml" "$T/web.yaml"
  run e2e.sh run SCRUM-5
  assert_rc 1; assert_contains "$OUT" "❌ closio-web-v2 isn't cloned on this Mac"
  mv "$T/web.yaml" "$A/local/repos/closio-web-v2.yaml"
  printf 'VITE_PORT=1\n' > "$W/.env.development"
  run e2e.sh run SCRUM-5
  assert_rc 1
  assert_eq "$OUT" "❌ The web app (closio-web-v2) isn't running on this Mac
   Fix: Start it: bash scripts/repo-run.sh closio-web-v2 start, then run this again."
  printf 'VITE_PORT=%s\n' "${WEB##*:}" > "$W/.env.development"
  rm "$FAKE_KEYCHAIN/closio-agent.fe-login-password"
  run e2e.sh run SCRUM-5
  assert_rc 1
  assert_eq "$OUT" "❌ Your FE login isn't saved in the Keychain
   Fix: Run /flow-configure-user fe-login-id (and fe-login-password), then run this again."
  assert_eq "$(fake_calls npx)" "" "nothing ran"
}

test_run_shows_each_test_each_ac_and_the_failed_calls_of_the_cards_apis() {
  setup_e2e; write_mixed_results
  printf '{"apis": [{"name": "scheme-detail", "method": "get", "base": "ws1", "path": "/api/v1/schemes/:id"}]}\n' > "$A/runs/SCRUM-5/e2e/api-list.json"
  run e2e.sh run SCRUM-5 --mock config-list,config-detail
  assert_rc 1
  assert_eq "$OUT" "   Running the Playwright tests of SCRUM-5 from runs/SCRUM-5/e2e/ (mocked: config-list,config-detail), time limit 900 s...
  ✅ AC 1 — list shows schemes
  ❌ AC 2 — filter by status
     Expected: 3
  ✅ AC 2 — filter resets
  ❌ AC 3 — export
     Timeout

  ✅ AC 1 passed (1 test(s))
  ❌ AC 2: 1 of 2 test(s) failed
  ❌ AC 3: 1 of 1 test(s) failed

❌ Playwright: 2 AC(s) failed, 1 passed

⚠️ API calls that failed on dev, in failing tests (ask the user whether each API is available on dev):
   GET /api/v1/schemes/6f1c2d3e-aaaa → 500   (AC 2)   · scheme-detail

   Other failed calls (not this card's APIs; shown only):
   GET /api/v1/other → no answer   (AC 2, 3)
   Mocked in this run: config-list, config-detail
   Screenshots and traces of failures: local/e2e-results/SCRUM-5/"
  assert_eq "$(npx_env E2E_TEST_DIR)" "$AR/runs/SCRUM-5/e2e"
  assert_eq "$(npx_env E2E_BASE_URL)" "http://localhost:${WEB##*:}"
  assert_eq "$(npx_env E2E_JSON)" "$AR/local/e2e-results/SCRUM-5.json"
  assert_eq "$(npx_env E2E_OUTPUT)" "$AR/local/e2e-results/SCRUM-5"
  assert_eq "$(npx_env E2E_MOCK_APIS)" "config-list,config-detail"
  assert_eq "$(npx_env E2E_LOGIN_ID) $(npx_env E2E_LOGIN_PASSWORD)" "fe.user fe-pass-9" "the FE login goes to the run as variables"
  assert_eq "$(fake_calls npx)" "npx playwright test --config playwright.config.ts"
  assert_not_contains "$OUT$(cat "$A/local/logs/e2e-SCRUM-5.log")$(fake_calls)" "fe-pass-9"
}

test_failed_calls_without_an_api_list_are_all_shown() {
  setup_e2e; write_mixed_results
  run e2e.sh run SCRUM-5
  assert_rc 1
  assert_contains "$OUT" "⚠️ API calls that failed on dev, in failing tests (ask the user whether each API is available on dev):
   GET /api/v1/other → no answer   (AC 2, 3)
   GET /api/v1/schemes/6f1c2d3e-aaaa → 500   (AC 2)
   Mocked in this run: config-list, config-detail"
  assert_not_contains "$OUT" "Other failed calls"
}

test_one_ac_every_test_passing() {
  setup_e2e
  printf '{"suites": [{"specs": [{"title": "AC 2 — a", "ok": true, "tests": []}, {"title": "smoke check", "ok": true}]}]}\n' > "$T/results.json"
  run e2e.sh run SCRUM-5 2
  assert_rc 0
  assert_eq "$OUT" "   Running the Playwright tests of SCRUM-5 (AC 2) from runs/SCRUM-5/e2e/, time limit 900 s...
  ✅ AC 2 — a
  ✅ smoke check

  ✅ AC 2 passed (1 test(s))
  ✅ AC ? passed (1 test(s))

✅ Playwright: every AC passed (2)
   Screenshots and traces of failures: local/e2e-results/SCRUM-5/"
  assert_eq "$(fake_calls npx)" "npx playwright test --config playwright.config.ts --grep AC 2 — "
}

test_a_run_without_any_test_or_without_results() {
  setup_e2e
  printf '{"suites": []}\n' > "$T/results.json"
  run e2e.sh run SCRUM-5 3
  assert_rc 1
  assert_contains "$OUT" "❌ Playwright ran no tests for AC 3
   Fix: check that each test title starts with \"AC <n> — \" (and that AC 3 has tests), then run it again."
  rm "$T/results.json"
  FAKE_NPX_RC=1 run e2e.sh run SCRUM-5
  assert_rc 1
  assert_contains "$OUT" "❌ Playwright gave no results (exit 1)
   Fix: Read local/logs/e2e-SCRUM-5.log (end below)."
  assert_contains "$OUT" "        playwright says hello"
}

test_a_run_stopped_at_its_time_limit() {
  setup_e2e
  FAKE_NPX_SLEEP=20 E2E_TIMEOUT=1 run e2e.sh run SCRUM-5
  assert_rc 1
  assert_contains "$OUT" "❌ The tests took longer than 1 seconds and were stopped
   Fix: Read local/logs/e2e-SCRUM-5.log, then run again."
}

test_quick_runs_the_one_off_tests_and_env_dev_the_dev_web_app() {
  setup_e2e
  mkdir -p "$A/local/quick-checks/SCRUM-5"
  printf "test('AC 1 — q', async () => {});\n" > "$A/local/quick-checks/SCRUM-5/q.spec.ts"
  printf '{"suites": [{"specs": [{"title": "AC 1 — q", "ok": true}]}]}\n' > "$T/results.json"
  printf 'VITE_PORT=1\n' > "$W/.env.development"
  run e2e.sh quick SCRUM-5 --env dev
  assert_rc 0
  assert_contains "$OUT" "   Running the Playwright tests of SCRUM-5 from local/quick-checks/SCRUM-5/ on dev, time limit 900 s..."
  assert_contains "$OUT" "Screenshots and traces of failures: local/e2e-results/SCRUM-5-quick-dev/"
  assert_eq "$(npx_env E2E_BASE_URL)" "https://dev-closio.test/home"
  assert_eq "$(npx_env E2E_TEST_DIR)" "$AR/local/quick-checks/SCRUM-5"
  assert_file "$RESULTS/SCRUM-5-quick-dev.json"
}

test_env_dev_without_a_dev_address() {
  setup_e2e
  sed -i '' '/^dev_base_url:/d' "$A/config/repos/closio-web-v2.yaml"
  run e2e.sh run SCRUM-5 --env dev
  assert_rc 1
  assert_eq "$OUT" "❌ The web app (closio-web-v2) has no dev address (dev_base_url)
   Fix: Run /flow-setup-repo closio-web-v2 dev-address (Codex: \$flow-setup-repo closio-web-v2 dev-address)."
}

# ---------------------------------------------------------------- probe

write_api_list() {
  printf '{"apis": [{"name": "scheme-list", "method": "GET", "base": "ws1", "path": "/api/v1/schemes"}]}\n' > "$1"
}

test_probe_every_api_answers() {
  setup_e2e; write_api_list "$A/runs/SCRUM-5/e2e/api-list.json"
  printf '✅\tscheme-list\tGET /api/v1/schemes\t200\n✅\tscheme-detail\tGET /api/v1/schemes/1\t200\n' > "$T/probe.txt"
  run e2e.sh probe SCRUM-5 --mock config-list
  assert_rc 0
  assert_eq "$OUT" "   Checking the card's GET APIs on dev before the run (mocked, not called: config-list)...
  ✅ scheme-list: GET /api/v1/schemes → 200
  ✅ scheme-detail: GET /api/v1/schemes/1 → 200
✅ Every GET API checked answers on dev"
  assert_eq "$(npx_env E2E_TEST_DIR)" "$AR/e2e/probe"
  assert_eq "$(npx_env E2E_API_LIST)" "$AR/runs/SCRUM-5/e2e/api-list.json"
  assert_eq "$(npx_env E2E_WEB_REPO)" "$W"
  assert_eq "$(npx_env E2E_PROBE_OUT)" "$AR/local/e2e-results/SCRUM-5-probe.txt"
  assert_eq "$(npx_env E2E_MOCK_APIS)" "config-list"
  assert_eq "$(npx_env E2E_LOGIN_ID)" "fe.user"
}

test_probe_with_an_api_that_looks_unavailable() {
  setup_e2e; write_api_list "$A/runs/SCRUM-5/e2e/api-list.json"
  printf '✅\tscheme-list\tGET /api/v1/schemes\t200\n⚠️\tscheme-export\tGET /api/v1/schemes/export\t404\n' > "$T/probe.txt"
  run e2e.sh probe SCRUM-5
  assert_rc 1
  assert_contains "$OUT" "  ⚠️ scheme-export: GET /api/v1/schemes/export → 404
⚠️ Some APIs look unavailable on dev: ask the user about each before the run (not available → mock it)"
}

test_probe_quick_on_dev() {
  setup_e2e
  mkdir -p "$A/local/quick-checks/SCRUM-5"; write_api_list "$A/local/quick-checks/SCRUM-5/api-list.json"
  printf '✅\tscheme-list\tGET /api/v1/schemes\t200\n' > "$T/probe.txt"
  run e2e.sh probe SCRUM-5 --quick --env dev
  assert_rc 0
  assert_eq "$(npx_env E2E_PROBE_OUT)" "$AR/local/e2e-results/SCRUM-5-quick-dev-probe.txt"
  assert_eq "$(npx_env E2E_BASE_URL)" "https://dev-closio.test/home"
}

test_probe_without_a_good_api_list() {
  setup_e2e
  run e2e.sh probe SCRUM-5
  assert_rc 2
  assert_eq "$OUT" "❌ No API list for SCRUM-5 (runs/SCRUM-5/e2e/api-list.json)
   Fix: flow-verify writes it first: the APIs the card's screens call (step 4)."
  printf '{"apis": {}}\n' > "$A/runs/SCRUM-5/e2e/api-list.json"
  run e2e.sh probe SCRUM-5
  assert_rc 2
  assert_eq "$OUT" "❌ runs/SCRUM-5/e2e/api-list.json isn't a valid API list
   Fix: It needs { \"apis\": [ { \"name\", \"method\", \"base\", \"path\" } ] }; write it again."
}

test_probe_needs_the_web_app_and_your_fe_login() {
  setup_e2e; write_api_list "$A/runs/SCRUM-5/e2e/api-list.json"
  printf 'local_path: not-cloned\n' > "$A/local/repos/closio-web-v2.yaml"
  run e2e.sh probe SCRUM-5
  assert_rc 1; assert_contains "$OUT" "❌ closio-web-v2 isn't cloned on this Mac"
  printf 'local_path: %s\n' "$W" > "$A/local/repos/closio-web-v2.yaml"
  sed -i '' '/^dev_base_url:/d' "$A/config/repos/closio-web-v2.yaml"
  run e2e.sh probe SCRUM-5 --env dev
  assert_rc 1; assert_contains "$OUT" "has no dev address"
  rm "$FAKE_KEYCHAIN/closio-agent.fe-login-id"
  run e2e.sh probe SCRUM-5
  assert_rc 1; assert_contains "$OUT" "❌ Your FE login isn't saved in the Keychain"
}

test_probe_that_does_not_finish() {
  setup_e2e; write_api_list "$A/runs/SCRUM-5/e2e/api-list.json"
  FAKE_NPX_RC=1 run e2e.sh probe SCRUM-5
  assert_rc 1
  assert_contains "$OUT" "❌ The API check didn't finish (exit 1)
   Fix: Read local/logs/e2e-SCRUM-5-probe.log (end below). Often the login: is the VPN on and is dev answering? (/flow-vpn status)"
  assert_contains "$OUT" "        playwright says hello"
}
