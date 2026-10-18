#!/usr/bin/env bash
# One API call to a repo's server running on this Mac (C4, flow-verify and flow-ac-check; rules A6, A11; D20, D37, D67).
# Run it from the closio-agent folder:
#
#   bash scripts/api-call.sh <ws1 repo> login          Logs in as you on the DEV WS1 login URL (WS1_LOGIN_URL; rule A24),
#                                                    with your WS1 login from the Keychain, and keeps the session cookie it
#                                                    returns in local/sessions/<repo>/ (only for you). Calls to the WS1 on this
#                                                    Mac then carry that cookie: first under its own name, and if this WS1
#                                                    answers 401 (session not found), once more as WS1_LOCAL_SESSION_COOKIE.
#   bash scripts/api-call.sh <ws1 repo> logout         Forgets that session
#   bash scripts/api-call.sh <repo> <METHOD> <path> [options]
#       --json '<json>' | --body <json file>         the request body
#       --header 'Name: value'                       an extra header (repeatable; never put a key or password here)
#       --auth user|none                             WS1 only: logged in as you (default) or not logged in
#       --client ok|none|id-only|secret-only|unknown|wrong-secret
#                                                    WS2 only: the caller's S2S keys: WS1's own pair (saved with
#                                                    /flow-configure-repo <ws1 repo> key ws1-client-id / ws1-client-secret),
#                                                    as WS1 sends it to the WS2s; a pair saved under the WS2 repo itself
#                                                    (ws2-client-id / ws2-client-secret) is used instead, for a WS2 to which
#                                                    WS1 sends another pair (pricing engine)
#                                                    (default ok), or missing / wrong keys on purpose, for the negative ACs
#       --save <file>                                also writes "status: <code>" and the raw body to <file>
#       --env dev                                    call the repo on the dev environment (dev_base_url in its repo file,
#                                                    D72) instead of the copy running on this Mac
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
usage() { echo "Usage: bash scripts/api-call.sh <repo> login | logout | <METHOD> <path> [--json '<json>' | --body <file>] [--header 'Name: value']... [--auth user|none] [--client ok|none|id-only|secret-only|unknown|wrong-secret] [--save <file>] [--env dev]"; }
# SECURITY_BIN can be a stand-in for the build tests only (like BREW_BIN in setup-repo.sh); normally the macOS "security" tool.
keychain_get() { "${SECURITY_BIN:-security}" find-generic-password -a "$USER" -s "$1" -w 2>/dev/null; }

TMP="$(mktemp -d)"; chmod 700 "$TMP"
trap 'rm -rf "$TMP"' EXIT

