#!/usr/bin/env bash
# The card's branch in a code repo (C2, Phase 1; rules G1, A12, A14; D50, D53, D61).
# Run it from the closio-agent folder:  bash scripts/card-branch.sh <action>
#
#   check <repo>                     The clone's current branch and uncommitted changes (only reads)
#   create <repo> <branch-name>      Fetches, pulls the repo's base branch (G1) and creates the card's branch from it;
#                                    an existing branch of that name is reused. Needs the VPN (GitLab).
#   update <repo> <branch-name>      Brings the latest base branch into the card's branch (rule A18: plans come from the
#                                    latest code): a fast-forward when the branch has no commits of its own; with its
#                                    own commits it's left alone (the rebase is flow-push's, rule G2). Needs the VPN.
#
# The branch name must follow the strict rule (A12): check it with scripts/branch-name.sh first; this script checks it too.
# Exit codes: 0 fine · 1 ❌ · 2 wrong usage · 3 the clone has uncommitted changes (stop and ask the user).
# Never clones (D53), never reads .env (A6). Works in the Mac's own bash 3.2.

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
REPOS_DIR="${REPOS_DIR:-$AGENT_ROOT/config/repos}"
LOCAL_REPOS_DIR="${LOCAL_REPOS_DIR:-$AGENT_ROOT/local/repos}"

ok() { echo "✅ $1"; }
look() {
  echo "⚠️ $1"
  [ -n "${2:-}" ] && echo "   Tip: $2"
}
bad() {
  echo "❌ $1"
  echo "   Fix: $2"
}
usage() { echo "Usage: bash scripts/card-branch.sh check <repo> | create <repo> <branch-name> | update <repo> <branch-name>"; }

yaml_get() { # <file> <key>
  [ -f "$1" ] || return 0
  grep -m1 -E "^$2:" "$1" | sed -E "s/^$2:[[:space:]]*//; s/[[:space:]]+#.*$//; s/[[:space:]]+$//"
}
clean_url() { printf '%s' "$1" | sed -E 's#://[^/@]*@#://#'; }
gitlab_path_of() { clean_url "$1" | sed -E 's#^[a-z]+://[^/]+/##; s#^[^@]+@[^:]+:##; s#\.git$##'; }

# Finds the repo's clone and base branch; sets PATH_, BASE, REPO. Returns 1 with a ❌ when something's missing.
locate() { # <repo>
  REPO="$1"
  local shared="$REPOS_DIR/$REPO.yaml" local_f="$LOCAL_REPOS_DIR/$REPO.yaml" want have
  printf '%s' "$REPO" | grep -q -E '^[a-z0-9][a-z0-9._-]*$' || { bad "'$REPO' isn't a repo name" "Use the name of a registered repo (see /flow-configure-repo)."; return 1; }
  [ -f "$shared" ] || { bad "$REPO isn't registered" "Register it with /flow-configure-repo <path of your clone> (Codex: \$flow-configure-repo …)."; return 1; }
  PATH_="$(yaml_get "$local_f" local_path)"
  BASE="$(yaml_get "$shared" base_branch)"
  [ -n "$BASE" ] || { bad "config/repos/$REPO.yaml has no base_branch" "Add the line base_branch: <branch> (e.g. develop) and commit it."; return 1; }
  if [ -z "$PATH_" ] || [ "$PATH_" = "not-cloned" ] || [ ! -d "$PATH_/.git" ]; then
    bad "$REPO isn't cloned on this Mac (cloning is manual, D53)" "On the VPN: git clone $(yaml_get "$shared" gitlab_url) <your workspace folder>/$REPO, then run /flow-configure-repo $REPO path <that folder>."
    return 1
  fi
  want="$(yaml_get "$shared" gitlab_path)"
  have="$(gitlab_path_of "$(git -C "$PATH_" remote get-url origin 2>/dev/null)")"
  [ -z "$want" ] || [ "$have" = "$want" ] || { bad "The clone at $PATH_ is a different project ($have, expected $want)" "Point closio-agent at the right clone: /flow-configure-repo $REPO path <folder>."; return 1; }
  return 0
}
g() { git -C "$PATH_" "$@"; }

do_check() { # <repo>
  locate "$1" || return 1
  local cur changed
  cur="$(g rev-parse --abbrev-ref HEAD 2>/dev/null)"
  changed="$(g status --porcelain --untracked-files=no | wc -l | tr -d ' ')"
  ok "$REPO: on branch $cur, base branch $BASE, $changed uncommitted change(s) to tracked files ($PATH_)"
  return 0
}

