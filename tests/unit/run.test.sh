# scripts/run.sh: the card's run folder runs/<KEY>/, saved on its own branch runs/<KEY> of closio-agent (never main).

# closio-agent in git with a bare origin ($T/origin.git); the rules files for "rules" and "step"
setup_run() {
  sandbox .gitignore AGENTS.md docs/agent-rules.md
  sandbox_git; sandbox_remote
}
card() { # <key> [<title>]: picked up (branch + create)
  run run.sh branch "$1"; assert_rc 0
  run run.sh create "$1" "${2:-Test card}"; assert_rc 0
}
saved_card() { card "$@"; run run.sh save "$1" "picked up"; assert_rc 0; }
st() { cat "$A/runs/$1/state.md"; }
hist_last() { tail -1 "$A/runs/$1/history.md"; }
remote_msg() { git -C "$T/origin.git" log -1 --format=%s "refs/heads/runs/$1" 2>/dev/null; }
remote_sha() { git -C "$T/origin.git" rev-parse -q --verify "refs/heads/runs/$1" 2>/dev/null; }
local_sha() { git -C "$A" rev-parse -q --verify "refs/heads/runs/$1" 2>/dev/null; }
offline() { git -C "$A" remote set-url origin "$T/nowhere.git"; }
online() { git -C "$A" remote set-url origin "$T/origin.git"; }
# A teammate saves newer work on runs/<KEY> on origin (a clone in $T/mate)
teammate_saves() { # <key> [<text>]
  [ -d "$T/mate" ] || git clone -q "$T/origin.git" "$T/mate" 2>/dev/null
  git -C "$T/mate" fetch -q origin && git -C "$T/mate" checkout -q -B "runs/$1" "origin/runs/$1" || fail "the teammate's checkout"
  echo "${2:-teammate}" >> "$T/mate/runs/$1/history.md"
  git -C "$T/mate" commit -q -am "$1: teammate's save" && git -C "$T/mate" push -q origin "runs/$1" || fail "the teammate's save"
}
NOW_RE='[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}'

# ---------------------------------------------------------------- check-folder
test_check_folder_in_the_closio_agent_folder() {
  setup_run
  run run.sh check-folder
  assert_rc 0; assert_eq "$OUT" "✅ Started in the closio-agent folder"
}
test_check_folder_from_another_folder() {
  setup_run
  run_in "$T" bash "$A/scripts/run.sh" check-folder
  assert_rc 1
  assert_contains "$OUT" "❌ Not started in the closio-agent folder (current folder: $(cd "$T" && pwd))"
  assert_contains "$OUT" "   Fix: Quit, open a terminal in "; assert_contains "$OUT" "run 'nvm use v22', then start Claude Code or Codex again."
}

