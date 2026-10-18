#!/usr/bin/env bash
# Help for the flow commands, and the "every command is listed everywhere" check (F8, D60, rule R17).
# Run it from the closio-agent folder:  bash scripts/help.sh <action>
#
#   list (or nothing)     Every flow command, grouped: a one-line summary and each way to type it
#   show <command>        One command in full (the "flow-" part can be left out)
#   check                 Rule R17: every command folder has a "## Usage" block, an "argument-hint" when it takes
#                         arguments (what Claude Code's / menu shows), a section in docs/commands.md, an index row in
#                         docs/user-guide.md, and is covered by the guide's "mirrored" line (the Claude artifact of
#                         the guide). ❌ with the fix for anything missing (rule A11).
#
# The text comes from the commands' own files: every folder .agents/skills/flow-*/ is a command; its SKILL.md
# gives the one-line "description:" and the "## Usage" block. So a new command can't be missing from the help.
# Output format for list and show (HELP_FORMAT overrides): in a terminal, colors and lines wrapped to its width
# ("terminal"; no colors with NO_COLOR set: "plain"); otherwise markdown ("markdown"), which is what the AI shows in
# its reply when /flow-help runs, so Claude Code and Codex draw the headings, bold names and `commands` in color.
# Exit codes: 0 fine, 1 at least one ❌ (check, or an unknown command), 2 wrong usage.
# Only reads. Works in the Mac's own bash 3.2.

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
SKILLS_DIR="${SKILLS_DIR:-$AGENT_ROOT/.agents/skills}"
COMMANDS_DOC="${COMMANDS_DOC:-$AGENT_ROOT/docs/commands.md}"
GUIDE_DOC="${GUIDE_DOC:-$AGENT_ROOT/docs/user-guide.md}"

# Groups shown by "list", in this order. A command that isn't named here still shows, under "Other",
# and "check" fails until it's in a group (rule R17).
GROUP_NAMES="Setup, once, in this order|Every day|Cards|Any time"
GROUP_1="flow-ping flow-doctor flow-configure-user flow-configure-repo flow-setup-repo"
GROUP_2="flow-vpn flow-memory"
GROUP_3="flow-check-card flow-start flow-develop flow-verify flow-ac-check flow-push flow-finish flow-status"
GROUP_4="flow-help"

to_fix=0
to_look=0
pass() { echo "✅ $1"; }
warn() {
  echo "⚠️ $1"
  [ -n "${2:-}" ] && echo "   Tip: $2"
  to_look=$((to_look + 1))
}
fail() {
  echo "❌ $1"
  echo "   Fix: $2"
  to_fix=$((to_fix + 1))
}
usage() {
  echo "Usage: bash scripts/help.sh [list | show <command> | check]"
}

# ---------------------------------------------------------------- output format
if [ -n "${HELP_FORMAT:-}" ]; then FORMAT="$HELP_FORMAT"
elif [ -t 1 ]; then
  if [ -n "${NO_COLOR:-}" ]; then FORMAT="plain"; else FORMAT="terminal"; fi
else FORMAT="markdown"; fi
case "$FORMAT" in markdown|terminal|plain) ;; *) FORMAT="markdown" ;; esac
if [ "$FORMAT" = "terminal" ]; then
  C_HEAD=$'\033[1;36m'; C_NAME=$'\033[1;32m'; C_FORM=$'\033[33m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else
  C_HEAD=""; C_NAME=""; C_FORM=""; C_DIM=""; C_OFF=""
fi
WIDTH="${COLUMNS:-}"
[ -z "$WIDTH" ] && [ -t 1 ] && WIDTH="$(tput cols 2>/dev/null)"
case "$WIDTH" in ''|*[!0-9]*) WIDTH=80 ;; esac
[ "$WIDTH" -gt 100 ] && WIDTH=100
[ "$WIDTH" -lt 40 ] && WIDTH=40
# Prints text wrapped to the width, every line starting with <indent> spaces (terminal and plain formats).
wrap() { # <indent> <text>
  local pad; pad="$(printf '%*s' "$1" '')"
  printf '%s\n' "$2" | fold -s -w "$((WIDTH - $1))" | sed -e 's/[[:space:]]*$//' -e "s/^/$pad/"
}

