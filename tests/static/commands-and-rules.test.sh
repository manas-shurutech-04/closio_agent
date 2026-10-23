# The commands, the rules and the docs that tie them together (D92): fixed checks on the files as they are, no AI.
# Each test reads the real files; anything a script must run on is copied into a sandbox first.

R="$CLOSIO_ROOT"
skills() { ls -d "$R"/.agents/skills/flow-*/ | sed 's#/$##'; }

test_every_script_has_valid_bash() {
  local f bad=""
  for f in "$R"/scripts/*.sh "$R"/scripts/lib/*.sh "$R"/config/project-settings.sh "$R"/tests/run.sh "$R"/tests/lib/*.sh "$R"/tests/fakes/keychain.sh "$R"/tests/fakes/nvm/nvm.sh; do
    bash -n "$f" 2>/dev/null || bad="$bad ${f#$R/}"
  done
  assert_eq "$bad" "" "scripts with a bash syntax error"
}
# The test image's stand-ins for the Mac's sed, stat, date, script (bash) and fold (python) (D93)
test_the_docker_stand_ins_parse() {
  local f
  for f in "$R"/tests/docker/shims/*; do
    case "$(head -1 "$f")" in
      *python3*) python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$f" || fail "${f#$R/} doesn't parse" ;;
      *bash*) bash -n "$f" || fail "${f#$R/} has a bash syntax error" ;;
      *) fail "${f#$R/}: neither bash nor python3" ;;
    esac
  done
}
test_every_test_file_has_valid_bash() {
  local f bad=""
  for f in "$R"/tests/unit/*.test.sh "$R"/tests/static/*.test.sh "$R"/tests/flows/*.test.sh; do
    [ -f "$f" ] || continue
    bash -n "$f" 2>/dev/null || bad="$bad ${f#$R/}"
  done
  assert_eq "$bad" "" "test files with a bash syntax error"
}
test_the_jq_python_and_javascript_helpers_compile() {
  echo null | jq -r -f "$R/scripts/lib/adf-to-markdown.jq" >/dev/null || fail "scripts/lib/adf-to-markdown.jq"
  printf '' | jq -Rs -j -f "$R/scripts/lib/markdown-to-wiki.jq" >/dev/null || fail "scripts/lib/markdown-to-wiki.jq"
  local f
  for f in "$R"/scripts/lib/*.py "$R"/tests/fakes/*.py "$R"/tests/lib/*.py; do
    python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$f" || fail "${f#$R/} doesn't parse"
  done
  if command -v node >/dev/null 2>&1; then node --check "$R/scripts/lib/db-run.js" || fail "scripts/lib/db-run.js doesn't parse"; fi
}

test_every_command_is_documented_everywhere_help_check() {
  sandbox .agents .claude .codex docs README.md AGENTS.md rulesets build-memory/rules.md
  run help.sh check
  assert_rc 0
  assert_not_contains "$OUT" "❌"
}
test_every_command_has_a_claude_code_link_and_a_codex_menu_file() {
  local d n
  for d in $(skills | sed 's/ /%20/g'); do
    d="$(printf '%s' "$d" | sed 's/%20/ /g')"; n="$(basename "$d")"
    [ -L "$R/.claude/skills/$n" ] || fail "no Claude Code link .claude/skills/$n"
    [ "$(cd "$R/.claude/skills/$n" 2>/dev/null && pwd -P)" = "$(cd "$d" && pwd -P)" ] || fail ".claude/skills/$n doesn't point to .agents/skills/$n"
    [ -f "$d/agents/openai.yaml" ] || fail "no .agents/skills/$n/agents/openai.yaml"
  done
}
test_every_command_runs_only_when_typed_except_flow_develop() {
  local d n inv imp
  for d in $(skills | sed 's/ /%20/g'); do
    d="$(printf '%s' "$d" | sed 's/%20/ /g')"; n="$(basename "$d")"
    assert_eq "$(sed -n 's/^name: //p' "$d/SKILL.md" | head -1)" "$n" "$n: the name line"
    inv="$(sed -n 's/^disable-model-invocation: //p' "$d/SKILL.md" | head -1)"
    imp="$(sed -n 's/^ *allow_implicit_invocation: //p' "$d/agents/openai.yaml" | head -1)"
    if [ "$n" = flow-develop ]; then
      assert_eq "$inv" "false" "flow-develop starts from plain words too (D61)"; assert_eq "$imp" "true" "flow-develop in Codex"
    else
      assert_eq "$inv" "true" "$n: runs only when typed (AGENTS.md rule 1)"; assert_eq "$imp" "false" "$n in Codex: runs only when typed"
    fi
  done
}
test_every_script_a_command_names_exists() {
  local s missing=""
  for s in $(grep -h -o 'bash scripts/[a-z0-9-]*\.sh' "$R"/.agents/skills/*/SKILL.md "$R"/.claude/agents/*.md "$R"/.codex/agents/*.toml | sort -u | sed 's#bash ##'); do
    [ -f "$R/$s" ] || missing="$missing $s"
  done
  assert_eq "$missing" "" "scripts named by a command or an agent that don't exist"
}
test_every_script_a_command_names_is_pre_approved_in_both_tools() {
  local s c="" x=""
  for s in $(grep -h -o 'bash scripts/[a-z0-9-]*\.sh' "$R"/.agents/skills/*/SKILL.md "$R"/.claude/agents/*.md "$R"/.codex/agents/*.toml | sort -u | sed 's#bash ##'); do
    grep -q -F "Bash(bash $s" "$R/.claude/settings.json" || c="$c $s"
    grep -q -F "\"bash\", \"$s\"" "$R/.codex/rules/closio-agent.rules" || x="$x $s"
  done
  assert_eq "$c" "" "not pre-approved in .claude/settings.json"
  assert_eq "$x" "" "not pre-approved in .codex/rules/closio-agent.rules"
}
test_the_hook_files_are_valid_and_point_to_scripts_that_exist() {
  local f cmd s
  for f in "$R/.claude/settings.json" "$R/.codex/hooks.json"; do
    jq -e . "$f" >/dev/null || fail "${f#$R/} isn't valid JSON"
    for cmd in $(jq -r '.hooks[]?[]?.hooks[]?.command' "$f" | grep -o 'scripts/[a-z0-9-]*\.sh'); do
      [ -f "$R/$cmd" ] || fail "${f#$R/} runs $cmd, which doesn't exist"
    done
  done
  for s in card-rules-hook.sh card-autosave-hook.sh build-sweep-hook.sh; do
    grep -q "scripts/$s" "$R/.claude/settings.json" || fail ".claude/settings.json doesn't run $s"
    grep -q "scripts/$s" "$R/.codex/hooks.json" || fail ".codex/hooks.json doesn't run $s"
  done
}

test_agents_md_rules_are_numbered_with_no_gap() {
  local nums want i=1
  nums="$(grep -o -E '^[0-9]+\.' "$R/AGENTS.md" | tr -d '.' | tr '\n' ' ')"
  want=""; while [ "$i" -le "$(printf '%s' "$nums" | wc -w | tr -d ' ')" ]; do want="$want$i "; i=$((i + 1)); done
  assert_eq "$nums" "$want" "AGENTS.md rule numbers"
}
test_the_agent_rules_are_numbered_and_counted_the_same_everywhere() {
  local n i stale=""
  n="$(grep -o -E '^\| A[0-9]+ \|' "$R/docs/agent-rules.md" | tr -dc '0-9\n' | sort -n | tail -1)"
  i=1; while [ "$i" -le "$n" ]; do grep -q -E "^\| A$i \|" "$R/docs/agent-rules.md" || fail "docs/agent-rules.md has no A$i"; i=$((i + 1)); done
  i=1; while [ "$i" -le 4 ]; do grep -q -E "^\| G$i \|" "$R/docs/agent-rules.md" || fail "docs/agent-rules.md has no G$i"; i=$((i + 1)); done
  i=1; while [ "$i" -le "$n" ]; do grep -q -E "^- A$i:" "$R/build-memory/project-context.md" || fail "build-memory/project-context.md has no copy of A$i"; i=$((i + 1)); done
  stale="$(cd "$R" && git grep -l -E 'A1–A[0-9]+' -- '*.md' | grep -v -E '^(docs/changelog\.md|docs/design-decisions\.md|build-memory/history\.md|build-memory/full-chat-transcript\.md)' |
    while IFS= read -r f; do grep -o -E 'A1–A[0-9]+' "$f" | grep -v -x "A1–A$n" >/dev/null && printf '%s ' "$f"; done)"
  assert_eq "$stale" "" "files where \"A1–A…\" isn't A1–A$n"
}
test_the_build_rules_are_numbered_and_counted_the_same_everywhere() {
  local n i stale
  n="$(grep -o -E '^\| R[0-9]+ \|' "$R/build-memory/rules.md" | tr -dc '0-9\n' | sort -n | tail -1)"
  i=1; while [ "$i" -le "$n" ]; do grep -q -E "^\| R$i \|" "$R/build-memory/rules.md" || fail "build-memory/rules.md has no R$i"; i=$((i + 1)); done
  stale="$(cd "$R" && git grep -l -E 'R1–R[0-9]+' -- '*.md' | grep -v -E '^(docs/changelog\.md|docs/design-decisions\.md|build-memory/history\.md|build-memory/full-chat-transcript\.md)' |
    while IFS= read -r f; do grep -o -E 'R1–R[0-9]+' "$f" | grep -v -x "R1–R$n" >/dev/null && printf '%s ' "$f"; done)"
  assert_eq "$stale" "" "files where \"R1–R…\" isn't R1–R$n"
}
test_every_decision_has_its_anchor_and_its_index_line() {
  local d n i
  n="$(grep -o -E '^### D[0-9]+ ' "$R/docs/design-decisions.md" | tr -dc '0-9\n' | sort -n | tail -1)"
  i=1
  while [ "$i" -le "$n" ]; do
    grep -q -E "^### D$i " "$R/docs/design-decisions.md" || fail "docs/design-decisions.md has no D$i"
    grep -q "<a id=\"d$i\"></a>" "$R/docs/design-decisions.md" || fail "D$i has no anchor <a id=\"d$i\">"
    grep -q -E "^- \*\*D$i:\*\*" "$R/build-memory/decisions.md" || fail "build-memory/decisions.md has no line for D$i"
    i=$((i + 1))
  done
}
test_every_link_to_a_decision_points_to_one_that_exists() {
  local bad
  bad="$(cd "$R" && git grep -h -o -E 'design-decisions\.md#d[0-9]+' -- '*.md' | sort -u | sed 's/.*#d//' |
    while read -r k; do grep -q "<a id=\"d$k\"></a>" docs/design-decisions.md || printf 'd%s ' "$k"; done)"
  assert_eq "$bad" "" "links to decisions that don't exist"
}
test_the_card_rules_are_numbered_with_no_gap() {
  local nums want i=1
  nums="$(grep -o -E '^## [0-9]+\.' "$R/rulesets/card-rules.md" | tr -dc '0-9 \n' | tr -s ' \n' ' ' | sed 's/^ //')"
  want=""; while [ "$i" -le "$(printf '%s' "$nums" | wc -w | tr -d ' ')" ]; do want="$want$i "; i=$((i + 1)); done
  assert_eq "$nums" "$want" "rulesets/card-rules.md numbers"
}
test_the_user_guide_mirrored_line_names_every_command() {
  local line d n
  line="$(grep -m1 'mirrored on' "$R/docs/user-guide.md")"
  for d in $(skills | sed 's/ /%20/g'); do
    n="$(basename "$(printf '%s' "$d" | sed 's/%20/ /g')")"
    assert_contains "$line" "$n" "the guide's mirrored line"
  done
}
# tests/ is left out: its fakes use secret-shaped values on purpose (e.g. memory.sh must refuse to save them).
test_no_secret_looking_text_is_committed() {
  local hits
  hits="$(cd "$R" && git grep -n -I -E 'glpat-[A-Za-z0-9_-]{10,}|ATATT[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY' -- ':!build-memory/full-chat-transcript.md' ':!tests/' | head -5)"
  assert_eq "$hits" "" "text that looks like a secret"
}
