#!/usr/bin/env bash
# Read-only git in a registered repo, without an approval prompt (D90): what the commands and agents read with
# "git -C <repo folder> …" (flow-develop, flow-verify, flow-ac-checker, flow-story-check). Run it from the closio-agent folder:
#
#   bash scripts/repo-git.sh <repo> log | diff | status | show [git arguments…]
#       e.g. bash scripts/repo-git.sh nodejs-ws2closio diff origin/develop...HEAD
#            bash scripts/repo-git.sh nodejs-ws1closio log --oneline -5
#   bash scripts/repo-git.sh <repo> save-diff <CARD-KEY> <base branch>
#       What the card changed in the repo, for the helper agents, which have no shell (D94): everything since the base
#       branch (commits, staged and not staged) and the new files git doesn't track yet, every .env file left out, saved
#       to local/diffs/<CARD-KEY>/<repo>.diff (git-ignored; replaced on every run). The only file it writes, never in a repo.
#
# Only these, which change nothing in the repo. It runs in the repo's folder (local_path in local/repos/<repo>.yaml) with
# --no-pager, and it never shows a .env file (rule A6): an argument that names one is refused, and diff, show and log
# leave every .env file out of what they print. It refuses --output (it would write a file) and --ext-diff (it would
# run another program). Exit codes: 0 fine · 1 ❌ · 2 wrong usage; otherwise git's own. Works in the Mac's own bash 3.2.

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
. "$AGENT_ROOT/scripts/lib/repo-info.sh"

bad() { echo "❌ $1"; echo "   Fix: $2"; }
usage() { echo "Usage: bash scripts/repo-git.sh <repo> log | diff | status | show [git arguments…] · <repo> save-diff <CARD-KEY> <base branch>"; }

[ $# -ge 2 ] || { usage; exit 2; }
repo="$1"; action="$2"; shift 2
case "$action" in log|diff|status|show|save-diff) ;; *) bad "'$action' isn't a read-only git command here" "Use log, diff, status, show or save-diff. Anything that changes a repo goes through the commands' own scripts."; exit 2 ;; esac
repo_ready "$repo" || { bad "$REPO_PROBLEM" "Register or clone it first: /flow-configure-repo (Codex: \$flow-configure-repo)."; exit 1; }
path="$(repo_path "$repo")"

dashes=no
for a in "$@"; do
  case "$a" in
    *.env|*.env.*|*/.env*|.env*|*:.env*) bad "An argument names a .env file ($a)" "Its values are never shown (rule A6). Leave it out."; exit 1 ;;
    --output|--output=*) bad "--output writes a file" "Leave it out: the output is shown here."; exit 1 ;;
    --ext-diff) bad "--ext-diff runs another program" "Leave it out."; exit 1 ;;
    --) dashes=yes ;;
  esac
done

if [ "$action" = save-diff ]; then
  key="${1:-}"; base="${2:-}"
  [ -n "$key" ] && [ -n "$base" ] || { usage; exit 2; }
  case "$key" in *[!A-Za-z0-9-]*) bad "'$key' isn't a card key" "Use the card's key, e.g. SCRUM-519."; exit 2 ;; esac
  mb="$(git -C "$path" merge-base "$base" HEAD 2>/dev/null)" || {
    bad "$repo has no commit in common with '$base'" "Check the base branch (base_branch in config/repos/$repo.yaml) exists in this clone, then run this again."
    exit 1
  }
  out="$AGENT_ROOT/local/diffs/$key/$repo.diff"
  mkdir -p "${out%/*}" || { bad "Couldn't make local/diffs/$key" "Check the closio-agent folder can be written to, then run this again."; exit 1; }
  {
    git -C "$path" --no-pager diff --no-ext-diff "$mb" -- . ':(exclude,glob)**/.env' ':(exclude,glob)**/.env.*'
    git -C "$path" ls-files --others --exclude-standard -z -- . ':(exclude,glob)**/.env' ':(exclude,glob)**/.env.*' |
      while IFS= read -r -d '' f; do git -C "$path" --no-pager diff --no-index --no-ext-diff -- /dev/null "$f"; done
  } > "$out"
  echo "✅ Saved what $key changed in $repo since $base (new files too, no .env file): local/diffs/$key/$repo.diff ($(wc -l < "$out" | tr -d ' ') lines)"
  exit 0
fi

case "$action" in
  status) exec git -C "$path" --no-pager status "$@" ;;
  *)
    # Leave every .env file out of what's printed: a pathspec that excludes them (with "." when no path was given).
    if [ "$dashes" = yes ]; then
      exec git -C "$path" --no-pager "$action" --no-ext-diff "$@" ':(exclude,glob)**/.env' ':(exclude,glob)**/.env.*'
    else
      exec git -C "$path" --no-pager "$action" --no-ext-diff "$@" -- . ':(exclude,glob)**/.env' ':(exclude,glob)**/.env.*'
    fi ;;
esac
