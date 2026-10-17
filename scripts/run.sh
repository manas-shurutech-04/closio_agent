#!/usr/bin/env bash
# The card's run folder: the agent's memory per Jira card (C1; rule A1, D36, D38, D61).
# Run it from the closio-agent folder:  bash scripts/run.sh <action>
#
#   check-folder                     Is this session in the closio-agent folder? (strict rule, D42)
#   branch <KEY>                     Creates (or checks out) the card's branch of closio-agent, runs/<KEY>:
#                                    from origin/runs/<KEY> if a teammate pushed it, else from origin/main. Never main.
#   create <KEY> "<title>"           Creates runs/<KEY>/ with state.md and history.md (run `branch` first)
#   state <KEY>                      Prints the card's state (from this Mac, else from the pushed branch)
#   get <KEY> <field>                One field of the state
#   set <KEY> <field> <value...>     Changes one field (and 'updated')
#   log <KEY> <step> "<what>" ["<rules and memory applied>"]
#                                    Appends one history line (rule A1; the last column is rule A17)
#   save <KEY> "<message>"           Commits runs/<KEY>/ on the card's branch and pushes it (D61)
#   list                             Every card in progress, from the run branches on this Mac and on origin
#   count | problems                 For flow-doctor
#
# Files (plain markdown, never a secret):
#   runs/<KEY>/state.md     key: value lines (card, title, type, phase, step, jira_status, repos, branch, run_branch, next, updated)
#   runs/<KEY>/history.md   a table: when · step · what happened · rules and memory applied
#   runs/<KEY>/card.md      the card as read from Jira (+ what the user explained)   } written by the command
#   runs/<KEY>/plan.md      the approved plan                                         }
# Every ❌ comes with the steps to fix it (rule A11). Works in the Mac's own bash 3.2.

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
RUNS_DIR="${RUNS_DIR:-$AGENT_ROOT/runs}"
CMD="/flow-start"
FIELDS="card title type phase step jira_status repos branch run_branch next updated"

ok() { echo "✅ $1"; }
look() {
  echo "⚠️ $1"
  [ -n "${2:-}" ] && echo "   Tip: $2"
}
bad() {
  echo "❌ $1"
  echo "   Fix: $2"
}
usage() {
  echo "Usage: bash scripts/run.sh check-folder | branch <KEY> | create <KEY> \"<title>\" | state <KEY> | get <KEY> <field>"
  echo "       | set <KEY> <field> <value> | log <KEY> <step> \"<what>\" [\"<rules and memory>\"] | save <KEY> \"<message>\" | list | count | problems"
}
now() { date '+%Y-%m-%d %H:%M'; }
valid_key() { printf '%s' "$1" | grep -q -E "^$JIRA_PROJECT_KEY-[0-9]+$"; }
run_dir() { echo "$RUNS_DIR/$1"; }
state_file() { echo "$RUNS_DIR/$1/state.md"; }
history_file() { echo "$RUNS_DIR/$1/history.md"; }
run_branch() { echo "${RUN_BRANCH_PREFIX}$1"; }
rel_runs() { # the runs folder relative to the git root (for git commands and `git show`)
  local root; root="$(git -C "$AGENT_ROOT" rev-parse --show-toplevel 2>/dev/null)" || { echo runs; return; }
  printf '%s' "$RUNS_DIR" | sed -E "s#^$(printf '%s' "$root" | sed 's/[.[\*^$]/\\&/g')/##"
}
need_key() { # <key>
  if [ -z "${1:-}" ] || ! valid_key "$1"; then
    bad "'${1:-}' isn't a card key" "Give the key as in Jira, e.g. $JIRA_PROJECT_KEY-567."; exit 2
  fi
}
git_here() { git -C "$AGENT_ROOT" "$@"; }
current_branch() { git_here rev-parse --abbrev-ref HEAD 2>/dev/null; }
field_value() { # <file> <field>
  [ -f "$1" ] || return 0
  grep -m1 -E "^$2:" "$1" | sed -E "s/^$2:[[:space:]]*//; s/[[:space:]]+$//"
}
set_field() { # <file> <field> <value>
  local tmp; tmp="$(mktemp)"
  awk -v k="$2" -v v="$3" 'BEGIN{done=0} { if (!done && index($0, k ":") == 1) { print k ": " v; done=1 } else print } END { if (!done) print k ": " v }' "$1" > "$tmp" && mv "$tmp" "$1"
}

