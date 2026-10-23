#!/bin/bash
# The fake macOS Keychain (D92): what the "security" stand-in does. One file per item in $FAKE_KEYCHAIN, named by its
# service; never the real Keychain. find-generic-password (-w prints the value) · add-generic-password (-w <value>, or
# -w last: the value read from stdin, as the real one asks for it) · delete-generic-password. Not found: exit 44.
cmd="${1:-}"; shift
service=""; value=""; wflag=no
while [ $# -gt 0 ]; do
  case "$1" in
    -s) service="$2"; shift 2 ;;
    -w) wflag=yes; if [ $# -ge 2 ] && [ "${2#-}" = "$2" ]; then value="$2"; shift 2; else shift; fi ;;
    -a|-l|-c|-C|-D|-j|-T) shift 2 ;;
    *) shift ;;
  esac
done
dir="${FAKE_KEYCHAIN:?FAKE_KEYCHAIN is not set}"
case "$cmd" in
  find-generic-password)
    [ -f "$dir/$service" ] || { echo "security: SecKeychainSearchCopyNext: The specified item could not be found in the keychain." >&2; exit 44; }
    if [ "$wflag" = yes ]; then cat "$dir/$service"; echo; else echo "keychain: \"login.keychain-db\""; echo "    \"svce\"<blob>=\"$service\""; fi ;;
  add-generic-password)
    if [ "$wflag" = yes ] && [ -z "$value" ]; then IFS= read -r value || true; fi
    [ -n "$value" ] || { echo "security: no password given" >&2; exit 1; }
    printf '%s' "$value" > "$dir/$service" ;;
  delete-generic-password)
    [ -f "$dir/$service" ] || exit 44
    rm -f "$dir/$service" ;;
  *) exit 0 ;;
esac
