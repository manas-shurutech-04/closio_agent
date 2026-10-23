# scripts/doctor.sh: every setup check of flow-doctor (F1, F2), in its three output formats.
#
# doctor.sh looks at the whole Mac, so each test gives it a PATH it fully controls: $T/bin (the shared stand-ins, the
# tools a test adds, git and jq) + nvm's Node 22 bin folder + $T/sys (links to the Mac's own /usr/bin, /bin, /usr/sbin
# and /sbin tools, minus every tool a stand-in plays). This file adds stand-ins of its own, all in $T/bin: curl (GitLab
# is https only, so the fake HTTP server can't play it; any other http://127.0.0.1 call goes to the real curl, for the
# fake Jira), ps (what Codex's background service runs on) and, in one test, a short sleep. nvm's folder is a temp
# folder without a space (ps lines are split on spaces), removed at the end. scripts/help.sh check (8 s, tested in its
# own file) is replaced in the sandbox by a one-line stand-in that prints $T/help-says; its line 1 is a comment line in
# the real help.sh, so the stand-in adds nothing to help.sh's coverage.

doctor_box() {
  sandbox .agents .claude/skills .claude/settings.json .codex rulesets AGENTS.md
  rm -f "$A/config/repos/"*.yaml
  NS="$(mktemp -d "${TMPDIR:-/tmp}/closio-nvm.XXXXXX")" || fail "no temp folder"
  case "$NS" in *" "*) rm -rf "$NS"; NS="$(mktemp -d /tmp/closio-nvm.XXXXXX)" ;; esac
  trap 'rm -rf "$NS"; sandbox_cleanup' EXIT
  NODE22="$NS/versions/node/v22.14.0/bin"
  mkdir -p "$NODE22" "$T/bin" "$T/sys" "$T/etc/resolver" "$T/work"
  cp "$TESTS_DIR/fakes/nvm/nvm.sh" "$NS/nvm.sh"
  local t gone=""
  ln -s "$(command -v git)" "$T/bin/git"; ln -s "$(command -v jq)" "$T/bin/jq"
  ln -s /usr/bin/* /bin/* /usr/sbin/* /sbin/* "$T/sys/" 2>/dev/null
  for t in "$TESTS_DIR"/fakes/bin/* curl ps git jq; do gone="$gone
$T/sys/${t##*/}"; done
  (IFS='
'; rm -f $gone)   # one rm for all (each process costs time)
  standin security ifconfig nc pgrep pkill killall open osascript sudo dscacheutil networksetup scutil route launchctl xcode-select curl ps
  export PATH="$T/bin:$NODE22:$T/sys" NVM_DIR="$NS"
  export GITLAB_HOST=gitlab.example.test JIRA_API_URL=http://127.0.0.1:1
  export VPN_RESOLVER_FILE="$T/etc/resolver/japfacomfeed.co.id" VPN_OLD_RESOLVER_FILE="$T/etc/resolver/jcvs.japfacomfeed.co.id"
  export VPN_CERT_EXPIRES="$(date -v+400d +%Y-%m-%d)" E2E_DIR="$T/e2e" PLAYWRIGHT_BROWSERS_PATH="$T/pw"
  unset CODEX_SANDBOX CODEX_SANDBOX_NETWORK_DISABLED COLUMNS DOCTOR_FORMAT XDG_CONFIG_HOME USER_SETTINGS_FILE 2>/dev/null
  printf '#!/usr/bin/env bash\ntrap - DEBUG; cat "%s/help-says"\n' "$T" > "$A/scripts/help.sh"
  printf '✅ Every command (19) has its "## Usage" block (what flow-help shows)\n' > "$T/help-says"
  fake_cmd ifconfig 'exit 1'
  printf '000' > "$T/gitlab-code"; printf '200' > "$T/token-code"
  fake_cmd curl 'd="$FAKE_CMDS/.."
case "$*" in
  *"https://gitlab.example.test/users/sign_in"*) cat "$d/gitlab-code" ;;
  *"https://gitlab.example.test/api/v4/user"*) cat > "$d/gitlab-header"; printf "{\"id\":7,\"username\":\"tester\"}\n%s" "$(cat "$d/token-code")" ;;
  *"http://127.0.0.1:"*) exec /usr/bin/curl "$@" ;;
  *) exit 7 ;;
