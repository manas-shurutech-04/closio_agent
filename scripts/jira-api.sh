#!/usr/bin/env bash
# Jira through its REST API: the backup for when the Jira connector isn't there (D88, rule A31).
# The commands use the Jira connector first (Claude Code: "claude.ai Atlassian MCP"; Codex: the Atlassian app). When its
# tools still aren't there after the 3 tries, or a Jira tool fails or can't do an action, they switch to this script by
# themselves, say so in one line, and do the same thing here. Run it from the closio-agent folder:
#
#   bash scripts/jira-api.sh check
#       Is the backup set up, and does Jira accept it? Only ⚠️, never ❌: the backup is optional (flow-doctor). Only reads.
#   bash scripts/jira-api.sh me
#       Your Jira account ID and name (flow-configure-user jira-account-id). Only reads.
#   bash scripts/jira-api.sh get <KEY>
#       The card: summary, type, status, assignee, sprint, its links and web links, and its description as Markdown,
#       the way the connector shows it (flow-check-card, flow-start, flow-grill, flow-push, flow-finish, flow-qa). Only reads.
#   bash scripts/jira-api.sh status <KEY> [<KEY> …]
#       Each card's status, one line each (flow-finish, flow-qa). Only reads.
#   bash scripts/jira-api.sh comments <KEY>
#       Every comment, oldest first: its id, author (name and account ID), date and text as Markdown; then the newest
#       comment's id (flow-qa). Only reads.
#   bash scripts/jira-api.sh transitions <KEY>
#       The moves the card can make now. Only reads.
#   bash scripts/jira-api.sh move <KEY> "<status>"
#       Moves the card to In Development, Code Review or Ready for Test; nowhere else, never to Blocked (rule A3).
#   bash scripts/jira-api.sh assign <KEY>
#       Assigns the card to you (JIRA_ACCOUNT_ID in local/user-settings.sh; flow-start).
#   bash scripts/jira-api.sh sprint <KEY>
#       Puts the card in project SCRUM's active sprint (flow-start).
#   bash scripts/jira-api.sh comment <KEY> <file>
#       Posts the Markdown in <file> as a new comment, as you; prints its id (flow-push, flow-finish, flow-qa).
#   bash scripts/jira-api.sh edit-comment <KEY> <comment id> <file>
#       Replaces that comment's text with the Markdown in <file> (flow-finish, on a later run).
#   bash scripts/jira-api.sh create <Bug|Story|Task> <file> [--relates <KEY>]
#       Creates a card in project SCRUM, from <file>: its first line "Title: …" (or "# …") is the summary, the rest the
#       description. With --relates, links it to <KEY> as "relates to". Prints the new key (flow-qa). Never pre-approved.
#
# The login: your Atlassian email (JIRA_EMAIL in local/user-settings.sh: /flow-configure-user jira-email) and your Atlassian
# API token (closio-agent.jira-api-token in the Keychain: /flow-configure-user jira-api-token). The token is read here and
# handed to curl on stdin: it's never printed, written to a file or put on a command line (rule A6). No VPN needed.
# Exit codes: 0 fine · 1 ❌ · 2 wrong usage · 3 the backup isn't set up (no email or no token). Works in the Mac's own
# bash 3.2; needs curl, jq and base64.

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
USER_SETTINGS_FILE="${USER_SETTINGS_FILE:-$AGENT_ROOT/local/user-settings.sh}"
JIRA_EMAIL=""
JIRA_ACCOUNT_ID=""
[ -f "$USER_SETTINGS_FILE" ] && . "$USER_SETTINGS_FILE"
API="${JIRA_API_URL:-https://$JIRA_SITE}"
TO_MD="$AGENT_ROOT/scripts/lib/adf-to-markdown.jq"
TO_WIKI="$AGENT_ROOT/scripts/lib/markdown-to-wiki.jq"
# The only moves a command makes (rule A3): flow-start and flow-qa → In Development, flow-push → Code Review,
# flow-finish and flow-qa → Ready for Test.
MOVES_ALLOWED="In Development|Code Review|Ready for Test"

