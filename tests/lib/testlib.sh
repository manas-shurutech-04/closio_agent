# The helpers every test uses (D92). Loaded by tests/run.sh before a test file; each test_ function runs in its own
# subshell, so what it sets ends with it.
#
#   sandbox [<path>…]       A throwaway closio-agent folder ($A, "closio agent", inside $T, which has a space too) with
#                           scripts/ and config/ copied, plus the repo paths given (e.g. rulesets docs/agent-rules.md).
#                           HOME, the Keychain, nvm and the outside tools are stand-ins (tests/fakes): nothing real is
#                           touched. Removed when the test ends.
#   sandbox_git             $A becomes a git repo with one commit on main (a test name and email)
#   sandbox_remote          …and gets a bare "origin" ($T/origin.git) with main pushed
#   run <script> [args…]    Runs bash scripts/<script> in $A; sets OUT (stdout and stderr) and RC
#   run_in <dir> <cmd…>     The same for any command, in <dir>
#   fake_cmd <name> <body>  What the stand-in <name> does in this test (a bash body; "$@" are its arguments)
#   fake_calls [<name>]     The stand-in calls made so far (all, or one tool's), one per line
#   keychain_set <service> <value> / keychain_has <service>   The fake Keychain
#   start_fake <var> <server> [args…]  Starts tests/fakes/<server>.py on a free port; sets <var> to its http://… URL
#   fake_requests <var>     The requests that fake server received, one JSON line each
#   assert_eq <actual> <expected> [what] · assert_contains <text> <part> [what] · assert_not_contains …
#   assert_match <text> <regex> [what] · assert_rc <code> · assert_file <path> · assert_no_file <path> · fail <why>

TESTS_DIR="${TESTS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
CLOSIO_ROOT="${CLOSIO_ROOT:-$(cd "$TESTS_DIR/.." && pwd -P)}"

fail() { printf '  ✗ %s\n' "$*"; exit 1; }
assert_eq() {
  [ "$1" = "$2" ] && return 0
  printf '  ✗ %s\n    expected: %s\n    actual:   %s\n' "${3:-not equal}" "$2" "$1"; exit 1
}
assert_contains() {
  case "$1" in *"$2"*) return 0 ;; esac
  printf '  ✗ %s\n    expected to contain: %s\n    actual:\n%s\n' "${3:-missing text}" "$2" "$(printf '%s' "$1" | sed 's/^/      /' | head -40)"; exit 1
}
assert_not_contains() {
  case "$1" in *"$2"*) printf '  ✗ %s\n    expected NOT to contain: %s\n    actual:\n%s\n' "${3:-unexpected text}" "$2" "$(printf '%s' "$1" | sed 's/^/      /' | head -40)"; exit 1 ;; esac
  return 0
}
assert_match() {
  printf '%s' "$1" | grep -q -E -- "$2" && return 0
  printf '  ✗ %s\n    expected to match: %s\n    actual:\n%s\n' "${3:-no match}" "$2" "$(printf '%s' "$1" | sed 's/^/      /' | head -40)"; exit 1
}
assert_rc() {
  [ "$RC" = "$1" ] && return 0
  printf '  ✗ exit code %s, expected %s\n    output:\n%s\n' "$RC" "$1" "$(printf '%s' "${OUT:-}" | sed 's/^/      /' | head -40)"; exit 1
}
assert_file() { [ -e "$1" ] || fail "missing: $1"; }
assert_no_file() { [ ! -e "$1" ] || fail "should not exist: $1"; }

sandbox_cleanup() {
  local p
  for p in $(cat "$T/.fake-pids" 2>/dev/null); do kill "$p" 2>/dev/null; done
  [ -n "${T:-}" ] && [ -d "$T" ] && chmod -R u+w "$T" 2>/dev/null; rm -rf "$T" 2>/dev/null
}

