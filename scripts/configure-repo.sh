#!/usr/bin/env bash
# Repo registry for the flow-configure-repo command (F5, D35, D39, D50).
# Run it from the closio-agent folder:  bash scripts/configure-repo.sh <action>
#
#   check-folder              Is this session in the closio-agent folder? (strict rule, D42)
#   list                      Registered repos and their status on this Mac
#   detect <local-path>       Reads a local clone and prints suggested registry values (only reads;
#                             never reads what's inside .env files, only file and variable NAMES)
#   validate <repo>           Checks config/repos/<repo>.yaml (required fields, format, base branch)
#   set-path <repo> <path>    Saves where the repo is on this Mac (local/repos/<repo>.yaml, private)
#   set-path <repo> not-cloned
#   keys <repo>               Asks every missing dev key of the repo in one run (hidden macOS box)
#   key <repo> <name>         Asks one dev key
#   show <repo>               Everything about one repo: shared facts, local path, keys
#
# Shared facts:   config/repos/<repo>.yaml   (committed, no secrets)
# Personal facts: local/repos/<repo>.yaml    (git-ignored, never pushed)
# Dev keys:       Keychain, closio-agent.<repo>.<key>.dev (D33, D37)
# Every ❌ comes with the steps to fix it (rule A11).

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
REPOS_DIR="${REPOS_DIR:-$AGENT_ROOT/config/repos}"
LOCAL_REPOS_DIR="${LOCAL_REPOS_DIR:-$AGENT_ROOT/local/repos}"
CMD="/flow-configure-repo"

ok() { echo "✅ $1"; }
look() {
  echo "⚠️ $1"
  [ -n "${2:-}" ] && echo "   Tip: $2"
}
bad() {
  echo "❌ $1"
  echo "   Fix: $2"
  [ -n "${3:-}" ] && echo "        $3"
}

. "$AGENT_ROOT/scripts/lib/secret-dialogs.sh"

# ---------------------------------------------------------------- helpers

# Value of "key: value" in a flat YAML file ("" if missing). A " # comment" at the end is dropped.
yaml_get() { # <file> <key>
  [ -f "$1" ] || return 0
  grep -m1 -E "^$2:" "$1" | sed -E "s/^$2:[[:space:]]*//; s/[[:space:]]+#.*$//; s/[[:space:]]+$//"
}

valid_repo_name() { printf '%s' "$1" | grep -q -E '^[a-z0-9][a-z0-9._-]*$'; }
shared_file() { echo "$REPOS_DIR/$1.yaml"; }
local_file() { echo "$LOCAL_REPOS_DIR/$1.yaml"; }

# GitLab address without any user name or token that may be written into it.
clean_url() { printf '%s' "$1" | sed -E 's#://[^/@]*@#://#'; }
gitlab_path_of() { clean_url "$1" | sed -E 's#^[a-z]+://[^/]+/##; s#^[^@]+@[^:]+:##; s#\.git$##'; }

key_service() { echo "$KEYCHAIN_PREFIX.$1.$2.dev"; }

key_description() { # <repo> <key>
  case "$2" in
    ws2-client-id) echo "the DEV client ID of $1 (the x-client-id header)" ;;
    ws2-client-secret) echo "the DEV client secret of $1 (the x-client-secret header)" ;;
    db-user) echo "your DEV database user for $1" ;;
    db-password) echo "your DEV database password for $1" ;;
    *) echo "the DEV value of '$2' for $1" ;;
  esac
}