# ---------------------------------------------------------------- where the state comes from
# Prints the state of a card: the file on this Mac, or the copy on the run branch (local or origin).
state_text() { # <key> -> prints the text; return 1 if none
  local f; f="$(state_file "$1")"
  if [ -f "$f" ]; then cat "$f"; return 0; fi
  local rel; rel="$(rel_runs)/$1/state.md"
  git_here show "refs/heads/$(run_branch "$1"):$rel" 2>/dev/null && return 0
  git_here show "refs/remotes/$GIT_REMOTE/$(run_branch "$1"):$rel" 2>/dev/null && return 0
  return 1
}
state_source() { # <key>: "this Mac" | "the branch on this Mac" | "origin"
  [ -f "$(state_file "$1")" ] && { echo "this Mac"; return; }
  git_here show-ref --verify --quiet "refs/heads/$(run_branch "$1")" && { echo "the branch $(run_branch "$1") on this Mac (not checked out)"; return; }
  echo "$GIT_REMOTE (pushed by a teammate; run: bash scripts/run.sh branch $1)"
}
all_keys() { # every card with a run folder here or a run branch here or on origin, one per line, sorted
  { for d in "$RUNS_DIR"/*/; do [ -f "$d/state.md" ] && basename "$d"; done
    git_here for-each-ref --format='%(refname:short)' "refs/heads/${RUN_BRANCH_PREFIX}" "refs/remotes/$GIT_REMOTE/${RUN_BRANCH_PREFIX}" 2>/dev/null \
      | sed -E "s#^($GIT_REMOTE/)?${RUN_BRANCH_PREFIX}##"
  } | grep -E "^$JIRA_PROJECT_KEY-[0-9]+$" | sort -u
}

# ---------------------------------------------------------------- actions
do_check_folder() {
  if [ "$(pwd -P)" = "$AGENT_ROOT" ]; then ok "Started in the closio-agent folder"; return 0; fi
  bad "Not started in the closio-agent folder (current folder: $(pwd))" \
    "Quit, open a terminal in $AGENT_ROOT, run 'nvm use v$NODE_MAJOR', then start Claude Code or Codex again."
  return 1
}

do_branch() { # <key>
  local key="$1" br cur changed
  br="$(run_branch "$key")"
  git_here rev-parse --is-inside-work-tree >/dev/null 2>&1 || { bad "closio-agent isn't a git repository here" "Clone it from GitHub (setup guide, section 1) and start again."; return 1; }
  cur="$(current_branch)"
  if [ "$cur" = "$br" ]; then ok "On the card's branch $br"; return 0; fi
  git_here fetch -q "$GIT_REMOTE" 2>/dev/null || look "Couldn't fetch from $GIT_REMOTE (no network?)" "A teammate's run branch may be missed; the branch is made from what's on this Mac."
  changed="$(git_here status --porcelain --untracked-files=no | wc -l | tr -d ' ')"
  if git_here show-ref --verify --quiet "refs/heads/$br"; then
    git_here checkout -q "$br" || { bad "Couldn't switch to $br" "Commit or stash your changes in closio-agent, then run: bash scripts/run.sh branch $key"; return 1; }
    ok "Switched to the card's branch $br (it already existed on this Mac)"
  elif git_here show-ref --verify --quiet "refs/remotes/$GIT_REMOTE/$br"; then
    git_here checkout -q -b "$br" --track "$GIT_REMOTE/$br" || { bad "Couldn't create $br from $GIT_REMOTE/$br" "Commit or stash your changes in closio-agent, then run: bash scripts/run.sh branch $key"; return 1; }
    ok "Created the card's branch $br from $GIT_REMOTE (a teammate already worked on this card; its run folder is here now)"
  else
    local from="$GIT_REMOTE/main"
    git_here show-ref --verify --quiet "refs/remotes/$GIT_REMOTE/main" || from="main"
    git_here checkout -q -b "$br" "$from" || { bad "Couldn't create $br from $from" "Commit or stash your changes in closio-agent, then run: bash scripts/run.sh branch $key"; return 1; }
    ok "Created the card's branch $br from $from (closio-agent's main is never used for run folders, D61)"
  fi
  [ "$changed" -gt 0 ] && look "$changed uncommitted change(s) in closio-agent came along to $br" "They're untouched; 'save' commits only the run folder. Commit them on their own branch when you're ready."
  return 0
}

do_create() { # <key> <title>
  local key="$1" title="${2:-}" d
  d="$(run_dir "$key")"
  if [ -f "$(state_file "$key")" ]; then look "The run folder runs/$key already exists (resuming)" "See where it stands: bash scripts/run.sh state $key"; return 0; fi
  [ "$(current_branch)" = "$(run_branch "$key")" ] || { bad "Not on the card's branch $(run_branch "$key")" "Run first: bash scripts/run.sh branch $key"; return 1; }
  mkdir -p "$d" || { bad "Couldn't create $d" "Check the folder's permissions."; return 1; }
  {
    echo "# $key — ${title:-(title not read yet)}"
    echo "card: $key"
    echo "title: $title"
    echo "type: "
    echo "phase: pick-up"
    echo "step: 1"
    echo "jira_status: "
    echo "repos: "
    echo "branch: "
    echo "run_branch: $(run_branch "$key")"
    echo "next: $CMD $key"
    echo "updated: $(now)"
  } > "$(state_file "$key")"
  {
    echo "# $key — history"
    echo
    echo "One line per step (rule A1). The last column says which team rules and user-memory entries were applied before the step (rule A17)."
    echo
    echo "| When | Step | What happened | Rules and memory applied |"
    echo "|---|---|---|---|"
    echo "| $(now) | pick-up 1 | Run folder created on the branch $(run_branch "$key") | rules: A1 · memory: — |"
  } > "$(history_file "$key")"
  ok "Run folder created: runs/$key/ (state.md, history.md) on the branch $(run_branch "$key")"
}

do_state() { # <key>
  local key="$1" text
  text="$(state_text "$key")" || { look "No run folder for $key on this Mac or on $GIT_REMOTE" "Pick the card up with $CMD $key (Codex: \$flow-start $key)."; return 1; }
  echo "$text"
  echo
  echo "From: $(state_source "$key")"
  return 0
}

do_get() { # <key> <field>
  local text; text="$(state_text "$1")" || return 1
  printf '%s\n' "$text" | grep -m1 -E "^$2:" | sed -E "s/^$2:[[:space:]]*//; s/[[:space:]]+$//"
}

do_set() { # <key> <field> <value...>
  local key="$1" field="$2"; shift 2
  local value="$*" f
  f="$(state_file "$key")"
  [ -f "$f" ] || { bad "No run folder for $key on this Mac" "Run: bash scripts/run.sh branch $key (then create it if it's new)."; return 1; }
  case " $FIELDS " in *" $field "*) ;; *) bad "'$field' isn't a state field" "Fields: $FIELDS"; return 2 ;; esac
  set_field "$f" "$field" "$value"
  [ "$field" = "updated" ] || set_field "$f" updated "$(now)"
  ok "$key: $field = $value"
}

