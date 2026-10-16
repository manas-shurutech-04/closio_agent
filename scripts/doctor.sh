#!/usr/bin/env bash
# Checks used by the flow-doctor command (F1 + F2).
# Run it from the closio-agent folder:  bash scripts/doctor.sh
# Prints one line per check:
#   ✅ fine   ⚠️ worth a look (doesn't fail)   ❌ must fix (with the steps to fix it, rule A11)
# Only reads: never changes anything, never asks for a password, never prints a secret.
# Exit code 1 if anything must be fixed.
# Checks for pieces not built yet are added by those pieces.

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
USER_SETTINGS_FILE="${USER_SETTINGS_FILE:-$AGENT_ROOT/local/user-settings.sh}"
JIRA_ACCOUNT_ID=""; GITLAB_USERNAME=""; WORKSPACE_DIR=""; AI_TOOLS=""; VPN_USERNAME=""; LOCAL_REDIS_FROM=""; LOCAL_RABBITMQ_FROM=""
[ -f "$USER_SETTINGS_FILE" ] && . "$USER_SETTINGS_FILE"
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
NODE_DIR_PREFIX="$NVM_DIR/versions/node/v$NODE_MAJOR."

to_fix=0
to_look=0

section() { echo; echo "$1"; }
pass() { echo "✅ $1"; }
warn() {
  echo "⚠️ $1"
  [ -n "${2:-}" ] && echo "   Tip: $2"
  to_look=$((to_look + 1))
}
fail() {
  echo "❌ $1"
  echo "   Fix: $2"
  [ -n "${3:-}" ] && echo "        $3"
  to_fix=$((to_fix + 1))
}

# Is this path inside the Node 22 folder of nvm?
in_node22() { case "$1" in "$NODE_DIR_PREFIX"*) return 0 ;; *) return 1 ;; esac; }

echo "flow-doctor — checking your setup"

# ---------------------------------------------------------------- Project
section "Project"

# The session was started in the closio-agent folder (D42, rule A10)
if [ "$(pwd -P)" = "$AGENT_ROOT" ]; then
  pass "Started in the closio-agent folder"
else
  fail "Not started in the closio-agent folder (current folder: $(pwd))" \
    "Quit, open a terminal in $AGENT_ROOT, run 'nvm use v$NODE_MAJOR', then start Claude Code or Codex again."
fi

# Node 22 is active (D41, rule A9)
if ! command -v node >/dev/null 2>&1; then
  fail "Node.js not found" \
    "Install nvm and Node $NODE_MAJOR (setup guide, section 1), then run 'nvm use v$NODE_MAJOR' before starting Claude Code or Codex."
else
  node_version="$(node -v)"
  case "$node_version" in
    "v$NODE_MAJOR".*) pass "Node $node_version is active" ;;
    *) fail "Node $node_version is active, but this project needs Node $NODE_MAJOR" \
         "Quit, run 'nvm use v$NODE_MAJOR', then start Claude Code or Codex again." \
         "In Codex, also run 'codex app-server daemon restart' after 'nvm use v$NODE_MAJOR' (setup guide, section 1)." ;;
  esac
fi

# Every flow command has its Claude Code link (D8)
missing=""
for dir in "$AGENT_ROOT"/.agents/skills/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  link="$AGENT_ROOT/.claude/skills/$name"
  if [ ! -L "$link" ] || [ "$(readlink "$link")" != "../../.agents/skills/$name" ] || [ ! -f "$link/SKILL.md" ]; then
    missing="$missing $name"
  fi
done
if [ -z "$missing" ]; then
  pass "Every flow command has its Claude Code link"
else
  fail "Claude Code link missing or wrong for:$missing" \
    "Run 'bash scripts/link-claude-skills.sh' in the closio-agent folder."
fi

# Rules file AGENTS.md is read by both tools (D45): it needs to exist, and a CLAUDE.md
# in this folder or above would stop Claude Code reading it, unless it imports it.
bad_claude_files=""
check_claude_file() {
  [ -f "$1" ] || return 0
  grep -q "@AGENTS.md" "$1" 2>/dev/null || bad_claude_files="$bad_claude_files '$1'"
}
check_claude_file "$AGENT_ROOT/CLAUDE.md"
check_claude_file "$AGENT_ROOT/CLAUDE.local.md"
check_claude_file "$AGENT_ROOT/.claude/CLAUDE.md"
parent="$(dirname "$AGENT_ROOT")"
while [ "$parent" != "/" ]; do
  check_claude_file "$parent/CLAUDE.md"
  check_claude_file "$parent/CLAUDE.local.md"
  parent="$(dirname "$parent")"
