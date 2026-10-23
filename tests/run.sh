#!/usr/bin/env bash
# closio-agent's own tests (D92): its scripts, its commands and its rules, checked without an AI, without the real
# Jira, GitLab, VPN or Keychain, and without installing anything (the Mac's bash, git, jq, python3 and curl).
# Run it from the closio-agent folder:
#
#   bash tests/run.sh                    every test
#   bash tests/run.sh <words…>           only the test files whose name has one of the words (e.g. run.sh, jira)
#   bash tests/run.sh --coverage [<words…>]
#                                        the same, plus the share of each script's lines the tests ran; fails when the
#                                        total is under 90% (the per-script list of lines not run: local/test-coverage/)
#
# The test files: tests/unit/<script>.test.sh (one per script), tests/static/*.test.sh (the commands and the rules),
# tests/flows/*.test.sh (the scripts in the order a command runs them, against fakes). Each test function (test_…)
# runs on its own, in a throwaway folder with a space in its path; it never touches this folder's local/, runs/, the
# Keychain, GitHub or GitLab (tests/lib/testlib.sh). Exit code: 0 = every test passed (and, with --coverage, 90% or
# more), 1 = otherwise. Works in the Mac's own bash 3.2.

set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd -P)"
ROOT="$(cd "$TESTS_DIR/.." && pwd -P)"
COVERAGE_MIN="${COVERAGE_MIN:-90}"
JOBS="${TEST_JOBS:-4}"

coverage=no
words=""
for a in "$@"; do
  case "$a" in
    --coverage) coverage=yes ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) words="$words $a" ;;
  esac
done

files=""
for f in "$TESTS_DIR"/unit/*.test.sh "$TESTS_DIR"/static/*.test.sh "$TESTS_DIR"/flows/*.test.sh; do
  [ -f "$f" ] || continue
  if [ -n "$words" ]; then
    keep=no
    for w in $words; do case "$(basename "$f")" in *"$w"*) keep=yes ;; esac; done
    [ "$keep" = yes ] || continue
  fi
  files="$files
$f"
done
files="$(printf '%s\n' "$files" | sed '/^$/d')"
[ -n "$files" ] || { echo "❌ No test file matches:$words"; echo "   Fix: see the names in tests/unit, tests/static and tests/flows."; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/closio-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export CLOSIO_ROOT="$ROOT" TESTS_DIR
if [ "$coverage" = yes ]; then
  export COV_FILE="$WORK/coverage.txt"
  : > "$COV_FILE"
fi

# One test file: every test_ function in it, each in its own subshell; results into <work>/<n>.out and <n>.counts
run_file() { # <file> <n>
  local file="$1" n="$2" names name out rc pass=0 fail=0 t0 t1
  names="$(bash -c '. "$1" >/dev/null 2>&1; declare -F | sed "s/^declare -f //" | grep "^test_"' _ "$file")"
  out="$WORK/$n.out"; : > "$out"
  for name in $names; do
    t0=$(date +%s)
    ( . "$TESTS_DIR/lib/testlib.sh"; . "$file"; "$name" ) > "$WORK/$n.$name.log" 2>&1
    rc=$?
    t1=$(date +%s)
    if [ "$rc" -eq 0 ]; then
      pass=$((pass + 1)); printf '✅ %s › %s\n' "$(basename "$file" .test.sh)" "$(printf '%s' "${name#test_}" | tr '_' ' ')" >> "$out"
    else
      fail=$((fail + 1)); printf '❌ %s › %s  (%ss)\n' "$(basename "$file" .test.sh)" "$(printf '%s' "${name#test_}" | tr '_' ' ')" $((t1 - t0)) >> "$out"
      tail -25 "$WORK/$n.$name.log" | sed 's/^/     /' >> "$out"
    fi
  done
  echo "$pass $fail" > "$WORK/$n.counts"
}

n=0
for f in $(printf '%s\n' "$files" | sed 's/ /%20/g'); do
  f="$(printf '%s' "$f" | sed 's/%20/ /g')"
  n=$((n + 1))
  while [ "$(jobs -r | wc -l | tr -d ' ')" -ge "$JOBS" ]; do sleep 0.2; done
  run_file "$f" "$n" &
done
wait

pass=0; fail=0
i=1
while [ "$i" -le "$n" ]; do
  cat "$WORK/$i.out"
  read p q < "$WORK/$i.counts" 2>/dev/null || { p=0; q=1; echo "❌ test file $i didn't finish"; }
  pass=$((pass + p)); fail=$((fail + q))
  i=$((i + 1))
done
echo
echo "passed $pass, failed $fail"
result=0
[ "$fail" -eq 0 ] || result=1

if [ "$coverage" = yes ]; then
  echo
  python3 "$TESTS_DIR/lib/coverage.py" "$COV_FILE" "$ROOT" "$COVERAGE_MIN" "$ROOT/local/test-coverage" || result=1
fi
exit "$result"
