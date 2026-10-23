# scripts/configure-user.sh: personal settings in local/user-settings.sh, secrets through the (stand-in) macOS dialogs
# into the fake Keychain, the GitLab token check against a fake GitLab, and the Playwright setup.

setup_user() {
  sandbox
  # the dialogs are the osascript stand-in; GitLab and Jira are unreachable unless a test starts a fake one
  export OSASCRIPT_BIN="$TESTS_DIR/fakes/bin/osascript" GITLAB_HOST="127.0.0.1:1" JIRA_API_URL="http://127.0.0.1:1"
  SETTINGS="$A/local/user-settings.sh"
}
dialogs_give() { # <value>: the heads-up dialog answers Continue, the hidden box gives <value>
  fake_cmd osascript "case \"\$*\" in *'hidden answer'*) printf '%s\\n' '$1' ;; *) echo Continue ;; esac"
}
# curl first on PATH: the real curl, but https:// addresses go over http (the fake servers have no TLS); its
# arguments are logged, so a test can check that a token is never on its command line
https_as_http() {
  mkdir -p "$T/bin"
  cat > "$T/bin/curl" <<'EOF'
#!/bin/bash
printf 'curl %s\n' "$*" >> "$FAKE_LOG"
args=()
for a in "$@"; do case "$a" in https://*) a="http://${a#https://}" ;; esac; args+=("$a"); done
exec /usr/bin/curl "${args[@]}"
EOF
  chmod +x "$T/bin/curl"
  export PATH="$T/bin:$PATH"
}
fake_gitlab() { # <body of /api/v4/user>: a fake GitLab that knows the token glpat-good; sets GITLAB_HOST to it
  https_as_http
  jq -n --arg body "$1" '[{path: "^/users/sign_in$", text: "sign in"},
    {path: "^/api/v4/user$", need_header: ["PRIVATE-TOKEN", "glpat-good"], text: $body}]' > "$T/gitlab.json"
  start_fake GL http "$T/gitlab.json"
  export GITLAB_HOST="${GL#http://}"
}
store_all_secrets() { local i; for i in gitlab-token fe-login-id fe-login-password ws1-login-userid ws1-login-password; do keychain_set "closio-agent.$i" "v-$i"; done; }
settings_line() { grep "^$1=" "$SETTINGS"; }