[ $# -ge 2 ] || { usage; exit 2; }
REPO="$1"; ACTION="$2"; shift 2
[ -f "$(repo_file "$REPO")" ] || { bad "$REPO isn't registered" "Register it with /flow-configure-repo <path of your clone>, then run this again."; exit 1; }
SDIR="$SESSIONS_DIR/$REPO"

ws1_headers() { # the headers every WS1 call needs (architecture.md, Phase 6)
  printf '%s\n' "accept: application/json" "Content-Type: application/json" "X-Secure-Transmission-Type: x" "X-Application-Version: $WS1_APP_VERSION"
}

# The session cookies of the dev login, from curl's cookie jar (HttpOnly ones are written with a "#HttpOnly_" prefix):
# one "name<TAB>value" line each. Never printed.
jar_cookies() { [ -f "$SDIR/cookies" ] && awk -F '\t' '{ sub(/^#HttpOnly_/, "", $1) } !/^#/ && NF >= 7 { print $6 "\t" $7 }' "$SDIR/cookies"; }
# The Cookie header for the WS1 on this Mac: "as-is" = every dev cookie under its own name; "local" = the session cookie
# (express-session's signed value starts with s%3A, or the only cookie there is) under WS1_LOCAL_SESSION_COOKIE.
cookie_header() { # <as-is|local>
  local v
  if [ "$1" = "local" ]; then
    v="$(jar_cookies | awk -F '\t' '$2 ~ /^s(%3A|:)/ { print $2; exit }')"
    [ -n "$v" ] || { [ "$(jar_cookies | grep -c .)" -eq 1 ] && v="$(jar_cookies | cut -f2)"; }
    [ -n "$v" ] || return 1
    printf 'Cookie: %s=%s\n' "$WS1_LOCAL_SESSION_COOKIE" "$v"
  else
    printf 'Cookie: %s\n' "$(jar_cookies | awk -F '\t' '{ printf "%s%s=%s", (NR > 1 ? "; " : ""), $1, $2 }')"
  fi
}

do_login() {
  local uid pw code
  [ "$REPO" = "$WS1_REPO" ] || { bad "Only WS1 ($WS1_REPO) has a login" "Call $REPO directly with its S2S keys (the default --client ok)."; return 1; }
  uid="$(keychain_get "$KEYCHAIN_PREFIX.ws1-login-userid")"; pw="$(keychain_get "$KEYCHAIN_PREFIX.ws1-login-password")"
  if [ -z "$uid" ] || [ -z "$pw" ]; then bad "Your WS1 login isn't saved in the Keychain" "Run /flow-configure-user ws1-login-userid (and ws1-login-password), then run this again."; return 1; fi
  mkdir -p "$SDIR"; chmod 700 "$SDIR"; rm -f "$SDIR/cookies" "$SDIR/token" "$SDIR/cookie-mode"
  jq -n --arg u "$uid" --arg p "$pw" --argjson n "$WS1_NAPP_PK" --arg c "$WS1_CLIENT_TYPE" '{userid: $u, password: $p, napp_pk: $n, client_type: $c}' > "$TMP/login.json"
  uid=""; pw=""
  ws1_headers > "$TMP/h"
  # Every login goes to the dev WS1 (rule A24), never to the WS1 on this Mac.
  code="$(curl -s -o "$TMP/resp" -w '%{http_code}' --max-time "$API_CALL_TIMEOUT" -H @"$TMP/h" -c "$SDIR/cookies" -X POST --data-binary @"$TMP/login.json" "$WS1_LOGIN_URL" 2>/dev/null)"
  rm -f "$TMP/login.json"; chmod 600 "$SDIR/cookies" 2>/dev/null
  if [ -z "$code" ] || [ "$code" = "000" ]; then bad "The dev WS1 login didn't answer" "Connect the VPN: /flow-vpn connect (Codex: \$flow-vpn connect), then run this again."; rm -f "$SDIR/cookies"; return 1; fi
  if [ "$(jq -r '.status // empty' "$TMP/resp" 2>/dev/null)" != "success" ]; then
    bad "The dev WS1 login failed (HTTP $code: $(jq -r '.message // .error_code // "no message"' "$TMP/resp" 2>/dev/null | cut -c1-160))" "The Keychain login must be your dev WS1 login: /flow-configure-user ws1-login-userid (and ws1-login-password), then run this again."
    rm -f "$SDIR/cookies"; return 1
  fi
  if [ "$(jq -r '.data.use_otp // false' "$TMP/resp")" = "true" ] && [ -z "$(jq -r '.data.token // empty' "$TMP/resp")" ] && [ "$(jar_cookies | grep -c .)" -eq 0 ]; then
    bad "Your WS1 login asks for an OTP, which a script can't type" "Use a test login without OTP: /flow-configure-user ws1-login-userid."; rm -f "$SDIR/cookies"; return 1
  fi
  jq -r '.data.token // empty' "$TMP/resp" > "$SDIR/token"; chmod 600 "$SDIR/token"   # web logins (client_type web) have none
  [ "$(jar_cookies | grep -c .)" -gt 0 ] || [ -s "$SDIR/token" ] || { bad "The dev WS1 login answered without a session cookie or a token" "Try again; if it keeps happening, check the login on dev by hand."; return 1; }
  ok "Logged in on the dev WS1 as you; its session cookie is used on the WS1 on this Mac (kept in local/sessions/$REPO/ until: bash scripts/api-call.sh $REPO logout)"
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

AUTH="user"; CLIENT="ok"; SAVE=""; : > "$TMP/extra"; BODY=""; ENV="local"
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
    --env) [ $# -ge 2 ] || { usage; exit 2; }; case "$2" in dev|local) ENV="$2" ;; *) usage; exit 2 ;; esac; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done
if [ -n "$BODY" ] && ! jq empty "$BODY" 2>/dev/null; then bad "The body isn't valid JSON" "Fix the JSON, then run this again."; exit 2; fi
if [ "$ENV" = "dev" ]; then
  BASE="$(repo_dev_url "$REPO")"
  [ -n "$BASE" ] || { bad "$REPO has no dev address (dev_base_url in config/repos/$REPO.yaml)" "Run /flow-setup-repo $REPO dev-address (Codex: \$flow-setup-repo $REPO dev-address)."; exit 1; }
else
  repo_ready "$REPO" || { bad "$REPO_PROBLEM" "Fix that first, then run this again."; exit 1; }
  BASE="$(repo_base_url "$REPO")" || { bad "$REPO: its port isn't set in its $(env_file_of "$REPO") ($(port_var "$REPO"))" "Set it there (the value isn't shown here, rule A6), then run this again."; exit 1; }
fi

: > "$TMP/h"; chmod 600 "$TMP/h"
CURL_EXTRA=""
if [ "$REPO" = "$WS1_REPO" ]; then
  ws1_headers >> "$TMP/h"
  case "$AUTH" in
    user)
      if [ ! -f "$SDIR/cookies" ]; then login_out="$(do_login)" || { echo "$login_out"; exit 1; }; fi
      CURL_EXTRA="session" ;;
    none) ;;
    *) usage; exit 2 ;;
  esac