esac'
}
standin() { # <tool>…: a stand-in in $T/bin (logged; what it does: fake_cmd)
  local t
  for t in "$@"; do printf '#!/bin/bash\nexec "%s/fakes/bin/_standin" %s "$@"\n' "$TESTS_DIR" "$t" > "$T/bin/$t"; done
  (cd "$T/bin" && chmod +x "$@")
}
ai_tool() { # <claude|codex> [<folder>]: the AI tool installed in <folder> (default: inside nvm's Node 22)
  local d="${2:-$NODE22}"; mkdir -p "$d"
  printf '#!/bin/bash\nexec "%s/fakes/bin/_standin" %s "$@"\n' "$TESTS_DIR" "$1" > "$d/$1"; chmod +x "$d/$1"
}
gitlab_says() { printf '%s' "$1" > "$T/gitlab-code"; }
# The repo demo-api: registered, cloned at $T/work/demo-api, set up and in Claude Code's folders
demo_repo() { # [<key>=<value>…] for config/repos/demo-api.yaml
  local f="$A/config/repos/demo-api.yaml" kv p="$T/work/demo-api"
  printf 'name: demo-api\ngitlab_url: https://gitlab.example.test/closio/backend/demo-api.git\ngitlab_path: closio/backend/demo-api\nlanguage: node\nnode_version: 22   # from the Dockerfile\ninstall_command: npm ci\nlocal_services: redis, rabbitmq\ndev_base_url: https://dev.example.test\ndev_keys: client-id, client-secret\n' > "$f"
  for kv in "$@"; do grep -v "^${kv%%=*}:" "$f" > "$f.tmp"; printf '%s: %s\n' "${kv%%=*}" "${kv#*=}" >> "$f.tmp"; mv "$f.tmp" "$f"; done
  git init -q -b main "$p" && git -C "$p" remote add origin "https://gitlab.example.test/closio/backend/demo-api.git"
  mkdir -p "$p/node_modules" "$A/local/repos" "$A/.claude"
  printf 'local_path: %s\nsetup_on: 2026-10-20 10:00\nsetup_tests: passed\n' "$p" > "$A/local/repos/demo-api.yaml"
  printf '{"permissions":{"additionalDirectories":["%s"]}}\n' "$p" > "$A/.claude/settings.local.json"
  keychain_set closio-agent.demo-api.client-id.dev x; keychain_set closio-agent.demo-api.client-secret.dev x
}
# Everything set up and working: flow-doctor has nothing to report
all_good() {
  doctor_box
  standin node openfortivpn docker
  fake_cmd node 'echo v22.14.0'; fake_cmd openfortivpn 'echo "1.21.0"'
  ai_tool claude; ai_tool codex
  fake_cmd claude 'echo "2.1.3 (Claude Code)"'; fake_cmd codex 'echo "codex-cli 0.50.0"'
  printf '[user]\n\tname = Test User\n\temail = test@example.com\n' > "$HOME/.gitconfig"
  fake_cmd ifconfig 'exit 0'; gitlab_says 200
  local i; for i in $KEYCHAIN_ITEMS; do keychain_set "closio-agent.$i" "glpat-secret-$i"; done
  start_fake JIRA_API_URL jira; keychain_set closio-agent.jira-api-token tok123
  user_settings JIRA_ACCOUNT_ID=712020:abc GITLAB_USERNAME=tester WORKSPACE_DIR="$T/work" AI_TOOLS="claude-code codex" \
    LOCAL_REDIS_FROM=homebrew JIRA_EMAIL=qa@example.com
  mkdir -p "$A/local/card-sessions"
  shasum -a 256 "$A/.codex/hooks.json" | cut -d' ' -f1 > "$A/local/card-sessions/codex-ran"
  mkdir -p "$E2E_DIR/node_modules/@playwright/test" "$PLAYWRIGHT_BROWSERS_PATH/chromium-1194"; printf '{}' > "$E2E_DIR/node_modules/@playwright/test/package.json"
  demo_repo
  fake_cmd nc 'case " $* " in *" -z "*) exit 0 ;; esac; printf "+PONG\r\n"'
}
KEYCHAIN_ITEMS="gitlab-token fe-login-id fe-login-password ws1-login-userid ws1-login-password"
line_of() { printf '%s\n' "$OUT" | grep -F -- "$1"; }   # the output lines that have <text>

test_everything_set_up_has_nothing_to_report() {
  all_good
  run doctor.sh
  assert_rc 0
  assert_eq "$(printf '%s\n' "$OUT" | tail -1)" "**Result: 0 to fix, 0 to look at.**"
  assert_eq "$(printf '%s\n' "$OUT" | head -3)" "## flow-doctor: checking your setup

### Project"
  assert_not_contains "$OUT" "⚠️"; assert_not_contains "$OUT" "❌"
  local l
  for l in "- ✅ Started in the closio-agent folder" "- ✅ Node v22.14.0 is active" "- ✅ Every flow command has its Claude Code link" \
    "- ✅ Claude Code suggests the commands' options while you type (\`flow-autocomplete\`)" "- ✅ Rules file AGENTS.md is in place" \
    "- ✅ Claude Code 2.1.3, installed inside Node 22" "- ✅ Codex 0.50.0, installed inside Node 22" \
    "- ✅ Codex background service isn't running (it starts with Codex)" "- ✅ openfortivpn 1.21.0" "- ✅ Docker is installed and running" \
    "### VPN and GitLab" "- ✅ VPN is on (openfortivpn) and GitLab is reachable" "- ✅ GitLab token works (signed in as tester)" \
    "### Personal settings · \`local/user-settings.sh\`" "- ✅ Jira account ID: 712020:abc" "- ✅ GitLab username: tester" \
    "- ✅ Workspace folder: $T/work" "- ✅ AI tools: claude-code codex" \
    "- ✅ User memory: none yet (that's normal; add entries with \`/flow-memory add <text>\`)" \
    "- ✅ Every command (19) has its \"## Usage\" block (what flow-help shows)" \
    "- ✅ The card-rules hook adds \`rulesets/card-rules.md\` to a card command (tested just now)" \
    "- ✅ Claude Code: the card hooks are set in \`.claude/settings.json\`" "- ✅ Codex: the card hooks are set in \`.codex/hooks.json\`" \
    "- ✅ Codex: the hooks are trusted and have run" "- ✅ No card in progress (pick one up with \`/flow-start <CARD-KEY>\`)" \
    "- ✅ Playwright is set up (\`e2e/\` packages and the Chromium browser)" \
    "- ✅ Ruleset for backend cards: \`rulesets/story-implementation-workflow.md\`" \
    "- ✅ Ruleset for web-app cards: \`rulesets/frontend-story-workflow.md\`" "- ✅ demo-api: $T/work/demo-api" \
    "- ✅ demo-api: set up on 2026-10-20 10:00 (tests: passed)" "- ✅ Local Redis answers on port 6379 (homebrew)" \
    "- ✅ Local RabbitMQ answers on port 5672" "- ✅ \`closio-agent.gitlab-token\`" "- ✅ \`closio-agent.ws1-login-password\`" \
    "- ✅ The Jira API backup works: signed in as Test User (qa@example.com)"; do
    assert_contains "$OUT" "$l"
  done
  assert_match "$OUT" "- ✅ git [0-9.]+ \(name and email set\)"
  assert_match "$OUT" "- ✅ VPN certificate pin is valid until $VPN_CERT_EXPIRES \((399|400) days left\)"
  # The GitLab token went to curl on stdin, never as an argument, and is never shown
  assert_eq "$(cat "$T/gitlab-header")" "PRIVATE-TOKEN: glpat-secret-gitlab-token"
  assert_not_contains "$(fake_calls)" "glpat-secret"; assert_not_contains "$OUT" "glpat-secret"
  assert_contains "$(fake_calls security)" "security find-generic-password -a $USER -s closio-agent.gitlab-token -w"
}


