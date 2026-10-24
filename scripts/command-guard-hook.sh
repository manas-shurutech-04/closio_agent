#!/usr/bin/env bash
# The command guard (D94, rule A32, AGENTS.md rule 30): stops that hold whatever the AI decides, in Claude Code and Codex.
# Wired for every shell command the AI runs: PreToolUse in .claude/settings.json and .codex/hooks.json, plus PostToolUse
# and PostToolUseFailure in Claude Code. Its argument says which tool runs it (claude | codex); both send the same JSON
# on stdin (hook_event_name, session_id, cwd, tool_name "Bash", tool_input.command).
#
# Before a shell command runs (PreToolUse):
#   1. Never, for the AI (the answer says why and what to do instead; the user can still run it themselves):
#      - git that throws work away or rewrites GitHub or GitLab: a forced or deleting push, reset --hard, clean,
#        checkout -- / checkout ., restore, branch -D, stash drop / clear, remote add / set-url / remove / rm / rename;
#      - a plain git push that isn't for this folder: a card's code goes out only through bash scripts/ship.sh;
#      - migrations and seeders outside closio-agent's scripts: npm run migrate… / seed…, sequelize / sequelize-cli;
#      - a recursive rm, sudo, chmod -R, chown -R, docker system / volume / image / container prune and volume rm,
#        dropdb, psql;
#      - anything that names the guard's own records (~/.closio-agent/guard).
#   2. Once per session (the user, 2026-10-24: "ask us once for that session"): the session's first push
#      (ship.sh push / push-update), migration (repo-run.sh migrate), seeder (repo-run.sh seed) and test-data run
#      (db-run.sh run) need the user's OK in the tool itself, which the AI can't give:
#      - Claude Code: the hook answers "ask", so Claude Code shows its own Allow box; once the command has run,
#        PostToolUse (or PostToolUseFailure) keeps that OK for the session and that kind;
#      - Codex (its hooks can't ask yet): a macOS dialog; "Allow for this session" keeps the OK, Deny or no answer in
#        2 minutes stops the command.
#      With the OK kept, the session's next ones of that kind run without a stop.
#   3. A warning the user sees (D95; the user, 2026-10-24: "give a small warning in the chat box that this is being done"):
#      a major step that runs without a question at that moment gets a "⚠️ closio-agent: …" line (systemMessage, shown
#      by Claude Code and Codex themselves): the session's next push, migration, seeder and test-data run, this folder's
#      own git push, a Jira change (jira-api.sh move, comment, edit-comment, assign, sprint; in Claude Code also the Jira
#      connector's move, comment and edit tools, wired with their own matcher) and a write on a merge request
#      (gitlab-mr.sh reply, describe).
#   Everything else: no answer, so the tool's own rules decide (the pre-approvals, its own prompts).
# The OKs are kept outside this folder, in ~/.closio-agent/guard/<session>/<kind>, where the AI can't write without
# asking; removed after 7 days. Never reads .env values or secrets (A6). A problem in the hook itself never blocks.
#
# Test it: echo '{"hook_event_name":"PreToolUse","session_id":"t","cwd":".","tool_name":"Bash","tool_input":{"command":"git reset --hard"}}' | bash scripts/command-guard-hook.sh claude
# Works in the Mac's own bash 3.2.

set -u

