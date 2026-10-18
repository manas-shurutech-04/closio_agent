#!/usr/bin/env bash
# User memory for the flow-memory command and every other flow command (F6b, D40, D56).
# Your private preferences and corrections. Every flow command loads them first (rule A7);
# team rules always win over them (rule A8).
# Run it from the closio-agent folder:  bash scripts/memory.sh <action>
#
#   for <phase> [words...]          The entries that apply to a command: your general ones for that phase, plus the
#                                   ones for any registered repo named in the words ("all" = every repo). Every
#                                   flow command runs this first.
#   list                            All your entries
#   add <general|repo> <phases> <card|-> <text...>
#                                   phases: all, or a comma list of: setup, pick-up, plan, develop, review,
#                                   ac-check, testing, ship, mr, after-merge
#   edit <id> <text...>             New text for an entry (the other fields stay)
#   set-phases <id> <phases>        New phases for an entry
#   remove <id>                     Removes an entry
#   clear-preview <all|repo>        What 'clear' would remove (only reads)
#   clear <all|repo> confirmed      Removes all your entries, or one repo's (only after the user said yes)
#   count                           Number of entries (for flow-doctor)
#   problems                        Lines in your memory files that aren't in the format (for flow-doctor)
#
# Files (private: local/ is never pushed; created on the first entry):
#   local/memory/general.md          applies everywhere
#   local/memory/repos/<repo>.md     applies only to that repo
# One entry per line (you can also edit the files by hand; lines that don't fit are shown as ⚠️ and ignored):
#   - [M3] 2026-10-16 · phases: plan, develop · from: SCRUM-519 · Write plans as short numbered steps.
# Anything that looks like a secret is refused (D33, rule A6). Every ❌ comes with the steps to fix it (rule A11).

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
MEMORY_DIR="${MEMORY_DIR:-$AGENT_ROOT/local/memory}"
REPOS_DIR="${REPOS_DIR:-$AGENT_ROOT/config/repos}"
CMD="/flow-memory"
PHASES="all setup pick-up plan develop review ac-check testing ship mr after-merge"
SEP=" · "
NL=$'\n'
ENTRY_RE='^- \[M[0-9]+\] [0-9]{4}-[0-9]{2}-[0-9]{2} · phases: [a-z, -]+ · from: [^ ]+ · .+$'

ok() { echo "✅ $1"; }
look() {
  echo "⚠️ $1"
  [ -n "${2:-}" ] && echo "   Tip: $2"
}
bad() {
  echo "❌ $1"
  echo "   Fix: $2"
}

general_file() { echo "$MEMORY_DIR/general.md"; }
repo_file() { echo "$MEMORY_DIR/repos/$1.md"; }
is_repo() { printf '%s' "$1" | grep -q -E '^[a-z0-9][a-z0-9._-]*$' && [ -f "$REPOS_DIR/$1.yaml" ]; }

all_files() { # every memory file that exists, general first; ONE PER LINE (paths can contain spaces,
  # e.g. "AI Pipeline", so callers read this with 'while IFS= read -r', never with 'for f in $(...)')
  local f
  [ -f "$(general_file)" ] && general_file
  for f in "$MEMORY_DIR"/repos/*.md; do [ -f "$f" ] && echo "$f"; done
  return 0
}

scope_of() { # <file>: general, or the repo name
  case "$1" in */repos/*) basename "$1" .md ;; *) echo general ;; esac
}

# Checks a phase list ("all" or "plan, develop") and prints it in the stored form ("plan, develop").
normal_phases() { # <phases>
  local list p out=""
  list="$(printf '%s' "$1" | tr ',' ' ')"
  [ -n "$(printf '%s' "$list" | tr -d ' ')" ] || return 1
  for p in $list; do
    case " $PHASES " in *" $p "*) ;; *) return 1 ;; esac
    case ", $out," in *", $p,"*) ;; *) out="${out:+$out, }$p" ;; esac
  done
  case ", $out," in *", all,"*) out="all" ;; esac
  echo "$out"
}

looks_secret() { # <text>
  printf '%s' "$1" | grep -q -i -E 'glpat-|gh[pousr]_[A-Za-z0-9]{10,}|(^|[^a-z])sk-[A-Za-z0-9_-]{16,}|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{12,}|xox[bpas]-|bearer +[A-Za-z0-9._-]{16,}|(password|passwd|pwd|secret|token|api[_-]?key|client[_-]?secret)[[:space:]]*[:=]|[A-Za-z0-9+=_]{40,}'
}

# Prints problems in hand-edited files: lines that are neither blank, a # comment, nor an entry.
format_problems() {
  local f n line
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    n=0
    while IFS= read -r line || [ -n "$line" ]; do
      n=$((n + 1))
      case "$line" in ''|'#'*) continue ;; esac
      printf '%s\n' "$line" | grep -q -E "$ENTRY_RE" ||
        look "${f#$AGENT_ROOT/} line $n isn't in the memory format, so it's ignored" \
          "Fix it by hand (format: - [M<n>] <date> · phases: <phases> · from: <card or -> · <text>), or remove it with $CMD."
    done < "$f"
  done <<EOF
$(all_files)
EOF
  return 0
}

entries() { # <file>: its valid entry lines
  grep -E "$ENTRY_RE" "$1" 2>/dev/null
  return 0
}

field() { # <entry line> <id|date|phases|from|text>
  local line="$1"
  case "$2" in
    id) printf '%s' "$line" | sed -E 's/^- \[(M[0-9]+)\].*/\1/' ;;
    date) printf '%s' "$line" | sed -E 's/^- \[M[0-9]+\] ([0-9-]+) · .*/\1/' ;;
    phases) printf '%s' "$line" | sed -E 's/^[^·]*· phases: ([^·]*) · from: .*/\1/' ;;
    from) printf '%s' "$line" | sed -E 's/^[^·]*· phases: [^·]* · from: ([^ ]+) · .*/\1/' ;;
    text) printf '%s' "$line" | sed -E 's/^[^·]*· phases: [^·]* · from: [^ ]+ · //' ;;
  esac
}

