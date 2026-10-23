# scripts/vpn.sh: connect, status and disconnect the VPN (F3, D14, D27, D30), with every outside tool a stand-in.
#
# sudo, ifconfig, pgrep, open and dscacheutil are the shared stand-ins; this file adds two of its own in $T/bin:
# curl (the stand-in decides what "GitLab" answers: GitLab is https only, so the fake HTTP server can't play it) and
# sleep (short, so the waits for GitLab take no time). The VPN DNS files and openfortivpn's places are in the sandbox;
# the admin steps are never really run (sudo is a stand-in that answers with the exit code a test chooses).

GW=vpn.example.test

vpn_box() {
  sandbox
  mkdir -p "$T/bin" "$T/etc/resolver" "$T/ofv"
  AP="$(cd "$A" && pwd -P)"   # the sandbox as the script sees itself (/private/var/…)
  printf '#!/bin/bash\nexec "%s/fakes/bin/_standin" curl "$@"\n' "$TESTS_DIR" > "$T/bin/curl"
  printf '#!/bin/bash\nexec /bin/sleep 0.02\n' > "$T/bin/sleep"
  chmod +x "$T/bin/curl" "$T/bin/sleep"
  export PATH="$T/bin:$PATH"
  export GITLAB_HOST=gitlab.example.test VPN_GATEWAY="$GW" VPN_DNS_SERVERS="10.0.0.1 10.0.0.2"
  export VPN_RESOLVER_FILE="$T/etc/resolver/japfacomfeed.co.id" VPN_OLD_RESOLVER_FILE="$T/etc/resolver/jcvs.japfacomfeed.co.id"
  export OPENFORTIVPN_BIN="$T/ofv/openfortivpn" OPENFORTIVPN_BIN_INTEL="$T/ofv-intel/openfortivpn" VPN_CONNECT_TIMEOUT=5
  export VPN_CERT_SHA256=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
  unset CODEX_SANDBOX CODEX_SANDBOX_NETWORK_DISABLED 2>/dev/null
  printf '#!/bin/bash\nexit 0\n' > "$OPENFORTIVPN_BIN"; chmod +x "$OPENFORTIVPN_BIN"
  fake_cmd ifconfig 'exit 1'   # openfortivpn's tunnel isn't up, unless a test says so
  fake_cmd sudo 'exit 0'       # the admin steps "work", unless a test says otherwise
  gitlab_answers_from 0
}
# GitLab answers 200 from the <n>-th call of curl on (0 = never)
gitlab_answers_from() {
  fake_cmd curl "n=\$((\$(cat \"\$FAKE_CMDS/../curl-n\" 2>/dev/null || echo 0) + 1)); echo \$n > \"\$FAKE_CMDS/../curl-n\"
if [ $1 -gt 0 ] && [ \$n -ge $1 ]; then printf 200; else printf 000; fi"
}
tunnel_up() { fake_cmd ifconfig 'exit 0'; }
# sudo (the admin steps) writes <log text> to openfortivpn's log, waits and exits with <code>. It waits until the SSO
# page was opened when the text has the gateway's login link (at most 10 s), else 1 s with a link, else 0.1 s.
admin_answers() { # <code> [<log text>]
  local wait='/bin/sleep 0.1'
  mkdir -p "$A/local/vpn"; printf '%s\n' "${2:-}" > "$T/admin-says"
  case "${2:-}" in
    *"Authenticate at 'https://$GW"*) wait='i=0; until grep -q "^open " "$FAKE_LOG" || [ $i -ge 200 ]; do /bin/sleep 0.05; i=$((i + 1)); done' ;;
    *Authenticate*) wait='/bin/sleep 1' ;;
  esac
  fake_cmd sudo "cat '$T/admin-says' >> '$A/local/vpn/openfortivpn.log'; $wait; exit $1"
}

test_status_off_is_fine_with_a_tip() {
  vpn_box
  run vpn.sh status
  assert_rc 0
  assert_eq "$OUT" "⚠️ VPN is off
   Tip: Run /flow-vpn connect (Codex: \$flow-vpn connect) when you need GitLab."
  assert_eq "$(fake_calls curl)" "curl -s -o /dev/null -w %{http_code} --max-time 6 https://gitlab.example.test/users/sign_in"
}