TOOL="${1:-claude}"
AGENT_ROOT="$(cd "${0%/*}/.." && pwd -P)"
GUARD_DIR="${GUARD_DIR:-$HOME/.closio-agent/guard}"
OSASCRIPT_BIN="${OSASCRIPT_BIN:-/usr/bin/osascript}"

command -v jq >/dev/null 2>&1 || exit 0
{ IFS= read -r -d '' event; IFS= read -r -d '' session; IFS= read -r -d '' cwd; IFS= read -r -d '' tool; IFS= read -r -d '' cmd
  IFS= read -r -d '' issue; } < <(
  jq -j '(.hook_event_name // ""), "\u0000", (.session_id // ""), "\u0000", (.cwd // ""), "\u0000", (.tool_name // ""), "\u0000",
    (.tool_input.command | if type == "array" then join(" ") else (. // "") end), "\u0000",
    (.tool_input.issueIdOrKey // "" | tostring), "\u0000"' 2>/dev/null)

warn() { jq -n --arg m "$1" '{systemMessage: $m}'; exit 0; }   # <lines>: shown to the user, the command goes on

# The Jira connector's tools that change a card (Claude Code; pre-approved, so they never ask): a warning first
case "${tool:-}" in
  mcp__*__transitionJiraIssue|mcp__*__addOrEditJiraIssueComment|mcp__*__editJiraIssue)
    [ "${event:-}" = PreToolUse ] || exit 0
    case "$tool" in *transition*) what="moving" ;; *Comment*) what="writing a comment on" ;; *) what="changing" ;; esac
    warn "⚠️ closio-agent: $what the Jira card ${issue:-} without asking (pre-approved)." ;;
esac
[ "${tool:-}" = Bash ] && [ -n "${cmd:-}" ] || exit 0
session="$(printf '%s' "${session:-}" | tr -cd 'A-Za-z0-9._-')"

# Most commands name none of these: done at once
case "$cmd" in
  *git*|*npm*|*npx*|*sequelize*|*rm*|*sudo*|*chmod*|*chown*|*docker*|*dropdb*|*psql*|*ship.sh*|*repo-run.sh*|*db-run.sh*|*jira-api.sh*|*gitlab-mr.sh*|*.closio-agent*) ;;
  *) exit 0 ;;
esac

has() { [[ $c =~ $1 ]]; }   # <extended regex>: found in the command (BASH_REMATCH holds the groups)

# The command as one line, without the text of its heredocs (text written to a file isn't a command)
c=""; delim=""
heredoc='(^|[^<])<<-?[[:space:]]*["'"'"']?([A-Za-z_][A-Za-z0-9_]*)'
while IFS= read -r line || [ -n "$line" ]; do
  if [ -n "$delim" ]; then
    trimmed="${line#"${line%%[![:space:]]*}"}"
    [ "$trimmed" = "$delim" ] && delim=""
    continue
  fi
  c="$c ; $line"
  [[ $line =~ $heredoc ]] && delim="${BASH_REMATCH[2]}"
done <<EOF
$cmd
EOF

Q="'"
# Where a command starts: the start, after ; & | ( { ` $( or bash -c ', then any VAR=value and a few wrappers
AT="(^|[;&|({\`]|\\\$\\(|(bash|sh|zsh)[[:space:]]+-[a-z]*c[[:space:]]+[\"$Q])[[:space:]]*(((then|do|else|time|nohup|exec|command|env|xargs)[[:space:]]+)|([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+))*"
ARG="(\"[^\"]*\"|$Q[^$Q]*$Q|[^[:space:];&|]+)"   # one argument, maybe quoted
GIT="${AT}git(([[:space:]]+(-C|-c)[[:space:]]+$ARG)|([[:space:]]+--[a-z-]+(=[^[:space:]]+)?))*[[:space:]]+"
END="([[:space:]]|\$|[;&|)\"$Q])"   # the end of a word
REST='([^;&|]*[[:space:]])?'
unquote() { local p="$1"; p="${p#[\"$Q]}"; printf '%s' "${p%[\"$Q]}"; }

deny() { # <reason>
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}
never="The guard never lets the AI run this (closio-agent's rules)"
user_runs="If it's really needed, ask the user to run it themselves in a terminal."

# The kinds of command that need the user's OK once per session, as found in the command
kinds=""
has "scripts/ship\.sh[[:space:]]+$ARG[[:space:]]+push(-update)?$END" && kinds="$kinds push"
has "scripts/repo-run\.sh[[:space:]]+$ARG[[:space:]]+migrate$END" && kinds="$kinds migration"
has "scripts/repo-run\.sh[[:space:]]+$ARG[[:space:]]+seed$END" && kinds="$kinds seeder"
has "scripts/db-run\.sh[[:space:]]+$ARG[[:space:]]+run$END" && kinds="$kinds test-data"

# After the command ran (Claude Code): the user allowed it, so keep the OK for the session
case "${event:-}" in
  PostToolUse|PostToolUseFailure)
    [ -n "$kinds" ] && [ -n "$session" ] || exit 0
    mkdir -p "$GUARD_DIR/$session" 2>/dev/null || exit 0
    for k in $kinds; do : > "$GUARD_DIR/$session/$k"; done
    find "$GUARD_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null
    exit 0 ;;
  PreToolUse) ;;
  *) exit 0 ;;
esac

# 1. Never
has '\.closio-agent/guard' && deny "$never: the guard's own records are written only by the guard."
has "${GIT}push${REST}(--force|--force-with-lease|--force-if-includes|-f|--delete|-d|--mirror|--prune)(=[^[:space:]]*)?$END" &&
  deny "$never: a forced or deleting push. A card's code goes out only with bash scripts/ship.sh (never forced). $user_runs"
has "${GIT}push${REST}[+:][^[:space:]]" &&
  deny "$never: a push with a + or : refspec (it forces or deletes a branch). A card's code goes out only with bash scripts/ship.sh. $user_runs"
has "${GIT}reset${REST}--hard$END" && deny "$never: git reset --hard (it throws away work). $user_runs"
has "${GIT}clean$END" && deny "$never: git clean (it deletes the files git doesn't track). $user_runs"
has "${GIT}checkout[[:space:]]+(${REST}--|\.)$END" && deny "$never: git checkout -- / git checkout . (it throws away changes). $user_runs"
has "${GIT}restore$END" && deny "$never: git restore (it throws away changes). $user_runs"
has "${GIT}branch${REST}-[a-zA-Z]*D[a-zA-Z]*$END" && deny "$never: git branch -D (it deletes a branch with its commits). $user_runs"
has "${GIT}stash[[:space:]]+(drop|clear)$END" && deny "$never: git stash drop / clear (it throws away saved changes). $user_runs"
has "${GIT}remote[[:space:]]+(add|set-url|remove|rm|rename)$END" && deny "$never: changing a repo's remotes. $user_runs"
has "${AT}npm[[:space:]]+(run|run-script)[[:space:]]+(migrate|seed)" &&
  deny "$never: npm run migrate / seed. Migrations and seeders run only with bash scripts/repo-run.sh <repo> migrate|seed confirmed."
has "${AT}((npx|npm[[:space:]]+exec)[[:space:]]+(-[^[:space:]]+[[:space:]]+)*)?sequelize(-cli)?$END" &&
  deny "$never: sequelize directly. Migrations and seeders run only with bash scripts/repo-run.sh <repo> migrate|seed confirmed."
has "${AT}rm(([[:space:]]+-[a-zA-Z]+)*[[:space:]]+-[a-zA-Z]*[rR][a-zA-Z]*|${REST}--recursive)$END" &&
  deny "$never: a recursive rm (rm -r, rm -rf). Remove single files instead. $user_runs"
has "${AT}sudo$END" && deny "$never: sudo (closio-agent's scripts ask for the Mac password in their own dialog). $user_runs"
has "${AT}(chmod|chown)${REST}-[a-zA-Z]*R[a-zA-Z]*$END" && deny "$never: chmod -R / chown -R. $user_runs"
has "${AT}docker[[:space:]]+(system[[:space:]]+prune|volume[[:space:]]+(rm|prune)|image[[:space:]]+prune|container[[:space:]]+prune)$END" &&
  deny "$never: deleting Docker's data (prune, volume rm). $user_runs"
has "${AT}(dropdb|psql)$END" &&
  deny "$never: dropdb / psql. Test data runs only with bash scripts/db-run.sh (show, then run … confirmed); a read with db-run.sh query."

# A plain git push: only for this folder (closio-agent's own commits); a card's code goes out through ship.sh
if has "${GIT}push$END"; then
  here="$(cd "${cwd:-.}" 2>/dev/null && pwd -P)"
  case "$here/" in "$AGENT_ROOT"/*) ;; *) here="" ;; esac
  other=""
  if has "git([[:space:]]+[^;&|]*)?[[:space:]]-C[[:space:]]+$ARG"; then
    p="$(unquote "${BASH_REMATCH[2]}")"; [ "$p" = "$AGENT_ROOT" ] || [ "$p" = . ] || other=yes
  fi
  if has "${AT}cd[[:space:]]+$ARG"; then
    p="$(unquote "${BASH_REMATCH[${#BASH_REMATCH[@]}-1]}")"; [ "$p" = "$AGENT_ROOT" ] || [ "$p" = . ] || other=yes
  fi
  [ -n "$here" ] && [ -z "$other" ] ||
    deny "$never: a plain git push outside this folder. A card's code goes out only with bash scripts/ship.sh <repo> push (after the user's yes)."
  own_push=yes
fi

# 2. Once per session, and 3. the warnings
short="${cmd%%$'\n'*}"; [ ${#short} -le 160 ] || short="${short:0:157}…"
notes=""
note() { notes="${notes:+$notes
}⚠️ closio-agent: $1"; }
words() { local w="${1# }"; w="${w// /, }"; printf '%s' "${w//test-data/test-data run}"; }
if [ -n "$kinds" ]; then
  missing=""
  for k in $kinds; do [ -n "$session" ] && [ -f "$GUARD_DIR/$session/$k" ] || missing="$missing $k"; done
  if [ -z "$missing" ]; then
    note "the session's next $(words "$kinds") runs without asking (you allowed it for this session): $short"
  elif [ "$TOOL" = codex ]; then
    what="$(words "$missing")"
    text="closio-agent wants to run the first $what of this Codex session:

${cmd:0:400}

Allow for this session: the session's next ones run without asking.
Deny: nothing runs."
    answer="$("$OSASCRIPT_BIN" -e 'on run argv' \
      -e 'display dialog (item 1 of argv) with title "closio-agent" buttons {"Deny", "Allow for this session"} default button "Deny" cancel button "Deny" with icon caution giving up after 120' \
      -e 'end run' "$text" 2>/dev/null)"
    case "$answer" in
      *"button returned:Allow for this session, gave up:false"*) ;;
      *) deny "The user didn't allow the first $what of this session in closio-agent's dialog (Deny, or no answer in 2 minutes). Nothing ran. Ask the user, then run it again." ;;
    esac
    mkdir -p "$GUARD_DIR/$session" 2>/dev/null && for k in $missing; do : > "$GUARD_DIR/$session/$k"; done
  else
    jq -n --arg r "closio-agent: the first $(words "$missing") of this session. Allow it here; the session's next ones then run without asking." \
      '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
    exit 0
  fi
fi
[ -n "${own_push:-}" ] && note "pushing this folder (closio-agent) to GitHub without asking (allowed for this folder): $short"
has "scripts/jira-api\.sh[[:space:]]+(move|comment|edit-comment|assign|sprint)$END" &&
  note "changing the Jira card without asking (pre-approved): $short"
has "scripts/gitlab-mr\.sh[[:space:]]+$ARG[[:space:]]+(reply|describe)$END" &&
  note "writing on the merge request without asking (after your yes): $short"
[ -n "$notes" ] && warn "$notes"
exit 0
