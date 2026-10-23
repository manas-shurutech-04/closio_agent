# scripts/help.sh: the flow-help list, one command in full, Codex's menu line, and the "every command is listed
# everywhere" check. Most tests use three small commands of their own (in the help groups: flow-ping, flow-memory,
# flow-help), with their docs; one test uses copies of the real commands and docs.

skill() { # <name> <description line or ""> <argument-hint or -> [usage lines…]: .agents/skills/<name>/SKILL.md
  local name="$1" desc="$2" hint="$3" d l
  shift 3
  d="$A/.agents/skills/$name"; mkdir -p "$d/agents"
  {
    echo "---"; echo "name: $name"
    [ -n "$desc" ] && echo "description: $desc"
    [ "$hint" != "-" ] && echo "argument-hint: $hint"
    echo "disable-model-invocation: true"; echo "---"; echo; echo "# $name"; echo
    if [ $# -gt 0 ]; then echo "## Usage"; echo; for l in "$@"; do echo "$l"; done; echo; fi
    echo "## Steps"; echo; echo "1. Do it."
  } > "$d/SKILL.md"
}
codex_yaml() { # <name> <short_description, escaped as in YAML>: agents/openai.yaml with Codex's menu line
  printf 'policy:\n  allow_implicit_invocation: false\ninterface:\n  short_description: "%s"\n' "$2" > "$A/.agents/skills/$1/agents/openai.yaml"
}
setup_help() { # the three commands, their Codex lines, docs and rule files: everything check wants
  sandbox
  skill flow-ping '"Checks that the agent answers (a quick test): says hello. Runs only when the user types /flow-ping (Claude Code) or $flow-ping (Codex)."' - \
    '- `/flow-ping`' '- Codex: `$flow-ping`'
  skill flow-memory 'Manages your "memory" and C:\notes: list, add. Starts when the user types /flow-memory.' "'[add <text> | remove <id>]'" \
    '- `/flow-memory`: list them.' '- `/flow-memory add <text>`: add one.' '- Codex: `$flow-memory …`'
  skill flow-help 'Lists every flow command. Shows one in full with its options, read from the commands own files, so that nothing is ever missing from the help and nobody has to keep a second list up to date by hand.' "'[<command>]'" \
    '- `/flow-help`: every command.' '- `/flow-help <command>`: one command in full, with every option and what it does, written out so that it needs a few lines on a narrow screen.'
  codex_yaml flow-ping '$flow-ping · Checks that the agent answers.'
  codex_yaml flow-memory '$flow-memory [add <text> | remove <id>] · Manages your \"memory\" and C:\\notes.'
  codex_yaml flow-help '$flow-help [<command>] · Lists every flow command.'
  mkdir -p "$A/docs" "$A/rulesets"
  printf '# Commands\n\n### `flow-ping`\n\nPing.\n\n### `flow-memory`\n\nMemory.\n\n### `flow-help`\n\nHelp.\n' > "$A/docs/commands.md"
  printf '# Guide\n\n**Claude artifact:** https://claude.ai/artifact/abc-123 · mirrored on 2026-10-23 · commands: flow-ping, flow-memory, flow-help\n\n| Command | What |\n| --- | --- |\n| `flow-ping` | ping |\n| `flow-memory` | memory |\n| `flow-help` | help |\n' > "$A/docs/user-guide.md"
  printf '# Rules\n\nA coming change to the VPN is not built yet (no command named).\nflow-pingpong is coming (not a command).\n' > "$A/AGENTS.md"
  printf '# Agent rules\n\nflow-ping, flow-memory and flow-help are built.\n' > "$A/docs/agent-rules.md"
  printf '# Ruleset\n\nUse flow-help.\n' > "$A/rulesets/story.md"
}
max_width() { # the widest line, in characters
  printf '%s\n' "$1" | python3 -I -c 'import sys; print(max(len(l) for l in sys.stdin.buffer.read().decode("utf-8").split("\n")))'
}

test_list_in_markdown_shows_the_groups_and_each_command_with_its_forms() {
  setup_help
  run help.sh
  assert_rc 0
  assert_eq "$OUT" '## flow-help: every flow command

Claude Code: `/flow-<name>` · Codex: `$flow-<name>` · one command in full: `/flow-help <command>`

### Setup, once, in this order

**flow-ping** · Checks that the agent answers.
- `/flow-ping`

### Every day

**flow-memory** · Manages your "memory" and C:\notes.
- `/flow-memory`
- `/flow-memory add <text>`

### Cards

### Any time

**flow-help** · Lists every flow command.
- `/flow-help`
- `/flow-help <command>`

Step by step: `docs/user-guide.md` · Claude artifact: https://claude.ai/artifact/abc-123 · every detail: `docs/commands.md`'
}
test_a_command_in_no_group_shows_under_other_even_without_description_or_usage() {
  setup_help
  skill flow-zeta "" -
  rm -f "$A/docs/user-guide.md"
  run help.sh list
  assert_rc 0
  assert_contains "$OUT" '### Other (not in a group yet: add it to the groups in scripts/help.sh)

**flow-zeta** · (no description in its SKILL.md yet)
- ⚠️ no `## Usage` block in its SKILL.md yet'
  assert_contains "$OUT" 'Step by step: `docs/user-guide.md` · every detail: `docs/commands.md`' "no artifact link without the guide"
}
test_list_in_plain_text_is_wrapped_to_the_width() {
  setup_help
  skill flow-zeta "" -
  export HELP_FORMAT=plain COLUMNS=50
  run help.sh list
  assert_rc 0
  assert_contains "$OUT" "SETUP, ONCE, IN THIS ORDER"
  assert_contains "$OUT" "  flow-ping
    Checks that the agent answers.
      /flow-ping"
  assert_contains "$OUT" "      ⚠️ no \"## Usage\" block in its SKILL.md yet"
  assert_contains "$OUT" "Claude Code: /flow-<name> · Codex: \$flow-<name> ·
one command in full: /flow-help <command>"
  assert_contains "$OUT" "Step by step: docs/user-guide.md · Claude
artifact: https://claude.ai/artifact/abc-123 ·
every detail: docs/commands.md"
  assert_not_contains "$OUT" "**"; assert_not_contains "$OUT" $'\033'
  [ "$(max_width "$(printf '%s\n' "$OUT" | grep -v '^[A-Z]')")" -le 50 ] || fail "lines wider than 50 columns: $(max_width "$OUT")"
}
test_list_in_a_terminal_has_colors() {
  setup_help
  export HELP_FORMAT=terminal
  run help.sh list
  assert_rc 0
  assert_contains "$OUT" $'\033[1;36mflow-help: every flow command\033[0m'
  assert_contains "$OUT" $'  \033[1;32mflow-ping\033[0m'
  assert_contains "$OUT" $'      \033[33m/flow-memory add <text>\033[0m'
}
test_an_unknown_format_falls_back_to_markdown() {
  setup_help
  export HELP_FORMAT=html
  run help.sh list
  assert_contains "$OUT" "### Every day"
}
test_the_width_stays_between_40_and_100_columns() {
  setup_help
  export HELP_FORMAT=plain
  COLUMNS=200 run help.sh show help
  local w; w="$(max_width "$OUT")"
  [ "$w" -gt 80 ] && [ "$w" -le 100 ] || fail "COLUMNS=200: widest line $w, expected 81 to 100"
  COLUMNS=10 run help.sh show help
  w="$(max_width "$OUT")"
  [ "$w" -gt 20 ] && [ "$w" -le 40 ] || fail "COLUMNS=10: widest line $w, expected up to 40"
  COLUMNS=wide run help.sh show help
  w="$(max_width "$OUT")"
  [ "$w" -gt 60 ] && [ "$w" -le 80 ] || fail "COLUMNS=wide: widest line $w, expected up to 80"
}
test_in_a_real_terminal_it_uses_colors_or_plain_text_with_no_color() {
  setup_help
  unset COLUMNS
  run_in "$A" bash -c 'script -q /dev/null bash scripts/help.sh list < /dev/null'
  assert_contains "$OUT" "SETUP, ONCE, IN THIS ORDER"
  assert_not_contains "$OUT" $'\033[1;36m' "NO_COLOR is set in the tests"
  run_in "$A" env -u NO_COLOR bash -c 'script -q /dev/null bash scripts/help.sh list < /dev/null'
  assert_contains "$OUT" $'\033[1;36mSETUP, ONCE, IN THIS ORDER'
}
test_show_one_command_in_markdown_without_typing_flow() {
  setup_help
  run help.sh show memory
  assert_rc 0
  assert_eq "$OUT" '## flow-memory

Manages your "memory" and C:\notes: list, add.

**How to type it**

- `/flow-memory`: list them.
- `/flow-memory add <text>`: add one.
- Codex: `$flow-memory …`

More: section `flow-memory` in `docs/commands.md` · step by step: `docs/user-guide.md`'
}
test_show_one_command_in_plain_text() {
  setup_help
  export HELP_FORMAT=plain COLUMNS=60
  run help.sh show flow-memory
  assert_rc 0
  assert_eq "$OUT" 'flow-memory

  Manages your "memory" and C:\notes: list, add.

HOW TO TYPE IT
  /flow-memory
    list them.
  /flow-memory add <text>
    add one.
  Codex: $flow-memory …

More: section "flow-memory" in docs/commands.md · step by
step: docs/user-guide.md'
}
test_show_a_command_without_a_usage_block_says_so() {
  setup_help
  skill flow-zeta "Does zeta things." -
  run help.sh show zeta
  assert_rc 0
  assert_contains "$OUT" "## flow-zeta"
  assert_contains "$OUT" '⚠️ No "## Usage" block in its SKILL.md yet'
  assert_contains "$OUT" "   Tip: Add one; flow-help reads it from there."
  HELP_FORMAT=plain run help.sh show zeta
  assert_rc 0
  assert_contains "$OUT" '⚠️ No "## Usage" block in its SKILL.md yet'
  assert_not_contains "$OUT" "HOW TO TYPE IT"
}
test_show_an_unknown_command_or_no_command() {
  setup_help
  run help.sh show nope
  assert_rc 1
  assert_eq "$OUT" "❌ No flow command called 'flow-nope'
   Fix: Run /flow-help to see every command (Codex: \$flow-help)."
  run help.sh show
  assert_rc 2; assert_eq "$OUT" "Usage: bash scripts/help.sh [list | show <command> | codex-line <command> | check]"
  run help.sh show ""
  assert_rc 2
}
test_codex_line_is_the_hint_and_summary_as_a_yaml_value() {
  setup_help
  run help.sh codex-line flow-memory
  assert_rc 0
  assert_eq "$OUT" 'interface:
  short_description: "$flow-memory [add <text> | remove <id>] · Manages your \"memory\" and C:\\notes."'
  run help.sh codex-line flow-ping
  assert_eq "$OUT" 'interface:
  short_description: "$flow-ping · Checks that the agent answers."'
  run help.sh codex-line flow-nope
  assert_rc 2; assert_contains "$OUT" "Usage:"
  run help.sh codex-line
  assert_rc 2
}
test_help_and_unknown_actions() {
  setup_help
  run help.sh --help
  assert_rc 0; assert_eq "$OUT" "Usage: bash scripts/help.sh [list | show <command> | codex-line <command> | check]"
  run help.sh help
  assert_rc 0
  run help.sh dance
  assert_rc 2; assert_contains "$OUT" "Usage:"
}
test_check_passes_when_every_command_is_listed_everywhere() {
  setup_help
  run help.sh check
  assert_rc 0
  assert_eq "$OUT" '✅ Every command (3) has its "## Usage" block (what flow-help shows)
✅ Every command that takes arguments has its argument-hint (what Claude Code'"'"'s / menu shows)
✅ Every command has its Codex menu line (its options in Codex'"'"'s $ menu)
✅ Every command is in a flow-help group
✅ Every command has its section in docs/commands.md
✅ Every command has its row in docs/user-guide.md
✅ The Claude artifact covers every command (2026-10-23)
✅ No rule file calls a built command "coming" or "not built yet"'
}
test_check_names_every_command_that_is_missing_somewhere() {
  setup_help
  skill flow-ping "Checks that the agent answers." -                                   # no Usage block now
  codex_yaml flow-ping '$flow-ping · Checks that the agent answers.'
  skill flow-memory "Manages your memory." - '- `/flow-memory add <text>`: add one.'  # takes arguments, no hint
  codex_yaml flow-memory '$flow-memory · Manages your memory.'
  sed -i '' 's/Lists every flow command/Lists the commands/' "$A/.agents/skills/flow-help/agents/openai.yaml"
  skill flow-zeta "Zeta." - '- `/flow-zeta`'                                            # in nothing at all
  sed -i '' '/^### `flow-memory`/d' "$A/docs/commands.md"
  sed -i '' '/^| `flow-help`/d' "$A/docs/user-guide.md"
  printf 'flow-ping: coming in the next release.\n' >> "$A/AGENTS.md"
  printf 'flow-help is not built yet.\n' >> "$A/rulesets/story.md"
  run help.sh check
  assert_rc 1
  assert_contains "$OUT" '❌ No "## Usage" block in SKILL.md: flow-ping
   Fix: Add a "## Usage" section with one "- `/flow-…`: …" line per form; flow-help reads it from there.'
  assert_contains "$OUT" "❌ No argument-hint in SKILL.md, though the command takes arguments: flow-memory"
  assert_contains "$OUT" "❌ Codex's menu line is missing or out of date: flow-help flow-zeta"
  assert_contains "$OUT" "   Fix: For each: bash scripts/help.sh codex-line <command>, and put the lines it prints in .agents/skills/<command>/agents/openai.yaml (under interface:)."
  assert_contains "$OUT" '❌ Not in a flow-help group (flow-help shows them under "Other"): flow-zeta'
  assert_contains "$OUT" "❌ No section in docs/commands.md: flow-memory flow-zeta"
  assert_contains "$OUT" "❌ No row in the command index of docs/user-guide.md: flow-help flow-zeta"
  assert_contains "$OUT" "❌ The Claude artifact of the guide is behind; not in its \"mirrored\" line: flow-zeta"
  assert_contains "$OUT" "❌ A rule file still calls a built command \"coming\" or \"not built yet\": rulesets/story.md:4 AGENTS.md:5"
  assert_eq "$(printf '%s\n' "$OUT" | grep -c '^❌')" "8"; assert_not_contains "$OUT" "✅"
}
test_check_without_the_docs_or_their_mirrored_line() {
  setup_help
  rm -f "$A/docs/commands.md" "$A/docs/user-guide.md"
  run help.sh check
  assert_rc 1
  assert_contains "$OUT" "❌ docs/commands.md is missing
   Fix: Restore it from git."
  assert_contains "$OUT" "❌ docs/user-guide.md is missing"
  assert_not_contains "$OUT" "mirrored"
  printf '# Guide\n\n| `flow-ping` |\n| `flow-memory` |\n| `flow-help` |\n' > "$A/docs/user-guide.md"
  run help.sh check
  assert_contains "$OUT" "❌ docs/user-guide.md has no \"mirrored\" line for the Claude artifact"
  assert_contains "$OUT" "Fix: Put at the top of the guide: **Claude artifact:** <link> · mirrored on <YYYY-MM-DD> · commands: <every command, comma-separated>."
  assert_contains "$OUT" "✅ Every command has its row in docs/user-guide.md"
}
test_check_with_no_commands_at_all() {
  sandbox
  mkdir -p "$A/.agents/skills"
  run help.sh check
  assert_rc 1
  assert_eq "$OUT" "❌ No flow commands found in $(cd "$A" && pwd -P)/.agents/skills
   Fix: Run it from the closio-agent folder: bash scripts/help.sh check"
}
test_check_on_the_real_commands_and_docs_and_a_broken_copy() {
  sandbox .agents docs/commands.md docs/user-guide.md docs/agent-rules.md AGENTS.md rulesets
  run help.sh check
  assert_rc 0; assert_not_contains "$OUT" "❌"
  assert_match "$OUT" "✅ Every command \([0-9]+\) has its"
  sed -i '' '/^###[[:space:]]*`flow-memory`/d' "$A/docs/commands.md"
  run help.sh check
  assert_rc 1
  assert_eq "$(printf '%s\n' "$OUT" | grep '^❌')" "❌ No section in docs/commands.md: flow-memory"
}