list_items() { printf '%s' "$1" | tr ',' '\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | grep -v -x 'none' | grep -v '^$'; }

require_registered() {
  if ! valid_repo_name "$1"; then
    bad "'$1' isn't a valid repo name" "Use the repo's folder name, e.g. nodejs-ws2closio."
    exit 1
  fi
  if [ ! -f "$(shared_file "$1")" ]; then
    bad "$1 isn't registered yet" "Run $CMD with the path of a local clone to register it."
    exit 1
  fi
}

# ---------------------------------------------------------------- detect (only reads)

detect() {
  local path="$1" url name pkg scripts deps
  case "$path" in "~"*) path="$HOME${path#\~}" ;; esac
  if [ ! -d "$path/.git" ]; then
    bad "No git repo at $path" "Give the full path of a local clone (the folder that contains .git)."
    exit 1
  fi
  path="$(cd "$path" && pwd -P)"
  url="$(clean_url "$(git -C "$path" remote get-url origin 2>/dev/null)")"
  name="$(basename "$(gitlab_path_of "$url")")"
  [ -n "$name" ] || name="$(basename "$path")"
  pkg="$path/package.json"

  echo "# Suggestions read from $path. Check every line with the user before saving."
  echo "name: $name"
  echo "gitlab_url: $url"
  echo "gitlab_path: $(gitlab_path_of "$url")"

  if [ -f "$pkg" ]; then
    scripts="$(node -e 'const p=require(process.argv[1]);for (const [k,v] of Object.entries(p.scripts||{})) console.log(k+"\t"+v)' "$pkg" 2>/dev/null)"
    deps="$(node -e 'const p=require(process.argv[1]);console.log(Object.keys({...p.dependencies,...p.devDependencies}).join(" "))' "$pkg" 2>/dev/null)"
  else
    scripts=""; deps=""
  fi
  has_dep() { case " $deps " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
  has_script() { printf '%s\n' "$scripts" | cut -f1 | grep -q -x "$1"; }
  script_text() { printf '%s\n' "$scripts" | awk -F'\t' -v k="$1" '$1==k {print $2; exit}'; }

  if has_dep vue || has_dep react || has_dep vite; then echo "type: FE"; else echo "type: BE"; fi
  echo "role:   # ask the user, e.g. 'WS2 service: core Closio APIs', 'BFF', 'RabbitMQ consumer'"
  echo "# Remote branches that could be the base branch: $(git -C "$path" branch -r 2>/dev/null | sed 's#^ *origin/##' | grep -x -E 'develop|development|dev|master|main|staging|release' | tr '\n' ' ')"
  echo "# GitLab's default branch: $(git -C "$path" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
  echo "base_branch:   # ask the user (it can differ per repo)"

  # Language: Node (package.json), Go (go.mod) or something else. Node suggestions only apply to Node repos.
  local lang="other"
  [ -f "$pkg" ] && lang="node"
  [ "$lang" = "other" ] && [ -f "$path/go.mod" ] && lang="go"
  echo "language: $lang"
  if [ "$lang" = "node" ]; then
    # Node version the repo is built for. Everything in the repo runs on this version (rule A13, D52).
    local nodev
    nodev="$(grep -h -m1 -i -o -E '^FROM[[:space:]]+node:[0-9]+' "$path/Dockerfile" 2>/dev/null | grep -o -E '[0-9]+$')"
    [ -z "$nodev" ] && nodev="$(grep -o -E '^v?[0-9]+' "$path/.nvmrc" 2>/dev/null | tr -d v)"
    echo "node_version: ${nodev:-$NODE_MAJOR}   # from the Dockerfile; run everything in this repo after 'nvm use v${nodev:-$NODE_MAJOR}'"
    if [ -f "$path/package-lock.json" ]; then echo "install_command: npm ci"
    elif [ -f "$path/yarn.lock" ]; then echo "install_command: yarn install --frozen-lockfile"
    else echo "install_command: npm install"; fi
    has_script dev && echo "dev_command: npm run dev"
    has_script start && echo "start_command: npm start"
    local lint=""
    has_script lint && lint="npm run lint"
    has_script check:circular && lint="${lint:+$lint, }npm run check:circular"
    echo "check_commands: ${lint:-none}"

    local test_text frameworks=""
    test_text="$(script_text test)"
    for f in mocha chai sinon supertest nyc vitest jest @vue/test-utils playwright @playwright/test cypress; do
      has_dep "$f" && frameworks="${frameworks:+$frameworks, }$f"
    done
    if [ -z "$test_text" ] || printf '%s' "$test_text" | grep -q "no test specified"; then
      echo "test_command: none   # no test suite (D25)"
      echo "test_framework: none"
    else
      echo "test_command: npm test"
      echo "test_framework: ${frameworks:-unknown}"
    fi
    has_script test:unit && echo "test_unit_command: npm run test:unit"
    has_script test:api && echo "test_api_command: npm run test:api"
    echo "test_layout: $(cd "$path" && ls -d test/* tests/* 2>/dev/null | grep -v -E '\.(js|ts)$' | head -6 | tr '\n' ' ' | sed 's/ $//')"
    if has_script coverage:check; then echo "coverage_command: npm run coverage:check"
    elif has_script test:coverage; then echo "coverage_command: npm run test:coverage"; fi
    local nycrc cov=""
    for nycrc in "$path/.nycrc" "$path/.nycrc.json"; do
      [ -f "$nycrc" ] && cov="$(grep -o -E '"(statements|branches|functions|lines)"[[:space:]]*:[[:space:]]*[0-9]+' "$nycrc" | tr -d '" ' | tr '\n' ' ')"
    done
    [ -z "$cov" ] && cov="$(script_text coverage:check | grep -o -E -- '--(statements|branches|functions|lines)[= ][0-9]+' | tr '\n' ' ')"
    [ -z "$cov" ] && cov="$(grep -h -o -E '(statements|branches|functions|lines)[[:space:]]*:[[:space:]]*[0-9]+' "$path"/vitest.config.* "$path"/vite.config.* 2>/dev/null | tr -d ' ' | sort -u | tr '\n' ' ')"
    if printf '%s' "$test_text" | grep -q "no test specified" || [ -z "$test_text" ]; then
      echo "coverage_rules: none"
    else
      echo "coverage_rules: ${cov:-   # not found; ask the user}"
    fi
    local hooks=""
    for h in pre-commit pre-push; do
      grep -q -i "coverage" "$path/.husky/$h" 2>/dev/null && hooks="${hooks:+$hooks, }husky $h"
    done
    echo "coverage_enforced_by: ${hooks:-not enforced by git hooks}"
  elif [ "$lang" = "go" ]; then
    echo "node_version: none   # not a Node repo"
    echo "install_command: go mod download"
    echo "dev_command:   # ask the user (e.g. go run ./cmd/<app>)"
    [ -f "$path/Makefile" ] && echo "# Makefile targets: $(grep -o -E '^[a-zA-Z0-9_-]+:' "$path/Makefile" | tr -d ':' | head -10 | tr '\n' ' ')"
    echo "check_commands: go vet ./..."
    if find "$path" -name '*_test.go' -not -path '*/vendor/*' 2>/dev/null | grep -q .; then
      echo "test_command: go test ./..."
      echo "test_framework: go test"
      echo "coverage_rules:   # ask the user (or none)"
    else
      echo "test_command: none   # no *_test.go files found"
      echo "test_framework: none"
      echo "coverage_rules: none"
    fi
    echo "coverage_enforced_by: not enforced by git hooks"
  else
    echo "node_version: none   # not a Node repo"
    echo "install_command:   # ask the user (no package.json or go.mod found)"
    echo "dev_command:   # ask the user"
    echo "check_commands:   # ask the user (or none)"
    echo "test_command:   # ask the user (or none)"
    echo "test_framework:   # ask the user (or none)"
    echo "coverage_rules:   # ask the user (or none)"
  fi
  echo "port:   # ask the user (it's in the repo's .env, which the AI doesn't read)"
  # Health URL: first the URL the repo's own docker-compose health check calls, then a full path in the code.
  local health
  health="$(grep -h -o -E 'https?://localhost:[0-9]+/[A-Za-z0-9/_-]*health[A-Za-z0-9/_-]*' "$path"/docker-compose*.yml 2>/dev/null | head -1 | sed -E 's#^https?://localhost:[0-9]+##')"
  [ -z "$health" ] && health="$(grep -r -h -o -E "['\"\`]/(api/)?v[0-9]+/health[a-z-]*['\"\`]" "$path/src" 2>/dev/null | head -1 | tr -d "'\"\`")"
  if [ -n "$health" ]; then
    echo "health_url: $health"
  elif has_dep vue || has_dep react || has_dep vite; then
    echo "health_url: /   # no health endpoint in a web app; the dev server's start page; confirm with the user"
  else
    echo "health_url:   # not found in the code; ask the user (every repo needs one)"
  fi

  if [ -f "$path/.sequelizerc" ]; then
    local mig seed
    mig="$(grep -E "migrations-path" "$path/.sequelizerc" | grep -o -E "'[^']+'" | tail -n +2 | tr -d "'" | paste -sd/ -)"
    seed="$(grep -E "seeders-path" "$path/.sequelizerc" | grep -o -E "'[^']+'" | tail -n +2 | tr -d "'" | paste -sd/ -)"
    echo "migration_tool: sequelize-cli"
    echo "migrations_path: ${mig:-src/migrations}"
    echo "seeders_path: ${seed:-src/seeders}"
    echo "migration_name_pattern: YYYYMMDDHHMMSS-<short-description>.js"
    echo "seeder_name_pattern: YYYYMMDDHHMMSS-seed-<name>.js"
    echo "# Existing migrations: $(ls "$path/${mig:-src/migrations}" 2>/dev/null | wc -l | tr -d ' '), latest: $(ls "$path/${mig:-src/migrations}" 2>/dev/null | tail -1)"
    local mc="" sc=""
    for s in migration:generate migrate migrate:undo; do has_script "$s" && mc="${mc:+$mc, }npm run $s"; done
    for s in seed seed:undo; do has_script "$s" && sc="${sc:+$sc, }npm run $s"; done
    echo "migration_commands: ${mc:-none}"
    echo "seed_commands: ${sc:-none}"
  else
    echo "migration_tool: none"
  fi

  local queues="" services=""
  if has_dep amqplib; then
    queues="RabbitMQ (consumers: $(cd "$path" && grep -r -l -E 'consume\(' src 2>/dev/null | head -4 | tr '\n' ' ' | sed 's/ $//'))"
  fi
  if has_dep bullmq; then
    queues="${queues:+$queues; }BullMQ (queues defined in: $(cd "$path" && grep -r -l -E 'new (Queue|Worker)\(' src 2>/dev/null | head -4 | tr '\n' ' ' | sed 's/ $//'))"
  fi
  echo "queues: ${queues:-none}"
  local envnames=""
  [ -f "$path/.env.example" ] && envnames="$(grep -o -E '^[A-Za-z_][A-Za-z0-9_]*=' "$path/.env.example" | tr -d '=' | tr '\n' ' ')"
  if has_dep ioredis || has_dep redis || has_dep bullmq || printf '%s' " $envnames " | grep -q " REDIS_HOST "; then services="redis"; fi
  has_dep bullmq && services="${services:+$services, }bullmq"
  if has_dep amqplib || printf '%s' " $envnames " | grep -q " RABBITMQ_URL "; then services="${services:+$services, }rabbitmq"; fi
  echo "local_services: ${services:-none}"

  # Which other repos it calls, guessed from config variable NAMES only.
  local calls=""
  for pair in "WS2CLOSIO:nodejs-ws2closio" "CLOSIO_WS2:nodejs-ws2closio" "WS2NOTIF:nodejs-ws2notification" "WS2PRICINGENGINE:nodejs-ws2pricingengine" \
              "PRICING_ENGINE:nodejs-ws2pricingengine" "WS2TARGETSALES:nodejs-ws2targetsalesincentive" "WS2AUTH:ws2jauth" "VITE_API_BASE_URL:nodejs-ws1closio"; do
    case " $envnames " in *" ${pair%%:*}"*) case ", $calls," in *", ${pair#*:},"*) ;; *) [ "${pair#*:}" != "$name" ] && calls="${calls:+$calls, }${pair#*:}" ;; esac ;; esac
  done
  echo "calls: ${calls:-none}   # guessed from config variable names; confirm with the user"

  echo "env_file: .env   # the AI never reads what's inside (rule A6)"
  echo "# .env files found (names only): $(cd "$path" && ls -a | grep -E '^\.env' | tr '\n' ' ')"

  local keys="" optional=""
  # WS2 services check x-client-id / x-client-secret (D37). WS1 is tested with the login cookie instead (D20).
  case "$name" in
    *ws1*) ;;
    *) if printf '%s' " $envnames " | grep -q " SERVICE_CREDENTIALS " || grep -r -q -E "x-client-id" "$path/src/middlewares" 2>/dev/null; then
         keys="ws2-client-id, ws2-client-secret"
       fi ;;
  esac
  printf '%s' "$envnames" | grep -q -E '(^| )PG_HOST' && optional="db-user, db-password"
  echo "dev_keys: ${keys:-none}"
  echo "dev_keys_optional: ${optional:-none}"
  if [ -n "$optional" ]; then
    echo "dev_db_host:   # optional, ask the user (not secret)"
    echo "dev_db_port:   # optional"
    echo "dev_db_name:   # optional"
    echo "dev_db_schema:   # optional"
  fi
  echo "mr_target_branch:   # ask the user (default: the base branch)"
  echo "mr_labels:   # optional default (comma-separated, or none); confirmed or changed when each MR is created (D51)"
  echo "mr_reviewers:   # optional default (GitLab usernames, or none); confirmed or changed when each MR is created"
  if has_dep vue || has_dep react || has_dep vite; then
    echo "rulesets: none yet   # FE rulesets to be defined later"
  else
    echo "rulesets: backend/story-implementation-workflow.md   # baseline (D26), to be refined later"
  fi
  echo "# local_path for set-path: $path"
}

