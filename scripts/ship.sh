#!/usr/bin/env bash
# Commits and pushes a card's work in a code repo (C5 flow-push, flow-review; rules G2, G3, G4, A12, A13; D10, D31, D70, D78).
# Run it from the closio-agent folder:
#
#   bash scripts/ship.sh <repo> status
#       What would ship (only reads): the card's branch, its uncommitted files (changed, new, deleted) and the commits it
#       already has that the MR target branch doesn't.
#   bash scripts/ship.sh <repo> commit "<message>" <file>...
#       Stages exactly these files (new, changed or deleted) and commits them with that message, which reads
#       "SCRUM-<n>: <what this commit does>" with the card's key. The repo's git hooks run (husky's coverage gate in some
#       repos), on the repo's Node version. A failing hook: nothing is committed and the files are unstaged again.
#   bash scripts/ship.sh <repo> push "<MR title>" [--label <label>]...
#       The one push of the card's branch (G4). Its push options create the MR on GitLab and assign it to you (D31):
#       target = mr_target_branch from the repo file, assignee = your GitLab username (local/user-settings.sh).
#       Prints the MR's link. Never forces a push. The pre-push hook runs too.
#   bash scripts/ship.sh <repo> push-update
#       Review fixes only (flow-review, D78: the exception to "one push" and "rebase before every push"): pushes the new
#       commits on top of the branch the MR already has, so they land in the same MR. No push options, no rebase, never
#       forced: the branch on GitLab must be part of this one (else someone else pushed: ❌, nothing is pushed).
#
# Output in local/logs/ship-<repo>.log. Exit codes: 0 fine · 1 ❌ · 2 wrong usage. Never reads .env (A6).
# Works in the Mac's own bash 3.2.

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
. "$AGENT_ROOT/scripts/lib/repo-info.sh"
LOGS_DIR="${LOGS_DIR:-$AGENT_ROOT/local/logs}"

ok() { echo "✅ $1"; }
look() { echo "⚠️ $1"; [ -n "${2:-}" ] && echo "   Tip: $2"; }
bad() { echo "❌ $1"; echo "   Fix: $2"; }
usage() { echo "Usage: bash scripts/ship.sh <repo> status | <repo> commit \"<message>\" <file>... | <repo> push \"<MR title>\" [--label <label>]... | <repo> push-update"; }

