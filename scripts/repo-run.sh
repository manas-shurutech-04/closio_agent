#!/usr/bin/env bash
# Runs a registered repo's own commands, in its folder, on its own Node version (C3, flow-develop; rules A13, A6; D21, D65).
# Run it from the closio-agent folder:  bash scripts/repo-run.sh <repo> <action>
#
#   <repo> check               The repo's check commands (check_commands in config/repos/<repo>.yaml: lint, circular imports).
#                              A lint command checks only the files the card changed (since the base branch, uncommitted,
#                              new) and its problems are warnings (⚠️), never ❌ (D65): the repos have older lint errors.
#   <repo> test                The repo's tests and coverage gate: its coverage_command (runs every test and the gate in one
#                              go), or its test_command when it has none. A repo with test_command: none has no tests (D25).
#   <repo> migrate confirmed   npm run migrate (the repo's own script), against the database its .env names. Only after the
#                              user's yes in chat, every run (D21, D64); without the word "confirmed" it refuses.
#   <repo> seed confirmed      npm run seed, the same way.
#   <repo> start [--no-wait]   Starts the repo's server on this Mac in the background (its dev_command, on its Node version),
#                              and waits until its health URL answers (SERVER_START_TIMEOUT). Log: local/logs/server-<repo>.log
#                              (C4, flow-verify; D67). A server closio-agent started is reused while the repo's code is the
#                              same as when it started (its commit, its changes, its new files, the change time of its env
#                              file), and restarted when the code changed (D90). One started outside closio-agent is left as
#                              it is. --no-wait: starts it and returns at once; a later "start" waits for it (D90).
#   <repo> stop | all stop     Stops the server(s) this script started (never one it didn't start).
#   <repo> status              Whether the repo's server answers, and whether this script started it.
#   <repo> review              Codex only (flow-review, D78): Codex's own reviewer on the card's changes, run in the repo's
#                              folder against the MR's target branch (codex review --base origin/<target>); prints its review.
#                              In Claude Code, flow-review uses Claude Code's own code-review instead.
#
# Prints one ✅ / ❌ line per command, with the test counts; the full output goes to local/logs/repo-run-<repo>.log.
# Never reads or prints .env values (rule A6): the repo's own scripts load .env themselves. Never clones (D53), never commits.
# Exit codes: 0 everything passed · 1 ❌ · 2 wrong usage. Works in the Mac's own bash 3.2.

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
. "$AGENT_ROOT/scripts/lib/repo-info.sh"
LOGS_DIR="${LOGS_DIR:-$AGENT_ROOT/local/logs}"
SERVERS_DIR="${SERVERS_DIR:-$AGENT_ROOT/local/servers}"

failed=0
ok() { echo "✅ $1"; }
look() {
  echo "⚠️ $1"
  [ -n "${2:-}" ] && echo "   Tip: $2"
}
bad() {
  echo "❌ $1"
  echo "   Fix: $2"
  failed=1
}
info() { echo "   $1"; }
usage() { echo "Usage: bash scripts/repo-run.sh <repo> check | test | migrate confirmed | seed confirmed | start [--no-wait] | stop | status | review  (or: all stop)"; }

