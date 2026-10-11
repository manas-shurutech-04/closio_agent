#!/bin/bash
# The few VPN steps that need admin rights (F3, D14, D27, D30).
# scripts/vpn.sh runs this through ONE 'sudo -A' call, so the user types their Mac password once.
# It checks every input and does nothing else.
# !! It runs as root: review any change to this file carefully.
#
#   connect <openfortivpn> <gateway> <port> <realm> <cert-sha256> <dns-file> <old-dns-file> <log-file> <timeout> <dns-server>...
#   add-dns <dns-file> <dns-server>...
#   disconnect <dns-file>
#
# Exit codes: 0 done, 2 bad input, 10 certificate refused, 11 openfortivpn stopped, 12 SSO login timed out.

set -u
PATH=/usr/bin:/bin:/usr/sbin:/sbin

[ "$(id -u)" = "0" ] || { echo "vpn-admin-steps.sh must run as root" >&2; exit 2; }

matches() { printf '%s' "$1" | grep -q -E "$2"; }
valid_dns_file() { matches "$1" '^/etc/resolver/[a-z0-9.-]+$'; }
valid_ip() { matches "$1" '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; }

write_dns_file() { # <dns-file> <dns-server>...
  local file="$1" content="" ip
  shift
  [ $# -gt 0 ] || exit 2
  for ip in "$@"; do
    valid_ip "$ip" || exit 2
    content="${content}nameserver $ip
"
  done
  mkdir -p /etc/resolver
  printf '%s' "$content" > "$file"
  chmod 644 "$file"
}

stop_openfortivpn() {
  pkill -INT -x openfortivpn 2>/dev/null || return 0
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -x openfortivpn >/dev/null || return 0
    sleep 1
  done
  pkill -x openfortivpn 2>/dev/null
  return 0
}

action="${1:-}"
case "$action" in
  connect)
    [ $# -ge 11 ] || exit 2
    ofv="$2"; gateway="$3"; port="$4"; realm="$5"; sha="$6"; dns_file="$7"; old_dns_file="$8"; log="$9"; timeout="${10}"
    shift 10
    case "$ofv" in /opt/homebrew/bin/openfortivpn|/usr/local/bin/openfortivpn) ;; *) exit 2 ;; esac
    [ -x "$ofv" ] || exit 2
    matches "$gateway" '^[a-z0-9.-]+$' || exit 2
    matches "$port" '^[0-9]{1,5}$' || exit 2
    matches "$realm" '^[A-Za-z0-9_-]+$' || exit 2
    matches "$sha" '^[0-9a-f]{64}$' || exit 2
    valid_dns_file "$dns_file" || exit 2
    valid_dns_file "$old_dns_file" || exit 2
    matches "$timeout" '^[0-9]{1,3}$' || exit 2
    case "$log" in /*/local/vpn/openfortivpn.log) ;; *) exit 2 ;; esac
    case "$log" in *..*) exit 2 ;; esac
    [ -f "$log" ] && [ "$(stat -f %Su "$log")" = "${SUDO_USER:-}" ] || exit 2
    for ip in "$@"; do valid_ip "$ip" || exit 2; done

    # A leftover DNS file stops the connection (D27); the old GitLab-only file is no longer needed.
    rm -f "$dns_file" "$old_dns_file"
    stop_openfortivpn

    # Start openfortivpn in its own session, so it keeps running after this script and the AI tool's command end.
    /usr/bin/perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV' -- \
      "$ofv" "$gateway:$port" --realm="$realm" --saml-login --trusted-cert "$sha" >> "$log" 2>&1 < /dev/null &
    pid=$!

    waited=0
    while [ "$waited" -lt "$timeout" ]; do
      if grep -q "Tunnel is up and running" "$log"; then
        write_dns_file "$dns_file" "$@"
        echo "closio-agent: connected" >> "$log"
        exit 0
      fi
      if grep -q -E "certificate digest is not in the local whitelist|Gateway certificate validation failed" "$log"; then
        kill -INT "$pid" 2>/dev/null
        echo "closio-agent: certificate refused" >> "$log"
        exit 10
      fi
      if ! kill -0 "$pid" 2>/dev/null; then
        echo "closio-agent: openfortivpn stopped" >> "$log"
        exit 11
      fi
      sleep 1
      waited=$((waited + 1))
    done
    stop_openfortivpn
    rm -f "$dns_file"
    echo "closio-agent: timed out" >> "$log"
    exit 12
    ;;

  add-dns)
    [ $# -ge 3 ] || exit 2
    dns_file="$2"
    shift 2
    valid_dns_file "$dns_file" || exit 2
    write_dns_file "$dns_file" "$@"
    exit 0
    ;;

  disconnect)
    [ $# -eq 2 ] || exit 2
    valid_dns_file "$2" || exit 2
    stop_openfortivpn
    rm -f "$2"
    exit 0
    ;;

  *)
    exit 2
    ;;
esac