# ---------------------------------------------------------------- reading the command files
# Every command folder, one name per line (names never contain spaces; paths may, so this prints names only).
all_commands() {
  local d
  for d in "$SKILLS_DIR"/flow-*/; do
    [ -d "$d" ] && basename "$d"
  done
}
skill_file() { echo "$SKILLS_DIR/$1/SKILL.md"; }
# The one-line description from the frontmatter, without the "Runs only when / Starts when the user types…" part.
description_of() { # <command>
  local f; f="$(skill_file "$1")"
  [ -f "$f" ] || return 0
  # a description in quotes (needed in YAML when it holds ": ") is shown without them
  sed -n 's/^description:[[:space:]]*//p' "$f" | head -n 1 | sed -E 's/^"(.*)"[[:space:]]*$/\1/; s/[[:space:]]*(Runs only|Starts) when the user types.*$//'
}
# A one-line summary for the list: the description's first sentence, without the parts in brackets, up to its first colon.
summary_of() { # <command>
  description_of "$1" | awk '{
    s = $0
    if (match(s, /\.[[:space:]]/)) s = substr(s, 1, RSTART)
    while (match(s, /[[:space:]]*\([^()]*\)/)) s = substr(s, 1, RSTART - 1) substr(s, RSTART + RLENGTH)
    if (match(s, /: /)) s = substr(s, 1, RSTART - 1)
    sub(/[.[:space:]]+$/, "", s)
    if (s != "") print s "."
  }'
}
# The lines of the "## Usage" block (up to the next "## " heading).
usage_of() { # <command>
  local f; f="$(skill_file "$1")"
  [ -f "$f" ] || return 0
  awk 'BEGIN{on=0} /^## Usage[[:space:]]*$/{on=1; next} on && /^## /{exit} on{print}' "$f"
}
# The command forms of a usage block, one per line: the first `…` of every "- " line, except the Codex line.
forms_of() { # <command>
  usage_of "$1" | grep -E '^- `' | grep -v -E '^- Codex' | sed -E 's/^- `([^`]*)`.*/\1/'
}
is_command() { [ -d "$SKILLS_DIR/$1" ] && [ -f "$(skill_file "$1")" ]; }
# The "argument-hint:" line of the frontmatter (what Claude Code's / menu shows after the name), "" when there's none.
hint_of() { # <command>
  awk 'NR == 1 && /^---/ { on = 1; next } on && /^---/ { exit } on && /^argument-hint:/ { sub(/^argument-hint:[[:space:]]*/, ""); print; exit }' "$(skill_file "$1")"
}
# Does the command take arguments? Some form in its usage block has more than the command's name.
takes_args() { forms_of "$1" | grep -v -x -F "/$1" | grep -q .; }
# The guide's "mirrored" line: the Claude artifact link, the date and the commands it covers.
mirrored_line() { [ -f "$GUIDE_DOC" ] && grep -m 1 -E 'mirrored on [0-9]{4}-[0-9]{2}-[0-9]{2}.*commands:' "$GUIDE_DOC"; return 0; }
artifact_url() { mirrored_line | grep -o -E 'https://[^ )>]+' | head -n 1; }

