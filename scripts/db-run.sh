#!/usr/bin/env bash
# A card's test data on the database a repo's .env names (C4, flow-verify; rules A6, A23; D21, D67).
# Run it from the closio-agent folder:
#
#   bash scripts/db-run.sh <repo> show <sql file>              Prints the SQL for the user to review, and which database
#                                                             it would run on (described, never a value)
#   bash scripts/db-run.sh <repo> run <sql file> confirmed     Runs it, in one transaction, with the repo's own database
#                                                             config and packages, on the repo's Node version
#   bash scripts/db-run.sh <repo> query <sql file>             Reads only: runs it in a READ ONLY transaction (the database
#                                                             refuses any change) and prints the rows; no yes needed, e.g.
#                                                             to check what a call wrote (flow-verify's quick check, D68)
#
# Only after the user has seen the exact SQL and said yes in chat: test data before the checks, the cleanup after them,
# every time (user, 2026-10-17). Without the word "confirmed" it refuses. The connection values stay in the repo's
# .env; nothing here prints them. Exit codes: 0 fine · 1 ❌ · 2 wrong usage. Works in the Mac's own bash 3.2.

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
. "$AGENT_ROOT/scripts/lib/repo-info.sh"
LOGS_DIR="${LOGS_DIR:-$AGENT_ROOT/local/logs}"

bad() { echo "❌ $1"; echo "   Fix: $2"; }
usage() { echo "Usage: bash scripts/db-run.sh <repo> show <sql file> | <repo> run <sql file> confirmed | <repo> query <sql file>"; }

[ $# -ge 3 ] || { usage; exit 2; }
REPO="$1"; ACTION="$2"; SQL="$3"
repo_ready "$REPO" || { bad "$REPO_PROBLEM" "Fix that first, then run this again."; exit 1; }
[ -f "$SQL" ] || { bad "No SQL file '$SQL'" "Write the card's SQL to a file in the card's folder (e.g. runs/<KEY>/test-data.sql) first."; exit 2; }
SQL="$(cd "$(dirname "$SQL")" && pwd -P)/$(basename "$SQL")"
P="$(repo_path "$REPO")"; NV="$(repo_node "$REPO")"
[ -f "$P/.sequelizerc" ] || { bad "$REPO has no .sequelizerc, so there's no database config to use" "Run this for a repo that owns the tables (a WS2 repo with migrations)."; exit 1; }

case "$ACTION" in
  show)
    [ $# -eq 3 ] || { usage; exit 2; }
    echo "SQL to review ($(basename "$SQL"), $(grep -c '' "$SQL") line(s)):"
    echo '```sql'; cat "$SQL"; echo; echo '```'
    echo "It would run on: the database $REPO's own sequelize-cli config names (its $(env_file_of "$REPO"), NODE_ENV ${NODE_ENV:-development}), in one transaction."
    echo "Nothing runs until the user says yes; then: bash scripts/db-run.sh $REPO run $(printf '%s' "$SQL" | sed "s#^$AGENT_ROOT/##") confirmed" ;;
  run|query)
    if [ "$ACTION" = run ]; then
      [ "${4:-}" = "confirmed" ] && [ $# -eq 4 ] || { bad "Running SQL needs the user's yes first" "Show it with: bash scripts/db-run.sh $REPO show <sql file>, ask the user, and only after their yes add the word confirmed."; exit 1; }
    else
      [ $# -eq 3 ] || { usage; exit 2; }
    fi
    mkdir -p "$LOGS_DIR"
    printf '\n$ db-run %s %s %s   (%s)\n' "$REPO" "$ACTION" "$(basename "$SQL")" "$(date '+%Y-%m-%d %H:%M:%S')" >> "$LOGS_DIR/db-run-$REPO.log"
    out="$(cd "$P" && /bin/bash -c '
      if [ -n "$1" ]; then . "$2" >/dev/null 2>&1 || { echo "❌ nvm could not be loaded"; exit 1; }; nvm use "$1" >/dev/null 2>&1 || { echo "❌ Node $1 is not installed (nvm install $1)"; exit 1; }; fi
      exec node "$3" "$4" "$5"' _ "$NV" "$(nvm_sh)" "$AGENT_ROOT/scripts/lib/db-run.js" "$SQL" "$ACTION" 2>&1)"; rc=$?
    printf '%s\n' "$out" | grep -v -E '^\[dotenv@' | tee -a "$LOGS_DIR/db-run-$REPO.log"
    exit "$rc" ;;
  *) usage; exit 2 ;;
esac
