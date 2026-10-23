#!/usr/bin/env bash
# A card's merge request through the GitLab REST API (C5 flow-push, C6 flow-finish, flow-review; D32, D48, D51, D70, D78).
# Run it from the closio-agent folder:
#
#   bash scripts/gitlab-mr.sh <repo> find <branch>
#       The open MR of that branch: its number, title and link.
#   bash scripts/gitlab-mr.sh <repo> status <branch>
#       The branch's latest MR, open or not: merged (with its merge commit), still open, or closed (C6, flow-finish).
#       Exit code 0 when it's merged, 3 when it isn't.
#   bash scripts/gitlab-mr.sh <repo> describe <branch> <description file> [--reviewers <username,username>]
#       Sets the MR's full description (multi-line; push options can't carry one, D31) and its reviewers (push options
#       can't set reviewers; each username is looked up on GitLab).
#   bash scripts/gitlab-mr.sh <repo> comments <branch> [--since <note id>]
#       The open MR's review state (who approved, merge conflicts, unresolved threads) and its threads: every unresolved
#       one, and any with a note newer than <note id> (marked "new"); each with its file and line, who wrote what, and
#       when (UTC). Ends with the newest note id, to pass as --since next time (flow-review). Only reads.
#   bash scripts/gitlab-mr.sh <repo> reply <branch> <thread id> <reply file>
#       Posts the reply in that file (multi-line) as a note in that thread of the open MR, as you (your token). Never
#       resolves a thread: the reviewer does (flow-review, D78).
#   bash scripts/gitlab-mr.sh <repo> pipeline <branch>
#       The open MR's latest pipeline: passed, still running, or failed with its failed jobs. Only reads.
#
# Your GitLab token (closio-agent.gitlab-token, scope api) is read from the macOS Keychain here and handed to curl on
# stdin: it's never printed, written to a file or put on a command line (rule A6, D32). Needs the VPN.
# Exit codes: 0 fine · 1 ❌ · 2 wrong usage · 3 the MR isn't merged (status) or its pipeline failed (pipeline). Works in the Mac's own bash 3.2; needs curl and jq.

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
. "$AGENT_ROOT/scripts/lib/repo-info.sh"
API="${GITLAB_API_URL:-https://$GITLAB_HOST/api/v4}"

ok() { echo "✅ $1"; }
bad() { echo "❌ $1"; echo "   Fix: $2"; }
usage() {
  echo "Usage: bash scripts/gitlab-mr.sh <repo> find <branch> | <repo> status <branch> | <repo> describe <branch> <description file> [--reviewers <username,username>]"
  echo "       | <repo> comments <branch> [--since <note id>] | <repo> reply <branch> <thread id> <reply file> | <repo> pipeline <branch>"
}
# SECURITY_BIN can be a stand-in for the build tests only (like e2e.sh); normally the macOS "security" tool.
token() { "${SECURITY_BIN:-security}" find-generic-password -a "$USER" -s "$KEYCHAIN_PREFIX.gitlab-token" -w 2>/dev/null; }

# One API call: api <METHOD> <path> [<json body file>]; sets CODE and BODY. The token goes to curl on stdin (-H @-).
api() {
  local method="$1" path="$2" data="${3:-}" out tok
  tok="$(token)"
  [ -n "$tok" ] || { CODE="no-token"; BODY=""; return 1; }
  if [ -n "$data" ]; then
    out="$(printf 'PRIVATE-TOKEN: %s\n' "$tok" | curl -sS --max-time "$GITLAB_API_TIMEOUT" -X "$method" -H @- -H 'Content-Type: application/json' --data-binary @"$data" -w '\n%{http_code}' "$API$path" 2>/dev/null)"
  else
    out="$(printf 'PRIVATE-TOKEN: %s\n' "$tok" | curl -sS --max-time "$GITLAB_API_TIMEOUT" -X "$method" -H @- -w '\n%{http_code}' "$API$path" 2>/dev/null)"
  fi
  tok=""
  CODE="$(printf '%s' "$out" | tail -1)"; BODY="$(printf '%s' "$out" | sed '$d')"
  case "$CODE" in 2??) return 0 ;; *) return 1 ;; esac
}
api_problem() { # <what was asked>: the ❌ line for a failed call
  case "$CODE" in
    no-token) bad "Your GitLab token isn't in the Keychain" "Run /flow-configure-user gitlab-token (Codex: \$flow-configure-user gitlab-token), then run this again." ;;
    000|"") bad "GitLab didn't answer ($1)" "Connect the VPN: /flow-vpn connect (Codex: \$flow-vpn connect), then run this again." ;;
    401) bad "GitLab refused your token ($1: 401)" "It may have expired: make a new personal access token (scope api) on GitLab, then /flow-configure-user gitlab-token." ;;
    403) bad "Your token may not do this ($1: 403)" "Check that the token has the api scope and that you're a member of the project." ;;
    404) bad "GitLab found nothing for $1 (404)" "Check gitlab_path in config/repos/$REPO.yaml and the branch name." ;;
    *) bad "GitLab answered $CODE ($1): $(printf '%s' "$BODY" | jq -r '.message // .error // empty' 2>/dev/null | head -c 200)" "Read the message; fix it, then run this again." ;;
  esac
}

