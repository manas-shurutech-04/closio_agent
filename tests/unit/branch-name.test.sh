# scripts/branch-name.sh: makes and checks the card's branch names (SCRUM-<number>/<short-description>).

test_make_drops_filler_words_and_keeps_five() {
  sandbox
  run branch-name.sh make SCRUM-519 "Add filter by status to the orders list"
  assert_rc 0; assert_eq "$OUT" "SCRUM-519/add-filter-status-orders-list"
}
test_make_turns_punctuation_and_capitals_into_plain_words() {
  sandbox
  run branch-name.sh make SCRUM-7 "Fix: API v2 returns 500 (WS1)"
  assert_rc 0; assert_eq "$OUT" "SCRUM-7/fix-api-v2-returns-500"
}
test_make_follows_the_max_words_setting() {
  sandbox
  export BRANCH_DESC_MAX_WORDS=2
  run branch-name.sh make SCRUM-1 "Scheme list filter by status"
  assert_rc 0; assert_eq "$OUT" "SCRUM-1/scheme-list"
}
test_make_with_a_bad_key() {
  sandbox
  run branch-name.sh make scrum-519 "Add filter"
  assert_rc 1
  assert_eq "$OUT" "❌ 'scrum-519' isn't a card key like SCRUM-519
   Fix: use the card key exactly as in Jira."
}
test_make_with_a_title_without_letters() {
  sandbox
  run branch-name.sh make SCRUM-1 "!!! --- ???"
  assert_rc 1
  assert_contains "$OUT" "❌ The title has no letters or numbers to build a description from"
  assert_contains "$OUT" "   Fix: give a short description in plain words."
}
test_make_with_only_filler_words() {
  sandbox
  run branch-name.sh make SCRUM-1 "to the and of"
  assert_rc 1; assert_contains "$OUT" "❌ The title has no letters or numbers"
}
test_make_without_a_title_shows_the_usage() {
  sandbox
  run branch-name.sh make SCRUM-1
  assert_rc 1; assert_eq "$OUT" "Usage: bash scripts/branch-name.sh make <CARD-KEY> \"<title>\""
}
test_check_a_good_name() {
  sandbox
  run branch-name.sh check SCRUM-519/add-filter-status
  assert_rc 0; assert_eq "$OUT" "✅ SCRUM-519/add-filter-status follows the branch-naming rule"
}
test_check_a_name_without_the_key_and_slash() {
  sandbox
  run branch-name.sh check add-filter-status
  assert_rc 1
  assert_eq "$OUT" "❌ 'add-filter-status' doesn't start with the card key and a '/' (e.g. SCRUM-519/add-filter-status)
   Fix: use the rule: SCRUM-<number>/<short-description>: lowercase words joined by '-', only a-z and 0-9, at most 5 words"
}
test_check_a_name_with_a_wrong_key() {
  sandbox
  run branch-name.sh check feature/add-filter
  assert_rc 1; assert_contains "$OUT" "doesn't start with the card key"
}
test_check_a_name_with_capitals_or_underscores() {
  sandbox
  run branch-name.sh check SCRUM-519/Add_filter
  assert_rc 1
  assert_eq "$OUT" "❌ The description 'Add_filter' must be lowercase words joined by '-' (only a-z and 0-9)
   Fix: e.g. bash scripts/branch-name.sh make SCRUM-519 \"<card title>\""
  run branch-name.sh check SCRUM-519/add--filter
  assert_rc 1; assert_contains "$OUT" "must be lowercase words joined by '-'"
}
test_check_a_name_with_too_many_words() {
  sandbox
  run branch-name.sh check SCRUM-519/one-two-three-four-five-six
  assert_rc 1
  assert_eq "$OUT" "❌ The description has 6 words; at most 5 are allowed
   Fix: shorten it to the 5 most telling words."
}
test_check_uses_the_project_key_setting() {
  sandbox
  export JIRA_PROJECT_KEY=ABC
  run branch-name.sh check ABC-12/add-thing
  assert_rc 0
  run branch-name.sh check SCRUM-12/add-thing
  assert_rc 1; assert_contains "$OUT" "(e.g. ABC-519/add-filter-status)"
}
test_check_with_a_wrong_number_of_arguments() {
  sandbox
  run branch-name.sh check
  assert_rc 1; assert_eq "$OUT" "Usage: bash scripts/branch-name.sh check <branch-name>"
  run branch-name.sh check SCRUM-1/a extra
  assert_rc 1; assert_eq "$OUT" "Usage: bash scripts/branch-name.sh check <branch-name>"
}
test_an_unknown_action_shows_the_usage() {
  sandbox
  run branch-name.sh
  assert_rc 1; assert_eq "$OUT" "Usage: bash scripts/branch-name.sh make <CARD-KEY> \"<title>\" | check <branch-name>"
  run branch-name.sh fix SCRUM-1
  assert_rc 1; assert_contains "$OUT" "Usage:"
}