# ---------------------------------------------------------------- branch
test_branch_outside_a_git_repo() {
  sandbox
  run run.sh branch SCRUM-1
  assert_rc 1
  assert_eq "$OUT" "❌ closio-agent isn't a git repository here
   Fix: Clone it from GitHub (setup guide, section 1) and start again."
}
test_branch_makes_the_card_branch_from_origin_main_without_switching() {
  setup_run
  echo "newer" > "$T/x"; git -C "$A" commit -q --allow-empty -m "local only"
  run run.sh branch SCRUM-1
  assert_rc 0
  assert_eq "$OUT" "✅ The card's saved copy is made: branch runs/SCRUM-1 (from origin/main); the card's folder is saved there, never on main
✅ The card's saved copy (branch runs/SCRUM-1) is ready; no card folder yet (create it next)"
  assert_eq "$(local_sha SCRUM-1)" "$(git -C "$A" rev-parse origin/main)"
  assert_eq "$(git -C "$A" rev-parse --abbrev-ref HEAD)" "main"
}
test_branch_without_a_remote_warns_and_uses_main() {
  sandbox .gitignore; sandbox_git
  run run.sh branch SCRUM-1
  assert_rc 0
  assert_contains "$OUT" "⚠️ Couldn't fetch from origin (no network?)
   Tip: A teammate's newer save may be missed; carrying on with what's on this Mac."
  assert_contains "$OUT" "✅ The card's saved copy is made: branch runs/SCRUM-1 (from main)"
}
test_branch_brings_a_teammate_card_from_origin() {
  setup_run; saved_card SCRUM-1
  rm -rf "$A/runs/SCRUM-1"; git -C "$A" branch -q -D runs/SCRUM-1
  run run.sh branch SCRUM-1
  assert_rc 0
  assert_eq "$OUT" "✅ The card's branch runs/SCRUM-1 came from origin (a teammate already worked on this card)
✅ Brought runs/SCRUM-1 onto this Mac from the branch runs/SCRUM-1 (this folder stays on main)"
  assert_contains "$(st SCRUM-1)" "title: Test card"
  assert_eq "$(git -C "$A" status --porcelain)" "" "main's working tree is clean"
}
test_branch_with_the_folder_already_here() {
  setup_run; saved_card SCRUM-1
  run run.sh branch SCRUM-1
  assert_rc 0
  assert_eq "$OUT" "✅ The card's folder runs/SCRUM-1 is on this Mac (its saved copy: branch runs/SCRUM-1; this folder stays on main)"
}
test_branch_takes_a_teammate_newer_save_when_nothing_here_is_unsaved() {
  setup_run; saved_card SCRUM-1
  teammate_saves SCRUM-1 "| t | develop 2 | the teammate's step | — |"
  run run.sh branch SCRUM-1
  assert_rc 0
  assert_contains "$OUT" "✅ Brought a teammate's newer save of runs/SCRUM-1 from origin"
  assert_contains "$(cat "$A/runs/SCRUM-1/history.md")" "the teammate's step"
  assert_eq "$(local_sha SCRUM-1)" "$(remote_sha SCRUM-1)"
}
test_branch_refuses_a_teammate_newer_save_over_unsaved_work() {
  setup_run; saved_card SCRUM-1
  teammate_saves SCRUM-1
  echo "| mine | develop 2 | my unsaved step | — |" >> "$A/runs/SCRUM-1/history.md"
  run run.sh branch SCRUM-1
  assert_rc 1
  assert_contains "$OUT" "❌ A teammate saved newer work on runs/SCRUM-1, and runs/SCRUM-1 here has changes that aren't saved"
  assert_contains "$OUT" "   Fix: Ask the user which to keep."
  assert_contains "$(cat "$A/runs/SCRUM-1/history.md")" "my unsaved step"
  assert_not_contains "$(cat "$A/runs/SCRUM-1/history.md")" "teammate"
}
test_branch_when_both_saved_the_card() {
  setup_run; saved_card SCRUM-1
  offline; echo "mine" >> "$A/runs/SCRUM-1/history.md"; run run.sh save SCRUM-1 "mine"; assert_rc 1; online
  teammate_saves SCRUM-1
  run run.sh branch SCRUM-1
  assert_rc 1
  assert_eq "$OUT" "❌ runs/SCRUM-1 on this Mac and on origin have both moved on (two people saved this card)
   Fix: Ask the user which to keep; compare them with: git log --oneline runs/SCRUM-1 origin/runs/SCRUM-1"
}
test_branch_with_a_save_here_not_pushed_yet() {
  setup_run; saved_card SCRUM-1
  offline; echo "mine" >> "$A/runs/SCRUM-1/history.md"; run run.sh save SCRUM-1 "mine"; online
  run run.sh branch SCRUM-1
  assert_rc 0
  assert_eq "$OUT" "✅ The card's folder runs/SCRUM-1 is on this Mac (its saved copy: branch runs/SCRUM-1; this folder stays on main)"
}

# ---------------------------------------------------------------- create
test_create_writes_the_state_and_the_history() {
  setup_run
  run run.sh branch SCRUM-1
  run run.sh create SCRUM-1 "Scheme list filter"
  assert_rc 0
  assert_eq "$OUT" "✅ Run folder created: runs/SCRUM-1/ (state.md, history.md) on the branch runs/SCRUM-1"
  # Empty fields are "<field>: " (with the space); compared here without the trailing spaces
  assert_eq "$(sed '$d' "$A/runs/SCRUM-1/state.md" | sed 's/[[:space:]]*$//')" "# SCRUM-1 — Scheme list filter
card: SCRUM-1
title: Scheme list filter
type:
size:
phase: pick-up
step: 1
jira_status:
repos:
branch:
run_branch: runs/SCRUM-1
next: /flow-start SCRUM-1"
  assert_eq "$(grep -c -x 'type: ' "$A/runs/SCRUM-1/state.md")" "1"
  assert_match "$(tail -1 "$A/runs/SCRUM-1/state.md")" "^updated: $NOW_RE\$"
  assert_contains "$(cat "$A/runs/SCRUM-1/history.md")" "| When | Step | What happened | Rules and memory applied |"
  assert_match "$(hist_last SCRUM-1)" "^\| $NOW_RE \| pick-up 1 \| Run folder created on the branch runs/SCRUM-1 \| rules: A1 · memory: — \|\$"
  assert_eq "$(git -C "$A" status --porcelain)" "" "the folder is git-ignored on main"
}
test_create_without_a_title() {
  setup_run
  run run.sh branch SCRUM-1; run run.sh create SCRUM-1
  assert_rc 0; assert_eq "$(head -1 "$A/runs/SCRUM-1/state.md")" "# SCRUM-1 — (title not read yet)"
}
test_create_before_the_branch_is_ready() {
  setup_run
  run run.sh create SCRUM-1 "x"
  assert_rc 1
  assert_eq "$OUT" "❌ The card's branch runs/SCRUM-1 isn't ready
   Fix: Run first: bash scripts/run.sh branch SCRUM-1"
  assert_no_file "$A/runs/SCRUM-1"
}
test_create_an_existing_folder_resumes() {
  setup_run; card SCRUM-1 "First"
  run run.sh create SCRUM-1 "Second"
  assert_rc 0
  assert_eq "$OUT" "⚠️ The card's folder runs/SCRUM-1 already exists (resuming)
   Tip: See where it stands: bash scripts/run.sh state SCRUM-1"
  assert_contains "$(st SCRUM-1)" "title: First"
}
test_create_when_the_folder_cannot_be_made() {
  setup_run
  run run.sh branch SCRUM-1
  echo "a file" > "$T/not-a-folder"
  export RUNS_DIR="$T/not-a-folder/runs"
  run run.sh create SCRUM-1 "x"
  assert_rc 1; assert_contains "$OUT" "❌ Couldn't create $T/not-a-folder/runs/SCRUM-1"; assert_contains "$OUT" "Fix: Check the folder's permissions."
}