project() { jq -rn --arg p "$(yaml_get "$(repo_file "$REPO")" gitlab_path)" '$p | @uri'; }

find_mr() { # <branch>: sets IID, WEB_URL, TITLE
  local q; q="$(jq -rn --arg b "$1" '$b | @uri')"
  api GET "/projects/$(project)/merge_requests?state=opened&source_branch=$q" || { api_problem "the open MR of $1"; return 1; }
  IID="$(printf '%s' "$BODY" | jq -r '.[0].iid // empty')"; WEB_URL="$(printf '%s' "$BODY" | jq -r '.[0].web_url // empty')"; TITLE="$(printf '%s' "$BODY" | jq -r '.[0].title // empty')"
  [ -n "$IID" ] || { bad "$REPO: no open MR for the branch $1" "Push it first (bash scripts/ship.sh $REPO push \"<title>\"), or check the branch name."; return 1; }
  return 0
}

do_find() { find_mr "$1" || return 1; ok "$REPO: MR !$IID · $TITLE · $WEB_URL"; }

do_status() { # <branch>: merged (0), open or closed (3)
  local q st sha at
  q="$(jq -rn --arg b "$1" '$b | @uri')"
  api GET "/projects/$(project)/merge_requests?state=all&source_branch=$q&order_by=created_at&sort=desc" || { api_problem "the MRs of $1"; return 1; }
  IID="$(printf '%s' "$BODY" | jq -r '.[0].iid // empty')"
  [ -n "$IID" ] || { bad "$REPO: no MR for the branch $1" "Was it pushed with /flow-push? Check the branch name (bash scripts/run.sh get <CARD-KEY> branch)."; return 1; }
  st="$(printf '%s' "$BODY" | jq -r '.[0].state')"; WEB_URL="$(printf '%s' "$BODY" | jq -r '.[0].web_url // empty')"
  sha="$(printf '%s' "$BODY" | jq -r '.[0].merge_commit_sha // .[0].squash_commit_sha // empty' | cut -c1-8)"; at="$(printf '%s' "$BODY" | jq -r '.[0].merged_at // empty' | cut -c1-16 | tr 'T' ' ')"
  case "$st" in
    merged) ok "$REPO: MR !$IID is merged${sha:+ (merge commit $sha)}${at:+, $at UTC} · $WEB_URL"; return 0 ;;
    opened|locked) echo "⚠️ $REPO: MR !$IID isn't merged yet (still open) · $WEB_URL"; echo "   Tip: run /flow-finish again once it's merged."; return 3 ;;
    closed) echo "⚠️ $REPO: MR !$IID was closed without merging · $WEB_URL"; echo "   Tip: ask the user how to go on (reopen it, or push again with /flow-push)."; return 3 ;;
    *) bad "$REPO: MR !$IID has an unknown state '$st'" "Look at it on GitLab: $WEB_URL"; return 1 ;;
  esac
}