do_log() { # <key> <step> <what> [<rules and memory>]
  local key="$1" step="$2" what="$3" applied="${4:-rules: — · memory: —}" f
  f="$(history_file "$key")"
  [ -f "$f" ] || { bad "No run folder for $key on this Mac" "Run: bash scripts/run.sh branch $key (then create it if it's new)."; return 1; }
  what="$(printf '%s' "$what" | tr '\n' ' ' | sed 's/|/\\|/g')"
  applied="$(printf '%s' "$applied" | tr '\n' ' ' | sed 's/|/\\|/g')"
  printf '| %s | %s | %s | %s |\n' "$(now)" "$step" "$what" "$applied" >> "$f"
  set_field "$(state_file "$key")" updated "$(now)"
  ok "$key: history: $step: $what"
}

do_save() { # <key> <message>
  local key="$1" msg="${2:-update}" br rel
  br="$(run_branch "$key")"; rel="$(rel_runs)/$key"
  [ -d "$(run_dir "$key")" ] || { bad "No run folder runs/$key to save" "Run: bash scripts/run.sh branch $key, then create it."; return 1; }
  [ "$(current_branch)" = "$br" ] || { bad "Not on the card's branch $br (on $(current_branch))" "Run: bash scripts/run.sh branch $key, then save again. Run folders never go on main (D61)."; return 1; }
  git_here add -- "$rel" || { bad "Couldn't stage runs/$key" "Check git in the closio-agent folder."; return 1; }
  if git_here diff --cached --quiet -- "$rel"; then ok "Nothing new to save in runs/$key"; return 0; fi
  git_here commit -q -m "$key: $msg" -- "$rel" || { bad "Couldn't commit runs/$key" "Check 'git status' in the closio-agent folder (a merge in progress? git name and email set?)."; return 1; }
  if git_here push -q -u "$GIT_REMOTE" "$br" 2>/dev/null; then
    ok "Saved and pushed: runs/$key on $br ($key: $msg)"
  else
    bad "Committed on $br, but the push to $GIT_REMOTE failed" "Check your network and GitHub login, then run: bash scripts/run.sh save $key \"$msg\" (it pushes the commit that's already made)."
    return 1
  fi
}