test_a_bare_mac_gets_every_fix() {
  doctor_box
  rm -f "$T/bin/git" "$A/AGENTS.md" "$A/rulesets/frontend-story-workflow.md"
  rm -rf "$A/.agents"                           # no flow commands: no links to check
  : > "$VPN_OLD_RESOLVER_FILE"
  export VPN_CERT_EXPIRES="$(date -v+10d +%Y-%m-%d)"
  mkdir -p "$A/local/memory" "$A/runs/SCRUM-1" "$A/runs/SCRUM-2" "$A/runs/notes"
  printf -- '- [M1] 2026-10-01 · phases: all · from: - · Keep replies short\n- [M2] 2026-10-02 · phases: plan · from: SCRUM-1 · Ask first\nnot an entry\n' > "$A/local/memory/general.md"
  printf 'card: SCRUM-1\nphase: develop\nstep: 2\nnext: x\nupdated: 2026-10-20\n' > "$A/runs/SCRUM-1/state.md"; : > "$A/runs/SCRUM-1/history.md"
  printf 'card: SCRUM-2\nphase: done\nstep: 1\nnext: x\nupdated: 2026-10-20\n' > "$A/runs/SCRUM-2/state.md"; : > "$A/runs/SCRUM-2/history.md"
  printf '✅ Fine for <repo>\n⚠️ A command lacks its usage\n   Tip: Add it to `docs/commands.md`\n❌ The guide is out of date\n   Fix: Update `docs/user-guide.md`\n   then mirror it to the artifact\n\n' > "$T/help-says"
  run doctor.sh
  assert_rc 1
  assert_contains "$OUT" "### Project

- ✅ Started in the closio-agent folder
- ❌ **Node.js not found**
  - **Fix:** Install nvm and Node 22 (setup guide, section 1), then run \`nvm use v22\` before starting Claude Code or Codex.
- ✅ Every flow command has its Claude Code link"
  assert_contains "$OUT" "- ❌ **The rules file AGENTS.md is missing**
  - **Fix:** Get it back from git: \`git checkout -- AGENTS.md\` in the closio-agent folder."
  assert_contains "$OUT" "### Tools

- ❌ **git is not installed**
  - **Fix:** Run \`xcode-select --install\` in a terminal.
- ❌ **Claude Code is not installed**
  - **Fix:** Run \`nvm use v22\`, then \`npm install -g @anthropic-ai/claude-code\` (setup guide, section 1).
- ⚠️ **Codex is not installed (optional)**
  - **Tip:** If you want it: \`nvm use v22\`, then \`npm install -g @openai/codex\` (setup guide, section 1).
- ❌ **openfortivpn is not installed**
  - **Fix:** Run \`brew install openfortivpn\` (setup guide, section 2.1).
- ✅ Docker isn't installed (only needed if you choose Docker for Redis or RabbitMQ)"
  assert_contains "$OUT" "- ⚠️ **VPN is off. That's fine until you need GitLab**
  - **Tip:** To connect, run \`/flow-vpn connect\` (Codex: \`\$flow-vpn connect\`).
- ✅ No leftover VPN DNS file
- ⚠️ **An old GitLab-only DNS file is still there (no longer needed)**
  - **Tip:** It's removed the next time you run \`/flow-vpn connect\`, or now with: \`sudo rm -f $VPN_OLD_RESOLVER_FILE\`"
  assert_match "$OUT" "- ⚠️ \*\*The VPN certificate pin expires in (9|10) days \($VPN_CERT_EXPIRES\)\*\*"
  assert_contains "$OUT" "  - **Tip:** Ask the IT/infra team for the new certificate's fingerprint, then update \`config/project-settings.sh\`."
  assert_contains "$OUT" "- ❌ **Your personal settings aren't set up yet**
  - **Fix:** Run \`/flow-configure-user\` (Codex: \`\$flow-configure-user\`)."
  assert_contains "$OUT" "- ✅ User memory: 2 entries (see them with \`/flow-memory\`)
- ⚠️ **1 line(s) in your memory files aren't in the memory format, so they're ignored**
  - **Tip:** Run \`/flow-memory\` to see which lines, then fix or remove them."
  # Another script's lines in doctor's look: a <placeholder> outside `code` gets backticks, a line that goes on joins its Fix
  assert_contains "$OUT" "### Commands documented · \`/flow-help\`, user guide, Claude artifact

- ✅ Fine for \`<repo>\`
- ⚠️ **A command lacks its usage**
  - **Tip:** Add it to \`docs/commands.md\`
- ❌ **The guide is out of date**
  - **Fix:** Update \`docs/user-guide.md\` then mirror it to the artifact

### Card hooks"
  assert_contains "$OUT" "### Cards in progress · \`runs/\`, \`/flow-status\`

- ❌ **runs/notes isn't a card key**
  - **Fix:** Rename or remove the folder; card folders are named after the card (e.g. SCRUM-567).
- ✅ Cards in progress: 1 (see them with \`/flow-status\`)"
  assert_contains "$OUT" "- ⚠️ **Playwright isn't set up yet (needed to check web cards)**"
  assert_contains "$OUT" "- ✅ Ruleset for backend cards: \`rulesets/story-implementation-workflow.md\`
- ❌ **The ruleset file \`rulesets/frontend-story-workflow.md\` is missing**
  - **Fix:** It's part of closio-agent: \`git checkout -- rulesets/frontend-story-workflow.md\` (or pull the latest closio-agent).
- ⚠️ **No repos registered yet**
  - **Tip:** Run \`/flow-configure-repo\` with the full path of a local clone."
  assert_contains "$OUT" "- ✅ No cloned repos to set up yet"
  assert_contains "$OUT" "- ❌ **\`closio-agent.gitlab-token\` is missing**
  - **Fix:** Run \`/flow-configure-user gitlab-token\` (Codex: \`\$flow-configure-user gitlab-token\`). It asks for the value in a hidden macOS box.
  - Backup, in your own terminal (not the AI chat): \`security add-generic-password -U -a \"\$USER\" -s \"closio-agent.gitlab-token\" -w\`"
  assert_eq "$(printf '%s\n' "$OUT" | grep -c '^- ❌ \*\*`closio-agent\..*` is missing\*\*$')" "5" "the five Keychain items"
  assert_contains "$OUT" "### Jira API backup · optional, used only when the Jira connector isn't there

- ⚠️ **The Jira API backup isn't set up (optional): no Atlassian email**
  - **Tip:** If the Jira connector is ever missing, the commands switch to it by themselves."
  assert_eq "$(printf '%s\n' "$OUT" | tail -1)" "**Result: 14 to fix, 9 to look at.**"
  assert_eq "$(fake_calls curl)" "curl -s -o /dev/null -w %{http_code} --max-time 8 https://gitlab.example.test/users/sign_in"
}

test_project_and_tool_problems_are_each_reported_with_their_fix() {
  all_good
  fake_cmd node 'echo v18.20.8'
  rm "$A/.claude/skills/flow-vpn"; rm "$A/.claude/skills/flow-status"; ln -s ../../.agents/skills/flow-help "$A/.claude/skills/flow-status"
  rm -rf "$A/.agents/skills/flow-ping"          # its link is left behind: not a command any more, so not looked at
  rm -f "$A/.claude/skills/flow-autocomplete/hooks/register.ts"
  printf '# mine\n' > "$A/CLAUDE.md"; printf '@AGENTS.md\n' > "$A/CLAUDE.local.md"; printf 'x\n' > "$T/CLAUDE.md"
  rm -f "$HOME/.gitconfig"
  ai_tool claude "$T/bin"; ai_tool codex "$T/bin"
  gitlab_says 000                               # openfortivpn is up, but GitLab doesn't answer (no DNS file)
  export VPN_CERT_EXPIRES="$(date -v-2d +%Y-%m-%d)"
  rm -f "$T/bin/docker"
  user_settings AI_TOOLS="claude-code codex" LOCAL_REDIS_FROM=docker
  fake_cmd security 'exit 36'                   # the Keychain can't be read from here
  rm -f "$A/rulesets/card-rules.md" "$A/scripts/card-autosave-hook.sh"
  printf '{"hooks":{}}\n' > "$A/.claude/settings.json"; printf '{"hooks":{}}\n' > "$A/.codex/hooks.json"
  local f
  for f in a-new b-notcloned c-gone d-wrong; do
    printf 'name: %s\ngitlab_url: https://gitlab.example.test/x/%s.git\ngitlab_path: x/%s\nnode_version: 18\ndev_keys: none\ndev_base_url: https://dev.example.test\n' "$f" "$f" "$f" > "$A/config/repos/$f.yaml"
  done
  printf 'local_path:\n' > "$A/local/repos/b-notcloned.yaml"
  printf 'local_path: %s\n' "$T/gone" > "$A/local/repos/c-gone.yaml"
  git init -q "$T/work/d-wrong"; git -C "$T/work/d-wrong" remote add origin "git@gitlab.example.test:x/other.git"
  printf 'local_path: %s\n' "$T/work/d-wrong" > "$A/local/repos/d-wrong.yaml"
  sed -i '' 's/^dev_base_url:.*/dev_base_url:/' "$A/config/repos/demo-api.yaml"
  rm -rf "$NS/versions/node/v22.14.0"; mkdir -p "$NS/versions/node/v18.20.8"
  run_in "$T" bash "$A/scripts/doctor.sh"
  assert_rc 1
  assert_contains "$OUT" "- ❌ **Not started in the closio-agent folder (current folder: $(cd "$T" && pwd))**
  - **Fix:** Quit, open a terminal in $(cd "$A" && pwd -P), run \`nvm use v22\`, then start Claude Code or Codex again."
  assert_contains "$OUT" "- ❌ **Node v18.20.8 is active, but this project needs Node 22**
  - **Fix:** Quit, run \`nvm use v22\`, then start Claude Code or Codex again.
  - In Codex, also run \`codex app-server daemon restart\` after \`nvm use v22\` (setup guide, section 1)."
  assert_contains "$OUT" "- ❌ **Claude Code link missing or wrong for: flow-status flow-vpn**
  - **Fix:** Run \`bash scripts/link-claude-skills.sh\` in the closio-agent folder."
  assert_contains "$OUT" "- ❌ **The suggestions while you type are missing (\`.claude/skills/flow-autocomplete/\`)**
  - **Fix:** Get them back from git: \`git checkout -- .claude/skills/flow-autocomplete\` in the closio-agent folder, then start Claude Code again."
  assert_contains "$OUT" "- ❌ **A CLAUDE.md file stops Claude Code from reading AGENTS.md: \`$(cd "$A" && pwd -P)/CLAUDE.md\` \`$(cd "$T" && pwd -P)/CLAUDE.md\`**
  - **Fix:** Remove that file, or add the line \`@AGENTS.md\` to it so it includes the rules."
  assert_match "$OUT" "- ❌ \*\*git [0-9.]+ is installed, but your name or email isn't set\*\*"
  assert_contains "$OUT" "  - **Fix:** Run: \`git config --global user.name \"Your Name\"\`
  - and: \`git config --global user.email \"you@company.com\"\`"
  assert_contains "$OUT" "- ❌ **Claude Code has a copy outside Node 22: $T/bin/claude**
  - **Fix:** Remove it (if it came from Homebrew: \`brew uninstall --cask claude-code\`), then \`nvm use v22\` and \`npm install -g @anthropic-ai/claude-code\`."
  assert_contains "$OUT" "- ❌ **Codex has a copy outside Node 22: $T/bin/codex**"
  assert_not_contains "$OUT" "Codex background service"
  assert_contains "$OUT" "- ❌ **Docker is not installed, but you chose Docker for Redis or RabbitMQ**
  - **Fix:** Install Docker Desktop from docker.com, or choose Homebrew instead: \`/flow-setup-repo <repo> services\`"
  assert_contains "$OUT" "- ❌ **VPN is on (openfortivpn), but the VPN DNS file is missing, so GitLab's name doesn't resolve**
  - **Fix:** Run \`/flow-vpn connect\` (Codex: \`\$flow-vpn connect\`). It adds the file."
  assert_contains "$OUT" "- ❌ **The VPN certificate pin expired on $VPN_CERT_EXPIRES, so the VPN won't connect**
  - **Fix:** Ask the IT/infra team to confirm the new certificate, then put its fingerprint in \`config/project-settings.sh\` (\`VPN_CERT_SHA256\` and \`VPN_CERT_EXPIRES\`)."
  assert_contains "$OUT" "- ❌ **Jira account ID is not set**
  - **Fix:** Run \`/flow-configure-user jira-account-id\`
- ❌ **GitLab username is not set**
  - **Fix:** Run \`/flow-configure-user gitlab-username\`
- ❌ **Workspace folder is not set**
  - **Fix:** Run \`/flow-configure-user workspace-dir\`
- ✅ AI tools: claude-code codex"
  assert_contains "$OUT" "- ❌ **The card-rules hook doesn't add the card rules**
  - **Fix:** Check that \`rulesets/card-rules.md\` and \`scripts/card-rules-hook.sh\` exist (\`git status\`; restore them with \`git checkout -- rulesets/card-rules.md scripts/card-rules-hook.sh\`), then run \`/flow-doctor\` again.
- ❌ **The auto-save hook is missing**
  - **Fix:** Restore it: \`git checkout -- scripts/card-autosave-hook.sh\`, then run \`/flow-doctor\` again.
- ❌ **Claude Code: the card hooks aren't all set in \`.claude/settings.json\`**
  - **Fix:** Restore the file's \`hooks\` block: \`git checkout -- .claude/settings.json\`, then start Claude Code again in this folder.
- ❌ **Codex: the card hooks aren't all set in \`.codex/hooks.json\`**
  - **Fix:** Restore it: \`git checkout -- .codex/hooks.json\`, start Codex again in this folder and approve the hooks when it asks."
  assert_contains "$OUT" "- ⚠️ **a-new isn't set up on this Mac**
  - **Tip:** Run \`/flow-configure-repo a-new\` (only if you work on it).
- ⚠️ **b-notcloned isn't cloned on this Mac yet**
  - **Tip:** Cloning is manual: on the VPN, \`git clone https://gitlab.example.test/x/b-notcloned.git <your workspace folder>/b-notcloned\`, then run \`/flow-configure-repo b-notcloned path <that folder>\`."
  assert_contains "$OUT" "- ❌ **c-gone: clone not found at $T/gone**
  - **Fix:** Run \`/flow-configure-repo c-gone\` and give the new path."
  assert_contains "$OUT" "- ❌ **d-wrong: $T/work/d-wrong is a clone of 'x/other', not 'x/d-wrong'**
  - **Fix:** Run \`/flow-configure-repo d-wrong\` and give the right clone."
  assert_contains "$OUT" "- ✅ demo-api: $T/work/demo-api
- ⚠️ **Node 22 (what demo-api is built for) isn't installed in nvm**
  - **Tip:** Run: \`nvm install 22\`
- ⚠️ **demo-api has no dev address yet (needed for the dev checks of \`/flow-finish\`)**
  - **Tip:** Run \`/flow-setup-repo demo-api dev-address\` (Codex: \`\$flow-setup-repo demo-api dev-address\`).
- ⚠️ **\`closio-agent.demo-api.client-id.dev\` is missing (needed to test demo-api on dev)**
  - **Tip:** Run \`/flow-configure-repo demo-api\` (it asks for the key in a hidden macOS box).
- ⚠️ **\`closio-agent.demo-api.client-secret.dev\` is missing (needed to test demo-api on dev)**"
  assert_not_contains "$OUT" "Node 18 (what"
  assert_contains "$OUT" "- ⚠️ **Couldn't read the Keychain from here to check \`closio-agent.gitlab-token\`**
  - **Tip:** Run \`bash scripts/doctor.sh\` in a normal terminal."
  assert_eq "$(printf '%s\n' "$OUT" | grep -c "Couldn't read the Keychain")" "5"
}

test_codex_only_users_and_what_is_not_running() {
  all_good
  rm -f "$NODE22/claude"; fake_cmd codex 'echo "no version here"'
  fake_cmd pgrep 'echo 4242; echo 4343'
  fake_cmd ps 'case "$3" in
  4242) echo "  PID TT STAT TIME COMMAND"; echo "4242 ?? S 0:01.00 node codex app-server --listen PATH=/u/.nvm/versions/node/v20.11.1/bin:/usr/bin HOME=/u" ;;
  4343) echo "4343 ?? S 0:01.00 node codex PATH=/usr/bin" ;;
esac'
  fake_cmd docker 'exit 1'
  fake_cmd ifconfig 'exit 1'; rm -f "$FAKE_KEYCHAIN/closio-agent.gitlab-token"
  user_settings JIRA_ACCOUNT_ID=a GITLAB_USERNAME=b WORKSPACE_DIR="$T/gone" AI_TOOLS=codex LOCAL_REDIS_FROM=docker JIRA_EMAIL=qa@example.com
  mkdir -p "$A/local/memory"; printf -- '- [M1] 2026-10-01 · phases: all · from: - · Keep replies short\n' > "$A/local/memory/general.md"
  rm -f "$A/local/card-sessions/codex-ran"
  rm -rf "$T/work/demo-api/node_modules"; printf '{}\n' > "$A/.claude/settings.local.json"
  printf 'name: b-api\ngitlab_url: u\ngitlab_path: x/b-api\nlocal_services: bullmq\nnode_version: none\ndev_base_url: d\n' > "$A/config/repos/b-api.yaml"
  git init -q "$T/work/b-api"; git -C "$T/work/b-api" remote add origin "https://gitlab.example.test/x/b-api.git"
  printf 'local_path: %s\n' "$T/work/b-api" > "$A/local/repos/b-api.yaml"
  fake_cmd nc 'exit 1'
  run doctor.sh
  assert_rc 1
  assert_contains "$OUT" "- ✅ Claude Code not installed (you don't use it)
- ✅ Codex (version unknown), installed inside Node 22
- ❌ **Codex background service runs on Node v20.11.1, not Node 22**
  - **Fix:** Close Codex. In a terminal run \`nvm use v22\`, then \`codex app-server daemon restart\`, then start Codex again (setup guide, section 1)."
  assert_contains "$(fake_calls pgrep)" "pgrep -f codex app-server --listen"
  assert_eq "$(fake_calls ps)" "ps eww -p 4242
ps eww -p 4343"
  assert_contains "$OUT" "- ⚠️ **Docker is installed but not running, and you use it for Redis or RabbitMQ**
  - **Tip:** Open Docker Desktop before running backend tests."
  assert_contains "$OUT" "- ✅ VPN is on (another VPN client, e.g. the FortiClient app) and GitLab is reachable
- ⚠️ **Can't check the GitLab token: it isn't in the Keychain yet**
  - **Tip:** See the Keychain section below."
  assert_contains "$OUT" "- ❌ **Workspace folder doesn't exist: $T/gone**
  - **Fix:** Create it again, or choose another with \`/flow-configure-user workspace-dir\`"
  assert_contains "$OUT" "- ✅ User memory: 1 entry (see them with \`/flow-memory\`)"
  assert_contains "$OUT" "- ⚠️ **Codex hasn't run the card hooks yet: they wait for your OK once**
  - **Tip:** (1) Start Codex in the closio-agent folder (after \`nvm use v22\`); it says \"… hooks need review before they can run\". (2) Type \`/hooks\`."
  assert_contains "$OUT" "### Repo setup on this Mac · \`/flow-setup-repo\`

- ⚠️ **demo-api: its packages aren't installed any more**
  - **Tip:** Run \`/flow-setup-repo demo-api\`
- ⚠️ **Cloned but not set up yet: b-api**
  - **Tip:** Run \`/flow-setup-repo <repo>\`, or \`/flow-setup-repo all\`.
- ⚠️ **Local Redis doesn't answer on port 6379 (needed by: demo-api)**
  - **Tip:** Run \`/flow-setup-repo demo-api\` (it finds or starts it).
- ⚠️ **Local RabbitMQ doesn't answer on port 5672 (needed by: demo-api)**
  - **Tip:** Run \`/flow-setup-repo demo-api\` (it finds or starts it).

### Keychain"
  assert_contains "$(fake_calls nc)" "nc -G 2 -w 2 127.0.0.1 6379"
  assert_contains "$(fake_calls nc)" "nc -z -G 2 127.0.0.1 5672"
  assert_contains "$OUT" "- ❌ **\`closio-agent.gitlab-token\` is missing**"
}

test_claude_code_only_users_with_a_refused_gitlab_token() {
  all_good
  rm -f "$NODE22/codex"; fake_cmd docker 'exit 1'
  user_settings JIRA_ACCOUNT_ID=a GITLAB_USERNAME=b WORKSPACE_DIR="$T/work" AI_TOOLS=claude-code LOCAL_REDIS_FROM=homebrew JIRA_EMAIL=qa@example.com
  keychain_set closio-agent.gitlab-token glpat-old; printf '401' > "$T/token-code"
  printf '{}\n' > "$A/.claude/settings.local.json"
  run doctor.sh
  assert_rc 1
  assert_contains "$OUT" "- ✅ Codex not installed (you don't use it)
- ✅ openfortivpn 1.21.0
- ✅ Docker is installed (not running; you don't use it for Redis or RabbitMQ)"
  assert_contains "$OUT" "- ❌ **GitLab rejected your token (HTTP 401): it may be expired or revoked**
  - **Fix:** Make a new token (setup guide, section 4.2), then store it again with the command in section 5.1."
  assert_contains "$OUT" "- ⚠️ **demo-api: Claude Code can't use its folder yet**
  - **Tip:** Run \`/flow-setup-repo demo-api\` (it adds the folder to your \`.claude/settings.local.json\`)."
  assert_not_contains "$OUT" "Codex: the hooks"; assert_not_contains "$OUT" "glpat-old"
  assert_eq "$(printf '%s\n' "$OUT" | tail -1)" "**Result: 1 to fix, 1 to look at.**"
}

test_inside_codex_sandbox_what_cannot_be_seen_is_a_warning() {
  all_good
  export CODEX_SANDBOX=seatbelt CODEX_SANDBOX_NETWORK_DISABLED=1 DOCTOR_FORMAT=html COLUMNS=wide VPN_CERT_EXPIRES=soon
  printf 'an old hash\n' > "$A/local/card-sessions/codex-ran"
  run doctor.sh
  assert_eq "$(printf '%s\n' "$OUT" | head -1)" "## flow-doctor: checking your setup" "an unknown format is markdown"
  assert_contains "$OUT" "- ⚠️ **Couldn't check which Node Codex's background service uses from inside Codex's sandbox**
  - **Tip:** Run \`bash scripts/doctor.sh\` in a normal terminal to check it."
  assert_contains "$OUT" "### VPN and GitLab

- ⚠️ **Can't check the VPN and GitLab from inside Codex's sandbox (network is blocked here)**
  - **Tip:** Approve running flow-doctor with network access, or run \`bash scripts/doctor.sh\` in a normal terminal.

### Personal settings"
  assert_contains "$OUT" "- ⚠️ **Codex's hook file changed since Codex last ran it: approve the hooks again**"
  assert_contains "$OUT" "- ⚠️ **Can't check the local Redis and RabbitMQ from inside Codex's sandbox**
  - **Tip:** Run \`bash scripts/doctor.sh\` in a normal terminal."
  assert_eq "$(fake_calls curl | grep -c gitlab)" "0" "GitLab isn't called"
  assert_eq "$(fake_calls nc)" "" "the ports aren't checked"
}

test_codex_service_on_node_22_vpn_up_with_its_dns_file_and_docker_stuck() {
  all_good
  fake_cmd pgrep 'echo 4242'
  fake_cmd ps "echo \"4242 ?? S 0:01.00 node codex PATH=$NODE22:/usr/bin\""
  gitlab_says 000; : > "$VPN_RESOLVER_FILE"
  fake_cmd docker 'exec /bin/sleep 30'          # docker info never answers: stopped after 10 waits
  printf '#!/bin/bash\nexec /bin/sleep 0.05\n' > "$T/bin/sleep"; chmod +x "$T/bin/sleep"
  run doctor.sh
  assert_rc 1
  assert_contains "$OUT" "- ✅ Codex background service runs on Node 22"
  assert_contains "$OUT" "- ⚠️ **Docker Desktop doesn't answer (it may be starting, or stuck)**
  - **Tip:** Wait a minute; if it stays like this, quit Docker Desktop and open it again."
  assert_contains "$OUT" "- ❌ **VPN is on (openfortivpn), but GitLab doesn't answer (HTTP 000)**
  - **Fix:** Run \`/flow-vpn disconnect\`, then \`/flow-vpn connect\`. If it still fails, see the setup guide, section 2.6."
}

test_codex_service_unknown_a_leftover_dns_file_and_no_jq() {
  all_good
  fake_cmd pgrep 'echo 4242'; fake_cmd ps 'echo "4242 ?? S 0:01.00 node codex"'
  fake_cmd ifconfig 'exit 1'; gitlab_says 000; : > "$VPN_RESOLVER_FILE"
  rm -f "$T/bin/jq"
  run doctor.sh
  assert_rc 1
  assert_contains "$OUT" "- ⚠️ **Couldn't check which Node Codex's background service uses from here**
  - **Tip:** Run \`bash scripts/doctor.sh\` in a normal terminal to check it."
  assert_contains "$OUT" "- ⚠️ **VPN is off. That's fine until you need GitLab**
  - **Tip:** To connect, run \`/flow-vpn connect\` (Codex: \`\$flow-vpn connect\`).
- ❌ **A leftover VPN DNS file is still there; it stops the next VPN connection**
  - **Fix:** Run \`/flow-vpn connect\` (it removes the file first), or: \`sudo rm -f $VPN_RESOLVER_FILE\`"
  assert_contains "$OUT" "### Card hooks · the card rules on every prompt about a card and after a summary, the card's folder saved after every reply

- ❌ **jq isn't installed, so the card hooks can't run**
  - **Fix:** Install it: \`brew install jq\`, then run \`/flow-doctor\` again.
- ❌ **Claude Code: the card hooks aren't all set in \`.claude/settings.json\`**"
}

test_terminal_format_has_colors_and_indents_and_wraps_at_forty_columns_at_least() {
  doctor_box
  export DOCTOR_FORMAT=terminal COLUMNS=30
  run doctor.sh
  assert_rc 1
  local E=$'\033'
  assert_eq "$(printf '%s\n' "$OUT" | head -3)" "${E}[1;36mflow-doctor — checking your setup${E}[0m

${E}[1;36mPROJECT${E}[0m"
  assert_contains "$OUT" "${E}[1;36mPERSONAL SETTINGS${E}[0m  ${E}[2mlocal/user-settings.sh${E}[0m"
  assert_contains "$OUT" "  ✅ Started in the closio-agent folder${E}[0m"
  assert_contains "$OUT" "  ❌ ${E}[1;31mNode.js not found${E}[0m
     ${E}[1;31mFix:${E}[0m Install nvm and Node 22${E}[0m
          (setup guide, section 1),${E}[0m
          then run ${E}[0m${E}[33mnvm use v22${E}[0m before${E}[0m
          starting Claude Code or Codex.${E}[0m"
  assert_contains "$OUT" "  ⚠️ ${E}[1;33mVPN is off. That's fine until you${E}[0m
     ${E}[1;33mneed GitLab${E}[0m
     ${E}[1;33mTip:${E}[0m To connect, run ${E}[0m${E}[33m/flow-vpn${E}[0m
          ${E}[33mconnect${E}[0m (Codex: ${E}[0m${E}[33m\$flow-vpn${E}[0m"
  # A fail's third line, and a \`command\` that goes on over two lines stays yellow
  assert_contains "$OUT" "          box.${E}[0m
          Backup, in your own terminal${E}[0m
          (not the AI chat): ${E}[0m${E}[33msecurity${E}[0m
          ${E}[33madd-generic-password -U -a${E}[0m"
  assert_eq "$(printf '%s\n' "$OUT" | tail -1)" "${E}[1;31mResult: 10 to fix, 5 to look at.${E}[0m"
  # Every line that goes on fits in 40 columns (colors don't count)
  assert_eq "$(printf '%s\n' "$OUT" | grep '^     ' | sed "s/${E}\[[0-9;]*m//g" | awk 'length($0) > 40' | wc -l | tr -d ' ')" "0"
}

test_plain_format_wraps_at_a_hundred_columns_at_most() {
  all_good
  export DOCTOR_FORMAT=plain COLUMNS=500
  run doctor.sh
  assert_rc 0
  assert_eq "$(printf '%s\n' "$OUT" | head -3)" "flow-doctor — checking your setup

Project"
  assert_contains "$OUT" "Personal settings (local/user-settings.sh)
✅ Jira account ID: 712020:abc"
  # fold counts the backticks it gets before they're dropped, so this line breaks a word early
  assert_contains "$OUT" "✅ Claude Code: the card hooks are set in .claude/settings.json (the card rules on each prompt
   and after a summary, the auto-save after each reply)"
  assert_eq "$(printf '%s\n' "$OUT" | tail -1)" "Result: 0 to fix, 0 to look at."
  assert_not_contains "$OUT" '`'; assert_not_contains "$OUT" $'\033'
}

test_in_a_terminal_it_picks_the_terminal_format_by_itself() {
  doctor_box
  unset NO_COLOR
  local o
  o="$(cd "$A" && script -q /dev/null bash scripts/doctor.sh < /dev/null 2>&1 | tr -d '\r')"
  assert_contains "$o" $'\033[1;36mflow-doctor — checking your setup\033[0m'
  assert_contains "$o" $'\033[1;36mPROJECT\033[0m'
  assert_contains "$o" $'  ❌ \033[1;31mNode.js not found\033[0m'
}
