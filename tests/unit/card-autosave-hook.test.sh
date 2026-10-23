# scripts/card-autosave-hook.sh: at the end of a reply in a card session, commits and pushes the card's folder to its
# own branch runs/<KEY> (through run.sh unsaved and save), never main, never forced; problems are one warning line.

# closio-agent in git with a bare origin; SCRUM-1 picked up and saved
setup_card() {
  sandbox .gitignore rulesets/card-rules.md .codex/hooks.json
  sandbox_git; sandbox_remote
  S="$A/local/card-sessions"
  run run.sh branch SCRUM-1; assert_rc 0
  run run.sh create SCRUM-1 "Test card"; assert_rc 0
  run run.sh save SCRUM-1 "picked up"; assert_rc 0
}
new_card() { # <key>: another card, picked up and saved
  run run.sh branch "$1"; run run.sh create "$1" "Card $1"; run run.sh save "$1" "picked up"; assert_rc 0
}
session() { # <session> <note lines…>: the card-rules hook's note for a session
  mkdir -p "$S"; local s="$1"; shift; printf '%s\n' "$@" > "$S/$s"
}
autosave() { # <session>
  OUT="$(cd "$A" && printf '{"session_id":"%s"}' "$1" | bash scripts/card-autosave-hook.sh 2>&1)"; RC=$?
}
remote_msg() { git -C "$T/origin.git" log -1 --format=%s "refs/heads/runs/$1" 2>/dev/null; }
remote_sha() { git -C "$T/origin.git" rev-parse -q --verify "refs/heads/runs/$1" 2>/dev/null; }
change() { echo "| x | develop ${2:-1} | something | — |" >> "$A/runs/$1/history.md"; }
# A teammate saves newer work on runs/SCRUM-1 on origin, and this Mac fetches it
teammate_saves() {
  git clone -q "$T/origin.git" "$T/mate" 2>/dev/null; git -C "$T/mate" checkout -q runs/SCRUM-1
  echo "teammate" >> "$T/mate/runs/SCRUM-1/history.md"
  git -C "$T/mate" commit -q -am "SCRUM-1: teammate's save" && git -C "$T/mate" push -q origin runs/SCRUM-1 || fail "the teammate's save"
  git -C "$A" fetch -q origin
}