test_status_off_with_a_leftover_dns_file_is_an_error() {
  vpn_box; : > "$VPN_RESOLVER_FILE"
  run vpn.sh status
  assert_rc 1
  assert_contains "$OUT" "❌ A leftover VPN DNS file is still there; it stops the next connection"
  assert_contains "$OUT" "   Fix: Run /flow-vpn connect (it removes the file first), or: sudo rm -f $VPN_RESOLVER_FILE"
}

test_status_on_through_openfortivpn_or_another_client() {
  vpn_box; gitlab_answers_from 1; tunnel_up
  run vpn.sh status
  assert_rc 0; assert_eq "$OUT" "✅ VPN is on (openfortivpn) and GitLab is reachable"
  fake_cmd ifconfig 'exit 1'
  run vpn.sh status
  assert_rc 0; assert_eq "$OUT" "✅ VPN is on (another VPN client, e.g. the FortiClient app) and GitLab is reachable"
  assert_contains "$(fake_calls ifconfig)" "ifconfig ppp0"
}

test_status_tunnel_up_but_gitlab_silent() {
  vpn_box; tunnel_up
  run vpn.sh status
  assert_rc 1
  assert_eq "$OUT" "❌ VPN is on (openfortivpn), but the VPN DNS file is missing, so GitLab's name doesn't resolve
   Fix: Run /flow-vpn connect (Codex: \$flow-vpn connect). It adds the file."
  : > "$VPN_RESOLVER_FILE"
  run vpn.sh status
  assert_rc 1
  assert_contains "$OUT" "❌ VPN is on (openfortivpn), but GitLab doesn't answer"
  assert_contains "$OUT" "   Fix: Run /flow-vpn disconnect, then /flow-vpn connect."
}

test_inside_codex_sandbox_every_action_stops_with_the_way_out() {
  vpn_box; export CODEX_SANDBOX=seatbelt
  local a
  for a in status connect disconnect; do
    run vpn.sh "$a"
    assert_rc 1
    assert_eq "$OUT" "❌ Can't change or check the VPN from inside Codex's sandbox
   Fix: Run the command again and approve running it outside the sandbox when Codex asks.
        Or run 'bash scripts/vpn.sh $a' in a normal terminal."
  done
  unset CODEX_SANDBOX; export CODEX_SANDBOX_NETWORK_DISABLED=1
  run vpn.sh status
  assert_rc 1; assert_contains "$OUT" "inside Codex's sandbox"
  assert_eq "$(fake_calls)" "" "nothing was checked or changed"
}

test_connect_does_nothing_when_gitlab_already_answers() {
  vpn_box; gitlab_answers_from 1; tunnel_up
  run vpn.sh connect
  assert_rc 0; assert_eq "$OUT" "✅ Already connected (openfortivpn). GitLab is reachable"
  fake_cmd ifconfig 'exit 1'
  run vpn.sh connect
  assert_rc 0; assert_eq "$OUT" "✅ Already connected through another VPN client (e.g. the FortiClient app). GitLab is reachable"
  assert_eq "$(fake_calls sudo)" "" "no password asked"
}

test_connect_without_openfortivpn_installed() {
  vpn_box; rm -f "$OPENFORTIVPN_BIN"
  run vpn.sh connect
  assert_rc 1
  assert_eq "$OUT" "❌ openfortivpn is not installed
   Fix: Run 'brew install openfortivpn' (setup guide, section 2.1), then try again."
  assert_eq "$(fake_calls sudo)" ""
}

test_connect_adds_the_missing_dns_file_when_the_tunnel_is_up() {
  vpn_box; tunnel_up; gitlab_answers_from 3; admin_answers 0
  run vpn.sh connect
  assert_rc 0
  assert_contains "$OUT" "The VPN is up, but GitLab doesn't answer. Type your Mac password in the macOS dialog to add the VPN DNS file."
  assert_contains "$OUT" "✅ VPN DNS file added. GitLab is reachable"
  assert_eq "$(fake_calls sudo)" "sudo -A /bin/bash $AP/scripts/vpn-admin-steps.sh add-dns $VPN_RESOLVER_FILE 10.0.0.1 10.0.0.2"
}

