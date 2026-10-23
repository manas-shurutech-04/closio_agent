# scripts/setup-repo.sh: flow-setup-repo (F6, D54), for test repos registered in the sandbox, with every outside tool a
# stand-in: brew, docker, npm, nc, open and osascript (OSASCRIPT_BIN, so no real dialog), the fake nvm in $T/nvm. This
# file adds one stand-in of its own: a short sleep in $T/bin (0.5 s, or $FAST_SLEEP), so the waits take little time.
# Homebrew and Docker are "not installed" (BREW_BIN / DOCKER_BIN point at nothing) unless a test says otherwise.
# A test repo has no Node version, install or test command unless the test gives them (each step costs time).

setup_box() {
  sandbox
  rm -f "$A/config/repos/"*.yaml
  mkdir -p "$T/bin" "$T/work" "$A/local/repos" "$T/nvm/versions/node/v22.14.0/bin"
  cp "$TESTS_DIR/fakes/nvm/nvm.sh" "$T/nvm/nvm.sh"
  printf '#!/bin/bash\nexec /bin/sleep "${FAST_SLEEP:-0.5}"\n' > "$T/bin/sleep"; chmod +x "$T/bin/sleep"
  export PATH="$T/bin:$PATH" NVM_DIR="$T/nvm"
  export OSASCRIPT_BIN=osascript BREW_BIN="$T/no-brew" DOCKER_BIN="$T/no-docker"
  export SETUP_INSTALL_TIMEOUT=900 SETUP_TEST_TIMEOUT=900 DOCKER_START_TIMEOUT=3 SERVICE_START_TIMEOUT=2
  export LOCAL_REDIS_PORT=6379 LOCAL_RABBITMQ_PORT=5672
  unset FAKE_NVM_MISSING FAKE_NVM_INSTALL_RC 2>/dev/null
  fake_cmd node 'echo v22.14.0'
  fake_cmd npm 'case "$1" in
  ci|install) mkdir -p node_modules; echo "added 12 packages" ;;
  test) echo "  3 passing"; echo "  0 failing" ;;
esac'
}

# config/repos/<repo>.yaml: the defaults below, each <key>=<value> given replacing its line
repo_config() { # <repo> [<key>=<value>…]
  local r="$1" f="$A/config/repos/$1.yaml" kv; shift
  printf '# test repo\nname: %s\ngitlab_url: https://gitlab.example.test/closio/backend/%s.git\ngitlab_path: closio/backend/%s\n' "$r" "$r" "$r" > "$f"
  printf 'language: node\nnode_version: none\ninstall_command: none\ntest_command: none\nlocal_services: none\nenv_file: .env\n' >> "$f"
  for kv in "$@"; do
    grep -v "^${kv%%=*}:" "$f" > "$f.tmp"; printf '%s: %s\n' "${kv%%=*}" "${kv#*=}" >> "$f.tmp"; mv "$f.tmp" "$f"
  done
}
# A clone of <repo> at $T/work/<repo> (origin: its GitLab URL, or <origin>), saved as its local_path
clone() { # <repo> [<origin>]
  local p="$T/work/$1"
  git init -q -b main "$p" && git -C "$p" remote add origin "${2:-https://gitlab.example.test/closio/backend/$1.git}" || fail "the clone"
  printf 'local_path: %s\n' "$p" > "$A/local/repos/$1.yaml"
}
demo() { # the repo most tests use: demo-api, cloned, with a .env
  repo_config demo-api "$@"
  clone demo-api
  printf 'PORT=3000\n' > "$T/work/demo-api/.env"
}
lfile() { cat "$A/local/repos/$1.yaml"; }

# Homebrew has <service> <version>, its service <status> (started / stopped / none)
brew_has() { # <service> <version> <status>
  unset BREW_BIN
  printf '%s' "$2" > "$T/brew-$1"
  [ "$3" = none ] || printf '%s %s manas ~/Library/LaunchAgents/homebrew.mxcl.%s.plist\n' "$1" "$3" "$1" >> "$T/brew-services"
  fake_cmd brew 'd="$FAKE_CMDS/.."
case "$1 ${2:-}" in
  "list --versions") [ -f "$d/brew-$3" ] && echo "$3 $(cat "$d/brew-$3")" ;;
  "services list") echo "Name Status User File"; cat "$d/brew-services" 2>/dev/null ;;
  "install "*) [ -f "$d/brew-install-fails" ] && { echo "Error: no bottle"; exit 1; }; echo "7.4.0" > "$d/brew-$2" ;;
esac
exit 0'
}
# Docker Desktop runs (docker info answers); docker_has adds a container <name> <state> <image> [<host port>]
docker_runs() {
  unset DOCKER_BIN
  fake_cmd docker 'd="$FAKE_CMDS/.."
case "$1" in
  info) [ -f "$d/docker-info-rc" ] && exit "$(cat "$d/docker-info-rc")"; exit 0 ;;
  ps) cat "$d/docker-ps" 2>/dev/null ;;
  inspect) cat "$d/docker-port-$4" 2>/dev/null ;;
  compose) exit "$(cat "$d/docker-compose-rc" 2>/dev/null || echo 0)" ;;
