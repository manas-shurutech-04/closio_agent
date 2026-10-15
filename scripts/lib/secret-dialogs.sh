#!/usr/bin/env bash
# Shared by scripts/configure-user.sh and scripts/configure-repo.sh (F4, F5). Load with:
#   . "$AGENT_ROOT/scripts/lib/secret-dialogs.sh"
# The caller must define ok(), look() and bad() first.
#
# Secrets are typed into a hidden macOS box and go straight into the Keychain (D15, D33).
# A value never appears in the AI chat, a file, or on a command line.

# Is this Keychain item stored? (checks the name only, never reads the value)
keychain_has() { security find-generic-password -a "$USER" -s "$1" >/dev/null 2>&1; }

# Reads one value from stdin and stores it under <service>. 'security' asks for the value twice
# when -w comes last, so it is sent twice. Returns 0 stored, 3 nothing entered, 1 failed.
store_secret_from_stdin() { # <service> <label> <hint for redoing it>
  local service="$1" label="$2" hint="$3" value
  IFS= read -r value || true
  if [ -z "$value" ]; then
    look "Nothing entered, so $service was not changed"
    return 3
  fi
  printf '%s\n%s\n' "$value" "$value" |
    security add-generic-password -U -a "$USER" -s "$service" -l "$label" -w >/dev/null 2>&1
  value=""
  if keychain_has "$service"; then
    ok "$service stored in the Keychain"
    return 0
  fi
  bad "Couldn't store $service in the Keychain" \
    "Run $hint again. If it keeps failing, use the terminal command in the setup guide, section 5.1."
  return 1
}

# 1. Heads-up, so the user can copy the value first. 2. Hidden input box. 3. Straight into the Keychain.
# Returns 0 stored, 3 skipped or cancelled, 1 failed.
ask_secret_dialog() { # <service> <label> <description> <hint for redoing it>
  local service="$1" label="$2" desc="$3" hint="$4" button value rc
  button="$(/usr/bin/osascript \
    -e "display dialog \"Next: $desc.\" & return & return & \"Copy it now, then click Continue.\" with title \"closio-agent setup\" buttons {\"Skip\", \"Continue\"} default button \"Continue\"" \
    -e 'button returned of result' 2>/dev/null)"
  if [ "$button" != "Continue" ]; then
    look "Skipped $service" "Add it later with: $hint"
    return 3
  fi
  value="$(/usr/bin/osascript \
    -e "display dialog \"Paste $desc here:\" with title \"closio-agent setup\" default answer \"\" with hidden answer buttons {\"Cancel\", \"Save\"} default button \"Save\"" \
    -e 'text returned of result' 2>/dev/null)"
  if [ $? -ne 0 ]; then
    value=""
    look "Cancelled, so $service was not changed" "Add it later with: $hint"
    return 3
  fi
  printf '%s\n' "$value" | store_secret_from_stdin "$service" "$label" "$hint"
  rc=$?
  value=""
  return "$rc"
}