done
if [ ! -f "$AGENT_ROOT/AGENTS.md" ]; then
  fail "The rules file AGENTS.md is missing" \
    "Get it back from git: 'git checkout -- AGENTS.md' in the closio-agent folder."
elif [ -n "$bad_claude_files" ]; then
  fail "A CLAUDE.md file stops Claude Code from reading AGENTS.md:$bad_claude_files" \
    "Remove that file, or add the line '@AGENTS.md' to it so it includes the rules (D45)."
else
  pass "Rules file AGENTS.md is in place"
fi

# ---------------------------------------------------------------- Tools
section "Tools"

# git, with your name and email for commits
if ! command -v git >/dev/null 2>&1; then
  fail "git is not installed" "Run 'xcode-select --install' in a terminal."
else
  git_version="$(git --version | awk '{print $3}')"
  if [ -n "$(git config user.name)" ] && [ -n "$(git config user.email)" ]; then
    pass "git $git_version (name and email set)"
  else
    fail "git $git_version is installed, but your name or email isn't set" \
      "Run: git config --global user.name \"Your Name\"" \
      "and: git config --global user.email \"you@company.com\""
  fi
fi

# Claude Code and Codex must be installed inside Node 22 (D41). Any other copy is a problem.
check_ai_tool() { # $1 = command, $2 = name, $3 = npm package, $4 = required|optional, $5 = Homebrew cask
  local cmd="$1" label="$2" pkg="$3" need="$4" cask="$5"
  local all others version
  all="$(which -a "$cmd" 2>/dev/null | awk '!seen[$0]++')"
  if [ -z "$all" ]; then
    if [ "$need" = "required" ]; then
      fail "$label is not installed" \
        "Run 'nvm use v$NODE_MAJOR', then 'npm install -g $pkg' (setup guide, section 1)."
    else
      warn "$label is not installed (optional)" \
        "If you want it: 'nvm use v$NODE_MAJOR', then 'npm install -g $pkg' (setup guide, section 1)."
    fi
    return 1
  fi
  others=""
  while IFS= read -r p; do
    [ -n "$p" ] && ! in_node22 "$p" && others="$others $p"
  done <<EOF_PATHS
$all
EOF_PATHS
  if [ -n "$others" ]; then
    fail "$label has a copy outside Node $NODE_MAJOR:$others" \
      "Remove it (if it came from Homebrew: 'brew uninstall --cask $cask'), then 'nvm use v$NODE_MAJOR' and 'npm install -g $pkg'."
    return 1
  fi
  version="$("$cmd" --version 2>/dev/null | head -1 | grep -o -E '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  pass "$label ${version:-(version unknown)}, installed inside Node $NODE_MAJOR"
  return 0
}

