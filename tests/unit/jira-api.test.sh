# scripts/jira-api.sh: the Jira API backup (D88), against the fake Jira (tests/fakes/jira.py).

setup_jira() {
  sandbox
  start_fake JIRA_API_URL jira
  user_settings JIRA_EMAIL=qa@example.com JIRA_ACCOUNT_ID=acc-123
  keychain_set closio-agent.jira-api-token tok123
}
writes() { fake_requests JIRA_API_URL; }
last_write() { fake_requests JIRA_API_URL | tail -1; }

test_check_without_email_is_a_warning_never_an_error() {
  setup_jira; user_settings JIRA_ACCOUNT_ID=acc-123
  run jira-api.sh check
  assert_rc 3; assert_contains "$OUT" "⚠️ The Jira API backup isn't set up (optional): no Atlassian email"; assert_not_contains "$OUT" "❌"
}
test_check_without_token_is_a_warning() {
  setup_jira; rm -f "$FAKE_KEYCHAIN/closio-agent.jira-api-token"
  run jira-api.sh check
  assert_rc 3; assert_contains "$OUT" "no Atlassian API token"; assert_not_contains "$OUT" "❌"
}
test_check_with_a_wrong_token_is_a_warning() {
  setup_jira; keychain_set closio-agent.jira-api-token wrong
  run jira-api.sh check
  assert_rc 1; assert_contains "$OUT" "⚠️ Jira refused"
}
test_check_when_jira_does_not_answer() {
  setup_jira; export JIRA_API_URL="http://127.0.0.1:1"
  run jira-api.sh check
  assert_rc 1; assert_contains "$OUT" "can't reach Jira"
}
test_check_works() {
  setup_jira
  run jira-api.sh check
  assert_rc 0; assert_eq "$OUT" "✅ The Jira API backup works: signed in as Test User (qa@example.com)"
}
test_me_prints_the_account_id() {
  setup_jira
  run jira-api.sh me
  assert_rc 0; assert_eq "$OUT" "✅ Signed in to Jira as Test User
Account ID: acc-123"
}
test_get_shows_the_card_and_its_description_as_markdown() {
  setup_jira
  run jira-api.sh get scrum-1
  assert_rc 0
  assert_eq "$OUT" 'SCRUM-1 — Scheme list filter
Type: Story · Status: To Do · Assignee: nobody
Sprint: Sprint 11 (closed, id 5)
Issue links: relates to SCRUM-2 (Done)
Web links: MR !12 — https://gitlab/x/12
Description (Markdown):
## Acceptance Criteria

1. Given **a scheme** returns `VALIDATION_ERROR`'
}
test_get_a_card_that_is_not_there() {
  setup_jira
  run jira-api.sh get SCRUM-404
  assert_rc 1; assert_contains "$OUT" "❌ Jira found nothing for SCRUM-404 (404)"; assert_contains "$OUT" "Fix:"
}
test_get_a_bad_key_is_wrong_usage() {
  setup_jira
  run jira-api.sh get 567
  assert_rc 2; assert_contains "$OUT" "isn't a card key"
}
test_status_of_two_cards() {
  setup_jira
  run jira-api.sh status SCRUM-1 SCRUM-2
  assert_eq "$OUT" "SCRUM-1: To Do · Scheme list filter
SCRUM-2: Ready for Test · Scheme list filter"
}
test_status_without_a_key_shows_the_usage() {
  setup_jira
  run jira-api.sh status
  assert_rc 2; assert_contains "$OUT" "Usage:"
}
test_status_of_a_missing_card_and_without_a_token() {
  setup_jira
  run jira-api.sh status SCRUM-404
  assert_rc 1
  rm -f "$FAKE_KEYCHAIN/closio-agent.jira-api-token"
  run jira-api.sh status SCRUM-1
  assert_rc 3
}
test_comments_over_two_pages() {
  setup_jira
  run jira-api.sh comments SCRUM-1
  assert_eq "$(printf '%s\n' "$OUT" | grep -c '^--- Comment ')" "3"
  assert_contains "$OUT" "--- Comment 10001 · QA 1 (qa-1) · 2026-10-21 10:15 +0700"
  assert_contains "$OUT" "point 3"
  assert_eq "$(printf '%s\n' "$OUT" | tail -1)" "Newest comment id: 10003"
}
test_transitions_lists_the_moves() {
  setup_jira
  run jira-api.sh transitions SCRUM-1
  assert_rc 0; assert_contains "$OUT" "SCRUM-1 can move to: In Development (transition 21), Blocked (transition 31)"
}
test_move_to_blocked_is_refused_and_nothing_is_sent() {
  setup_jira
  run jira-api.sh move SCRUM-1 Blocked
  assert_rc 2; assert_contains "$OUT" "never to Blocked"; assert_eq "$(writes)" ""
}
test_move_uses_the_matching_transition() {
  setup_jira
  run jira-api.sh move SCRUM-1 "in development"
  assert_rc 0; assert_eq "$OUT" "✅ SCRUM-1 moved: To Do → In Development"
  assert_contains "$(last_write)" '"transition": {"id": "21"}'
}
test_move_to_where_it_already_is_sends_nothing() {
  setup_jira
  run jira-api.sh move SCRUM-2 "Ready for Test"
  assert_eq "$OUT" "✅ SCRUM-2 is already in Ready for Test"; assert_eq "$(writes)" ""
}
test_move_the_workflow_does_not_have() {
  setup_jira
  run jira-api.sh move SCRUM-1 "Code Review"
  assert_rc 1; assert_contains "$OUT" "can't move from To Do to Code Review"
}
test_assign_to_your_account() {
  setup_jira
  run jira-api.sh assign SCRUM-1
  assert_eq "$OUT" "✅ SCRUM-1 is assigned to you"
  assert_contains "$(last_write)" '"p": "/rest/api/3/issue/SCRUM-1/assignee", "b": {"accountId": "acc-123"}'
}
test_assign_without_an_account_id() {
  setup_jira; user_settings JIRA_EMAIL=qa@example.com
  run jira-api.sh assign SCRUM-1
  assert_rc 1; assert_contains "$OUT" "jira-account-id"
}
test_sprint_puts_the_card_in_the_one_active_sprint() {
  setup_jira
  run jira-api.sh sprint SCRUM-1
  assert_eq "$OUT" "✅ SCRUM-1 is in the active sprint: Sprint 12"
  assert_contains "$(last_write)" '"b": {"fields": {"customfield_10020": 7}}'
}
test_comment_posts_markdown_as_wiki_text() {
  setup_jira
  printf '## Deployment\n\n**Fix:** run `x {id}`\n- [MR !12](https://g/12)\n' > "$T/doc.md"
  run jira-api.sh comment SCRUM-1 "$T/doc.md"
  assert_eq "$OUT" "✅ Comment posted on SCRUM-1
Comment id: 10050"
  printf '%s' "$(last_write)" | jq -e '.b.body == "h2. Deployment\n\n*Fix:* run {{x \\{id\\}}}\n* [MR !12|https://g/12]"' >/dev/null ||
    fail "wiki body: $(last_write)"
}
test_comment_without_a_file_is_wrong_usage() {
  setup_jira
  run jira-api.sh comment SCRUM-1 "$T/none.md"
  assert_rc 2; assert_contains "$OUT" "No file"
}
test_edit_comment() {
  setup_jira
  printf 'new text\n' > "$T/doc.md"
  run jira-api.sh edit-comment SCRUM-1 10050 "$T/doc.md"
  assert_eq "$OUT" "✅ Comment 10050 on SCRUM-1 edited"
  run jira-api.sh edit-comment SCRUM-1 abc "$T/doc.md"
  assert_rc 2
}
test_create_a_bug_linked_to_its_story() {
  setup_jira
  printf 'Title: Filter ignores status (from QA on SCRUM-1)\nWhat QA saw: "x"\nRelates to: SCRUM-1\n' > "$T/bug.md"
  run jira-api.sh create Bug "$T/bug.md" --relates scrum-1
  assert_rc 0; assert_contains "$OUT" "New key: SCRUM-99"; assert_contains "$OUT" "✅ SCRUM-99 relates to SCRUM-1"
  fake_requests JIRA_API_URL | grep '"/rest/api/2/issue"' | jq -e '.b.fields.summary == "Filter ignores status (from QA on SCRUM-1)" and .b.fields.issuetype.name == "Bug"' >/dev/null ||
    fail "the card created: $(writes)"
}
test_create_with_a_bad_type_or_title() {
  setup_jira
  printf 'x\n' > "$T/c.md"
  run jira-api.sh create Epic "$T/c.md"
  assert_rc 2
  printf '\n' > "$T/empty.md"; printf ' \n' >> "$T/empty.md"
  run jira-api.sh create Task "$T/empty.md"
  assert_rc 2
}
test_a_write_without_a_token_sends_nothing() {
  setup_jira; rm -f "$FAKE_KEYCHAIN/closio-agent.jira-api-token"
  printf 'x\n' > "$T/doc.md"
  run jira-api.sh comment SCRUM-1 "$T/doc.md"
  assert_rc 3; assert_contains "$OUT" "jira-api-token"; assert_eq "$(writes)" ""
}
test_the_token_is_never_printed_or_sent_in_a_body() {
  setup_jira
  run jira-api.sh get SCRUM-1; all="$OUT"
  run jira-api.sh comments SCRUM-1; all="$all$OUT"
  assert_not_contains "$all" "tok123"; assert_not_contains "$(writes)" "tok123"
}
test_a_refused_token_on_a_call() {
  setup_jira; keychain_set closio-agent.jira-api-token wrong
  run jira-api.sh get SCRUM-1
  assert_rc 1; assert_contains "$OUT" "401"; assert_contains "$OUT" "jira-api-token"
}
test_jira_not_answering_on_a_call() {
  setup_jira; export JIRA_API_URL="http://127.0.0.1:1"
  run jira-api.sh get SCRUM-1
  assert_rc 1; assert_contains "$OUT" "❌ Jira didn't answer"
}
test_an_unknown_action_shows_the_usage() {
  setup_jira
  run jira-api.sh nothing
  assert_rc 2; assert_contains "$OUT" "Usage:"
}
