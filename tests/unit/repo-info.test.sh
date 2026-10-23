# scripts/lib/repo-info.sh: facts about a registered repo, read from config/repos/<repo>.yaml and local/repos/<repo>.yaml.
# The functions run in a bash of their own, with config/project-settings.sh and the library loaded (that's how the
# scripts use them, and how the lines are counted).

lib() { # <bash code>: runs it in $A with the library loaded; sets OUT and RC
  run_in "$A" bash -c 'AGENT_ROOT="$PWD"; . config/project-settings.sh; . scripts/lib/repo-info.sh; '"$1"
}
setup_repo() { # a registered repo "demo" (a Node repo, port from its .env) cloned in $T/clones/demo
  sandbox
  cat > "$A/config/repos/demo.yaml" <<'EOF'
# Shared repo facts for demo
name: demo
language: node
node_version: 20   # from the Dockerfile
port: from the repo's .env (DEMO_PORT)
health_url: /api/v1/health
dev_base_url: https://dev-demo.example.com/   # the repo on dev
EOF
  mkdir -p "$T/clones/demo" "$A/local/repos"
  printf 'local_path: %s\n' "$T/clones/demo" > "$A/local/repos/demo.yaml"
}

test_yaml_get_reads_a_value_without_its_comment() {
  setup_repo
  lib 'yaml_get config/repos/demo.yaml node_version; echo "|"; yaml_get config/repos/demo.yaml health_url; echo "|"; yaml_get config/repos/demo.yaml nothing; echo "|"; yaml_get no-file.yaml name; echo "rc=$?"'
  assert_eq "$OUT" "20
|
/api/v1/health
|
|
rc=0"
}
test_repo_file_path_and_your_gitlab_username() {
  setup_repo
  user_settings GITLAB_USERNAME=jdoe JIRA_EMAIL=x@example.com
  lib 'repo_file demo; repo_path demo; gitlab_username'
  assert_eq "$OUT" "$(cd "$A" && pwd)/config/repos/demo.yaml
$T/clones/demo
jdoe"
  rm -f "$A/local/user-settings.sh"
  lib 'echo "[$(gitlab_username)]"'
  assert_eq "$OUT" "[]"
}
test_repo_node_is_the_version_only_for_node_repos() {
  setup_repo
  printf 'name: gosvc\nlanguage: go\nnode_version: 22\n' > "$A/config/repos/gosvc.yaml"
  printf 'name: old\nnode_version: 18\n' > "$A/config/repos/old.yaml"
  printf 'name: none\nlanguage: node\nnode_version: none\n' > "$A/config/repos/none.yaml"
  lib 'for r in demo gosvc old none; do echo "$r=[$(repo_node $r)]"; done'
  assert_eq "$OUT" "demo=[20]
gosvc=[]
old=[18]
none=[]"
}
test_nvm_sh_finds_nvm() {
  setup_repo
  lib 'nvm_sh'
  assert_eq "$OUT" "$TESTS_DIR/fakes/nvm/nvm.sh"
  mkdir -p "$T/no-nvm"
  NVM_DIR="$T/no-nvm" lib 'nvm_sh; echo "rc=$?"'
  assert_rc 0; assert_contains "$OUT" "rc=0"
  assert_not_contains "$OUT" "$T/no-nvm"
}
test_repo_ready_says_what_is_missing() {
  setup_repo
  lib 'repo_ready demo && echo ready'
  assert_eq "$OUT" "ready"
  lib 'repo_ready "Bad Name"; echo "$?: $REPO_PROBLEM"'
  assert_eq "$OUT" "1: 'Bad Name' isn't a repo name"
  lib 'repo_ready ghost; echo "$?: $REPO_PROBLEM"'
  assert_eq "$OUT" "1: ghost isn't registered (run /flow-configure-repo <path of your clone>)"
  printf 'local_path: not-cloned\n' > "$A/local/repos/demo.yaml"
  lib 'repo_ready demo; echo "$?: $REPO_PROBLEM"'
  assert_eq "$OUT" "1: demo isn't cloned on this Mac (cloning is manual, D53; then /flow-configure-repo demo path <folder>)"
  printf 'local_path: %s\n' "$T/gone" > "$A/local/repos/demo.yaml"
  lib 'repo_ready demo; echo "$?"'
  assert_eq "$OUT" "1"
  rm -f "$A/local/repos/demo.yaml"
  lib 'repo_ready demo; echo "$?"'
  assert_eq "$OUT" "1"
}
test_the_port_comes_from_the_repos_env_file() {
  setup_repo
  printf 'OTHER=1\n  export DEMO_PORT="3007"   # the API\n' > "$T/clones/demo/.env"
  lib 'port_var demo; env_file_of demo; echo; repo_port demo; echo; repo_base_url demo'
  assert_eq "$OUT" "DEMO_PORT
.env
3007
http://localhost:3007"
  printf "env_file: .env.local\n" >> "$A/config/repos/demo.yaml"
  printf "DEMO_PORT='4000'\n" > "$T/clones/demo/.env.local"
  lib 'repo_port demo'
  assert_eq "$OUT" "4000"
}
test_no_port_when_the_variable_file_or_line_is_missing() {
  setup_repo
  lib 'repo_port demo; echo "no file: $?"'
  assert_eq "$OUT" "no file: 1"
  printf 'PORT=1\n' > "$T/clones/demo/.env"
  lib 'repo_port demo; echo "no line: $?"; repo_base_url demo; echo "no url: $?"'
  assert_eq "$OUT" "no line: 1
no url: 1"
  sed -i '' '/^port:/d' "$A/config/repos/demo.yaml"
  lib 'repo_port demo; echo "no variable: $?"'
  assert_eq "$OUT" "no variable: 1"
  printf 'port: from the repo'"'"'s .env (DEMO_PORT)\n' >> "$A/config/repos/demo.yaml"
  printf 'DEMO_PORT=\n' > "$T/clones/demo/.env"
  lib 'repo_base_url demo; echo "empty: $?"'
  assert_eq "$OUT" "empty: 1"
}
test_dev_url_and_health_path() {
  setup_repo
  printf 'name: bare\n' > "$A/config/repos/bare.yaml"
  printf 'name: off\ndev_base_url: none\n' > "$A/config/repos/off.yaml"
  lib 'repo_dev_url demo; echo; repo_health_path demo; echo; echo "[$(repo_dev_url bare)][$(repo_dev_url off)][$(repo_health_path bare)]"'
  assert_eq "$OUT" "https://dev-demo.example.com
/api/v1/health
[][][/]"
}
test_repo_answers_when_anything_answers_on_its_health_url() {
  setup_repo
  printf '[{"path": "^/api/v1/health$", "status": 503, "text": "down"}]' > "$T/routes.json"
  start_fake SRV http "$T/routes.json"
  printf 'DEMO_PORT=%s\n' "${SRV##*:}" > "$T/clones/demo/.env"
  lib 'repo_answers demo && echo answers'
  assert_eq "$OUT" "answers"
  assert_contains "$(fake_requests SRV)" '"p": "/api/v1/health"'
  printf 'DEMO_PORT=1\n' > "$T/clones/demo/.env"
  lib 'repo_answers demo; echo "nothing on port 1: $?"'
  assert_eq "$OUT" "nothing on port 1: 1"
  rm -f "$T/clones/demo/.env"
  lib 'repo_answers demo; echo "no port: $?"'
  assert_eq "$OUT" "no port: 1"
}
test_run_in_repo_runs_in_the_folder_on_the_repos_node_and_logs_it() {
  setup_repo
  run_in "$T/clones/demo" bash -c 'AGENT_ROOT="$1"; . "$1/config/project-settings.sh"; . "$1/scripts/lib/repo-info.sh"; run_in_repo "$PWD" 20 30 "$PWD/run.log" "pwd -P; echo out; echo err >&2"; echo "rc=$?"' _ "$A"
  assert_eq "$OUT" "rc=0"
  local log; log="$(cat "$T/clones/demo/run.log")"
  assert_match "$log" '^\$ pwd -P; echo out; echo err >&2   \(in .*/clones/demo, [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:]{8}\)'
  assert_contains "$log" "/clones/demo
out
err"
  assert_contains "$(fake_calls nvm)" "nvm use 20"
}
test_run_in_repo_gives_the_commands_exit_code() {
  setup_repo
  lib 'run_in_repo "'"$T"'/clones/demo" "" 30 "'"$T"'/r.log" "exit 5"; echo "rc=$?"'
  assert_eq "$OUT" "rc=5"
  FAKE_NVM_MISSING=20 lib 'run_in_repo "'"$T"'/clones/demo" 20 30 "'"$T"'/r.log" "echo never"; echo "rc=$?"'
  assert_eq "$OUT" "rc=98" "nvm use failed"
  lib 'run_in_repo "'"$T"'/no-folder" "" 30 "'"$T"'/r.log" "echo never"; echo "rc=$?"'
  assert_eq "$OUT" "rc=96" "the folder isn't there"
  assert_eq "$(grep -c -x never "$T/r.log")" "0" "a command that shouldn't run ran"
}
test_run_in_repo_stops_a_command_at_its_time_limit() {
  setup_repo
  lib 'run_in_repo "'"$T"'/clones/demo" "" 1 "'"$T"'/slow.log" "echo started; sleep 20; echo finished"; echo "rc=$?"'
  assert_eq "$OUT" "rc=124"
  local log; log="$(cat "$T/slow.log")"
  assert_eq "$(printf '%s\n' "$log" | grep -x -E 'started|finished')" "started"
  assert_contains "$log" "closio-agent: stopped after 1 seconds (time limit)"
}
test_result_lines_are_the_test_summary_of_the_last_command() {
  setup_repo
  cat > "$T/test.log" <<'EOF'

$ npm run lint   (in /x, 2026-10-23 10:00:00)
  99 passing
$ npm test   (in /x, 2026-10-23 10:01:00)
> mocha
  12 passing (3s)
  1 failing
  2 pending
Statements   : 85.1% ( 100/117 )
Lines        : 80% ( 90/112 )
ERROR: Coverage for lines (80%) does not meet global threshold (90%)
 Test Files  3 passed (3)
EOF
  lib 'last_output "'"$T"'/test.log" | head -2; echo ---; result_lines "'"$T"'/test.log"'
  assert_eq "$OUT" '$ npm test   (in /x, 2026-10-23 10:01:00)
> mocha
---
   12 passing (3s)
   1 failing
   2 pending
   Statements   : 85.1% ( 100/117 )
   Lines        : 80% ( 90/112 )
   ERROR: Coverage for lines (80%) does not meet global threshold (90%)
   Test Files  3 passed (3)'
}