list_items() { printf '%s' "$1" | tr ',' '\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | grep -v -x 'none' | grep -v '^$'; }


# Runs a command string in the repo folder, on the repo's Node version, with a time limit (the same way as
# scripts/setup-repo.sh). Output goes to the log. Returns the command's exit code; 124 = time limit; 96–98 = setup.
# run_in_repo, last_output and result_lines live in scripts/lib/repo-info.sh (shared with ship.sh).
run_one() { # <label> <command>
  local label="$1" command="$2" rc
  run_in_repo "$PATH_" "$NV" "$REPO_RUN_TIMEOUT" "$LOG" "$command"
  rc=$?
  run_one_result "$rc" "$label" "$command"
}
run_one_result() { # <exit code> <label> <command>
  local rc="$1" label="$2" command="$3"
  case "$rc" in
    0) ok "$REPO: $label passed ($command)"; result_lines "$LOG" ;;
    124) bad "$REPO: $label took longer than $REPO_RUN_TIMEOUT seconds and was stopped ($command)" "Run it yourself to see why: cd \"$PATH_\" && nvm use $NV && $command. The limit is REPO_RUN_TIMEOUT in config/project-settings.sh." ;;
    96) bad "$REPO: couldn't go into $PATH_" "Check the clone is there: /flow-configure-repo $REPO path <folder>."; exit 1 ;;
    97) bad "$REPO: nvm couldn't be loaded" "Install nvm (setup guide, section 1), then run this again."; exit 1 ;;
    98) bad "$REPO: Node $NV (what $REPO is built for) isn't installed" "Run: nvm install $NV, then run this again."; exit 1 ;;
    *) bad "$REPO: $label failed ($command)" "Read the lines below (full output: local/logs/repo-run-$REPO.log), fix the cause, then run this again."
       result_lines "$LOG"
       last_output "$LOG" | tail -12 | sed 's/^/        /' ;;
  esac
  return 0
}

# The files the card changed in the repo that lint can read: committed on this branch since the base branch,
# uncommitted, and new; one per line, relative to the repo.
changed_files() {
  local base; base="$(yaml_get "$FILE" base_branch)"
  { [ -n "$base" ] && git -C "$PATH_" diff --name-only "origin/$base...HEAD" 2>/dev/null
    git -C "$PATH_" diff --name-only HEAD 2>/dev/null
    git -C "$PATH_" ls-files --others --exclude-standard 2>/dev/null
  } | sort -u | while IFS= read -r f; do
    [ -f "$PATH_/$f" ] || continue
    case "$f" in *.js|*.cjs|*.mjs|*.jsx|*.ts|*.tsx|*.vue) printf '%s\n' "$f" ;; esac
  done
}

# A lint command: only on the card's changed files, and its problems are warnings (D65)
run_lint() { # <command>
  local command="$1" files n=0 f args="" rc problems
  files="$(changed_files)"
  if [ -z "$files" ]; then ok "$REPO: lint has nothing to check (no changed code files yet)"; return 0; fi
  while IFS= read -r f; do
    n=$((n + 1))
    args="$args '$(printf '%s' "$f" | sed "s/'/'\\\\''/g")'"
  done <<EOF_FILES
$files
EOF_FILES
  case "$command" in "npm run "*) command="$command --$args" ;; *) command="$command$args" ;; esac
  run_in_repo "$PATH_" "$NV" "$REPO_RUN_TIMEOUT" "$LOG" "$command"
  rc=$?
  case "$rc" in
    0) ok "$REPO: lint passed on the $n file(s) the card changed" ;;
    96|97|98) run_one_result "$rc" "lint" "$command" ;;
    124) look "$REPO: lint took longer than $REPO_RUN_TIMEOUT seconds and was stopped (a warning)" "Run it yourself to see why: cd \"$PATH_\" && nvm use $NV && $command" ;;
    *) problems="$(last_output "$LOG" | grep -E '✖ [0-9]+ problem' | tail -1 | sed 's/^[[:space:]]*//')"
       look "$REPO: lint found problems in the $n file(s) the card changed: ${problems:-see below} (a warning, it doesn't stop anything)" "Tidy them in the card's own files if you can; older lint errors elsewhere in the repo are left alone."
       if [ -n "$problems" ]; then
         last_output "$LOG" | grep -E '^/|^[[:space:]]+[0-9]+:[0-9]+[[:space:]]+(error|warning)' | head -12 | sed 's/^/        /'
       else
         last_output "$LOG" | tail -8 | sed 's/^/        /'
       fi ;;
  esac
  return 0
}