ok() { echo "✅ $1"; }
look() { echo "⚠️ $1"; echo "   Tip: $2"; }
bad() { echo "❌ $1"; echo "   Fix: $2"; }
usage() {
  echo "Usage: bash scripts/jira-api.sh check | me | get <KEY> | status <KEY> [<KEY> …] | comments <KEY> | transitions <KEY>"
  echo "       | move <KEY> \"<status>\" | assign <KEY> | sprint <KEY> | comment <KEY> <file> | edit-comment <KEY> <comment id> <file>"
  echo "       | create <Bug|Story|Task> <file> [--relates <KEY>]"
}
# SECURITY_BIN can be a stand-in for the build tests only (like gitlab-mr.sh); normally the macOS "security" tool.
token() { "${SECURITY_BIN:-security}" find-generic-password -a "$USER" -s "$KEYCHAIN_PREFIX.jira-api-token" -w 2>/dev/null; }

# One API call: api <METHOD> <path> [<json body file>]; sets CODE and BODY. The login goes to curl on stdin (-H @-).
api() {
  local method="$1" path="$2" data="${3:-}" tok auth out
  [ -n "$JIRA_EMAIL" ] || { CODE="no-email"; BODY=""; return 1; }
  tok="$(token)"
  [ -n "$tok" ] || { CODE="no-token"; BODY=""; return 1; }
  auth="$(printf '%s:%s' "$JIRA_EMAIL" "$tok" | base64 | tr -d '\n')"
  tok=""
  if [ -n "$data" ]; then
    out="$(printf 'Authorization: Basic %s\n' "$auth" | curl -sS --max-time "$JIRA_API_TIMEOUT" -X "$method" -H @- -H 'Accept: application/json' -H 'Content-Type: application/json' --data-binary @"$data" -w '\n%{http_code}' "$API$path" 2>/dev/null)"
  else
    out="$(printf 'Authorization: Basic %s\n' "$auth" | curl -sS --max-time "$JIRA_API_TIMEOUT" -X "$method" -H @- -H 'Accept: application/json' -w '\n%{http_code}' "$API$path" 2>/dev/null)"
  fi
  auth=""
  CODE="$(printf '%s' "$out" | tail -1)"; BODY="$(printf '%s' "$out" | sed '$d')"
  case "$CODE" in 2??) return 0 ;; *) return 1 ;; esac
}
jira_message() { printf '%s' "$BODY" | jq -r '[(.errorMessages // [])[], ((.errors // {}) | to_entries[] | "\(.key): \(.value)")] | join("; ")' 2>/dev/null | head -c 300; }
api_problem() { # <what was asked>: the ❌ line for a failed call; returns the exit code to use
  case "$CODE" in
    no-email) bad "The Jira API backup isn't set up: no Atlassian email saved" "Run /flow-configure-user jira-email, then /flow-configure-user jira-api-token (Codex: \$flow-configure-user …)."; return 3 ;;
    no-token) bad "The Jira API backup isn't set up: no Atlassian API token in the Keychain" "Run /flow-configure-user jira-api-token (Codex: \$flow-configure-user jira-api-token)."; return 3 ;;
    000|"") bad "Jira didn't answer ($1)" "Check this Mac's internet connection (Jira doesn't need the VPN), then run this again." ;;
    401) bad "Jira refused your email and API token ($1: 401)" "Check the email is the one you log in to Jira with (/flow-configure-user jira-email). The token may have expired or been revoked: make a new one (setup guide, section 3), then /flow-configure-user jira-api-token." ;;
    403) bad "Your Jira account may not do this ($1: 403)" "Check you can do it in Jira yourself (project $JIRA_PROJECT_KEY); if not, ask a Jira admin. $(jira_message)" ;;
    404) bad "Jira found nothing for $1 (404)" "Check the card key (and the comment id). $(jira_message)" ;;
    *) bad "Jira answered $CODE ($1): $(jira_message)" "Read the message; fix it, then run this again." ;;
  esac
  return 1
}

