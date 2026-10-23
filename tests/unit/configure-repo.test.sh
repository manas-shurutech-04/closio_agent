# scripts/configure-repo.sh: the repo registry (config/repos/<repo>.yaml, local/repos/<repo>.yaml), what detect reads
# from a clone, the dev keys through the (stand-in) dialogs into the fake Keychain, the dev address and the ruleset.

setup_repos() { # a sandbox with no registered repo (the real ones are removed from the copy)
  sandbox
  rm -f "$A"/config/repos/*.yaml
  export OSASCRIPT_BIN="$TESTS_DIR/fakes/bin/osascript"
}
registry() { # <repo>: a complete, valid config/repos/<repo>.yaml
  cat > "$A/config/repos/$1.yaml" <<EOF
# Shared repo facts for $1
name: $1
gitlab_url: https://jcvs.example.com/closio/backend/$1.git
gitlab_path: closio/backend/$1
type: BE
language: node
role: WS2 service: test
base_branch: develop
node_version: 22   # from the Dockerfile
install_command: npm ci
health_url: /api/v1/health-checker
test_command: npm test
local_services: redis
calls: none
dev_keys: none
dev_keys_optional: none
mr_target_branch: develop
EOF
}
set_key() { # <repo> <key> <value>: changes one line of config/repos/<repo>.yaml, or adds it
  local f="$A/config/repos/$1.yaml"
  if grep -q "^$2:" "$f"; then
    awk -v k="$2" -v v="$3" 'index($0, k ":") == 1 { print k ": " v; next } { print }' "$f" > "$f.new" && mv "$f.new" "$f"
  else
    printf '%s: %s\n' "$2" "$3" >> "$f"
  fi
}
clone() { # <folder> <origin URL or ""> [remote branches…]: a local clone, as far as the script can tell
  local d="$1" url="$2" b
  shift 2
  git init -q -b main "$d" && git -C "$d" commit -q --allow-empty -m init || fail "git init $d"
  [ -z "$url" ] || git -C "$d" remote add origin "$url"
  for b in "$@"; do git -C "$d" update-ref "refs/remotes/origin/$b" HEAD; done
}
real() { (cd "$1" && pwd -P); }
cloned_demo() { # demo registered and cloned in $T/clones/demo, with its local file
  registry demo
  clone "$T/clones/demo" "https://jcvs.example.com/closio/backend/demo.git" develop main
  mkdir -p "$A/local/repos"
  printf 'local_path: %s\n' "$(real "$T/clones/demo")" > "$A/local/repos/demo.yaml"
}
dialogs_give() { # <value>: the heads-up dialog answers Continue, the hidden box gives <value>
  fake_cmd osascript "case \"\$*\" in *'hidden answer'*) printf '%s\\n' '$1' ;; *) echo Continue ;; esac"
}
nvm_with_22() { # an nvm folder where Node 22 is installed
  mkdir -p "$T/nvm/versions/node/v22.14.0"; cp "$TESTS_DIR/fakes/nvm/nvm.sh" "$T/nvm/"
  export NVM_DIR="$T/nvm"
}

# ---------------------------------------------------------------- folder and usage
test_check_folder_in_and_outside_the_closio_agent_folder() {
  setup_repos
  run configure-repo.sh check-folder
  assert_rc 0; assert_eq "$OUT" "✅ Started in the closio-agent folder"
  run_in "$T" bash "$A/scripts/configure-repo.sh" check-folder
  assert_rc 1
  assert_contains "$OUT" "❌ Not started in the closio-agent folder (current folder: $(cd "$T" && pwd))"
  assert_contains "$OUT" "        Always start Claude Code or Codex in the closio-agent folder."
}
test_each_action_with_the_wrong_words_shows_its_usage() {
  setup_repos
  local a
  for a in "detect" "validate" "set-path demo" "set-dev-url demo" "dev-url" "keys" "key demo" "show" "ruleset"; do
    run configure-repo.sh $a
    assert_rc 1; assert_match "$OUT" "^Usage: bash scripts/configure-repo.sh ${a%% *} " "usage of: $a"
  done
  run configure-repo.sh
  assert_rc 1; assert_contains "$OUT" "Usage: bash scripts/configure-repo.sh check-folder | list | detect <path> |"
}
test_a_bad_or_unregistered_repo_name() {
  setup_repos
  run configure-repo.sh show "Bad_Name"
  assert_rc 1; assert_eq "$OUT" "❌ 'Bad_Name' isn't a valid repo name
   Fix: Use the repo's folder name, e.g. nodejs-ws2closio."
  run configure-repo.sh validate ghost
  assert_rc 1; assert_eq "$OUT" "❌ ghost isn't registered yet
   Fix: Run /flow-configure-repo with the path of a local clone to register it."
}

# ---------------------------------------------------------------- detect
test_detect_needs_a_git_clone() {
  setup_repos
  mkdir -p "$T/plain"
  run configure-repo.sh detect "$T/plain"
  assert_rc 1; assert_contains "$OUT" "❌ No git repo at $T/plain"
}
test_detect_a_node_backend_clone() {
  setup_repos
  local c="$T/clones/ws1"
  clone "$c" "https://jane:glpat-Secret123@jcvs.example.com/closio/backend/nodejs-ws1closio.git" develop main feature-x
  git -C "$c" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop
  cat > "$c/package.json" <<'EOF'
{ "name": "ws1",
  "scripts": { "dev": "nodemon", "start": "node .", "lint": "eslint .", "check:circular": "madge", "test": "mocha",
               "test:unit": "mocha unit", "test:api": "mocha api", "coverage:check": "nyc check-coverage --statements=80 --branches 70",
               "migrate": "sequelize db:migrate", "seed": "sequelize db:seed:all" },
  "dependencies": { "express": "4", "amqplib": "1", "bullmq": "1", "ioredis": "5" },
  "devDependencies": { "mocha": "10", "chai": "4", "nyc": "15" } }
EOF
  echo "FROM node:20-alpine" > "$c/Dockerfile"; echo "{}" > "$c/package-lock.json"
  mkdir -p "$c/.husky" "$c/src/migrations" "$c/test/unit" "$c/test/api"
  echo "npm run lint" > "$c/.husky/pre-commit"; echo "npm run coverage:check" > "$c/.husky/pre-push"
  echo '    test: ["CMD", "curl", "-f", "http://localhost:3000/api/v1/health-checker"]' > "$c/docker-compose.yml"
  printf "module.exports = {\n  'migrations-path': path.resolve('src', 'migrations'),\n  'seeders-path': path.resolve('src', 'seeders'),\n};\n" > "$c/.sequelizerc"
  : > "$c/src/migrations/20260101000000-a.js"; : > "$c/src/migrations/20260102000000-b.js"
  printf 'channel.consume(q)\nconst q = new Queue("x")\n' > "$c/src/queue.js"
  : > "$c/test/setup.js"
  printf 'PORT=3000\nPG_HOST=db\nWS2CLOSIO_URL=x\nCLOSIO_WS2_URL=y\nWS2NOTIF_URL=z\nRABBITMQ_URL=q\n' > "$c/.env.example"
  echo "SECRET_VALUE_NEVER_READ=1" > "$c/.env"; : > "$c/.env.local"
  run configure-repo.sh detect "$c"
  assert_rc 0
  local p; p="$(real "$c")"
  assert_eq "$(printf '%s\n' "$OUT" | head -4)" "# Suggestions read from $p. Check every line with the user before saving.
name: nodejs-ws1closio
gitlab_url: https://jcvs.example.com/closio/backend/nodejs-ws1closio.git
gitlab_path: closio/backend/nodejs-ws1closio"
  local line
  for line in "type: BE" "# Remote branches that could be the base branch: develop main " "# GitLab's default branch: develop" \
      "language: node" "node_version: 20   # from the Dockerfile; run everything in this repo after 'nvm use v20'" \
      "install_command: npm ci" "dev_command: npm run dev" "start_command: npm start" \
      "check_commands: npm run lint, npm run check:circular" "test_command: npm test" "test_framework: mocha, chai, nyc" \
      "test_unit_command: npm run test:unit" "test_api_command: npm run test:api" "test_layout: test/api test/unit" \
      "coverage_command: npm run coverage:check" "coverage_rules: --statements=80 --branches 70 " \
      "coverage_enforced_by: husky pre-push" "health_url: /api/v1/health-checker" \
      "migration_tool: sequelize-cli" "migrations_path: src/migrations" "seeders_path: src/seeders" \
      "# Existing migrations: 2, latest: 20260102000000-b.js" "migration_commands: npm run migrate" "seed_commands: npm run seed" \
      "queues: RabbitMQ (consumers: src/queue.js); BullMQ (queues defined in: src/queue.js)" \
      "local_services: redis, bullmq, rabbitmq" \
      "calls: nodejs-ws2closio, nodejs-ws2notification   # guessed from config variable names; confirm with the user" \
      "# .env files found (names only): .env .env.example .env.local " \
      "dev_keys: ws1-client-id, ws1-client-secret" "dev_keys_optional: db-user, db-password" \
      "dev_db_host:   # optional, ask the user (not secret)" "# local_path for set-path: $p"; do
    printf '%s\n' "$OUT" | grep -q -x -F -- "$line" || fail "line missing: $line
$OUT"
  done
  assert_not_contains "$OUT" "glpat-Secret123"; assert_not_contains "$OUT" "jane:"
  assert_not_contains "$OUT" "SECRET_VALUE_NEVER_READ"
}
test_detect_a_web_app_clone() {
  setup_repos
  local c="$T/clones/web"
  clone "$c" "git@jcvs.example.com:closio/web/closio-web-v2.git"
  cat > "$c/package.json" <<'EOF'
{ "scripts": { "dev": "vite", "test": "vitest run", "test:coverage": "vitest run --coverage" },
  "dependencies": { "vue": "3", "vite": "5" },
  "devDependencies": { "vitest": "1", "@vue/test-utils": "2", "@playwright/test": "1" } }
EOF
  echo "v18.19.0" > "$c/.nvmrc"; : > "$c/yarn.lock"
  printf 'export default { test: { coverage: { thresholds: { statements: 80, lines : 75 } } } }\n' > "$c/vitest.config.ts"
  echo "VITE_API_BASE_URL=http://localhost:3000" > "$c/.env.example"
  run configure-repo.sh detect "$c"
  assert_rc 0
  local line
  for line in "name: closio-web-v2" "gitlab_path: closio/web/closio-web-v2" "type: FE" "node_version: 18   # from the Dockerfile; run everything in this repo after 'nvm use v18'" \
      "install_command: yarn install --frozen-lockfile" "check_commands: none" "test_command: npm test" \
      "test_framework: vitest, @vue/test-utils, @playwright/test" "test_layout: " "coverage_command: npm run test:coverage" \
      "coverage_rules: lines:75 statements:80 " "coverage_enforced_by: not enforced by git hooks" \
      "health_url: /   # no health endpoint in a web app; the dev server's start page; confirm with the user" \
      "migration_tool: none" "queues: none" "local_services: none" \
      "calls: nodejs-ws1closio   # guessed from config variable names; confirm with the user" \
      "dev_keys: none" "dev_keys_optional: none"; do
    printf '%s\n' "$OUT" | grep -q -x -F -- "$line" || fail "line missing: $line
$OUT"
  done
  assert_not_contains "$OUT" "start_command"; assert_not_contains "$OUT" "dev_db_host"
}
test_detect_node_repos_without_tests_or_with_an_nycrc() {
  setup_repos
  local c="$T/clones/svc"
  clone "$c" ""
  printf '{ "scripts": { "test": "echo \\"Error: no test specified\\" && exit 1" }, "dependencies": { "redis": "4" } }\n' > "$c/package.json"
  run configure-repo.sh detect "$c"
  assert_rc 0
  local line
  for line in "name: svc" "gitlab_url: " "node_version: 22   # from the Dockerfile; run everything in this repo after 'nvm use v22'" \
      "install_command: npm install" "test_command: none   # no test suite (D25)" "test_framework: none" "coverage_rules: none" \
      "health_url:   # not found in the code; ask the user (every repo needs one)" "local_services: redis" "calls: none   # guessed from config variable names; confirm with the user"; do
    printf '%s\n' "$OUT" | grep -q -x -F -- "$line" || fail "line missing: $line
$OUT"
  done
  printf '{ "scripts": { "test": "mocha" } }\n' > "$c/package.json"
  printf '{ "statements": 90, "lines": 85 }\n' > "$c/.nycrc"
  mkdir -p "$c/src"; echo "router.get('/api/v1/health-check', h)" > "$c/src/routes.js"
  echo "REDIS_HOST=localhost" > "$c/.env.example"
  run configure-repo.sh detect "$c"
  for line in "test_command: npm test" "test_framework: unknown" "coverage_rules: statements:90 lines:85 " \
      "health_url: /api/v1/health-check" "local_services: redis"; do
    printf '%s\n' "$OUT" | grep -q -x -F -- "$line" || fail "line missing: $line
$OUT"
  done
}
test_detect_go_repos_and_other_repos() {
  setup_repos
  clone "$T/clones/gosvc" "https://jcvs.example.com/closio/go/gosvc.git"
  echo "module gosvc" > "$T/clones/gosvc/go.mod"
  printf 'build:\n\tgo build\ntest:\n\tgo test\n' > "$T/clones/gosvc/Makefile"
  : > "$T/clones/gosvc/main_test.go"
  run configure-repo.sh detect "$T/clones/gosvc"
  assert_rc 0
  local line
  for line in "language: go" "node_version: none   # not a Node repo" "install_command: go mod download" \
      "# Makefile targets: build test " "check_commands: go vet ./..." "test_command: go test ./..." "test_framework: go test" \
      "coverage_rules:   # ask the user (or none)" "coverage_enforced_by: not enforced by git hooks"; do
    printf '%s\n' "$OUT" | grep -q -x -F -- "$line" || fail "line missing: $line
$OUT"
  done
  rm -f "$T/clones/gosvc/main_test.go" "$T/clones/gosvc/Makefile"
  run configure-repo.sh detect "$T/clones/gosvc"
  assert_contains "$OUT" "test_command: none   # no *_test.go files found"
  assert_not_contains "$OUT" "Makefile"
  clone "$HOME/code/tool" ""
  run configure-repo.sh detect "~/code/tool"
  assert_rc 0
  for line in "name: tool" "language: other" "install_command:   # ask the user (no package.json or go.mod found)" \
      "test_command:   # ask the user (or none)" "migration_tool: none" "dev_keys: none" "# local_path for set-path: $(real "$HOME/code/tool")"; do
    printf '%s\n' "$OUT" | grep -q -x -F -- "$line" || fail "line missing: $line
$OUT"
  done
}

# ---------------------------------------------------------------- validate
test_validate_a_good_registry_file() {
  setup_repos; cloned_demo; nvm_with_22
  run configure-repo.sh validate demo
  assert_rc 0; assert_eq "$OUT" "✅ config/repos/demo.yaml is valid"
}
test_validate_warns_when_the_repos_node_is_not_in_nvm() {
  setup_repos; cloned_demo
  run configure-repo.sh validate demo
  assert_rc 0
  assert_eq "$OUT" "⚠️ Node 22 (what demo is built for) isn't installed in nvm
   Tip: Run: nvm install 22  (everything in demo runs on Node 22)
✅ config/repos/demo.yaml is valid"
}
test_validate_lists_every_problem() {
  setup_repos; cloned_demo; nvm_with_22
  printf 'not a key value line\nKey-With-Caps: x\n' >> "$A/config/repos/demo.yaml"
  set_key demo role ""
  set_key demo name other
  set_key demo type XX
  sed -i '' '/^node_version:/d' "$A/config/repos/demo.yaml"
  set_key demo health_url none
  set_key demo dev_base_url "ftp://dev.example.com"
  set_key demo gitlab_url "https://jane:pw@jcvs.example.com/closio/backend/demo.git"
  set_key demo base_branch release
  run configure-repo.sh validate demo
  assert_rc 1
  assert_contains "$OUT" "❌ config/repos/demo.yaml has lines that aren't 'key: value'
   Fix: Fix these lines: 17:not a key value line 18:Key-With-Caps: x"
  assert_contains "$OUT" "❌ config/repos/demo.yaml: 'role' is empty
   Fix: Run /flow-configure-repo demo and fill it in (or write 'none' where that's allowed)."
  assert_contains "$OUT" "❌ 'name' in config/repos/demo.yaml must be demo
   Fix: Change the name line to: name: demo"
  assert_contains "$OUT" "❌ 'type' must be FE or BE"
  assert_contains "$OUT" "❌ config/repos/demo.yaml: 'node_version' is empty
   Fix: Write the Node version the repo is built for (its Dockerfile), e.g. node_version: 22"
  assert_contains "$OUT" "❌ 'health_url' is 'none', but every repo needs one"
  assert_contains "$OUT" "❌ 'dev_base_url' must start with http:// or https://"
  assert_contains "$OUT" "❌ config/repos/demo.yaml looks like it contains a secret (a token, key or password in a URL)"
  assert_contains "$OUT" "❌ Branch 'release' (base_branch) doesn't exist on GitLab for demo (as last fetched)
   Fix: Check the name, or run 'git fetch' in $(real "$T/clones/demo") while on the VPN, then validate again."
  assert_eq "$(printf '%s\n' "$OUT" | grep -c '^❌')" "9"
  assert_not_contains "$OUT" "is valid"
}
test_validate_a_health_url_or_dev_address_in_the_wrong_form() {
  setup_repos; registry demo; nvm_with_22
  set_key demo health_url "api/v1/health"
  set_key demo dev_base_url "https://dev host.example.com"
  set_key demo language go
  sed -i '' '/^node_version:/d' "$A/config/repos/demo.yaml"
  run configure-repo.sh validate demo
  assert_rc 1
  assert_contains "$OUT" "❌ 'health_url' must be a path starting with /
   Fix: e.g. health_url: /api/v1/health-checker"
  assert_contains "$OUT" "❌ 'dev_base_url' isn't a plain web address"
  assert_eq "$(printf '%s\n' "$OUT" | grep -c '^❌')" "2" "a Go repo needs no node_version"
}

# ---------------------------------------------------------------- set-path
test_set_path_saves_the_clone() {
  setup_repos; registry demo
  clone "$HOME/w/demo" "git@jcvs.example.com:closio/backend/demo.git"
  run configure-repo.sh set-path demo "~/w/demo"
  assert_rc 0
  local p; p="$(real "$HOME/w/demo")"
  assert_eq "$OUT" "✅ Local path saved for demo: $p"
  assert_eq "$(cat "$A/local/repos/demo.yaml")" "# Where demo is on this Mac (F5). Private: local/ is never pushed.
local_path: $p"
}
test_set_path_not_cloned_yet() {
  setup_repos; registry demo
  run configure-repo.sh set-path demo not-cloned
  assert_rc 0
  assert_eq "$OUT" "⚠️ demo marked as not cloned yet on this Mac
   Tip: Cloning is manual: on the VPN, git clone https://jcvs.example.com/closio/backend/demo.git <your workspace folder>/demo, then run /flow-configure-repo demo path <that folder>."
  assert_eq "$(sed -n 2p "$A/local/repos/demo.yaml")" "local_path: "
}
test_set_path_refuses_the_wrong_folder() {
  setup_repos; registry demo
  mkdir -p "$T/plain"
  run configure-repo.sh set-path demo "$T/plain"
  assert_rc 1; assert_contains "$OUT" "❌ No git repo at $T/plain"
  clone "$T/other" "https://jcvs.example.com/closio/backend/other.git"
  run configure-repo.sh set-path demo "$T/other"
  assert_rc 1; assert_eq "$OUT" "❌ $(real "$T/other") is a clone of 'closio/backend/other', not 'closio/backend/demo'
   Fix: Give the path of the right clone of demo."
  clone "$T/no-remote" ""
  run configure-repo.sh set-path demo "$T/no-remote"
  assert_rc 1; assert_contains "$OUT" "is a clone of 'no GitLab remote', not 'closio/backend/demo'"
  clone "$T/a\$b" "https://jcvs.example.com/closio/backend/demo.git"
  run configure-repo.sh set-path demo "$T/a\$b"
  assert_rc 1; assert_eq "$OUT" "❌ The path has characters that aren't supported
   Fix: Move the clone to a simpler path."
  assert_no_file "$A/local/repos/demo.yaml"
}

# ---------------------------------------------------------------- dev address
test_set_dev_url_adds_it_after_the_health_url() {
  setup_repos; registry demo
  run configure-repo.sh set-dev-url demo "https://dev-demo.example.com/"
  assert_rc 0
  assert_eq "$OUT" "✅ demo: dev address saved in config/repos/demo.yaml (https://dev-demo.example.com)
   It's a shared file: commit it to closio-agent so the whole team gets it."
  assert_eq "$(grep -A1 '^health_url:' "$A/config/repos/demo.yaml" | tail -1)" "dev_base_url: https://dev-demo.example.com   # the repo on the dev environment (D72)"
  run configure-repo.sh set-dev-url demo "https://dev-demo.example.com"
  assert_rc 0; assert_eq "$OUT" "✅ demo: dev address unchanged (https://dev-demo.example.com)"
  run configure-repo.sh set-dev-url demo "https://dev2.example.com:8443/api"
  assert_rc 0; assert_contains "$OUT" "✅ demo: dev address changed in config/repos/demo.yaml, from https://dev-demo.example.com to https://dev2.example.com:8443/api"
  assert_eq "$(grep -c '^dev_base_url:' "$A/config/repos/demo.yaml")" "1"
  assert_no_file "$A/config/repos/demo.yaml.tmp.$$"
}
test_set_dev_url_without_a_health_url_line_adds_it_at_the_end() {
  setup_repos; registry demo
  sed -i '' '/^health_url:/d' "$A/config/repos/demo.yaml"
  run configure-repo.sh set-dev-url demo "http://10.0.0.5:3000"
  assert_rc 0
  assert_eq "$(tail -1 "$A/config/repos/demo.yaml")" "dev_base_url: http://10.0.0.5:3000   # the repo on the dev environment (D72)"
}
test_set_dev_url_refuses_what_is_not_a_plain_address() {
  setup_repos; registry demo
  local before; before="$(cat "$A/config/repos/demo.yaml")"
  for u in "ftp://dev.example.com" "https://user:pw@dev.example.com" "dev.example.com" "https://dev example.com"; do
    run configure-repo.sh set-dev-url demo "$u"
    assert_rc 1; assert_contains "$OUT" "❌ '$u' isn't a plain web address"
  done
  assert_eq "$(cat "$A/config/repos/demo.yaml")" "$before"
}
test_dev_url_of_one_repo_or_all() {
  setup_repos; registry demo; registry api
  set_key api dev_base_url "https://dev-api.example.com   # dev"
  run configure-repo.sh dev-url demo
  assert_rc 0; assert_eq "$OUT" "demo: not set"
  run configure-repo.sh dev-url all
  assert_rc 0; assert_eq "$OUT" "api: https://dev-api.example.com
demo: not set"
  run configure-repo.sh dev-url ghost
  assert_rc 1; assert_contains "$OUT" "❌ ghost isn't registered yet"
}
test_dev_url_all_with_no_repos() {
  setup_repos
  run configure-repo.sh dev-url all
  assert_rc 0; assert_eq "$OUT" "⚠️ No repos registered yet
   Tip: Run /flow-configure-repo with the path of a local clone to register one."
}

# ---------------------------------------------------------------- keys
test_keys_when_the_repo_needs_none_or_has_them_all() {
  setup_repos; registry demo
  run configure-repo.sh keys demo
  assert_rc 0; assert_eq "$OUT" "✅ demo needs no dev keys"
  set_key demo dev_keys "ws1-client-id   # WS1's own pair"
  keychain_set closio-agent.demo.ws1-client-id.dev v
  run configure-repo.sh keys demo
  assert_rc 0; assert_eq "$OUT" "✅ All dev keys for demo are already stored. To replace one, run /flow-configure-repo demo key <name>"
  assert_eq "$(fake_calls osascript)" ""
}
test_keys_asks_each_missing_key_and_stores_it() {
  setup_repos; registry demo
  set_key demo dev_keys "ws1-client-id, ws1-client-secret, ws2-client-id, ws2-client-secret, api-key"
  set_key demo dev_keys_optional "db-user, db-password"
  keychain_set closio-agent.demo.ws1-client-id.dev already
  dialogs_give "K3y-Value"
  run configure-repo.sh keys demo
  assert_rc 0
  assert_contains "$OUT" "Dev keys to add for demo: ws1-client-secret ws2-client-id ws2-client-secret api-key db-user db-password
Optional ones can be skipped with the Skip button: db-user, db-password"
  assert_contains "$OUT" "✅ closio-agent.demo.db-password.dev stored in the Keychain"
  assert_contains "$OUT" "Dev keys for demo: 6 stored, 0 skipped, 0 failed."
  assert_eq "$(cat "$FAKE_KEYCHAIN/closio-agent.demo.ws2-client-secret.dev")" "K3y-Value"
  assert_eq "$(cat "$FAKE_KEYCHAIN/closio-agent.demo.ws1-client-id.dev")" "already" "a stored key isn't asked again"
  local calls; calls="$(fake_calls osascript)"
  assert_contains "$calls" "Next: WS1's own DEV client secret, which it sends to the WS2s (x-client-secret): the value of WS1_AUTH_SECRET_KEY in WS1's .env."
  assert_contains "$calls" "the DEV client ID WS1 sends to demo (e.g. PRICING_ENGINE_CLIENT_ID for the pricing engine)"
  assert_contains "$calls" "the DEV client secret WS1 sends to demo (e.g. PRICING_ENGINE_SECRET_KEY)"
  assert_contains "$calls" "Paste the DEV value of 'api-key' for demo here:"
  assert_contains "$calls" "your DEV database user for demo"
  assert_contains "$calls" "your DEV database password for demo"
  assert_not_contains "$calls$OUT" "K3y-Value"
}
test_keys_skipped_or_not_stored() {
  setup_repos; registry demo
  set_key demo dev_keys "ws1-client-id"
  set_key demo dev_keys_optional "db-user"
  run configure-repo.sh keys demo
  assert_rc 0
  assert_contains "$OUT" "⚠️ Skipped closio-agent.demo.db-user.dev
   Tip: Add it later with: /flow-configure-repo demo key db-user"
  assert_contains "$OUT" "Dev keys for demo: 0 stored, 2 skipped, 0 failed."
  dialogs_give "v"
  fake_cmd security 'case "$1" in add-generic-password) exit 1 ;; *) exec bash "$TESTS_DIR/fakes/keychain.sh" "$@" ;; esac'
  run configure-repo.sh keys demo
  assert_rc 1
  assert_contains "$OUT" "❌ Couldn't store closio-agent.demo.ws1-client-id.dev in the Keychain
   Fix: Run /flow-configure-repo demo key ws1-client-id again."
  assert_contains "$OUT" "Dev keys for demo: 0 stored, 0 skipped, 2 failed."
}
test_key_asks_one_key() {
  setup_repos; registry demo
  dialogs_give "one"
  run configure-repo.sh key demo ws1-client-id
  assert_rc 0; assert_eq "$OUT" "✅ closio-agent.demo.ws1-client-id.dev stored in the Keychain"
  assert_contains "$(fake_calls osascript | head -1)" "WS1's own DEV client ID, which it sends to the WS2s (x-client-id): the value of WS1_AUTH_CLIENT_ID in WS1's .env"
  run configure-repo.sh key demo "Bad_Key"
  assert_rc 1; assert_eq "$OUT" "❌ 'Bad_Key' isn't a valid key name
   Fix: Use lowercase letters, numbers and '-'."
  run configure-repo.sh key ghost x
  assert_rc 1; assert_contains "$OUT" "❌ ghost isn't registered yet"
}

# ---------------------------------------------------------------- show and list
test_show_a_cloned_repo_with_its_keys() {
  setup_repos; cloned_demo
  set_key demo dev_base_url "https://dev-demo.example.com"
  set_key demo dev_keys "ws1-client-id, ws1-client-secret"
  set_key demo dev_keys_optional "db-user, db-password"
  set_key demo calls "nodejs-ws2closio"
  keychain_set closio-agent.demo.ws1-client-id.dev a; keychain_set closio-agent.demo.db-user.dev b
  run configure-repo.sh show demo
  assert_rc 0
  assert_eq "$OUT" "demo
   BE · WS2 service: test
   GitLab: closio/backend/demo · base branch: develop · MRs to: develop
   Tests: npm test · local services: redis · calls: nodejs-ws2closio
   Dev: https://dev-demo.example.com
✅ Local clone: $(real "$T/clones/demo")
✅ closio-agent.demo.ws1-client-id.dev stored
⚠️ closio-agent.demo.ws1-client-secret.dev missing (needed to test demo on dev)
   Tip: Run /flow-configure-repo demo key ws1-client-secret
✅ closio-agent.demo.db-user.dev stored
✅ closio-agent.demo.db-password.dev not set (optional)"
}
test_show_where_the_clone_is_not() {
  setup_repos; registry demo
  run configure-repo.sh show demo
  assert_contains "$OUT" "   Dev: not set (set it with /flow-setup-repo demo dev-address; needed for the dev checks of /flow-finish)"
  assert_contains "$OUT" "❌ Local path not set on this Mac
   Fix: Run /flow-configure-repo demo (give your clone's path, or say it's not cloned yet)."
  run configure-repo.sh set-path demo not-cloned
  run configure-repo.sh show demo
  assert_contains "$OUT" "⚠️ Not cloned on this Mac yet
   Tip: Cloning is manual: on the VPN, git clone https://jcvs.example.com/closio/backend/demo.git <your workspace folder>/demo, then run /flow-configure-repo demo path <that folder>."
  mkdir -p "$A/local/repos"; printf 'local_path: %s\n' "$T/moved" > "$A/local/repos/demo.yaml"
  run configure-repo.sh show demo
  assert_contains "$OUT" "❌ Local clone not found any more: $T/moved
   Fix: Run /flow-configure-repo demo again with the new path."
}
test_list_every_registered_repo() {
  setup_repos; registry api; cloned_demo
  run configure-repo.sh list
  assert_rc 0
  assert_eq "$(printf '%s\n' "$OUT" | head -3)" "Registered repos (config/repos/)

api"
  assert_contains "$OUT" "❌ Local path not set on this Mac"
  assert_contains "$OUT" "
demo
   BE · WS2 service: test"
  assert_eq "$(printf '%s\n' "$OUT" | tail -2)" "
Branch names for every repo: SCRUM-<number>/<short-description>, at most 5 words."
}
test_list_with_no_repos() {
  setup_repos
  run configure-repo.sh list
  assert_rc 0
  assert_eq "$OUT" "Registered repos (config/repos/)
⚠️ No repos registered yet
   Tip: Run /flow-configure-repo with the path of a local clone to register one.

Branch names for every repo: SCRUM-<number>/<short-description>, at most 5 words."
}

# ---------------------------------------------------------------- ruleset
test_ruleset_of_a_backend_and_a_web_repo() {
  setup_repos; registry demo; registry web; set_key web type FE
  mkdir -p "$A/rulesets"; : > "$A/rulesets/story-implementation-workflow.md"; : > "$A/rulesets/frontend-story-workflow.md"
  run configure-repo.sh ruleset demo
  assert_rc 0
  assert_eq "$OUT" "✅ demo (BE) follows the backend ruleset rulesets/story-implementation-workflow.md
   File: rulesets/story-implementation-workflow.md · your memory entries may change its points for you (flow-memory); the agent rules always win"
  run configure-repo.sh ruleset web
  assert_rc 0; assert_contains "$OUT" "✅ web (FE) follows the frontend ruleset rulesets/frontend-story-workflow.md"
}
test_ruleset_missing_file_or_type() {
  setup_repos; registry demo; registry odd; set_key odd type XX
  run configure-repo.sh ruleset demo
  assert_rc 1
  assert_eq "$OUT" "❌ The ruleset file rulesets/story-implementation-workflow.md is missing from closio-agent
   Fix: It's part of closio-agent: get it back with: git checkout -- rulesets/story-implementation-workflow.md (or pull the latest closio-agent), then run this again."
  run configure-repo.sh ruleset odd
  assert_rc 1; assert_eq "$OUT" "❌ 'type' in config/repos/odd.yaml must be FE or BE
   Fix: Edit config/repos/odd.yaml, then run this again."
}
