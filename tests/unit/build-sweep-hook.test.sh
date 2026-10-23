# scripts/build-sweep-hook.sh: the builder's doc check at the end of a reply (only on the builder's Mac, never in a card
# session): holds the AI back once with the list of doc updates a change still needs.

# A small closio-agent of its own (its docs written here, so the test doesn't depend on today's real docs): newest
# agent rule A2, build rule R2, decision D2; one command (flow-ping, copied); the guide mirrored on 2026-01-02 (today).
setup_builder() {
  sandbox .gitignore .agents/skills/flow-ping
  mkdir -p "$A/docs" "$A/build-memory" "$A/rulesets" "$A/.claude" "$A/.codex/rules" "$A/local/card-sessions"
  printf '# Agent rules\n\n| A1 | one |\n| A2 | two |\n\nThe rules A1–A2.\n' > "$A/docs/agent-rules.md"
  printf '# Build rules\n\n| R1 | one |\n| R2 | two |\n\nThe rules R1–R2 and A1–A2.\n' > "$A/build-memory/rules.md"
  printf '# Decisions\n\n### D1 — one\n\n### D2 — two\n' > "$A/docs/design-decisions.md"
  printf '# Decisions\n\n- **D1:** one\n- **D2:** two\n' > "$A/build-memory/decisions.md"
  printf '# Changelog\n\nOld: A1–A1, R1–R1.\n' > "$A/docs/changelog.md"
  printf '# History\n' > "$A/build-memory/history.md"
  printf '# Project context\n\nA1–A2\n' > "$A/build-memory/project-context.md"
  printf '# README\n\nAgent rules A1–A2, build rules R1–R2.\n' > "$A/docs/README.md"
  printf '# Rules for AI tools\n\n1. One rule.\n' > "$A/AGENTS.md"
  printf '# Card rules\n' > "$A/rulesets/card-rules.md"
  printf '# Commands\n\n### `flow-ping`\n\nHelper scripts: `run.sh`.\n' > "$A/docs/commands.md"
  printf '# Guide\n\n**Claude artifact:** https://claude.ai/x · mirrored on 2026-01-02 · commands: flow-ping\n\n| 1 | `flow-ping` |\n' > "$A/docs/user-guide.md"
  printf '{"permissions": {"allow": ["Bash(bash scripts/run.sh:*)"]}}\n' > "$A/.claude/settings.json"
  printf '{"hooks": {}}\n' > "$A/.codex/hooks.json"
  printf 'prefix_rule(pattern=["bash", "scripts/run.sh"], decision="allow")\n' > "$A/.codex/rules/closio-agent.rules"
  sandbox_git
  echo "# the builder's Mac" > "$A/local/builder"
  export BUILD_SWEEP_TODAY=2026-01-02
}
sweep() { # <json>
  OUT="$(cd "$A" && printf '%s' "$1" | bash scripts/build-sweep-hook.sh 2>&1)"; RC=$?
}
reason() { printf '%s' "$OUT" | jq -r 'select(.decision == "block") | .reason' 2>/dev/null; }
assert_nothing() { assert_rc 0; assert_eq "$OUT" "" "the hook should print nothing"; }
add_line() { printf '%s\n' "${2:-x}" >> "$A/$1"; }
# The usual updates of a build change: the changelog, the history and a rule file
usual_updates() { add_line docs/changelog.md "- x"; add_line build-memory/history.md "| x |"; add_line rulesets/card-rules.md; mkdir -p "$A/tests/unit"; add_line tests/unit/run.test.sh "# x"; }
INTRO="The builder's doc check (closio-agent, the builder's Mac only, never in a card session) found these updates missing. Before you finish this reply, make each one (or say why it isn't needed), then say in your reply which files you updated:"