applies_to() { # <phases field> <phase>
  case ", $1," in *", all,"*|*", $2,"*) return 0 ;; *) return 1 ;; esac
}

next_id() {
  local max=0 n f
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    for n in $(grep -o -E '^- \[M[0-9]+\]' "$f" 2>/dev/null | grep -o -E '[0-9]+'); do
      [ "$n" -gt "$max" ] && max="$n"
    done
  done <<EOF
$(all_files)
EOF
  echo "M$((max + 1))"
}

file_of_id() { # <id>: the file that holds it
  local f
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    grep -q -E "^- \[$1\] " "$f" 2>/dev/null && { echo "$f"; return 0; }
  done <<EOF
$(all_files)
EOF
  return 1
}

replace_line() { # <file> <id> <new line, or "" to remove>
  local file="$1" id="$2" new="$3"
  awk -v id="$id" -v new="$new" '
    index($0, "- [" id "] ") == 1 { if (new != "") print new; next }
    { print }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

valid_id() { printf '%s' "$1" | grep -q -E '^M[0-9]+$'; }

# ---------------------------------------------------------------- actions

for_command() { # <phase> [words...]
  local phase="$1" words f line scope shown=0 out="" repos="" w files
  shift
  case " $PHASES " in *" $phase "*) ;; *) bad "Unknown phase '$phase'" "Use one of: $PHASES"; return 1 ;; esac
  words=" $* "
  # Repos named in the command's words ("all" = every repo with its own memory)
  for f in "$MEMORY_DIR"/repos/*.md; do
    [ -f "$f" ] || continue
    w="$(basename "$f" .md)"
    case "$words" in *" all "*|*" $w "*) repos="$repos $w" ;; esac
  done
  files="$(general_file)"
  for w in $repos; do files="$files$NL$(repo_file "$w")"; done
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    scope="$(scope_of "$f")"
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      applies_to "$(field "$line" phases)" "$phase" || continue
      out="$out- [$(field "$line" id)] ($scope) $(field "$line" text)$NL"
      shown=$((shown + 1))
    done <<EOF
$(entries "$f")
EOF
  done <<EOF
$files
EOF
  if [ "$shown" -eq 0 ]; then
    echo "User memory: nothing applies to this command (that's normal)."
  else
    echo "User memory for this command ($shown $( [ "$shown" -eq 1 ] && echo entry || echo entries )). Apply them; team rules always win, so say so if one conflicts:"
    printf '%s' "$out"
  fi
  format_problems
}

list_all() {
  local f n=0 line scope
  if [ -z "$(all_files)" ]; then
    echo "You have no user memory yet (that's normal). Add an entry with: $CMD add <text>"
    return 0
  fi
  echo "Your user memory (private, in local/memory/)"
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    scope="$(scope_of "$f")"
    echo
    if [ "$scope" = "general" ]; then echo "General (everywhere)"; else echo "Repo: $scope"; fi
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      echo "   [$(field "$line" id)] $(field "$line" text)"
      echo "        phases: $(field "$line" phases) · saved $(field "$line" date)$( [ "$(field "$line" from)" != "-" ] && echo " · from $(field "$line" from)")"
      n=$((n + 1))
    done <<EOF
$(entries "$f")
EOF
  done <<EOF
$(all_files)
EOF
  echo
  echo "Total: $n $( [ "$n" -eq 1 ] && echo entry || echo entries )."
  format_problems
}

add_entry() { # <scope> <phases> <card> <text...>
  local scope="$1" phases_in="$2" phases card="$3" text file id
  shift 3
  text="$*"
  text="$(printf '%s' "$text" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  if [ "$scope" != "general" ] && ! is_repo "$scope"; then
    bad "'$scope' isn't 'general' or a registered repo" "Use general, or a repo name from config/repos/ (e.g. nodejs-ws2closio)."; return 1
  fi
  phases="$(normal_phases "$phases_in")" || { bad "Unknown phases '$phases_in'" "Use all, or a comma list of: ${PHASES#all }"; return 1; }
  printf '%s' "$card" | grep -q -E '^(-|[A-Z][A-Z0-9]+-[0-9]+)$' || { bad "'$card' isn't a card key" "Use a card key like SCRUM-519, or - for none."; return 1; }
  [ -n "$text" ] || { bad "The entry text is empty" "Write what the agent should remember, e.g. $CMD add Write plans as short numbered steps."; return 1; }
  if looks_secret "$text"; then
    bad "This looks like a secret (a token, key or password), so it wasn't saved" "Never put secrets in memory; they go in the Keychain (/flow-configure-user, /flow-configure-repo)."; return 1
  fi
  if [ "$scope" = "general" ]; then file="$(general_file)"; else file="$(repo_file "$scope")"; fi
  mkdir -p "$(dirname "$file")"
  if [ ! -f "$file" ]; then
    if [ "$scope" = "general" ]; then
      printf '# Your user memory: applies everywhere (F6b, D40). Private: local/ is never pushed.\n# One entry per line. Manage it with %s, or edit by hand in the same format.\n\n' "$CMD" > "$file"
    else
      printf '# Your user memory for %s only (F6b, D40). Private: local/ is never pushed.\n# One entry per line. Manage it with %s, or edit by hand in the same format.\n\n' "$scope" "$CMD" > "$file"
    fi
  fi
  id="$(next_id)"
  printf -- '- [%s] %s%sphases: %s%sfrom: %s%s%s\n' "$id" "$(date +%Y-%m-%d)" "$SEP" "$phases" "$SEP" "$card" "$SEP" "$text" >> "$file"
  ok "Saved as $id ($scope · phases: $phases): $text"
}

edit_entry() { # <id> <text...>
  local id="$1" file line text
  shift
  text="$(printf '%s' "$*" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  valid_id "$id" || { bad "'$id' isn't an entry ID" "Use an ID like M3 (see $CMD)."; return 1; }
  file="$(file_of_id "$id")" || { bad "No entry $id" "See your entries with $CMD."; return 1; }
  [ -n "$text" ] || { bad "The new text is empty" "To remove the entry, use $CMD remove $id."; return 1; }
  looks_secret "$text" && { bad "This looks like a secret (a token, key or password), so it wasn't saved" "Never put secrets in memory; they go in the Keychain."; return 1; }
  line="$(grep -m1 -E "^- \[$id\] " "$file")"
  printf '%s' "$line" | grep -q -E "$ENTRY_RE" || { bad "Entry $id isn't in the memory format" "Fix the line by hand in ${file#$AGENT_ROOT/}."; return 1; }
  replace_line "$file" "$id" "- [$id] $(field "$line" date)${SEP}phases: $(field "$line" phases)${SEP}from: $(field "$line" from)${SEP}$text"
  ok "$id changed: $text"
}

set_phases() { # <id> <phases>
  local id="$1" file line phases
  valid_id "$id" || { bad "'$id' isn't an entry ID" "Use an ID like M3 (see $CMD)."; return 1; }
  file="$(file_of_id "$id")" || { bad "No entry $id" "See your entries with $CMD."; return 1; }
  phases="$(normal_phases "$2")" || { bad "Unknown phases '$2'" "Use all, or a comma list of: ${PHASES#all }"; return 1; }
  line="$(grep -m1 -E "^- \[$id\] " "$file")"
  printf '%s' "$line" | grep -q -E "$ENTRY_RE" || { bad "Entry $id isn't in the memory format" "Fix the line by hand in ${file#$AGENT_ROOT/}."; return 1; }
  replace_line "$file" "$id" "- [$id] $(field "$line" date)${SEP}phases: $phases${SEP}from: $(field "$line" from)${SEP}$(field "$line" text)"
  ok "$id now applies to: $phases"
}

remove_entry() { # <id>
  local id="$1" file line
  valid_id "$id" || { bad "'$id' isn't an entry ID" "Use an ID like M3 (see $CMD)."; return 1; }
  file="$(file_of_id "$id")" || { bad "No entry $id" "See your entries with $CMD."; return 1; }
  line="$(grep -m1 -E "^- \[$id\] " "$file")"
  replace_line "$file" "$id" ""
  ok "Removed $id: $(field "$line" text)"
}

# The files 'clear' works on: every memory file (all), or one repo's. One per line.
clear_files() { # <all|repo>
  if [ "$1" = "all" ]; then all_files
  else [ -f "$(repo_file "$1")" ] && repo_file "$1"; fi
  return 0
}

clear_target_ok() { # <all|repo>
  [ "$1" = "all" ] && return 0
  is_repo "$1" && return 0
  bad "'$1' isn't 'all' or a registered repo" "Use $CMD clear (everything) or $CMD clear <repo> (e.g. nodejs-ws2closio)."
  return 1
}

clear_preview() { # <all|repo>
  local target="$1" f line n=0 scope out=""
  clear_target_ok "$target" || return 1
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    scope="$(scope_of "$f")"
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      out="$out   [$(field "$line" id)] ($scope) $(field "$line" text)$NL"
      n=$((n + 1))
    done <<EOF
$(entries "$f")
EOF
  done <<EOF
$(clear_files "$target")
EOF
  if [ "$n" -eq 0 ]; then
    if [ "$target" = "all" ]; then echo "Nothing to clear: you have no memory entries."; else echo "Nothing to clear: you have no memory entries for $target."; fi
    return 0
  fi
  echo "These $n $( [ "$n" -eq 1 ] && echo entry || echo entries ) would be removed$( [ "$target" = "all" ] || echo " ($target only)"):"
  printf '%s' "$out"
  echo "This can't be undone."
}

clear_memory() { # <all|repo> confirmed
  local target="$1" f n=0
  clear_target_ok "$target" || return 1
  if [ "${2:-}" != "confirmed" ]; then
    bad "Clearing needs the user's yes first" "Show '$CMD clear' (it lists what would be removed), ask the user, then run it with 'confirmed'."
    return 1
  fi
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    n=$((n + $(entries "$f" | grep -c .)))
    rm -f "$f"
  done <<EOF
$(clear_files "$target")
EOF
  rmdir "$MEMORY_DIR/repos" 2>/dev/null
  rmdir "$MEMORY_DIR" 2>/dev/null
  if [ "$target" = "all" ]; then
    ok "Removed $n $( [ "$n" -eq 1 ] && echo entry || echo entries ). Your user memory is empty now (that's normal); add entries again any time with $CMD add."
  else
    ok "Removed $n $( [ "$n" -eq 1 ] && echo entry || echo entries ) for $target. Your other entries are kept."
  fi
}

count_entries() {
  local f n=0
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    n=$((n + $(entries "$f" | grep -c .)))
  done <<EOF
$(all_files)
EOF
  echo "$n"
}

# ---------------------------------------------------------------- main

case "${1:-}" in
  for)
    # Runs at the start of every command (Claude Code stops the whole command if this fails), so it never fails:
    # any problem is shown as a ⚠️ line and the command goes on without the memory.
    shift
    if [ $# -lt 1 ]; then echo "⚠️ The memory step was called without a phase, so no user memory was loaded."; exit 0; fi
    ( for_command "$@" ) 2>&1 ||
      echo "⚠️ Couldn't read all of your user memory, so some entries may be missing. Run /flow-memory to check it."
    exit 0 ;;
  list) list_all ;;
  add) [ $# -ge 5 ] || { echo "Usage: bash scripts/memory.sh add <general|repo> <phases> <card|-> <text...>"; exit 1; }; shift; add_entry "$@" ;;
  edit) [ $# -ge 3 ] || { echo "Usage: bash scripts/memory.sh edit <id> <text...>"; exit 1; }; shift; edit_entry "$@" ;;
  set-phases) [ $# -eq 3 ] || { echo "Usage: bash scripts/memory.sh set-phases <id> <phases>"; exit 1; }; set_phases "$2" "$3" ;;
  remove) [ $# -eq 2 ] || { echo "Usage: bash scripts/memory.sh remove <id>"; exit 1; }; remove_entry "$2" ;;
  clear-preview) [ $# -eq 2 ] || { echo "Usage: bash scripts/memory.sh clear-preview <all|repo>"; exit 1; }; clear_preview "$2" ;;
  clear) [ $# -ge 2 ] || { echo "Usage: bash scripts/memory.sh clear <all|repo> confirmed"; exit 1; }; clear_memory "$2" "${3:-}" ;;
  count) count_entries ;;
  problems) format_problems ;;
  *) echo "Usage: bash scripts/memory.sh for <phase> [words...] | list | add <general|repo> <phases> <card|-> <text...> | edit <id> <text...> | set-phases <id> <phases> | remove <id> | clear-preview <all|repo> | clear <all|repo> confirmed | count | problems"; exit 1 ;;
esac