esac
exit 0'
}
docker_has() { # <name> <state> <image> [<host port>]
  printf '%s %s %s\n' "$1" "$2" "$3" >> "$T/docker-ps"
  [ -n "${4:-}" ] && printf '%s\n' "$4" > "$T/docker-port-$1"
  return 0
}
# nc: -z (is the port open?) exits <z>; a Redis command gets <reply> (\r\n line ends added)
nc_answers() { # <z exit code> [<reply to PING>] [<reply to CONFIG GET>]
  printf '%s' "${2:-}" > "$T/nc-ping"; printf '%s' "${3:-}" > "$T/nc-config"
  fake_cmd nc "case \" \$* \" in *' -z '*) exit $1 ;; esac
cmd=\"\$(head -1 | tr -d '\\r')\"
case \"\$cmd\" in PING) f=nc-ping ;; CONFIG*) f=nc-config ;; *) exit 1 ;; esac
[ -s \"\$FAKE_CMDS/../\$f\" ] || exit 1
tr '|' '\\n' < \"\$FAKE_CMDS/../\$f\"; echo"
}

test_check_folder_inside_and_outside_the_closio_agent_folder() {
  setup_box
  run setup-repo.sh check-folder
  assert_rc 0; assert_eq "$OUT" "✅ Started in the closio-agent folder"
  run_in "$T" bash "$A/scripts/setup-repo.sh" check-folder
  assert_rc 1
  assert_contains "$OUT" "❌ Not started in the closio-agent folder (current folder: $(cd "$T" && pwd))"
  assert_contains "$OUT" "   Fix: Quit, open a terminal in "
  assert_contains "$OUT" "        Always start Claude Code or Codex in the closio-agent folder."
}

test_wrong_usage_and_unknown_repos() {
  setup_box; demo
  run setup-repo.sh
  assert_rc 1; assert_eq "$OUT" "Usage: bash scripts/setup-repo.sh check-folder | list | run <repo|all> [install|services]"
  run setup-repo.sh run
  assert_rc 1; assert_eq "$OUT" "Usage: bash scripts/setup-repo.sh run <repo|all> [install|services]"
  run setup-repo.sh run demo-api fast
  assert_rc 1; assert_contains "$OUT" "❌ Unknown option 'fast'"
  run setup-repo.sh run "Bad Name"
  assert_rc 1; assert_contains "$OUT" "❌ 'Bad Name' isn't a valid repo name"
  run setup-repo.sh run other-api
  assert_rc 1; assert_eq "$OUT" "❌ other-api isn't registered
   Fix: Register it first: /flow-configure-repo <path of its clone>."
  assert_eq "$(fake_calls npm)" "" "nothing ran"
}

test_a_full_run_sets_up_one_repo_and_saves_the_result() {
  setup_box; demo "node_version=22   # from the Dockerfile" "install_command=npm ci" "test_command=npm test"
  run setup-repo.sh run demo-api
  assert_rc 0
  local p="$T/work/demo-api"
  assert_contains "$OUT" "flow-setup-repo — setting up demo-api

━━ demo-api
✅ Clone: $p
   Branch: main · 1 uncommitted change(s). Left as they are: the card phases handle branches.
✅ Node v22.14.0 (what demo-api is built for: 22)
✅ Env file: .env is there (its values are never shown)
   Installing packages (npm ci)...
✅ Packages installed (npm ci)
✅ Local services: none needed
   Running the tests (npm test, time limit 900 s)...
✅ Tests passed
   3 passing
   0 failing
   Full output: local/logs/setup-demo-api.log
✅ Claude Code can now use $p (added to your personal .claude/settings.local.json)
Result for demo-api: 0 to fix, 0 to look at.

Codex: to let it work in these repos, start it from the closio-agent folder with:
   codex --add-dir \"$p\"

Result: 0 to fix, 0 to look at."
  assert_eq "$(fake_calls npm)" "npm ci
npm test"
  assert_contains "$(fake_calls nvm)" "nvm use 22"
  assert_eq "$(jq -c '.permissions.additionalDirectories' "$A/.claude/settings.local.json")" "[\"$p\"]"
  assert_match "$(lfile demo-api)" "setup_on: [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}"
  assert_contains "$(lfile demo-api)" "setup_tests: passed"
  assert_contains "$(cat "$A/local/logs/setup-demo-api.log")" "\$ npm ci   (in $p,"
  assert_contains "$(cat "$A/local/logs/setup-demo-api.log")" "added 12 packages"
  # A second run: nothing to install, the folder already there, the saved lines replaced (not added again)
  run setup-repo.sh run demo-api
  assert_rc 0
  assert_contains "$OUT" "✅ Packages already installed and up to date"
  assert_contains "$OUT" "✅ Claude Code can already use $p"
  assert_eq "$(fake_calls npm)" "npm ci
npm test
npm test"
  assert_eq "$(lfile demo-api | grep -c '^setup_on:')" "1"
  assert_eq "$(lfile demo-api | tail -1)" "setup_tests: passed"
}

test_the_clone_must_be_saved_present_and_the_right_one() {
  setup_box; repo_config demo-api
  run setup-repo.sh run demo-api
  assert_rc 1
  assert_contains "$OUT" "❌ Where demo-api is on this Mac isn't saved yet
   Fix: Run /flow-configure-repo demo-api (give your clone's path)."
  assert_contains "$OUT" "Result: 1 to fix, 0 to look at."
  printf 'local_path:\n' > "$A/local/repos/demo-api.yaml"
  run setup-repo.sh run demo-api
  assert_rc 1
  assert_contains "$OUT" "❌ demo-api isn't cloned on this Mac
   Fix: Cloning is manual: on the VPN, git clone https://gitlab.example.test/closio/backend/demo-api.git <your workspace folder>/demo-api, then run /flow-configure-repo demo-api path <that folder>."
  printf 'local_path: %s\n' "$T/gone" > "$A/local/repos/demo-api.yaml"
  run setup-repo.sh run demo-api
  assert_rc 1; assert_contains "$OUT" "❌ demo-api: clone not found at $T/gone"
  clone demo-api git@gitlab.example.test:closio/backend/other-api.git
  run setup-repo.sh run demo-api
  assert_rc 1
  assert_contains "$OUT" "❌ $T/work/demo-api is a clone of 'closio/backend/other-api', not 'closio/backend/demo-api'"
  git -C "$T/work/demo-api" remote remove origin
  run setup-repo.sh run demo-api
  assert_rc 1; assert_contains "$OUT" "is a clone of 'no GitLab remote', not 'closio/backend/demo-api'"
  assert_eq "$(fake_calls npm)" "" "nothing ran"
}

test_a_missing_node_version_is_installed_with_nvm() {
  setup_box; demo node_version=18 "install_command=npm ci"; fake_cmd node 'echo v18.20.8'
  run setup-repo.sh run demo-api
  assert_rc 0
  assert_contains "$OUT" "   Node 18 isn't installed yet. Installing it with nvm...
✅ Node 18 installed with nvm
✅ Node v18.20.8 (what demo-api is built for: 18)"
  assert_contains "$(fake_calls nvm)" "nvm install 18"
  assert_contains "$(fake_calls nvm)" "nvm use 18"
}

test_node_that_nvm_cannot_install_or_switch_to() {
  setup_box; demo node_version=18 "install_command=npm ci"; export FAKE_NVM_INSTALL_RC=3
  run setup-repo.sh run demo-api
  assert_rc 1
  assert_contains "$OUT" "❌ Couldn't install Node 18 with nvm
   Fix: Run 'nvm install 18' in a terminal, then run /flow-setup-repo demo-api again. Details: local/logs/setup-demo-api.log"
  assert_not_contains "$OUT" "Tests"
  export FAKE_NVM_MISSING=22
  repo_config demo-api node_version=22 "install_command=npm ci"
  run setup-repo.sh run demo-api
  assert_rc 1
  assert_contains "$OUT" "❌ Couldn't switch to Node 22
   Fix: Run 'nvm install 22' in a terminal, then run /flow-setup-repo demo-api again."
  assert_eq "$(fake_calls npm)" "" "nothing installed on the wrong Node"
}

test_without_nvm_the_node_step_stops() {
  setup_box; demo node_version=22
  if [ -s /opt/homebrew/opt/nvm/nvm.sh ] || [ -s /usr/local/opt/nvm/nvm.sh ]; then
    echo "skipped: this Mac has Homebrew's nvm, which the script would find (never used by a test)"; return 0
  fi
  export NVM_DIR="$T/no-nvm"
  run setup-repo.sh run demo-api
  assert_rc 1
  assert_contains "$OUT" "❌ nvm isn't installed, so Node 22 can't be used for demo-api"
}

test_a_repo_without_node_tests_or_env_file() {
  setup_box; demo language=go env_file=none
  run setup-repo.sh run demo-api
  assert_rc 0
  assert_not_contains "$OUT" "Node"; assert_not_contains "$OUT" "Env file"; assert_not_contains "$OUT" "Packages"
  assert_contains "$OUT" "✅ No test suite in demo-api, so no tests to run"
  assert_contains "$(lfile demo-api)" "setup_tests: no test suite"
  assert_eq "$(fake_calls npm)" ""
}

test_a_missing_env_file_explains_how_to_get_it() {
  setup_box; demo env_file=.env.local
  run setup-repo.sh run demo-api
  assert_rc 1
  assert_contains "$OUT" "❌ demo-api: .env.local is missing
   How to fix it:
   1. Ask your team for this repo's .env.local (local values).
   2. Save it as $T/work/demo-api/.env.local (never paste it into the AI chat).
   3. Run /flow-setup-repo demo-api again."
  printf 'A=1\n' > "$T/work/demo-api/.env.example"
  run setup-repo.sh run demo-api
  assert_contains "$OUT" "      If the team has no copy, start from the example: in the repo folder run  cp .env.example .env.local  and fill in the values."
  assert_contains "$OUT" "Result for demo-api: 1 to fix, 0 to look at."
}

test_env_names_are_compared_with_the_example_never_the_values() {
  setup_box; demo
  printf 'PORT=3000\nexport DB_PASS="SECRET_VALUE_123"\n' > "$T/work/demo-api/.env"
  printf '# example\nPORT=1\nDB_PASS=x\n' > "$T/work/demo-api/.env.example"
  run setup-repo.sh run demo-api
  assert_contains "$OUT" "✅ .env has every variable .env.example lists (names only)"
  printf 'PORT=1\nDB_PASS=x\n  export DB_HOST=x\nJWT_KEY=x\n' > "$T/work/demo-api/.env.example"
  run setup-repo.sh run demo-api
  assert_rc 0
  assert_contains "$OUT" "⚠️ demo-api/.env is missing 2 variable(s) that .env.example has: DB_HOST, JWT_KEY
   The app or its tests may fail until they're added.
   How to fix it (you change the file yourself; the AI never sees it):
   1. It's open in your text editor now: $T/work/demo-api/.env
   2. Add these lines, each with the value from your team (or from .env.example if it's only an example value):
        DB_HOST=
        JWT_KEY=
   3. Save, then run /flow-setup-repo demo-api again."
  assert_contains "$OUT" "Result for demo-api: 0 to fix, 1 to look at."
  assert_eq "$(fake_calls open)" "open -t $T/work/demo-api/.env"
  assert_not_contains "$OUT" "SECRET_VALUE_123"
}

test_many_missing_env_names_are_cut_at_fifteen() {
  setup_box; demo
  local i; for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17; do printf 'VAR_%02d=x\n' "$i"; done > "$T/work/demo-api/.env.sample"
  fake_cmd open 'exit 1'
  run setup-repo.sh run demo-api
  assert_contains "$OUT" "⚠️ demo-api/.env is missing 17 variable(s) that .env.sample has: VAR_01, VAR_02, VAR_03, VAR_04, VAR_05, VAR_06, VAR_07, VAR_08, VAR_09, VAR_10, VAR_11, VAR_12, VAR_13, VAR_14, VAR_15, and 2 more"
  assert_contains "$OUT" "   1. Open it:  open -t \"$T/work/demo-api/.env\""
  assert_contains "$OUT" "        VAR_15=
        … and 2 more (see .env.sample)"
  assert_not_contains "$OUT" "VAR_16="
}

test_packages_are_installed_again_only_when_needed() {
  setup_box; demo "install_command=npm ci"
  local p="$T/work/demo-api"
  mkdir -p "$p/node_modules"
  run setup-repo.sh run demo-api
  assert_contains "$OUT" "✅ Packages already installed and up to date"
  run setup-repo.sh run demo-api install
  assert_contains "$OUT" "✅ Packages installed (npm ci)"
  printf '{}' > "$p/package-lock.json"   # npm's own copy of the lock file is missing
  run setup-repo.sh run demo-api
  assert_contains "$OUT" "✅ Packages installed (npm ci)"
  printf '{}' > "$p/node_modules/.package-lock.json"; touch -t 202001010000 "$p/node_modules/.package-lock.json"
  run setup-repo.sh run demo-api   # the lock file is newer
  assert_contains "$OUT" "✅ Packages installed (npm ci)"
  touch "$p/node_modules/.package-lock.json"
  run setup-repo.sh run demo-api
  assert_contains "$OUT" "✅ Packages already installed and up to date"
  rm -f "$p/package-lock.json"; printf '' > "$p/yarn.lock"
  run setup-repo.sh run demo-api   # no .yarn-integrity
  assert_contains "$OUT" "✅ Packages installed (npm ci)"
  printf '' > "$p/node_modules/.yarn-integrity"; touch -t 202001010000 "$p/node_modules/.yarn-integrity"
  run setup-repo.sh run demo-api
  assert_contains "$OUT" "✅ Packages installed (npm ci)"
  touch "$p/node_modules/.yarn-integrity"
  run setup-repo.sh run demo-api
  assert_contains "$OUT" "✅ Packages already installed and up to date"
  assert_eq "$(fake_calls npm | grep -c '^npm ci')" "5"
}

test_a_failed_install_shows_the_end_of_the_log_and_skips_the_tests() {
  setup_box; demo "install_command=npm ci" "test_command=npm test"
  fake_cmd npm 'echo "npm ERR! code E404"; echo "npm ERR! 404 Not Found - left-pad"; exit 1'
  run setup-repo.sh run demo-api
  assert_rc 1
  assert_contains "$OUT" "❌ Installing packages failed (npm ci)
   Fix: Read the end of local/logs/setup-demo-api.log, fix what it says, then run /flow-setup-repo demo-api install."
  assert_contains "$OUT" "        npm ERR! 404 Not Found - left-pad"
  assert_contains "$OUT" "⚠️ Tests not run, because installing the packages failed
   Tip: Fix the install first (see above)."
  assert_eq "$(fake_calls npm)" "npm ci"
  assert_contains "$(lfile demo-api)" "setup_tests: not run"
}

test_an_install_over_the_time_limit_is_stopped() {
  setup_box; demo "install_command=npm ci"; export SETUP_INSTALL_TIMEOUT=2
  fake_cmd npm 'echo $$ >> "$FAKE_CMDS/../.fake-pids"; exec /bin/sleep 30'
  run setup-repo.sh run demo-api
  assert_rc 1
  assert_contains "$OUT" "❌ Installing packages took longer than 2 seconds and was stopped
   Fix: Check your internet connection, then run /flow-setup-repo demo-api install. Details: local/logs/setup-demo-api.log"
  assert_contains "$(cat "$A/local/logs/setup-demo-api.log")" "closio-agent: stopped after 2 seconds (time limit)"
  local pid; pid="$(tail -1 "$T/.fake-pids")"
  kill -0 "$pid" 2>/dev/null && fail "the install still runs (pid $pid)"
  return 0
}

test_failed_tests_show_their_summary_and_end() {
  setup_box; demo "test_command=npm test"
  fake_cmd npm 'case "$1" in ci) mkdir -p node_modules ;; test) echo "  2 passing"; echo "  1 failing"; echo "  1) scheme list: AssertionError: expected 200"; exit 1 ;; esac'
  run setup-repo.sh run demo-api
  assert_rc 1
  assert_contains "$OUT" "❌ Tests failed
   Fix: Read local/logs/setup-demo-api.log. If the errors mention a database or a host that can't be reached, connect the VPN (/flow-vpn connect) and run /flow-setup-repo demo-api again; if they're real test failures, they come from the repo's current branch."
  assert_contains "$OUT" "   2 passing
   1 failing"
  assert_contains "$OUT" "          1) scheme list: AssertionError: expected 200"
  assert_contains "$(lfile demo-api)" "setup_tests: failed"
}

test_tests_over_the_time_limit_are_stopped() {
  setup_box; demo node_version=22 "test_command=npm test"; export SETUP_TEST_TIMEOUT=2
  fake_cmd npm 'case "$1" in ci) mkdir -p node_modules ;; test) echo $$ >> "$FAKE_CMDS/../.fake-pids"; exec /bin/sleep 30 ;; esac'
  run setup-repo.sh run demo-api
  assert_rc 1
  assert_contains "$OUT" "❌ The tests took longer than 2 seconds and were stopped
   Fix: Run them yourself to see why: cd \"$T/work/demo-api\" && nvm use 22 && npm test. The limit is SETUP_TEST_TIMEOUT in config/project-settings.sh."
  assert_contains "$(lfile demo-api)" "setup_tests: timed out"
}

test_claude_settings_keep_what_is_there_or_report_bad_json() {
  setup_box; demo
  mkdir -p "$A/.claude"; printf '{"permissions":{"allow":["Bash(ls)"]},"model":"x"}' > "$A/.claude/settings.local.json"
  run setup-repo.sh run demo-api
  assert_rc 0
  assert_eq "$(jq -c . "$A/.claude/settings.local.json")" "{\"permissions\":{\"allow\":[\"Bash(ls)\"],\"additionalDirectories\":[\"$T/work/demo-api\"]},\"model\":\"x\"}"
  printf '{ not json' > "$A/.claude/settings.local.json"
  run setup-repo.sh run demo-api
  assert_rc 1
  assert_contains "$OUT" "❌ Couldn't add $T/work/demo-api to .claude/settings.local.json
   Fix: Check that the file is valid JSON (jq . .claude/settings.local.json), then run /flow-setup-repo demo-api again."
  assert_eq "$(cat "$A/.claude/settings.local.json")" "{ not json" "a bad file is left as it was"
  assert_no_file "$A/.claude/settings.local.json.tmp"
}

test_run_all_skips_repos_not_cloned_and_checks_a_shared_service_once() {
  setup_box
  demo local_services=redis
  repo_config demo-jobs local_services=bullmq install_command=none test_command=none env_file=none node_version=none
  clone demo-jobs
  repo_config demo-web
  brew_has redis 7.2.4 started; nc_answers 0 "+PONG" '*2|$16|maxmemory-policy|$10|noeviction'
  printf 'REDIS_HOST=127.0.0.1\nREDIS_PORT=6379\n' >> "$T/work/demo-api/.env"
  run setup-repo.sh run all
  assert_rc 0
  assert_contains "$OUT" "   Skipping demo-web: not cloned on this Mac.
flow-setup-repo — setting up: demo-api demo-jobs"
  assert_contains "$OUT" "✅ Local Redis: using Homebrew Redis 7.2.4, answering on port 6379"
  assert_contains "$OUT" "✅ .env: Redis points to this Mac, and it answers"
  assert_contains "$OUT" "✅ Local Redis: checked above"
  assert_eq "$(printf '%s\n' "$OUT" | grep -c 'answering on port')" "1"
  # demo-jobs uses BullMQ: Redis was set up for demo-api above, and its memory setting is still checked (once)
  assert_contains "$OUT" "✅ Local Redis: checked above
✅ Redis memory setting is right for BullMQ (noeviction)"
  assert_eq "$(printf '%s\n' "$OUT" | grep -c 'memory setting is right for BullMQ')" "1"
  assert_contains "$OUT" "   codex --add-dir \"$T/work/demo-api\" --add-dir \"$T/work/demo-jobs\""
}

test_run_all_with_nothing_cloned() {
  setup_box; repo_config demo-api
  run setup-repo.sh run all
  assert_rc 1
  assert_eq "$OUT" "   Skipping demo-api: not cloned on this Mac.
❌ No repo is cloned on this Mac yet
   Fix: Clone one yourself, then /flow-configure-repo <repo> path <folder>."
}

test_a_homebrew_copy_that_is_stopped_is_started() {
  setup_box; demo "local_services=redis, rabbitmq"
  brew_has redis 7.2.4 stopped; brew_has rabbitmq 4.1.0 none; nc_answers 0 "+PONG"
  printf 'REDIS_HOST=localhost\nREDIS_PORT=6379\nRABBITMQ_URL=amqp://guest:guest@127.0.0.1:5672\n' >> "$T/work/demo-api/.env"
  run setup-repo.sh run demo-api
  assert_rc 0
  assert_contains "$OUT" "   Started the Homebrew copy of Redis (brew services start redis)
✅ Local Redis: using Homebrew Redis 7.2.4, answering on port 6379"
  assert_contains "$OUT" "   Started the Homebrew copy of RabbitMQ (brew services start rabbitmq)
✅ Local RabbitMQ: using Homebrew RabbitMQ 4.1.0, answering on port 5672"
  assert_contains "$OUT" "✅ .env: RabbitMQ points to this Mac, and it answers"
  assert_contains "$(fake_calls brew)" "brew services start redis"
  assert_contains "$(fake_calls brew)" "brew services start rabbitmq"
  assert_contains "$(fake_calls nc)" "nc -z -G 2 127.0.0.1 5672"
}

test_a_docker_copy_that_is_stopped_is_started_on_its_own_port() {
  setup_box; demo local_services=redis; docker_runs; docker_has my-redis exited docker.io/library/redis:7.2 6380
  nc_answers 0 "+PONG"
  printf 'REDIS_HOST=127.0.0.1\nREDIS_PORT=6380\nREDIS_USER=\nREDIS_PASSWORD=\n' >> "$T/work/demo-api/.env"
  run setup-repo.sh run demo-api
  assert_rc 0
  assert_contains "$OUT" "   Started the Docker copy of Redis (container my-redis)
✅ Local Redis: using Docker container my-redis, answering on port 6380"
  assert_contains "$OUT" "✅ .env: Redis points to this Mac, and it answers"
  assert_contains "$(fake_calls docker)" "docker start my-redis"
  assert_contains "$(fake_calls nc)" "nc -z -G 2 127.0.0.1 6380"
}

test_two_copies_ask_once_and_save_the_choice() {
  setup_box; demo local_services=redis
  brew_has redis 7.2.4 started; docker_runs; docker_has my-redis running redis:7.2; nc_answers 0 "+PONG"
  fake_cmd osascript 'echo Docker'
  printf 'REDIS_HOST=127.0.0.1\nREDIS_PORT=6379\n' >> "$T/work/demo-api/.env"
  run setup-repo.sh run demo-api
  assert_rc 0
  assert_contains "$OUT" "   Your choice for Redis is saved (docker). To change it: /flow-setup-repo demo-api services
✅ Stopped the Homebrew copy of Redis: you use the Docker one
✅ Local Redis: using Docker container my-redis, answering on port 6379"
  assert_contains "$(fake_calls osascript)" "You have two copies of Redis: Homebrew (Redis 7.2.4) and Docker (container my-redis)."
  assert_contains "$(fake_calls osascript)" 'buttons {"Not now", "Homebrew", "Docker"} default button "Docker" giving up after 300'
  assert_contains "$(cat "$A/local/user-settings.sh")" 'LOCAL_REDIS_FROM="docker"   # homebrew or docker; set by flow-setup-repo (D54)'
  assert_contains "$(fake_calls brew)" "brew services stop redis"
  # Saved: no dialog the next time
  : > "$FAKE_LOG"
  run setup-repo.sh run demo-api
  assert_eq "$(fake_calls osascript)" ""
  # The services option forgets it and asks again
  fake_cmd osascript 'echo Homebrew'
  run setup-repo.sh run demo-api services
  assert_rc 0
  assert_contains "$OUT" "   Your choice for Redis is saved (homebrew)."
  assert_contains "$OUT" "✅ Stopped the Docker copy of Redis (container my-redis): you use the Homebrew one"
  assert_eq "$(grep -c '^LOCAL_REDIS_FROM=' "$A/local/user-settings.sh")" "1"
  assert_contains "$(cat "$A/local/user-settings.sh")" 'LOCAL_REDIS_FROM="homebrew"'
}

test_two_copies_and_no_answer() {
  setup_box; demo local_services=redis
  brew_has redis 7.2.4 started; docker_runs; docker_has my-redis running redis; nc_answers 0
  fake_cmd osascript 'echo ""'
  run setup-repo.sh run demo-api
  assert_rc 0
  assert_contains "$OUT" "⚠️ Redis: you have a Homebrew and a Docker copy, and no choice was made
   Tip: Run /flow-setup-repo demo-api services to choose."
  assert_no_file "$A/local/user-settings.sh"
}

test_no_copy_with_docker_running_is_started_from_the_shared_file_after_a_yes() {
  setup_box; demo local_services=redis; docker_runs; nc_answers 0 "+PONG"
  fake_cmd osascript 'echo "Start with Docker"'
  printf 'REDIS_HOST=127.0.0.1\nREDIS_PORT=6379\n' >> "$T/work/demo-api/.env"
  run setup-repo.sh run demo-api
  assert_rc 0
  assert_contains "$OUT" "✅ Redis started with Docker (container closio-agent-redis, from config/local-services.yml)
✅ Local Redis: using Docker container closio-agent-redis, answering on port 6379"
  assert_contains "$(fake_calls docker)" "docker compose -f $(cd "$A" && pwd -P)/config/local-services.yml up -d redis"
  assert_contains "$(cat "$A/local/user-settings.sh")" 'LOCAL_REDIS_FROM="docker"'
}

test_no_copy_with_docker_running_but_no_yes_or_a_failed_start() {
  setup_box; demo local_services=redis; docker_runs; nc_answers 0
  fake_cmd osascript 'echo "Not now"'
  run setup-repo.sh run demo-api
  assert_rc 0
  assert_contains "$OUT" "⚠️ No local Redis (nothing was started)
   Tip: Run /flow-setup-repo demo-api again and choose 'Start with Docker', or install it with Homebrew: brew install redis && brew services start redis"
  fake_cmd osascript 'echo "Start with Docker"'; echo 1 > "$T/docker-compose-rc"
  run setup-repo.sh run demo-api
  assert_rc 1
  assert_contains "$OUT" "❌ Couldn't start Redis with Docker
   Fix: See local/logs/local-services.log, then run /flow-setup-repo demo-api again."
}

test_no_copy_without_docker_is_installed_with_homebrew_after_a_yes() {
  setup_box; demo local_services=rabbitmq; brew_has none 0 none; nc_answers 0
  fake_cmd osascript 'echo "Install with Homebrew"'
  printf 'RABBITMQ_URL=amqp://guest:guest@127.0.0.1:5672\n' >> "$T/work/demo-api/.env"
  run setup-repo.sh run demo-api
  assert_rc 0
  assert_contains "$OUT" "   Installing RabbitMQ with Homebrew (brew install rabbitmq)...
   Started the Homebrew copy of RabbitMQ (brew services start rabbitmq)
✅ Local RabbitMQ: using Homebrew RabbitMQ 7.4.0, answering on port 5672"
  assert_contains "$(cat "$A/local/user-settings.sh")" 'LOCAL_RABBITMQ_FROM="homebrew"'
  assert_contains "$(fake_calls osascript)" "Docker isn't available."
}

test_no_copy_without_docker_and_no_yes_or_a_failed_install() {
  setup_box; demo local_services=redis; brew_has none 0 none; nc_answers 0
  fake_cmd osascript 'echo "Not now"'
  run setup-repo.sh run demo-api
  assert_contains "$OUT" "⚠️ No local Redis (nothing was installed)
   Tip: Run /flow-setup-repo demo-api again and choose 'Install with Homebrew', or install Docker Desktop (docker.com)."
  fake_cmd osascript 'echo "Install with Homebrew"'; : > "$T/brew-install-fails"
  run setup-repo.sh run demo-api
  assert_rc 1
  assert_contains "$OUT" "❌ Couldn't install Redis with Homebrew
   Fix: See local/logs/local-services.log, then run /flow-setup-repo demo-api again."
  assert_contains "$(cat "$A/local/logs/local-services.log")" "Error: no bottle"
}

test_no_copy_and_neither_docker_nor_homebrew() {
  setup_box; demo local_services=redis
  run setup-repo.sh run demo-api
  assert_rc 1
  assert_contains "$OUT" "❌ No local Redis, and neither Docker nor Homebrew is installed
   Fix: Install Docker Desktop (docker.com) or Homebrew (brew.sh), then run /flow-setup-repo demo-api again."
  assert_eq "$(fake_calls osascript)" "" "no dialog"
}

test_a_service_that_does_not_answer_on_its_port() {
  setup_box; demo local_services=redis; brew_has redis 7.2.4 started; nc_answers 1
  run setup-repo.sh run demo-api
  assert_rc 1
  assert_contains "$OUT" "❌ Local Redis (Homebrew Redis 7.2.4) doesn't answer on port 6379
   Fix: See local/logs/local-services.log. For Homebrew: brew services restart redis. For Docker: open Docker Desktop and start the container. Then run /flow-setup-repo demo-api again."
}

test_bullmq_needs_redis_with_noeviction() {
  setup_box; demo local_services=bullmq env_file=none; brew_has redis 7.2.4 started
  nc_answers 0 "+PONG" '*2|$16|maxmemory-policy|$10|noeviction'
  run setup-repo.sh run demo-api
  assert_contains "$OUT" "✅ Redis memory setting is right for BullMQ (noeviction)"
  assert_contains "$(fake_calls nc)" "nc -G 2 -w 2 127.0.0.1 6379"
  nc_answers 0 "+PONG" '*2|$16|maxmemory-policy|$11|allkeys-lru'
  run setup-repo.sh run demo-api
  assert_contains "$OUT" "⚠️ Redis's memory setting isn't 'noeviction', which BullMQ needs
   Tip: Run: redis-cli CONFIG SET maxmemory-policy noeviction (and set it in the Redis config file to keep it)"
  nc_answers 0 "+PONG" "-NOAUTH Authentication required."
  run setup-repo.sh run demo-api
  assert_contains "$OUT" "⚠️ Couldn't read Redis's memory setting (BullMQ needs 'noeviction')
   Tip: Check it with: redis-cli CONFIG GET maxmemory-policy"
}

test_docker_desktop_is_started_to_look_and_quit_again_when_unused() {
  setup_box; demo local_services=redis; brew_has redis 7.2.4 started; docker_runs; nc_answers 0 "+PONG"
  echo 1 > "$T/docker-info-rc"
  fake_cmd open "case \"\$*\" in *Docker*) rm -f '$T/docker-info-rc' ;; esac"   # Docker answers once it's opened
  printf 'REDIS_HOST=127.0.0.1\nREDIS_PORT=6379\n' >> "$T/work/demo-api/.env"
  run setup-repo.sh run demo-api
  assert_rc 0
  assert_contains "$OUT" "   Docker Desktop isn't running. Starting it to look for Docker copies (up to 3 s)..."
  assert_contains "$OUT" "   Quit Docker Desktop again (it was only started to look for Docker copies)."
  assert_contains "$(fake_calls open)" "open -g -a Docker"
  assert_contains "$(fake_calls osascript)" "osascript -e quit app \"Docker\""
}

test_docker_desktop_that_does_not_start_or_hangs() {
  setup_box; demo local_services=redis; brew_has redis 7.2.4 started; docker_runs; nc_answers 0
  fake_cmd docker 'case "$1" in info) exec /bin/sleep 30 ;; esac'   # docker info never answers
  export FAST_SLEEP=0.05
  run setup-repo.sh run demo-api
  assert_rc 0
  assert_contains "$OUT" "⚠️ Docker Desktop didn't start within 3 seconds, so Docker copies couldn't be checked
   Tip: Open Docker Desktop yourself, wait until it says it's running, then run /flow-setup-repo demo-api again."
  assert_contains "$OUT" "✅ Local Redis: using Homebrew Redis 7.2.4, answering on port 6379"
  assert_not_contains "$OUT" "Quit Docker Desktop"
}

test_env_pointing_elsewhere_lists_every_line_to_change() {
  setup_box; demo "local_services=redis, rabbitmq"; brew_has redis 7.2.4 started; brew_has rabbitmq 4.1.0 started
  nc_answers 0 "+PONG"
  printf 'REDIS_HOST=redis.dev.example.test\nREDIS_PORT=6380\nREDIS_USE_TLS=true\nRABBITMQ_URL=amqps://u:p@mq.dev.example.test:5671/vhost\n' >> "$T/work/demo-api/.env"
  run setup-repo.sh run demo-api
  assert_rc 0
  assert_contains "$OUT" "   (The Redis your .env points to answers, but it isn't the one on this Mac.)
⚠️ demo-api/.env: REDIS_HOST points somewhere else, not to this Mac
⚠️ demo-api/.env: REDIS_PORT isn't the port of your local Redis (6379)
⚠️ demo-api/.env: REDIS_USE_TLS is on, but a local Redis doesn't use TLS
⚠️ demo-api/.env: RABBITMQ_URL uses amqps (TLS), but a local RabbitMQ doesn't use TLS
⚠️ demo-api/.env: RABBITMQ_URL points somewhere else, not to this Mac
   How to fix it (you change the file yourself; the AI never sees it):
   1. It's open in your text editor now: $T/work/demo-api/.env
   2. Note down the old values first, if you'll need them again (e.g. for the dev server).
   3. Set these lines for your local copies:
        REDIS_HOST=127.0.0.1
        REDIS_PORT=6379
        REDIS_USER=
        REDIS_PASSWORD=
        REDIS_USE_TLS=false
        RABBITMQ_URL=amqp://guest:guest@127.0.0.1:5672   (guest / guest is a local RabbitMQ's built-in login; it only works from this Mac)
   4. Save, then run /flow-setup-repo demo-api again."
  assert_contains "$OUT" "Result for demo-api: 0 to fix, 5 to look at."
  assert_not_contains "$OUT" "mq.dev.example.test"; assert_not_contains "$OUT" "redis.dev.example.test"
}

test_env_without_the_service_lines_or_with_wrong_ports() {
  setup_box; demo "local_services=redis, rabbitmq"; brew_has redis 7.2.4 started; brew_has rabbitmq 4.1.0 started
  nc_answers 0
  run setup-repo.sh run demo-api
  assert_contains "$OUT" "⚠️ demo-api/.env: REDIS_HOST isn't set
⚠️ demo-api/.env: REDIS_PORT isn't set
⚠️ demo-api/.env: RABBITMQ_URL isn't set"
  printf 'PORT=1\nREDIS_HOST=127.0.0.1\nREDIS_PORT=6379\nREDIS_USE_TLS=false\nRABBITMQ_URL=amqp://guest:guest@localhost:5673\n' > "$T/work/demo-api/.env"
  run setup-repo.sh run demo-api
  assert_contains "$OUT" "⚠️ demo-api/.env: the Redis that .env points to doesn't answer
⚠️ demo-api/.env: RABBITMQ_URL doesn't use the port of your local RabbitMQ (5672)"
  assert_contains "$OUT" "        REDIS_USE_TLS=false"
  printf 'REDIS_HOST=127.0.0.1\nREDIS_PORT=6379\nRABBITMQ_URL=amqp://localhost\n' > "$T/work/demo-api/.env"
  nc_answers 0 "-NOAUTH Authentication required."
  fake_cmd nc "case \" \$* \" in *' -z '*) case \"\$*\" in *5672*) exit 1 ;; esac; exit 0 ;; esac; printf -- '-NOAUTH Authentication required.\r\n'"
  run setup-repo.sh run demo-api
  assert_contains "$OUT" "❌ Local RabbitMQ (Homebrew RabbitMQ 4.1.0) doesn't answer on port 5672"
  assert_contains "$OUT" "✅ .env: Redis points to this Mac, and it answers"
  assert_contains "$OUT" "⚠️ demo-api/.env: the RabbitMQ that .env points to doesn't answer"
}

test_your_own_docker_copies_need_your_own_logins_in_env() {
  setup_box; demo "local_services=redis, rabbitmq"; docker_runs
  docker_has my-redis running redis:7; docker_has my-rabbit running rabbitmq:3-management; nc_answers 0
  run setup-repo.sh run demo-api
  assert_contains "$OUT" "        REDIS_USER=  and  REDIS_PASSWORD=   (the user and password you gave your own Docker Redis; empty if none)"
  assert_contains "$OUT" "        RABBITMQ_URL=amqp://<user>:<password>@127.0.0.1:5672   (the user and password of your own Docker RabbitMQ)"
}

test_list_shows_each_repo_state() {
  setup_box
  run setup-repo.sh list
  assert_rc 0
  assert_eq "$OUT" "Repo setup on this Mac (flow-setup-repo)
⚠️ No repos registered yet. Run /flow-configure-repo first.

Saved choice for when you have both a Homebrew and a Docker copy: Redis: none · RabbitMQ: none"
  repo_config a-gone
  repo_config b-new; clone b-new
  repo_config c-nomods; clone c-nomods; printf 'setup_on: 2026-10-01 10:00\nsetup_tests: passed\n' >> "$A/local/repos/c-nomods.yaml"
  repo_config d-failed; clone d-failed; mkdir -p "$T/work/d-failed/node_modules"; printf 'setup_on: 2026-10-02 10:00\nsetup_tests: failed\n' >> "$A/local/repos/d-failed.yaml"
  repo_config e-slow; clone e-slow; mkdir -p "$T/work/e-slow/node_modules"; printf 'setup_on: 2026-10-03 10:00\nsetup_tests: timed out\n' >> "$A/local/repos/e-slow.yaml"
  repo_config f-good local_services=redis; clone f-good; mkdir -p "$T/work/f-good/node_modules"; printf 'setup_on: 2026-10-04 10:00\nsetup_tests: passed\n' >> "$A/local/repos/f-good.yaml"
  repo_config g-go language=go; clone g-go; printf 'setup_on: 2026-10-05 10:00\n' >> "$A/local/repos/g-go.yaml"
  user_settings LOCAL_REDIS_FROM=docker
  run setup-repo.sh list
  assert_rc 0
  assert_eq "$OUT" "Repo setup on this Mac (flow-setup-repo)
⚠️ a-gone: not on this Mac (or its path isn't saved)
   Tip: Clone it yourself, then /flow-configure-repo a-gone path <folder>.
⚠️ b-new: cloned, not set up yet
   Tip: Run /flow-setup-repo b-new
⚠️ c-nomods: set up on 2026-10-01 10:00, but its packages are gone
   Tip: Run /flow-setup-repo c-nomods
⚠️ d-failed: set up on 2026-10-02 10:00, but its tests failed
   Tip: See local/logs/setup-d-failed.log, then run /flow-setup-repo d-failed again.
⚠️ e-slow: set up on 2026-10-03 10:00, but its tests timed out
   Tip: See local/logs/setup-e-slow.log, then run /flow-setup-repo e-slow again.
✅ f-good: set up on 2026-10-04 10:00 · tests: passed · services: redis
✅ g-go: set up on 2026-10-05 10:00 · tests: not run · services: none

Saved choice for when you have both a Homebrew and a Docker copy: Redis: docker · RabbitMQ: none"
}
test_run_all_checks_the_bullmq_memory_setting_once_when_two_repos_use_bullmq() {
  setup_box
  demo local_services=bullmq
  repo_config demo-jobs local_services=bullmq install_command=none test_command=none env_file=none node_version=none
  clone demo-jobs
  brew_has redis 7.2.4 started; nc_answers 0 "+PONG" '*2|$16|maxmemory-policy|$10|noeviction'
  printf 'REDIS_HOST=127.0.0.1\nREDIS_PORT=6379\n' >> "$T/work/demo-api/.env"
  run setup-repo.sh run all
  assert_rc 0
  assert_contains "$OUT" "✅ Local Redis: checked above"
  assert_eq "$(printf '%s\n' "$OUT" | grep -c 'memory setting is right for BullMQ')" "1"
}
