# A card's journey through the scripts, in the order the card commands run them (D92): picked up, its branch made,
# developed and pushed with its MR, then a QA round. The AI's own part (reading, deciding, writing) is played by the
# test; Jira, GitLab, the code repo's remote and closio-agent's GitHub are fakes on this Mac.

KEY=SCRUM-1

# A code repo like the real ones: a "GitLab" bare repo with develop (it accepts push options and prints an MR link,
# as GitLab does), the user's clone of it, and its registration in the sandbox.
code_repo() {
  local bare="$T/gitlab/closio/backend/fake-ws2.git" clone="$T/repos/fake-ws2"
  mkdir -p "$T/gitlab/closio/backend" "$T/repos" "$A/local/repos"
  git init -q --bare "$bare" && git -C "$bare" config receive.advertisePushOptions true
  printf '#!/bin/bash\necho "To create a merge request, visit:"\necho "  https://gitlab.example/closio/fake-ws2/-/merge_requests/7"\n' > "$bare/hooks/post-receive"
  chmod +x "$bare/hooks/post-receive"
  git init -q -b develop "$clone"
  echo "module.exports = {};" > "$clone/app.js"
  git -C "$clone" add -A && git -C "$clone" commit -q -m "first" && git -C "$clone" remote add origin "$bare" && git -C "$clone" push -q origin develop 2>/dev/null
  # its project is what the remote's address gives (for a real clone: closio/backend/<repo>; here the bare repo's folder)
  cat > "$A/config/repos/fake-ws2.yaml" <<EOF
name: fake-ws2
gitlab_path: ${bare%.git}
type: BE
language: other
base_branch: develop
mr_target_branch: develop
test_command: none
check_commands: none
EOF
  printf 'local_path: %s\n' "$clone" > "$A/local/repos/fake-ws2.yaml"
  CLONE="$clone"; BARE="$bare"
}
journey_start() {
  sandbox rulesets docs/agent-rules.md AGENTS.md
  sandbox_git; sandbox_remote
  start_fake JIRA_API_URL jira
  user_settings JIRA_EMAIL=qa@example.com JIRA_ACCOUNT_ID=acc-123 GITLAB_USERNAME=tester
  keychain_set closio-agent.jira-api-token tok123
  keychain_set closio-agent.gitlab-token glpat-test-token
  code_repo
}
# What /flow-start does with the scripts, steps 1 to 6 (the AI writes card.md from what Jira returns)
pick_up() {
  run jira-api.sh get "$KEY"; assert_rc 0
  CARD_TEXT="$OUT"
  run run.sh branch "$KEY"; assert_rc 0
  run run.sh create "$KEY" "Scheme list filter"; assert_rc 0
  run run.sh rules "$KEY" read; assert_rc 0
  run run.sh set "$KEY" type Story; assert_rc 0
  { echo "# $KEY — Scheme list filter"; echo; echo "_Story · To Do · Read on 2026-10-23_"; echo; printf '%s\n' "$CARD_TEXT" | sed -n '/^Description (Markdown):$/,$p' | sed 1d; } > "$A/runs/$KEY/card.md"
  run card-check.sh "runs/$KEY/card.md"
  CARD_CHECK="$OUT"
  run run.sh step "$KEY" "pick-up 2" "card read and checked" "rules: A16 · memory: —" --next 3; assert_rc 0
  run jira-api.sh sprint "$KEY"; assert_rc 0
  run jira-api.sh move "$KEY" "In Development"; assert_rc 0
  run jira-api.sh assign "$KEY"; assert_rc 0
  run run.sh set "$KEY" jira_status "In Development"; assert_rc 0
  run branch-name.sh make "$KEY" "Scheme list filter"; assert_rc 0
  BRANCH="$(printf '%s\n' "$OUT" | grep -o -E "$KEY/[a-z0-9-]+" | head -1)"
  [ -n "$BRANCH" ] || fail "branch-name.sh made no name: $OUT"
  run card-branch.sh create fake-ws2 "$BRANCH"; assert_rc 0
  run run.sh set "$KEY" repos fake-ws2; run run.sh set "$KEY" branch "$BRANCH"
  run run.sh decide "$KEY" "pick-up 4" "Which repos?" "fake-ws2" "you: recommended"; assert_rc 0
  run run.sh step "$KEY" "pick-up 5" "branch $BRANCH made" "rules: A12 · memory: —" --next 6; assert_rc 0
  run run.sh save "$KEY" "picked up: In Development"; assert_rc 0
}

test_a_card_is_picked_up_and_saved_to_its_branch() {
  journey_start
  pick_up
  assert_contains "$CARD_CHECK" "✅" "the card check ran on the saved card"
  assert_eq "$(git -C "$CLONE" rev-parse --abbrev-ref HEAD)" "$BRANCH" "the code repo is on the card's branch"
  assert_contains "$(fake_requests JIRA_API_URL)" '"transition": {"id": "21"}' "the card moved to In Development"
  assert_contains "$(fake_requests JIRA_API_URL)" '"accountId": "acc-123"' "the card assigned to the user"
  local saved
  saved="$(git -C "$T/origin.git" show "refs/heads/runs/$KEY:runs/$KEY/history.md")" || fail "runs/$KEY isn't on the card's saved copy"
  assert_contains "$saved" "| pick-up 2 | card read and checked | rules: A16 · memory: — |"
  assert_contains "$(git -C "$T/origin.git" show "refs/heads/runs/$KEY:runs/$KEY/decisions.md")" "Which repos?"
  assert_contains "$(git -C "$T/origin.git" show "refs/heads/runs/$KEY:runs/$KEY/state.md")" "jira_status: In Development"
  assert_eq "$(git -C "$A" rev-parse --abbrev-ref HEAD)" "main" "closio-agent itself stays on main"
}

