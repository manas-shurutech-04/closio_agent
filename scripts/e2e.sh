#!/usr/bin/env bash
# closio-agent's Playwright tests for web cards (C4; D24, D67). Run it from the closio-agent folder:
#
#   bash scripts/e2e.sh check                 Is Playwright set up on this Mac? (only reads)
#   bash scripts/e2e.sh setup                 Installs the e2e/ project's packages and the Chromium browser (a download of
#                                             about 150 MB, about 430 MB on disk; flow-configure-user asks first). Log: local/logs/e2e-setup.log
#   bash scripts/e2e.sh run <CARD-KEY> [<AC>] Runs the card's tests in runs/<CARD-KEY>/e2e/ (or one AC's) against the web app
#                                             running on this Mac, logged in with your FE login from the Keychain
#   bash scripts/e2e.sh quick <CARD-KEY> [<AC>] The same for flow-verify's quick check (D68): its one-off tests in
#                                             local/quick-checks/<CARD-KEY>/ (on this Mac only, never saved or pushed)
#       … --mock <name,name>                  run/quick: turn on those mocks of the card's api-mocks.ts (the APIs the
#                                             user said aren't available on dev in this run; D69); every other API is real
#   bash scripts/e2e.sh probe <CARD-KEY> [--quick] [--mock <names>]
#                                             The API check before the run (D69): logs in once and calls each GET API of
#                                             the card's api-list.json that isn't mocked; ⚠️ for one that looks unavailable
#
# The FE login goes to the test run only (as variables of that run), never into a file, a command line or the chat (rule A6).
# Tests are titled "AC <n> — …". Prints ✅ / ❌ per test and per AC; no test run at all is a ❌; under failing tests, the API
# calls that got no answer or a 5xx from dev (e2e/fixtures.ts watches them). Exit codes: 0 fine · 1 ❌ · 2 wrong usage.
# closio-agent's own Node (22, rule A9) runs Playwright. Works in the Mac's own bash 3.2; needs jq.

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
. "$AGENT_ROOT/scripts/lib/repo-info.sh"
E2E_DIR="${E2E_DIR:-$AGENT_ROOT/e2e}"
RUNS_DIR="${RUNS_DIR:-$AGENT_ROOT/runs}"
LOGS_DIR="${LOGS_DIR:-$AGENT_ROOT/local/logs}"
RESULTS_DIR="${RESULTS_DIR:-$AGENT_ROOT/local/e2e-results}"
QUICK_DIR="${QUICK_DIR:-$AGENT_ROOT/local/quick-checks}"
PW_BROWSERS="${PLAYWRIGHT_BROWSERS_PATH:-$HOME/Library/Caches/ms-playwright}"

ok() { echo "✅ $1"; }
look() { echo "⚠️ $1"; [ -n "${2:-}" ] && echo "   Tip: $2"; }
bad() { echo "❌ $1"; echo "   Fix: $2"; }
usage() { echo "Usage: bash scripts/e2e.sh check | setup | run <CARD-KEY> [<AC number>] [--mock <names>] | quick <CARD-KEY> [<AC number>] [--mock <names>] | probe <CARD-KEY> [--quick] [--mock <names>]"; }
# SECURITY_BIN can be a stand-in for the build tests only (like BREW_BIN in setup-repo.sh); normally the macOS "security" tool.
keychain_get() { "${SECURITY_BIN:-security}" find-generic-password -a "$USER" -s "$1" -w 2>/dev/null; }

installed() { [ -f "$E2E_DIR/node_modules/@playwright/test/package.json" ] && ls -d "$PW_BROWSERS"/chromium-* >/dev/null 2>&1; }

