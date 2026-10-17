#!/usr/bin/env bash
# One API call to a repo's server running on this Mac (C4, flow-verify and flow-ac-check; rules A6, A11; D20, D37, D67).
# Run it from the closio-agent folder:
#
#   bash scripts/api-call.sh <ws1 repo> login          Logs in to WS1 as you (your WS1 login from the Keychain) and keeps
#                                                    the session in local/sessions/<repo>/ (cookie + token, only for you)
#   bash scripts/api-call.sh <ws1 repo> logout         Forgets that session
#   bash scripts/api-call.sh <repo> <METHOD> <path> [options]
#       --json '<json>' | --body <json file>         the request body
#       --header 'Name: value'                       an extra header (repeatable; never put a key or password here)
#       --auth user|none                             WS1 only: logged in as you (default) or not logged in
#       --client ok|none|id-only|secret-only|unknown|wrong-secret
#                                                    WS2 only: the S2S keys saved with /flow-configure-repo <repo> key …
#                                                    (default ok), or missing / wrong keys on purpose, for the negative ACs
#       --save <file>                                also writes "status: <code>" and the raw body to <file>
#
# The keys, the password and the session are added by this script and never printed or put on a command line.
# Prints "HTTP <code>" and the response body (pretty when JSON, cut after 6000 characters).
# Exit codes: 0 the call got an answer (any HTTP status) · 1 ❌ (no answer, missing key, login failed) · 2 wrong usage.
# Works in the Mac's own bash 3.2; needs curl and jq.

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
. "$AGENT_ROOT/scripts/lib/repo-info.sh"
SESSIONS_DIR="${SESSIONS_DIR:-$AGENT_ROOT/local/sessions}"

bad() { echo "❌ $1"; echo "   Fix: $2"; }
ok() { echo "✅ $1"; }
usage() { echo "Usage: bash scripts/api-call.sh <repo> login | logout | <METHOD> <path> [--json '<json>' | --body <file>] [--header 'Name: value']... [--auth user|none] [--client ok|none|id-only|secret-only|unknown|wrong-secret] [--save <file>]"; }
# SECURITY_BIN can be a stand-in for the build tests only (like BREW_BIN in setup-repo.sh); normally the macOS "security" tool.
keychain_get() { "${SECURITY_BIN:-security}" find-generic-password -a "$USER" -s "$1" -w 2>/dev/null; }

TMP="$(mktemp -d)"; chmod 700 "$TMP"
trap 'rm -rf "$TMP"' EXIT

