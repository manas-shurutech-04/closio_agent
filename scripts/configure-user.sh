#!/usr/bin/env bash
# Personal settings for the flow-configure-user command (F4, D15).
# Run it from the closio-agent folder:  bash scripts/configure-user.sh <action>
#
#   check-folder                     Is this session in the closio-agent folder? (strict rule, D42)
#   show                             What's set and what's missing (secrets: names only, never values)
#   set <item> <value>               jira-account-id | gitlab-username | workspace-dir | ai-tools | vpn-username | git-name | git-email
#   secrets                          Asks every missing secret in one run (one approval in the AI tool)
#   secret <item>                    Heads-up dialog, then a hidden dialog; the value goes straight into the Keychain
#   gitlab-username-from-token       Reads your GitLab username with the stored token (VPN needed)
#   store-secret-from-stdin <item>   Stores the value read from stdin (used by 'secret' and by tests)
#
# Personal settings go to local/user-settings.sh (private, git-ignored, never pushed).
# Secrets only go to the macOS Keychain. Secret values are never printed (D33).
# Every ❌ comes with the steps to fix it (rule A11).

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
USER_SETTINGS_FILE="${USER_SETTINGS_FILE:-$AGENT_ROOT/local/user-settings.sh}"

CMD="/flow-configure-user"
CMD_CODEX="\$flow-configure-user"

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

# ---------------------------------------------------------------- personal settings file

JIRA_ACCOUNT_ID=""
GITLAB_USERNAME=""
WORKSPACE_DIR=""
AI_TOOLS=""
VPN_USERNAME=""
LOCAL_REDIS_FROM=""      # set by flow-setup-repo (F6, D54)
LOCAL_RABBITMQ_FROM=""
[ -f "$USER_SETTINGS_FILE" ] && . "$USER_SETTINGS_FILE"

# Values are written inside double quotes, so they must not contain characters the shell would treat specially.
plain_value() {
  case "$1" in *'"'* | *'$'* | *'`'* | *'\'*) return 1 ;; esac
  [ "$(printf '%s' "$1" | wc -l | tr -d ' ')" = "0" ]
}

write_settings() {
  mkdir -p "$(dirname "$USER_SETTINGS_FILE")"
  {
    echo "# Personal closio-agent settings for this Mac (F4, D15)."
    echo "# Private: the local/ folder is git-ignored and never pushed."
    echo "# Written by flow-configure-user. No secrets here: they are in the macOS Keychain."
    printf 'JIRA_ACCOUNT_ID="%s"\n' "$JIRA_ACCOUNT_ID"
    printf 'GITLAB_USERNAME="%s"\n' "$GITLAB_USERNAME"
    printf 'WORKSPACE_DIR="%s"\n' "$WORKSPACE_DIR"
    printf 'AI_TOOLS="%s"\n' "$AI_TOOLS"
    printf 'VPN_USERNAME="%s"   # optional, not needed today (kept for later use, D15)\n' "$VPN_USERNAME"
    if [ -n "$LOCAL_REDIS_FROM" ]; then printf 'LOCAL_REDIS_FROM="%s"   # homebrew or docker; set by flow-setup-repo (D54)\n' "$LOCAL_REDIS_FROM"; fi
    if [ -n "$LOCAL_RABBITMQ_FROM" ]; then printf 'LOCAL_RABBITMQ_FROM="%s"   # homebrew or docker; set by flow-setup-repo (D54)\n' "$LOCAL_RABBITMQ_FROM"; fi
  } > "$USER_SETTINGS_FILE.tmp" && mv "$USER_SETTINGS_FILE.tmp" "$USER_SETTINGS_FILE"
}

# ---------------------------------------------------------------- secrets

secret_description() {
  case "$1" in
    gitlab-token) echo "your GitLab personal access token (scope: api; setup guide, section 4.2)" ;;
    fe-login-id) echo "your login ID for the Closio web app" ;;
    fe-login-password) echo "your password for the Closio web app" ;;
    ws1-login-userid) echo "your userid for the dev WS1 login (every check logs in on dev, rule A24)" ;;
    ws1-login-password) echo "your password for the dev WS1 login (rule A24)" ;;
    *) return 1 ;;
  esac
}