# Runs a command in e2e/ on closio-agent's Node, with a time limit; output to the log. 124 = time limit.
run_e2e() { # <seconds> <log> <command>
  local limit="$1" log="$2" command="$3" pid waited=0
  printf '\n$ %s   (%s)\n' "$command" "$(date '+%Y-%m-%d %H:%M:%S')" >> "$log"
  /usr/bin/perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV' -- /bin/bash -c '
    cd "$1" || exit 96
    . "$2" >/dev/null 2>&1 || exit 97
    nvm use "$3" >/dev/null 2>&1 || exit 98
    eval "$4"' _ "$E2E_DIR" "$(nvm_sh)" "$NODE_MAJOR" "$command" >> "$log" 2>&1 < /dev/null &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "$limit" ]; then
      { kill -TERM -- "-$pid"; sleep 2; kill -KILL -- "-$pid"; wait "$pid"; } 2>/dev/null
      echo "closio-agent: stopped after $limit seconds (time limit)" >> "$log"; return 124
    fi
    sleep 1; waited=$((waited + 1))
  done
  wait "$pid"
}

do_check() {
  if installed; then ok "Playwright is set up (e2e/ packages and the Chromium browser)"; return 0; fi
  look "Playwright isn't set up yet (needed to check web cards)" "Run /flow-configure-user playwright (Codex: \$flow-configure-user playwright); it asks before the download."
  return 1
}

do_setup() {
  local log="$LOGS_DIR/e2e-setup.log" cmd rc
  mkdir -p "$LOGS_DIR"
  [ -f "$E2E_DIR/package.json" ] || { bad "e2e/package.json is missing" "It's part of closio-agent: git checkout -- e2e/ (or pull the latest closio-agent)."; return 1; }
  if [ -f "$E2E_DIR/package-lock.json" ]; then cmd="npm ci"; else cmd="npm install"; fi
  echo "   Installing the e2e/ packages ($cmd) and the Chromium browser, time limit $E2E_TIMEOUT s..."
  run_e2e "$E2E_TIMEOUT" "$log" "$cmd && npx playwright install chromium"; rc=$?
  case "$rc" in
    0) ok "Playwright is set up (e2e/ packages and the Chromium browser)" ;;
    124) bad "The setup took longer than $E2E_TIMEOUT seconds and was stopped" "Check your network, then run /flow-configure-user playwright again. Details: local/logs/e2e-setup.log"; return 1 ;;
    97|98) bad "nvm or Node $NODE_MAJOR isn't available" "Install nvm and Node $NODE_MAJOR (setup guide, section 1), then run /flow-configure-user playwright again."; return 1 ;;
    *) bad "The setup failed" "Read local/logs/e2e-setup.log (end below), fix the cause (often the network), then run /flow-configure-user playwright again."
       tail -10 "$log" | sed 's/^/        /'; return 1 ;;
  esac
}