test_a_changed_folder_is_saved_and_pushed_quietly() {
  setup_card; session s1 "key SCRUM-1" "last /flow-develop"
  change SCRUM-1
  autosave s1
  assert_rc 0; assert_eq "$OUT" ""
  assert_eq "$(remote_msg SCRUM-1)" "SCRUM-1: auto-saved after /flow-develop"
  assert_contains "$(git -C "$T/origin.git" show refs/heads/runs/SCRUM-1:runs/SCRUM-1/history.md)" "| x | develop 1 | something |"
  assert_eq "$(git -C "$A" rev-parse --abbrev-ref HEAD)" "main" "this folder stays on main"
  assert_eq "$(git -C "$T/origin.git" rev-parse refs/heads/main)" "$(git -C "$A" rev-parse main)" "main isn't pushed to"
}
test_nothing_changed_pushes_nothing() {
  setup_card; session s1 "key SCRUM-1" "last /flow-develop"
  before="$(remote_sha SCRUM-1)"
  autosave s1
  assert_rc 0; assert_eq "$OUT" ""; assert_eq "$(remote_sha SCRUM-1)" "$before"
}
test_a_session_not_working_on_a_card_saves_nothing() {
  setup_card
  before="$(remote_sha SCRUM-1)"; change SCRUM-1
  autosave not-a-card-session
  assert_rc 0; assert_eq "$OUT" ""; assert_eq "$(remote_sha SCRUM-1)" "$before"
}
test_after_a_reply_the_message_says_a_reply() {
  setup_card; session s2 "key SCRUM-1" "last a reply"
  change SCRUM-1
  autosave s2
  assert_eq "$(remote_msg SCRUM-1)" "SCRUM-1: auto-saved after a reply"
}
test_a_note_without_a_last_line_says_a_reply() {
  setup_card; session s2 "key SCRUM-1"
  change SCRUM-1
  autosave s2
  assert_eq "$(remote_msg SCRUM-1)" "SCRUM-1: auto-saved after a reply"
}
test_a_session_that_named_no_key_saves_every_card_folder() {
  setup_card; new_card SCRUM-2; session s3 "last /flow-develop"
  mkdir -p "$A/runs/not-a-card"
  change SCRUM-1; change SCRUM-2
  autosave s3
  assert_rc 0; assert_eq "$OUT" ""
  assert_eq "$(remote_msg SCRUM-1)" "SCRUM-1: auto-saved after /flow-develop"
  assert_eq "$(remote_msg SCRUM-2)" "SCRUM-2: auto-saved after /flow-develop"
  run run.sh unsaved SCRUM-1; assert_rc 1
}
test_only_the_session_cards_are_saved() {
  setup_card; new_card SCRUM-2; session s1 "key SCRUM-2" "last /flow-verify"
  before="$(remote_sha SCRUM-1)"
  change SCRUM-1; change SCRUM-2
  autosave s1
  assert_eq "$(remote_sha SCRUM-1)" "$before"
  assert_eq "$(remote_msg SCRUM-2)" "SCRUM-2: auto-saved after /flow-verify"
}
test_a_card_without_its_branch_here_is_skipped_quietly() {
  setup_card; session s1 "key SCRUM-1" "key SCRUM-2" "last a reply"
  mkdir -p "$A/runs/SCRUM-2"; echo "card: SCRUM-2" > "$A/runs/SCRUM-2/state.md"
  autosave s1
  assert_rc 0; assert_eq "$OUT" ""
  assert_eq "$(remote_sha SCRUM-2)" ""
}
test_a_save_not_pushed_yet_is_pushed() {
  setup_card; session s1 "key SCRUM-1" "last /flow-push"
  git -C "$A" remote set-url origin "$T/nowhere.git"
  change SCRUM-1
  run run.sh save SCRUM-1 "offline"; assert_rc 1
  git -C "$A" remote set-url origin "$T/origin.git"
  autosave s1
  assert_rc 0; assert_eq "$OUT" ""
  assert_eq "$(remote_msg SCRUM-1)" "SCRUM-1: offline"
}
test_a_teammate_newer_save_and_nothing_here_is_left_alone() {
  setup_card; session s2 "key SCRUM-1" "last /flow-develop"
  teammate_saves
  autosave s2
  assert_rc 0; assert_eq "$OUT" ""
  assert_eq "$(remote_msg SCRUM-1)" "SCRUM-1: teammate's save"
}
test_a_teammate_newer_save_and_a_change_here_is_one_warning_never_forced() {
  setup_card; session s2 "key SCRUM-1" "last /flow-develop"
  teammate_saves
  change SCRUM-1
  autosave s2
  assert_rc 0
  assert_eq "$(printf '%s' "$OUT" | jq -r .systemMessage)" "⚠️ Auto-save of SCRUM-1's folder: Saved on runs/SCRUM-1 on this Mac, but a teammate saved newer work on origin first, so the push was refused. Fix: Ask the user which to keep; compare them with: git log --oneline runs/SCRUM-1 origin/runs/SCRUM-1 (nothing is lost: both are kept). It tries again after your next reply."
  assert_eq "$(remote_msg SCRUM-1)" "SCRUM-1: teammate's save" "theirs is kept"
}
test_a_failed_push_is_a_warning_and_never_blocks() {
  setup_card; session s2 "key SCRUM-1" "last /flow-develop"
  git -C "$A" remote set-url origin "$T/nowhere.git"
  change SCRUM-1
  autosave s2
  assert_rc 0
  assert_eq "$(printf '%s' "$OUT" | jq -r .systemMessage)" "⚠️ Auto-save of SCRUM-1's folder: Saved on runs/SCRUM-1 on this Mac, but the push to origin failed. Fix: Check your network and GitHub login, then run: bash scripts/run.sh save SCRUM-1 \"auto-saved after /flow-develop\" (it pushes what's already saved). It tries again after your next reply."
}
test_two_failed_cards_are_two_warning_lines() {
  setup_card; new_card SCRUM-2; session s2 "key SCRUM-1" "key SCRUM-2" "last a reply"
  git -C "$A" remote set-url origin "$T/nowhere.git"
  change SCRUM-1; change SCRUM-2
  autosave s2
  assert_rc 0
  msg="$(printf '%s' "$OUT" | jq -r .systemMessage)"
  assert_eq "$(printf '%s\n' "$msg" | wc -l | tr -d ' ')" "2"
  assert_match "$msg" "^⚠️ Auto-save of SCRUM-1's folder: "
  assert_match "$(printf '%s\n' "$msg" | tail -1)" "^⚠️ Auto-save of SCRUM-2's folder: "
}
test_bad_input_or_no_session_does_nothing() {
  setup_card
  OUT="$(cd "$A" && printf 'nope' | bash scripts/card-autosave-hook.sh 2>&1)"; RC=$?
  assert_rc 0; assert_eq "$OUT" ""
  autosave ""
  assert_rc 0; assert_eq "$OUT" ""
  autosave '../../etc'
  assert_rc 0; assert_eq "$OUT" ""
}
test_without_jq_or_the_project_settings_nothing_happens() {
  setup_card; session s1 "key SCRUM-1" "last a reply"
  before="$(remote_sha SCRUM-1)"; change SCRUM-1
  mkdir -p "$T/nojq"; ln -s "$(command -v dirname)" "$T/nojq/dirname"
  OUT="$(cd "$A" && printf '{"session_id":"s1"}' | PATH="$T/nojq" /bin/bash scripts/card-autosave-hook.sh 2>&1)"; RC=$?
  assert_rc 0; assert_eq "$OUT" ""
  rm -f "$A/config/project-settings.sh"
  autosave s1
  assert_rc 0; assert_eq "$OUT" ""
  assert_eq "$(remote_sha SCRUM-1)" "$before"
}
