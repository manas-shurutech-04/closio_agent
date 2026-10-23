# scripts/wait-seconds.sh: waits 1 to 30 seconds. "sleep" is a stand-in here (logged, returns at once), so no test
# waits, except the one that checks the real sleep for 1 second.

fake_sleep() { # sleep first on PATH: logs "sleep <seconds>" to the stand-in log and returns at once
  sandbox
  mkdir -p "$T/bin"
  printf '#!/bin/bash\nprintf "sleep %%s\\n" "$*" >> "$FAKE_LOG"\n' > "$T/bin/sleep"
  chmod +x "$T/bin/sleep"
  export PATH="$T/bin:$PATH"
}

test_waits_the_seconds_given() {
  fake_sleep
  run wait-seconds.sh 7
  assert_rc 0; assert_eq "$OUT" "Waited 7 seconds."
  assert_eq "$(fake_calls sleep)" "sleep 7"
}
test_without_a_number_it_waits_ten_seconds() {
  fake_sleep
  run wait-seconds.sh
  assert_rc 0; assert_eq "$OUT" "Waited 10 seconds."
  assert_eq "$(fake_calls sleep)" "sleep 10"
}
test_every_number_from_1_to_30_is_accepted() {
  fake_sleep
  local s
  for s in 1 9 10 19 20 29 30; do
    run wait-seconds.sh "$s"
    assert_rc 0; assert_eq "$OUT" "Waited $s seconds." "wait $s"
  done
  assert_eq "$(fake_calls sleep | tr '\n' ' ')" "sleep 1 sleep 9 sleep 10 sleep 19 sleep 20 sleep 29 sleep 30 "
}
test_numbers_outside_1_to_30_and_words_are_refused() {
  fake_sleep
  local s
  for s in 0 31 40 100 -1 05 1.5 abc "1 2"; do
    run wait-seconds.sh "$s"
    assert_rc 1; assert_eq "$OUT" "Usage: bash scripts/wait-seconds.sh <1-30>" "refuse '$s'"
  done
  assert_eq "$(fake_calls sleep)" "" "never sleeps on a refused number"
}
test_it_really_waits_with_the_real_sleep() {
  sandbox
  local t0 t1
  t0=$(date +%s)
  run wait-seconds.sh 1
  t1=$(date +%s)
  assert_rc 0; assert_eq "$OUT" "Waited 1 seconds."
  [ $((t1 - t0)) -ge 1 ] || fail "returned before a second had passed"
}
