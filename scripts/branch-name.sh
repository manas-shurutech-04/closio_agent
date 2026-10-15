#!/usr/bin/env bash
# Makes and checks branch names (D50, rule A12). The rule is strict, for every repo:
#   SCRUM-<number>/<short-description>        e.g. SCRUM-519/add-filter-status
#   - the card key exactly as in Jira (project key from config/project-settings.sh)
#   - the description: lowercase words joined by "-", only a-z and 0-9,
#     at most BRANCH_DESC_MAX_WORDS words (5)
#   - the same branch name in every repo the card touches
#
# Usage (from the closio-agent folder):
#   bash scripts/branch-name.sh make SCRUM-519 "Add filter by status to the orders list"
#   bash scripts/branch-name.sh check SCRUM-519/add-filter-status

set -u
AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"

RULE="$JIRA_PROJECT_KEY-<number>/<short-description>: lowercase words joined by '-', only a-z and 0-9, at most $BRANCH_DESC_MAX_WORDS words"

check_name() {
  local name="$1" key desc words
  key="${name%%/*}"
  desc="${name#*/}"
  if [ "$key" = "$name" ] || ! printf '%s' "$key" | grep -q -E "^$JIRA_PROJECT_KEY-[0-9]+\$"; then
    echo "❌ '$name' doesn't start with the card key and a '/' (e.g. $JIRA_PROJECT_KEY-519/add-filter-status)"
    echo "   Fix: use the rule: $RULE"
    return 1
  fi
  if ! printf '%s' "$desc" | grep -q -E '^[a-z0-9]+(-[a-z0-9]+)*$'; then
    echo "❌ The description '$desc' must be lowercase words joined by '-' (only a-z and 0-9)"
    echo "   Fix: e.g. bash scripts/branch-name.sh make $key \"<card title>\""
    return 1
  fi
  words="$(printf '%s' "$desc" | tr '-' '\n' | grep -c .)"
  if [ "$words" -gt "$BRANCH_DESC_MAX_WORDS" ]; then
    echo "❌ The description has $words words; at most $BRANCH_DESC_MAX_WORDS are allowed"
    echo "   Fix: shorten it to the $BRANCH_DESC_MAX_WORDS most telling words."
    return 1
  fi
  echo "✅ $name follows the branch-naming rule"
  return 0
}

make_name() {
  local key="$1" title="$2" desc
  if ! printf '%s' "$key" | grep -q -E "^$JIRA_PROJECT_KEY-[0-9]+\$"; then
    echo "❌ '$key' isn't a card key like $JIRA_PROJECT_KEY-519"
    echo "   Fix: use the card key exactly as in Jira."
    return 1
  fi
  # lowercase, anything that isn't a-z or 0-9 becomes a space, drop filler words, keep the first N words
  desc="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/ /g' |
    awk -v max="$BRANCH_DESC_MAX_WORDS" '
      BEGIN { split("a an the to of for in on by and or with from at is are be as into", f, " "); for (i in f) filler[f[i]] = 1 }
      { out=""; n=0; for (i=1; i<=NF && n<max; i++) { if ($i in filler) continue; out = (n ? out "-" : "") $i; n++ } print out }')"
  if [ -z "$desc" ]; then
    echo "❌ The title has no letters or numbers to build a description from"
    echo "   Fix: give a short description in plain words."
    return 1
  fi
  echo "$key/$desc"
}

case "${1:-}" in
  make) [ $# -ge 3 ] || { echo "Usage: bash scripts/branch-name.sh make <CARD-KEY> \"<title>\""; exit 1; }; make_name "$2" "$3" ;;
  check) [ $# -eq 2 ] || { echo "Usage: bash scripts/branch-name.sh check <branch-name>"; exit 1; }; check_name "$2" ;;
  *) echo "Usage: bash scripts/branch-name.sh make <CARD-KEY> \"<title>\" | check <branch-name>"; exit 1 ;;
esac