test_check_folder_in_and_outside_the_closio_agent_folder() {
  setup_user
  run configure-user.sh check-folder
  assert_rc 0; assert_eq "$OUT" "✅ Started in the closio-agent folder"
  run_in "$T" bash "$A/scripts/configure-user.sh" check-folder
  assert_rc 1
  assert_contains "$OUT" "❌ Not started in the closio-agent folder (current folder: $(cd "$T" && pwd))"
  assert_contains "$OUT" "   Fix: Quit, open a terminal in $(cd "$A" && pwd -P), run 'nvm use v22', then start Claude Code or Codex again."
  assert_contains "$OUT" "        Always start Claude Code or Codex in the closio-agent folder."
}
test_no_or_an_unknown_action_shows_the_usage() {
  setup_user
  run configure-user.sh
  assert_rc 1; assert_eq "$OUT" "Usage: bash scripts/configure-user.sh check-folder | show | set <item> <value> | secrets | secret <item> | gitlab-username-from-token | playwright"
  run configure-user.sh fly
  assert_rc 1; assert_contains "$OUT" "Usage:"
  run configure-user.sh set
  assert_rc 1; assert_eq "$OUT" "Usage: bash scripts/configure-user.sh set <item> <value>"
}
test_set_jira_account_id_writes_the_settings_file() {
  setup_user
  run configure-user.sh set jira-account-id 712020:abc-DEF_123
  assert_rc 0; assert_eq "$OUT" "✅ Jira account ID saved"
  assert_eq "$(cat "$SETTINGS")" '# Personal closio-agent settings for this Mac (F4, D15).
# Private: the local/ folder is git-ignored and never pushed.
# Written by flow-configure-user. No secrets here: they are in the macOS Keychain.
JIRA_ACCOUNT_ID="712020:abc-DEF_123"
GITLAB_USERNAME=""
WORKSPACE_DIR=""
AI_TOOLS=""
VPN_USERNAME=""   # optional, not needed today (kept for later use, D15)
JIRA_EMAIL=""   # optional: your Atlassian email, for the Jira API backup (D88)'
  assert_no_file "$SETTINGS.tmp"
}
test_set_keeps_the_other_settings_and_the_service_lines() {
  setup_user
  user_settings JIRA_ACCOUNT_ID=acc-123456 AI_TOOLS=codex LOCAL_REDIS_FROM=homebrew LOCAL_RABBITMQ_FROM=docker
  run configure-user.sh set gitlab-username jane.doe
  assert_rc 0; assert_eq "$OUT" "✅ GitLab username saved: jane.doe"
  assert_eq "$(settings_line JIRA_ACCOUNT_ID)" 'JIRA_ACCOUNT_ID="acc-123456"'
  assert_eq "$(settings_line GITLAB_USERNAME)" 'GITLAB_USERNAME="jane.doe"'
  assert_eq "$(settings_line AI_TOOLS)" 'AI_TOOLS="codex"'
  assert_eq "$(settings_line LOCAL_REDIS_FROM)" 'LOCAL_REDIS_FROM="homebrew"   # homebrew or docker; set by flow-setup-repo (D54)'
  assert_eq "$(settings_line LOCAL_RABBITMQ_FROM)" 'LOCAL_RABBITMQ_FROM="docker"   # homebrew or docker; set by flow-setup-repo (D54)'
}
test_set_refuses_values_that_do_not_fit_and_writes_nothing() {
  setup_user
  run configure-user.sh set jira-account-id "ab"
  assert_rc 1; assert_contains "$OUT" "❌ That doesn't look like a Jira account ID"; assert_contains "$OUT" "   Fix: Let the AI fetch it again: /flow-configure-user jira-account-id"
  run configure-user.sh set gitlab-username "@jane"
  assert_rc 1; assert_contains "$OUT" "❌ That doesn't look like a GitLab username"
  run configure-user.sh set ai-tools vim
  assert_rc 1; assert_contains "$OUT" "❌ Unknown choice: vim"; assert_contains "$OUT" "Fix: Use claude-code, codex or both: /flow-configure-user ai-tools"
  run configure-user.sh set vpn-username 'jane"x'
  assert_rc 1; assert_contains "$OUT" "❌ That username has characters that aren't supported"
  run configure-user.sh set vpn-username 'two
lines'
  assert_rc 1
  run configure-user.sh set git-name ""
  assert_rc 1; assert_contains "$OUT" "❌ The name is empty"
  run configure-user.sh set git-email "jane at example"
  assert_rc 1; assert_contains "$OUT" "❌ That doesn't look like an email address"; assert_contains "$OUT" "Run /flow-configure-user git-email again."
  run configure-user.sh set jira-email "jane@example"
  assert_rc 1; assert_contains "$OUT" "Use the email you log in to Jira with. Run /flow-configure-user jira-email again."
  run configure-user.sh set jira-email 'ja$ne@example.com'
  assert_rc 1; assert_contains "$OUT" "❌ That doesn't look like an email address"
  run configure-user.sh set colour blue
  assert_rc 1; assert_contains "$OUT" "❌ Unknown item: colour"
  assert_contains "$OUT" "   Fix: Use one of: jira-account-id, gitlab-username, workspace-dir, ai-tools, vpn-username, git-name, git-email, jira-email"
  assert_no_file "$SETTINGS"
  assert_eq "$(git config --global user.email)" "" "git config untouched"
}
test_set_workspace_dir_saves_the_real_full_path() {
  setup_user
  mkdir -p "$HOME/work space/real"; ln -s "$HOME/work space/real" "$HOME/link"
  run configure-user.sh set workspace-dir "~/link"
  assert_rc 0
  local real; real="$(cd "$HOME/work space/real" && pwd -P)"
  assert_eq "$OUT" "✅ Workspace folder saved: $real"
  assert_eq "$(settings_line WORKSPACE_DIR)" "WORKSPACE_DIR=\"$real\""
}
test_set_workspace_dir_refuses_a_relative_missing_or_odd_path() {
  setup_user
  run configure-user.sh set workspace-dir "work"
  assert_rc 1; assert_contains "$OUT" "❌ The workspace folder must be a full path, starting with /"
  run configure-user.sh set workspace-dir "$T/nothing-here"
  assert_rc 1; assert_contains "$OUT" "❌ Folder not found: $T/nothing-here"; assert_contains "$OUT" "Fix: Create it first (e.g. in Finder)"
  mkdir -p "$T/a\$b"
  run configure-user.sh set workspace-dir "$T/a\$b"
  assert_rc 1; assert_contains "$OUT" "❌ The folder path has characters that aren't supported (\" \$ \` \\)"
  assert_no_file "$SETTINGS"
}
test_set_ai_tools_choices() {
  setup_user
  run configure-user.sh set ai-tools claude-code
  assert_eq "$OUT" "✅ AI tools saved: claude-code"
  run configure-user.sh set ai-tools codex
  assert_eq "$OUT" "✅ AI tools saved: codex"
  run configure-user.sh set ai-tools both
  assert_eq "$OUT" "✅ AI tools saved: claude-code codex"
  assert_eq "$(settings_line AI_TOOLS)" 'AI_TOOLS="claude-code codex"'
}
test_set_vpn_username_or_leave_it_empty() {
  setup_user
  run configure-user.sh set vpn-username jane
  assert_rc 0; assert_eq "$OUT" "✅ VPN username saved (optional, not needed today)"
  assert_eq "$(settings_line VPN_USERNAME)" 'VPN_USERNAME="jane"   # optional, not needed today (kept for later use, D15)'
  run configure-user.sh set vpn-username
  assert_rc 0; assert_eq "$OUT" "✅ VPN username left empty (optional, not needed today)"
  assert_contains "$(settings_line VPN_USERNAME)" 'VPN_USERNAME=""'
}
test_set_git_name_and_email_go_to_the_global_git_config() {
  setup_user
  run configure-user.sh set git-name "Jane Doe"
  assert_rc 0; assert_eq "$OUT" "✅ git name set: Jane Doe"
  run configure-user.sh set git-email jane@example.com
  assert_rc 0; assert_eq "$OUT" "✅ git email set: jane@example.com"
  assert_eq "$(git config --global user.name)" "Jane Doe"
  assert_eq "$(git config --global user.email)" "jane@example.com"
  assert_no_file "$SETTINGS"
}
test_set_jira_email() {
  setup_user
  run configure-user.sh set jira-email qa@example.com
  assert_rc 0; assert_eq "$OUT" "✅ Jira email saved: qa@example.com (optional: the Jira API backup)"
  assert_eq "$(settings_line JIRA_EMAIL)" 'JIRA_EMAIL="qa@example.com"   # optional: your Atlassian email, for the Jira API backup (D88)'
}
test_show_with_nothing_set_lists_everything_to_set_up() {
  setup_user
  run configure-user.sh show
  assert_rc 0
  assert_eq "$OUT" "flow-configure-user — your personal settings

Personal settings (local/user-settings.sh, never pushed)
❌ Jira account ID: not set
   Fix: Run /flow-configure-user jira-account-id (the AI fetches it from Jira).
❌ GitLab username: not set
   Fix: Run /flow-configure-user gitlab-username (read from your GitLab token when the VPN is on).
❌ Workspace folder: not set
   Fix: Run /flow-configure-user workspace-dir
❌ AI tools: not set
   Fix: Run /flow-configure-user ai-tools
✅ VPN username: not set (optional, not needed today)
   VPN gateway and port are shared settings: vpnwm.japfacomfeed.co.id:443 (config/project-settings.sh)

Git
❌ git name: not set
   Fix: Run /flow-configure-user git-name
❌ git email: not set
   Fix: Run /flow-configure-user git-email

Keychain (names only, values are never shown)
❌ closio-agent.gitlab-token missing
   Fix: Run /flow-configure-user gitlab-token (Codex: \$flow-configure-user gitlab-token)
❌ closio-agent.fe-login-id missing
   Fix: Run /flow-configure-user fe-login-id (Codex: \$flow-configure-user fe-login-id)
❌ closio-agent.fe-login-password missing
   Fix: Run /flow-configure-user fe-login-password (Codex: \$flow-configure-user fe-login-password)
❌ closio-agent.ws1-login-userid missing
   Fix: Run /flow-configure-user ws1-login-userid (Codex: \$flow-configure-user ws1-login-userid)
❌ closio-agent.ws1-login-password missing
   Fix: Run /flow-configure-user ws1-login-password (Codex: \$flow-configure-user ws1-login-password)

Jira API backup (optional: the commands switch to it by themselves when the Jira connector isn't there, D88)
⚠️ Jira email: not set (optional)
   Tip: Run /flow-configure-user jira-email, then /flow-configure-user jira-api-token (setup guide, section 3).
⚠️ closio-agent.jira-api-token: not stored (optional)
   Tip: Run /flow-configure-user jira-api-token (Codex: \$flow-configure-user jira-api-token).

Playwright (for checking web cards)
❌ Playwright isn't set up
   Fix: Run /flow-configure-user playwright (a download of about 150 MB, about 430 MB on disk; it asks you first).

Result: 12 to set up."
}
test_show_with_everything_set_and_no_secret_values() {
  setup_user
  mkdir -p "$T/ws"
  user_settings JIRA_ACCOUNT_ID=acc-123456 GITLAB_USERNAME=jane WORKSPACE_DIR="$T/ws" AI_TOOLS=codex VPN_USERNAME=jvpn JIRA_EMAIL=qa@example.com
  git config --global user.name "Jane Doe"; git config --global user.email jane@example.com
  store_all_secrets; keychain_set closio-agent.jira-api-token v-jira
  mkdir -p "$A/e2e/node_modules/@playwright/test" "$T/browsers/chromium-1140"
  echo '{}' > "$A/e2e/node_modules/@playwright/test/package.json"
  PLAYWRIGHT_BROWSERS_PATH="$T/browsers" run configure-user.sh show
  assert_rc 0
  assert_contains "$OUT" "✅ Jira account ID: acc-123456"
  assert_contains "$OUT" "✅ GitLab username: jane"
  assert_contains "$OUT" "✅ Workspace folder: $T/ws"
  assert_contains "$OUT" "✅ AI tools: codex"
  assert_contains "$OUT" "✅ VPN username: jvpn (optional, not needed today)"
  assert_contains "$OUT" "✅ git name: Jane Doe"
  assert_contains "$OUT" "✅ git email: jane@example.com"
  assert_contains "$OUT" "✅ closio-agent.ws1-login-password stored"
  assert_contains "$OUT" "✅ Jira email: qa@example.com"
  assert_contains "$OUT" "✅ closio-agent.jira-api-token stored"
  assert_contains "$OUT" "✅ Playwright is set up (e2e/ packages and the Chromium browser)"
  assert_contains "$OUT" "Result: 0 to set up."
  assert_not_contains "$OUT" "❌"; assert_not_contains "$OUT" "⚠️"; assert_not_contains "$OUT" "v-"
}
test_show_a_workspace_folder_that_is_gone() {
  setup_user
  user_settings WORKSPACE_DIR="$T/gone"
  run configure-user.sh show
  assert_contains "$OUT" "❌ Workspace folder doesn't exist any more: $T/gone
   Fix: Run /flow-configure-user workspace-dir to choose it again."
}
test_secrets_asks_only_the_missing_ones_and_never_shows_a_value() {
  setup_user
  keychain_set closio-agent.gitlab-token v1; keychain_set closio-agent.fe-login-id v2
  dialogs_give "S3cret Value!"
  run configure-user.sh secrets
  assert_rc 0
  assert_eq "$OUT" "Secrets to add: fe-login-password ws1-login-userid ws1-login-password
For each one: a macOS message says which is next (copy it, then click Continue), then a hidden box opens to paste it into.

✅ closio-agent.fe-login-password stored in the Keychain
✅ closio-agent.ws1-login-userid stored in the Keychain
✅ closio-agent.ws1-login-password stored in the Keychain

Secrets: 3 stored, 0 skipped, 0 failed."
  assert_eq "$(cat "$FAKE_KEYCHAIN/closio-agent.ws1-login-password")" "S3cret Value!"
  assert_no_file "$FAKE_KEYCHAIN/closio-agent.jira-api-token"
  assert_eq "$(fake_calls osascript | grep -c 'hidden answer')" "3"
  assert_contains "$(fake_calls osascript | head -1)" "Next: your password for the Closio web app."
  assert_contains "$(fake_calls osascript | sed -n 2p)" "Paste your password for the Closio web app here:"
  assert_not_contains "$(fake_calls)" "S3cret"
  assert_eq "$(grep -r -l "S3cret" "$A" "$HOME" 2>/dev/null)" "" "the value is in no file but the Keychain's"
}
test_secrets_when_every_one_is_stored() {
  setup_user
  store_all_secrets
  run configure-user.sh secrets
  assert_rc 0; assert_eq "$OUT" "✅ All 5 secrets are already stored. To replace one, run /flow-configure-user <item>"
  assert_eq "$(fake_calls osascript)" ""
}
test_secrets_skipped_or_cancelled_change_nothing() {
  setup_user
  store_all_secrets; rm -f "$FAKE_KEYCHAIN/closio-agent.fe-login-id" "$FAKE_KEYCHAIN/closio-agent.ws1-login-userid"
  run configure-user.sh secrets
  assert_rc 0
  assert_contains "$OUT" "⚠️ Skipped closio-agent.fe-login-id
   Tip: Add it later with: /flow-configure-user fe-login-id"
  assert_contains "$OUT" "Secrets: 0 stored, 2 skipped, 0 failed."
  fake_cmd osascript 'case "$*" in *"hidden answer"*) exit 1 ;; *) echo Continue ;; esac'
  run configure-user.sh secrets
  assert_rc 0
  assert_contains "$OUT" "⚠️ Cancelled, so closio-agent.ws1-login-userid was not changed
   Tip: Add it later with: /flow-configure-user ws1-login-userid"
  assert_contains "$OUT" "Secrets: 0 stored, 2 skipped, 0 failed."
  dialogs_give ""
  run configure-user.sh secrets
  assert_contains "$OUT" "⚠️ Nothing entered, so closio-agent.fe-login-id was not changed"
  assert_no_file "$FAKE_KEYCHAIN/closio-agent.fe-login-id"
}
test_secrets_a_value_the_keychain_does_not_take_fails_the_run() {
  setup_user
  store_all_secrets; rm -f "$FAKE_KEYCHAIN/closio-agent.fe-login-id"
  dialogs_give "abc"
  fake_cmd security 'case "$1" in add-generic-password) exit 1 ;; *) exec bash "$TESTS_DIR/fakes/keychain.sh" "$@" ;; esac'
  run configure-user.sh secrets
  assert_rc 1
  assert_contains "$OUT" "❌ Couldn't store closio-agent.fe-login-id in the Keychain
   Fix: Run /flow-configure-user fe-login-id again. If it keeps failing, use the terminal command in the setup guide, section 5.1."
  assert_contains "$OUT" "Secrets: 0 stored, 0 skipped, 1 failed."
}
test_secret_gitlab_token_then_reads_your_username_from_gitlab() {
  setup_user
  fake_gitlab '{"id":7,"username":"jane.doe","name":"Jane"}'
  dialogs_give "glpat-good"
  run configure-user.sh secret gitlab-token
  assert_rc 0
  assert_eq "$OUT" "✅ closio-agent.gitlab-token stored in the Keychain
✅ GitLab token works. GitLab username saved: jane.doe"
  assert_eq "$(settings_line GITLAB_USERNAME)" 'GITLAB_USERNAME="jane.doe"'
  assert_contains "$(fake_requests GL | tail -1)" '"PRIVATE-TOKEN": "glpat-good"'
  assert_contains "$(fake_calls curl)" "https://$GITLAB_HOST/api/v4/user"
  assert_not_contains "$(fake_calls)" "glpat-good" "the token is never on a command line"
}
test_secret_gitlab_token_with_gitlab_unreachable_is_only_a_warning() {
  setup_user
  dialogs_give "glpat-any"
  run configure-user.sh secret gitlab-token
  assert_rc 0
  assert_eq "$OUT" "✅ closio-agent.gitlab-token stored in the Keychain
⚠️ Can't check the token or read your GitLab username: GitLab isn't reachable (VPN off?)
   Tip: Run /flow-vpn connect, then /flow-configure-user gitlab-username. Or type your GitLab username yourself."
}
test_secret_jira_api_token_checks_the_jira_api_backup() {
  setup_user
  start_fake JIRA_API_URL jira
  user_settings JIRA_EMAIL=qa@example.com
  dialogs_give "tok123"
  run configure-user.sh secret jira-api-token
  assert_rc 0
  assert_eq "$OUT" "✅ closio-agent.jira-api-token stored in the Keychain
✅ The Jira API backup works: signed in as Test User (qa@example.com)"
  assert_contains "$(fake_calls osascript | head -1)" "your Atlassian API token, for the Jira API backup"
}
test_secret_cancelled_returns_3() {
  setup_user
  fake_cmd osascript 'case "$*" in *"hidden answer"*) exit 1 ;; *) echo Continue ;; esac'
  run configure-user.sh secret ws1-login-userid
  assert_rc 3; assert_contains "$OUT" "⚠️ Cancelled, so closio-agent.ws1-login-userid was not changed"
}
test_secret_an_unknown_item() {
  setup_user
  run configure-user.sh secret password
  assert_rc 1
  assert_eq "$OUT" "❌ Unknown secret: password
   Fix: Use one of: gitlab-token fe-login-id fe-login-password ws1-login-userid ws1-login-password jira-api-token"
  run configure-user.sh secret
  assert_rc 1; assert_contains "$OUT" "❌ Unknown secret: none"
  KEYCHAIN_PERSONAL_ITEMS="gitlab-token sso-pin" run configure-user.sh secret sso-pin
  assert_rc 1; assert_contains "$OUT" "❌ Unknown secret: sso-pin"
  dialogs_give x
  KEYCHAIN_PERSONAL_ITEMS="sso-pin" run configure-user.sh secrets
  assert_rc 1; assert_contains "$OUT" "Secrets: 0 stored, 0 skipped, 1 failed."
  assert_eq "$(fake_calls osascript)" "" "no dialog for an item it can't describe"
}
test_store_secret_from_stdin() {
  setup_user
  run configure-user.sh store-secret-from-stdin fe-login-password <<< "pa ss"
  assert_rc 0; assert_eq "$OUT" "✅ closio-agent.fe-login-password stored in the Keychain"
  assert_eq "$(cat "$FAKE_KEYCHAIN/closio-agent.fe-login-password")" "pa ss"
  run configure-user.sh store-secret-from-stdin fe-login-id < /dev/null
  assert_rc 3; assert_eq "$OUT" "⚠️ Nothing entered, so closio-agent.fe-login-id was not changed"
  run configure-user.sh store-secret-from-stdin nothing <<< "x"
  assert_rc 1; assert_contains "$OUT" "❌ Unknown secret: nothing"
}
test_gitlab_username_from_token_says_why_it_could_not() {
  setup_user
  run configure-user.sh gitlab-username-from-token
  assert_rc 1; assert_eq "$OUT" "❌ No GitLab token in the Keychain yet
   Fix: Run /flow-configure-user gitlab-token"
  keychain_set closio-agent.gitlab-token glpat-bad
  run configure-user.sh gitlab-username-from-token
  assert_rc 1; assert_contains "$OUT" "⚠️ Can't check the token or read your GitLab username: GitLab isn't reachable (VPN off?)"
  fake_gitlab '{"id":7}'
  run configure-user.sh gitlab-username-from-token
  assert_rc 1; assert_eq "$OUT" "❌ GitLab rejected your token: it may be expired, revoked, or missing the api scope
   Fix: Make a new token (setup guide, section 4.2), then run /flow-configure-user gitlab-token"
  keychain_set closio-agent.gitlab-token glpat-good
  run configure-user.sh gitlab-username-from-token
  assert_rc 1; assert_eq "$OUT" "❌ GitLab answered, but without a username
   Fix: Type your GitLab username: /flow-configure-user gitlab-username"
  assert_no_file "$SETTINGS"
}
test_playwright_runs_the_e2e_setup() {
  setup_user
  run configure-user.sh playwright
  assert_rc 1
  assert_contains "$OUT" "❌ e2e/package.json is missing"
}
