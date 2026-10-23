# scripts/vpn-admin-steps.sh: the VPN steps that run as root (D14, D27, D30).
#
# The real script only runs as root, resets PATH and writes /etc/resolver, so (apart from the not-root test) the tests
# run a copy in the sandbox with exactly those fixed places moved into it, line for line (so coverage still counts):
# PATH starts with $T/abin (id says 0, pkill/pgrep are the logged stand-ins, sleep is short), /etc/resolver is
# $T/etc/resolver and openfortivpn's two Homebrew places are under $T. Nothing here runs as root, writes /etc, or
# touches a real openfortivpn: the "openfortivpn" it starts is a script in the sandbox, killed when the test ends.

GW=vpn.example.test
SHA=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef

admin_box() {
  sandbox
  local src="$CLOSIO_ROOT/scripts/vpn-admin-steps.sh" f="$A/scripts/vpn-admin-steps.sh" t
  mkdir -p "$T/abin" "$T/etc/resolver" "$T/opt/homebrew/bin" "$T/usr/local/bin" "$A/local/vpn"
  sed -e "s|^PATH=/usr/bin:|PATH=\"$T/abin\":/usr/bin:|" \
      -e "s|'^/etc/resolver/|'^$T/etc/resolver/|" \
      -e "s|mkdir -p /etc/resolver|mkdir -p \"$T/etc/resolver\"|" \
      -e "s|in /opt/homebrew/bin/openfortivpn\|/usr/local/bin/openfortivpn)|in \"$T/opt/homebrew/bin/openfortivpn\"\|\"$T/usr/local/bin/openfortivpn\")|" \
      "$src" > "$f"
  # The copy must have the same lines, and no fixed system place left in its code (else the test could touch them)
  assert_eq "$(wc -l < "$f" | tr -d ' ')" "$(wc -l < "$src" | tr -d ' ')" "the copy keeps every line"
  assert_eq "$(grep -v '^[[:space:]]*#' "$f" | grep -c -E '\^/etc/resolver| /etc/resolver| /opt/homebrew|[|]/usr/local/bin|^PATH=/usr')" "0" "fixed places left in the copy"
  assert_eq "$(grep -c -F "$T" "$f")" "4" "the four lines moved into the sandbox"
  printf '#!/bin/bash\nif [ "${1:-}" = "-u" ]; then echo 0; else exec /usr/bin/id "$@"; fi\n' > "$T/abin/id"
  printf '#!/bin/bash\nexec /bin/sleep 0.02\n' > "$T/abin/sleep"
  for t in pkill pgrep; do printf '#!/bin/bash\nexec "%s/fakes/bin/_standin" %s "$@"\n' "$TESTS_DIR" "$t" > "$T/abin/$t"; done
  chmod +x "$T/abin/"*
  OFV="$T/opt/homebrew/bin/openfortivpn"
  DNS="$T/etc/resolver/japfacomfeed.co.id"
  OLD="$T/etc/resolver/jcvs.japfacomfeed.co.id"
  LOG="$A/local/vpn/openfortivpn.log"
  : > "$LOG"
  export SUDO_USER="$(id -un)"
}

# The stand-in openfortivpn: <mode> up | cert | stop | wait. It logs its arguments and its pid (killed at the end).
fake_openfortivpn() { # <mode> [<path>]
  local p="${2:-$OFV}" body
  case "$1" in
    up) body='echo "INFO:   Tunnel is up and running."; exec /bin/sleep 30' ;;
    cert) body='echo "ERROR:  Gateway certificate validation failed."; exec /bin/sleep 30' ;;
    stop) body='echo "ERROR:  Could not resolve the gateway."; exit 1' ;;
    wait) body='exec /bin/sleep 30' ;;
  esac
  printf '#!/bin/bash\necho $$ >> "%s/.fake-pids"\nprintf "%%s\\n" "$*" > "%s/ofv-args"\n%s\n' "$T" "$T" "$body" > "$p"
  chmod +x "$p"
}