test_connect_dns_file_added_but_gitlab_still_silent() {
  vpn_box; tunnel_up; admin_answers 0
  run vpn.sh connect
  assert_rc 1
  assert_contains "$OUT" "❌ GitLab still doesn't answer"
  assert_eq "$(fake_calls curl | wc -l | tr -d ' ')" "6" "one check, then five tries"
}

test_connect_dns_file_password_refused() {
  vpn_box; tunnel_up; admin_answers 1
  run vpn.sh connect
  assert_rc 1
  assert_contains "$OUT" "❌ The password dialog was cancelled, or the password was wrong. Nothing was changed
   Fix: Run the command again and type your Mac password in the macOS dialog."
}

test_connect_starts_the_vpn_opens_the_sso_page_and_waits_for_gitlab() {
  vpn_box; printf 'old log\n' > "$T/old"; mkdir -p "$A/local/vpn"; cp "$T/old" "$A/local/vpn/openfortivpn.log"
  gitlab_answers_from 2
  admin_answers 0 "Authenticate at 'https://$GW:443/remote/saml/start?redirect=1'"
  run vpn.sh connect
  assert_rc 0
  assert_contains "$OUT" "Connecting the VPN:
  1. Type your Mac password in the macOS dialog.
  2. Finish the SSO login in the browser page that opens (it may finish by itself).
  You have 5 seconds."
  assert_contains "$OUT" "Opened the SSO login page in your browser."
  assert_contains "$OUT" "✅ VPN connected (openfortivpn). GitLab is reachable. It stays on until you run /flow-vpn disconnect"
  assert_eq "$(fake_calls open)" "open https://$GW:443/remote/saml/start?redirect=1"
  assert_eq "$(fake_calls sudo)" "sudo -A /bin/bash $AP/scripts/vpn-admin-steps.sh connect $OPENFORTIVPN_BIN $GW 443 sso $VPN_CERT_SHA256 $VPN_RESOLVER_FILE $VPN_OLD_RESOLVER_FILE $AP/local/vpn/openfortivpn.log 5 10.0.0.1 10.0.0.2"
  assert_not_contains "$(cat "$A/local/vpn/openfortivpn.log")" "old log" "the log starts empty"
}

test_connect_finds_openfortivpn_in_the_second_homebrew_place() {
  vpn_box; rm -f "$OPENFORTIVPN_BIN"; mkdir -p "$T/ofv-intel"
  printf '#!/bin/bash\n' > "$OPENFORTIVPN_BIN_INTEL"; chmod +x "$OPENFORTIVPN_BIN_INTEL"
  gitlab_answers_from 2; admin_answers 0
  run vpn.sh connect
  assert_rc 0
  assert_contains "$(fake_calls sudo)" "connect $OPENFORTIVPN_BIN_INTEL $GW"
}

test_connect_never_opens_a_login_page_of_another_host() {
  vpn_box; gitlab_answers_from 2
  admin_answers 0 "Authenticate at 'https://evil.example.test/login'"
  run vpn.sh connect
  assert_rc 0
  assert_not_contains "$OUT" "Opened the SSO login page"; assert_eq "$(fake_calls open)" ""
}

test_connect_up_but_gitlab_silent() {
  vpn_box; admin_answers 0
  run vpn.sh connect
  assert_rc 1
  assert_contains "$OUT" "❌ The VPN came up, but GitLab doesn't answer"
}

test_connect_certificate_changed_shows_the_new_fingerprint() {
  vpn_box
  admin_answers 10 "ERROR: certificate digest is not in the local whitelist: $VPN_CERT_SHA256 and fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"
  run vpn.sh connect
  assert_rc 1
  assert_contains "$OUT" "❌ The VPN gateway's certificate changed, so openfortivpn refused it. Nothing was left behind"
  assert_contains "$OUT" "openfortivpn reports this fingerprint: fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"
  assert_contains "$OUT" "        If it's genuine, put it in config/project-settings.sh (VPN_CERT_SHA256 and VPN_CERT_EXPIRES), then run /flow-vpn connect again."
  admin_answers 10 "ERROR: no fingerprint here"
  run vpn.sh connect
  assert_contains "$OUT" "openfortivpn reports this fingerprint: see local/vpn/openfortivpn.log"
}