# The repo, its clone, its Node version and the card's branch; sets REPO, PATH_, NV, BRANCH, KEY, BASE. 1 with a ❌.
locate() {
  REPO="$1"
  repo_ready "$REPO" || { bad "$REPO_PROBLEM" "Fix that first, then run this again."; return 1; }
  PATH_="$(repo_path "$REPO")"; NV="$(repo_node "$REPO")"
  [ -d "$PATH_/.git" ] || { bad "$PATH_ isn't a git clone" "Point closio-agent at the clone: /flow-configure-repo $REPO path <folder>."; return 1; }
  BASE="$(yaml_get "$(repo_file "$REPO")" base_branch)"
  BRANCH="$(git -C "$PATH_" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [ "$BRANCH" = "$BASE" ] || ! bash "$AGENT_ROOT/scripts/branch-name.sh" check "$BRANCH" >/dev/null 2>&1; then
    bad "$REPO is on '$BRANCH', not on a card's branch" "Switch to the card's branch (bash scripts/run.sh get <CARD-KEY> branch); closio-agent never commits to $BASE."; return 1
  fi
  KEY="${BRANCH%%/*}"
  [ -d "$PATH_/.git/rebase-merge" ] || [ -d "$PATH_/.git/rebase-apply" ] && { bad "$REPO: a rebase is in progress" "Finish it first: bash scripts/card-branch.sh rebase-continue $REPO $BRANCH"; return 1; }
  return 0
}
g() { git -C "$PATH_" "$@"; }
log_file() { mkdir -p "$LOGS_DIR"; echo "$LOGS_DIR/ship-$REPO.log"; }
one_line() { case "$1" in *"
"*) return 1 ;; esac; [ -n "$1" ]; }

mr_target() { local t; t="$(yaml_get "$(repo_file "$REPO")" mr_target_branch)"; [ -n "$t" ] && [ "$t" != "none" ] || t="$BASE"; printf '%s' "$t"; }

do_status() { # <repo>
  local target files ahead
  locate "$1" || return 1
  target="$(mr_target)"
  files="$(g status --porcelain)"
  ok "$REPO: on $BRANCH; MR target $target; $(printf '%s' "$files" | grep -c .) uncommitted file(s) ($PATH_)"
  [ -z "$files" ] || printf '%s\n' "$files" | sed 's/^/   /'
  if g show-ref --verify --quiet "refs/remotes/origin/$target"; then
    ahead="$(g rev-list --count "origin/$target..HEAD")"
    echo "   Commits $target doesn't have yet: $ahead"
    [ "$ahead" -eq 0 ] || g log --format='   %h %s' "origin/$target..HEAD"
  else
    echo "   (origin/$target not fetched yet: the rebase step fetches it)"
  fi
  return 0
}

do_commit() { # <repo> <message> <file>...
  local msg="$2" log msgfile f staged rc; shift 2
  locate "$REPO" || return 1
  one_line "$msg" || { bad "The commit message must be one line" "Write it as \"$KEY: <what this commit does>\"."; return 2; }
  printf '%s' "$msg" | grep -q -E "^$KEY: .{3,}" || { bad "The commit message must start with the card's key: \"$KEY: <what this commit does>\"" "Write it like that, e.g. \"$KEY: add the ageing config model and migration\"."; return 2; }
  [ $# -gt 0 ] || { usage; return 2; }
  staged="$(g diff --cached --name-only)"
  [ -z "$staged" ] || { bad "$REPO already has staged files: $(printf '%s' "$staged" | tr '\n' ' ')" "Ask the user: unstage them (git -C \"$PATH_\" reset) or commit them first, then run this again."; return 1; }
  for f in "$@"; do
    [ -e "$PATH_/$f" ] || g ls-files --error-unmatch -- "$f" >/dev/null 2>&1 || { bad "$REPO has no file $f (and it isn't a deleted tracked file)" "Use paths from the repo's root, as git status shows them."; return 2; }
  done
  g add -A -- "$@" || { bad "$REPO: couldn't stage the files" "Check git -C \"$PATH_\" status."; return 1; }
  [ -n "$(g diff --cached --name-only)" ] || { bad "$REPO: nothing changed in those files" "Check the file list against git -C \"$PATH_\" status."; return 1; }
  log="$(log_file)"; msgfile="$(mktemp)"; printf '%s\n' "$msg" > "$msgfile"
  echo "   $REPO: committing $(g diff --cached --name-only | wc -l | tr -d ' ') file(s); the repo's git hooks run (time limit $REPO_RUN_TIMEOUT s)..."
  run_in_repo "$PATH_" "$NV" "$REPO_RUN_TIMEOUT" "$log" "git commit -q -F $(printf '%q' "$msgfile")"; rc=$?
  rm -f "$msgfile"
  if [ "$rc" -ne 0 ]; then
    g reset -q -- "$@" 2>/dev/null
    [ "$rc" -eq 124 ] && { bad "$REPO: the commit took longer than $REPO_RUN_TIMEOUT s (its hook) and was stopped; nothing is committed" "Read local/logs/ship-$REPO.log, then try again."; return 1; }
    bad "$REPO: the commit failed (a git hook, e.g. the coverage gate); nothing is committed, the files are unstaged again" "Read the end below (full: local/logs/ship-$REPO.log); fix the code or tests (/flow-develop $KEY), then run this again."
    result_lines "$log"; last_output "$log" | tail -10 | sed 's/^/        /'
    return 1
  fi
  ok "$REPO: $(g log -1 --format='%h %s') ($(g show --stat --format= HEAD | tail -1 | sed 's/^ *//'))"
  return 0
}

push_failed() { # <exit code> <log>: the ❌ for a failed push (push, push-update)
  [ "$1" -eq 124 ] && { bad "$REPO: the push took longer than $REPO_RUN_TIMEOUT s and was stopped" "Read local/logs/ship-$REPO.log; check on GitLab whether the branch arrived, then run this again."; return; }
  if last_output "$2" | grep -q -E 'rejected|non-fast-forward|fetch first'; then
    bad "$REPO: GitLab refused the push: the branch there has commits this Mac doesn't have" "Ask the user: someone else pushed to $BRANCH. Look with git -C \"$PATH_\" log HEAD..origin/$BRANCH; closio-agent never forces a push."
  else
    bad "$REPO: the push failed (the pre-push hook, the VPN or GitLab)" "Read the end below (full: local/logs/ship-$REPO.log), fix it, then run this again."
  fi
  result_lines "$2"; last_output "$2" | tail -10 | sed 's/^/        /'
}

do_push() { # <repo> <title> [--label <label>]...
  local title="$2" target user labels="" opts log rc untracked ahead url; shift 2
  locate "$REPO" || return 1
  while [ $# -gt 0 ]; do
    case "$1" in
      --label) [ $# -ge 2 ] && one_line "$2" || { usage; return 2; }; labels="$labels$(printf ' -o %q' "merge_request.label=$2")"; shift 2 ;;
      *) usage; return 2 ;;
    esac
  done
  one_line "$title" || { bad "The MR title must be one line" "Write it as \"$KEY: <card title>\"."; return 2; }
  printf '%s' "$title" | grep -q -E "^$KEY: .{3,}" || { bad "The MR title must read \"$KEY: <card title>\"" "Write it like that."; return 2; }
  target="$(mr_target)"
  user="$(gitlab_username)"
  [ -n "$user" ] || { bad "Your GitLab username isn't set" "Run /flow-configure-user gitlab-username (Codex: \$flow-configure-user gitlab-username), then run this again."; return 1; }
  [ -z "$(g status --porcelain --untracked-files=no)" ] || { bad "$REPO has uncommitted changes to tracked files" "Commit them first (bash scripts/ship.sh $REPO commit …), or ask the user what they are."; return 1; }
  untracked="$(g status --porcelain | grep '^??' | sed 's/^?? //')"
  [ -z "$untracked" ] || look "$REPO has files git doesn't track; they won't be pushed: $(printf '%s' "$untracked" | tr '\n' ' ')" "If one belongs to the card, commit it first."
  if ! g fetch -q origin 2>/dev/null; then bad "$REPO: can't reach GitLab" "Connect the VPN: /flow-vpn connect (Codex: \$flow-vpn connect), then run this again."; return 1; fi
  g show-ref --verify --quiet "refs/remotes/origin/$target" || { bad "$REPO: the MR target branch $target isn't on GitLab" "Check mr_target_branch in config/repos/$REPO.yaml."; return 1; }
  ahead="$(g rev-list --count "origin/$target..HEAD")"
  [ "$ahead" -gt 0 ] || { bad "$REPO: $BRANCH has no commits that $target doesn't have" "Commit the card's work first (bash scripts/ship.sh $REPO commit …)."; return 1; }
  opts="-o merge_request.create$(printf ' -o %q -o %q -o %q' "merge_request.target=$target" "merge_request.title=$title" "merge_request.assign=$user")$labels"
  log="$(log_file)"
  echo "   $REPO: pushing $BRANCH ($ahead commit(s)) and creating the MR into $target, assigned to $user; the pre-push hook runs (time limit $REPO_RUN_TIMEOUT s)..."
  run_in_repo "$PATH_" "$NV" "$REPO_RUN_TIMEOUT" "$log" "git push -u origin $(printf '%q' "HEAD:refs/heads/$BRANCH") $opts"; rc=$?
  [ "$rc" -eq 0 ] || { push_failed "$rc" "$log"; return 1; }
  url="$(last_output "$log" | grep -o -E 'https://[^ ]*/-/merge_requests/[0-9]+' | tail -1)"
  ok "$REPO: $BRANCH pushed ($ahead commit(s), $(g rev-parse --short HEAD))"
  if [ -n "$url" ]; then echo "   MR: $url"; else look "$REPO: GitLab printed no MR link" "Check it: bash scripts/gitlab-mr.sh $REPO find $BRANCH"; fi
  return 0
}

do_push_update() { # <repo>: review fixes into the same MR (D78)
  local log rc ahead untracked
  locate "$REPO" || return 1
  [ -z "$(g status --porcelain --untracked-files=no)" ] || { bad "$REPO has uncommitted changes to tracked files" "Commit the fix first (bash scripts/ship.sh $REPO commit …), or ask the user what they are."; return 1; }
  untracked="$(g status --porcelain | grep '^??' | sed 's/^?? //')"
  [ -z "$untracked" ] || look "$REPO has files git doesn't track; they won't be pushed: $(printf '%s' "$untracked" | tr '\n' ' ')" "If one belongs to the fix, commit it first."
  if ! g fetch -q origin 2>/dev/null; then bad "$REPO: can't reach GitLab" "Connect the VPN: /flow-vpn connect (Codex: \$flow-vpn connect), then run this again."; return 1; fi
  g show-ref --verify --quiet "refs/remotes/origin/$BRANCH" || { bad "$REPO: $BRANCH isn't on GitLab yet" "This is for review fixes on a pushed MR; the first push is /flow-push."; return 1; }
  g merge-base --is-ancestor "origin/$BRANCH" HEAD || { bad "$REPO: the branch on GitLab has commits this Mac doesn't have (or history that differs)" "Ask the user: someone else pushed to $BRANCH. Look with git -C \"$PATH_\" log HEAD..origin/$BRANCH; closio-agent never forces a push or rebases during review."; return 1; }
  ahead="$(g rev-list --count "origin/$BRANCH..HEAD")"
  [ "$ahead" -gt 0 ] || { bad "$REPO: nothing new to push to the MR" "Commit the review fix first (bash scripts/ship.sh $REPO commit …)."; return 1; }
  log="$(log_file)"
  echo "   $REPO: pushing $ahead review-fix commit(s) to $BRANCH, into its open MR; the pre-push hook runs (time limit $REPO_RUN_TIMEOUT s)..."
  run_in_repo "$PATH_" "$NV" "$REPO_RUN_TIMEOUT" "$log" "git push origin $(printf '%q' "HEAD:refs/heads/$BRANCH")"; rc=$?
  [ "$rc" -eq 0 ] || { push_failed "$rc" "$log"; return 1; }
  ok "$REPO: $ahead commit(s) pushed to $BRANCH ($(g rev-parse --short HEAD)); the MR shows them"
  return 0
}

[ $# -ge 2 ] || { usage; exit 2; }
REPO="$1"
case "$2" in
  status) [ $# -eq 2 ] || { usage; exit 2; }; do_status "$REPO" ;;
  commit) [ $# -ge 4 ] || { usage; exit 2; }; shift 2; do_commit "$REPO" "$@" ;;
  push) [ $# -ge 3 ] || { usage; exit 2; }; shift 2; do_push "$REPO" "$@" ;;
  push-update) [ $# -eq 2 ] || { usage; exit 2; }; do_push_update "$REPO" ;;
  *) usage; exit 2 ;;
esac
