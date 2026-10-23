#!/usr/bin/env bash
# Checks used by the flow-doctor command (F1 + F2).
# Run it from the closio-agent folder:  bash scripts/doctor.sh
# Prints one line per check, grouped in sections:
#   ✅ fine   ⚠️ worth a look (doesn't fail)   ❌ must fix (with the steps to fix it, rule A11)
# Output format (DOCTOR_FORMAT overrides), the same as help.sh: in a terminal, colors and lines wrapped to its width
# ("terminal"; no colors with NO_COLOR set: "plain"); otherwise markdown ("markdown"), which is what the AI shows in its
# reply when /flow-doctor runs, so Claude Code and Codex draw the headings, bold problems and `commands`.
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

# ---------------------------------------------------------------- output format
# In the messages below, commands, files and names are written between backticks: `code` in markdown, yellow in a
# terminal, plain text without colors.
if [ -n "${DOCTOR_FORMAT:-}" ]; then FORMAT="$DOCTOR_FORMAT"
elif [ -t 1 ]; then
  if [ -n "${NO_COLOR:-}" ]; then FORMAT="plain"; else FORMAT="terminal"; fi
else FORMAT="markdown"; fi
case "$FORMAT" in markdown|terminal|plain) ;; *) FORMAT="markdown" ;; esac
if [ "$FORMAT" = "terminal" ]; then
  C_HEAD=$'\033[1;36m'; C_WARN=$'\033[1;33m'; C_BAD=$'\033[1;31m'; C_GOOD=$'\033[1;32m'; C_CMD=$'\033[33m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
  IND="  "   # a terminal indents the checks under their section
else
  C_HEAD=""; C_WARN=""; C_BAD=""; C_GOOD=""; C_CMD=""; C_DIM=""; C_OFF=""
  IND=""
fi
WIDTH="${COLUMNS:-}"
[ -z "$WIDTH" ] && [ -t 1 ] && WIDTH="$(tput cols 2>/dev/null)"
case "$WIDTH" in ''|*[!0-9]*) WIDTH=80 ;; esac
[ "$WIDTH" -gt 100 ] && WIDTH=100
[ "$WIDTH" -lt 40 ] && WIDTH=40

# Terminal and plain: <text> wrapped to the width, its first line after <first>, the others indented by <indent>
# columns; the text in <color>, every `command` in yellow (plain: no colors, the backticks dropped).
emit() { # <first> <indent> <color> <text>
  local pad; pad="$(printf '%*s' "$2" '')"
  printf '%s\n' "$4" | fold -s -w "$(($WIDTH - $2))" | sed -e 's/[[:space:]]*$//' |
    awk -v first="$1" -v pad="$pad" -v col="$3" -v cmd="$C_CMD" -v off="$C_OFF" '
      { s = $0; out = (incode ? cmd : col)
        while ((p = index(s, "`")) > 0) { out = out substr(s, 1, p - 1) off; incode = !incode; out = out (incode ? cmd : col); s = substr(s, p + 1) }
        print (NR == 1 ? first : pad) out s off }'
}
# Markdown: a <placeholder> outside `code` is put in backticks too (else it would vanish as an HTML tag).
md() { # <text>
  printf '%s\n' "$1" | awk '
    function fix(t) { gsub(/<[^<>]+>/, "`&`", t); return t }
    { s = $0; out = ""; incode = 0
      while ((p = index(s, "`")) > 0) { seg = substr(s, 1, p - 1); out = out (incode ? seg : fix(seg)) "`"; incode = !incode; s = substr(s, p + 1) }
      print out (incode ? s : fix(s)) }'
}

