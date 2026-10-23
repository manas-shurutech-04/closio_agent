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
#   bash tests/run.sh --docker [--coverage] [<words…>]
#                                        the same, in a Linux container with the Mac's bash 3.2 (D93): about a minute,
#                                        where a Mac with security software takes about 11. Needs Docker Desktop running;
#                                        its image (tests/docker/) is built the first time and whenever it changes.
#
# The test files: tests/unit/<script>.test.sh (one per script), tests/static/*.test.sh (the commands and the rules),
# tests/flows/*.test.sh (the scripts in the order a command runs them, against fakes). Each test function (test_…)
# runs on its own (tests/lib/run-test.sh), TEST_JOBS at a time (4 on the Mac, 16 in Docker), in a throwaway folder with
# a space in its path; it never touches this folder's local/, runs/, the Keychain, GitHub or GitLab
# (tests/lib/testlib.sh). Exit code: 0 = every test passed (and, with --coverage, 90% or more), 1 = otherwise.
# Works in the Mac's own bash 3.2.

set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd -P)"
ROOT="$(cd "$TESTS_DIR/.." && pwd -P)"
COVERAGE_MIN="${COVERAGE_MIN:-90}"
JOBS="${TEST_JOBS:-4}"

coverage=no
docker=no
words=""
for a in "$@"; do
  case "$a" in
    --coverage) coverage=yes ;;
    --docker) docker=yes ;;
    -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) words="$words $a" ;;
  esac
done

# --docker (D93): the same run inside the test image; this folder is mounted at /work, the throwaway folders are in
# the container's memory. The image's tag is the hash of tests/docker/, so a changed image is built again by itself.
if [ "$docker" = yes ]; then
  command -v docker >/dev/null 2>&1 || {
    echo "❌ Docker isn't installed"
    echo "   Fix: install Docker Desktop (https://www.docker.com/products/docker-desktop/), start it, then run this again; or run without --docker."
    exit 1
  }
  docker info >/dev/null 2>&1 || {
    echo "❌ Docker isn't running"
    echo "   Fix: start Docker Desktop (open -a Docker), wait until it says it's running, then run this again; or run without --docker."
    exit 1
  }
  tag="closio-tests:$(cd "$TESTS_DIR/docker" && find . -type f | LC_ALL=C sort | while IFS= read -r f; do printf '%s\n' "$f"; cat "$f"; done |
    shasum -a 256 | cut -c1-12)"
  # Docker Desktop pauses itself after a few idle minutes; the first look after it wakes can miss the image, so look twice
  if ! docker image inspect "$tag" >/dev/null 2>&1 && ! { sleep 2; docker image inspect "$tag" >/dev/null 2>&1; }; then
    echo "Building the test image $tag (only when tests/docker/ changed; the first time downloads about 90 MB)…"
    docker build -q -t "$tag" "$TESTS_DIR/docker" >/dev/null || {
      echo "❌ The test image didn't build"
      echo "   Fix: check Docker Desktop is running and this Mac is online (the build downloads bash 3.2 and the tools), then run this again; Docker's error is above."
      exit 1
    }
    for old in $(docker image ls --format '{{.Repository}}:{{.Tag}}' closio-tests 2>/dev/null); do
      [ "$old" = "$tag" ] || docker image rm "$old" >/dev/null 2>&1
    done
  fi
  set --
  [ "$coverage" = yes ] && set -- --coverage
  exec docker run --rm -v "$ROOT":/work -w /work --tmpfs /tmp:exec,size=2g -e TEST_JOBS="${TEST_JOBS:-16}" \
    -e COVERAGE_MIN="$COVERAGE_MIN" "$tag" bash tests/run.sh "$@" $words
fi

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
export CLOSIO_ROOT="$ROOT" TESTS_DIR WORK
if [ "$coverage" = yes ]; then
  export COV_FILE="$WORK/coverage.txt"
  : > "$COV_FILE"
fi

# Every test is a job of its own (D93): <file> <test function> <file number>.<test number>, NUL-separated, then xargs
# runs JOBS at once; each writes $WORK/<id>.res, printed afterwards in file order.
n=0
for f in $(printf '%s\n' "$files" | sed 's/ /%20/g'); do
  f="$(printf '%s' "$f" | sed 's/%20/ /g')"
  n=$((n + 1)); i=0
  for name in $(bash -c '. "$1" >/dev/null 2>&1; declare -F | sed "s/^declare -f //" | grep "^test_"' _ "$f"); do
    i=$((i + 1))
    printf '%s\0%s\0%03d.%03d\0' "$f" "$name" "$n" "$i"
  done
done > "$WORK/tasks"
total="$(tr -cd '\0' < "$WORK/tasks" | wc -c | tr -d ' ')"; total=$((total / 3))
xargs -0 -n 3 -P "$JOBS" bash "$TESTS_DIR/lib/run-test.sh" < "$WORK/tasks"

cat "$WORK"/*.res 2>/dev/null
pass="$(cat "$WORK"/*.res 2>/dev/null | grep -c '^✅')"
fail="$(cat "$WORK"/*.res 2>/dev/null | grep -c '^❌')"
if [ $((pass + fail)) -lt "$total" ]; then
  echo "❌ $((total - pass - fail)) test(s) didn't finish"
  fail=$((total - pass))
fi
echo
echo "passed $pass, failed $fail"
result=0
[ "$fail" -eq 0 ] || result=1

if [ "$coverage" = yes ]; then
  echo
  python3 "$TESTS_DIR/lib/coverage.py" "$COV_FILE" "$ROOT" "$COVERAGE_MIN" "$ROOT/local/test-coverage" || result=1
fi
exit "$result"