test_connect_every_other_failure_of_the_admin_steps() {
  vpn_box
  admin_answers 11
  run vpn.sh connect
  assert_rc 1; assert_contains "$OUT" "❌ openfortivpn stopped before the VPN came up"
  admin_answers 12
  run vpn.sh connect
  assert_rc 1
  assert_contains "$OUT" "❌ The SSO login wasn't finished within 5 seconds. The VPN was stopped and cleaned up"
  assert_contains "$OUT" "        If no page opens, open https://$GW:443/remote/saml/start?redirect=1&realm=sso yourself."
  admin_answers 2
  run vpn.sh connect
  assert_rc 1; assert_contains "$OUT" "❌ The VPN settings were refused as invalid"
  admin_answers 1
  run vpn.sh connect
  assert_rc 1; assert_contains "$OUT" "❌ The password dialog was cancelled, or the password was wrong."
}

test_disconnect_when_nothing_is_connected() {
  vpn_box
  run vpn.sh disconnect
  assert_rc 0; assert_eq "$OUT" "✅ Already disconnected"
  gitlab_answers_from 1
  run vpn.sh disconnect
  assert_rc 0
  assert_eq "$OUT" "⚠️ openfortivpn isn't running, but you're connected through another VPN client (e.g. the FortiClient app)
   Tip: Disconnect it in that app."
  assert_eq "$(fake_calls sudo)" ""
}

test_disconnect_stops_openfortivpn_and_checks_the_gateway_name() {
  vpn_box; : > "$VPN_RESOLVER_FILE"
  fake_cmd sudo "rm -f '$VPN_RESOLVER_FILE'"
  fake_cmd dscacheutil 'echo "name: x"; echo "ip_address: 203.0.113.9"'
  run vpn.sh disconnect
  assert_rc 0
  assert_eq "$OUT" "Disconnecting the VPN: type your Mac password in the macOS dialog.
✅ VPN disconnected and the VPN DNS file removed"
  assert_eq "$(fake_calls sudo)" "sudo -A /bin/bash $AP/scripts/vpn-admin-steps.sh disconnect $VPN_RESOLVER_FILE"
  assert_eq "$(fake_calls dscacheutil)" "dscacheutil -q host -a name $GW"
}

test_disconnect_when_the_gateway_name_does_not_resolve_after() {
  vpn_box
  fake_cmd pgrep "n=\$((\$(cat '$T/pgrep-n' 2>/dev/null || echo 0) + 1)); echo \$n > '$T/pgrep-n'; [ \$n -eq 1 ]"
  run vpn.sh disconnect
  assert_rc 0
  assert_contains "$OUT" "⚠️ VPN disconnected, but the VPN gateway's name doesn't resolve right now
   Tip: Check your internet connection before you connect again."
  assert_eq "$(fake_calls pgrep)" "pgrep -x openfortivpn
pgrep -x openfortivpn"
}

test_disconnect_failures() {
  vpn_box; : > "$VPN_RESOLVER_FILE"
  fake_cmd sudo 'exit 1'
  run vpn.sh disconnect
  assert_rc 1; assert_contains "$OUT" "❌ The password dialog was cancelled"
  fake_cmd sudo 'exit 0'
  run vpn.sh disconnect
  assert_rc 1
  assert_contains "$OUT" "❌ The VPN DNS file is still there
   Fix: Run: sudo rm -f $VPN_RESOLVER_FILE"
  fake_cmd pgrep 'exit 0'
  run vpn.sh disconnect
  assert_rc 1
  assert_contains "$OUT" "❌ openfortivpn is still running
   Fix: Run /flow-vpn disconnect again. If it stays, run: sudo pkill -x openfortivpn"
}

test_an_unknown_action_shows_the_usage() {
  vpn_box
  run vpn.sh
  assert_rc 1; assert_eq "$OUT" "Usage: bash scripts/vpn.sh connect | status | disconnect"
  run vpn.sh reconnect
  assert_rc 1; assert_contains "$OUT" "Usage:"
}
