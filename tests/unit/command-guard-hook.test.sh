# scripts/command-guard-hook.sh: the commands the AI may never run, a plain git push only for this folder, and the
# session's first push, migration, seeder and test-data run asked in the tool itself (Claude Code: its Allow box;
# Codex: a macOS dialog, here the osascript stand-in).

# Runs the guard as <tool> for <event>, the command <cmd>, in <cwd> (default: the sandbox's closio-agent folder)
guard() { # <tool> <event> <cmd> [<cwd>] [<session>]
  local in
  in="$(jq -n --arg e "$2" --arg c "$3" --arg w "${4:-$AP}" --arg s "${5-s1}" \
    '{hook_event_name: $e, session_id: $s, cwd: $w, tool_name: "Bash", tool_input: {command: $c}}')"
  OUT="$(cd "$A" && printf '%s' "$in" | bash scripts/command-guard-hook.sh "$1" 2>&1)"; RC=$?
}
decision() { printf '%s' "$OUT" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null; }
reason() { printf '%s' "$OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null; }
message() { printf '%s' "$OUT" | jq -r '.systemMessage // empty' 2>/dev/null; }   # the warning shown to the user (D95)
# The command runs, with only a warning: no decision, and the warning says <text>
warned() { # <text> [what]
  assert_eq "$(decision)" "" "${2:-no decision}"
  assert_contains "$(message)" "⚠️ closio-agent: $1" "${2:-the warning}"
}
setup() { sandbox; AP="$(cd "$A" && pwd -P)"; G="$HOME/.closio-agent/guard"; }
dialog() { # <osascript output>: what the Codex dialog answers
  printf '%s\n' "$1" > "$T/dialog"
  fake_cmd osascript 'printf "%s\n" "$*" >> "'"$T"'/dialog-shown"; cat "'"$T"'/dialog"'
  export OSASCRIPT_BIN="$TESTS_DIR/fakes/bin/osascript"
}

test_everyday_commands_get_no_answer() {
  setup
  local c
  for c in 'git status' 'ls -la' 'bash scripts/ship.sh nodejs-ws2closio status' 'bash scripts/repo-run.sh ws2 test' \
    'bash scripts/db-run.sh ws2 query runs/SCRUM-1/data/check.sql' 'git stash' 'git branch -d old' 'git checkout -b feature' \
    'rm -f a.txt' 'chmod +x a.sh' 'docker ps' 'git remote -v' 'npm run migration:generate -- --name add-x' 'echo "format permission"'; do
    guard claude PreToolUse "$c"
    assert_rc 0; assert_eq "$OUT" "" "$c"
  done
}
test_commands_that_throw_work_away_are_never_run() {
  setup
  local c
  while IFS='|' read -r c why; do
    guard claude PreToolUse "$c"
    assert_rc 0; assert_eq "$(decision)" "deny" "$c"
    assert_contains "$(reason)" "$why" "$c"
  done <<'EOF'
git reset --hard HEAD~1|git reset --hard
git -C "/repos/a b" reset --hard origin/develop|git reset --hard
cd /repos/x && git clean -fd|git clean
git checkout -- .|git checkout --
git checkout main -- src/app.js|git checkout --
git checkout .|git checkout .
git restore --staged a.js|git restore
git branch -D feature|git branch -D
git stash drop|git stash drop
git stash clear|git stash drop / clear
git remote add other https://example.test/x.git|remotes
git remote set-url origin https://example.test/x.git|remotes
git push --force origin main|a forced or deleting push
git push origin main --force-with-lease|a forced or deleting push
git push -f|a forced or deleting push
git push origin --delete old-branch|a forced or deleting push
git push origin +main|+ or : refspec
git push origin :old-branch|+ or : refspec
npm run migrate|bash scripts/repo-run.sh <repo> migrate|seed confirmed
npm run seed:undo|npm run migrate / seed
npx sequelize-cli db:migrate|sequelize directly
npx --yes sequelize db:seed:all|sequelize directly
rm -rf /tmp/x|a recursive rm
rm -r build|a recursive rm
rm --recursive build|a recursive rm
sudo rm /etc/hosts|sudo
chmod -R 777 .|chmod -R
chown -R me .|chown -R
docker system prune -a|Docker's data
docker volume rm redis-data|Docker's data
dropdb closio|dropdb / psql
psql -h localhost closio|dropdb / psql
touch ~/.closio-agent/guard/s1/push|the guard's own records
EOF
}
test_the_reason_says_what_to_do_instead() {
  setup
  guard claude PreToolUse 'git reset --hard'
  assert_contains "$(reason)" "The guard never lets the AI run this"
  assert_contains "$(reason)" "ask the user to run it themselves in a terminal"
}
test_wrapped_and_chained_commands_are_checked_too() {
  setup
  local c
  for c in 'bash -c "git reset --hard"' "sh -c 'rm -rf build'" 'ls && git clean -f' 'true; sudo ls' 'x=$(git stash drop)' \
    'FOO=1 git reset --hard' 'env A=1 rm -rf x' 'git status | xargs rm -rf'; do
    guard claude PreToolUse "$c"
    assert_eq "$(decision)" "deny" "$c"
  done
}
test_text_in_a_heredoc_or_a_message_is_not_a_command() {
  setup
  guard claude PreToolUse "cat > notes.md <<'EOF'
git reset --hard
rm -rf /
EOF
echo done"
  assert_eq "$OUT" "" "a heredoc's text"
  guard claude PreToolUse 'git commit -m "docs: never git reset --hard or rm -rf"'
  assert_eq "$OUT" "" "a commit message"
  guard claude PreToolUse "python3 - <<-PY
	import os  # sudo rm -rf
	PY"
  assert_eq "$OUT" "" "an indented heredoc"
}
test_a_plain_push_works_only_for_this_folder() {
  setup
  guard claude PreToolUse 'git push origin main'
  warned "pushing this folder (closio-agent) to GitHub without asking (allowed for this folder): git push origin main" "here"
  guard claude PreToolUse 'git push -u origin HEAD:refs/heads/x' "$AP/scripts"
  warned "pushing this folder (closio-agent) to GitHub" "from a folder inside"
  guard claude PreToolUse "cd \"$AP\" && git push origin main" /tmp
  assert_eq "$(decision)" "deny" "cd here but started elsewhere"
  guard claude PreToolUse "cd \"$AP\" && git push origin main"
  warned "pushing this folder" "cd here"
  guard claude PreToolUse "git -C \"$AP\" push"
  warned "pushing this folder" "-C here"
  guard claude PreToolUse 'git push' "$T"
  assert_eq "$(decision)" "deny" "another folder"
  assert_contains "$(reason)" "bash scripts/ship.sh <repo> push"
  guard claude PreToolUse 'cd /repos/ws2 && git push'
  assert_eq "$(decision)" "deny" "cd elsewhere"
  guard claude PreToolUse 'git -C /repos/ws2 push origin x'
  assert_eq "$(decision)" "deny" "-C elsewhere"
  guard claude PreToolUse 'git push' "$T/missing folder"
  assert_eq "$(decision)" "deny" "a folder that isn't there"
}

test_claude_code_asks_once_per_session_for_each_kind() {
  setup
  local c k
  for c in 'bash scripts/ship.sh nodejs-ws2closio push SCRUM-1|push' 'bash scripts/ship.sh "nodejs-ws1closio" push-update|push' \
    'bash scripts/repo-run.sh nodejs-ws2closio migrate confirmed|migration' 'bash scripts/repo-run.sh nodejs-ws2closio seed confirmed|seeder' \
    'bash scripts/db-run.sh nodejs-ws2closio run runs/SCRUM-1/data/1.sql confirmed|test-data run'; do
    k="${c##*|}"; c="${c%|*}"
    guard claude PreToolUse "$c" "" "fresh-$RANDOM"
    assert_eq "$(decision)" "ask" "$c"
    assert_contains "$(reason)" "the first $k of this session"
  done
  guard claude PreToolUse 'bash scripts/ship.sh ws2 push SCRUM-1'
  assert_eq "$(decision)" "ask" "before the OK"
  guard claude PostToolUse 'bash scripts/ship.sh ws2 push SCRUM-1'
  assert_rc 0; assert_eq "$OUT" ""; assert_file "$G/s1/push"
  guard claude PreToolUse 'bash scripts/ship.sh ws1 push-update'
  warned "the session's next push runs without asking (you allowed it for this session): bash scripts/ship.sh ws1 push-update" "the session's next push runs, with a warning"
  guard claude PreToolUse 'bash scripts/repo-run.sh ws2 migrate confirmed'
  assert_eq "$(decision)" "ask" "another kind still asks"
  guard claude PreToolUse 'bash scripts/ship.sh ws2 push SCRUM-1' "" s2
  assert_eq "$(decision)" "ask" "another session asks again"
}
test_a_command_that_failed_after_the_ok_still_keeps_it() {
  setup
  guard claude PostToolUseFailure 'bash scripts/db-run.sh ws2 run runs/SCRUM-1/data/1.sql confirmed'
  assert_file "$G/s1/test-data"
  guard claude PreToolUse 'bash scripts/db-run.sh ws2 run runs/SCRUM-1/data/2.sql confirmed'
  warned "the session's next test-data run runs without asking"
}
test_two_kinds_in_one_command_are_asked_together() {
  setup
  guard claude PreToolUse 'bash scripts/repo-run.sh ws2 migrate confirmed && bash scripts/repo-run.sh ws2 seed confirmed'
  assert_eq "$(decision)" "ask"; assert_contains "$(reason)" "the first migration, seeder of this session"
  guard claude PostToolUse 'bash scripts/repo-run.sh ws2 migrate confirmed && bash scripts/repo-run.sh ws2 seed confirmed'
  assert_file "$G/s1/migration"; assert_file "$G/s1/seeder"
  guard claude PreToolUse 'bash scripts/repo-run.sh ws2 seed confirmed'
  warned "the session's next seeder runs without asking"
}
test_only_a_command_of_those_kinds_keeps_an_ok() {
  setup
  guard claude PostToolUse 'bash scripts/ship.sh ws2 status'
  assert_no_file "$G/s1"
  guard claude PostToolUse 'bash scripts/ship.sh ws2 push SCRUM-1' "" ""
  assert_no_file "$G/s1"; assert_eq "$(ls "$G" 2>/dev/null)" "" "no session id: nothing kept"
}
test_old_oks_are_removed_after_seven_days() {
  setup
  mkdir -p "$G/old-session" && : > "$G/old-session/push" && touch -t 202001010000 "$G/old-session"
  guard claude PostToolUse 'bash scripts/ship.sh ws2 push SCRUM-1'
  assert_no_file "$G/old-session"; assert_file "$G/s1/push"
}

test_codex_asks_in_a_macos_dialog_and_keeps_an_allow() {
  setup
  dialog "button returned:Allow for this session, gave up:false"
  guard codex PreToolUse 'bash scripts/ship.sh nodejs-ws2closio push SCRUM-1'
  assert_rc 0; assert_eq "$OUT" "" "allowed: no answer, the command runs"
  assert_file "$G/s1/push"
  assert_contains "$(cat "$T/dialog-shown")" "closio-agent wants to run the first push of this Codex session"
  assert_contains "$(cat "$T/dialog-shown")" "bash scripts/ship.sh nodejs-ws2closio push SCRUM-1"
  rm -f "$T/dialog-shown"
  guard codex PreToolUse 'bash scripts/ship.sh nodejs-ws1closio push-update'
  warned "the session's next push runs without asking"; assert_no_file "$T/dialog-shown"
}
test_codex_deny_or_no_answer_stops_the_command() {
  setup
  dialog "button returned:Deny, gave up:false"
  guard codex PreToolUse 'bash scripts/repo-run.sh ws2 migrate confirmed'
  assert_eq "$(decision)" "deny"; assert_contains "$(reason)" "didn't allow the first migration of this session"
  assert_no_file "$G/s1/migration"
  dialog "button returned:, gave up:true"
  guard codex PreToolUse 'bash scripts/repo-run.sh ws2 migrate confirmed'
  assert_eq "$(decision)" "deny"; assert_no_file "$G/s1/migration"
  fake_cmd osascript 'exit 1'
  guard codex PreToolUse 'bash scripts/db-run.sh ws2 run x.sql confirmed'
  assert_eq "$(decision)" "deny" "the dialog closed or failed"
}
test_codex_blocks_the_same_commands() {
  setup
  guard codex PreToolUse 'git -C /repos/ws2 reset --hard'
  assert_eq "$(decision)" "deny"
  guard codex PreToolUse 'git push origin main'
  warned "pushing this folder (closio-agent) to GitHub"
}

test_anything_else_is_left_alone() {
  setup
  OUT="$(cd "$A" && printf '%s' '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Read","tool_input":{"file_path":"x"}}' | bash scripts/command-guard-hook.sh claude)"
  assert_eq "$OUT" "" "another tool"
  OUT="$(cd "$A" && printf 'not json' | bash scripts/command-guard-hook.sh claude)"; RC=$?
  assert_rc 0; assert_eq "$OUT" "" "input that isn't JSON"
  guard claude Stop 'git reset --hard'
  assert_eq "$OUT" "" "another event"
  OUT="$(cd "$A" && printf '%s' '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Bash","tool_input":{"command":["git","reset","--hard"]}}' | bash scripts/command-guard-hook.sh codex)"
  assert_eq "$(decision)" "deny" "a command given as a list"
}