# ---------------------------------------------------------------- list
group_heading() { # <text>
  if [ "$FORMAT" = "markdown" ]; then printf '### %s\n\n' "$1"
  else printf '%s%s%s\n\n' "$C_HEAD" "$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')" "$C_OFF"; fi
}
do_list() {
  local shown="" i=1 names group name url
  if [ "$FORMAT" = "markdown" ]; then
    echo "## flow-help: every flow command"
    echo
    echo "Claude Code: \`/flow-<name>\` · Codex: \`\$flow-<name>\` · one command in full: \`/flow-help <command>\`"
  else
    printf '%sflow-help: every flow command%s\n' "$C_HEAD" "$C_OFF"
    wrap 0 "Claude Code: /flow-<name> · Codex: \$flow-<name> · one command in full: /flow-help <command>"
  fi
  echo
  names="$GROUP_NAMES"
  while [ -n "$names" ]; do
    group="${names%%|*}"
    case "$names" in *"|"*) names="${names#*|}" ;; *) names="" ;; esac
    eval "members=\"\$GROUP_$i\""
    group_heading "$group"
    for name in $members; do
      is_command "$name" || continue
      print_command "$name"; shown="$shown $name "
    done
    i=$((i + 1))
  done
  local other=""
  while IFS= read -r name; do
    case "$shown" in *" $name "*) ;; *) other="$other $name" ;; esac
  done < <(all_commands)
  if [ -n "$other" ]; then
    group_heading "Other (not in a group yet: add it to the groups in scripts/help.sh)"
    for name in $other; do print_command "$name"; done
  fi
  url="$(artifact_url)"
  if [ "$FORMAT" = "markdown" ]; then
    echo "Step by step: \`docs/user-guide.md\`${url:+ · Claude artifact: $url} · every detail: \`docs/commands.md\`"
  else
    wrap 0 "${C_DIM}Step by step: docs/user-guide.md${url:+ · Claude artifact: $url} · every detail: docs/commands.md${C_OFF}"
  fi
}
print_command() { # <command>
  local name="$1" summary forms f
  summary="$(summary_of "$name")"; summary="${summary:-(no description in its SKILL.md yet)}"
  forms="$(forms_of "$name")"
  if [ "$FORMAT" = "markdown" ]; then
    echo "**$name** · $summary"
    if [ -n "$forms" ]; then
      while IFS= read -r f; do echo "- \`$f\`"; done <<EOF_FORMS
$forms
EOF_FORMS
    else
      echo "- ⚠️ no \`## Usage\` block in its SKILL.md yet (rule R17)"
    fi
    echo
  else
    printf '  %s%s%s\n' "$C_NAME" "$name" "$C_OFF"
    wrap 4 "$summary"
    if [ -n "$forms" ]; then
      while IFS= read -r f; do printf '      %s%s%s\n' "$C_FORM" "$f" "$C_OFF"; done <<EOF_FORMS
$forms
EOF_FORMS
    else
      wrap 6 "⚠️ no \"## Usage\" block in its SKILL.md yet (rule R17)"
    fi
    echo
  fi
}

# ---------------------------------------------------------------- show
do_show() { # <command>
  local name="$1" lines l
  case "$name" in flow-*) ;; *) name="flow-$name" ;; esac
  if ! is_command "$name"; then
    fail "No flow command called '$name'" "Run /flow-help to see every command (Codex: \$flow-help)."
    return 1
  fi
  lines="$(usage_of "$name" | grep -E '^- ')"
  if [ "$FORMAT" = "markdown" ]; then
    echo "## $name"
    echo
    description_of "$name"
    echo
    if [ -n "$lines" ]; then
      echo "**How to type it**"
      echo
      printf '%s\n' "$lines"
    else
      warn "No \"## Usage\" block in its SKILL.md yet" "Add one (rule R17); flow-help reads it from there."
    fi
    echo
    echo "More: section \`$name\` in \`docs/commands.md\` · step by step: \`docs/user-guide.md\`"
  else
    printf '%s%s%s\n\n' "$C_NAME" "$name" "$C_OFF"
    wrap 2 "$(description_of "$name")"
    echo
    if [ -n "$lines" ]; then
      printf '%sHOW TO TYPE IT%s\n' "$C_HEAD" "$C_OFF"
      while IFS= read -r l; do
        l="${l#- }"
        # the form (first `…`) in color, the rest wrapped under it
        case "$l" in
          '`'*) f="${l#\`}"; f="${f%%\`*}"; rest="${l#\`$f\`}"; rest="${rest#:}"; rest="${rest# }"
                printf '  %s%s%s\n' "$C_FORM" "$f" "$C_OFF"; [ -n "$rest" ] && wrap 4 "$(printf '%s' "$rest" | tr -d '`')" ;;
          *) wrap 2 "$(printf '%s' "$l" | tr -d '`')" ;;
        esac
      done <<EOF_LINES
$lines
EOF_LINES
    else
      warn "No \"## Usage\" block in its SKILL.md yet" "Add one (rule R17); flow-help reads it from there."
    fi
    echo
    wrap 0 "${C_DIM}More: section \"$name\" in docs/commands.md · step by step: docs/user-guide.md${C_OFF}"
  fi
}

# ---------------------------------------------------------------- check (rule R17)
grouped_commands() { # every command named in a GROUP_ line, one per line
  local i=1 members
  while :; do
    eval "members=\"\${GROUP_$i:-}\""
    [ -n "$members" ] || break
    printf '%s\n' $members
    i=$((i + 1))
  done
}