# Finds the repo; sets REPO, FILE, PATH_, NV, LOG. Exits with a ❌ when something's missing.
locate() { # <repo>
  REPO="$1"
  printf '%s' "$REPO" | grep -q -E '^[a-z0-9][a-z0-9._-]*$' || { bad "'$REPO' isn't a repo name" "Use the name of a registered repo (see /flow-configure-repo)."; exit 1; }
  FILE="$REPOS_DIR/$REPO.yaml"
  [ -f "$FILE" ] || { bad "$REPO isn't registered" "Register it with /flow-configure-repo <path of your clone> (Codex: \$flow-configure-repo …)."; exit 1; }
  PATH_="$(yaml_get "$LOCAL_REPOS_DIR/$REPO.yaml" local_path)"
  if [ -z "$PATH_" ] || [ "$PATH_" = "not-cloned" ] || [ ! -d "$PATH_/.git" ]; then
    bad "$REPO isn't cloned on this Mac (cloning is manual)" "On the VPN: git clone $(yaml_get "$FILE" gitlab_url) <your workspace folder>/$REPO, then run /flow-configure-repo $REPO path <that folder>."
    exit 1
  fi
  NV=""
  case "$(yaml_get "$FILE" language)" in node|'') NV="$(yaml_get "$FILE" node_version)" ;; esac
  [ "$NV" = "none" ] && NV=""
  mkdir -p "$LOGS_DIR"
  LOG="$LOGS_DIR/repo-run-$REPO.log"
}

has_npm_script() { # <name>: the repo's package.json has this script
  [ -f "$PATH_/package.json" ] && grep -q -E "^[[:space:]]*\"$1\"[[:space:]]*:" "$PATH_/package.json"
}