[ $# -ge 2 ] || { usage; exit 2; }
REPO="$1"; ACTION="$2"; shift 2
repo_ready "$REPO" || { bad "$REPO_PROBLEM" "Fix that first, then run this again."; exit 1; }
BASE="$(repo_base_url "$REPO")" || { bad "$REPO: its port isn't set in its $(env_file_of "$REPO") ($(port_var "$REPO"))" "Set it there (the value isn't shown here, rule A6), then run this again."; exit 1; }
SDIR="$SESSIONS_DIR/$REPO"

ws1_headers() { # the headers every WS1 call needs (architecture.md, Phase 6)
  printf '%s\n' "accept: application/json" "Content-Type: application/json" "X-Secure-Transmission-Type: x" "X-Application-Version: $WS1_APP_VERSION"
}

do_login() {
  local uid pw body code
  [ "$REPO" = "$WS1_REPO" ] || { bad "Only WS1 ($WS1_REPO) has a login" "Call $REPO directly with its S2S keys (the default --client ok)."; return 1; }
  uid="$(keychain_get "$KEYCHAIN_PREFIX.ws1-login-userid")"; pw="$(keychain_get "$KEYCHAIN_PREFIX.ws1-login-password")"
  if [ -z "$uid" ] || [ -z "$pw" ]; then bad "Your WS1 login isn't saved in the Keychain" "Run /flow-configure-user ws1-login-userid (and ws1-login-password), then run this again."; return 1; fi
  mkdir -p "$SDIR"; chmod 700 "$SDIR"; rm -f "$SDIR/cookies" "$SDIR/token"
  jq -n --arg u "$uid" --arg p "$pw" --argjson n "$WS1_NAPP_PK" --arg c "$WS1_CLIENT_TYPE" '{userid: $u, password: $p, napp_pk: $n, client_type: $c}' > "$TMP/login.json"
  ws1_headers > "$TMP/h"
  code="$(curl -s -o "$TMP/resp" -w '%{http_code}' --max-time "$API_CALL_TIMEOUT" -H @"$TMP/h" -c "$SDIR/cookies" -X POST --data-binary @"$TMP/login.json" "$BASE/api/v1/login" 2>/dev/null)"
  rm -f "$TMP/login.json"; chmod 600 "$SDIR/cookies" 2>/dev/null
  if [ -z "$code" ] || [ "$code" = "000" ]; then bad "WS1 ($REPO) didn't answer on this Mac" "Start it: bash scripts/repo-run.sh $REPO start, then run this again."; return 1; fi
  if [ "$(jq -r '.status // empty' "$TMP/resp" 2>/dev/null)" != "success" ]; then
    bad "WS1 login failed (HTTP $code: $(jq -r '.message // .error_code // "no message"' "$TMP/resp" 2>/dev/null | cut -c1-160))" "Check your WS1 login with /flow-configure-user ws1-login-userid (and ws1-login-password), and that WS1's own login services answer (VPN for the dev services: /flow-vpn connect)."
    rm -f "$SDIR/cookies"; return 1
  fi
  if [ "$(jq -r '.data.use_otp // false' "$TMP/resp")" = "true" ] && [ -z "$(jq -r '.data.token // empty' "$TMP/resp")" ]; then
    bad "Your WS1 login asks for an OTP, which a script can't type" "Use a test login without OTP: /flow-configure-user ws1-login-userid."; rm -f "$SDIR/cookies"; return 1
  fi
  jq -r '.data.token // empty' "$TMP/resp" > "$SDIR/token"; chmod 600 "$SDIR/token"
  [ -s "$SDIR/token" ] || { bad "WS1 answered the login without a token" "Read WS1's log: local/logs/server-$REPO.log"; return 1; }
  ok "Logged in to WS1 as you (the session stays in local/sessions/$REPO/ until: bash scripts/api-call.sh $REPO logout)"
}

case "$ACTION" in
  login) do_login; exit $? ;;
  logout) rm -rf "$SDIR"; ok "Forgot the WS1 session for $REPO"; exit 0 ;;
esac