do_run() { # <run|quick> <key> [<ac>] [<mock names>]
  local mode="$1" key="$2" one="${3:-}" mock="${4:-}" dir name where base id pw json log rc grep_args="" list apis
  printf '%s' "$key" | grep -q -E "^$JIRA_PROJECT_KEY-[0-9]+$" || { usage; return 2; }
  [ -z "$one" ] || printf '%s' "$one" | grep -q -E '^[0-9]+$' || { usage; return 2; }
  installed || { do_check; return 1; }
  if [ "$mode" = quick ]; then
    dir="$QUICK_DIR/$key"; name="$key-quick"; where="local/quick-checks/$key/"; list="$dir/api-list.json"
    ls "$dir"/*.spec.ts >/dev/null 2>&1 || { bad "No one-off Playwright tests in $where" "flow-verify's quick check writes them there first (/flow-verify $key quick)."; return 2; }
  else
    dir="$RUNS_DIR/$key/e2e"; name="$key"; where="runs/$key/e2e/"; list="$dir/api-list.json"
    ls "$dir"/*.spec.ts >/dev/null 2>&1 || { bad "No Playwright tests in $where" "/flow-verify $key writes them (or /flow-ac-check $key <AC> for one AC)."; return 2; }
  fi
  repo_ready "$WEB_REPO" || { bad "$REPO_PROBLEM" "Fix that first, then run this again."; return 1; }
  repo_answers "$WEB_REPO" || { bad "The web app ($WEB_REPO) isn't running on this Mac" "Start it: bash scripts/repo-run.sh $WEB_REPO start, then run this again."; return 1; }
  base="$(repo_base_url "$WEB_REPO")"
  id="$(keychain_get "$KEYCHAIN_PREFIX.fe-login-id")"; pw="$(keychain_get "$KEYCHAIN_PREFIX.fe-login-password")"
  if [ -z "$id" ] || [ -z "$pw" ]; then bad "Your FE login isn't saved in the Keychain" "Run /flow-configure-user fe-login-id (and fe-login-password), then run this again."; return 1; fi
  mkdir -p "$RESULTS_DIR" "$LOGS_DIR"
  json="$RESULTS_DIR/$name.json"; rm -f "$json"; log="$LOGS_DIR/e2e-$name.log"
  # Playwright matches --grep against "<project> <file> <title>", so the AC is found inside that text, not at its start.
  [ -n "$one" ] && grep_args=" --grep \"AC $one — \""
  echo "   Running the Playwright tests of $key${one:+ (AC $one)} from $where${mock:+ (mocked: $mock)}, time limit $E2E_TIMEOUT s..."
  E2E_TEST_DIR="$dir" E2E_BASE_URL="$base" E2E_JSON="$json" E2E_OUTPUT="$RESULTS_DIR/$name" E2E_MOCK_APIS="$mock" \
  E2E_LOGIN_ID="$id" E2E_LOGIN_PASSWORD="$pw" \
    run_e2e "$E2E_TIMEOUT" "$log" "npx playwright test --config playwright.config.ts$grep_args"; rc=$?
  id=""; pw=""
  if [ "$rc" -eq 124 ]; then bad "The tests took longer than $E2E_TIMEOUT seconds and were stopped" "Read local/logs/e2e-$name.log, then run again."; return 1; fi
  if [ ! -s "$json" ]; then bad "Playwright gave no results (exit $rc)" "Read local/logs/e2e-$name.log (end below)."; tail -12 "$log" | sed 's/^/        /'; return 1; fi
  # one line per test: AC number, title, result, first line of the error
  jq -r '
    def specs: (.suites // [])[] | recurse(.suites[]?) | (.specs // [])[];
    [specs | {title: .title, ok: (.ok // false),
              err: ([.tests[]?.results[]?.error?.message // empty] | first // "" | gsub("\u001b\\[[0-9;]*m"; "") | split("\n")[0]),
              notes: [.tests[]? | ((.annotations // [])[]), ((.results // [])[] | (.annotations // [])[])]}]
    | .[] | "\(if .ok then "✅" else "❌" end)\t\(.title)\t\(.err)\t\([.notes[] | select(.type == "api-failed") | .description] | unique | join(" | "))\t\([.notes[] | select(.type == "api-mocked") | .description] | unique | join(","))"' "$json" > "$RESULTS_DIR/$name.lines"
  # The card's APIs (api-list.json): "METHOD<TAB>path<TAB>name", to tell its failed calls from other screens' (D69).
  apis="$RESULTS_DIR/$name.apis"; : > "$apis"
  [ -f "$list" ] && jq -r '.apis[]? | "\(.method | ascii_upcase)\t\(.path)\t\(.name)"' "$list" > "$apis" 2>/dev/null
  awk -F '\t' -v one="$one" -v apis="$apis" '
    function norm(p,   n, i, seg, out) { n = split(p, seg, "/"); out = ""
      for (i = 2; i <= n; i++) out = out "/" ((seg[i] ~ /^[0-9a-fA-F-]{8,}$/ || seg[i] ~ /^[0-9]+$/) ? ":id" : seg[i]); return out }
    function owner(call,   m, p, i) { m = call; sub(/ .*/, "", m); p = call; sub(/^[A-Z]+ /, "", p); sub(/ → .*/, "", p); p = norm(p)
      for (i = 1; i <= na; i++) if (am[i] == m && length(p) >= length(ap[i]) && substr(p, length(p) - length(ap[i]) + 1) == ap[i]) return an[i]; return "" }
    BEGIN { while ((getline l < apis) > 0) { split(l, x, "\t"); na++; am[na] = x[1]; ap[na] = norm(x[2]); an[na] = x[3] } }
    { ac = $2; sub(/^AC /, "", ac); sub(/[^0-9].*$/, "", ac); if (ac == "") ac = "?";
      print "  " $1 " " $2; if ($1 == "❌" && $3 != "") print "     " substr($3, 1, 300);
      if ($1 == "❌" && $4 != "") { nn = split($4, calls, / \| /); for (c = 1; c <= nn; c++) { if (!(calls[c] in acs)) { acs[calls[c]] = ac; corder[++nc] = calls[c] } else if (index(" " acs[calls[c]] ",", " " ac ",") == 0 && acs[calls[c]] !~ ("(^|, )" ac "$")) acs[calls[c]] = acs[calls[c]] ", " ac } }
      if ($5 != "") { nm2 = split($5, ms, ","); for (c = 1; c <= nm2; c++) if (!(ms[c] in mocked)) { mocked[ms[c]] = 1; morder[++nm] = ms[c] } }
      n[ac]++; if ($1 == "✅") p[ac]++; if (!(ac in seen)) { seen[ac] = 1; order[++k] = ac } }
    END { if (k == 0) { print "❌ Playwright ran no tests" (one != "" ? " for AC " one : ""); print "   Fix: check that each test title starts with \"AC <n> — \" (and that AC " (one != "" ? one : "<n>") " has tests), then run it again."; exit 1 }
      print ""; fails = 0; okc = 0;
      for (i = 1; i <= k; i++) { a = order[i];
        if (p[a] == n[a]) { print "  ✅ AC " a " passed (" n[a] " test(s))"; okc++ }
        else { print "  ❌ AC " a ": " n[a] - p[a] " of " n[a] " test(s) failed"; fails++ } }
      print ""; if (fails == 0) print "✅ Playwright: every AC passed (" okc ")"; else print "❌ Playwright: " fails " AC(s) failed, " okc " passed";
      if (nc > 0) { mine = ""; other = ""
        for (c = 1; c <= nc; c++) { o = (na > 0) ? owner(corder[c]) : "?"; ln = "   " corder[c] "   (AC " acs[corder[c]] ")"
          if (o == "") other = other ln "\n"; else mine = mine ln (o != "?" ? "   · " o : "") "\n" }
        if (mine != "") { print ""; print "⚠️ API calls that failed on dev, in failing tests (ask the user whether each API is available on dev):"; printf "%s", mine }
        if (other != "") { print ""; print "   Other failed calls (not this card'"'"'s APIs; shown only):"; printf "%s", other } }
      if (nm > 0) { line = ""; for (c = 1; c <= nm; c++) line = line (c > 1 ? ", " : "") morder[c]; print "   Mocked in this run: " line }
      exit (fails > 0) }' "$RESULTS_DIR/$name.lines"
  rc=$?
  echo "   Screenshots and traces of failures: local/e2e-results/$name/"
  return "$rc"
}