do_describe() { # <branch> <file> [--reviewers a,b]
  local branch="$1" file="$2" reviewers="" ids="[]" u id body names=""
  shift 2
  while [ $# -gt 0 ]; do
    case "$1" in
      --reviewers) [ $# -ge 2 ] || { usage; return 2; }; reviewers="$2"; shift 2 ;;
      *) usage; return 2 ;;
    esac
  done
  [ -s "$file" ] || { bad "No description file '$file' (or it's empty)" "Write the MR description to a file first (flow-push keeps it in the card's folder)."; return 2; }
  [ -z "$reviewers" ] || printf '%s' "$reviewers" | grep -q -E '^[A-Za-z0-9._-]+(,[A-Za-z0-9._-]+)*$' || { bad "Reviewers must be GitLab usernames, comma between them" "e.g. --reviewers ana.s,budi"; return 2; }
  find_mr "$branch" || return 1
  if [ -n "$reviewers" ]; then
    for u in $(printf '%s' "$reviewers" | tr ',' ' '); do
      api GET "/users?username=$(jq -rn --arg u "$u" '$u | @uri')" || { api_problem "the GitLab user $u"; return 1; }
      id="$(printf '%s' "$BODY" | jq -r '.[0].id // empty')"
      [ -n "$id" ] || { bad "There's no GitLab user named $u" "Check the username (as in their GitLab profile, without @), then run this again."; return 1; }
      ids="$(printf '%s' "$ids" | jq -c --argjson i "$id" '. + [$i]')"; names="$names${names:+, }$u"
    done
  fi
  body="$(mktemp)"; chmod 600 "$body"
  if [ -n "$reviewers" ]; then jq -n --rawfile d "$file" --argjson r "$ids" '{description: $d, reviewer_ids: $r}' > "$body"
  else jq -n --rawfile d "$file" '{description: $d}' > "$body"; fi
  api PUT "/projects/$(project)/merge_requests/$IID" "$body"; local rc=$?
  rm -f "$body"
  [ "$rc" -eq 0 ] || { api_problem "setting MR !$IID's description"; return 1; }
  ok "$REPO: MR !$IID description set ($(grep -c '' "$file") line(s))${names:+; reviewers: $names} · $WEB_URL"
}