do_create() { # <repo> <branch-name>
  local name="$2"
  locate "$1" || return 1
  bash "$AGENT_ROOT/scripts/branch-name.sh" check "$name" >/dev/null 2>&1 || { bad "'$name' doesn't follow the branch-naming rule (A12)" "Make one with: bash scripts/branch-name.sh make <CARD-KEY> \"<card title>\"."; return 1; }
  local changed cur
  changed="$(g status --porcelain --untracked-files=no | wc -l | tr -d ' ')"
  if [ "$changed" -gt 0 ]; then
    look "$REPO has $changed uncommitted change(s) to tracked files on $(g rev-parse --abbrev-ref HEAD)" "Stop here and ask the user: commit or stash them (git -C \"$PATH_\" stash), then run this again. The agent never throws changes away."
    return 3
  fi
  if ! g fetch -q origin 2>/dev/null; then
    bad "$REPO: can't reach GitLab to fetch" "Connect the VPN: /flow-vpn connect (Codex: \$flow-vpn connect), then run this again."
    return 1
  fi
  if g show-ref --verify --quiet "refs/heads/$name"; then
    g checkout -q "$name" || { bad "$REPO: couldn't switch to $name" "Check git -C \"$PATH_\" status."; return 1; }
    if g rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then g pull -q --ff-only 2>/dev/null || look "$REPO: $name has an upstream but couldn't fast-forward" "Look at git -C \"$PATH_\" status when you get to pushing."; fi
    look "$REPO: the branch $name already existed; it's checked out and reused (resuming)" "If that's not what you want, delete it first: git -C \"$PATH_\" branch -D $name"
    return 0
  fi
  if g show-ref --verify --quiet "refs/remotes/origin/$name"; then
    g checkout -q -b "$name" --track "origin/$name" || { bad "$REPO: couldn't create $name from origin/$name" "Check git -C \"$PATH_\" status."; return 1; }
    look "$REPO: the branch $name already existed on GitLab; it's checked out and reused (resuming)" "If that's not what you want, pick another name."
    return 0
  fi
  if g show-ref --verify --quiet "refs/heads/$BASE"; then
    g checkout -q "$BASE" || { bad "$REPO: couldn't switch to the base branch $BASE" "Check git -C \"$PATH_\" status."; return 1; }
    g pull -q --ff-only origin "$BASE" || { bad "$REPO: couldn't pull the latest $BASE (not a fast-forward?)" "In the clone: git -C \"$PATH_\" status; fix the base branch by hand, then run this again."; return 1; }
  else
    g checkout -q -b "$BASE" --track "origin/$BASE" || { bad "$REPO: the base branch $BASE isn't on GitLab" "Check base_branch in config/repos/$REPO.yaml."; return 1; }
  fi
  g checkout -q -b "$name" || { bad "$REPO: couldn't create the branch $name" "Check git -C \"$PATH_\" status."; return 1; }
  ok "$REPO: branch $name created from the latest $BASE ($(g rev-parse --short HEAD))"
  return 0
}

do_update() { # <repo> <branch-name>
  local name="$2" changed behind own
  locate "$1" || return 1
  bash "$AGENT_ROOT/scripts/branch-name.sh" check "$name" >/dev/null 2>&1 || { bad "'$name' doesn't follow the branch-naming rule (A12)" "Use the card's branch name from its run folder: bash scripts/run.sh get <CARD-KEY> branch."; return 1; }
  g show-ref --verify --quiet "refs/heads/$name" || { bad "$REPO: there's no branch $name on this Mac" "Create it first: bash scripts/card-branch.sh create $REPO $name"; return 1; }
  changed="$(g status --porcelain --untracked-files=no | wc -l | tr -d ' ')"
  if [ "$changed" -gt 0 ]; then
    look "$REPO has $changed uncommitted change(s) to tracked files on $(g rev-parse --abbrev-ref HEAD)" "Stop here and ask the user: commit or stash them (git -C \"$PATH_\" stash), then run this again. The agent never throws changes away."
    return 3
  fi
  if ! g fetch -q origin 2>/dev/null; then
    bad "$REPO: can't reach GitLab to fetch" "Connect the VPN: /flow-vpn connect (Codex: \$flow-vpn connect), then run this again."
    return 1
  fi
  g show-ref --verify --quiet "refs/remotes/origin/$BASE" || { bad "$REPO: the base branch $BASE isn't on GitLab" "Check base_branch in config/repos/$REPO.yaml."; return 1; }
  if [ "$(g rev-parse --abbrev-ref HEAD)" != "$name" ]; then
    g checkout -q "$name" || { bad "$REPO: couldn't switch to $name" "Check git -C \"$PATH_\" status."; return 1; }
  fi
  [ "$(g rev-parse --abbrev-ref HEAD)" = "$BASE" ] || g fetch -q origin "$BASE:$BASE" 2>/dev/null || true   # the local base branch too, when it's a fast-forward (G1)
  behind="$(g rev-list --count "$name..origin/$BASE")"
  own="$(g rev-list --count "origin/$BASE..$name")"
  if [ "$behind" -eq 0 ]; then
    ok "$REPO: $name is up to date with the latest $BASE ($(g rev-parse --short HEAD))"
  elif [ "$own" -eq 0 ]; then
    g merge -q --ff-only "origin/$BASE" || { bad "$REPO: couldn't move $name forward to the latest $BASE" "Check git -C \"$PATH_\" status, then run this again."; return 1; }
    ok "$REPO: $name moved forward to the latest $BASE: $behind new commit(s) ($(g rev-parse --short HEAD))"
  else
    look "$REPO: $name has $own commit(s) of its own and $BASE has $behind newer one(s); left as it is" "The latest $BASE comes in with the rebase in flow-push (stash, rebase, stash pop; rule G2). Read the newer $BASE code with: git -C \"$PATH_\" diff $name...origin/$BASE"
  fi
  return 0
}

case "${1:-}" in
  check) [ -n "${2:-}" ] || { usage; exit 2; }; do_check "$2" ;;
  create) [ -n "${2:-}" ] && [ -n "${3:-}" ] || { usage; exit 2; }; do_create "$2" "$3" ;;
  update) [ -n "${2:-}" ] && [ -n "${3:-}" ] || { usage; exit 2; }; do_update "$2" "$3" ;;
  -h|--help|help|"") usage; exit 2 ;;
  *) usage; exit 2 ;;
esac
