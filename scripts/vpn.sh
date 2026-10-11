#!/usr/bin/env bash
# Connects, checks or disconnects the Japfa VPN (F3, D14, D27, D30).
# Run it from the closio-agent folder:  bash scripts/vpn.sh connect | status | disconnect
#
# connect     Does nothing if GitLab already answers (through openfortivpn or another VPN client
#             such as the FortiClient app). Otherwise ONE macOS password dialog runs all admin steps
#             at once (scripts/vpn-admin-steps.sh), and the SSO login page opens in your browser.
#             The VPN then stays on until you disconnect.
# status      Only reads.
# disconnect  One password dialog: stops openfortivpn and removes the VPN DNS file.
#
# Every ❌ comes with the steps to fix it (rule A11). Exit code 1 when something failed.

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
ADMIN_STEPS="$AGENT_ROOT/scripts/vpn-admin-steps.sh"
LOG_FILE="$AGENT_ROOT/local/vpn/openfortivpn.log"
export SUDO_ASKPASS="$AGENT_ROOT/scripts/password-dialog.sh"

ok() { echo "✅ $1"; }
look() {
  echo "⚠️ $1"
  [ -n "${2:-}" ] && echo "   Tip: $2"
}
bad() {
  echo "❌ $1"
  echo "   Fix: $2"
  [ -n "${3:-}" ] && echo "        $3"
}

gitlab_answers() {
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 "https://$GITLAB_HOST/users/sign_in" 2>/dev/null)" = "200" ]
}
openfortivpn_up() { ifconfig "$VPN_INTERFACE" >/dev/null 2>&1; }
openfortivpn_running() { pgrep -x openfortivpn >/dev/null 2>&1; }
find_openfortivpn() {
  local p
  for p in /opt/homebrew/bin/openfortivpn /usr/local/bin/openfortivpn; do
    [ -x "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}
in_codex_sandbox() { [ -n "${CODEX_SANDBOX:-}${CODEX_SANDBOX_NETWORK_DISABLED:-}" ]; }
run_admin() { sudo -A /bin/bash "$ADMIN_STEPS" "$@"; }

wait_for_gitlab() { # up to ~15 seconds, DNS can take a moment after connecting
  local i
  for i in 1 2 3 4 5; do
    gitlab_answers && return 0
    sleep 3
  done
  return 1
}

password_failed() {
  bad "The password dialog was cancelled, or the password was wrong. Nothing was changed" \
    "Run the command again and type your Mac password in the macOS dialog."
}

sandbox_stop() {
  bad "Can't change or check the VPN from inside Codex's sandbox" \
    "Run the command again and approve running it outside the sandbox when Codex asks." \
    "Or run 'bash scripts/vpn.sh $1' in a normal terminal."
  exit 1
}

vpn_status() {
  in_codex_sandbox && sandbox_stop status
  if gitlab_answers; then
    if openfortivpn_up; then
      ok "VPN is on (openfortivpn) and GitLab is reachable"
    else
      ok "VPN is on (another VPN client, e.g. the FortiClient app) and GitLab is reachable"
    fi
    return 0
  fi
  if openfortivpn_up; then
    if [ ! -f "$VPN_RESOLVER_FILE" ]; then
      bad "VPN is on (openfortivpn), but the VPN DNS file is missing, so GitLab's name doesn't resolve" \
        "Run /flow-vpn connect (Codex: \$flow-vpn connect). It adds the file."
    else
      bad "VPN is on (openfortivpn), but GitLab doesn't answer" \
        "Run /flow-vpn disconnect, then /flow-vpn connect. If it still fails, see the setup guide, section 2.6."
    fi
    return 1
  fi
  look "VPN is off" "Run /flow-vpn connect (Codex: \$flow-vpn connect) when you need GitLab."
  if [ -f "$VPN_RESOLVER_FILE" ]; then
    bad "A leftover VPN DNS file is still there; it stops the next connection" \
      "Run /flow-vpn connect (it removes the file first), or: sudo rm -f $VPN_RESOLVER_FILE"
    return 1
  fi
  return 0
}

vpn_connect() {
  in_codex_sandbox && sandbox_stop connect

  if gitlab_answers; then
    if openfortivpn_up; then
      ok "Already connected (openfortivpn). GitLab is reachable"
    else
      ok "Already connected through another VPN client (e.g. the FortiClient app). GitLab is reachable"
    fi
    return 0
  fi

  local ofv
  if ! ofv="$(find_openfortivpn)"; then
    bad "openfortivpn is not installed" "Run 'brew install openfortivpn' (setup guide, section 2.1), then try again."
    return 1
  fi

  # openfortivpn runs, but GitLab doesn't answer: most likely the DNS file is missing.
  if openfortivpn_up; then
    echo "The VPN is up, but GitLab doesn't answer. Type your Mac password in the macOS dialog to add the VPN DNS file."
    # shellcheck disable=SC2086
    run_admin add-dns "$VPN_RESOLVER_FILE" $VPN_DNS_SERVERS || { password_failed; return 1; }
    if wait_for_gitlab; then
      ok "VPN DNS file added. GitLab is reachable"
      return 0
    fi
    bad "GitLab still doesn't answer" \
      "Run /flow-vpn disconnect, then /flow-vpn connect. If it still fails, see the setup guide, section 2.6."
    return 1
  fi

  mkdir -p "$(dirname "$LOG_FILE")"
  : > "$LOG_FILE"
  echo "Connecting the VPN:"
  echo "  1. Type your Mac password in the macOS dialog."
  echo "  2. Finish the SSO login in the browser page that opens (it may finish by itself)."
  echo "  You have $VPN_CONNECT_TIMEOUT seconds."

  # shellcheck disable=SC2086
  run_admin connect "$ofv" "$VPN_GATEWAY" "$VPN_PORT" "$VPN_REALM" "$VPN_CERT_SHA256" \
    "$VPN_RESOLVER_FILE" "$VPN_OLD_RESOLVER_FILE" "$LOG_FILE" "$VPN_CONNECT_TIMEOUT" $VPN_DNS_SERVERS &
  local admin_pid=$! opened="" url rc
  while kill -0 "$admin_pid" 2>/dev/null; do
    if [ -z "$opened" ]; then
      url="$(grep -o "Authenticate at '[^']*'" "$LOG_FILE" 2>/dev/null | head -1 | sed "s/^Authenticate at '//; s/'\$//")"
      case "$url" in
        "https://$VPN_GATEWAY"*) open "$url" && opened="yes" && echo "Opened the SSO login page in your browser." ;;
      esac
    fi
    sleep 1
  done
  wait "$admin_pid"
  rc=$?

  case "$rc" in
    0)
      if wait_for_gitlab; then
        ok "VPN connected (openfortivpn). GitLab is reachable. It stays on until you run /flow-vpn disconnect"
        return 0
      fi
      bad "The VPN came up, but GitLab doesn't answer" \
        "Run /flow-vpn disconnect, then /flow-vpn connect. If it still fails, see the setup guide, section 2.6."
      return 1
      ;;
    10)
      local new_pin
      new_pin="$(grep -o -E '[0-9a-f]{64}' "$LOG_FILE" | grep -v "$VPN_CERT_SHA256" | head -1)"
      bad "The VPN gateway's certificate changed, so openfortivpn refused it. Nothing was left behind" \
        "Ask the IT/infra team to confirm the new certificate. openfortivpn reports this fingerprint: ${new_pin:-see local/vpn/openfortivpn.log}" \
        "If it's genuine, put it in config/project-settings.sh (VPN_CERT_SHA256 and VPN_CERT_EXPIRES), then run /flow-vpn connect again."
      return 1
      ;;
    11)
      bad "openfortivpn stopped before the VPN came up" \
        "Look at local/vpn/openfortivpn.log for the error, then see the VPN troubleshooting table (setup guide, section 2.6)."
      return 1
      ;;
    12)
      bad "The SSO login wasn't finished within $VPN_CONNECT_TIMEOUT seconds. The VPN was stopped and cleaned up" \
        "Run /flow-vpn connect again and finish the login in the browser page that opens." \
        "If no page opens, open https://$VPN_GATEWAY:$VPN_PORT/remote/saml/start?redirect=1&realm=$VPN_REALM yourself."
      return 1
      ;;
    2)
      bad "The VPN settings were refused as invalid" \
        "Check the VPN values in config/project-settings.sh against the setup guide, section 2."
      return 1
      ;;
    *)
      password_failed
      return 1
      ;;
  esac
}