# Which tools you use comes from your personal settings (flow-configure-user). Until that's set:
# Claude Code is required and Codex optional.
uses_tool() { case " $AI_TOOLS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
claude_need="required"; codex_need="optional"
if [ -n "$AI_TOOLS" ]; then
  uses_tool claude-code || claude_need="unused"
  uses_tool codex && codex_need="required" || codex_need="unused"
fi

if [ "$claude_need" = "unused" ] && ! command -v claude >/dev/null 2>&1; then
  pass "Claude Code not installed (you don't use it)"
else
  check_ai_tool claude "Claude Code" "@anthropic-ai/claude-code" "${claude_need/unused/optional}" claude-code
fi

codex_ok=""
if [ "$codex_need" = "unused" ] && ! command -v codex >/dev/null 2>&1; then
  pass "Codex not installed (you don't use it)"
elif check_ai_tool codex "Codex" "@openai/codex" "${codex_need/unused/optional}" codex; then
  codex_ok="yes"
fi

if [ -n "$codex_ok" ]; then
  # Codex runs its commands through a background service that keeps the Node it started with.
  service_pids="$(pgrep -f 'codex app-server --listen' 2>/dev/null)"
  if [ -z "$service_pids" ] && [ -n "${CODEX_SANDBOX:-}${CODEX_SANDBOX_NETWORK_DISABLED:-}" ]; then
    # Inside Codex's sandbox other programs can't be seen, so "not found" means "can't tell".
    warn "Couldn't check which Node Codex's background service uses from inside Codex's sandbox" \
      "Run 'bash scripts/doctor.sh' in a normal terminal to check it."
  elif [ -z "$service_pids" ]; then
    pass "Codex background service isn't running (it starts with Codex)"
  else
    wrong=""
    unknown=""
    for pid in $service_pids; do
      first_node="$(ps eww -p "$pid" 2>/dev/null | tr ' ' '\n' | grep '^PATH=' | sed 's/^PATH=//' | tr ':' '\n' | grep -m1 -E '/versions/node/v[0-9.]+/bin$')"
      if [ -z "$first_node" ]; then
        unknown="yes"
      elif ! in_node22 "$first_node"; then
        wrong="$(echo "$first_node" | grep -o -E 'v[0-9.]+')"
      fi
    done
    if [ -n "$wrong" ]; then
      fail "Codex background service runs on Node $wrong, not Node $NODE_MAJOR" \
        "Close Codex. In a terminal run 'nvm use v$NODE_MAJOR', then 'codex app-server daemon restart', then start Codex again (setup guide, section 1)."
    elif [ -n "$unknown" ]; then
      warn "Couldn't check which Node Codex's background service uses from here" \
        "Run 'bash scripts/doctor.sh' in a normal terminal to check it."
    else
      pass "Codex background service runs on Node $NODE_MAJOR"
    fi
  fi
fi

# openfortivpn (VPN client, D14)
if command -v openfortivpn >/dev/null 2>&1; then
  pass "openfortivpn $(openfortivpn --version 2>&1 | head -1)"
else
  fail "openfortivpn is not installed" "Run 'brew install openfortivpn' (setup guide, section 2.1)."
fi

# Docker: only needed when you use Docker copies of Redis or RabbitMQ (D21, D54). flow-setup-repo can use Homebrew ones.
uses_docker=""
case " $LOCAL_REDIS_FROM $LOCAL_RABBITMQ_FROM " in *" docker "*) uses_docker="yes" ;; esac
if ! command -v docker >/dev/null 2>&1; then
  if [ -n "$uses_docker" ]; then
    fail "Docker is not installed, but you chose Docker for Redis or RabbitMQ" \
      "Install Docker Desktop from docker.com, or choose Homebrew instead: /flow-setup-repo <repo> services"
  else
    pass "Docker isn't installed (only needed if you choose Docker for Redis or RabbitMQ)"
  fi
elif docker info >/dev/null 2>&1; then
  pass "Docker is installed and running"
elif [ -n "$uses_docker" ]; then
  warn "Docker is installed but not running, and you use it for Redis or RabbitMQ" "Open Docker Desktop before running backend tests."
else
  pass "Docker is installed (not running; you don't use it for Redis or RabbitMQ)"
fi

# ---------------------------------------------------------------- VPN and GitLab
section "VPN and GitLab"

openfortivpn_up=""
ifconfig "$VPN_INTERFACE" >/dev/null 2>&1 && openfortivpn_up="yes"

if [ "${CODEX_SANDBOX_NETWORK_DISABLED:-}" = "1" ]; then
  warn "Can't check the VPN and GitLab from inside Codex's sandbox (network is blocked here)" \
    "Approve running flow-doctor with network access, or run 'bash scripts/doctor.sh' in a normal terminal."
