# scripts/card-rules-hook.sh: adds rulesets/card-rules.md to every prompt about a card, remembers the card sessions,
# and flags the rules to read again after a summary of the conversation.

setup_hook() {
  sandbox rulesets/card-rules.md .codex/hooks.json
  S="$A/local/card-sessions"
}
# Runs the hook with <json> on stdin; sets OUT and RC
hook() { OUT="$(cd "$A" && printf '%s' "$1" | bash scripts/card-rules-hook.sh 2>&1)"; RC=$?; }
prompt() { # <prompt> <session or "">
  if [ -n "$2" ]; then hook "$(jq -n --arg p "$1" --arg s "$2" '{prompt: $p, session_id: $s, hook_event_name: "UserPromptSubmit"}')"
  else hook "$(jq -n --arg p "$1" '{prompt: $p}')"; fi
}
# The hook added the card rules for this event
assert_rules_added() { # [<event>]
  assert_rc 0
  printf '%s' "$OUT" | jq -e --arg e "${1:-UserPromptSubmit}" '.hookSpecificOutput.hookEventName == $e and
    (.hookSpecificOutput.additionalContext | startswith("closio-agent'"'"'s card rules (rulesets/card-rules.md, added by the card-rules hook): follow them in this turn.")
      and contains("## 1. Every decision is recorded the moment it'"'"'s made"))' >/dev/null || fail "no card rules added: $OUT"
}
assert_nothing() { assert_rc 0; assert_eq "$OUT" "" "the hook should print nothing"; }
# A card command has read the rules for <key>: its fingerprints file in local/rules-read/
rules_read() { mkdir -p "$A/local/rules-read"; printf 'AGENTS.md abc\ndocs/agent-rules.md def\n' > "$A/local/rules-read/$1"; }

test_a_card_command_adds_the_rules_and_remembers_the_session() {
  setup_hook
  prompt "/flow-develop SCRUM-567" s1
  assert_rules_added
  assert_eq "$(cat "$S/s1")" "key SCRUM-567
last /flow-develop"
}
test_every_card_command_is_about_a_card() {
  setup_hook
  local c
  for c in start develop verify ac-check push review finish qa; do
    prompt "/flow-$c" "s-$c"
    assert_rules_added
    assert_eq "$(cat "$S/s-$c")" "last /flow-$c"
  done
}
test_a_later_reply_in_a_card_session_adds_the_rules() {
  setup_hook
  prompt "/flow-develop scrum-1" s1
  prompt "yes, and look at SCRUM-2 too" s1
  assert_rules_added
  assert_eq "$(cat "$S/s1")" "key SCRUM-1
key SCRUM-2
last a reply"
}
test_the_same_reply_in_another_session_adds_nothing() {
  setup_hook
  prompt "/flow-develop SCRUM-1" s1
  prompt "yes" s2
  assert_nothing; assert_no_file "$S/s2"
}
test_plain_words_naming_a_card_key_in_any_case() {
  setup_hook
  prompt "please develop scrum-567 now" s3
  assert_rules_added
  assert_eq "$(cat "$S/s3")" "key SCRUM-567
last a reply"
}
test_a_key_inside_another_word_is_not_a_card() {
  setup_hook
  prompt "see XSCRUM-12 and SCRUM-x" s4
  assert_nothing
  prompt "the fix for SCRUM-12a" s5
  assert_rules_added
}
test_flow_status_alone_or_with_a_key_only_reads() {
  setup_hook
  prompt "/flow-status" s4
  assert_nothing
  prompt "/flow-status SCRUM-567" s5
  assert_nothing; assert_no_file "$S/s5"
}
test_flow_status_in_a_card_session_adds_the_rules() {
  setup_hook
  prompt "/flow-start SCRUM-1" s1
  prompt "/flow-status" s1
  assert_rules_added
  assert_eq "$(cat "$S/s1")" "key SCRUM-1
last /flow-status"
}
test_codex_dollar_form_is_noted_as_the_slash_command() {
  setup_hook
  prompt '$flow-push SCRUM-567' s6
  assert_rules_added
  assert_eq "$(cat "$S/s6")" "key SCRUM-567
last /flow-push"
}
test_flow_grill_only_with_a_card_key() {
  setup_hook
  prompt '/flow-grill "move the deck"' s7
  assert_nothing
  prompt '/flow-grill scrum-567' s8
  assert_rules_added
  assert_eq "$(cat "$S/s8")" "key SCRUM-567
last /flow-grill"
}
test_setup_commands_and_look_alikes_add_nothing() {
  setup_hook
  prompt "/flow-doctor" s9
  assert_nothing
  prompt "/flow-developer notes" s10
  assert_nothing
  prompt "hello there" s11
  assert_nothing; assert_no_file "$S/s11"
}
test_bad_input_prints_nothing() {
  setup_hook
  hook "not json"
  assert_nothing
  hook ""
  assert_nothing
}
test_no_session_id_adds_the_rules_but_remembers_nothing() {
  setup_hook
  prompt "/flow-finish SCRUM-567" ""
  assert_rules_added
  assert_no_file "$S"
}
test_the_event_name_is_passed_back() {
  setup_hook
  hook '{"prompt":"/flow-qa SCRUM-1","session_id":"s1","hook_event_name":"SomethingElse"}'
  assert_rules_added SomethingElse
}
test_sessions_older_than_a_week_are_removed_but_not_codex_ran() {
  setup_hook
  mkdir -p "$S"; echo "last a reply" > "$S/old-session"; echo "abc" > "$S/codex-ran"
  touch -t 202001010000 "$S/old-session" "$S/codex-ran"
  prompt "/flow-start SCRUM-1" s13
  assert_no_file "$S/old-session"; assert_file "$S/codex-ran"; assert_file "$S/s13"
}
test_a_codex_prompt_leaves_codex_ran_with_the_hooks_file_hash() {
  setup_hook
  hook '{"prompt":"hello","session_id":"cx1","turn_id":"t1"}'
  assert_nothing
  assert_eq "$(cat "$S/codex-ran")" "$(shasum -a 256 "$A/.codex/hooks.json" | cut -d' ' -f1)"
  assert_no_file "$S/cx1"
}
test_a_claude_code_prompt_leaves_no_codex_ran() {
  setup_hook
  prompt "/flow-start SCRUM-3" s15
  assert_rules_added
  assert_no_file "$S/codex-ran"
}
test_a_session_folder_that_cannot_be_made_still_adds_the_rules() {
  setup_hook
  mkdir -p "$A/local"; echo "a file" > "$A/local/not-a-folder"
  export CARD_SESSIONS_DIR="$A/local/not-a-folder/sessions"
  prompt "/flow-start SCRUM-3" s15
  assert_rules_added
}
test_without_the_rules_file_nothing_happens() {
  setup_hook
  rm -f "$A/rulesets/card-rules.md"
  prompt "/flow-develop SCRUM-1" s1
  assert_nothing; assert_no_file "$S/s1"
}
test_without_the_project_settings_nothing_happens() {
  setup_hook
  rm -f "$A/config/project-settings.sh"
  prompt "/flow-develop SCRUM-1" s1
  assert_nothing; assert_no_file "$S/s1"
}
test_without_jq_nothing_happens() {
  setup_hook
  mkdir -p "$T/nojq"; ln -s "$(command -v dirname)" "$T/nojq/dirname"
  OUT="$(cd "$A" && printf '{"prompt":"/flow-develop SCRUM-1","session_id":"s1"}' | PATH="$T/nojq" /bin/bash scripts/card-rules-hook.sh 2>&1)"; RC=$?
  assert_nothing; assert_no_file "$S/s1"
}

# ---------------------------------------------------------------- after a summary of the conversation
test_a_session_start_that_is_not_a_summary_does_nothing() {
  setup_hook
  prompt "/flow-develop SCRUM-1" s1; rules_read SCRUM-1
  hook '{"hook_event_name":"SessionStart","source":"startup","session_id":"s1"}'
  assert_nothing
  assert_eq "$(grep -c -x summarized "$A/local/rules-read/SCRUM-1")" "0"
}
test_a_summary_in_a_session_not_on_a_card_does_nothing() {
  setup_hook
  rules_read SCRUM-1
  hook '{"hook_event_name":"SessionStart","source":"compact","session_id":"other"}'
  assert_nothing
  hook '{"hook_event_name":"SessionStart","source":"compact"}'
  assert_nothing
  assert_eq "$(grep -c -x summarized "$A/local/rules-read/SCRUM-1")" "0"
}
test_claude_code_after_a_summary_flags_the_session_cards_and_adds_the_note() {
  setup_hook
  prompt "/flow-develop SCRUM-1" s1; rules_read SCRUM-1; rules_read SCRUM-2
  hook '{"hook_event_name":"SessionStart","source":"compact","session_id":"s1"}'
  assert_rc 0
  printf '%s' "$OUT" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart" and
    (.hookSpecificOutput.additionalContext | startswith("The conversation was just summarized (closio-agent'"'"'s card hook).")
      and contains("bash scripts/run.sh rules <KEY> read") and contains("# Card rules"))' >/dev/null || fail "the note: $OUT"
  assert_eq "$(tail -1 "$A/local/rules-read/SCRUM-1")" "summarized"
  assert_eq "$(grep -c -x summarized "$A/local/rules-read/SCRUM-2")" "0" "a card of another session isn't flagged"
}
test_codex_after_a_summary_flags_the_rules_once_and_adds_no_text() {
  setup_hook
  prompt "/flow-develop SCRUM-1" s1; rules_read SCRUM-1
  hook '{"hook_event_name":"PostCompact","session_id":"s1","turn_id":"t1"}'
  assert_nothing
  hook '{"hook_event_name":"PostCompact","session_id":"s1"}'
  assert_nothing
  assert_eq "$(grep -c -x summarized "$A/local/rules-read/SCRUM-1")" "1"
  assert_file "$S/codex-ran"
}
test_a_summary_in_a_session_without_keys_flags_every_card() {
  setup_hook
  mkdir -p "$S"; echo "last a reply" > "$S/s3"
  rules_read SCRUM-1; rules_read SCRUM-2
  hook '{"hook_event_name":"PostCompact","session_id":"s3"}'
  assert_nothing
  assert_eq "$(tail -1 "$A/local/rules-read/SCRUM-1")" "summarized"
  assert_eq "$(tail -1 "$A/local/rules-read/SCRUM-2")" "summarized"
}
test_a_summary_makes_no_rules_file_for_a_card_that_never_read_them() {
  setup_hook
  prompt "/flow-develop SCRUM-9" s1
  hook '{"hook_event_name":"PostCompact","session_id":"s1"}'
  assert_nothing
  assert_no_file "$A/local/rules-read/SCRUM-9"
}
