#!/usr/bin/env bash
# Read-only git in a registered repo, without an approval prompt (D90): what the commands and agents read with
# "git -C <repo folder> …" (flow-develop, flow-verify, flow-ac-checker, flow-story-check). Run it from the closio-agent folder:
#
#   bash scripts/repo-git.sh <repo> log | diff | status | show [git arguments…]
#       e.g. bash scripts/repo-git.sh nodejs-ws2closio diff origin/develop...HEAD
#            bash scripts/repo-git.sh nodejs-ws1closio log --oneline -5
#
# Only these four, which change nothing. It runs in the repo's folder (local_path in local/repos/<repo>.yaml) with
# --no-pager, and it never shows a .env file (rule A6): an argument that names one is refused, and diff, show and log
# leave every .env file out of what they print. It refuses --output (it would write a file) and --ext-diff (it would
# run another program). Exit codes: 0 fine · 1 ❌ · 2 wrong usage; otherwise git's own. Works in the Mac's own bash 3.2.

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
. "$AGENT_ROOT/scripts/lib/repo-info.sh"

bad() { echo "❌ $1"; echo "   Fix: $2"; }
usage() { echo "Usage: bash scripts/repo-git.sh <repo> log | diff | status | show [git arguments…]"; }

[ $# -ge 2 ] || { usage; exit 2; }
repo="$1"; action="$2"; shift 2
case "$action" in log|diff|status|show) ;; *) bad "'$action' isn't a read-only git command here" "Use log, diff, status or show. Anything that changes a repo goes through the commands' own scripts."; exit 2 ;; esac
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