secret_label() {
  case "$1" in
    gitlab-token) echo "$KEYCHAIN_PREFIX: GitLab personal access token" ;;
    fe-login-id) echo "$KEYCHAIN_PREFIX: Closio web app login ID" ;;
    fe-login-password) echo "$KEYCHAIN_PREFIX: Closio web app password" ;;
    ws1-login-userid) echo "$KEYCHAIN_PREFIX: WS1 login API userid" ;;
    ws1-login-password) echo "$KEYCHAIN_PREFIX: WS1 login API password" ;;
  esac
}

valid_secret_item() {
  local i
  for i in $KEYCHAIN_PERSONAL_ITEMS; do [ "$i" = "$1" ] && return 0; done
  return 1
}

secret_stored() { keychain_has "$KEYCHAIN_PREFIX.$1"; }

store_secret_from_stdin_item() { # <item>
  store_secret_from_stdin "$KEYCHAIN_PREFIX.$1" "$(secret_label "$1")" "$CMD $1"
}

gitlab_token_check() { # prints the username on success; return 0 ok, 1 rejected, 2 can't reach GitLab, 3 no token
  local token response status
  token="$(security find-generic-password -a "$USER" -s "$KEYCHAIN_PREFIX.gitlab-token" -w 2>/dev/null)"
  [ -n "$token" ] || return 3
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 "https://$GITLAB_HOST/users/sign_in" 2>/dev/null)" = "200" ] || { token=""; return 2; }
  response="$(printf 'PRIVATE-TOKEN: %s\n' "$token" | curl -s --max-time 8 -H @- -w '\n%{http_code}' "https://$GITLAB_HOST/api/v4/user" 2>/dev/null)"
  token=""
  status="$(printf '%s' "$response" | tail -1)"
  [ "$status" = "200" ] || return 1
  printf '%s' "$response" | grep -o '"username":"[^"]*"' | head -1 | cut -d'"' -f4
  return 0
}

gitlab_username_from_token() {
  local username rc
  username="$(gitlab_token_check)"
  rc=$?
  case "$rc" in
    0)
      if [ -n "$username" ] && plain_value "$username"; then
        GITLAB_USERNAME="$username"
        write_settings
        ok "GitLab token works. GitLab username saved: $username"
        return 0
      fi
      bad "GitLab answered, but without a username" "Type your GitLab username: $CMD gitlab-username"
      ;;
    1) bad "GitLab rejected your token: it may be expired, revoked, or missing the api scope" \
         "Make a new token (setup guide, section 4.2), then run $CMD gitlab-token" ;;
    2) look "Can't check the token or read your GitLab username: GitLab isn't reachable (VPN off?)" \
         "Run /flow-vpn connect, then $CMD gitlab-username. Or type your GitLab username yourself." ;;
    3) bad "No GitLab token in the Keychain yet" "Run $CMD gitlab-token" ;;
  esac
  return 1
}

ask_secret() {
  local item="$1" desc rc
  desc="$(secret_description "$item")" || { bad "Unknown secret: $item" "Use one of: $KEYCHAIN_PERSONAL_ITEMS"; return 1; }
  ask_secret_dialog "$KEYCHAIN_PREFIX.$item" "$(secret_label "$item")" "$desc" "$CMD $item"
  rc=$?
  [ "$rc" -eq 0 ] || return "$rc"
  if [ "$item" = "gitlab-token" ]; then
    gitlab_username_from_token
  fi
  return 0
}