# ---------------------------------------------------------------- state, status, get
test_state_from_this_mac() {
  setup_run; card SCRUM-1
  run run.sh state SCRUM-1
  assert_rc 0
  assert_eq "$OUT" "$(st SCRUM-1)

From: this Mac"
}
test_state_from_the_branch_on_this_mac() {
  setup_run; saved_card SCRUM-1
  rm -rf "$A/runs/SCRUM-1"
  run run.sh state SCRUM-1
  assert_rc 0
  assert_contains "$OUT" "card: SCRUM-1"
  assert_eq "$(printf '%s\n' "$OUT" | tail -1)" "From: the branch runs/SCRUM-1 on this Mac (not checked out)"
}
test_state_from_origin_only() {
  setup_run; saved_card SCRUM-1
  rm -rf "$A/runs/SCRUM-1"; git -C "$A" branch -q -D runs/SCRUM-1
  run run.sh state SCRUM-1
  assert_rc 0
  assert_contains "$OUT" "title: Test card"
  assert_eq "$(printf '%s\n' "$OUT" | tail -1)" "From: origin (pushed by a teammate; run: bash scripts/run.sh branch SCRUM-1)"
}
test_state_of_a_card_not_picked_up() {
  setup_run
  run run.sh state SCRUM-9
  assert_rc 1
  assert_eq "$OUT" "⚠️ No card folder for SCRUM-9 on this Mac, and no saved copy on origin
   Tip: Pick the card up with /flow-start SCRUM-9 (Codex: \$flow-start SCRUM-9)."
}
test_status_in_plain_words() {
  setup_run; card SCRUM-1 "Scheme list filter"
  run run.sh set SCRUM-1 phase develop
  run run.sh set SCRUM-1 next /flow-develop SCRUM-1
  run run.sh set SCRUM-1 jira_status In Development
  run run.sh set SCRUM-1 repos nodejs-ws2closio
  run run.sh set SCRUM-1 branch SCRUM-1/scheme-list-filter
  run run.sh set SCRUM-1 updated 2026-10-23 10:00
  run run.sh status SCRUM-1
  assert_rc 0
  assert_eq "$OUT" "SCRUM-1 · Scheme list filter
State: in development
Next: /flow-develop SCRUM-1
Jira: In Development
Repos: nodejs-ws2closio
Branch: SCRUM-1/scheme-list-filter
Updated: 2026-10-23 10:00"
}
test_status_names_every_phase_in_plain_words() {
  setup_run; card SCRUM-1
  local pair
  for pair in "pick-up:being picked up" "plan:planning" "develop:in development" "verify:being checked" \
              "ship:ready to push" "after-merge:waiting for the merge" "done:finished" "odd:odd"; do
    run run.sh set SCRUM-1 phase "${pair%%:*}"
    run run.sh status SCRUM-1
    assert_contains "$OUT" "State: ${pair#*:}"
  done
}
test_status_of_a_card_saved_only_on_origin() {
  setup_run; saved_card SCRUM-1
  rm -rf "$A/runs/SCRUM-1"; git -C "$A" branch -q -D runs/SCRUM-1
  run run.sh status SCRUM-1
  assert_rc 0
  assert_eq "$(printf '%s\n' "$OUT" | tail -1)" "Saved only in origin (pushed by a teammate; run: bash scripts/run.sh branch SCRUM-1)"
}
test_status_of_a_card_not_picked_up() {
  setup_run
  run run.sh status SCRUM-9
  assert_rc 1; assert_contains "$OUT" "⚠️ No card folder for SCRUM-9 on this Mac"
}
test_get_one_field() {
  setup_run; card SCRUM-1 "Scheme list filter"
  run run.sh get SCRUM-1 title
  assert_rc 0; assert_eq "$OUT" "Scheme list filter"
  run run.sh get SCRUM-1 phase
  assert_eq "$OUT" "pick-up"
  run run.sh get SCRUM-1 nothing
  assert_rc 0; assert_eq "$OUT" ""
}
test_get_without_a_field_or_a_card() {
  setup_run
  run run.sh get SCRUM-1
  assert_rc 2; assert_contains "$OUT" "Usage: bash scripts/run.sh check-folder"
  run run.sh get SCRUM-1 phase
  assert_rc 1; assert_eq "$OUT" ""
}