do_probe() { # <key> <quick: 1 or empty> <mock names>
  local key="$1" quick="$2" mock="$3" list name base id pw out log rc
  printf '%s' "$key" | grep -q -E "^$JIRA_PROJECT_KEY-[0-9]+$" || { usage; return 2; }
  installed || { do_check; return 1; }
  if [ -n "$quick" ]; then list="$QUICK_DIR/$key/api-list.json"; name="$key-quick"; else list="$RUNS_DIR/$key/e2e/api-list.json"; name="$key"; fi
  [ -f "$list" ] || { bad "No API list for $key (${list#"$AGENT_ROOT"/})" "flow-verify writes it first: the APIs the card's screens call (step 4)."; return 2; }
  jq -e '.apis | type == "array"' "$list" >/dev/null 2>&1 || { bad "${list#"$AGENT_ROOT"/} isn't a valid API list" "It needs { \"apis\": [ { \"name\", \"method\", \"base\", \"path\" } ] }; write it again."; return 2; }
  repo_ready "$WEB_REPO" || { bad "$REPO_PROBLEM" "Fix that first, then run this again."; return 1; }
  repo_answers "$WEB_REPO" || { bad "The web app ($WEB_REPO) isn't running on this Mac" "Start it: bash scripts/repo-run.sh $WEB_REPO start, then run this again."; return 1; }
  base="$(repo_base_url "$WEB_REPO")"
  id="$(keychain_get "$KEYCHAIN_PREFIX.fe-login-id")"; pw="$(keychain_get "$KEYCHAIN_PREFIX.fe-login-password")"
  if [ -z "$id" ] || [ -z "$pw" ]; then bad "Your FE login isn't saved in the Keychain" "Run /flow-configure-user fe-login-id (and fe-login-password), then run this again."; return 1; fi
  mkdir -p "$RESULTS_DIR" "$LOGS_DIR"
  out="$RESULTS_DIR/$name-probe.txt"; rm -f "$out"; log="$LOGS_DIR/e2e-$name-probe.log"
  echo "   Checking the card's GET APIs on dev before the run${mock:+ (mocked, not called: $mock)}..."
  E2E_TEST_DIR="$E2E_DIR/probe" E2E_BASE_URL="$base" E2E_JSON="$RESULTS_DIR/$name-probe.json" E2E_OUTPUT="$RESULTS_DIR/$name-probe" \
  E2E_API_LIST="$list" E2E_WEB_REPO="$(repo_path "$WEB_REPO")" E2E_PROBE_OUT="$out" E2E_MOCK_APIS="$mock" \
  E2E_LOGIN_ID="$id" E2E_LOGIN_PASSWORD="$pw" \
    run_e2e 300 "$log" "npx playwright test --config playwright.config.ts"; rc=$?
  id=""; pw=""
  if [ ! -s "$out" ]; then bad "The API check didn't finish (exit $rc)" "Read local/logs/e2e-$name-probe.log (end below). Often the login: is the VPN on and is dev answering? (/flow-vpn status)"; tail -12 "$log" | sed 's/^/        /'; return 1; fi
  awk -F '\t' '{ print "  " $1 " " $2 ": " $3 " → " $4 }' "$out"
  if grep -q '^⚠️' "$out"; then
    echo "⚠️ Some APIs look unavailable on dev: ask the user about each before the run (not available → mock it)"; return 1
  fi
  ok "Every GET API checked answers on dev"; return 0
}

case "${1:-}" in
  check) do_check ;;
  setup) do_setup ;;
  run|quick|probe)
    act="$1"; shift; [ $# -ge 1 ] || { usage; exit 2; }; k="$1"; shift; ac=""; mock=""; q=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --mock) [ $# -ge 2 ] || { usage; exit 2; }; mock="$2"; shift 2 ;;
        --quick) [ "$act" = probe ] || { usage; exit 2; }; q=1; shift ;;
        *) [ "$act" != probe ] && [ -z "$ac" ] || { usage; exit 2; }; ac="$1"; shift ;;
      esac
    done
    [ -z "$mock" ] || printf '%s' "$mock" | grep -q -E '^[A-Za-z0-9_,-]+$' || { bad "Mock names may only have letters, digits, - and _ (comma between names)" "Use the names in the card's api-mocks.ts, e.g. --mock config-detail,config-list"; exit 2; }
    if [ "$act" = probe ]; then do_probe "$k" "$q" "$mock"; else do_run "$act" "$k" "$ac" "$mock"; fi ;;
  *) usage; exit 2 ;;
esac