sandbox() {
  T="$(mktemp -d "${TMPDIR:-/tmp}/closio test.XXXXXX")" || fail "no temp folder"
  A="$T/closio agent"
  mkdir -p "$A" "$T/home" "$T/keychain" "$T/fake-cmds"
  trap sandbox_cleanup EXIT
  cp -R "$CLOSIO_ROOT/scripts" "$CLOSIO_ROOT/config" "$A/"
  local p
  for p in "$@"; do
    mkdir -p "$A/$(dirname "$p")"
    cp -R "$CLOSIO_ROOT/$p" "$A/$p"
  done
  export HOME="$T/home"
  export NVM_DIR="$TESTS_DIR/fakes/nvm"
  export PATH="$TESTS_DIR/fakes/bin:$PATH"
  export FAKE_KEYCHAIN="$T/keychain" FAKE_CMDS="$T/fake-cmds" FAKE_LOG="$T/fake-calls.log"
  export GIT_AUTHOR_NAME=tester GIT_AUTHOR_EMAIL=tester@example.com GIT_COMMITTER_NAME=tester GIT_COMMITTER_EMAIL=tester@example.com
  export GIT_CONFIG_NOSYSTEM=1 NO_COLOR=1 TERM=dumb
  unset CLAUDE_PROJECT_DIR GITLAB_TOKEN 2>/dev/null
  : > "$FAKE_LOG"
  if [ -n "${COV_FILE:-}" ]; then export BASH_ENV="$TESTS_DIR/lib/coverage-env.sh"; fi
}

sandbox_git() {
  git init -q -b main "$A" && git -C "$A" add -A && git -C "$A" commit -q -m init || fail "git init in the sandbox"
}
sandbox_remote() {
  git init -q --bare "$T/origin.git" && git -C "$A" remote add origin "$T/origin.git" && git -C "$A" push -q origin main 2>/dev/null ||
    fail "the sandbox's origin"
}

run() { local s="$1"; shift; OUT="$(cd "$A" && bash "scripts/$s" "$@" 2>&1)"; RC=$?; }
run_in() { local d="$1"; shift; OUT="$(cd "$d" && "$@" 2>&1)"; RC=$?; }

fake_cmd() { # <name> <bash body>
  printf '#!/bin/bash\n%s\n' "$2" > "$FAKE_CMDS/$1"; chmod +x "$FAKE_CMDS/$1"
}
fake_calls() { if [ -n "${1:-}" ]; then grep "^$1 " "$FAKE_LOG" 2>/dev/null; else cat "$FAKE_LOG" 2>/dev/null; fi; }

keychain_set() { printf '%s' "$2" > "$FAKE_KEYCHAIN/$1"; }
keychain_has() { [ -f "$FAKE_KEYCHAIN/$1" ]; }

start_fake() { # <var> <server> [args…]
  local var="$1" server="$2" pf="$T/.fake-$1.port" i=0 port
  shift 2
  ( python3 -I "$TESTS_DIR/fakes/$server.py" "$pf" "$T/.fake-$var.log" "$@" > "$T/.fake-$var.out" 2>&1 &
    echo $! >> "$T/.fake-pids" )
  while [ ! -s "$pf" ] && [ "$i" -lt 100 ]; do sleep 0.05; i=$((i + 1)); done
  port="$(cat "$pf" 2>/dev/null)"
  [ -n "$port" ] || fail "the fake $server didn't start: $(cat "$T/.fake-$var.out")"
  eval "export $var=\"http://127.0.0.1:$port\""
}
fake_requests() { cat "$T/.fake-$1.log" 2>/dev/null; }

# A user settings file in the sandbox (local/user-settings.sh), from KEY=value arguments
user_settings() { mkdir -p "$A/local"; : > "$A/local/user-settings.sh"; local kv; for kv in "$@"; do printf '%s="%s"\n' "${kv%%=*}" "${kv#*=}" >> "$A/local/user-settings.sh"; done; }