title() {
  if [ "$FORMAT" = "markdown" ]; then echo "## flow-doctor: checking your setup"
  else printf '%sflow-doctor — checking your setup%s\n' "$C_HEAD" "$C_OFF"; fi
}
section() { # <name> [<note>]
  echo
  case "$FORMAT" in
    markdown) echo "### $1${2:+ · $(md "$2")}"; echo ;;
    terminal) printf '%s%s%s%s\n' "$C_HEAD" "$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')" "$C_OFF" "${2:+  $C_DIM$(printf '%s' "$2" | tr -d '`')$C_OFF}" ;;
    plain) echo "$1${2:+ ($(printf '%s' "$2" | tr -d '`'))}" ;;
  esac
}
pass() {
  if [ "$FORMAT" = "markdown" ]; then echo "- ✅ $(md "$1")"
  else emit "${IND}✅ " $((${#IND} + 3)) "" "$1"; fi
}
warn() {
  if [ "$FORMAT" = "markdown" ]; then
    echo "- ⚠️ **$(md "$1")**"
    [ -n "${2:-}" ] && echo "  - **Tip:** $(md "$2")"
  else
    emit "${IND}⚠️ " $((${#IND} + 3)) "$C_WARN" "$1"
    [ -n "${2:-}" ] && emit "${IND}   ${C_WARN}Tip:${C_OFF} " $((${#IND} + 8)) "" "$2"
  fi
  to_look=$((to_look + 1))
}
fail() {
  if [ "$FORMAT" = "markdown" ]; then
    echo "- ❌ **$(md "$1")**"
    [ -n "${2:-}" ] && echo "  - **Fix:** $(md "$2")"
    [ -n "${3:-}" ] && echo "  - $(md "$3")"
  else
    emit "${IND}❌ " $((${#IND} + 3)) "$C_BAD" "$1"
    [ -n "${2:-}" ] && emit "${IND}   ${C_BAD}Fix:${C_OFF} " $((${#IND} + 8)) "" "$2"
    [ -n "${3:-}" ] && emit "${IND}        " $((${#IND} + 8)) "" "$3"
  fi
  to_fix=$((to_fix + 1))
}
result() {
  local c="$C_GOOD"
  [ "$to_fix" -gt 0 ] && c="$C_BAD"
  echo
  if [ "$FORMAT" = "markdown" ]; then echo "**Result: $to_fix to fix, $to_look to look at.**"
  else printf '%sResult: %s to fix, %s to look at.%s\n' "$c" "$to_fix" "$to_look" "$C_OFF"; fi
}
# Another script's ✅ / ⚠️ / ❌ lines (with their "   Fix:" / "   Tip:" lines) in this script's look, counted here.
relay() { # <output>
  local kind="" msg="" more="" line
  while IFS= read -r line; do
    case "$line" in
      "✅ "* | "⚠️ "* | "❌ "*) relay_one; kind="${line%% *}"; msg="${line#* }"; more="" ;;
      "   Fix: "*) more="${line#   Fix: }" ;;
      "   Tip: "*) more="${line#   Tip: }" ;;
      *[![:space:]]*) more="${more:+$more }$(printf '%s' "$line" | sed 's/^[[:space:]]*//')" ;;
    esac
  done <<EOF_RELAY
$1
EOF_RELAY
  relay_one
}
relay_one() { # uses kind, msg and more of relay
  case "$kind" in
    "✅") pass "$msg" ;;
    "⚠️") warn "$msg" "$more" ;;
    "❌") fail "$msg" "$more" ;;
  esac
  kind=""
}

# Is this path inside the Node 22 folder of nvm?
in_node22() { case "$1" in "$NODE_DIR_PREFIX"*) return 0 ;; *) return 1 ;; esac; }

title

# ---------------------------------------------------------------- Project
section "Project"

# The session was started in the closio-agent folder (D42, rule A10)
if [ "$(pwd -P)" = "$AGENT_ROOT" ]; then
  pass "Started in the closio-agent folder"
else
  fail "Not started in the closio-agent folder (current folder: $(pwd))" \
    "Quit, open a terminal in $AGENT_ROOT, run \`nvm use v$NODE_MAJOR\`, then start Claude Code or Codex again."
fi

# Node 22 is active (D41, rule A9)
if ! command -v node >/dev/null 2>&1; then
  fail "Node.js not found" \
    "Install nvm and Node $NODE_MAJOR (setup guide, section 1), then run \`nvm use v$NODE_MAJOR\` before starting Claude Code or Codex."
else
  node_version="$(node -v)"
  case "$node_version" in
    "v$NODE_MAJOR".*) pass "Node $node_version is active" ;;
    *) fail "Node $node_version is active, but this project needs Node $NODE_MAJOR" \
         "Quit, run \`nvm use v$NODE_MAJOR\`, then start Claude Code or Codex again." \
         "In Codex, also run \`codex app-server daemon restart\` after \`nvm use v$NODE_MAJOR\` (setup guide, section 1)." ;;
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
    "Run \`bash scripts/link-claude-skills.sh\` in the closio-agent folder."
fi

# Claude Code suggests the flow commands' options while you type: the mod in .claude/skills/flow-autocomplete/ (D73),
# loaded by Claude Code by itself in every session started in this folder.
autocomplete_dir="$AGENT_ROOT/.claude/skills/flow-autocomplete"
if [ -f "$autocomplete_dir/.claude-plugin/plugin.json" ] && [ -f "$autocomplete_dir/hooks/hooks.json" ] && [ -f "$autocomplete_dir/hooks/register.ts" ]; then
  pass "Claude Code suggests the commands' options while you type (\`flow-autocomplete\`)"
else
  fail "The suggestions while you type are missing (\`.claude/skills/flow-autocomplete/\`)" \
    "Get them back from git: \`git checkout -- .claude/skills/flow-autocomplete\` in the closio-agent folder, then start Claude Code again."
fi

# Rules file AGENTS.md is read by both tools (D45): it needs to exist, and a CLAUDE.md
# in this folder or above would stop Claude Code reading it, unless it imports it.
bad_claude_files=""
check_claude_file() {
  [ -f "$1" ] || return 0
  grep -q "@AGENTS.md" "$1" 2>/dev/null || bad_claude_files="$bad_claude_files \`$1\`"
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
    "Get it back from git: \`git checkout -- AGENTS.md\` in the closio-agent folder."
elif [ -n "$bad_claude_files" ]; then
  fail "A CLAUDE.md file stops Claude Code from reading AGENTS.md:$bad_claude_files" \
    "Remove that file, or add the line \`@AGENTS.md\` to it so it includes the rules."
else
  pass "Rules file AGENTS.md is in place"
fi

# ---------------------------------------------------------------- Tools
section "Tools"

# git, with your name and email for commits
if ! command -v git >/dev/null 2>&1; then
  fail "git is not installed" "Run \`xcode-select --install\` in a terminal."
else
  git_version="$(git --version | awk '{print $3}')"
  if [ -n "$(git config user.name)" ] && [ -n "$(git config user.email)" ]; then
    pass "git $git_version (name and email set)"
  else
    fail "git $git_version is installed, but your name or email isn't set" \
      "Run: \`git config --global user.name \"Your Name\"\`" \
      "and: \`git config --global user.email \"you@company.com\"\`"
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
        "Run \`nvm use v$NODE_MAJOR\`, then \`npm install -g $pkg\` (setup guide, section 1)."
    else
      warn "$label is not installed (optional)" \
        "If you want it: \`nvm use v$NODE_MAJOR\`, then \`npm install -g $pkg\` (setup guide, section 1)."
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
      "Remove it (if it came from Homebrew: \`brew uninstall --cask $cask\`), then \`nvm use v$NODE_MAJOR\` and \`npm install -g $pkg\`."
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
      "Run \`bash scripts/doctor.sh\` in a normal terminal to check it."
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
        "Close Codex. In a terminal run \`nvm use v$NODE_MAJOR\`, then \`codex app-server daemon restart\`, then start Codex again (setup guide, section 1)."
    elif [ -n "$unknown" ]; then
      warn "Couldn't check which Node Codex's background service uses from here" \
        "Run \`bash scripts/doctor.sh\` in a normal terminal to check it."
    else
      pass "Codex background service runs on Node $NODE_MAJOR"
    fi
  fi
fi

# openfortivpn (VPN client, D14)
if command -v openfortivpn >/dev/null 2>&1; then
  pass "openfortivpn $(openfortivpn --version 2>&1 | head -1)"
else
  fail "openfortivpn is not installed" "Run \`brew install openfortivpn\` (setup guide, section 2.1)."
fi

# Docker: only needed when you use Docker copies of Redis or RabbitMQ (D21, D54). flow-setup-repo can use Homebrew ones.
uses_docker=""
# 'docker info' can hang while Docker Desktop is starting or stuck, so it gets a 10-second limit.
docker_answers() { # 0 = Docker answers; 124 = no answer within 10 s
  local pid waited=0
  { docker info >/dev/null 2>&1 & pid=$!
    while kill -0 "$pid" 2>/dev/null; do
      if [ "$waited" -ge 10 ]; then kill -KILL "$pid"; wait "$pid"; return 124; fi
      sleep 1; waited=$((waited + 1))
    done
    wait "$pid"; } 2>/dev/null
}
case " $LOCAL_REDIS_FROM $LOCAL_RABBITMQ_FROM " in *" docker "*) uses_docker="yes" ;; esac
if ! command -v docker >/dev/null 2>&1; then
  if [ -n "$uses_docker" ]; then
    fail "Docker is not installed, but you chose Docker for Redis or RabbitMQ" \
      "Install Docker Desktop from docker.com, or choose Homebrew instead: \`/flow-setup-repo <repo> services\`"
  else
    pass "Docker isn't installed (only needed if you choose Docker for Redis or RabbitMQ)"
  fi
elif docker_answers; then
  pass "Docker is installed and running"
elif [ $? -eq 124 ]; then
  warn "Docker Desktop doesn't answer (it may be starting, or stuck)" "Wait a minute; if it stays like this, quit Docker Desktop and open it again."
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
    "Approve running flow-doctor with network access, or run \`bash scripts/doctor.sh\` in a normal terminal."
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
        "Run \`/flow-vpn connect\` (Codex: \`\$flow-vpn connect\`). It adds the file."
    else
      fail "VPN is on (openfortivpn), but GitLab doesn't answer (HTTP ${code:-none})" \
        "Run \`/flow-vpn disconnect\`, then \`/flow-vpn connect\`. If it still fails, see the setup guide, section 2.6."
    fi
  else
    warn "VPN is off. That's fine until you need GitLab" \
      "To connect, run \`/flow-vpn connect\` (Codex: \`\$flow-vpn connect\`)."
    if [ -f "$VPN_RESOLVER_FILE" ]; then
      fail "A leftover VPN DNS file is still there; it stops the next VPN connection" \
        "Run \`/flow-vpn connect\` (it removes the file first), or: \`sudo rm -f $VPN_RESOLVER_FILE\`"
    else
      pass "No leftover VPN DNS file"
    fi
  fi
fi

if [ -f "$VPN_OLD_RESOLVER_FILE" ]; then
  warn "An old GitLab-only DNS file is still there (no longer needed)" \
    "It's removed the next time you run \`/flow-vpn connect\`, or now with: \`sudo rm -f $VPN_OLD_RESOLVER_FILE\`"
fi

# The pinned VPN certificate (D14) stops working when the gateway's certificate is renewed.
expires_epoch="$(date -j -f %Y-%m-%d "$VPN_CERT_EXPIRES" +%s 2>/dev/null)"
if [ -n "$expires_epoch" ]; then
  days_left=$(( (expires_epoch - $(date +%s)) / 86400 ))
  if [ "$days_left" -lt 0 ]; then
    fail "The VPN certificate pin expired on $VPN_CERT_EXPIRES, so the VPN won't connect" \
      "Ask the IT/infra team to confirm the new certificate, then put its fingerprint in \`config/project-settings.sh\` (\`VPN_CERT_SHA256\` and \`VPN_CERT_EXPIRES\`)."
  elif [ "$days_left" -lt 30 ]; then
    warn "The VPN certificate pin expires in $days_left days ($VPN_CERT_EXPIRES)" \
      "Ask the IT/infra team for the new certificate's fingerprint, then update \`config/project-settings.sh\`."
  else
    pass "VPN certificate pin is valid until $VPN_CERT_EXPIRES ($days_left days left)"
  fi
fi

# ---------------------------------------------------------------- Personal settings (F4)
section "Personal settings" "\`local/user-settings.sh\`"

if [ ! -f "$USER_SETTINGS_FILE" ]; then
  fail "Your personal settings aren't set up yet" "Run \`/flow-configure-user\` (Codex: \`\$flow-configure-user\`)."
else
  check_setting() { # $1 value, $2 label, $3 item name
    if [ -n "$1" ]; then pass "$2: $1"; else fail "$2 is not set" "Run \`/flow-configure-user $3\`"; fi
  }
  check_setting "$JIRA_ACCOUNT_ID" "Jira account ID" jira-account-id
  check_setting "$GITLAB_USERNAME" "GitLab username" gitlab-username
  if [ -z "$WORKSPACE_DIR" ]; then
    fail "Workspace folder is not set" "Run \`/flow-configure-user workspace-dir\`"
  elif [ ! -d "$WORKSPACE_DIR" ]; then
    fail "Workspace folder doesn't exist: $WORKSPACE_DIR" "Create it again, or choose another with \`/flow-configure-user workspace-dir\`"
  else
    pass "Workspace folder: $WORKSPACE_DIR"
  fi
  check_setting "$AI_TOOLS" "AI tools" ai-tools
fi

# ---------------------------------------------------------------- User memory (F6b)
section "User memory" "\`local/memory/\`, private"

# Absence is normal: the memory is created on the first saved entry (D40). Never a ❌.
memory_count="$(bash "$AGENT_ROOT/scripts/memory.sh" count 2>/dev/null)"
memory_problems="$(bash "$AGENT_ROOT/scripts/memory.sh" problems 2>/dev/null | grep -c '^⚠️')"
if [ "${memory_count:-0}" -gt 0 ] 2>/dev/null; then
  pass "User memory: $memory_count $( [ "$memory_count" -eq 1 ] && echo entry || echo entries ) (see them with \`/flow-memory\`)"
else
  pass "User memory: none yet (that's normal; add entries with \`/flow-memory add <text>\`)"
fi
[ "${memory_problems:-0}" -gt 0 ] && warn "$memory_problems line(s) in your memory files aren't in the memory format, so they're ignored" \
  "Run \`/flow-memory\` to see which lines, then fix or remove them."

# ---------------------------------------------------------------- Repos (F5)
# ---------------------------------------------------------------- Commands documented (F8, D60, rule R17)
section "Commands documented" "\`/flow-help\`, user guide, Claude artifact"
relay "$(bash "$AGENT_ROOT/scripts/help.sh" check 2>/dev/null)"

# ---------------------------------------------------------------- Card hooks (D86, D87; rules A29, A30)
section "Card hooks" "the card rules on every prompt about a card, the card's folder saved after every reply"
rules_hook="card-rules-hook.sh"; save_hook="card-autosave-hook.sh"
if ! command -v jq >/dev/null 2>&1; then
  fail "jq isn't installed, so the card hooks can't run" "Install it: \`brew install jq\`, then run \`/flow-doctor\` again."
elif printf '{"prompt":"/flow-develop %s-1"}' "${JIRA_PROJECT_KEY:-SCRUM}" | bash "$AGENT_ROOT/scripts/$rules_hook" 2>/dev/null |
     jq -e '.hookSpecificOutput.additionalContext | test("card-rules")' >/dev/null 2>&1; then
  pass "The card-rules hook adds \`rulesets/card-rules.md\` to a card command (tested just now)"
else
  fail "The card-rules hook doesn't add the card rules" "Check that \`rulesets/card-rules.md\` and \`scripts/$rules_hook\` exist (\`git status\`; restore them with \`git checkout -- rulesets/card-rules.md scripts/$rules_hook\`), then run \`/flow-doctor\` again."
fi
[ -f "$AGENT_ROOT/scripts/$save_hook" ] || fail "The auto-save hook is missing" "Restore it: \`git checkout -- scripts/$save_hook\`, then run \`/flow-doctor\` again."
if grep -q "$rules_hook" "$AGENT_ROOT/.claude/settings.json" 2>/dev/null && grep -q "$save_hook" "$AGENT_ROOT/.claude/settings.json" 2>/dev/null; then
  pass "Claude Code: both hooks are set in \`.claude/settings.json\` (the card rules on each prompt, the auto-save after each reply)"
else
  fail "Claude Code: the card hooks aren't both set in \`.claude/settings.json\`" "Restore the file's \`hooks\` block: \`git checkout -- .claude/settings.json\`, then start Claude Code again in this folder."
fi
if grep -q "$rules_hook" "$AGENT_ROOT/.codex/hooks.json" 2>/dev/null && grep -q "$save_hook" "$AGENT_ROOT/.codex/hooks.json" 2>/dev/null; then
  pass "Codex: both hooks are set in \`.codex/hooks.json\`"
  trust_steps="(1) Start Codex in the closio-agent folder (after \`nvm use v22\`); it says \"… hooks need review before they can run\". (2) Type \`/hooks\`. (3) In the list, select the hooks under \"When the user submits a prompt\" (\`bash scripts/$rules_hook\`) and \"Right before Codex ends its turn\" (\`bash scripts/$save_hook\`) and approve them. (4) Send any prompt that names a card (e.g. \"Is SCRUM-567 picked up?\"), then \`\$flow-doctor\` again: this line turns ✅. If the hook file changes later, Codex asks again."
  case " ${AI_TOOLS:-} " in
    *" codex "*)
      codex_ran="$AGENT_ROOT/local/card-sessions/codex-ran"
      if [ ! -f "$codex_ran" ]; then
        warn "Codex hasn't run the card hooks yet: they wait for your OK once" "$trust_steps"
      elif [ "$(cat "$codex_ran" 2>/dev/null)" != "$(shasum -a 256 "$AGENT_ROOT/.codex/hooks.json" 2>/dev/null | cut -d' ' -f1)" ]; then
        warn "Codex's hook file changed since Codex last ran it: approve the hooks again" "$trust_steps"
      else
        pass "Codex: the hooks are trusted and have run"
      fi ;;
  esac
else
  fail "Codex: the card hooks aren't both set in \`.codex/hooks.json\`" "Restore it: \`git checkout -- .codex/hooks.json\`, start Codex again in this folder and approve the hooks when it asks."
fi

# ---------------------------------------------------------------- Cards in progress (C1, D61)
section "Cards in progress" "\`runs/\`, \`/flow-status\`"
cards_n="$(bash "$AGENT_ROOT/scripts/run.sh" count 2>/dev/null)"
cards_problems="$(bash "$AGENT_ROOT/scripts/run.sh" problems 2>/dev/null)"
[ -n "$cards_problems" ] && relay "$cards_problems"
if [ "${cards_n:-0}" -eq 0 ]; then
  pass "No card in progress (pick one up with \`/flow-start <CARD-KEY>\`)"
else
  pass "Cards in progress: $cards_n (see them with \`/flow-status\`)"
fi

section "Checking web cards" "Playwright, \`/flow-verify\`"
if bash "$AGENT_ROOT/scripts/e2e.sh" check >/dev/null 2>&1; then
  pass "Playwright is set up (\`e2e/\` packages and the Chromium browser)"
else
  warn "Playwright isn't set up yet (needed to check web cards)" "Run \`/flow-configure-user playwright\` (Codex: \`\$flow-configure-user playwright\`); it asks before the download."
fi

section "Repos" "\`config/repos/\`"

yaml_get() { # <file> <key>: value of a flat "key: value" line
  [ -f "$1" ] || return 0
  grep -m1 -E "^$2:" "$1" | sed -E "s/^$2:[[:space:]]*//; s/[[:space:]]+#.*$//; s/[[:space:]]+$//"
}
for ruleset_file in "$RULESET_FILE" "$FRONTEND_RULESET_FILE"; do
  if [ -f "$AGENT_ROOT/$ruleset_file" ]; then
    case "$ruleset_file" in "$RULESET_FILE") what="backend cards" ;; *) what="web-app cards" ;; esac
    pass "Ruleset for $what: \`$ruleset_file\`"
  else
    fail "The ruleset file \`$ruleset_file\` is missing" "It's part of closio-agent: \`git checkout -- $ruleset_file\` (or pull the latest closio-agent)."
  fi
done
repo_count=0
for repo_file in "$AGENT_ROOT"/config/repos/*.yaml; do
  [ -f "$repo_file" ] || continue
  repo_count=$((repo_count + 1))
  repo="$(basename "$repo_file" .yaml)"
  local_repo_file="$AGENT_ROOT/local/repos/$repo.yaml"
  repo_path="$(yaml_get "$local_repo_file" local_path)"
  if [ ! -f "$local_repo_file" ]; then
    warn "$repo isn't set up on this Mac" "Run \`/flow-configure-repo $repo\` (only if you work on it)."
    continue
  elif [ -z "$repo_path" ]; then
    warn "$repo isn't cloned on this Mac yet" "Cloning is manual: on the VPN, \`git clone $(yaml_get "$repo_file" gitlab_url) <your workspace folder>/$repo\`, then run \`/flow-configure-repo $repo path <that folder>\`."
  elif [ ! -d "$repo_path/.git" ]; then
    fail "$repo: clone not found at $repo_path" "Run \`/flow-configure-repo $repo\` and give the new path."
  else
    want="$(yaml_get "$repo_file" gitlab_path)"
    have="$(git -C "$repo_path" remote get-url origin 2>/dev/null | sed -E 's#://[^/@]*@#://#; s#^[a-z]+://[^/]+/##; s#^[^@]+@[^:]+:##; s#\.git$##')"
    if [ "$want" = "$have" ]; then
      pass "$repo: $repo_path"
    else
      fail "$repo: $repo_path is a clone of '${have:-no GitLab remote}', not '$want'" "Run \`/flow-configure-repo $repo\` and give the right clone."
    fi
  fi
  # Each repo runs on its own Node version (rule A13, D52); it must be installed in nvm.
  repo_node="$(yaml_get "$repo_file" node_version)"
  case "$repo_node" in
    ''|none) ;;
    *) ls -d "$NVM_DIR/versions/node/v$repo_node."* >/dev/null 2>&1 ||
         warn "Node $repo_node (what $repo is built for) isn't installed in nvm" "Run: \`nvm install $repo_node\`" ;;
  esac
  [ -n "$(yaml_get "$repo_file" dev_base_url)" ] ||
    warn "$repo has no dev address yet (needed for the dev checks of \`/flow-finish\`)" "Run \`/flow-setup-repo $repo dev-address\` (Codex: \`\$flow-setup-repo $repo dev-address\`)."
  for k in $(yaml_get "$repo_file" dev_keys | tr ',' ' '); do
    [ "$k" = "none" ] && continue
    security find-generic-password -a "$USER" -s "$KEYCHAIN_PREFIX.$repo.$k.dev" >/dev/null 2>&1 ||
      warn "\`$KEYCHAIN_PREFIX.$repo.$k.dev\` is missing (needed to test $repo on dev)" "Run \`/flow-configure-repo $repo\` (it asks for the key in a hidden macOS box)."
  done
done
[ "$repo_count" -eq 0 ] && warn "No repos registered yet" "Run \`/flow-configure-repo\` with the full path of a local clone."

# ---------------------------------------------------------------- Repo setup (F6)
section "Repo setup on this Mac" "\`/flow-setup-repo\`"

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
    warn "$repo: its packages aren't installed any more" "Run \`/flow-setup-repo $repo\`"
  else
    pass "$repo: set up on $setup_on (tests: $(yaml_get "$local_repo_file" setup_tests))"
  fi
  if [ "$claude_need" != "unused" ] && ! jq -e --arg p "$repo_path" '(.permissions.additionalDirectories // []) | index($p)' "$claude_settings" >/dev/null 2>&1; then
    warn "$repo: Claude Code can't use its folder yet" "Run \`/flow-setup-repo $repo\` (it adds the folder to your \`.claude/settings.local.json\`)."
  fi
  repo_services="$(yaml_get "$repo_file" local_services)"
  case ", $repo_services," in *", redis,"* | *", bullmq,"*) need_redis="$need_redis $repo" ;; esac
  case ", $repo_services," in *", rabbitmq,"*) need_rabbitmq="$need_rabbitmq $repo" ;; esac
done
[ -n "$not_set_up" ] && warn "Cloned but not set up yet:$not_set_up" "Run \`/flow-setup-repo <repo>\`, or \`/flow-setup-repo all\`."
[ "$set_up_count" -eq 0 ] && [ -z "$not_set_up" ] && pass "No cloned repos to set up yet"

if [ -n "$need_redis$need_rabbitmq" ] && [ "${CODEX_SANDBOX_NETWORK_DISABLED:-}" = "1" ]; then
  warn "Can't check the local Redis and RabbitMQ from inside Codex's sandbox" "Run \`bash scripts/doctor.sh\` in a normal terminal."
else
  if [ -n "$need_redis" ]; then
    if [ "$(printf 'PING\r\n' | nc -G 2 -w 2 127.0.0.1 "$LOCAL_REDIS_PORT" 2>/dev/null | tr -d '\r' | head -1)" = "+PONG" ]; then
      pass "Local Redis answers on port $LOCAL_REDIS_PORT${LOCAL_REDIS_FROM:+ ($LOCAL_REDIS_FROM)}"
    else
      warn "Local Redis doesn't answer on port $LOCAL_REDIS_PORT (needed by:$need_redis)" "Run \`/flow-setup-repo $(echo "$need_redis" | awk '{print $1}')\` (it finds or starts it)."
    fi
  fi
  if [ -n "$need_rabbitmq" ]; then
    if nc -z -G 2 127.0.0.1 "$LOCAL_RABBITMQ_PORT" >/dev/null 2>&1; then
      pass "Local RabbitMQ answers on port $LOCAL_RABBITMQ_PORT${LOCAL_RABBITMQ_FROM:+ ($LOCAL_RABBITMQ_FROM)}"
    else
      warn "Local RabbitMQ doesn't answer on port $LOCAL_RABBITMQ_PORT (needed by:$need_rabbitmq)" "Run \`/flow-setup-repo $(echo "$need_rabbitmq" | awk '{print $1}')\` (it finds or starts it)."
    fi
  fi
fi

# ---------------------------------------------------------------- Keychain
section "Keychain" "names only, values are never read"

for item in $KEYCHAIN_PERSONAL_ITEMS; do
  service="$KEYCHAIN_PREFIX.$item"
  security find-generic-password -a "$USER" -s "$service" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "\`$service\`"
  elif [ "$rc" -eq 44 ]; then
    fail "\`$service\` is missing" \
      "Run \`/flow-configure-user $item\` (Codex: \`\$flow-configure-user $item\`). It asks for the value in a hidden macOS box." \
      "Backup, in your own terminal (not the AI chat): \`security add-generic-password -U -a \"\$USER\" -s \"$service\" -w\`"
  else
    warn "Couldn't read the Keychain from here to check \`$service\`" \
      "Run \`bash scripts/doctor.sh\` in a normal terminal."
  fi
done

# ---------------------------------------------------------------- Jira API backup (D88)
# Optional: the commands switch to it by themselves when the Jira connector isn't there. So ✅ or ⚠️, never ❌.
section "Jira API backup" "optional, used only when the Jira connector isn't there"
relay "$(bash "$AGENT_ROOT/scripts/jira-api.sh" check 2>&1 | sed 's/^❌ /⚠️ /; s/^   Fix: /   Tip: /')"

# ---------------------------------------------------------------- Result
result
[ "$to_fix" -eq 0 ] || exit 1