valid_key() { printf '%s' "$1" | grep -q -E '^[A-Z][A-Z0-9]+-[0-9]+$'; }
need_key() { # <key>: upper-cased into KEY, or wrong usage
  KEY="$(printf '%s' "${1:-}" | tr '[:lower:]' '[:upper:]')"
  valid_key "$KEY" || { bad "'${1:-}' isn't a card key" "Use a key like $JIRA_PROJECT_KEY-567."; return 2; }
}
need_file() { [ -s "$1" ] || { bad "No file '$1' (or it's empty)" "Write the text to a file first (the card's folder keeps it), then run this again."; return 2; }; }
json_file() { local f; f="$(mktemp)"; chmod 600 "$f"; cat > "$f"; printf '%s' "$f"; }
to_wiki() { jq -Rs -j -f "$TO_WIKI" "$1"; }

sprint_field() { # sets SPRINT_FIELD: the id of Jira's Sprint field
  api GET "/rest/api/3/field" || { api_problem "the list of fields"; return; }
  SPRINT_FIELD="$(printf '%s' "$BODY" | jq -r '[.[] | select(.schema.custom == "com.pyxis.greenhopper.jira:gh-sprint") | .id][0] // empty')"
  [ -n "$SPRINT_FIELD" ] || { bad "Jira has no Sprint field" "Check that project $JIRA_PROJECT_KEY uses a Scrum board; set the sprint by hand in Jira."; return 1; }
}

# ---------------------------------------------------------------- reads

do_check() {
  [ -n "$JIRA_EMAIL" ] || { look "The Jira API backup isn't set up (optional): no Atlassian email" "If the Jira connector is ever missing, the commands switch to it by themselves. To set it up: /flow-configure-user jira-email, then /flow-configure-user jira-api-token (setup guide, section 3)."; return 3; }
  [ -n "$(token)" ] || { look "The Jira API backup isn't set up (optional): no Atlassian API token in the Keychain" "Run /flow-configure-user jira-api-token (setup guide, section 3)."; return 3; }
  if api GET "/rest/api/3/myself"; then
    ok "The Jira API backup works: signed in as $(printf '%s' "$BODY" | jq -r '.displayName // "?"') ($JIRA_EMAIL)"
    return 0
  fi
  case "$CODE" in
    000|"") look "The Jira API backup can't reach Jira" "Check this Mac's internet connection, then check again." ;;
    401) look "Jira refused the Jira API backup's email and token (401)" "Check the email (/flow-configure-user jira-email); the token may have expired: make a new one (setup guide, section 3), then /flow-configure-user jira-api-token." ;;
    *) look "The Jira API backup got $CODE from Jira: $(jira_message)" "Read the message; fix it, then check again." ;;
  esac
  return 1
}

do_me() {
  api GET "/rest/api/3/myself" || { api_problem "who you are"; return; }
  ok "Signed in to Jira as $(printf '%s' "$BODY" | jq -r '.displayName // "?"')"
  echo "Account ID: $(printf '%s' "$BODY" | jq -r '.accountId // empty')"
}

