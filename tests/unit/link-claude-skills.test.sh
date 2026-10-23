# scripts/link-claude-skills.sh: .claude/skills/<name> becomes a link to .agents/skills/<name> for every command.

setup_skills() { # sandbox with the command folders named
  sandbox
  local n
  for n in "$@"; do mkdir -p "$A/.agents/skills/$n"; printf -- '---\nname: %s\n---\n' "$n" > "$A/.agents/skills/$n/SKILL.md"; done
}

test_makes_a_link_for_every_command_from_any_folder() {
  setup_skills flow-a flow-b
  run_in "$T" bash "$A/scripts/link-claude-skills.sh"
  assert_rc 0
  assert_eq "$OUT" "created: .claude/skills/flow-a -> ../../.agents/skills/flow-a
created: .claude/skills/flow-b -> ../../.agents/skills/flow-b"
  assert_eq "$(readlink "$A/.claude/skills/flow-a")" "../../.agents/skills/flow-a"
  assert_contains "$(cat "$A/.claude/skills/flow-b/SKILL.md")" "name: flow-b" "the link reaches the command's file"
}
test_running_it_again_leaves_the_right_links_alone() {
  setup_skills flow-a flow-b
  run link-claude-skills.sh
  run link-claude-skills.sh
  assert_rc 0
  assert_eq "$OUT" "ok:      .claude/skills/flow-a
ok:      .claude/skills/flow-b"
}
test_something_else_in_the_way_is_skipped_never_replaced() {
  setup_skills flow-a flow-b flow-c
  mkdir -p "$A/.claude/skills/flow-b"; echo mine > "$A/.claude/skills/flow-b/notes.txt"
  ln -s "/somewhere/else" "$A/.claude/skills/flow-c"
  run link-claude-skills.sh
  assert_rc 0
  assert_eq "$OUT" "created: .claude/skills/flow-a -> ../../.agents/skills/flow-a
skipped: .claude/skills/flow-b already exists but isn't the expected link. Check it by hand.
skipped: .claude/skills/flow-c already exists but isn't the expected link. Check it by hand."
  assert_eq "$(cat "$A/.claude/skills/flow-b/notes.txt")" "mine"
  assert_eq "$(readlink "$A/.claude/skills/flow-c")" "/somewhere/else"
}
test_no_commands_only_makes_the_folder() {
  sandbox
  mkdir -p "$A/.agents/skills"
  run link-claude-skills.sh
  assert_rc 0; assert_eq "$OUT" ""
  [ -d "$A/.claude/skills" ] || fail ".claude/skills not made"
}
