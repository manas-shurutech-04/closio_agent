# scripts/lib/secret-dialogs.sh: a secret asked in a heads-up dialog and a hidden box, stored straight in the Keychain
# (here the fake one; the dialogs are the osascript stand-in). Its callers are configure-user.sh and configure-repo.sh.

# Runs one of the library's functions in a bash of its own (so its lines are recorded), with ok/look/bad as the
# scripts define them.
lib() { # <function> [args…]  (stdin goes to the function)
  OUT="$(cd "$A" && bash -c '
    ok() { echo "✅ $1"; }; look() { echo "⚠️ $1"; [ -n "${2:-}" ] && echo "   Tip: $2"; }; bad() { echo "❌ $1"; echo "   Fix: $2"; }
    . scripts/lib/secret-dialogs.sh; "$@"' _ "$@" 2>&1)"
  RC=$?
}
# The two dialogs: the heads-up answers its button, the hidden box the value (or fails, as Cancel does)
dialogs() { # <button> <value or "CANCEL">
  printf '%s\n' "$1" > "$T/button"; printf '%s\n' "$2" > "$T/value"
  fake_cmd osascript 'case "$*" in *"Copy it now"*) cat "'"$T"'/button" ;; *) v="$(cat "'"$T"'/value")"; [ "$v" = CANCEL ] && exit 1; echo "$v" ;; esac'
}

test_the_dialogs_are_the_macos_osascript_unless_a_test_says_otherwise() {
  sandbox
  OUT="$(cd "$A" && env -u OSASCRIPT_BIN bash -c '. scripts/lib/secret-dialogs.sh; echo "$OSASCRIPT_BIN"')"
  assert_eq "$OUT" "/usr/bin/osascript"
}
test_a_secret_typed_in_the_hidden_box_goes_only_into_the_keychain() {
  sandbox; export OSASCRIPT_BIN="$TESTS_DIR/fakes/bin/osascript"
  dialogs Continue "s3cr3t-value"
  lib ask_secret_dialog closio-agent.gitlab-token "closio-agent: GitLab token" "your GitLab token" "/flow-configure-user gitlab-token"
  assert_rc 0; assert_eq "$OUT" "✅ closio-agent.gitlab-token stored in the Keychain"
  assert_eq "$(cat "$FAKE_KEYCHAIN/closio-agent.gitlab-token")" "s3cr3t-value"
  assert_not_contains "$(fake_calls)" "s3cr3t-value" "the value on a command line"
}
test_skip_in_the_heads_up_stores_nothing() {
  sandbox; export OSASCRIPT_BIN="$TESTS_DIR/fakes/bin/osascript"
  dialogs Skip "x"
  lib ask_secret_dialog closio-agent.fe-login-id "label" "your login ID" "/flow-configure-user fe-login-id"
  assert_rc 3; assert_contains "$OUT" "⚠️ Skipped closio-agent.fe-login-id"; assert_contains "$OUT" "Add it later with: /flow-configure-user fe-login-id"
  keychain_has closio-agent.fe-login-id && fail "stored after Skip"
  return 0
}
test_cancel_in_the_hidden_box_stores_nothing() {
  sandbox; export OSASCRIPT_BIN="$TESTS_DIR/fakes/bin/osascript"
  dialogs Continue CANCEL
  lib ask_secret_dialog closio-agent.fe-login-id "label" "your login ID" "/flow-configure-user fe-login-id"
  assert_rc 3; assert_contains "$OUT" "⚠️ Cancelled, so closio-agent.fe-login-id was not changed"
}
test_an_empty_value_is_not_stored() {
  sandbox
  lib store_secret_from_stdin closio-agent.x "label" "/flow-configure-user x" < /dev/null
  assert_rc 3; assert_contains "$OUT" "⚠️ Nothing entered, so closio-agent.x was not changed"
}
test_a_keychain_that_refuses_the_value_is_an_error_with_its_fix() {
  sandbox
  fake_cmd security 'exit 44'
  OUT="$(cd "$A" && printf 'v\n' | bash -c 'ok() { echo "✅ $1"; }; look() { echo "⚠️ $1"; }; bad() { echo "❌ $1"; echo "   Fix: $2"; }
    . scripts/lib/secret-dialogs.sh; store_secret_from_stdin closio-agent.x label "/flow-configure-user x"' 2>&1)"; RC=$?
  assert_rc 1; assert_contains "$OUT" "❌ Couldn't store closio-agent.x in the Keychain"; assert_contains "$OUT" "Run /flow-configure-user x again"
}
