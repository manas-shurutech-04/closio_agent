#!/usr/bin/env bash
# Runs a card's backend API test cases and says, per AC, whether they pass (C4, flow-verify and flow-ac-check; D67).
# Run it from the closio-agent folder:  bash scripts/api-check.sh <CARD-KEY> [<AC number>]
#
# The cases are in the card's run folder, one file per AC: runs/<CARD-KEY>/api-checks/ac-<n>.json
#   { "ac": 6, "title": "WS2 S2S auth — Missing client credentials",
#     "cases": [
#       { "name": "no client keys → 401 MISSING_CLIENT_CREDENTIALS",
#         "repo": "nodejs-ws2targetsalesincentive", "method": "GET",
#         "path": "/api/incentives/v1/trader-stock-days-multiplier-configs?status=active",
#         "headers": { "X-Partner-Id": "e3d8f926-a1bf-4890-9524-cc2d610152f9" },
#         "body": null,
#         "auth": "user",      (WS1: user | none)          "client": "none"   (WS2: ok | none | id-only | secret-only | unknown | wrong-secret)
#         "expect": { "status": 401, "checks": [ ".error_code == \"MISSING_CLIENT_CREDENTIALS\"" ] } } ] }
#   "checks" are jq expressions on the response body; each must be true.
# Every call goes through scripts/api-call.sh, so keys, passwords and sessions are never shown (rule A6).
# Prints ✅ / ❌ per case and per AC, with the response of each failing case.
# Exit codes: 0 every case passed · 1 at least one ❌ · 2 wrong usage or no cases.

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
RUNS_DIR="${RUNS_DIR:-$AGENT_ROOT/runs}"

usage() { echo "Usage: bash scripts/api-check.sh <CARD-KEY> [<AC number>]"; }
KEY="${1:-}"; ONE="${2:-}"
printf '%s' "$KEY" | grep -q -E "^$JIRA_PROJECT_KEY-[0-9]+$" || { usage; exit 2; }
[ -z "$ONE" ] || printf '%s' "$ONE" | grep -q -E '^[0-9]+$' || { usage; exit 2; }
DIR="$RUNS_DIR/$KEY/api-checks"
if [ -n "$ONE" ]; then FILES="$DIR/ac-$ONE.json"; [ -f "$FILES" ] || { echo "❌ No API test cases for AC $ONE: runs/$KEY/api-checks/ac-$ONE.json"; echo "   Fix: write them with /flow-ac-check $KEY $ONE (or /flow-verify $KEY writes every AC's)."; exit 2; }
else
  FILES="$(ls "$DIR"/ac-*.json 2>/dev/null | sed -E 's/.*ac-([0-9]+)\.json$/\1 &/' | sort -n | cut -d' ' -f2-)"
  [ -n "$FILES" ] || { echo "❌ No API test cases in runs/$KEY/api-checks/"; echo "   Fix: /flow-verify $KEY writes them (or /flow-ac-check $KEY <AC> for one AC)."; exit 2; }
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
ac_pass=0; ac_fail=0; failed_acs=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if ! jq empty "$f" 2>/dev/null; then echo "❌ $(basename "$f") isn't valid JSON"; echo "   Fix: correct it with /flow-ac-check $KEY <AC>."; ac_fail=$((ac_fail + 1)); continue; fi
  ac="$(jq -r '.ac // empty' "$f")"; title="$(jq -r '.title // ""' "$f")"
  [ -n "$ac" ] || ac="$(basename "$f" .json | sed 's/ac-//')"
  echo; echo "AC $ac — $title"
  n="$(jq '.cases | length' "$f")"; ok_n=0
  i=0
  while [ "$i" -lt "$n" ]; do
    jq ".cases[$i]" "$f" > "$TMP/case"
    name="$(jq -r '.name // "case"' "$TMP/case")"; repo="$(jq -r '.repo' "$TMP/case")"
    method="$(jq -r '.method // "GET"' "$TMP/case")"; path="$(jq -r '.path' "$TMP/case")"
    want="$(jq -r '.expect.status // empty' "$TMP/case")"
    set -- "$repo" "$method" "$path" --save "$TMP/saved"
    if [ "$(jq -r '.body == null' "$TMP/case")" = "false" ] && [ "$(jq -r 'has("body")' "$TMP/case")" = "true" ]; then
      jq '.body' "$TMP/case" > "$TMP/body"; set -- "$@" --body "$TMP/body"
    fi
    while IFS= read -r h; do [ -n "$h" ] && set -- "$@" --header "$h"; done <<EOF_H
$(jq -r '(.headers // {}) | to_entries[] | "\(.key): \(.value)"' "$TMP/case")
EOF_H
    a="$(jq -r '.auth // empty' "$TMP/case")"; [ -n "$a" ] && set -- "$@" --auth "$a"
    c="$(jq -r '.client // empty' "$TMP/case")"; [ -n "$c" ] && set -- "$@" --client "$c"
    rm -f "$TMP/saved"
    out="$(bash "$AGENT_ROOT/scripts/api-call.sh" "$@" 2>&1)"; rc=$?
    problems=""
    if [ "$rc" -ne 0 ] || [ ! -f "$TMP/saved" ]; then
      problems="the call failed: $(printf '%s' "$out" | head -2 | tr '\n' ' ')"
    else
      got="$(head -1 "$TMP/saved" | sed 's/^status: //')"; tail -n +2 "$TMP/saved" > "$TMP/resp"
      [ -z "$want" ] || [ "$got" = "$want" ] || problems="status $got, expected $want"
      while IFS= read -r chk; do
        [ -n "$chk" ] || continue
        jq -e "$chk" "$TMP/resp" >/dev/null 2>&1 || problems="${problems:+$problems; }not true: $chk"
      done <<EOF_C
$(jq -r '(.expect.checks // [])[]' "$TMP/case")
EOF_C
    fi
    if [ -z "$problems" ]; then
      echo "  ✅ $name"; ok_n=$((ok_n + 1))
    else
      echo "  ❌ $name"
      echo "     $problems"
      [ -f "$TMP/resp" ] && { jq -c . "$TMP/resp" 2>/dev/null || cat "$TMP/resp"; } | head -c 600 | sed 's/^/     response: /'; echo
    fi
    i=$((i + 1))
  done
  if [ "$ok_n" -eq "$n" ] && [ "$n" -gt 0 ]; then echo "  ✅ AC $ac passed ($n case(s))"; ac_pass=$((ac_pass + 1))
  else echo "  ❌ AC $ac: $((n - ok_n)) of $n case(s) failed"; ac_fail=$((ac_fail + 1)); failed_acs="${failed_acs:+$failed_acs, }AC $ac"; fi
done <<EOF_FILES
$FILES
EOF_FILES

echo
if [ "$ac_fail" -eq 0 ]; then echo "✅ API checks: every AC passed ($ac_pass)"; exit 0; fi
echo "❌ API checks: $ac_fail AC(s) failed ($failed_acs), $ac_pass passed"
exit 1
