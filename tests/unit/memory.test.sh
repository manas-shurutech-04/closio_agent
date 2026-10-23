# scripts/memory.sh: the user memory in local/memory/ (general.md and repos/<repo>.md).

setup_memory() { # a sandbox with two registered repos of its own: demo-repo and other-repo
  sandbox
  printf 'name: demo-repo\n' > "$A/config/repos/demo-repo.yaml"
  printf 'name: other-repo\n' > "$A/config/repos/other-repo.yaml"
  TODAY="$(date +%Y-%m-%d)"
  GEN="$A/local/memory/general.md"
}
add() { run memory.sh add "$@"; assert_rc 0; }
# Four entries: M1 general (plan), M2 general (develop, from SCRUM-12), M3 demo-repo (all), M4 other-repo (plan)
# (written straight into the files, as add writes them: the add tests check that)
four_entries() {
  mkdir -p "$A/local/memory/repos"
  printf '# Your user memory: applies everywhere (F6b, D40). Private: local/ is never pushed.\n# One entry per line.\n\n' > "$GEN"
  printf -- '- [M1] %s · phases: plan · from: - · Write plans as short numbered steps.\n' "$TODAY" >> "$GEN"
  printf -- '- [M2] %s · phases: develop · from: SCRUM-12 · Run the linter before the tests.\n' "$TODAY" >> "$GEN"
  printf -- '# demo-repo only\n\n- [M3] %s · phases: all · from: - · Use the seed data in test/fixtures.\n' "$TODAY" > "$A/local/memory/repos/demo-repo.md"
  printf -- '# other-repo only\n\n- [M4] %s · phases: plan · from: - · Mention the queue names.\n' "$TODAY" > "$A/local/memory/repos/other-repo.md"
}