do_check() {
  local name count=0 missing_usage="" missing_hint="" missing_doc="" missing_guide="" missing_mirror="" missing_group="" line grouped
  grouped=" $(grouped_commands | tr '\n' ' ') "
  while IFS= read -r name; do
    count=$((count + 1))
    [ -n "$(usage_of "$name" | grep -E '^- ')" ] || missing_usage="$missing_usage $name"
    if takes_args "$name" && [ -z "$(hint_of "$name")" ]; then missing_hint="$missing_hint $name"; fi
    if [ -f "$COMMANDS_DOC" ]; then
      grep -q -E "^###[[:space:]]+\`$name\`" "$COMMANDS_DOC" || missing_doc="$missing_doc $name"
    fi
    if [ -f "$GUIDE_DOC" ]; then
      grep -q -E "^\|.*\`$name\`" "$GUIDE_DOC" || missing_guide="$missing_guide $name"
    fi
    case "$grouped" in *" $name "*) ;; *) missing_group="$missing_group $name" ;; esac
  done < <(all_commands)

  if [ "$count" -eq 0 ]; then
    fail "No flow commands found in $SKILLS_DIR" "Run it from the closio-agent folder: bash scripts/help.sh check"
    return 1
  fi
  if [ -n "$missing_usage" ]; then
    fail "No \"## Usage\" block in SKILL.md:$missing_usage" "Add a \"## Usage\" section with one \"- \`/flow-…\`: …\" line per form (rule R17); flow-help reads it from there."
  else
    pass "Every command ($count) has its \"## Usage\" block (what flow-help shows)"
  fi
  if [ -n "$missing_hint" ]; then
    fail "No argument-hint in SKILL.md, though the command takes arguments:$missing_hint" "Add a line \"argument-hint: '<its forms, from its ## Usage block>'\" under \"description:\" (e.g. argument-hint: '<CARD-KEY> [full|quick]'); Claude Code shows it in the / menu (rule R17)."
  else
    pass "Every command that takes arguments has its argument-hint (what Claude Code's / menu shows)"
  fi
  if [ -n "$missing_group" ]; then
    fail "Not in a flow-help group (flow-help shows them under \"Other\"):$missing_group" "Add each one to the right GROUP_ line at the top of scripts/help.sh (rule R17)."
  else
    pass "Every command is in a flow-help group"
  fi
  if [ ! -f "$COMMANDS_DOC" ]; then
    fail "docs/commands.md is missing" "Restore it from git."
  elif [ -n "$missing_doc" ]; then
    fail "No section in docs/commands.md:$missing_doc" "Add a \"### \`<command>\`\" section for it (purpose, usage, what it does, files) and a row in the command list (rule R17)."
  else
    pass "Every command has its section in docs/commands.md"
  fi
  if [ ! -f "$GUIDE_DOC" ]; then
    fail "docs/user-guide.md is missing" "Restore it from git."
  elif [ -n "$missing_guide" ]; then
    fail "No row in the command index of docs/user-guide.md:$missing_guide" "Add a step-by-step section and a row in \"Every command and its options\" (rule R17), then update the Claude artifact."
  else
    pass "Every command has its row in docs/user-guide.md"
  fi
  if [ -f "$GUIDE_DOC" ]; then
    line="$(mirrored_line)"
    if [ -z "$line" ]; then
      fail "docs/user-guide.md has no \"mirrored\" line for the Claude artifact" "Put at the top of the guide: **Claude artifact:** <link> · mirrored on <YYYY-MM-DD> · commands: <every command, comma-separated> (rule R17)."
    else
      while IFS= read -r name; do
        printf '%s' "$line" | grep -q -E "commands:.*(^|[ ,])$name([ ,]|$)" || missing_mirror="$missing_mirror $name"
      done < <(all_commands)
      if [ -n "$missing_mirror" ]; then
        fail "The Claude artifact of the guide is behind; not in its \"mirrored\" line:$missing_mirror" "In Claude Code: update the artifact from docs/user-guide.md (link at the top of the guide), then set the \"mirrored\" line to today's date and every command (rule R17, AGENTS.md rule 11). From Codex this can't be done: finish it in Claude Code."
      else
        pass "The Claude artifact covers every command ($(printf '%s' "$line" | sed -E 's/.*mirrored on ([0-9-]+).*/\1/'))"
      fi
    fi
  fi
  [ "$to_fix" -eq 0 ]
}

# ---------------------------------------------------------------- main
action="${1:-list}"
case "$action" in
  list) do_list ;;
  show) [ $# -ge 2 ] && [ -n "$2" ] || { usage; exit 2; }; do_show "$2" || exit 1 ;;
  check) do_check || exit 1 ;;
  -h|--help|help) usage ;;
  *) usage; exit 2 ;;
esac
exit 0