# ---------------------------------------------------------------- servers (C4, D67)
pid_file() { echo "$SERVERS_DIR/$1.pid"; }
started_here() { # <repo>: the server this script started is still running
  local f; f="$(pid_file "$1")"
  [ -f "$f" ] && kill -0 "$(cat "$f")" 2>/dev/null
}
# The code a server runs: the repo's commit, its uncommitted changes and new files (never a .env file's content), and
# the change time of its env file. A server closio-agent started is reused only while this is the same (D90).
print_file() { echo "$SERVERS_DIR/$1.code"; }
code_print() {
  {
    git -C "$PATH_" rev-parse HEAD 2>/dev/null
    git -C "$PATH_" diff HEAD -- . ':(exclude,glob)**/.env' ':(exclude,glob)**/.env.*' 2>/dev/null
    git -C "$PATH_" ls-files -o --exclude-standard 2>/dev/null | grep -v -E '(^|/)\.env' | sort | while IFS= read -r f; do
      printf '%s ' "$f"; shasum < "$PATH_/$f" 2>/dev/null
    done
    stat -f %m "$PATH_/$(env_file_of "$REPO")" 2>/dev/null
  } | shasum | cut -d' ' -f1
}
wait_ready() { # <pid> <log>: waits until the server answers on its health URL
  local pid="$1" log="$2" waited=0
  info "$REPO: waiting up to $SERVER_START_TIMEOUT s for $(repo_health_path "$REPO")..."
  while [ "$waited" -lt "$SERVER_START_TIMEOUT" ]; do
    if ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$(pid_file "$REPO")" "$(print_file "$REPO")"
      bad "$REPO stopped while starting" "Read the end of local/logs/server-$REPO.log (below), fix the cause, then run this again."
      tail -12 "$log" | sed 's/^/        /'; return 0
    fi
    if repo_answers "$REPO"; then ok "$REPO is running and answers on $(repo_health_path "$REPO") (log: local/logs/server-$REPO.log)"; return 0; fi
    sleep 2; waited=$((waited + 2))
  done
  bad "$REPO didn't answer on $(repo_health_path "$REPO") within $SERVER_START_TIMEOUT s" "Read local/logs/server-$REPO.log (end below). The server is left running; stop it with: bash scripts/repo-run.sh $REPO stop"
  tail -12 "$log" | sed 's/^/        /'
}
do_start() { # [--no-wait]
  local nowait="${1:-}" cmd pid log print
  cmd="$(yaml_get "$FILE" dev_command)"; [ -n "$cmd" ] && [ "$cmd" != "none" ] || cmd="$(yaml_get "$FILE" start_command)"
  if [ -z "$cmd" ] || [ "$cmd" = "none" ]; then
    bad "$REPO has no dev_command or start_command in config/repos/$REPO.yaml" "Add one (e.g. dev_command: npm run dev) with /flow-configure-repo $REPO, then run this again."; return 0
  fi
  if ! repo_port "$REPO" >/dev/null || [ -z "$(repo_port "$REPO")" ]; then
    bad "$REPO: its port isn't set in its $(env_file_of "$REPO") ($(port_var "$REPO"))" "Set $(port_var "$REPO") in $PATH_/$(env_file_of "$REPO") (the value isn't shown here), then run this again."; return 0
  fi
  log="$LOGS_DIR/server-$REPO.log"
  print="$(code_print)"
  if started_here "$REPO"; then
    pid="$(cat "$(pid_file "$REPO")")"
    if [ "$(cat "$(print_file "$REPO")" 2>/dev/null)" = "$print" ]; then
      if repo_answers "$REPO"; then ok "$REPO is already running (started by closio-agent, on the same code): reused"; return 0; fi
      if [ "$nowait" = "--no-wait" ]; then ok "$REPO is still starting in the background"; return 0; fi
      wait_ready "$pid" "$log"; return 0
    fi
    info "$REPO: the code changed since closio-agent started its server: restarting it"
    do_stop "$REPO" >/dev/null
  elif repo_answers "$REPO"; then
    ok "$REPO is already running (started outside closio-agent; it's left as it is)"; return 0
  fi
  mkdir -p "$SERVERS_DIR" "$LOGS_DIR"
  printf '\n$ %s   (in %s, %s)\n' "$cmd" "$PATH_" "$(date '+%Y-%m-%d %H:%M:%S')" >> "$log"
  /usr/bin/perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV' -- /bin/bash -c '
    cd "$1" || exit 96
    if [ -n "$2" ]; then . "$3" >/dev/null 2>&1 || exit 97; nvm use "$2" >/dev/null 2>&1 || exit 98; fi
    exec /bin/bash -c "$4"' _ "$PATH_" "$NV" "$(nvm_sh)" "$cmd" >> "$log" 2>&1 < /dev/null &
  pid=$!
  echo "$pid" > "$(pid_file "$REPO")"
  echo "$print" > "$(print_file "$REPO")"
  info "$REPO: starting ($cmd)"
  if [ "$nowait" = "--no-wait" ]; then
    ok "$REPO: starting in the background; \"bash scripts/repo-run.sh $REPO start\" waits until it answers"; return 0
  fi
  wait_ready "$pid" "$log"
}
do_stop() { # <repo>
  local f pid; f="$(pid_file "$1")"
  if [ ! -f "$f" ]; then ok "$1: no server started by closio-agent"; return 0; fi
  pid="$(cat "$f")"
  if kill -0 "$pid" 2>/dev/null; then
    kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
    local n=0; while kill -0 "$pid" 2>/dev/null && [ "$n" -lt 10 ]; do sleep 1; n=$((n + 1)); done
    kill -0 "$pid" 2>/dev/null && { kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null; }
    ok "$1: server stopped"
  else
    ok "$1: the server had already stopped"
  fi
  rm -f "$f" "$(print_file "$1")"
}