# ---------------------------------------------------------------- validate

REQUIRED_FIELDS="name gitlab_url gitlab_path type role base_branch install_command health_url test_command local_services dev_keys mr_target_branch"

validate() {
  local repo="$1" file f value bad_lines problems=0 path
  require_registered "$repo"
  file="$(shared_file "$repo")"
  bad_lines="$(grep -n -v -E '^[[:space:]]*(#.*)?$|^[a-z0-9_]+:( .*)?$' "$file")"
  if [ -n "$bad_lines" ]; then
    bad "config/repos/$repo.yaml has lines that aren't 'key: value'" "Fix these lines: $(printf '%s' "$bad_lines" | head -3 | tr '\n' ' ')"
    problems=$((problems + 1))
  fi
  for f in $REQUIRED_FIELDS; do
    value="$(yaml_get "$file" "$f")"
    if [ -z "$value" ]; then
      bad "config/repos/$repo.yaml: '$f' is empty" "Run $CMD $repo and fill it in (or write 'none' where that's allowed)."
      problems=$((problems + 1))
    fi
  done
  [ "$(yaml_get "$file" name)" = "$repo" ] || { bad "'name' in config/repos/$repo.yaml must be $repo" "Change the name line to: name: $repo"; problems=$((problems + 1)); }
  case "$(yaml_get "$file" type)" in FE|BE) ;; *) bad "'type' must be FE or BE" "Edit config/repos/$repo.yaml."; problems=$((problems + 1)) ;; esac
  case "$(yaml_get "$file" language)" in
    node|'') [ -n "$(yaml_get "$file" node_version)" ] ||
               { bad "config/repos/$repo.yaml: 'node_version' is empty" "Write the Node version the repo is built for (its Dockerfile), e.g. node_version: $NODE_MAJOR"; problems=$((problems + 1)); } ;;
  esac
  local nv
  nv="$(yaml_get "$file" node_version)"
  case "$nv" in
    ''|none) ;;
    *) ls -d "${NVM_DIR:-$HOME/.nvm}/versions/node/v$nv."* >/dev/null 2>&1 ||
         look "Node $nv (what $repo is built for) isn't installed in nvm" "Run: nvm install $nv  (everything in $repo runs on Node $nv, rule A13)" ;;
  esac
  case "$(yaml_get "$file" health_url)" in
    none) bad "'health_url' is 'none', but every repo needs one" "Find the repo's health check route (e.g. /api/v1/health-checker) and put it in config/repos/$repo.yaml."; problems=$((problems + 1)) ;;
    ''|/*) ;;
    *) bad "'health_url' must be a path starting with /" "e.g. health_url: /api/v1/health-checker"; problems=$((problems + 1)) ;;
  esac
  grep -q -E 'glpat-|-----BEGIN|://[^/[:space:]]+:[^/@[:space:]]+@' "$file" &&
    { bad "config/repos/$repo.yaml looks like it contains a secret (a token, key or password in a URL)" "Remove it. Secrets only go in the Keychain."; problems=$((problems + 1)); }

  path="$(yaml_get "$(local_file "$repo")" local_path)"
  if [ -n "$path" ] && [ -d "$path/.git" ]; then
    for f in base_branch mr_target_branch; do
      value="$(yaml_get "$file" "$f")"
      [ -z "$value" ] && continue
      git -C "$path" rev-parse --verify --quiet "refs/remotes/origin/$value" >/dev/null ||
        { bad "Branch '$value' ($f) doesn't exist on GitLab for $repo (as last fetched)" "Check the name, or run 'git fetch' in $path while on the VPN, then validate again."; problems=$((problems + 1)); }
    done
  fi
  if [ "$problems" -eq 0 ]; then ok "config/repos/$repo.yaml is valid"; return 0; fi
  return 1
}

# ---------------------------------------------------------------- set-path

set_path() {
  local repo="$1" path="$2" want have
  require_registered "$repo"
  mkdir -p "$LOCAL_REPOS_DIR"
  if [ "$path" = "not-cloned" ]; then
    printf '# Where %s is on this Mac (F5). Private: local/ is never pushed.\nlocal_path: \n' "$repo" > "$(local_file "$repo")"
    look "$repo marked as not cloned yet on this Mac" "Cloning is manual (D53): on the VPN, git clone $(yaml_get "$(shared_file "$repo")" gitlab_url) <your workspace folder>/$repo, then run $CMD $repo path <that folder>."
    return 0
  fi
  case "$path" in "~"*) path="$HOME${path#\~}" ;; esac
  if [ ! -d "$path/.git" ]; then
    bad "No git repo at $path" "Give the full path of the local clone (the folder that contains .git), or say 'not cloned yet'."
    return 1
  fi
  path="$(cd "$path" && pwd -P)"
  case "$path" in *'"'* | *'$'* | *'`'* | *'\'*) bad "The path has characters that aren't supported" "Move the clone to a simpler path."; return 1 ;; esac
  want="$(yaml_get "$(shared_file "$repo")" gitlab_path)"
  have="$(gitlab_path_of "$(git -C "$path" remote get-url origin 2>/dev/null)")"
  if [ "$want" != "$have" ]; then
    bad "$path is a clone of '${have:-no GitLab remote}', not '$want'" "Give the path of the right clone of $repo."
    return 1
  fi
  printf '# Where %s is on this Mac (F5). Private: local/ is never pushed.\nlocal_path: %s\n' "$repo" "$path" > "$(local_file "$repo")"
  ok "Local path saved for $repo: $path"
}

# ---------------------------------------------------------------- keys

ask_key() { # <repo> <key>
  ask_secret_dialog "$(key_service "$1" "$2")" "$KEYCHAIN_PREFIX: $1 $2 (dev)" "$(key_description "$1" "$2")" "$CMD $1 key $2"
}

ask_missing_keys() {
  local repo="$1" file k required optional missing="" stored=0 skipped=0 failed=0 rc
  require_registered "$repo"
  file="$(shared_file "$repo")"
  required="$(list_items "$(yaml_get "$file" dev_keys)")"
  optional="$(list_items "$(yaml_get "$file" dev_keys_optional)")"
  for k in $required $optional; do keychain_has "$(key_service "$repo" "$k")" || missing="$missing $k"; done
  if [ -z "$required$optional" ]; then ok "$repo needs no dev keys"; return 0; fi
  if [ -z "$missing" ]; then ok "All dev keys for $repo are already stored. To replace one, run $CMD $repo key <name>"; return 0; fi
  echo "Dev keys to add for $repo:$missing"
  echo "Optional ones can be skipped with the Skip button: $(echo $optional | tr ' ' ',' | sed 's/,/, /g')"
  echo
  for k in $missing; do
    ask_key "$repo" "$k"
    rc=$?
    case "$rc" in 0) stored=$((stored + 1)) ;; 3) skipped=$((skipped + 1)) ;; *) failed=$((failed + 1)) ;; esac
  done
  echo
  echo "Dev keys for $repo: $stored stored, $skipped skipped, $failed failed."
  [ "$failed" -eq 0 ]
}

# ---------------------------------------------------------------- show / list

show() {
  local repo="$1" file path k
  require_registered "$repo"
  file="$(shared_file "$repo")"
  echo "$repo"
  echo "   $(yaml_get "$file" type) · $(yaml_get "$file" role)"
  echo "   GitLab: $(yaml_get "$file" gitlab_path) · base branch: $(yaml_get "$file" base_branch) · MRs to: $(yaml_get "$file" mr_target_branch)"
  echo "   Tests: $(yaml_get "$file" test_command) · local services: $(yaml_get "$file" local_services) · calls: $(yaml_get "$file" calls)"
  path="$(yaml_get "$(local_file "$repo")" local_path)"
  if [ ! -f "$(local_file "$repo")" ]; then
    bad "Local path not set on this Mac" "Run $CMD $repo (give your clone's path, or say it's not cloned yet)."
  elif [ -z "$path" ]; then
    look "Not cloned on this Mac yet" "Cloning is manual (D53): on the VPN, git clone $(yaml_get "$file" gitlab_url) <your workspace folder>/$repo, then run $CMD $repo path <that folder>."
  elif [ -d "$path/.git" ]; then
    ok "Local clone: $path"
  else
    bad "Local clone not found any more: $path" "Run $CMD $repo again with the new path."
  fi
  for k in $(list_items "$(yaml_get "$file" dev_keys)"); do
    if keychain_has "$(key_service "$repo" "$k")"; then ok "$(key_service "$repo" "$k") stored"
    else look "$(key_service "$repo" "$k") missing (needed to test $repo on dev)" "Run $CMD $repo key $k"; fi
  done
  for k in $(list_items "$(yaml_get "$file" dev_keys_optional)"); do
    if keychain_has "$(key_service "$repo" "$k")"; then ok "$(key_service "$repo" "$k") stored"
    else ok "$(key_service "$repo" "$k") not set (optional)"; fi
  done
}

list() {
  local f repo n=0
  echo "Registered repos (config/repos/)"
  for f in "$REPOS_DIR"/*.yaml; do
    [ -f "$f" ] || continue
    repo="$(basename "$f" .yaml)"
    n=$((n + 1))
    echo
    show "$repo"
  done
  [ "$n" -eq 0 ] && look "No repos registered yet" "Run $CMD with the path of a local clone to register one."
  echo
  echo "Branch names for every repo (D50, rule A12): $JIRA_PROJECT_KEY-<number>/<short-description>, at most $BRANCH_DESC_MAX_WORDS words."
}

# ---------------------------------------------------------------- main

case "${1:-}" in
  check-folder)
    if [ "$(pwd -P)" = "$AGENT_ROOT" ]; then
      ok "Started in the closio-agent folder"
    else
      bad "Not started in the closio-agent folder (current folder: $(pwd))" \
        "Quit, open a terminal in $AGENT_ROOT, run 'nvm use v$NODE_MAJOR', then start Claude Code or Codex again." \
        "Always start Claude Code or Codex in the closio-agent folder (D42)."
      exit 1
    fi ;;
  list) list ;;
  detect) [ $# -eq 2 ] || { echo "Usage: bash scripts/configure-repo.sh detect <local-path>"; exit 1; }; detect "$2" ;;
  validate) [ $# -eq 2 ] || { echo "Usage: bash scripts/configure-repo.sh validate <repo>"; exit 1; }; validate "$2" ;;
  set-path) [ $# -eq 3 ] || { echo "Usage: bash scripts/configure-repo.sh set-path <repo> <path|not-cloned>"; exit 1; }; set_path "$2" "$3" ;;
  keys) [ $# -eq 2 ] || { echo "Usage: bash scripts/configure-repo.sh keys <repo>"; exit 1; }; ask_missing_keys "$2" ;;
  key) [ $# -eq 3 ] || { echo "Usage: bash scripts/configure-repo.sh key <repo> <name>"; exit 1; }
    require_registered "$2"
    printf '%s' "$3" | grep -q -E '^[a-z0-9-]+$' || { bad "'$3' isn't a valid key name" "Use lowercase letters, numbers and '-'."; exit 1; }
    ask_key "$2" "$3" ;;
  show) [ $# -eq 2 ] || { echo "Usage: bash scripts/configure-repo.sh show <repo>"; exit 1; }; show "$2" ;;
  *) echo "Usage: bash scripts/configure-repo.sh check-folder | list | detect <path> | validate <repo> | set-path <repo> <path|not-cloned> | keys <repo> | key <repo> <name> | show <repo>"; exit 1 ;;
esac