do_get() {
  need_key "${1:-}" || return
  sprint_field || return
  api GET "/rest/api/3/issue/$KEY?fields=summary,issuetype,status,assignee,description,issuelinks,$SPRINT_FIELD" || { api_problem "$KEY"; return; }
  local issue="$BODY" links="none"
  if api GET "/rest/api/3/issue/$KEY/remotelink"; then
    links="$(printf '%s' "$BODY" | jq -r 'if length == 0 then "none" else map("\(.object.title // "link") — \(.object.url // "")") | join("; ") end')"
  fi
  printf '%s' "$issue" | jq -r --arg sf "$SPRINT_FIELD" --arg web "$links" '
    .fields as $f
    | "\(.key) — \($f.summary // "")",
      "Type: \($f.issuetype.name // "?") · Status: \($f.status.name // "?") · Assignee: \(if $f.assignee then "\($f.assignee.displayName) (\($f.assignee.accountId))" else "nobody" end)",
      "Sprint: \(($f[$sf] // []) | if length == 0 then "none" else map("\(.name) (\(.state), id \(.id))") | join("; ") end)",
      "Issue links: \(($f.issuelinks // []) | if length == 0 then "none" else map(if .outwardIssue then "\(.type.outward) \(.outwardIssue.key) (\(.outwardIssue.fields.status.name // "?"))" else "\(.type.inward) \(.inwardIssue.key) (\(.inwardIssue.fields.status.name // "?"))" end) | join("; ") end)",
      "Web links: \($web)",
      "Description (Markdown):"'
  printf '%s' "$issue" | jq '.fields.description' | jq -r -f "$TO_MD"
}

do_status() {
  local k rc=0
  [ $# -ge 1 ] || { usage; return 2; }
  for k in "$@"; do
    need_key "$k" || return
    if api GET "/rest/api/3/issue/$KEY?fields=status,summary"; then
      printf '%s' "$BODY" | jq -r '"\(.key): \(.fields.status.name) · \(.fields.summary)"'
    else
      api_problem "$KEY"; rc=$?
      [ "$rc" -eq 3 ] && return 3
    fi
  done
  return "$rc"
}

do_comments() {
  need_key "${1:-}" || return
  local start=0 total=1 page n=0 newest=""
  while [ "$start" -lt "$total" ]; do
    api GET "/rest/api/3/issue/$KEY/comment?orderBy=created&startAt=$start&maxResults=100" || { api_problem "the comments of $KEY"; return; }
    page="$BODY"
    total="$(printf '%s' "$page" | jq -r '.total // 0')"
    n="$(printf '%s' "$page" | jq -r '.comments | length')"
    [ "$n" -gt 0 ] || break
    printf '%s' "$page" | jq -c '.comments[]' | while IFS= read -r c; do
      printf '%s' "$c" | jq -r '"--- Comment \(.id) · \(.author.displayName // "?") (\(.author.accountId // "?")) · \(.created // "" | "\(.[0:10]) \(.[11:16]) \(.[-5:])")"'
      printf '%s' "$c" | jq '.body' | jq -r -f "$TO_MD"
    done
    newest="$(printf '%s' "$page" | jq -r '.comments[-1].id')"
    start=$((start + n))
  done
  if [ -n "$newest" ]; then echo "Newest comment id: $newest"; else echo "No comments on $KEY."; fi
}

do_transitions() {
  need_key "${1:-}" || return
  api GET "/rest/api/3/issue/$KEY/transitions" || { api_problem "the moves of $KEY"; return; }
  printf '%s' "$BODY" | jq -r --arg k "$KEY" '"\($k) can move to: " + (if (.transitions | length) == 0 then "nothing" else (.transitions | map("\(.to.name) (transition \(.id))") | join(", ")) end)'
}

# ---------------------------------------------------------------- writes

do_move() {
  need_key "${1:-}" || return
  local want="${2:-}" target now id body
  target="$(printf '%s' "$MOVES_ALLOWED" | tr '|' '\n' | awk -v w="$want" 'tolower($0) == tolower(w)')"
  [ -n "$target" ] || { bad "closio-agent doesn't move a card to '$want'" "It only moves a card to In Development, Code Review or Ready for Test, never to Blocked (rule A3). Move it by hand in Jira if it must go elsewhere."; return 2; }
  api GET "/rest/api/3/issue/$KEY?fields=status" || { api_problem "$KEY"; return; }
  now="$(printf '%s' "$BODY" | jq -r '.fields.status.name')"
  [ "$now" != "$target" ] || { ok "$KEY is already in $target"; return 0; }
  api GET "/rest/api/3/issue/$KEY/transitions" || { api_problem "the moves of $KEY"; return; }
  id="$(printf '%s' "$BODY" | jq -r --arg t "$target" '[.transitions[] | select((.to.name | ascii_downcase) == ($t | ascii_downcase)) | .id][0] // empty')"
  [ -n "$id" ] || { bad "$KEY can't move from $now to $target in Jira's workflow" "Moves it can make now: $(printf '%s' "$BODY" | jq -r '[.transitions[].to.name] | join(", ")'). Move it by hand in Jira."; return 1; }
  body="$(jq -n --arg id "$id" '{transition: {id: $id}}' | json_file)"
  api POST "/rest/api/3/issue/$KEY/transitions" "$body"; local rc=$?
  rm -f "$body"
  [ "$rc" -eq 0 ] || { api_problem "moving $KEY to $target"; return; }
  ok "$KEY moved: $now → $target"
}

do_assign() {
  need_key "${1:-}" || return
  [ -n "$JIRA_ACCOUNT_ID" ] || { bad "Your Jira account ID isn't saved" "Run /flow-configure-user jira-account-id (Codex: \$flow-configure-user jira-account-id), then run this again."; return 1; }
  local body
  body="$(jq -n --arg a "$JIRA_ACCOUNT_ID" '{accountId: $a}' | json_file)"
  api PUT "/rest/api/3/issue/$KEY/assignee" "$body"; local rc=$?
  rm -f "$body"
  [ "$rc" -eq 0 ] || { api_problem "assigning $KEY to you"; return; }
  ok "$KEY is assigned to you"
}

do_sprint() {
  need_key "${1:-}" || return
  local jql active n id name body
  sprint_field || return
  api GET "/rest/api/3/issue/$KEY?fields=$SPRINT_FIELD" || { api_problem "$KEY"; return; }
  name="$(printf '%s' "$BODY" | jq -r --arg sf "$SPRINT_FIELD" '[(.fields[$sf] // [])[] | select(.state == "active") | .name][0] // empty')"
  [ -z "$name" ] || { ok "$KEY is already in the active sprint: $name"; return 0; }
  jql="$(jq -rn --arg q "project = $JIRA_PROJECT_KEY AND sprint in openSprints()" '$q | @uri')"
  api GET "/rest/api/3/search/jql?jql=$jql&fields=$SPRINT_FIELD&maxResults=50" || { api_problem "the open sprints of $JIRA_PROJECT_KEY"; return; }
  active="$(printf '%s' "$BODY" | jq -c --arg sf "$SPRINT_FIELD" '[.issues[].fields[$sf][]? | select(.state == "active")] | unique_by(.id)')"
  n="$(printf '%s' "$active" | jq 'length')"
  [ "$n" -gt 0 ] || { bad "Project $JIRA_PROJECT_KEY has no active sprint with cards in it" "Start the sprint in Jira (or ask the Scrum master), or set the sprint by hand."; return 1; }
  [ "$n" -eq 1 ] || { bad "Project $JIRA_PROJECT_KEY has $n active sprints: $(printf '%s' "$active" | jq -r 'map(.name) | join(", ")')" "Set the right sprint on $KEY by hand in Jira."; return 1; }
  id="$(printf '%s' "$active" | jq -r '.[0].id')"; name="$(printf '%s' "$active" | jq -r '.[0].name')"
  body="$(jq -n --arg sf "$SPRINT_FIELD" --argjson id "$id" '{fields: {($sf): $id}}' | json_file)"
  api PUT "/rest/api/2/issue/$KEY" "$body"; local rc=$?
  rm -f "$body"
  [ "$rc" -eq 0 ] || { api_problem "setting the sprint of $KEY"; return; }
  ok "$KEY is in the active sprint: $name"
}

do_comment() {
  need_key "${1:-}" || return
  need_file "${2:-}" || return
  local body
  body="$(to_wiki "$2" | jq -Rs '{body: .}' | json_file)"
  api POST "/rest/api/2/issue/$KEY/comment" "$body"; local rc=$?
  rm -f "$body"
  [ "$rc" -eq 0 ] || { api_problem "posting a comment on $KEY"; return; }
  ok "Comment posted on $KEY"
  echo "Comment id: $(printf '%s' "$BODY" | jq -r '.id')"
}

do_edit_comment() {
  need_key "${1:-}" || return
  printf '%s' "${2:-}" | grep -q -E '^[0-9]+$' || { bad "'${2:-}' isn't a comment id" "Use the id the comment was posted with (a number)."; return 2; }
  need_file "${3:-}" || return
  local body
  body="$(to_wiki "$3" | jq -Rs '{body: .}' | json_file)"
  api PUT "/rest/api/2/issue/$KEY/comment/$2" "$body"; local rc=$?
  rm -f "$body"
  [ "$rc" -eq 0 ] || { api_problem "comment $2 on $KEY"; return; }
  ok "Comment $2 on $KEY edited"
}

do_create() {
  local type="${1:-}" file="${2:-}" relates="" summary rest body new
  case "$type" in Bug|Story|Task) ;; *) usage; return 2 ;; esac
  need_file "$file" || return
  shift 2
  while [ $# -gt 0 ]; do
    case "$1" in
      --relates) [ $# -ge 2 ] || { usage; return 2; }; need_key "$2" || return; relates="$KEY"; shift 2 ;;
      *) usage; return 2 ;;
    esac
  done
  summary="$(awk 'NF { sub(/^(Title:|#)[ \t]*/, ""); print; exit }' "$file")"
  [ -n "$summary" ] && [ "${#summary}" -le 255 ] || { bad "The card's first line must be its title (\"Title: …\" or \"# …\", at most 255 characters)" "Fix the draft's first line, then run this again."; return 2; }
  rest="$(mktemp)"; awk 'NF && !seen { seen = 1; next } seen' "$file" > "$rest"
  body="$(to_wiki "$rest" | jq -Rs --arg p "$JIRA_PROJECT_KEY" --arg t "$type" --arg s "$summary" '{fields: {project: {key: $p}, issuetype: {name: $t}, summary: $s, description: .}}' | json_file)"
  rm -f "$rest"
  api POST "/rest/api/2/issue" "$body"; local rc=$?
  rm -f "$body"
  [ "$rc" -eq 0 ] || { api_problem "creating a $type in $JIRA_PROJECT_KEY"; return; }
  new="$(printf '%s' "$BODY" | jq -r '.key')"
  ok "$type created: $new · https://$JIRA_SITE/browse/$new"
  echo "New key: $new"
  [ -n "$relates" ] || return 0
  body="$(jq -n --arg a "$new" --arg b "$relates" '{type: {name: "Relates"}, inwardIssue: {key: $a}, outwardIssue: {key: $b}}' | json_file)"
  api POST "/rest/api/3/issueLink" "$body"; rc=$?
  rm -f "$body"
  if [ "$rc" -eq 0 ]; then ok "$new relates to $relates"
  else echo "⚠️ $new was created, but Jira didn't add the link to $relates ($CODE: $(jira_message))"; echo "   Tip: add the \"relates to\" link by hand in Jira; the card's \"Relates to\" line names $relates meanwhile."; fi
  return 0
}

# ---------------------------------------------------------------- main

action="${1:-}"
[ $# -gt 0 ] && shift
case "$action" in
  check) do_check ;;
  me) do_me ;;
  get) do_get "$@" ;;
  status) do_status "$@" ;;
  comments) do_comments "$@" ;;
  transitions) do_transitions "$@" ;;
  move) do_move "$@" ;;
  assign) do_assign "$@" ;;
  sprint) do_sprint "$@" ;;
  comment) do_comment "$@" ;;
  edit-comment) do_edit_comment "$@" ;;
  create) do_create "$@" ;;
  *) usage; exit 2 ;;
esac