do_comments() { # <branch> [--since <note id>]
  local branch="$1" since=0 page=1 n me tmp approved conflicts
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --since) [ $# -ge 2 ] && printf '%s' "$2" | grep -q -E '^[0-9]+$' || { usage; return 2; }; since="$2"; shift 2 ;;
      *) usage; return 2 ;;
    esac
  done
  find_mr "$branch" || return 1
  me="$(gitlab_username)"
  tmp="$(mktemp -d)" || { bad "Couldn't make a temporary folder" "Check the disk, then run this again."; return 1; }
  api GET "/projects/$(project)/merge_requests/$IID" || { api_problem "MR !$IID"; rm -rf "$tmp"; return 1; }
  conflicts="$(printf '%s' "$BODY" | jq -r 'if .has_conflicts then "yes" else "none" end')"
  if api GET "/projects/$(project)/merge_requests/$IID/approvals"; then
    approved="$(printf '%s' "$BODY" | jq -r '[.approved_by[]?.user.username] | if length == 0 then "nobody yet" else join(", ") end')"
  else approved="couldn't read ($CODE)"; fi
  while :; do   # the threads, 100 a page (at most 20 pages)
    api GET "/projects/$(project)/merge_requests/$IID/discussions?per_page=100&page=$page" || { api_problem "the threads of MR !$IID"; rm -rf "$tmp"; return 1; }
    printf '%s' "$BODY" > "$tmp/page-$page.json"; n="$(printf '%s' "$BODY" | jq 'if type == "array" then length else empty end' 2>/dev/null)"
    if [ -z "$n" ]; then   # not a list (e.g. a proxy's HTML error page): one ❌, no more pages (D92)
      bad "GitLab's answer for the threads of MR !$IID isn't a list (page $page)" "Check GitLab is reachable and the token is valid, then run this again."
      rm -rf "$tmp"; return 1
    fi
    [ "$n" -lt 100 ] || [ "$page" -ge 20 ] && break
    page=$((page + 1))
  done
  jq -s -r --argjson since "$since" --arg me "$me" --arg head "MR !$IID · $TITLE · approved by: $approved · conflicts: $conflicts" --arg url "$WEB_URL" '
    add // []
    | map({id, notes: [.notes[] | select(.system | not)]} | select(.notes | length > 0))
    | map(. + {unresolved: ([.notes[] | select(.resolvable and (.resolved | not))] | length > 0),
               resolvable: ([.notes[] | select(.resolvable)] | length > 0),
               new: ([.notes[] | select(.id > $since)] | length > 0)}) as $all
    | ($all | map(select(.unresolved)) | length) as $open
    | ([$all[].notes[].id] | max // $since) as $last
    | ($all | map(select(.unresolved or .new))) as $shown
    | "\($head) · unresolved threads: \($open) · \($url)",
      ($shown[] | . as $t | .notes[0] as $f
        | "--- Thread \($t.id) · \(if $f.position then "\($f.position.new_path // $f.position.old_path):\($f.position.new_line // $f.position.old_line)" else "general" end) · \(if $t.unresolved then "unresolved" elif $t.resolvable then "resolved" else "comment" end)",
          ($t.notes[] | "  [\(.id) · \(.author.username)\(if .author.username == $me then " (you)" else "" end) · \(.created_at[0:16] | sub("T"; " ")) UTC]\(if .id > $since then " (new)" else "" end)",
                        (.body | split("\n") | map("      " + .) | join("\n")))),
      "\($shown | length) thread(s) shown (unresolved, or new since note \($since)). Newest note id: \($last)"
  ' "$tmp"/page-*.json; n=$?
  rm -rf "$tmp"
  [ "$n" -eq 0 ] || { bad "Couldn't read the threads GitLab sent" "Run it again; if it keeps failing, look at the MR on GitLab: $WEB_URL"; return 1; }
  return 0
}

do_reply() { # <branch> <thread id> <reply file>
  local branch="$1" did="$2" file="$3" body rc nid
  printf '%s' "$did" | grep -q -E '^[0-9a-f]{8,64}$' || { bad "'$did' isn't a thread id" "Use the id after \"Thread\" in: bash scripts/gitlab-mr.sh $REPO comments $branch"; return 2; }
  [ -s "$file" ] || { bad "No reply file '$file' (or it's empty)" "Write the reply the user approved to a file first (flow-review keeps it in the card's folder)."; return 2; }
  find_mr "$branch" || return 1
  body="$(mktemp)"; chmod 600 "$body"
  jq -n --rawfile b "$file" '{body: $b}' > "$body"
  api POST "/projects/$(project)/merge_requests/$IID/discussions/$did/notes" "$body"; rc=$?
  rm -f "$body"
  [ "$rc" -eq 0 ] || { api_problem "the reply in thread $did of MR !$IID"; return 1; }
  nid="$(printf '%s' "$BODY" | jq -r '.id // empty')"
  ok "$REPO: reply posted in MR !$IID, thread $did (note $nid); the thread stays open for the reviewer · $WEB_URL"
}

do_pipeline() { # <branch>
  local pid st url
  find_mr "$1" || return 1
  api GET "/projects/$(project)/merge_requests/$IID" || { api_problem "MR !$IID"; return 1; }
  pid="$(printf '%s' "$BODY" | jq -r '.head_pipeline.id // empty')"; st="$(printf '%s' "$BODY" | jq -r '.head_pipeline.status // empty')"; url="$(printf '%s' "$BODY" | jq -r '.head_pipeline.web_url // empty')"
  [ -n "$pid" ] || { echo "⚠️ $REPO: MR !$IID has no pipeline"; echo "   Tip: this repo may not run CI on its MRs; nothing to wait for."; return 0; }
  case "$st" in
    success) ok "$REPO: MR !$IID's pipeline passed · $url" ;;
    failed)
      echo "❌ $REPO: MR !$IID's pipeline failed · $url"
      if api GET "/projects/$(project)/pipelines/$pid/jobs?scope%5B%5D=failed&per_page=100"; then
        printf '%s' "$BODY" | jq -r '.[] | "   failed job: \(.name) (stage \(.stage)) · \(.web_url)"'
      fi
      echo "   Fix: open the failed job's log; /flow-review treats it like a finding (a fix, its tests, your yes, then a push)."
      return 3 ;;
    running|pending|created|preparing|waiting_for_resource|scheduled) echo "⚠️ $REPO: MR !$IID's pipeline is still $st · $url"; echo "   Tip: look again later: /flow-review <CARD-KEY> check" ;;
    *) echo "⚠️ $REPO: MR !$IID's pipeline is $st · $url"; echo "   Tip: look at it on GitLab." ;;
  esac
  return 0
}

[ $# -ge 3 ] || { usage; exit 2; }
REPO="$1"
repo_ready "$REPO" || { bad "$REPO_PROBLEM" "Fix that first, then run this again."; exit 1; }
[ -n "$(yaml_get "$(repo_file "$REPO")" gitlab_path)" ] || { bad "config/repos/$REPO.yaml has no gitlab_path" "Add it with /flow-configure-repo $REPO."; exit 1; }
case "$2" in
  find) [ $# -eq 3 ] || { usage; exit 2; }; do_find "$3" ;;
  status) [ $# -eq 3 ] || { usage; exit 2; }; do_status "$3" ;;
  describe) [ $# -ge 4 ] || { usage; exit 2; }; shift 2; do_describe "$@" ;;
  comments) shift 2; do_comments "$@" ;;
  reply) [ $# -eq 5 ] || { usage; exit 2; }; do_reply "$3" "$4" "$5" ;;
  pipeline) [ $# -eq 3 ] || { usage; exit 2; }; do_pipeline "$3" ;;
  *) usage; exit 2 ;;
esac
