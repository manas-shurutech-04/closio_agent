# One test for tests/run.sh (D93): runs <test function> from <test file> in its own subshell and writes its result
# line (and, when it failed, the end of its output) to $WORK/<id>.res. tests/run.sh starts it through xargs, JOBS at a
# time, so a file with slow tests (real time limits, a server that restarts) doesn't hold up the others.
# Only builtins besides the test itself: on a Mac with security software every extra program costs time.

set -u
file="$1" name="$2" id="$3"
SECONDS=0
( . "$TESTS_DIR/lib/testlib.sh"; . "$file"; "$name" ) > "$WORK/$id.log" 2>&1
rc=$?
base="${file##*/}"; words="${name#test_}"
title="${base%.test.sh} › ${words//_/ }"
if [ "$rc" -eq 0 ]; then
  printf '✅ %s\n' "$title" > "$WORK/$id.res"
else
  { printf '❌ %s  (%ss)\n' "$title" "$SECONDS"; tail -25 "$WORK/$id.log" | sed 's/^/     /'; } > "$WORK/$id.res"
fi
exit 0