# 3. The warnings for a major step that runs without a question (D95)
test_a_jira_change_and_a_merge_request_write_get_a_warning() {
  setup
  local c
  for c in 'bash scripts/jira-api.sh move SCRUM-1 "Ready for Test"' 'bash scripts/jira-api.sh comment SCRUM-1 runs/SCRUM-1/deployment.md' \
    'bash scripts/jira-api.sh edit-comment SCRUM-1 10001 runs/SCRUM-1/deployment.md' 'bash scripts/jira-api.sh assign SCRUM-1' \
    'bash scripts/jira-api.sh sprint SCRUM-1'; do
    guard claude PreToolUse "$c"
    warned "changing the Jira card without asking (pre-approved): $c" "$c"
  done
  for c in 'bash scripts/gitlab-mr.sh nodejs-ws2closio reply SCRUM-1/x 12 runs/SCRUM-1/review-reply.md' \
    'bash scripts/gitlab-mr.sh nodejs-ws2closio describe SCRUM-1/x runs/SCRUM-1/mr-nodejs-ws2closio.md --reviewers a'; do
    guard codex PreToolUse "$c"
    warned "writing on the merge request without asking (after your yes): $c" "$c"
  done
}
test_reading_jira_or_the_merge_request_gets_no_warning() {
  setup
  local c
  for c in 'bash scripts/jira-api.sh get SCRUM-1' 'bash scripts/jira-api.sh comments SCRUM-1' 'bash scripts/gitlab-mr.sh ws2 status SCRUM-1/x' \
    'bash scripts/gitlab-mr.sh ws2 comments SCRUM-1/x'; do
    guard claude PreToolUse "$c"
    assert_eq "$OUT" "" "$c"
  done
}
test_the_jira_connector_s_changes_get_a_warning_in_claude_code() {
  setup
  local t
  for t in "transitionJiraIssue|moving the Jira card SCRUM-7" "addOrEditJiraIssueComment|writing a comment on the Jira card SCRUM-7" \
    "editJiraIssue|changing the Jira card SCRUM-7"; do
    OUT="$(cd "$A" && jq -n --arg t "mcp__claude_ai_Atlassian_MCP__${t%%|*}" '{hook_event_name: "PreToolUse", session_id: "s1", tool_name: $t, tool_input: {issueIdOrKey: "SCRUM-7"}}' |
      bash scripts/command-guard-hook.sh claude)"
    warned "${t#*|} without asking (pre-approved)." "${t%%|*}"
  done
  OUT="$(cd "$A" && jq -n '{hook_event_name: "PostToolUse", session_id: "s1", tool_name: "mcp__claude_ai_Atlassian_MCP__transitionJiraIssue", tool_input: {issueIdOrKey: "SCRUM-7"}}' |
    bash scripts/command-guard-hook.sh claude)"
  assert_eq "$OUT" "" "after it ran: nothing more"
  OUT="$(cd "$A" && jq -n '{hook_event_name: "PreToolUse", session_id: "s1", tool_name: "mcp__claude_ai_Atlassian_MCP__getJiraIssue", tool_input: {issueIdOrKey: "SCRUM-7"}}' |
    bash scripts/command-guard-hook.sh claude)"
  assert_eq "$OUT" "" "reading a card"
}
test_several_warnings_in_one_command_are_one_message() {
  setup
  mkdir -p "$G/s1" && : > "$G/s1/push"
  guard claude PreToolUse 'bash scripts/ship.sh ws2 push-update && bash scripts/gitlab-mr.sh ws2 reply SCRUM-1/x 12 r.md'
  warned "the session's next push runs without asking"
  assert_contains "$(message)" "⚠️ closio-agent: writing on the merge request without asking"
  assert_eq "$(message | grep -c '^⚠️ ')" "2" "two lines"
}
test_a_long_command_is_cut_in_the_warning() {
  setup
  local long="git push origin main $(printf 'x%.0s' $(seq 1 200))"
  guard claude PreToolUse "$long
echo second line"
  assert_contains "$(message)" "…"; assert_not_contains "$(message)" "second line"
}