# All missing secrets in one run, so the AI tool asks for approval only once.
ask_missing_secrets() {
  local item missing="" stored=0 skipped=0 failed=0 rc
  for item in $KEYCHAIN_PERSONAL_ITEMS; do
    secret_stored "$item" || missing="$missing $item"
  done
  if [ -z "$missing" ]; then
    ok "All $(echo $KEYCHAIN_PERSONAL_ITEMS | wc -w | tr -d ' ') secrets are already stored. To replace one, run $CMD <item>"
    return 0
  fi
  echo "Secrets to add:$missing"
  echo "For each one: a macOS message says which is next (copy it, then click Continue), then a hidden box opens to paste it into."
  echo
  for item in $missing; do
    ask_secret "$item"
    rc=$?
    case "$rc" in
      0) stored=$((stored + 1)) ;;
      3) skipped=$((skipped + 1)) ;;
      *) failed=$((failed + 1)) ;;
    esac
  done
  echo
  echo "Secrets: $stored stored, $skipped skipped, $failed failed."
  [ "$failed" -eq 0 ]
}

# ---------------------------------------------------------------- set (non-secret items)

set_item() {
  local item="$1" value="${2:-}"
  case "$item" in
    jira-account-id)
      printf '%s' "$value" | grep -q -E '^[A-Za-z0-9:_-]{6,128}$' ||
        { bad "That doesn't look like a Jira account ID" "Let the AI fetch it again: $CMD jira-account-id"; return 1; }
      JIRA_ACCOUNT_ID="$value"; write_settings; ok "Jira account ID saved" ;;
    gitlab-username)
      printf '%s' "$value" | grep -q -E '^[A-Za-z0-9_.-]{1,255}$' ||
        { bad "That doesn't look like a GitLab username" "Use the name shown on your GitLab profile, without @. Run $CMD gitlab-username again."; return 1; }
      GITLAB_USERNAME="$value"; write_settings; ok "GitLab username saved: $value" ;;
    workspace-dir)
      case "$value" in "~"*) value="$HOME${value#\~}" ;; esac
      case "$value" in /*) ;; *) bad "The workspace folder must be a full path, starting with /" "Run $CMD workspace-dir again with the full path."; return 1 ;; esac
      [ -d "$value" ] || { bad "Folder not found: $value" "Create it first (e.g. in Finder), then run $CMD workspace-dir again."; return 1; }
      value="$(cd "$value" && pwd -P)"
      plain_value "$value" || { bad "The folder path has characters that aren't supported (\" \$ \` \\)" "Use or create a folder whose path doesn't contain them."; return 1; }
      WORKSPACE_DIR="$value"; write_settings; ok "Workspace folder saved: $value" ;;
    ai-tools)
      case "$value" in
        claude-code) AI_TOOLS="claude-code" ;;
        codex) AI_TOOLS="codex" ;;
        both) AI_TOOLS="claude-code codex" ;;
        *) bad "Unknown choice: $value" "Use claude-code, codex or both: $CMD ai-tools"; return 1 ;;
      esac
      write_settings; ok "AI tools saved: $AI_TOOLS" ;;
    vpn-username)
      plain_value "$value" || { bad "That username has characters that aren't supported" "Run $CMD vpn-username again."; return 1; }
      VPN_USERNAME="$value"; write_settings
      if [ -n "$value" ]; then ok "VPN username saved (optional, not needed today)"; else ok "VPN username left empty (optional, not needed today)"; fi ;;
    git-name)
      [ -n "$value" ] || { bad "The name is empty" "Run $CMD git-name again."; return 1; }
      git config --global user.name "$value" && ok "git name set: $value" ;;
    git-email)
      printf '%s' "$value" | grep -q -E '^[^@ ]+@[^@ ]+\.[^@ ]+$' ||
        { bad "That doesn't look like an email address" "Run $CMD git-email again."; return 1; }
      git config --global user.email "$value" && ok "git email set: $value" ;;
    *)
      bad "Unknown item: $item" "Use one of: jira-account-id, gitlab-username, workspace-dir, ai-tools, vpn-username, git-name, git-email"
      return 1 ;;
  esac
}

# ---------------------------------------------------------------- show

show() {
  local missing=0 item
  echo "flow-configure-user — your personal settings"
  echo
  echo "Personal settings (local/user-settings.sh, never pushed)"
  if [ -n "$JIRA_ACCOUNT_ID" ]; then ok "Jira account ID: $JIRA_ACCOUNT_ID"; else bad "Jira account ID: not set" "Run $CMD jira-account-id (the AI fetches it from Jira)."; missing=$((missing + 1)); fi
  if [ -n "$GITLAB_USERNAME" ]; then ok "GitLab username: $GITLAB_USERNAME"; else bad "GitLab username: not set" "Run $CMD gitlab-username (read from your GitLab token when the VPN is on)."; missing=$((missing + 1)); fi
  if [ -n "$WORKSPACE_DIR" ] && [ -d "$WORKSPACE_DIR" ]; then
    ok "Workspace folder: $WORKSPACE_DIR"
  elif [ -n "$WORKSPACE_DIR" ]; then
    bad "Workspace folder doesn't exist any more: $WORKSPACE_DIR" "Run $CMD workspace-dir to choose it again."; missing=$((missing + 1))
  else
    bad "Workspace folder: not set" "Run $CMD workspace-dir"; missing=$((missing + 1))
  fi
  if [ -n "$AI_TOOLS" ]; then ok "AI tools: $AI_TOOLS"; else bad "AI tools: not set" "Run $CMD ai-tools"; missing=$((missing + 1)); fi
  if [ -n "$VPN_USERNAME" ]; then ok "VPN username: $VPN_USERNAME (optional, not needed today)"; else ok "VPN username: not set (optional, not needed today)"; fi
  echo "   VPN gateway and port are shared settings: $VPN_GATEWAY:$VPN_PORT (config/project-settings.sh)"

  echo
  echo "Git"
  if [ -n "$(git config --global user.name)" ]; then ok "git name: $(git config --global user.name)"; else bad "git name: not set" "Run $CMD git-name"; missing=$((missing + 1)); fi
  if [ -n "$(git config --global user.email)" ]; then ok "git email: $(git config --global user.email)"; else bad "git email: not set" "Run $CMD git-email"; missing=$((missing + 1)); fi

  echo
  echo "Keychain (names only, values are never shown)"
  for item in $KEYCHAIN_PERSONAL_ITEMS; do
    if secret_stored "$item"; then
      ok "$KEYCHAIN_PREFIX.$item stored"
    else
      bad "$KEYCHAIN_PREFIX.$item missing" "Run $CMD $item (Codex: $CMD_CODEX $item)"
      missing=$((missing + 1))
    fi
  done

  echo
  echo "Playwright (for checking web cards, D67)"
  if [ -f "$AGENT_ROOT/e2e/node_modules/@playwright/test/package.json" ] && ls -d "${PLAYWRIGHT_BROWSERS_PATH:-$HOME/Library/Caches/ms-playwright}"/chromium-* >/dev/null 2>&1; then
    ok "Playwright is set up (e2e/ packages and the Chromium browser)"
  else
    bad "Playwright isn't set up" "Run $CMD playwright (a download of about 150 MB, about 430 MB on disk; it asks you first)."
    missing=$((missing + 1))
  fi

  echo
  echo "Result: $missing to set up."
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
  show) show ;;
  set) [ $# -ge 2 ] || { echo "Usage: bash scripts/configure-user.sh set <item> <value>"; exit 1; }; set_item "$2" "${3:-}" ;;
  secrets) ask_missing_secrets ;;
  secret)
    [ $# -eq 2 ] && valid_secret_item "$2" || { bad "Unknown secret: ${2:-none}" "Use one of: $KEYCHAIN_PERSONAL_ITEMS"; exit 1; }
    ask_secret "$2" ;;
  store-secret-from-stdin)
    [ $# -eq 2 ] && valid_secret_item "$2" || { bad "Unknown secret: ${2:-none}" "Use one of: $KEYCHAIN_PERSONAL_ITEMS"; exit 1; }
    store_secret_from_stdin_item "$2" ;;
  gitlab-username-from-token) gitlab_username_from_token ;;
  playwright) bash "$AGENT_ROOT/scripts/e2e.sh" setup ;;
  *)
    echo "Usage: bash scripts/configure-user.sh check-folder | show | set <item> <value> | secrets | secret <item> | gitlab-username-from-token | playwright"
    exit 1 ;;
esac