test_for_without_a_phase_loads_nothing_and_never_fails() {
  setup_memory
  run memory.sh for
  assert_rc 0; assert_eq "$OUT" "⚠️ The memory step was called without a phase, so no user memory was loaded."
}
test_for_an_unknown_phase_is_a_warning_and_never_fails() {
  setup_memory
  run memory.sh for cooking
  assert_rc 0
  assert_contains "$OUT" "❌ Unknown phase 'cooking'"
  assert_contains "$OUT" "   Fix: Use one of: all setup pick-up plan develop review ac-check testing ship mr after-merge"
  assert_contains "$OUT" "⚠️ Couldn't read all of your user memory, so some entries may be missing. Run /flow-memory to check it."
}
test_for_with_no_memory_says_nothing_applies() {
  setup_memory
  run memory.sh for plan all
  assert_rc 0; assert_eq "$OUT" "User memory: nothing applies to this command (that's normal)."
}
test_add_a_general_entry_makes_the_file_with_its_header() {
  setup_memory
  run memory.sh add general plan - Write plans as short numbered steps.
  assert_rc 0; assert_eq "$OUT" "✅ Saved as M1 (general · phases: plan): Write plans as short numbered steps."
  assert_eq "$(cat "$GEN")" "# Your user memory: applies everywhere (F6b, D40). Private: local/ is never pushed.
# One entry per line. Manage it with /flow-memory, or edit by hand in the same format.

- [M1] $TODAY · phases: plan · from: - · Write plans as short numbered steps."
}
test_add_a_repo_entry_and_the_ids_count_up_across_files() {
  setup_memory
  add general plan - one
  run memory.sh add demo-repo develop SCRUM-519 two
  assert_eq "$OUT" "✅ Saved as M2 (demo-repo · phases: develop): two"
  add general all - three
  assert_eq "$OUT" "✅ Saved as M3 (general · phases: all): three"
  assert_eq "$(cat "$A/local/memory/repos/demo-repo.md")" "# Your user memory for demo-repo only (F6b, D40). Private: local/ is never pushed.
# One entry per line. Manage it with /flow-memory, or edit by hand in the same format.

- [M2] $TODAY · phases: develop · from: SCRUM-519 · two"
}
test_add_cleans_up_the_phases_and_the_text() {
  setup_memory
  run memory.sh add general "plan,develop,plan" - "  Keep   it
short  "
  assert_eq "$OUT" "✅ Saved as M1 (general · phases: plan, develop): Keep it short"
  run memory.sh add general "review, all" - x
  assert_eq "$OUT" "✅ Saved as M2 (general · phases: all): x"
  assert_contains "$(cat "$GEN")" "- [M1] $TODAY · phases: plan, develop · from: - · Keep it short"
}
test_add_refuses_a_bad_scope_phases_card_or_empty_text() {
  setup_memory
  run memory.sh add nobody-repo plan - x
  assert_rc 1; assert_contains "$OUT" "❌ 'nobody-repo' isn't 'general' or a registered repo"; assert_contains "$OUT" "   Fix: Use general, or a repo name"
  run memory.sh add general cooking - x
  assert_rc 1; assert_contains "$OUT" "❌ Unknown phases 'cooking'"
  assert_contains "$OUT" "Fix: Use all, or a comma list of: setup pick-up plan develop review ac-check testing ship mr after-merge"
  run memory.sh add general "," - x
  assert_rc 1; assert_contains "$OUT" "❌ Unknown phases ','"
  run memory.sh add general plan scrum-1 x
  assert_rc 1; assert_contains "$OUT" "❌ 'scrum-1' isn't a card key"
  run memory.sh add general plan - "   "
  assert_rc 1; assert_contains "$OUT" "❌ The entry text is empty"
  assert_no_file "$A/local/memory"
}
test_add_refuses_anything_that_looks_like_a_secret_and_never_shows_it() {
  setup_memory
  local s
  for s in "the password: hunter2" "token=abc" "use glpat-AbCdEf123456" "Bearer abcdefghijklmnopqrstu" \
           "key AKIAABCDEFGHIJKLMNOP" "QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVphYmNkZWZnaGlq"; do
    run memory.sh add general plan - "$s"
    assert_rc 1; assert_contains "$OUT" "❌ This looks like a secret (a token, key or password), so it wasn't saved" "refuse: $s"
    assert_not_contains "$OUT" "$s"
  done
  assert_no_file "$GEN"
}
test_add_without_its_words_shows_the_usage() {
  setup_memory
  run memory.sh add general plan -
  assert_rc 1; assert_eq "$OUT" "Usage: bash scripts/memory.sh add <general|repo> <phases> <card|-> <text...>"
}
test_for_shows_the_general_entries_and_the_named_repos_for_the_phase() {
  setup_memory; four_entries
  run memory.sh for plan
  assert_rc 0
  assert_eq "$OUT" "User memory for this command (1 entry). Apply them; team rules always win, so say so if one conflicts:
- [M1] (general) Write plans as short numbered steps."
  run memory.sh for plan demo-repo SCRUM-1
  assert_eq "$OUT" "User memory for this command (2 entries). Apply them; team rules always win, so say so if one conflicts:
- [M1] (general) Write plans as short numbered steps.
- [M3] (demo-repo) Use the seed data in test/fixtures."
  run memory.sh for plan all
  assert_contains "$OUT" "(3 entries)"
  assert_contains "$OUT" "- [M4] (other-repo) Mention the queue names."
  run memory.sh for develop
  assert_eq "$(printf '%s\n' "$OUT" | tail -1)" "- [M2] (general) Run the linter before the tests."
  run memory.sh for ship
  assert_eq "$OUT" "User memory: nothing applies to this command (that's normal)."
}
test_hand_edited_lines_that_do_not_fit_are_shown_and_ignored() {
  setup_memory
  add general plan - one
  printf 'a note I typed\n\n# a comment is fine\n- [M9] no date here\n' >> "$GEN"
  run memory.sh for plan
  assert_rc 0
  assert_contains "$OUT" "- [M1] (general) one"
  assert_contains "$OUT" "⚠️ local/memory/general.md line 5 isn't in the memory format, so it's ignored"
  assert_contains "$OUT" "⚠️ local/memory/general.md line 8 isn't in the memory format, so it's ignored"
  assert_contains "$OUT" "   Tip: Fix it by hand (format: - [M<n>] <date> · phases: <phases> · from: <card or -> · <text>), or remove it with /flow-memory."
  assert_eq "$(printf '%s\n' "$OUT" | grep -c '^⚠️')" "2" "blank lines and # comments are fine"
  run memory.sh problems
  assert_rc 0; assert_eq "$(printf '%s\n' "$OUT" | grep -c '^⚠️')" "2"
  run memory.sh count
  assert_eq "$OUT" "1"
}
test_list_with_no_memory() {
  setup_memory
  run memory.sh list
  assert_rc 0; assert_eq "$OUT" "You have no user memory yet (that's normal). Add an entry with: /flow-memory add <text>"
}
test_list_shows_every_entry_by_file() {
  setup_memory; four_entries
  run memory.sh list
  assert_rc 0
  assert_eq "$OUT" "Your user memory (private, in local/memory/)

General (everywhere)
   [M1] Write plans as short numbered steps.
        phases: plan · saved $TODAY
   [M2] Run the linter before the tests.
        phases: develop · saved $TODAY · from SCRUM-12

Repo: demo-repo
   [M3] Use the seed data in test/fixtures.
        phases: all · saved $TODAY

Repo: other-repo
   [M4] Mention the queue names.
        phases: plan · saved $TODAY

Total: 4 entries."
}
test_list_one_entry_says_entry() {
  setup_memory
  add demo-repo all - only one
  run memory.sh list
  assert_contains "$OUT" "Repo: demo-repo"; assert_contains "$OUT" "Total: 1 entry."
}
test_edit_changes_only_the_text() {
  setup_memory; four_entries
  run memory.sh edit M2 Run   the linter first.
  assert_rc 0; assert_eq "$OUT" "✅ M2 changed: Run the linter first."
  assert_contains "$(cat "$GEN")" "- [M2] $TODAY · phases: develop · from: SCRUM-12 · Run the linter first."
  assert_not_contains "$(cat "$GEN")" "before the tests"
  run memory.sh edit M3 Seeds live in test/seed.
  assert_contains "$(cat "$A/local/memory/repos/demo-repo.md")" "- [M3] $TODAY · phases: all · from: - · Seeds live in test/seed."
}
test_edit_refuses_a_bad_id_a_missing_entry_empty_text_a_secret_or_a_broken_line() {
  setup_memory; four_entries
  printf -- '- [M7] broken line\n' >> "$GEN"
  local before; before="$(cat "$GEN")"
  run memory.sh edit 3 x
  assert_rc 1; assert_contains "$OUT" "❌ '3' isn't an entry ID"; assert_contains "$OUT" "Fix: Use an ID like M3 (see /flow-memory)."
  run memory.sh edit M99 x
  assert_rc 1; assert_contains "$OUT" "❌ No entry M99"
  run memory.sh edit M1 "  "
  assert_rc 1; assert_contains "$OUT" "❌ The new text is empty"; assert_contains "$OUT" "/flow-memory remove M1"
  run memory.sh edit M1 password=letmein1
  assert_rc 1; assert_contains "$OUT" "❌ This looks like a secret"; assert_not_contains "$OUT" "letmein1"
  run memory.sh edit M7 fixed
  assert_rc 1; assert_contains "$OUT" "❌ Entry M7 isn't in the memory format"; assert_contains "$OUT" "Fix the line by hand in local/memory/general.md."
  assert_eq "$(cat "$GEN")" "$before" "nothing changed"
}
test_set_phases_changes_only_the_phases() {
  setup_memory; four_entries
  run memory.sh set-phases M1 "develop,review"
  assert_rc 0; assert_eq "$OUT" "✅ M1 now applies to: develop, review"
  assert_contains "$(cat "$GEN")" "- [M1] $TODAY · phases: develop, review · from: - · Write plans as short numbered steps."
}
test_set_phases_refuses_a_bad_id_missing_entry_bad_phases_or_a_broken_line() {
  setup_memory; four_entries
  printf -- '- [M7] broken line\n' >> "$GEN"
  run memory.sh set-phases X1 plan
  assert_rc 1; assert_contains "$OUT" "❌ 'X1' isn't an entry ID"
  run memory.sh set-phases M50 plan
  assert_rc 1; assert_contains "$OUT" "❌ No entry M50"
  run memory.sh set-phases M1 lunch
  assert_rc 1; assert_contains "$OUT" "❌ Unknown phases 'lunch'"
  run memory.sh set-phases M7 plan
  assert_rc 1; assert_contains "$OUT" "❌ Entry M7 isn't in the memory format"
}
test_remove_an_entry() {
  setup_memory; four_entries
  run memory.sh remove M4
  assert_rc 0; assert_eq "$OUT" "✅ Removed M4: Mention the queue names."
  assert_not_contains "$(cat "$A/local/memory/repos/other-repo.md")" "[M4]"
  run memory.sh count
  assert_eq "$OUT" "3"
  run memory.sh remove M4
  assert_rc 1; assert_contains "$OUT" "❌ No entry M4"; assert_contains "$OUT" "Fix: See your entries with /flow-memory."
  run memory.sh remove four
  assert_rc 1; assert_contains "$OUT" "❌ 'four' isn't an entry ID"
}
test_clear_preview_lists_what_would_go_and_changes_nothing() {
  setup_memory; four_entries
  run memory.sh clear-preview all
  assert_rc 0
  assert_eq "$OUT" "These 4 entries would be removed:
   [M1] (general) Write plans as short numbered steps.
   [M2] (general) Run the linter before the tests.
   [M3] (demo-repo) Use the seed data in test/fixtures.
   [M4] (other-repo) Mention the queue names.
This can't be undone."
  run memory.sh clear-preview demo-repo
  assert_eq "$OUT" "These 1 entry would be removed (demo-repo only):
   [M3] (demo-repo) Use the seed data in test/fixtures.
This can't be undone."
  run memory.sh count
  assert_eq "$OUT" "4"
}
test_clear_preview_with_nothing_or_a_bad_target() {
  setup_memory
  run memory.sh clear-preview all
  assert_rc 0; assert_eq "$OUT" "Nothing to clear: you have no memory entries."
  run memory.sh clear-preview demo-repo
  assert_eq "$OUT" "Nothing to clear: you have no memory entries for demo-repo."
  run memory.sh clear-preview "../x"
  assert_rc 1; assert_contains "$OUT" "❌ '../x' isn't 'all' or a registered repo"
}
test_clear_needs_the_users_yes() {
  setup_memory; four_entries
  run memory.sh clear all
  assert_rc 1; assert_contains "$OUT" "❌ Clearing needs the user's yes first"
  run memory.sh clear nobody confirmed
  assert_rc 1; assert_contains "$OUT" "❌ 'nobody' isn't 'all' or a registered repo"
  run memory.sh count
  assert_eq "$OUT" "4"
}
test_clear_one_repo_keeps_the_rest() {
  setup_memory; four_entries
  run memory.sh clear demo-repo confirmed
  assert_rc 0; assert_eq "$OUT" "✅ Removed 1 entry for demo-repo. Your other entries are kept."
  assert_no_file "$A/local/memory/repos/demo-repo.md"
  assert_file "$A/local/memory/repos/other-repo.md"
  run memory.sh count
  assert_eq "$OUT" "3"
}
test_clear_all_removes_every_file() {
  setup_memory; four_entries
  run memory.sh clear all confirmed
  assert_rc 0
  assert_eq "$OUT" "✅ Removed 4 entries. Your user memory is empty now (that's normal); add entries again any time with /flow-memory add."
  assert_no_file "$A/local/memory"
  run memory.sh count
  assert_eq "$OUT" "0"
}
test_clear_all_of_one_entry() {
  setup_memory
  add general plan - one
  run memory.sh clear all confirmed
  assert_contains "$OUT" "✅ Removed 1 entry. Your user memory is empty now"
}
test_wrong_words_show_the_usage() {
  setup_memory
  local args
  for args in "edit M1" "set-phases M1" "remove" "clear-preview" "clear"; do
    run memory.sh $args
    assert_rc 1; assert_match "$OUT" "^Usage: bash scripts/memory.sh ${args%% *} " "usage of: $args"
  done
  run memory.sh nothing
  assert_rc 1; assert_contains "$OUT" "Usage: bash scripts/memory.sh for <phase> [words...] | list |"
}
