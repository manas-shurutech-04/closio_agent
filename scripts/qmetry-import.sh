#!/usr/bin/env bash
# Saves a QMetry test-case export (.xlsx) of a card as markdown in its run folder; QMetry is optional, and when a card has
# an export its cases are the base for the card's test cases (C4, flow-verify and flow-ac-check; D67). Run it from the
# closio-agent folder:
#   bash scripts/qmetry-import.sh <CARD-KEY> <export.xlsx>     → runs/<CARD-KEY>/qmetry/<file name>.md
#   bash scripts/qmetry-import.sh coverage <CARD-KEY>          → how many of the QMetry cases the card's test cases cover
# Only reads the export. The QMetry test cases themselves can't be read through the Jira tools (they live inside QMetry).
set -u
AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
RUNS_DIR="${RUNS_DIR:-$AGENT_ROOT/runs}"
USAGE="Usage: bash scripts/qmetry-import.sh <CARD-KEY> <export.xlsx>   or   bash scripts/qmetry-import.sh coverage <CARD-KEY>"

# coverage: a QMetry case is covered when its key (the export's first column, e.g. SCRUM-TC-419) is in the name of one
# of the card's test cases (runs/<KEY>/api-checks/*.json, runs/<KEY>/e2e/*.spec.ts); flow-ac-checker writes it there.
if [ "${1:-}" = coverage ]; then
  KEY="${2:-}"
  printf '%s' "$KEY" | grep -q -E "^$JIRA_PROJECT_KEY-[0-9]+$" || { echo "$USAGE"; exit 2; }
  QDIR="$RUNS_DIR/$KEY/qmetry"
  ls "$QDIR"/*.md >/dev/null 2>&1 || { echo "No QMetry export saved for $KEY: nothing to count."; exit 0; }
  # In each export the first row with a value in its first column is the header; the next ones are the cases.
  keys=$(awk '/^\| [^ |]/ { n[FILENAME]++; if (n[FILENAME] == 1) next; split($0, c, "|"); k = c[2]; gsub(/^ +| +$/, "", k); if (k != "") print k }' "$QDIR"/*.md | sort -u)
  total=$(printf '%s\n' "$keys" | grep -c .)
  [ "$total" -gt 0 ] || { echo "⚠️ No QMetry test cases found in runs/$KEY/qmetry/"; echo "   Tip: import the export again: bash scripts/qmetry-import.sh $KEY <export.xlsx>"; exit 0; }
  tests=$(cat "$RUNS_DIR/$KEY"/api-checks/*.json "$RUNS_DIR/$KEY"/e2e/*.spec.ts 2>/dev/null)
  covered=0
  while IFS= read -r k; do
    pat=$(printf '%s' "$k" | sed 's/[][\.*^$+?(){}|/]/\\&/g')
    printf '%s\n' "$tests" | grep -q -E "(^|[^A-Za-z0-9-])$pat([^0-9]|$)" && covered=$((covered + 1))
  done <<EOF
$keys
EOF
  echo "QMetry: $covered of $total test cases covered ($(awk -v c="$covered" -v t="$total" 'BEGIN { printf "%.0f", c * 100 / t }')%)"
  exit 0
fi

KEY="${1:-}"; FILE="${2:-}"
printf '%s' "$KEY" | grep -q -E "^$JIRA_PROJECT_KEY-[0-9]+$" && [ -n "$FILE" ] || { echo "$USAGE"; exit 2; }
[ -f "$FILE" ] || { echo "❌ No file '$FILE'"; echo "   Fix: give the full path of the QMetry export (.xlsx)."; exit 1; }
[ -d "$RUNS_DIR/$KEY" ] || { echo "❌ No run folder runs/$KEY on this Mac"; echo "   Fix: bash scripts/run.sh branch $KEY (it brings the card's run folder here), then run this again."; exit 1; }
mkdir -p "$RUNS_DIR/$KEY/qmetry"
out="$RUNS_DIR/$KEY/qmetry/$(basename "$FILE" .xlsx).md"
{ echo "# QMetry test cases of $KEY"; echo; echo "Imported from $(basename "$FILE") on $(date '+%Y-%m-%d'); the base for the card's test cases."; echo; python3 -I "$AGENT_ROOT/scripts/lib/xlsx-to-md.py" "$FILE"; } > "$out.tmp" || { rm -f "$out.tmp"; echo "❌ Couldn't read '$FILE' as an Excel export"; echo "   Fix: export the test cases from QMetry again as .xlsx, then run this again."; exit 1; }
mv "$out.tmp" "$out"
# A case starts a row with its key in the first column; the rows under it with an empty first column are its steps.
cases=$(($(grep -c -E '^\| [^ |]' "$out") - 1)); steps=$(($(grep -c '^| ' "$out") - 1 - cases))
echo "✅ $cases QMetry test case(s) ($steps more row(s) of their steps) saved to runs/$KEY/qmetry/$(basename "$out")"
# The export names the stories its cases are linked to; one for another card is most likely the wrong file.
grep '^| ' "$out" | grep -q -E "(^|[^0-9A-Z-])$KEY([^0-9]|$)" || { echo "⚠️ The export doesn't mention $KEY: its cases may belong to another card"; echo "   Tip: check its \"Story Linkages\" column; if it's the wrong file, delete runs/$KEY/qmetry/$(basename "$out") and import the right one."; }