else
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "https://$GITLAB_HOST/users/sign_in" 2>/dev/null)"
  if [ "$code" = "200" ]; then
    if [ -n "$openfortivpn_up" ]; then
      pass "VPN is on (openfortivpn) and GitLab is reachable"
    else
      pass "VPN is on (another VPN client, e.g. the FortiClient app) and GitLab is reachable"
    fi
    # Does the GitLab token work? It is read from the Keychain and never printed.
    token="$(security find-generic-password -a "$USER" -s "$KEYCHAIN_PREFIX.gitlab-token" -w 2>/dev/null)"
    if [ -z "$token" ]; then
      warn "Can't check the GitLab token: it isn't in the Keychain yet" "See the Keychain section below."
    else
      response="$(printf 'PRIVATE-TOKEN: %s\n' "$token" | curl -s --max-time 8 -H @- -w '\n%{http_code}' "https://$GITLAB_HOST/api/v4/user" 2>/dev/null)"
      token=""
      status="$(printf '%s' "$response" | tail -1)"
      username="$(printf '%s' "$response" | grep -o '"username":"[^"]*"' | head -1 | cut -d'"' -f4)"
      if [ "$status" = "200" ]; then
        pass "GitLab token works (signed in as ${username:-unknown})"
      else
        fail "GitLab rejected your token (HTTP $status): it may be expired or revoked" \
          "Make a new token (setup guide, section 4.2), then store it again with the command in section 5.1."
      fi
    fi
  elif [ -n "$openfortivpn_up" ]; then
    if [ ! -f "$VPN_RESOLVER_FILE" ]; then
      fail "VPN is on (openfortivpn), but the VPN DNS file is missing, so GitLab's name doesn't resolve" \
        "Run /flow-vpn connect (Codex: \$flow-vpn connect). It adds the file."
    else
      fail "VPN is on (openfortivpn), but GitLab doesn't answer (HTTP ${code:-none})" \
        "Run /flow-vpn disconnect, then /flow-vpn connect. If it still fails, see the setup guide, section 2.6."
    fi
  else
    warn "VPN is off. That's fine until you need GitLab" \
      "To connect, run /flow-vpn connect (Codex: \$flow-vpn connect)."
    if [ -f "$VPN_RESOLVER_FILE" ]; then
      fail "A leftover VPN DNS file is still there; it stops the next VPN connection" \
        "Run /flow-vpn connect (it removes the file first), or: sudo rm -f $VPN_RESOLVER_FILE"
    else
      pass "No leftover VPN DNS file"
    fi
  fi
fi

if [ -f "$VPN_OLD_RESOLVER_FILE" ]; then
  warn "An old GitLab-only DNS file is still there (no longer needed)" \
    "It's removed the next time you run /flow-vpn connect, or now with: sudo rm -f $VPN_OLD_RESOLVER_FILE"
fi

# The pinned VPN certificate (D14) stops working when the gateway's certificate is renewed.
expires_epoch="$(date -j -f %Y-%m-%d "$VPN_CERT_EXPIRES" +%s 2>/dev/null)"
if [ -n "$expires_epoch" ]; then
  days_left=$(( (expires_epoch - $(date +%s)) / 86400 ))
  if [ "$days_left" -lt 0 ]; then
    fail "The VPN certificate pin expired on $VPN_CERT_EXPIRES, so the VPN won't connect" \
      "Ask the IT/infra team to confirm the new certificate, then put its fingerprint in config/project-settings.sh (VPN_CERT_SHA256 and VPN_CERT_EXPIRES)."
  elif [ "$days_left" -lt 30 ]; then
    warn "The VPN certificate pin expires in $days_left days ($VPN_CERT_EXPIRES)" \
      "Ask the IT/infra team for the new certificate's fingerprint, then update config/project-settings.sh."
  else
    pass "VPN certificate pin is valid until $VPN_CERT_EXPIRES ($days_left days left)"
  fi
fi

# ---------------------------------------------------------------- Personal settings (F4)
section "Personal settings (local/user-settings.sh)"

if [ ! -f "$USER_SETTINGS_FILE" ]; then
  fail "Your personal settings aren't set up yet" "Run /flow-configure-user (Codex: \$flow-configure-user)."
else
  check_setting() { # $1 value, $2 label, $3 item name
    if [ -n "$1" ]; then pass "$2: $1"; else fail "$2 is not set" "Run /flow-configure-user $3"; fi
  }
  check_setting "$JIRA_ACCOUNT_ID" "Jira account ID" jira-account-id
  check_setting "$GITLAB_USERNAME" "GitLab username" gitlab-username
  if [ -z "$WORKSPACE_DIR" ]; then
    fail "Workspace folder is not set" "Run /flow-configure-user workspace-dir"
  elif [ ! -d "$WORKSPACE_DIR" ]; then
    fail "Workspace folder doesn't exist: $WORKSPACE_DIR" "Create it again, or choose another with /flow-configure-user workspace-dir"
  else
    pass "Workspace folder: $WORKSPACE_DIR"
  fi
  check_setting "$AI_TOOLS" "AI tools" ai-tools
fi

# ---------------------------------------------------------------- Repos (F5)
section "Repos (config/repos/)"

yaml_get() { # <file> <key>: value of a flat "key: value" line
  [ -f "$1" ] || return 0
  grep -m1 -E "^$2:" "$1" | sed -E "s/^$2:[[:space:]]*//; s/[[:space:]]+#.*$//; s/[[:space:]]+$//"
}
repo_count=0
for repo_file in "$AGENT_ROOT"/config/repos/*.yaml; do
  [ -f "$repo_file" ] || continue
  repo_count=$((repo_count + 1))
  repo="$(basename "$repo_file" .yaml)"
  local_repo_file="$AGENT_ROOT/local/repos/$repo.yaml"
  repo_path="$(yaml_get "$local_repo_file" local_path)"
  if [ ! -f "$local_repo_file" ]; then
    warn "$repo isn't set up on this Mac" "Run /flow-configure-repo $repo (only if you work on it)."
    continue
  elif [ -z "$repo_path" ]; then
    warn "$repo isn't cloned on this Mac yet" "Cloning is manual (D53): on the VPN, git clone $(yaml_get "$repo_file" gitlab_url) <your workspace folder>/$repo, then run /flow-configure-repo $repo path <that folder>."
  elif [ ! -d "$repo_path/.git" ]; then
    fail "$repo: clone not found at $repo_path" "Run /flow-configure-repo $repo and give the new path."
  else
    want="$(yaml_get "$repo_file" gitlab_path)"
    have="$(git -C "$repo_path" remote get-url origin 2>/dev/null | sed -E 's#://[^/@]*@#://#; s#^[a-z]+://[^/]+/##; s#^[^@]+@[^:]+:##; s#\.git$##')"
    if [ "$want" = "$have" ]; then
      pass "$repo: $repo_path"
    else
      fail "$repo: $repo_path is a clone of '${have:-no GitLab remote}', not '$want'" "Run /flow-configure-repo $repo and give the right clone."
    fi
  fi
  # Each repo runs on its own Node version (rule A13, D52); it must be installed in nvm.
  repo_node="$(yaml_get "$repo_file" node_version)"
  case "$repo_node" in
    ''|none) ;;
    *) ls -d "$NVM_DIR/versions/node/v$repo_node."* >/dev/null 2>&1 ||
         warn "Node $repo_node (what $repo is built for) isn't installed in nvm" "Run: nvm install $repo_node" ;;
  esac
  for k in $(yaml_get "$repo_file" dev_keys | tr ',' ' '); do
    [ "$k" = "none" ] && continue
    security find-generic-password -a "$USER" -s "$KEYCHAIN_PREFIX.$repo.$k.dev" >/dev/null 2>&1 ||
      warn "$KEYCHAIN_PREFIX.$repo.$k.dev is missing (needed to test $repo on dev)" "Run /flow-configure-repo $repo (it asks for the key in a hidden macOS box)."
  done
done
[ "$repo_count" -eq 0 ] && warn "No repos registered yet" "Run /flow-configure-repo with the full path of a local clone."

# ---------------------------------------------------------------- Repo setup (F6)
section "Repo setup on this Mac (flow-setup-repo)"

claude_settings="$AGENT_ROOT/.claude/settings.local.json"
not_set_up=""; need_redis=""; need_rabbitmq=""; set_up_count=0
for repo_file in "$AGENT_ROOT"/config/repos/*.yaml; do
  [ -f "$repo_file" ] || continue
  repo="$(basename "$repo_file" .yaml)"
  local_repo_file="$AGENT_ROOT/local/repos/$repo.yaml"
  repo_path="$(yaml_get "$local_repo_file" local_path)"
  { [ -n "$repo_path" ] && [ -d "$repo_path/.git" ]; } || continue
  setup_on="$(yaml_get "$local_repo_file" setup_on)"
  if [ -z "$setup_on" ]; then not_set_up="$not_set_up $repo"; continue; fi
  set_up_count=$((set_up_count + 1))
  repo_lang="$(yaml_get "$repo_file" language)"
  repo_install="$(yaml_get "$repo_file" install_command)"
  if [ "${repo_lang:-node}" = "node" ] && [ -n "$repo_install" ] && [ "$repo_install" != "none" ] && [ ! -d "$repo_path/node_modules" ]; then
    warn "$repo: its packages aren't installed any more" "Run /flow-setup-repo $repo"
  else
    pass "$repo: set up on $setup_on (tests: $(yaml_get "$local_repo_file" setup_tests))"
  fi
  if [ "$claude_need" != "unused" ] && ! jq -e --arg p "$repo_path" '(.permissions.additionalDirectories // []) | index($p)' "$claude_settings" >/dev/null 2>&1; then
    warn "$repo: Claude Code can't use its folder yet" "Run /flow-setup-repo $repo (it adds the folder to your .claude/settings.local.json)."
  fi
  repo_services="$(yaml_get "$repo_file" local_services)"
  case ", $repo_services," in *", redis,"* | *", bullmq,"*) need_redis="$need_redis $repo" ;; esac
  case ", $repo_services," in *", rabbitmq,"*) need_rabbitmq="$need_rabbitmq $repo" ;; esac
done
[ -n "$not_set_up" ] && warn "Cloned but not set up yet:$not_set_up" "Run /flow-setup-repo <repo>, or /flow-setup-repo all."
[ "$set_up_count" -eq 0 ] && [ -z "$not_set_up" ] && pass "No cloned repos to set up yet"

if [ -n "$need_redis$need_rabbitmq" ] && [ "${CODEX_SANDBOX_NETWORK_DISABLED:-}" = "1" ]; then
  warn "Can't check the local Redis and RabbitMQ from inside Codex's sandbox" "Run 'bash scripts/doctor.sh' in a normal terminal."
else
  if [ -n "$need_redis" ]; then
    if [ "$(printf 'PING\r\n' | nc -G 2 -w 2 127.0.0.1 "$LOCAL_REDIS_PORT" 2>/dev/null | tr -d '\r' | head -1)" = "+PONG" ]; then
      pass "Local Redis answers on port $LOCAL_REDIS_PORT${LOCAL_REDIS_FROM:+ ($LOCAL_REDIS_FROM)}"
    else
      warn "Local Redis doesn't answer on port $LOCAL_REDIS_PORT (needed by:$need_redis)" "Run /flow-setup-repo$(echo "$need_redis" | awk '{print " " $1}') (it finds or starts it)."
    fi
  fi
  if [ -n "$need_rabbitmq" ]; then
    if nc -z -G 2 127.0.0.1 "$LOCAL_RABBITMQ_PORT" >/dev/null 2>&1; then
      pass "Local RabbitMQ answers on port $LOCAL_RABBITMQ_PORT${LOCAL_RABBITMQ_FROM:+ ($LOCAL_RABBITMQ_FROM)}"
    else
      warn "Local RabbitMQ doesn't answer on port $LOCAL_RABBITMQ_PORT (needed by:$need_rabbitmq)" "Run /flow-setup-repo$(echo "$need_rabbitmq" | awk '{print " " $1}') (it finds or starts it)."
    fi
  fi
fi

# ---------------------------------------------------------------- Keychain
section "Keychain (names only, values are never read)"

for item in $KEYCHAIN_PERSONAL_ITEMS; do
  service="$KEYCHAIN_PREFIX.$item"
  security find-generic-password -a "$USER" -s "$service" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "$service"
  elif [ "$rc" -eq 44 ]; then
    fail "$service is missing" \
      "Run /flow-configure-user $item (Codex: \$flow-configure-user $item). It asks for the value in a hidden macOS box." \
      "Backup, in your own terminal (not the AI chat): security add-generic-password -U -a \"\$USER\" -s \"$service\" -w"
  else
    warn "Couldn't read the Keychain from here to check $service" \
      "Run 'bash scripts/doctor.sh' in a normal terminal."
  fi
done

# ---------------------------------------------------------------- Result
echo
echo "Result: $to_fix to fix, $to_look to look at."
[ "$to_fix" -eq 0 ] || exit 1