test_without_the_builder_marker_nothing_happens() {
  setup_builder; rm -f "$A/local/builder"
  add_line scripts/run.sh "# x"
  sweep '{"session_id":"s1"}'
  assert_nothing
}
test_without_a_session_id_nothing_happens() {
  setup_builder; add_line scripts/run.sh "# x"
  sweep '{}'
  assert_nothing
  sweep 'not json'
  assert_nothing
}
test_a_card_session_never_runs_it() {
  setup_builder; add_line scripts/run.sh "# x"
  printf 'key SCRUM-1\nlast /flow-develop\n' > "$A/local/card-sessions/card1"
  sweep '{"session_id":"card1"}'
  assert_nothing
}
test_already_held_back_in_this_reply_nothing_happens() {
  setup_builder; add_line scripts/run.sh "# x"
  sweep '{"session_id":"s1","stop_hook_active":true}'
  assert_nothing
}
test_nothing_changed_nothing_happens() {
  setup_builder
  sweep '{"session_id":"s1"}'
  assert_nothing
}
test_only_runs_and_local_changed_nothing_happens() {
  setup_builder
  mkdir -p "$A/runs/SCRUM-1"; echo x > "$A/runs/SCRUM-1/history.md"; echo y > "$A/local/notes.md"
  sweep '{"session_id":"s1"}'
  assert_nothing
}
test_a_script_changed_alone_holds_back_with_the_changelog_history_and_rule_files() {
  setup_builder; add_line scripts/run.sh "# x"
  sweep '{"session_id":"s2"}'
  assert_rc 0
  assert_eq "$(printf '%s' "$OUT" | jq -r .decision)" "block"
  assert_eq "$(reason)" "$INTRO
- docs/changelog.md: no entry for this change yet.
- build-memory/history.md: no row for this step yet (rule R10).
- scripts/run.sh changed, tests/unit/run.test.sh didn't: add or change its tests for what changed, then run bash tests/run.sh (rule R20).
- No rule file changed: go through rulesets/, AGENTS.md, docs/agent-rules.md, build-memory/project-context.md, build-memory/rules.md and the two pre-approval files, and say in your reply which you checked (rule R15, step 6)."
}
test_the_same_list_is_said_once_per_session() {
  setup_builder; add_line scripts/run.sh "# x"
  sweep '{"session_id":"s2"}'
  assert_contains "$(reason)" "docs/changelog.md"
  assert_file "$A/local/build-sweep/s2"
  sweep '{"session_id":"s2"}'
  assert_nothing
  sweep '{"session_id":"s3"}'
  assert_contains "$(reason)" "docs/changelog.md" "another session hears it too"
  add_line docs/changelog.md "- x"
  sweep '{"session_id":"s2"}'
  assert_contains "$(reason)" "build-memory/history.md" "a different list is said again"
  assert_not_contains "$(reason)" "docs/changelog.md"
}
test_with_the_usual_updates_nothing_is_missing() {
  setup_builder; add_line scripts/run.sh "# x"; usual_updates
  sweep '{"session_id":"s2"}'
  assert_nothing
}
test_a_new_decision_without_its_line_in_build_memory() {
  setup_builder
  printf '\n### D3 — three\n' >> "$A/docs/design-decisions.md"; add_line build-memory/history.md "| x |"
  sweep '{"session_id":"s3"}'
  assert_eq "$(reason)" "$INTRO
- Decisions: the newest in docs/design-decisions.md is D3, in build-memory/decisions.md D2 (one line per decision, rule R11)."
}
test_agents_md_alone_needs_the_two_rule_copies() {
  setup_builder
  add_line AGENTS.md "2. A new rule."; add_line docs/changelog.md "- x"; add_line build-memory/history.md "| x |"
  sweep '{"session_id":"s4"}'
  assert_eq "$(reason)" "$INTRO
- AGENTS.md changed, docs/agent-rules.md didn't (the team copy of the agent rules).
- AGENTS.md changed, build-memory/project-context.md didn't (the build copy of the agent rules)."
}
test_a_stale_rule_count_is_named_with_its_file() {
  setup_builder
  add_line docs/README.md "Old count: A1–A1 and R1–R1."; add_line build-memory/history.md "| x |"
  sweep '{"session_id":"s5"}'
  assert_eq "$(reason)" "$INTRO
- \"A1–A…\" isn't A1–A2 in: docs/README.md (the newest rule is A2).
- \"R1–R…\" isn't R1–R2 in: docs/README.md (the newest rule is R2)."
}
test_a_command_changed_without_its_docs() {
  setup_builder; usual_updates
  add_line .agents/skills/flow-ping/SKILL.md
  sweep '{"session_id":"s6"}'
  assert_eq "$(reason)" "$INTRO
- A command changed, docs/commands.md didn't (its section, rule R17).
- A command changed, docs/user-guide.md didn't (its step or row, and then the Claude artifact, rule R17)."
}
test_the_guide_changed_but_was_not_mirrored_today() {
  setup_builder; add_line docs/user-guide.md; add_line build-memory/history.md "| x |"
  export BUILD_SWEEP_TODAY=2026-02-03
  sweep '{"session_id":"s7"}'
  assert_eq "$(reason)" "$INTRO
- docs/user-guide.md changed but says \"mirrored on 2026-01-02\": update its Claude artifact the same way, then set the date to 2026-02-03 and every command (rule R17)."
  export BUILD_SWEEP_TODAY=2026-01-02
  sweep '{"session_id":"s8"}'
  assert_nothing
}
test_the_guide_without_a_mirrored_line() {
  setup_builder; printf '# Guide\n' > "$A/docs/user-guide.md"; add_line build-memory/history.md "| x |"
  sweep '{"session_id":"s7"}'
  assert_contains "$(reason)" "says \"mirrored on ?\""
}
test_new_scripts_need_the_helper_table_the_pre_approvals_and_the_hook_files() {
  setup_builder; usual_updates
  printf '#!/bin/bash\n' > "$A/scripts/new-thing.sh"; printf '#!/bin/bash\n' > "$A/scripts/other-hook.sh"
  sweep '{"session_id":"s9"}'
  assert_eq "$(reason)" "$INTRO
- New script new-thing.sh: not in docs/commands.md's helper scripts.
- New script new-thing.sh: not pre-approved in both .claude/settings.json and .codex/rules/closio-agent.rules (if a command runs it).
- New script other-hook.sh: not in docs/commands.md's helper scripts.
- New hook other-hook.sh: not set in both .claude/settings.json and .codex/hooks.json.
- scripts/new-thing.sh changed, tests/unit/new-thing.test.sh didn't: add or change its tests for what changed, then run bash tests/run.sh (rule R20).
- scripts/other-hook.sh changed, tests/unit/other-hook.test.sh didn't: add or change its tests for what changed, then run bash tests/run.sh (rule R20)."
}
test_new_scripts_listed_everywhere_need_nothing() {
  setup_builder; usual_updates
  printf '#!/bin/bash\n' > "$A/scripts/new-thing.sh"; printf '#!/bin/bash\n' > "$A/scripts/other-hook.sh"
  add_line docs/commands.md 'And `new-thing.sh`, `other-hook.sh`.'
  printf '{"x": ["bash scripts/new-thing.sh", "bash scripts/other-hook.sh"]}\n' > "$A/.claude/settings.json"
  add_line .codex/rules/closio-agent.rules 'prefix_rule(pattern=["bash", "scripts/new-thing.sh"], decision="allow")'
  printf '{"hooks": {"Stop": "bash scripts/other-hook.sh"}}\n' > "$A/.codex/hooks.json"
  add_line tests/unit/new-thing.test.sh "# x"; add_line tests/unit/other-hook.test.sh "# x"
  sweep '{"session_id":"s10"}'
  assert_nothing
}
test_help_check_problems_are_passed_on() {
  setup_builder; usual_updates; add_line docs/commands.md
  python3 - "$A/.agents/skills/flow-ping/SKILL.md" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
open(p, "w").write(s.replace("## Usage", "## Use"))
PY
  add_line docs/user-guide.md
  sweep '{"session_id":"s11"}'
  assert_eq "$(reason)" "$INTRO
- bash scripts/help.sh check: No \"## Usage\" block in SKILL.md: flow-ping."
}
test_without_jq_nothing_happens() {
  setup_builder; add_line scripts/run.sh "# x"
  mkdir -p "$T/nojq"; ln -s "$(command -v dirname)" "$T/nojq/dirname"
  OUT="$(cd "$A" && printf '{"session_id":"s1"}' | PATH="$T/nojq" /bin/bash scripts/build-sweep-hook.sh 2>&1)"; RC=$?
  assert_nothing
}
test_a_state_folder_that_cannot_be_made_prints_nothing() {
  setup_builder; add_line scripts/run.sh "# x"
  echo "a file" > "$A/local/not-a-folder"
  export BUILD_SWEEP_DIR="$A/local/not-a-folder/sweep"
  sweep '{"session_id":"s1"}'
  assert_nothing
}
test_old_session_notes_are_removed() {
  setup_builder; add_line scripts/run.sh "# x"
  mkdir -p "$A/local/build-sweep"; echo old > "$A/local/build-sweep/old"; touch -t 202001010000 "$A/local/build-sweep/old"
  sweep '{"session_id":"s1"}'
  assert_contains "$(reason)" "docs/changelog.md"
  assert_no_file "$A/local/build-sweep/old"; assert_file "$A/local/build-sweep/s1"
}
test_a_script_changed_with_its_tests_needs_no_test_reminder() {
  setup_builder; add_line scripts/lib/repo-info.sh "# x"; add_line docs/changelog.md "- x"; add_line build-memory/history.md "| x |"; add_line rulesets/card-rules.md
  sweep '{"session_id":"s11"}'
  assert_contains "$(reason)" "scripts/lib/repo-info.sh changed, tests/unit/repo-info.test.sh didn't"
  mkdir -p "$A/tests/unit"; add_line tests/unit/repo-info.test.sh "# x"
  sweep '{"session_id":"s12"}'
  assert_nothing
}
