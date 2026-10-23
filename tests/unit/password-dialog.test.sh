# scripts/password-dialog.sh: the Mac password box "sudo -A" uses for the VPN steps. osascript is the stand-in
# (OSASCRIPT_BIN), so no real dialog opens.

setup_dialog() {
  sandbox
  export OSASCRIPT_BIN="$TESTS_DIR/fakes/bin/osascript"
}

test_the_password_typed_goes_to_sudo_on_stdout() {
  setup_dialog
  fake_cmd osascript 'echo "mac-Pass 123"'
  run password-dialog.sh
  assert_rc 0; assert_eq "$OUT" "mac-Pass 123"
  local call; call="$(fake_calls osascript)"
  assert_contains "$call" "closio-agent needs your Mac password to change the VPN connection."
  assert_contains "$call" "with hidden answer"
  assert_contains "$call" "text returned of result"
  assert_not_contains "$call" "mac-Pass 123" "the password is never on the dialog's command line"
}
test_cancel_gives_no_password_and_fails() {
  setup_dialog
  fake_cmd osascript 'echo "execution error: User canceled. (-128)" >&2; exit 1'
  run password-dialog.sh
  assert_rc 1; assert_eq "$OUT" "" "nothing printed (osascript's error is hidden)"
}
test_without_the_test_override_it_opens_the_macs_own_dialog() {
  setup_dialog
  grep -q -x 'OSASCRIPT_BIN="${OSASCRIPT_BIN:-/usr/bin/osascript}"' "$A/scripts/password-dialog.sh" ||
    fail "the default must stay /usr/bin/osascript"
}