test_a_card_is_developed_rebased_pushed_with_its_mr_and_noted_on_jira() {
  journey_start
  pick_up
  # develop: the AI writes code; a teammate merges something into develop meanwhile
  echo "module.exports = { filter: true };" > "$CLONE/app.js"
  printf 'it("filters")\n' > "$CLONE/app.test.js"
  local mate="$T/mate"
  git clone -q -b develop "$BARE" "$mate" && echo "x" > "$mate/other.js" && git -C "$mate" add -A &&
    git -C "$mate" commit -q -m "teammate's change" && git -C "$mate" push -q origin develop || fail "the teammate's push"
  run card-branch.sh rebase fake-ws2 "$BRANCH"; assert_rc 0
  assert_contains "$OUT" "1 newer commit(s) from develop came in"
  run ship.sh fake-ws2 status; assert_rc 0
  assert_contains "$OUT" "app.js"
  run ship.sh fake-ws2 commit "$KEY: filter the scheme list" app.js app.test.js; assert_rc 0
  run ship.sh fake-ws2 push "$KEY: Scheme list filter"; assert_rc 0
  assert_contains "$OUT" "MR: https://gitlab.example/closio/fake-ws2/-/merge_requests/7"
  git -C "$BARE" rev-parse --verify -q "refs/heads/$BRANCH" >/dev/null || fail "the card's branch isn't on the fake GitLab"
  # the MR's description through the GitLab API
  printf '[{"method":"GET","path":"/merge_requests$","json":[{"iid":7,"web_url":"https://gitlab.example/closio/fake-ws2/-/merge_requests/7","title":"%s: Scheme list filter"}]},{"method":"PUT","path":"/merge_requests/7$","json":{"iid":7}}]\n' "$KEY" > "$T/gitlab.json"
  start_fake GITLAB http "$T/gitlab.json"; export GITLAB_API_URL="$GITLAB/api/v4"
  printf '**Jira:** [%s](https://example/browse/%s)\n' "$KEY" "$KEY" > "$A/runs/$KEY/mr-fake-ws2.md"
  run gitlab-mr.sh fake-ws2 describe "$BRANCH" "runs/$KEY/mr-fake-ws2.md"; assert_rc 0
  fake_requests GITLAB | grep '"PUT"' | jq -e '.b.description | test("Jira")' >/dev/null || fail "the MR description wasn't sent: $(fake_requests GITLAB)"
  assert_not_contains "$(fake_requests GITLAB | grep -v PRIVATE-TOKEN)" "glpat-test-token"
  # the MR link on the card, then the card's folder saved
  printf 'Merge requests: fake-ws2: https://gitlab.example/closio/fake-ws2/-/merge_requests/7\n' > "$T/mr-comment.md"
  run jira-api.sh comment "$KEY" "$T/mr-comment.md"; assert_rc 0
  run run.sh set "$KEY" phase after-merge; run run.sh step "$KEY" "push 12" "pushed, MR !7" "rules: G4 · memory: —"
  run run.sh save "$KEY" "pushed: MRs created"; assert_rc 0
  assert_contains "$(git -C "$T/origin.git" show "refs/heads/runs/$KEY:runs/$KEY/state.md")" "phase: after-merge"
}

test_after_every_reply_the_card_folder_is_pushed_by_the_hook() {
  journey_start
  pick_up
  printf '{"prompt":"/flow-develop %s","session_id":"s1"}' "$KEY" | bash "$A/scripts/card-rules-hook.sh" >/dev/null
  echo "| x | develop 1 | started | — |" >> "$A/runs/$KEY/history.md"
  OUT="$(printf '{"session_id":"s1"}' | bash "$A/scripts/card-autosave-hook.sh")"
  assert_eq "$OUT" "" "the hook says nothing when the save works"
  assert_eq "$(git -C "$T/origin.git" log -1 --format=%s "refs/heads/runs/$KEY")" "$KEY: auto-saved after /flow-develop"
}

test_a_qa_round_reads_the_comments_raises_a_bug_and_records_the_decisions() {
  journey_start
  pick_up
  run jira-api.sh comments "$KEY"; assert_rc 0
  assert_contains "$OUT" "Newest comment id: 10003"
  printf 'Title: Filter ignores status (from QA on %s)\nWhat QA saw: "point 2"\nRelates to: %s\n' "$KEY" "$KEY" > "$T/bug.md"
  run jira-api.sh create Bug "$T/bug.md" --relates "$KEY"; assert_rc 0
  local bug; bug="$(printf '%s\n' "$OUT" | sed -n 's/^New key: //p')"
  assert_eq "$bug" "SCRUM-99"
  run run.sh decide "$KEY" "qa 5" "Raise a Bug card for point 2?" "yes: $bug" "you"; assert_rc 0
  run run.sh save "$KEY" "qa round 1"; assert_rc 0
  assert_contains "$(git -C "$T/origin.git" show "refs/heads/runs/$KEY:runs/$KEY/decisions.md")" "yes: SCRUM-99"
}