do_list() {
  local key n=0 text phase step next updated where
  while IFS= read -r key; do
    [ -n "$key" ] || continue
    n=$((n + 1))
    text="$(state_text "$key")" || { look "$key: a run branch exists but its state can't be read" "Run: bash scripts/run.sh branch $key"; continue; }
    phase="$(printf '%s\n' "$text" | grep -m1 '^phase:' | sed 's/^phase:[[:space:]]*//')"
    step="$(printf '%s\n' "$text" | grep -m1 '^step:' | sed 's/^step:[[:space:]]*//')"
    next="$(printf '%s\n' "$text" | grep -m1 '^next:' | sed 's/^next:[[:space:]]*//')"
    updated="$(printf '%s\n' "$text" | grep -m1 '^updated:' | sed 's/^updated:[[:space:]]*//')"
    where="$(state_source "$key")"
    echo "$key · phase $phase, step $step · next: $next · updated $updated · from $where"
  done < <(all_keys)
  [ "$n" -eq 0 ] && echo "No card in progress (no run folder here, no run branch on $GIT_REMOTE)."
  return 0
}

do_count() { all_keys | grep -c '' ; return 0; }

do_problems() { # for flow-doctor: ❌ lines only
  local key f field
  for d in "$RUNS_DIR"/*/; do
    [ -d "$d" ] || continue
    key="$(basename "$d")"
    valid_key "$key" || { bad "runs/$key isn't a card key" "Rename or remove the folder; run folders are named after the card (e.g. $JIRA_PROJECT_KEY-567)."; continue; }
    f="$d/state.md"
    [ -f "$f" ] || { bad "runs/$key has no state.md" "Pick the card up again with $CMD $key, or remove the folder."; continue; }
    for field in card phase step next updated; do
      [ -n "$(field_value "$f" "$field")" ] || bad "runs/$key/state.md has no '$field' line" "Add it, or pick the card up again with $CMD $key."
    done
    [ -f "$d/history.md" ] || bad "runs/$key has no history.md" "Pick the card up again with $CMD $key."
  done
  return 0
}

# ---------------------------------------------------------------- main
action="${1:-}"
case "$action" in
  check-folder) do_check_folder ;;
  branch) need_key "${2:-}"; do_branch "$2" ;;
  create) need_key "${2:-}"; do_create "$2" "${3:-}" ;;
  state) need_key "${2:-}"; do_state "$2" ;;
  get) need_key "${2:-}"; [ -n "${3:-}" ] || { usage; exit 2; }; do_get "$2" "$3" ;;
  set) need_key "${2:-}"; [ -n "${3:-}" ] && [ $# -ge 4 ] || { usage; exit 2; }; k="$2"; f="$3"; shift 3; do_set "$k" "$f" "$@" ;;
  log) need_key "${2:-}"; [ -n "${3:-}" ] && [ -n "${4:-}" ] || { usage; exit 2; }; do_log "$2" "$3" "$4" "${5:-}" ;;
  save) need_key "${2:-}"; do_save "$2" "${3:-}" ;;
  list) do_list ;;
  count) do_count ;;
  problems) do_problems ;;
  -h|--help|help|"") usage; [ -n "$action" ] && exit 0 || exit 2 ;;
  *) usage; exit 2 ;;
esac
