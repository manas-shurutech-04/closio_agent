#!/usr/bin/env bash
# macOS password dialog used by 'sudo -A' for the VPN steps (D30).
# The password goes straight to sudo. It is never saved, logged or shown to the AI.
# Cancel = no password, so sudo stops and nothing changes.
# OSASCRIPT_BIN can be a stand-in for the build tests only (like setup-repo.sh); normally the macOS osascript.
OSASCRIPT_BIN="${OSASCRIPT_BIN:-/usr/bin/osascript}"

"$OSASCRIPT_BIN" \
  -e 'display dialog "closio-agent needs your Mac password to change the VPN connection." with title "closio-agent" default answer "" with hidden answer buttons {"Cancel", "OK"} default button "OK" with icon caution' \
  -e 'text returned of result' 2>/dev/null