connect() { # [<timeout>] [<dns servers>…]: the connect step with valid input
  local to="${1:-999}"; [ $# -gt 0 ] && shift
  [ $# -gt 0 ] || set -- 10.90.0.53 10.190.0.55
  run vpn-admin-steps.sh connect "$OFV" "$GW" 443 sso "$SHA" "$DNS" "$OLD" "$LOG" "$to" "$@"
}

test_it_refuses_to_run_without_admin_rights() {
  sandbox
  [ "$(id -u)" != "0" ] || fail "run the tests as yourself, never as root"
  run vpn-admin-steps.sh no-such-step   # the real script: even as root it would only exit 2
  assert_rc 2; assert_eq "$OUT" "vpn-admin-steps.sh must run as root"
  assert_eq "$(fake_calls)" "" "nothing else ran"
}

test_connect_starts_openfortivpn_and_writes_the_dns_file_when_the_tunnel_is_up() {
  admin_box; fake_openfortivpn up
  printf 'old\n' > "$DNS"; printf 'old\n' > "$OLD"
  connect 999 10.90.0.53 10.190.0.55
  assert_rc 0
  assert_eq "$(cat "$DNS")" "nameserver 10.90.0.53
nameserver 10.190.0.55"
  assert_eq "$(stat -f %Lp "$DNS")" "644" "the DNS file's mode"
  assert_no_file "$OLD"
  assert_eq "$(cat "$T/ofv-args")" "$GW:443 --realm=sso --saml-login --trusted-cert $SHA"
  assert_contains "$(cat "$LOG")" "Tunnel is up and running"
  assert_eq "$(tail -1 "$LOG")" "closio-agent: connected"
  assert_contains "$(fake_calls pkill)" "pkill -INT -x openfortivpn" "a leftover openfortivpn is stopped first"
}

test_connect_also_finds_openfortivpn_in_the_intel_homebrew_place() {
  admin_box; fake_openfortivpn up "$T/usr/local/bin/openfortivpn"; OFV="$T/usr/local/bin/openfortivpn"
  connect 999 10.0.0.1
  assert_rc 0; assert_eq "$(cat "$DNS")" "nameserver 10.0.0.1"
}

test_connect_stops_when_the_certificate_is_refused() {
  admin_box; fake_openfortivpn cert
  connect
  assert_rc 10
  assert_eq "$(tail -1 "$LOG")" "closio-agent: certificate refused"
  assert_no_file "$DNS"
}

test_connect_reports_openfortivpn_stopping_before_the_tunnel() {
  admin_box; fake_openfortivpn stop
  connect
  assert_rc 11
  assert_eq "$(tail -1 "$LOG")" "closio-agent: openfortivpn stopped"
  assert_no_file "$DNS"
}

test_connect_times_out_cleans_up_and_waits_for_openfortivpn_to_stop() {
  admin_box; fake_openfortivpn wait
  fake_cmd pgrep 'exit 0'   # openfortivpn never stops on its own: the 10 checks, then a plain pkill
  connect 2
  assert_rc 12
  assert_eq "$(tail -1 "$LOG")" "closio-agent: timed out"
  assert_no_file "$DNS"
  assert_eq "$(fake_calls pgrep | wc -l | tr -d ' ')" "20" "two stops (before and after), 10 checks each"
  assert_eq "$(fake_calls pkill)" "pkill -INT -x openfortivpn
pkill -x openfortivpn
pkill -INT -x openfortivpn
pkill -x openfortivpn"
}

test_connect_refuses_every_bad_input_before_doing_anything() {
  admin_box; fake_openfortivpn up
  local a
  run vpn-admin-steps.sh connect "$OFV" "$GW" 443 sso "$SHA" "$DNS" "$OLD" "$LOG" 30
  assert_rc 2   # no DNS server
  for a in "/usr/bin/openfortivpn|$GW|443|sso|$SHA|$DNS|$OLD|$LOG|30" \
           "$OFV|Bad_Gateway|443|sso|$SHA|$DNS|$OLD|$LOG|30" \
           "$OFV|$GW|44a|sso|$SHA|$DNS|$OLD|$LOG|30" \
           "$OFV|$GW|443|s;o|$SHA|$DNS|$OLD|$LOG|30" \
           "$OFV|$GW|443|sso|abc|$DNS|$OLD|$LOG|30" \
           "$OFV|$GW|443|sso|$SHA|$T/etc/hosts|$OLD|$LOG|30" \
           "$OFV|$GW|443|sso|$SHA|$DNS|$T/etc/resolver/Bad Name|$LOG|30" \
           "$OFV|$GW|443|sso|$SHA|$DNS|$OLD|$LOG|1000" \
           "$OFV|$GW|443|sso|$SHA|$DNS|$OLD|$T/openfortivpn.log|30" \
           "$OFV|$GW|443|sso|$SHA|$DNS|$OLD|$A/../closio agent/local/vpn/openfortivpn.log|30" \
           "$OFV|$GW|443|sso|$SHA|$DNS|$OLD|$A/x/local/vpn/openfortivpn.log|30"; do
    (IFS='|'; set -- $a; cd "$A" && bash scripts/vpn-admin-steps.sh connect "$@" 10.0.0.1 >/dev/null 2>&1); RC=$?
    assert_rc 2
  done
  run vpn-admin-steps.sh connect "$OFV" "$GW" 443 sso "$SHA" "$DNS" "$OLD" "$LOG" 30 10.0.0.256x
  assert_rc 2   # a bad DNS server
  export SUDO_USER=someone-else; connect 30
  assert_rc 2   # the log file isn't the user's
  export SUDO_USER="$(id -un)"
  chmod -x "$OFV"; connect 30
  assert_rc 2   # openfortivpn isn't executable
  assert_no_file "$T/ofv-args"; assert_eq "$(fake_calls)" "" "nothing was started or stopped"
}

test_add_dns_writes_only_a_valid_file() {
  admin_box
  run vpn-admin-steps.sh add-dns "$DNS" 10.1.2.3
  assert_rc 0; assert_eq "$(cat "$DNS")" "nameserver 10.1.2.3"
  rm -f "$DNS"
  run vpn-admin-steps.sh add-dns "$DNS"
  assert_rc 2
  run vpn-admin-steps.sh add-dns "$T/etc/other" 10.1.2.3
  assert_rc 2
  run vpn-admin-steps.sh add-dns "$DNS" 10.1.2.3 not-an-ip
  assert_rc 2; assert_no_file "$DNS"
}

test_disconnect_stops_openfortivpn_and_removes_the_dns_file() {
  admin_box; printf 'x\n' > "$DNS"
  run vpn-admin-steps.sh disconnect "$DNS"
  assert_rc 0; assert_no_file "$DNS"
  assert_eq "$(fake_calls pkill)" "pkill -INT -x openfortivpn"
  assert_eq "$(fake_calls pgrep)" "pgrep -x openfortivpn"
}

test_disconnect_when_openfortivpn_is_not_running() {
  admin_box; printf 'x\n' > "$DNS"
  fake_cmd pkill 'exit 1'
  run vpn-admin-steps.sh disconnect "$DNS"
  assert_rc 0; assert_no_file "$DNS"; assert_eq "$(fake_calls pgrep)" "" "no wait when nothing was stopped"
}

test_disconnect_and_unknown_actions_refuse_bad_input() {
  admin_box; printf 'x\n' > "$DNS"
  run vpn-admin-steps.sh disconnect
  assert_rc 2
  run vpn-admin-steps.sh disconnect "$DNS" extra
  assert_rc 2
  run vpn-admin-steps.sh disconnect "$T/etc/hosts"
  assert_rc 2
  run vpn-admin-steps.sh rm-rf /
  assert_rc 2
  run vpn-admin-steps.sh
  assert_rc 2
  assert_file "$DNS"; assert_eq "$(fake_calls)" "" "nothing was stopped"
}