METHOD="$(printf '%s' "$ACTION" | tr '[:lower:]' '[:upper:]')"
case "$METHOD" in GET|POST|PUT|PATCH|DELETE) ;; *) usage; exit 2 ;; esac
[ $# -ge 1 ] || { usage; exit 2; }
URLPATH="$1"; shift
case "$URLPATH" in /*) ;; *) bad "The path must start with /" "e.g. /api/incentives/v1/…"; exit 2 ;; esac

AUTH="user"; CLIENT="ok"; SAVE=""; : > "$TMP/extra"; BODY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --json) [ $# -ge 2 ] || { usage; exit 2; }; printf '%s' "$2" > "$TMP/body"; BODY="$TMP/body"; shift 2 ;;
    --body) [ $# -ge 2 ] && [ -f "$2" ] || { bad "No body file '${2:-}'" "Give the path of a JSON file."; exit 2; }; BODY="$2"; shift 2 ;;
    --header) [ $# -ge 2 ] || { usage; exit 2; }
      case "$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')" in
        x-client-secret:*|x-client-id:*|authorization:*|cookie:*) bad "Keys, tokens and cookies are added by the script, never typed" "Use --client or --auth instead."; exit 2 ;;
      esac
      printf '%s\n' "$2" >> "$TMP/extra"; shift 2 ;;
    --auth) [ $# -ge 2 ] || { usage; exit 2; }; AUTH="$2"; shift 2 ;;
    --client) [ $# -ge 2 ] || { usage; exit 2; }; CLIENT="$2"; shift 2 ;;
    --save) [ $# -ge 2 ] || { usage; exit 2; }; SAVE="$2"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done
if [ -n "$BODY" ] && ! jq empty "$BODY" 2>/dev/null; then bad "The body isn't valid JSON" "Fix the JSON, then run this again."; exit 2; fi

: > "$TMP/h"; chmod 600 "$TMP/h"
CURL_EXTRA=""
if [ "$REPO" = "$WS1_REPO" ]; then
  ws1_headers >> "$TMP/h"
  case "$AUTH" in
    user)
      if [ ! -s "$SDIR/token" ] || [ ! -f "$SDIR/cookies" ]; then login_out="$(do_login)" || { echo "$login_out"; exit 1; }; fi
      printf 'Authorization: Bearer %s\n' "$(cat "$SDIR/token")" >> "$TMP/h"; CURL_EXTRA="cookies" ;;
    none) ;;
    *) usage; exit 2 ;;
  esac
else
  echo "Content-Type: application/json" >> "$TMP/h"; echo "accept: application/json" >> "$TMP/h"
  id=""; secret=""
  case "$CLIENT" in
    ok|id-only|secret-only|wrong-secret)
      id="$(keychain_get "$KEYCHAIN_PREFIX.$REPO.ws2-client-id.dev")"; secret="$(keychain_get "$KEYCHAIN_PREFIX.$REPO.ws2-client-secret.dev")"
      if [ -z "$id" ] || [ -z "$secret" ]; then
        bad "$REPO's S2S keys aren't saved in the Keychain" "Run /flow-configure-repo $REPO key ws2-client-id and /flow-configure-repo $REPO key ws2-client-secret (Codex: \$flow-configure-repo …), then run this again."; exit 1
      fi ;;
    none|unknown) ;;
    *) usage; exit 2 ;;
  esac
  case "$CLIENT" in
    ok) printf 'x-client-id: %s\nx-client-secret: %s\n' "$id" "$secret" >> "$TMP/h" ;;
    id-only) printf 'x-client-id: %s\n' "$id" >> "$TMP/h" ;;
    secret-only) printf 'x-client-secret: %s\n' "$secret" >> "$TMP/h" ;;
    unknown) printf 'x-client-id: closio-agent-unknown-client\nx-client-secret: not-a-real-secret\n' >> "$TMP/h" ;;
    wrong-secret) printf 'x-client-id: %s\nx-client-secret: not-the-right-secret-%s\n' "$id" "$$" >> "$TMP/h" ;;
  esac
  id=""; secret=""
fi
cat "$TMP/extra" >> "$TMP/h"

set -- -s -o "$TMP/resp" -w '%{http_code}' --max-time "$API_CALL_TIMEOUT" -X "$METHOD" -H @"$TMP/h"
[ "$CURL_EXTRA" = "cookies" ] && set -- "$@" -b "$SDIR/cookies" -c "$SDIR/cookies"
[ -n "$BODY" ] && set -- "$@" --data-binary @"$BODY"
code="$(curl "$@" "$BASE$URLPATH" 2>/dev/null)"
if [ -z "$code" ] || [ "$code" = "000" ]; then
  bad "$REPO didn't answer (no response within $API_CALL_TIMEOUT s)" "Is it running? bash scripts/repo-run.sh $REPO status (start it with: bash scripts/repo-run.sh $REPO start)"; exit 1
fi
if [ "$REPO" = "$WS1_REPO" ] && [ "$AUTH" = "user" ] && [ "$code" = "401" ] && [ "$(jq -r '.error_code // empty' "$TMP/resp" 2>/dev/null)" = "INVALID_TOKEN" ]; then
  echo "   (the WS1 session had expired; log in again and run the call once more: bash scripts/api-call.sh $REPO login)"
fi
echo "HTTP $code"
if jq . "$TMP/resp" > "$TMP/pretty" 2>/dev/null; then out="$TMP/pretty"; else out="$TMP/resp"; fi
head -c 6000 "$out"; echo
[ "$(wc -c < "$out")" -gt 6000 ] && echo "… (cut after 6000 characters)"
if [ -n "$SAVE" ]; then { echo "status: $code"; cat "$TMP/resp"; } > "$SAVE"; fi
exit 0