vpn_disconnect() {
  in_codex_sandbox && sandbox_stop disconnect

  if ! openfortivpn_running && [ ! -f "$VPN_RESOLVER_FILE" ]; then
    if gitlab_answers; then
      look "openfortivpn isn't running, but you're connected through another VPN client (e.g. the FortiClient app)" \
        "Disconnect it in that app."
    else
      ok "Already disconnected"
    fi
    return 0
  fi

  echo "Disconnecting the VPN: type your Mac password in the macOS dialog."
  run_admin disconnect "$VPN_RESOLVER_FILE" || { password_failed; return 1; }

  if openfortivpn_running; then
    bad "openfortivpn is still running" "Run /flow-vpn disconnect again. If it stays, run: sudo pkill -x openfortivpn"
    return 1
  fi
  if [ -f "$VPN_RESOLVER_FILE" ]; then
    bad "The VPN DNS file is still there" "Run: sudo rm -f $VPN_RESOLVER_FILE"
    return 1
  fi
  if dscacheutil -q host -a name "$VPN_GATEWAY" 2>/dev/null | grep -q ip_address; then
    ok "VPN disconnected and the VPN DNS file removed"
  else
    look "VPN disconnected, but the VPN gateway's name doesn't resolve right now" \
      "Check your internet connection before you connect again."
  fi
  return 0
}

case "${1:-}" in
  connect) vpn_connect ;;
  status) vpn_status ;;
  disconnect) vpn_disconnect ;;
  *)
    echo "Usage: bash scripts/vpn.sh connect | status | disconnect"
    exit 1
    ;;
esac