# ---------------------------------------------------------------- set, log
test_set_changes_a_field_and_the_updated_time() {
  setup_run; card SCRUM-1
  run run.sh set SCRUM-1 updated old
  assert_rc 0; assert_eq "$OUT" "✅ SCRUM-1: updated = old"
  assert_contains "$(st SCRUM-1)" "updated: old"
  run run.sh set SCRUM-1 next /flow-develop SCRUM-1
  assert_rc 0; assert_eq "$OUT" "✅ SCRUM-1: next = /flow-develop SCRUM-1"
  assert_contains "$(st SCRUM-1)" "
next: /flow-develop SCRUM-1
"
  assert_match "$(grep '^updated:' "$A/runs/SCRUM-1/state.md")" "^updated: $NOW_RE\$"
  assert_eq "$(grep -c '^next:' "$A/runs/SCRUM-1/state.md")" "1"
}
test_set_adds_a_field_the_file_does_not_have_yet() {
  setup_run; card SCRUM-1
  sed -i '' '/^size:/d' "$A/runs/SCRUM-1/state.md"
  run run.sh set SCRUM-1 size small
  assert_rc 0; assert_contains "$(st SCRUM-1)" "size: small"
}
test_set_a_field_that_is_not_in_the_state() {
  setup_run; card SCRUM-1
  run run.sh set SCRUM-1 colour blue
  assert_rc 2
  assert_eq "$OUT" "❌ 'colour' isn't a state field
   Fix: Fields: card title type size phase step jira_status jira_comment repos branch run_branch next updated"
}
test_set_without_a_folder_or_a_value() {
  setup_run
  run run.sh set SCRUM-1 phase develop
  assert_rc 1
  assert_eq "$OUT" "❌ No card folder for SCRUM-1 on this Mac
   Fix: Run: bash scripts/run.sh branch SCRUM-1 (then create it if it's new)."
  run run.sh set SCRUM-1 phase
  assert_rc 2; assert_contains "$OUT" "Usage:"
}
test_log_appends_one_history_line_as_one_table_cell() {
  setup_run; card SCRUM-1
  run run.sh log SCRUM-1 "develop 2" "wrote a | b
and more" "rules: A13 · memory: M2"
  assert_rc 0; assert_eq "$OUT" "✅ SCRUM-1: history: develop 2: wrote a \\| b and more"
  assert_match "$(hist_last SCRUM-1)" "^\| $NOW_RE \| develop 2 \| wrote a \\\\\| b and more \| rules: A13 · memory: M2 \|\$"
  run run.sh log SCRUM-1 "develop 3" "no rules named"
  assert_contains "$(hist_last SCRUM-1)" "| develop 3 | no rules named | rules: — · memory: — |"
}
test_log_without_a_folder_or_text() {
  setup_run
  run run.sh log SCRUM-1 "develop 1" "x"
  assert_rc 1; assert_contains "$OUT" "❌ No card folder for SCRUM-1 on this Mac"
  run run.sh log SCRUM-1 "develop 1"
  assert_rc 2; assert_contains "$OUT" "Usage:"
}

# ---------------------------------------------------------------- rules and step (one call after every step)
test_step_before_the_rules_were_read_asks_to_read_them() {
  setup_run; card SCRUM-1
  run run.sh step SCRUM-1 "develop 1" "x" "rules: A13 · memory: —" --next 2
  assert_rc 0
  assert_eq "$OUT" "✅ SCRUM-1: history: develop 1: x · next step 2
⚠️ Rules: not read in this command yet. Read AGENTS.md and docs/agent-rules.md in full now, then: bash scripts/run.sh rules SCRUM-1 read"
  assert_contains "$(hist_last SCRUM-1)" "| develop 1 | x | rules: A13 · memory: — |"
  assert_contains "$(st SCRUM-1)" "step: 2"
}
test_rules_read_keeps_the_two_fingerprints() {
  setup_run; card SCRUM-1
  before="$(wc -l < "$A/runs/SCRUM-1/history.md")"
  run run.sh rules SCRUM-1 read
  assert_rc 0; assert_eq "$OUT" "✅ SCRUM-1: rules read (AGENTS.md, docs/agent-rules.md)"
  assert_match "$(cat "$A/local/rules-read/SCRUM-1")" "^AGENTS.md [0-9a-f]{12}
docs/agent-rules.md [0-9a-f]{12}\$"
  assert_eq "$(wc -l < "$A/runs/SCRUM-1/history.md")" "$before" "no history line on a first read"
}
test_step_after_the_rules_were_read_in_one_call() {
  setup_run; card SCRUM-1
  run run.sh rules SCRUM-1 read
  run run.sh step SCRUM-1 "develop 2" "wrote the service" "rules: A13, A16 · memory: M2" --next 3 --memory develop all
  assert_rc 0
  assert_contains "$OUT" "✅ SCRUM-1: history: develop 2: wrote the service · next step 3
✅ Rules: unchanged since you read them
User memory: nothing applies to this command (that's normal)."
  assert_contains "$(hist_last SCRUM-1)" "| develop 2 | wrote the service | rules: A13, A16 · memory: M2 |"
  run run.sh get SCRUM-1 step
  assert_eq "$OUT" "3"
}
test_step_without_next_keeps_the_step_number() {
  setup_run; card SCRUM-1
  run run.sh rules SCRUM-1 read
  run run.sh step SCRUM-1 "review 1" "r" "rules: — · memory: —"
  assert_rc 0
  assert_eq "$OUT" "✅ SCRUM-1: history: review 1: r
✅ Rules: unchanged since you read them"
  assert_contains "$(st SCRUM-1)" "step: 1"
}
test_step_names_a_rules_file_that_changed_and_reading_again_notes_it() {
  setup_run; card SCRUM-1
  run run.sh rules SCRUM-1 read
  echo "- a new rule" >> "$A/docs/agent-rules.md"
  run run.sh step SCRUM-1 "develop 3" "y" "rules: — · memory: —" --next 4
  assert_contains "$OUT" "⚠️ Rules changed since you read them: docs/agent-rules.md. Read it again before the next step, then: bash scripts/run.sh rules SCRUM-1 read"
  run run.sh rules SCRUM-1 read
  assert_rc 0
  assert_eq "$OUT" "✅ SCRUM-1: rules read again; they changed (docs/agent-rules.md): noted in the card's history"
  assert_contains "$(hist_last SCRUM-1)" "| rules | the rules changed (docs/agent-rules.md): read again from here | rules: read again |"
  run run.sh step SCRUM-1 "develop 4" "z" "rules: — · memory: —"
  assert_contains "$OUT" "✅ Rules: unchanged since you read them"
}
test_step_after_a_summary_asks_for_a_full_read_and_reading_clears_it() {
  setup_run; card SCRUM-1
  run run.sh rules SCRUM-1 read
  echo summarized >> "$A/local/rules-read/SCRUM-1"
  run run.sh step SCRUM-1 "develop 5" "w" "rules: — · memory: —"
  assert_contains "$OUT" "⚠️ Rules: the conversation was summarized since you read them. Read AGENTS.md and docs/agent-rules.md in full again now, then: bash scripts/run.sh rules SCRUM-1 read"
  before="$(wc -l < "$A/runs/SCRUM-1/history.md")"
  run run.sh rules SCRUM-1 read
  assert_eq "$OUT" "✅ SCRUM-1: rules read (AGENTS.md, docs/agent-rules.md)"
  assert_eq "$(grep -c -x summarized "$A/local/rules-read/SCRUM-1")" "0"
  assert_eq "$(wc -l < "$A/runs/SCRUM-1/history.md")" "$before"
}
test_rules_read_again_after_a_change_without_a_card_folder() {
  setup_run
  run run.sh rules SCRUM-1 read
  echo "x" >> "$A/AGENTS.md"
  run run.sh rules SCRUM-1 read
  assert_rc 0; assert_eq "$OUT" "✅ SCRUM-1: rules read (AGENTS.md, docs/agent-rules.md)"
}
test_rules_when_its_folder_cannot_be_made() {
  setup_run; card SCRUM-1
  echo "a file" > "$T/not-a-folder"
  export RULES_READ_DIR="$T/not-a-folder/rules"
  run run.sh rules SCRUM-1 read
  assert_rc 1; assert_contains "$OUT" "❌ Couldn't create $T/not-a-folder/rules"
}
test_rules_wrong_usage() {
  setup_run
  run run.sh rules SCRUM-1
  assert_rc 2; assert_contains "$OUT" "Usage:"
  run run.sh rules SCRUM-1 read now
  assert_rc 2
}
test_step_wrong_usage() {
  setup_run; card SCRUM-1
  run run.sh step SCRUM-1 "develop 5" "z" "rules: —" --next x
  assert_rc 2; assert_contains "$OUT" "Usage:"
  run run.sh step SCRUM-1 "develop 5" "z" "rules: —" --next
  assert_rc 2
  run run.sh step SCRUM-1 "develop 5" "z" "rules: —" --memory
  assert_rc 2
  run run.sh step SCRUM-1 "develop 5" "z" "rules: —" --later
  assert_rc 2
  run run.sh step SCRUM-1 "develop 5" "z"
  assert_rc 2
  assert_not_contains "$(cat "$A/runs/SCRUM-1/history.md")" "develop 5"
}
test_step_without_a_card_folder() {
  setup_run
  run run.sh step SCRUM-1 "develop 1" "x" "rules: —"
  # Today's behaviour: do_step sends do_log's output to /dev/null, so the ❌ and its fix aren't shown (exit 1 only).
  assert_rc 1; assert_eq "$OUT" ""
}

# ---------------------------------------------------------------- decide
test_decide_numbers_each_decision_in_its_own_file() {
  setup_run; card SCRUM-1
  run run.sh decide SCRUM-1 "plan 2" "Error code for a bad status?" "VALIDATION_ERROR" "you: recommended"
  assert_rc 0; assert_eq "$OUT" "✅ SCRUM-1: decision 1: Error code for a bad status? → VALIDATION_ERROR"
  f="$A/runs/SCRUM-1/decisions.md"
  assert_eq "$(head -1 "$f")" "# SCRUM-1 — decisions"
  assert_contains "$(cat "$f")" "| No. | When | Step | Question | Decided | Who / why |
|---|---|---|---|---|---|"
  run run.sh decide SCRUM-1 "plan 3" "Which a | b?
Two lines" "a | b" "memory M2"
  assert_rc 0; assert_eq "$OUT" "✅ SCRUM-1: decision 2: Which a | b? Two lines → a | b"
  assert_match "$(tail -1 "$f")" "^\| 2 \| $NOW_RE \| plan 3 \| Which a \\\\\| b\? Two lines \| a \\\\\| b \| memory M2 \|\$"
  assert_eq "$(grep -c -E '^\| [0-9]+ \|' "$f")" "2"
}
test_decide_without_a_folder_or_all_parts() {
  setup_run
  run run.sh decide SCRUM-1 "plan 1" "q" "d" "you"
  assert_rc 1; assert_contains "$OUT" "❌ No card folder for SCRUM-1 on this Mac"
  run run.sh decide SCRUM-1 "plan 1" "q" "d"
  assert_rc 2; assert_contains "$OUT" "Usage:"
}

# ---------------------------------------------------------------- save, unsaved
test_save_pushes_the_folder_to_the_card_branch_without_touching_main() {
  setup_run; card SCRUM-1
  echo "staged on main" > "$A/notes.txt"; git -C "$A" add notes.txt
  status_before="$(git -C "$A" status --porcelain)"; main_before="$(git -C "$A" rev-parse main)"
  run run.sh save SCRUM-1 "picked up"
  assert_rc 0
  assert_eq "$OUT" "✅ Saved and pushed: runs/SCRUM-1 on runs/SCRUM-1 (SCRUM-1: picked up); this folder stays on main"
  assert_eq "$(remote_msg SCRUM-1)" "SCRUM-1: picked up"
  assert_eq "$(git -C "$T/origin.git" ls-tree --name-only "runs/SCRUM-1" runs/SCRUM-1/ | sort | tr '\n' ' ')" "runs/SCRUM-1/history.md runs/SCRUM-1/state.md "
  assert_eq "$(git -C "$T/origin.git" rev-parse "runs/SCRUM-1^")" "$main_before" "the card's branch grows from main"
  assert_eq "$(git -C "$A" status --porcelain)" "$status_before" "main's index and files are untouched"
  assert_eq "$(git -C "$A" rev-parse main)" "$main_before"
  assert_eq "$(git -C "$A" rev-parse --abbrev-ref HEAD)" "main"
}
test_save_with_nothing_new() {
  setup_run; saved_card SCRUM-1
  before="$(remote_sha SCRUM-1)"
  run run.sh save SCRUM-1
  assert_rc 0; assert_eq "$OUT" "✅ Nothing new to save in runs/SCRUM-1"
  assert_eq "$(remote_sha SCRUM-1)" "$before"
}
test_save_without_a_message_says_update() {
  setup_run; saved_card SCRUM-1
  echo "x" >> "$A/runs/SCRUM-1/history.md"
  run run.sh save SCRUM-1
  assert_rc 0; assert_eq "$(remote_msg SCRUM-1)" "SCRUM-1: update"
}
test_save_removes_files_deleted_from_the_folder() {
  setup_run; card SCRUM-1
  echo "plan" > "$A/runs/SCRUM-1/plan.md"; run run.sh save SCRUM-1 "plan"
  rm "$A/runs/SCRUM-1/plan.md"; run run.sh save SCRUM-1 "no plan"
  assert_rc 0
  assert_eq "$(git -C "$T/origin.git" ls-tree --name-only "runs/SCRUM-1" runs/SCRUM-1/ | grep -c plan.md)" "0"
}
test_save_when_the_push_fails_keeps_the_save_and_pushes_it_later() {
  setup_run; saved_card SCRUM-1
  offline; echo "x" >> "$A/runs/SCRUM-1/history.md"
  run run.sh save SCRUM-1 "offline save"
  assert_rc 1
  assert_eq "$OUT" "❌ Saved on runs/SCRUM-1 on this Mac, but the push to origin failed
   Fix: Check your network and GitHub login, then run: bash scripts/run.sh save SCRUM-1 \"offline save\" (it pushes what's already saved)."
  assert_eq "$(git -C "$A" log -1 --format=%s refs/heads/runs/SCRUM-1)" "SCRUM-1: offline save"
  online
  run run.sh save SCRUM-1 "again"
  assert_rc 0; assert_contains "$OUT" "✅ Saved and pushed: runs/SCRUM-1 on runs/SCRUM-1 (SCRUM-1: again)"
  assert_eq "$(remote_msg SCRUM-1)" "SCRUM-1: offline save"
}
test_save_after_a_teammate_newer_save_is_refused_and_both_are_kept() {
  setup_run; saved_card SCRUM-1
  teammate_saves SCRUM-1
  echo "mine" >> "$A/runs/SCRUM-1/history.md"
  run run.sh save SCRUM-1 "mine"
  assert_rc 1
  assert_eq "$OUT" "❌ Saved on runs/SCRUM-1 on this Mac, but a teammate saved newer work on origin first, so the push was refused
   Fix: Ask the user which to keep; compare them with: git log --oneline runs/SCRUM-1 origin/runs/SCRUM-1 (nothing is lost: both are kept)."
  assert_eq "$(remote_msg SCRUM-1)" "SCRUM-1: teammate's save"
  assert_eq "$(git -C "$A" log -1 --format=%s refs/heads/runs/SCRUM-1)" "SCRUM-1: mine"
}
test_save_without_a_folder_or_a_branch() {
  setup_run
  run run.sh save SCRUM-1 "x"
  assert_rc 1
  assert_eq "$OUT" "❌ No card folder runs/SCRUM-1 to save
   Fix: Run: bash scripts/run.sh branch SCRUM-1, then create it."
  mkdir -p "$A/runs/SCRUM-1"; echo x > "$A/runs/SCRUM-1/state.md"
  run run.sh save SCRUM-1 "x"
  assert_rc 1
  assert_eq "$OUT" "❌ The card's branch runs/SCRUM-1 isn't ready
   Fix: Run: bash scripts/run.sh branch SCRUM-1, then save again."
}
test_save_when_a_file_cannot_be_read() {
  setup_run; card SCRUM-1
  echo "secret-free" > "$A/runs/SCRUM-1/locked.md"; chmod 000 "$A/runs/SCRUM-1/locked.md"
  run run.sh save SCRUM-1 "x"
  chmod 644 "$A/runs/SCRUM-1/locked.md"
  assert_rc 1
  assert_eq "$(printf '%s\n' "$OUT" | tail -2)" "❌ Couldn't stage runs/SCRUM-1 for runs/SCRUM-1
   Fix: Check 'git status' in the closio-agent folder."
  assert_eq "$(remote_sha SCRUM-1)" ""
}
test_save_when_git_cannot_commit() {
  setup_run; card SCRUM-1
  export GIT_AUTHOR_NAME="" GIT_COMMITTER_NAME=""
  run run.sh save SCRUM-1 "x"
  assert_rc 1
  assert_eq "$(printf '%s\n' "$OUT" | tail -2)" "❌ Couldn't commit runs/SCRUM-1
   Fix: Check that git's name and email are set (/flow-configure-user), then save again."
}
test_unsaved_says_what_the_auto_save_needs() {
  setup_run
  run run.sh unsaved SCRUM-1
  assert_rc 1 "no folder: nothing to save"
  mkdir -p "$A/runs/SCRUM-1"
  run run.sh unsaved SCRUM-1
  assert_rc 3 "no branch here"
  rm -rf "$A/runs/SCRUM-1"; card SCRUM-1
  run run.sh unsaved SCRUM-1
  assert_rc 0 "a new folder"; assert_eq "$OUT" ""
  run run.sh save SCRUM-1 "picked up"
  run run.sh unsaved SCRUM-1
  assert_rc 1 "all on GitHub"
  echo x >> "$A/runs/SCRUM-1/history.md"
  run run.sh unsaved SCRUM-1
  assert_rc 0 "a change"
}
test_unsaved_with_a_save_not_pushed() {
  setup_run; card SCRUM-1
  offline; run run.sh save SCRUM-1 "never pushed"
  run run.sh unsaved SCRUM-1
  assert_rc 0 "saved here, never pushed"
  online; run run.sh save SCRUM-1; offline
  echo x >> "$A/runs/SCRUM-1/history.md"; run run.sh save SCRUM-1 "ahead"
  run run.sh unsaved SCRUM-1
  assert_rc 0 "saved here, ahead of origin"
}
test_unsaved_after_a_teammate_newer_save() {
  setup_run; saved_card SCRUM-1
  teammate_saves SCRUM-1; git -C "$A" fetch -q origin
  run run.sh unsaved SCRUM-1
  assert_rc 1
}

# ---------------------------------------------------------------- list, count, problems, quick-clean
test_list_with_no_card() {
  setup_run
  run run.sh list
  assert_rc 0; assert_eq "$OUT" "No card in progress (no card folder on this Mac, no saved copy on origin)."
  run run.sh count
  assert_eq "$OUT" "0"
}
test_list_shows_the_cards_in_progress_then_the_finished_ones() {
  setup_run
  saved_card SCRUM-1; run run.sh set SCRUM-1 phase develop; run run.sh set SCRUM-1 next /flow-develop SCRUM-1; run run.sh set SCRUM-1 updated u1
  saved_card SCRUM-2; run run.sh set SCRUM-2 phase done; run run.sh set SCRUM-2 jira_status Ready for Test; run run.sh set SCRUM-2 updated u2
  saved_card SCRUM-3; run run.sh set SCRUM-3 updated u3; run run.sh save SCRUM-3 "x"
  rm -rf "$A/runs/SCRUM-3"; git -C "$A" branch -q -D runs/SCRUM-3
  run run.sh branch SCRUM-4
  mkdir -p "$A/runs/notes"
  run run.sh list
  assert_rc 0
  assert_eq "$OUT" "SCRUM-1 · in development · next: /flow-develop SCRUM-1 · updated u1
SCRUM-3 · being picked up · next: /flow-start SCRUM-3 · updated u3 · only in origin (pushed by a teammate; run: bash scripts/run.sh branch SCRUM-3)
⚠️ SCRUM-4: the card's saved copy exists, but where it stands can't be read
   Tip: Run: bash scripts/run.sh branch SCRUM-4

Finished:
SCRUM-2 · finished (Ready for Test) · updated u2"
  run run.sh count
  assert_rc 0; assert_eq "$OUT" "3"
}
test_list_a_finished_card_only_on_origin() {
  setup_run
  card SCRUM-2; run run.sh set SCRUM-2 phase done; run run.sh set SCRUM-2 updated u2; run run.sh save SCRUM-2 "done"
  rm -rf "$A/runs/SCRUM-2"; git -C "$A" branch -q -D runs/SCRUM-2
  run run.sh list
  assert_eq "$OUT" "No card in progress (no card folder on this Mac, no saved copy on origin).

Finished:
SCRUM-2 · finished () · updated u2 · only in origin (pushed by a teammate; run: bash scripts/run.sh branch SCRUM-2)"
}
test_problems_with_healthy_folders_prints_nothing() {
  setup_run; card SCRUM-1
  run run.sh problems
  assert_rc 0; assert_eq "$OUT" ""
}
test_problems_lists_each_broken_folder() {
  setup_run; card SCRUM-1
  mkdir -p "$A/runs/notes" "$A/runs/SCRUM-2" "$A/runs/SCRUM-3"
  printf 'card: SCRUM-3\nphase: plan\n' > "$A/runs/SCRUM-3/state.md"
  rm "$A/runs/SCRUM-1/history.md"
  run run.sh problems
  assert_rc 0
  assert_eq "$OUT" "❌ runs/SCRUM-1 has no history.md
   Fix: Pick the card up again with \`/flow-start SCRUM-1\`.
❌ runs/SCRUM-2 has no state.md
   Fix: Pick the card up again with \`/flow-start SCRUM-2\`, or remove the folder.
❌ runs/SCRUM-3/state.md has no \`step\` line
   Fix: Add it, or pick the card up again with \`/flow-start SCRUM-3\`.
❌ runs/SCRUM-3/state.md has no \`next\` line
   Fix: Add it, or pick the card up again with \`/flow-start SCRUM-3\`.
❌ runs/SCRUM-3/state.md has no \`updated\` line
   Fix: Add it, or pick the card up again with \`/flow-start SCRUM-3\`.
❌ runs/SCRUM-3 has no history.md
   Fix: Pick the card up again with \`/flow-start SCRUM-3\`.
❌ runs/notes isn't a card key
   Fix: Rename or remove the folder; card folders are named after the card (e.g. SCRUM-567)."
}
test_problems_when_the_folder_is_on_a_card_branch() {
  setup_run; run run.sh branch SCRUM-1
  git -C "$A" symbolic-ref HEAD refs/heads/runs/SCRUM-1
  run run.sh problems
  assert_rc 0
  assert_contains "$OUT" "❌ The closio-agent folder is on a card's saved copy (runs/SCRUM-1)
   Fix: Switch back: \`git checkout main\`"
}
test_problems_without_a_runs_folder() {
  setup_run
  run run.sh problems
  assert_rc 0; assert_eq "$OUT" ""
}
test_quick_clean_removes_the_scratch_files() {
  setup_run
  mkdir -p "$A/local/quick-checks/SCRUM-1/data"; echo x > "$A/local/quick-checks/SCRUM-1/data/q.sql"
  run run.sh quick-clean SCRUM-1
  assert_rc 0; assert_eq "$OUT" "✅ Removed local/quick-checks/SCRUM-1/ (the quick check's scratch files)"
  assert_no_file "$A/local/quick-checks/SCRUM-1"
  run run.sh quick-clean SCRUM-1
  assert_rc 0; assert_eq "$OUT" "✅ Nothing to remove: no local/quick-checks/SCRUM-1/"
}

# ---------------------------------------------------------------- usage
test_a_bad_card_key_is_wrong_usage() {
  setup_run
  local a
  for a in branch create state status save unsaved quick-clean; do
    run run.sh "$a" scrum-1
    assert_rc 2
    assert_eq "$OUT" "❌ 'scrum-1' isn't a card key
   Fix: Give the key as in Jira, e.g. SCRUM-567."
  done
  run run.sh state
  assert_rc 2; assert_contains "$OUT" "❌ '' isn't a card key"
}
test_help_and_unknown_actions_show_the_usage() {
  setup_run
  run run.sh help
  assert_rc 0; assert_contains "$OUT" "Usage: bash scripts/run.sh check-folder | branch <KEY>"
  run run.sh
  assert_rc 2; assert_contains "$OUT" "Usage:"
  run run.sh nothing
  assert_rc 2; assert_contains "$OUT" "Usage:"
}
