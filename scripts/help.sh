#!/usr/bin/env bash
# Help for the flow commands, and the "every command is listed everywhere" check (F8, D60, rule R17).
# Run it from the closio-agent folder:  bash scripts/help.sh <action>
#
#   list (or nothing)     Every flow command, grouped, with what it does and how it's typed
#   show <command>        One command in full (the "flow-" part can be left out)
#   check                 Rule R17: every command folder has a "## Usage" block, a section in docs/commands.md,
#                         an index row in docs/user-guide.md, and is covered by the guide's "mirrored" line
#                         (the Claude artifact of the guide). ❌ with the fix for anything missing (rule A11).
#
# The text comes from the commands' own files: every folder .agents/skills/flow-*/ is a command; its SKILL.md
# gives the one-line "description:" and the "## Usage" block. So a new command can't be missing from the help.
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
GROUP_3="flow-check-card flow-start flow-status"
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

# ---------------------------------------------------------------- reading the command files
# Every command folder, one name per line (names never contain spaces; paths may, so this prints names only).
all_commands() {
  local d
  for d in "$SKILLS_DIR"/flow-*/; do
    [ -d "$d" ] && basename "$d"
  done
}
skill_file() { echo "$SKILLS_DIR/$1/SKILL.md"; }
# The one-line description from the frontmatter, without the "Runs only when the user types…" sentence.
description_of() { # <command>
  local f; f="$(skill_file "$1")"
  [ -f "$f" ] || return 0
  sed -n 's/^description:[[:space:]]*//p' "$f" | head -n 1 | sed -E 's/[[:space:]]*Runs only when the user types.*$//'
}
# The lines of the "## Usage" block (up to the next "## " heading).
usage_of() { # <command>
  local f; f="$(skill_file "$1")"
  [ -f "$f" ] || return 0
  awk 'BEGIN{on=0} /^## Usage[[:space:]]*$/{on=1; next} on && /^## /{exit} on{print}' "$f"
}
# The command forms of a usage block: the first `…` of every "- " line, except the Codex line.
forms_of() { # <command>
  usage_of "$1" | grep -E '^- `' | grep -v -E '^- Codex' | sed -E 's/^- `([^`]*)`.*/\1/' | awk '{ if (NR > 1) printf " · "; printf "%s", $0 } END { print "" }'
}
is_command() { [ -d "$SKILLS_DIR/$1" ] && [ -f "$(skill_file "$1")" ]; }
# The guide's "mirrored" line: the Claude artifact link, the date and the commands it covers.
mirrored_line() { [ -f "$GUIDE_DOC" ] && grep -m 1 -E 'mirrored on [0-9]{4}-[0-9]{2}-[0-9]{2}.*commands:' "$GUIDE_DOC"; return 0; }
artifact_url() { mirrored_line | grep -o -E 'https://[^ )>]+' | head -n 1; }

# ---------------------------------------------------------------- list
do_list() {
  echo "flow-help — every flow command (Claude Code: /name · Codex: \$name)"
  local shown="" i=1 names group name forms desc
  names="$GROUP_NAMES"
  while [ -n "$names" ]; do
    group="${names%%|*}"
    case "$names" in *"|"*) names="${names#*|}" ;; *) names="" ;; esac
    eval "members=\"\$GROUP_$i\""
    echo; echo "$group"
    for name in $members; do
      is_command "$name" || continue
      print_line "$name"; shown="$shown $name "
    done
    i=$((i + 1))
  done
  local other=""
  while IFS= read -r name; do
    case "$shown" in *" $name "*) ;; *) other="$other $name" ;; esac
  done < <(all_commands)
  if [ -n "$other" ]; then
    echo; echo "Other (not in a group yet: add it to the groups in scripts/help.sh)"
    for name in $other; do print_line "$name"; done
  fi
  echo
  echo "Step-by-step guide: docs/user-guide.md$( [ -n "$(artifact_url)" ] && echo " · Claude artifact: $(artifact_url)")"
  echo "One command in full: /flow-help <command> · every detail: docs/commands.md"
}
print_line() { # <command>
  local name="$1" desc forms
  desc="$(description_of "$name")"; forms="$(forms_of "$name")"
  printf '  %-22s %s\n' "$name" "${desc:-(no description in its SKILL.md yet)}"
  if [ -n "$forms" ]; then printf '  %-22s %s\n' "" "$forms"; else printf '  %-22s %s\n' "" "⚠️ no \"## Usage\" block in its SKILL.md yet (rule R17)"; fi
}

# ---------------------------------------------------------------- show
do_show() { # <command>
  local name="$1"
  case "$name" in flow-*) ;; *) name="flow-$name" ;; esac
  if ! is_command "$name"; then
    fail "No flow command called '$name'" "Run /flow-help to see every command (Codex: \$flow-help)."
    return 1
  fi
  echo "$name — $(description_of "$name")"
  echo
  if [ -n "$(usage_of "$name" | grep -E '^- ')" ]; then
    echo "How to type it:"
    usage_of "$name" | grep -E '^- ' | sed 's/^- /  /'
  else
    warn "No \"## Usage\" block in its SKILL.md yet" "Add one (rule R17); flow-help reads it from there."
  fi
  echo
  echo "More: docs/commands.md (section \"$name\") · step by step: docs/user-guide.md"
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
  local name count=0 missing_usage="" missing_doc="" missing_guide="" missing_mirror="" missing_group="" line grouped
  grouped=" $(grouped_commands | tr '\n' ' ') "
  while IFS= read -r name; do
    count=$((count + 1))
    [ -n "$(usage_of "$name" | grep -E '^- ')" ] || missing_usage="$missing_usage $name"
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