# "all stop": every server this script started
if [ "${1:-}" = "all" ] && [ "${2:-}" = "stop" ]; then
  stopped=0
  for f in "$SERVERS_DIR"/*.pid; do [ -f "$f" ] && { do_stop "$(basename "$f" .pid)"; stopped=1; }; done
  [ "$stopped" -eq 1 ] || ok "No servers started by closio-agent are running"
  exit 0
fi

[ $# -ge 2 ] || { usage; exit 2; }
action="$2"
case "$action" in check|test|migrate|seed|start|stop|status|review) ;; *) usage; exit 2 ;; esac
if [ "$action" = "stop" ]; then
  printf '%s' "$1" | grep -q -E '^[a-z0-9][a-z0-9._-]*$' || { bad "'$1' isn't a repo name" "Use the name of a registered repo, or: bash scripts/repo-run.sh all stop"; exit 1; }
  do_stop "$1"; exit 0
fi
locate "$1"

case "$action" in
  check)
    [ $# -eq 2 ] || { usage; exit 2; }
    cmds="$(list_items "$(yaml_get "$FILE" check_commands)")"
    if [ -z "$cmds" ]; then
      ok "$REPO has no check commands (check_commands: none)"
    else
      while IFS= read -r c; do
        case "$c" in *lint*) run_lint "$c" ;; *) run_one "check" "$c" ;; esac
      done <<EOF_CMDS
$cmds
EOF_CMDS
    fi ;;
  test)
    [ $# -eq 2 ] || { usage; exit 2; }
    test_cmd="$(yaml_get "$FILE" test_command)"
    cov_cmd="$(yaml_get "$FILE" coverage_command)"
    if [ -z "$test_cmd" ] || [ "$test_cmd" = "none" ]; then
      ok "$REPO has no test suite, so no tests to write or run"
    elif [ -n "$cov_cmd" ] && [ "$cov_cmd" != "none" ]; then
      info "$REPO: every test and the coverage gate ($(yaml_get "$FILE" coverage_rules)) in one run, time limit $REPO_RUN_TIMEOUT s..."
      run_one "the tests and the coverage gate" "$cov_cmd"
    else
      info "$REPO: every test (no coverage command registered), time limit $REPO_RUN_TIMEOUT s..."
      run_one "the tests" "$test_cmd"
    fi ;;
  migrate|seed)
    if [ "${3:-}" != "confirmed" ] || [ $# -ne 3 ]; then
      bad "$REPO: '$action' needs the user's yes first" "Ask the user in chat, naming $REPO and what will run (npm run $action, against the database its .env names). Only after their yes: bash scripts/repo-run.sh $REPO $action confirmed"
      exit 1
    fi
    if ! has_npm_script "$action"; then
      bad "$REPO has no '$action' script in its package.json" "Nothing to run here: this repo has no migrations or seeders. If the card needs some, they go in a repo that has them."
      exit 1
    fi
    run_one "npm run $action" "npm run $action"
    [ "$failed" -eq 0 ] && info "Write this run in the card's develop.md (for the deployment doc)." ;;
  start) { [ $# -eq 2 ] || { [ $# -eq 3 ] && [ "$3" = "--no-wait" ]; }; } || { usage; exit 2; }; do_start "${3:-}" ;;
  status) [ $# -eq 2 ] || { usage; exit 2; }
    if repo_answers "$REPO"; then
      if started_here "$REPO"; then ok "$REPO is running (started by closio-agent)"; else ok "$REPO is running (started outside closio-agent)"; fi
    else
      look "$REPO isn't running" "Start it with: bash scripts/repo-run.sh $REPO start"
    fi ;;
  review) [ $# -eq 2 ] || { usage; exit 2; }
    command -v codex >/dev/null 2>&1 || { bad "Codex isn't installed here (this runs Codex's own reviewer)" "In Claude Code, /flow-review uses Claude Code's own code-review instead; for Codex, install it as the setup guide says."; exit 1; }
    target="$(yaml_get "$FILE" mr_target_branch)"; { [ -n "$target" ] && [ "$target" != "none" ]; } || target="$(yaml_get "$FILE" base_branch)"
    git -C "$PATH_" fetch -q origin 2>/dev/null || look "$REPO: couldn't fetch from GitLab; reviewing against the origin/$target this Mac already has" "Connect the VPN for the latest: /flow-vpn connect"
    info "$REPO: Codex's own review of the card's changes against origin/$target (time limit $REPO_RUN_TIMEOUT s)..."
    run_in_repo "$PATH_" "" "$REPO_RUN_TIMEOUT" "$LOG" "codex review --base $(printf '%q' "origin/$target")"; rc=$?
    if [ "$rc" -eq 0 ]; then ok "$REPO: Codex's review (below; check each point against the code before showing it):"; last_output "$LOG" | sed '1d; s/^/   /'
    else run_one_result "$rc" "Codex's review" "codex review --base origin/$target"; fi ;;
  *) usage; exit 2 ;;
esac

[ "$failed" -eq 0 ]