else
  echo "Content-Type: application/json" >> "$TMP/h"; echo "accept: application/json" >> "$TMP/h"
  id=""; secret=""
  case "$CLIENT" in
    ok|id-only|secret-only|wrong-secret)
      # The caller's pair (D37): a pair saved under this WS2 repo wins (a WS2 to which WS1 sends another pair), else WS1's own.
      id="$(keychain_get "$KEYCHAIN_PREFIX.$REPO.ws2-client-id.dev")"; secret="$(keychain_get "$KEYCHAIN_PREFIX.$REPO.ws2-client-secret.dev")"
      if [ -z "$id" ] || [ -z "$secret" ]; then
        id="$(keychain_get "$KEYCHAIN_PREFIX.$WS1_REPO.ws1-client-id.dev")"; secret="$(keychain_get "$KEYCHAIN_PREFIX.$WS1_REPO.ws1-client-secret.dev")"
      fi
      if [ -z "$id" ] || [ -z "$secret" ]; then
        bad "WS1's client ID and secret aren't saved in the Keychain (a direct WS2 call sends them, as WS1 does)" "Save WS1's own pair (the values of WS1_AUTH_CLIENT_ID and WS1_AUTH_SECRET_KEY in WS1's .env): /flow-configure-repo $WS1_REPO key ws1-client-id and /flow-configure-repo $WS1_REPO key ws1-client-secret (Codex: \$flow-configure-repo …), then run this again."; exit 1
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

call() { # [<as-is|local>]: one call to the repo on this Mac; sets code
  cp "$TMP/h" "$TMP/h2"
  if [ -n "${1:-}" ]; then
    cookie_header "$1" >> "$TMP/h2" || return 1
    [ -s "$SDIR/token" ] && printf 'Authorization: Bearer %s\n' "$(cat "$SDIR/token")" >> "$TMP/h2"
  fi
  set -- -s -o "$TMP/resp" -w '%{http_code}' --max-time "$API_CALL_TIMEOUT" -X "$METHOD" -H @"$TMP/h2"
  [ -n "$BODY" ] && set -- "$@" --data-binary @"$BODY"
  code="$(curl "$@" "$BASE$URLPATH" 2>/dev/null)"
  rm -f "$TMP/h2"
  if [ -z "$code" ] || [ "$code" = "000" ]; then
    if [ "$ENV" = "dev" ]; then bad "$REPO on dev didn't answer (no response within $API_CALL_TIMEOUT s)" "Is the VPN on (/flow-vpn status)? Is $REPO deployed and up on dev?"; exit 1; fi
    bad "$REPO didn't answer (no response within $API_CALL_TIMEOUT s)" "Is it running? bash scripts/repo-run.sh $REPO status (start it with: bash scripts/repo-run.sh $REPO start)"; exit 1
  fi
}
rejected() { [ "$code" = "401" ] && case "$(jq -r '.error_code // empty' "$TMP/resp" 2>/dev/null)" in SESSION_EXPIRED|INVALID_TOKEN|UNAUTHORIZED) true ;; *) false ;; esac; }
if [ "$CURL_EXTRA" = "session" ]; then
  # The dev session cookie on the WS1 on this Mac (rule A24): its own name first, then WS1_LOCAL_SESSION_COOKIE once;
  # the way that works is remembered. Still refused: log in on dev again once and try both ways again.
  mode="$(cat "$SDIR/cookie-mode" 2>/dev/null)"; [ "$mode" = "local" ] || mode="as-is"
  call "$mode"
  if rejected && [ "$mode" = "as-is" ]; then call local && ! rejected && echo local > "$SDIR/cookie-mode"; fi
  if rejected; then
    login_out="$(do_login)" || { echo "$login_out"; exit 1; }
    call as-is
    if rejected; then call local && ! rejected && echo local > "$SDIR/cookie-mode"; fi
  fi
  if rejected; then
    echo "   ⚠️ The WS1 on this Mac refused the dev session (tried the cookie's own name and $WS1_LOCAL_SESSION_COOKIE, after a fresh dev login)."
    echo "   Tip: it can only read sessions kept where the dev WS1 keeps them; check its session settings with the user (values aren't read here, rule A6)."
  fi
else
  call
fi
echo "HTTP $code"
if jq . "$TMP/resp" > "$TMP/pretty" 2>/dev/null; then out="$TMP/pretty"; else out="$TMP/resp"; fi
head -c 6000 "$out"; echo
[ "$(wc -c < "$out")" -gt 6000 ] && echo "… (cut after 6000 characters)"
if [ -n "$SAVE" ]; then { echo "status: $code"; cat "$TMP/resp"; } > "$SAVE"; fi
exit 0
