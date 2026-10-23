# scripts/repo-run.sh: a registered repo's own commands (checks, tests, migrate/seed with "confirmed"), its server on
# this Mac (start with --no-wait and the code-fingerprint reuse, stop, status) and Codex's review. The repos are git
# repos in $T; npm, nvm and codex are stand-ins; the servers are real python3 http.servers on free ports, always stopped
# when the test ends.

register_repo() { # <name> <folder> [<yaml line>…]
  local name="$1" dir="$2" l; shift 2
  mkdir -p "$dir" "$A/local/repos"
  printf 'name: %s\n' "$name" > "$A/config/repos/$name.yaml"
  for l in "$@"; do printf '%s\n' "$l" >> "$A/config/repos/$name.yaml"; done
  printf 'local_path: %s\n' "$dir" > "$A/local/repos/$name.yaml"
}
free_port() { python3 -I -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()'; }

# make_repo <name> [<yaml line>…]: a git repo on develop (package.json with a migrate script, app.js, .env ignored),
# registered in the sandbox; sets R
make_repo() {
  local name="$1"; shift
  R="$T/repos/$name repo"
  mkdir -p "$R"
  git init -q -b develop "$R"
  printf 'node_modules/\n.env\n' > "$R/.gitignore"
  printf '{\n  "name": "%s",\n  "scripts": {\n    "migrate": "sequelize-cli db:migrate",\n    "test": "mocha"\n  }\n}\n' "$name" > "$R/package.json"
  echo "one" > "$R/app.js"
  git -C "$R" add -A && git -C "$R" commit -q -m init
  register_repo "$name" "$R" "gitlab_url: https://gitlab.test/$name.git" "$@"
}

setup_run() {
  sandbox
  trap '(cd "$A" && bash scripts/repo-run.sh all stop) >/dev/null 2>&1; sandbox_cleanup' EXIT
  LOG_DIR="$A/local/logs"; SRV="$A/local/servers"
}
setup_node_repo() { # [<yaml line>…]: the repo "fake" on Node 18.20.8 (the fake nvm)
  setup_run
  make_repo fake "language: node" "node_version: 18.20.8   # from the Dockerfile" "base_branch: develop" "$@"
  LOG="$LOG_DIR/repo-run-fake.log"
}
# The repo "web": a python3 http.server on a free port as its dev_command; sets PORT
setup_server_repo() {
  setup_run
  make_repo web "language: python" "port: from the repo's .env (PORT)" "health_url: /" \
    "dev_command: exec python3 -m http.server \$(grep '^PORT=' .env | cut -d= -f2) --bind 127.0.0.1"
  PORT="$(free_port)"
  printf 'PORT=%s\n' "$PORT" > "$R/.env"
}
pid_of() { cat "$SRV/$1.pid" 2>/dev/null; }

# ---------------------------------------------------------------- usage and the repo

test_wrong_usage_shows_the_usage() {
  setup_node_repo
  local args
  for args in "" "fake" "fake deploy" "fake check x" "fake test x" "fake status x" "fake review x" "fake start --wait" \
    "fake start --no-wait x"; do
    run repo-run.sh $args
    assert_rc 2
    assert_eq "$OUT" "Usage: bash scripts/repo-run.sh <repo> check | test | migrate confirmed | seed confirmed | start [--no-wait] | stop | status | review  (or: all stop)" "usage for: $args"
  done
}

test_a_repo_that_is_not_a_name_not_registered_or_not_cloned() {
  setup_node_repo
  run repo-run.sh Bad_Name check
  assert_rc 1; assert_eq "$OUT" "❌ 'Bad_Name' isn't a repo name
   Fix: Use the name of a registered repo (see /flow-configure-repo)."
  run repo-run.sh nope test
  assert_rc 1; assert_contains "$OUT" "❌ nope isn't registered"
  printf 'local_path: not-cloned\n' > "$A/local/repos/fake.yaml"
  run repo-run.sh fake test
  assert_rc 1
  assert_eq "$OUT" "❌ fake isn't cloned on this Mac (cloning is manual)
   Fix: On the VPN: git clone https://gitlab.test/fake.git <your workspace folder>/fake, then run /flow-configure-repo fake path <that folder>."
}

# ---------------------------------------------------------------- check

test_check_without_check_commands() {
  setup_node_repo "check_commands: none"
  run repo-run.sh fake check
  assert_rc 0; assert_eq "$OUT" "✅ fake has no check commands (check_commands: none)"
}

test_check_runs_a_command_on_the_repos_node_and_logs_it() {
  setup_node_repo "check_commands: npm run check:circular"
  fake_cmd npm 'echo "no circular imports in $(basename "$PWD")"'
  run repo-run.sh fake check
  assert_rc 0
  assert_eq "$OUT" "✅ fake: check passed (npm run check:circular)"
  assert_contains "$(fake_calls nvm)" "nvm use 18.20.8"
  assert_eq "$(fake_calls npm)" "npm run check:circular"
  assert_contains "$(cat "$LOG")" "\$ npm run check:circular   (in $R, "
  assert_contains "$(cat "$LOG")" "no circular imports in fake repo"
}

test_a_failing_check_shows_the_end_of_its_output() {
  setup_node_repo "check_commands: npm run check:circular"
  fake_cmd npm 'echo "Found 1 circular dependency"; echo "src/a.js > src/b.js"; exit 1'
  run repo-run.sh fake check
  assert_rc 1
  assert_eq "$OUT" "❌ fake: check failed (npm run check:circular)
   Fix: Read the lines below (full output: local/logs/repo-run-fake.log), fix the cause, then run this again.
        \$ npm run check:circular   (in $R, $(sed -n 's/.*(in .*, \(.*\))$/\1/p' "$LOG" | tail -1))
        Found 1 circular dependency
        src/a.js > src/b.js"
}

test_lint_without_changed_files_has_nothing_to_check() {
  setup_node_repo "check_commands: npm run lint"
  run repo-run.sh fake check
  assert_rc 0; assert_eq "$OUT" "✅ fake: lint has nothing to check (no changed code files yet)"
  assert_eq "$(fake_calls npm)" "" "lint not run"
}

test_lint_checks_only_the_code_files_the_card_changed() {
  setup_node_repo "check_commands: npm run lint, npm run check:circular"
  git init -q --bare "$T/origin.git"; git -C "$R" remote add origin "$T/origin.git"; git -C "$R" push -q origin develop 2>/dev/null
  git -C "$R" checkout -q -b SCRUM-1/x
  mkdir -p "$R/lib"; echo "f" > "$R/lib/feature.js"; git -C "$R" add -A; git -C "$R" commit -q -m feature
  echo "two" >> "$R/app.js"; echo "n" > "$R/new.ts"; echo "q" > "$R/it's.vue"; echo "doc" > "$R/notes.md"
  run repo-run.sh fake check
  assert_rc 0
  assert_eq "$OUT" "✅ fake: lint passed on the 4 file(s) the card changed
✅ fake: check passed (npm run check:circular)"
  assert_eq "$(fake_calls npm | head -1)" "npm run lint -- app.js it's.vue lib/feature.js new.ts"
}

test_lint_problems_are_warnings_with_their_lines() {
  setup_node_repo "check_commands: npm run lint"
  echo "two" >> "$R/app.js"
  fake_cmd npm 'echo "> lint"; echo "/repo/app.js"; echo "  2:1  error  Unexpected var  no-var"; echo "  3:1  warning  x  y"; echo "✖ 2 problems (1 error, 1 warning)"; exit 1'
  run repo-run.sh fake check
  assert_rc 0
  assert_eq "$OUT" "⚠️ fake: lint found problems in the 1 file(s) the card changed: ✖ 2 problems (1 error, 1 warning) (a warning, it doesn't stop anything)
   Tip: Tidy them in the card's own files if you can; older lint errors elsewhere in the repo are left alone.
        /repo/app.js
          2:1  error  Unexpected var  no-var
          3:1  warning  x  y"
}

test_lint_failing_without_a_summary_shows_its_last_lines() {
  setup_node_repo "check_commands: npx eslint"
  echo "n" > "$R/new.js"
  fake_cmd npx 'echo "eslint: config not found"; exit 2'
  run repo-run.sh fake check
  assert_rc 0
  assert_contains "$OUT" "⚠️ fake: lint found problems in the 1 file(s) the card changed: see below (a warning, it doesn't stop anything)"
  assert_contains "$OUT" "        eslint: config not found"
  assert_eq "$(fake_calls npx)" "npx eslint new.js"
}

test_lint_stopped_at_the_time_limit_is_a_warning() {
  setup_node_repo "check_commands: npm run lint"
  echo "n" > "$R/new.js"
  fake_cmd npm 'sleep 20'
  REPO_RUN_TIMEOUT=1 run repo-run.sh fake check
  assert_rc 0
  assert_eq "$OUT" "⚠️ fake: lint took longer than 1 seconds and was stopped (a warning)
   Tip: Run it yourself to see why: cd \"$R\" && nvm use 18.20.8 && npm run lint -- 'new.js'"
}

test_lint_without_the_repos_node_stops() {
  setup_node_repo "check_commands: npm run lint, npm run check:circular"
  echo "n" > "$R/new.js"
  FAKE_NVM_MISSING=18.20.8 run repo-run.sh fake check
  assert_rc 1
  assert_eq "$OUT" "❌ fake: Node 18.20.8 (what fake is built for) isn't installed
   Fix: Run: nvm install 18.20.8, then run this again."
  assert_eq "$(fake_calls npm)" "" "nothing ran"
}

# ---------------------------------------------------------------- test

test_a_repo_without_tests() {
  setup_node_repo "test_command: none"
  run repo-run.sh fake test
  assert_rc 0; assert_eq "$OUT" "✅ fake has no test suite, so no tests to write or run"
}

test_the_coverage_command_runs_every_test_and_the_gate() {
  setup_node_repo "test_command: npm test" "coverage_command: npm run test:coverage" "coverage_rules: lines:80 branches:70"
  fake_cmd npm 'echo "  12 passing (3s)"; echo "  1 pending"; echo "Statements   : 91.2% ( 100/110 )"; echo "Lines        : 90% ( 90/100 )"'
  run repo-run.sh fake test
  assert_rc 0
  assert_eq "$OUT" "   fake: every test and the coverage gate (lines:80 branches:70) in one run, time limit 900 s...
✅ fake: the tests and the coverage gate passed (npm run test:coverage)
   12 passing (3s)
   1 pending
   Statements   : 91.2% ( 100/110 )
   Lines        : 90% ( 90/100 )"
  assert_eq "$(fake_calls npm)" "npm run test:coverage"
}

test_failing_tests_show_the_counts_and_the_end_of_the_output() {
  setup_node_repo "test_command: npm test -- --run" "coverage_command: none"
  fake_cmd npm 'echo " Test Files  1 failed (3)"; echo "      Tests  2 failed | 10 passed (12)"; echo "FAIL src/a.test.ts"; exit 1'
  run repo-run.sh fake test
  assert_rc 1
  assert_contains "$OUT" "   fake: every test (no coverage command registered), time limit 900 s...
❌ fake: the tests failed (npm test -- --run)
   Fix: Read the lines below (full output: local/logs/repo-run-fake.log), fix the cause, then run this again.
   Test Files  1 failed (3)
   Tests  2 failed | 10 passed (12)"
  assert_contains "$OUT" "        FAIL src/a.test.ts"
}

test_tests_stopped_at_the_time_limit() {
  setup_node_repo "test_command: npm test"
  fake_cmd npm 'sleep 20'
  REPO_RUN_TIMEOUT=1 run repo-run.sh fake test
  assert_rc 1
  assert_contains "$OUT" "❌ fake: the tests took longer than 1 seconds and was stopped (npm test)
   Fix: Run it yourself to see why: cd \"$R\" && nvm use 18.20.8 && npm test. The limit is REPO_RUN_TIMEOUT in config/project-settings.sh."
  assert_contains "$(cat "$LOG")" "closio-agent: stopped after 1 seconds (time limit)"
}

test_the_setup_failures_stop_with_their_own_fix() {
  setup_node_repo "test_command: npm test"
  fake_cmd npm 'exit 96'
  run repo-run.sh fake test
  assert_rc 1; assert_contains "$OUT" "❌ fake: couldn't go into $R
   Fix: Check the clone is there: /flow-configure-repo fake path <folder>."
  mkdir -p "$T/broken nvm"; printf 'return 1\n' > "$T/broken nvm/nvm.sh"
  NVM_DIR="$T/broken nvm" run repo-run.sh fake test
  assert_rc 1; assert_contains "$OUT" "❌ fake: nvm couldn't be loaded
   Fix: Install nvm (setup guide, section 1), then run this again."
  FAKE_NVM_MISSING=18.20.8 run repo-run.sh fake test
  assert_rc 1; assert_contains "$OUT" "❌ fake: Node 18.20.8 (what fake is built for) isn't installed"
}

test_a_repo_that_is_not_node_runs_without_nvm() {
  setup_run
  make_repo pyrepo "language: python" "node_version: 22" "test_command: npm test"
  fake_cmd npm 'echo "  3 passing"'
  run repo-run.sh pyrepo test
  assert_rc 0; assert_contains "$OUT" "✅ pyrepo: the tests passed (npm test)"
  assert_eq "$(fake_calls nvm)" "" "no nvm"
}

# ---------------------------------------------------------------- migrate and seed

test_migrate_and_seed_need_the_users_yes() {
  setup_node_repo
  run repo-run.sh fake migrate
  assert_rc 1
  assert_eq "$OUT" "❌ fake: 'migrate' needs the user's yes first
   Fix: Ask the user in chat, naming fake and what will run (npm run migrate, against the database its .env names). Only after their yes: bash scripts/repo-run.sh fake migrate confirmed"
  run repo-run.sh fake seed yes
  assert_rc 1; assert_contains "$OUT" "❌ fake: 'seed' needs the user's yes first"
  run repo-run.sh fake migrate confirmed now
  assert_rc 1
  assert_eq "$(fake_calls npm)" "" "nothing ran"
}

test_migrate_confirmed_runs_the_repos_own_script() {
  setup_node_repo
  fake_cmd npm 'echo "== 2026-10-20-create-x: migrated"'
  run repo-run.sh fake migrate confirmed
  assert_rc 0
  assert_eq "$OUT" "✅ fake: npm run migrate passed (npm run migrate)
   Write this run in the card's develop.md (for the deployment doc)."
  assert_eq "$(fake_calls npm)" "npm run migrate"
}

test_seed_without_a_script_or_failing() {
  setup_node_repo
  run repo-run.sh fake seed confirmed
  assert_rc 1
  assert_eq "$OUT" "❌ fake has no 'seed' script in its package.json
   Fix: Nothing to run here: this repo has no migrations or seeders. If the card needs some, they go in a repo that has them."
  rm "$R/package.json"
  run repo-run.sh fake migrate confirmed
  assert_rc 1; assert_contains "$OUT" "❌ fake has no 'migrate' script in its package.json"
  printf '{\n  "scripts": {\n    "seed": "sequelize-cli db:seed:all"\n  }\n}\n' > "$R/package.json"
  fake_cmd npm 'echo "ERROR: duplicate key"; exit 1'
  run repo-run.sh fake seed confirmed
  assert_rc 1
  assert_contains "$OUT" "❌ fake: npm run seed failed (npm run seed)"
  assert_not_contains "$OUT" "develop.md"
}

# ---------------------------------------------------------------- servers

test_stop_and_all_stop_without_servers() {
  setup_server_repo
  run repo-run.sh all stop
  assert_rc 0; assert_eq "$OUT" "✅ No servers started by closio-agent are running"
  run repo-run.sh web stop
  assert_rc 0; assert_eq "$OUT" "✅ web: no server started by closio-agent"
  run repo-run.sh "Bad!" stop
  assert_rc 1; assert_eq "$OUT" "❌ 'Bad!' isn't a repo name
   Fix: Use the name of a registered repo, or: bash scripts/repo-run.sh all stop"
}

test_stop_a_server_that_already_stopped() {
  setup_server_repo
  mkdir -p "$SRV"; sh -c 'exit 0' & local dead=$!; wait "$dead"
  echo "$dead" > "$SRV/web.pid"; echo "abc" > "$SRV/web.code"
  run repo-run.sh web stop
  assert_rc 0; assert_eq "$OUT" "✅ web: the server had already stopped"
  assert_no_file "$SRV/web.pid"; assert_no_file "$SRV/web.code"
}

test_start_needs_a_dev_command_and_a_port() {
  setup_server_repo
  sed -i '' 's/^dev_command: .*/dev_command: none/' "$A/config/repos/web.yaml"
  run repo-run.sh web start
  assert_rc 1
  assert_eq "$OUT" "❌ web has no dev_command or start_command in config/repos/web.yaml
   Fix: Add one (e.g. dev_command: npm run dev) with /flow-configure-repo web, then run this again."
  printf 'start_command: exec python3 -m http.server 1\n' >> "$A/config/repos/web.yaml"
  printf 'OTHER=1\n' > "$R/.env"
  run repo-run.sh web start
  assert_rc 1
  assert_eq "$OUT" "❌ web: its port isn't set in its .env (PORT)
   Fix: Set PORT in $R/.env (the value isn't shown here), then run this again."
  printf 'PORT=\n' > "$R/.env"
  run repo-run.sh web start
  assert_rc 1; assert_contains "$OUT" "its port isn't set"
  assert_no_file "$SRV/web.pid"
}

test_start_no_wait_returns_at_once_and_start_then_waits_and_reuses_it() {
  setup_server_repo; export SERVER_START_TIMEOUT=20
  local t0 t1 pid1 n
  t0=$(date +%s); run repo-run.sh web start --no-wait; t1=$(date +%s)
  assert_rc 0
  assert_eq "$OUT" "   web: starting (exec python3 -m http.server \$(grep '^PORT=' .env | cut -d= -f2) --bind 127.0.0.1)
✅ web: starting in the background; \"bash scripts/repo-run.sh web start\" waits until it answers"
  [ $((t1 - t0)) -lt 10 ] || fail "--no-wait took $((t1 - t0)) s"   # it never waits (SERVER_START_TIMEOUT is 20)
  assert_file "$SRV/web.pid"; assert_file "$SRV/web.code"
  pid1="$(pid_of web)"
  run repo-run.sh web start --no-wait
  assert_rc 0; assert_match "$OUT" "still starting in the background|on the same code\): reused"
  assert_eq "$(pid_of web)" "$pid1" "no second server"
  run repo-run.sh web start
  assert_rc 0; assert_match "$OUT" "web is running and answers on / \(log: local/logs/server-web.log\)|reused"
  curl -s -o /dev/null --max-time 3 "http://127.0.0.1:$PORT/" || fail "the server doesn't answer"
  n="$(ps -axo command | grep -c "[h]ttp.server $PORT ")"
  assert_eq "$n" "1" "one server process"
  run repo-run.sh web start
  assert_rc 0; assert_eq "$OUT" "✅ web is already running (started by closio-agent, on the same code): reused"
  assert_eq "$(pid_of web)" "$pid1"
  run repo-run.sh web status
  assert_rc 0; assert_eq "$OUT" "✅ web is running (started by closio-agent)"
  run repo-run.sh web stop
  assert_rc 0; assert_eq "$OUT" "✅ web: server stopped"
  assert_no_file "$SRV/web.pid"; assert_no_file "$SRV/web.code"
  kill -0 "$pid1" 2>/dev/null && fail "the server still runs"
  run repo-run.sh web status
  assert_rc 0
  assert_eq "$OUT" "⚠️ web isn't running
   Tip: Start it with: bash scripts/repo-run.sh web start"
}

test_a_code_change_or_the_env_file_restarts_the_server_and_a_new_env_file_does_not() {
  setup_server_repo; export SERVER_START_TIMEOUT=20
  local pid1 pid2 pid3 pid4
  run repo-run.sh web start
  assert_rc 0; assert_contains "$OUT" "✅ web is running and answers on /"
  assert_contains "$OUT" "   web: waiting up to 20 s for /..."
  pid1="$(pid_of web)"
  echo "two" >> "$R/app.js"
  run repo-run.sh web start
  assert_rc 0
  assert_contains "$OUT" "   web: the code changed since closio-agent started its server: restarting it"
  assert_contains "$OUT" "✅ web is running and answers on /"
  pid2="$(pid_of web)"
  [ "$pid2" != "$pid1" ] || fail "not restarted after a code change"
  kill -0 "$pid1" 2>/dev/null && fail "the old server still runs"
  echo "SECRET=x" > "$R/.env.local"
  run repo-run.sh web start
  assert_contains "$OUT" "reused"; assert_eq "$(pid_of web)" "$pid2" "a new .env file isn't code"
  sleep 1; touch "$R/.env"
  run repo-run.sh web start
  assert_contains "$OUT" "the code changed"
  pid3="$(pid_of web)"; [ "$pid3" != "$pid2" ] || fail "not restarted after the env file changed"
  echo "new" > "$R/new.js"
  run repo-run.sh web start
  assert_contains "$OUT" "the code changed"
  pid4="$(pid_of web)"; [ "$pid4" != "$pid3" ] || fail "not restarted after a new file"
  assert_not_contains "$(cat "$SRV/web.code")" "SECRET"
}

test_a_server_that_stops_while_starting() {
  setup_server_repo
  sed -i '' 's/^dev_command: .*/dev_command: echo "Error: listen EADDRINUSE"; exit 3/' "$A/config/repos/web.yaml"
  run repo-run.sh web start
  assert_rc 1
  assert_contains "$OUT" "❌ web stopped while starting
   Fix: Read the end of local/logs/server-web.log (below), fix the cause, then run this again."
  assert_contains "$OUT" "        Error: listen EADDRINUSE"
  assert_no_file "$SRV/web.pid"; assert_no_file "$SRV/web.code"
}

test_a_server_that_does_not_answer_in_time_is_left_running() {
  setup_server_repo; export SERVER_START_TIMEOUT=2
  sed -i '' 's/^dev_command: .*/dev_command: echo starting slowly; exec sleep 60/' "$A/config/repos/web.yaml"
  run repo-run.sh web start --no-wait
  assert_rc 0
  run repo-run.sh web start --no-wait
  assert_rc 0; assert_eq "$OUT" "✅ web is still starting in the background"
  run repo-run.sh web start
  assert_rc 1
  assert_contains "$OUT" "❌ web didn't answer on / within 2 s
   Fix: Read local/logs/server-web.log (end below). The server is left running; stop it with: bash scripts/repo-run.sh web stop"
  assert_contains "$OUT" "        starting slowly"
  kill -0 "$(pid_of web)" 2>/dev/null || fail "the server should be left running"
  run repo-run.sh all stop
  assert_rc 0; assert_eq "$OUT" "✅ web: server stopped"
  assert_no_file "$SRV/web.pid"
}

test_a_server_started_outside_closio_agent_is_left_alone() {
  setup_server_repo
  printf '[{"path": ".", "text": "up"}]\n' > "$T/routes.json"
  start_fake OUTSIDE http "$T/routes.json"
  printf 'PORT=%s\n' "${OUTSIDE##*:}" > "$R/.env"
  run repo-run.sh web start
  assert_rc 0; assert_eq "$OUT" "✅ web is already running (started outside closio-agent; it's left as it is)"
  assert_no_file "$SRV/web.pid"
  run repo-run.sh web status
  assert_rc 0; assert_eq "$OUT" "✅ web is running (started outside closio-agent)"
  run repo-run.sh web stop
  assert_eq "$OUT" "✅ web: no server started by closio-agent"
  curl -s -o /dev/null --max-time 3 "$OUTSIDE/" || fail "the outside server was stopped"
}

# ---------------------------------------------------------------- review

test_review_without_codex() {
  setup_node_repo
  mkdir -p "$T/bin"
  local f
  for f in "$TESTS_DIR"/fakes/bin/*; do [ "$(basename "$f")" = codex ] || ln -s "$f" "$T/bin/$(basename "$f")"; done
  run_in "$A" env PATH="$T/bin:/usr/bin:/bin:/usr/sbin:/sbin" bash scripts/repo-run.sh fake review
  assert_rc 1
  assert_eq "$OUT" "❌ Codex isn't installed here (this runs Codex's own reviewer)
   Fix: In Claude Code, /flow-review uses Claude Code's own code-review instead; for Codex, install it as the setup guide says."
}

test_review_runs_codex_against_the_mr_target_branch() {
  setup_node_repo "mr_target_branch: main"
  git init -q --bare "$T/origin.git"; git -C "$R" remote add origin "$T/origin.git"; git -C "$R" push -q origin develop:main 2>/dev/null
  fake_cmd codex 'echo "Review of: $*"; echo "- [P2] app.js:1 rename one"'
  run repo-run.sh fake review
  assert_rc 0
  assert_eq "$OUT" "   fake: Codex's own review of the card's changes against origin/main (time limit 900 s)...
✅ fake: Codex's review (below; check each point against the code before showing it):
   Review of: review --base origin/main
   - [P2] app.js:1 rename one"
  assert_eq "$(fake_calls nvm)" "" "Codex runs on closio-agent's own Node"
}

test_review_offline_uses_the_base_branch_and_a_failing_review() {
  setup_node_repo "mr_target_branch: none"
  fake_cmd codex 'echo "codex: not logged in"; exit 1'
  run repo-run.sh fake review
  assert_rc 1
  assert_contains "$OUT" "⚠️ fake: couldn't fetch from GitLab; reviewing against the origin/develop this Mac already has
   Tip: Connect the VPN for the latest: /flow-vpn connect"
  assert_contains "$OUT" "❌ fake: Codex's review failed (codex review --base origin/develop)"
  assert_contains "$OUT" "        codex: not logged in"
}
