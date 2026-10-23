#!/usr/bin/env bash
# The card-rules hook (D86, rule A29): adds rulesets/card-rules.md to every prompt about a card, in Claude Code and Codex.
# Wired as a UserPromptSubmit hook in .claude/settings.json (Claude Code) and .codex/hooks.json (Codex); both send the
# same JSON on stdin (prompt, session_id) and read the same answer (hookSpecificOutput.additionalContext).
#
# A prompt is about a card when:
#   - it's a card command: /flow-start, /flow-develop, /flow-verify, /flow-ac-check, /flow-push, /flow-review,
#     /flow-finish, /flow-qa, or /flow-grill with a card key ($flow-… in Codex); /flow-status alone only reads;
#   - it names a card key (SCRUM-567, any case);
#   - an earlier prompt in the same session was about a card (decisions are made in replies like "yes"):
#     the session is remembered in local/card-sessions/<session> (git-ignored; entries older than 7 days are removed),
#     with the card keys it named ("key SCRUM-567") and its last command ("last /flow-develop", or "last a reply"):
#     what the auto-save hook (scripts/card-autosave-hook.sh, D87) saves at the end of each reply, and its message.
# When Codex runs it (only Codex sends a turn_id), it leaves local/card-sessions/codex-ran with the hash of
# .codex/hooks.json: flow-doctor's sign that the user has trusted that hook file in Codex (D86).
# Otherwise it prints nothing. It never blocks a prompt and never reads .env values or secrets (A6): on any problem
# it prints nothing and exits 0, so the prompt goes on as typed.
#
# Test it: echo '{"prompt":"/flow-develop SCRUM-567","session_id":"test"}' | bash scripts/card-rules-hook.sh
# Works in the Mac's own bash 3.2.

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh" 2>/dev/null || exit 0
RULES_FILE="${CARD_RULES_FILE:-$AGENT_ROOT/rulesets/card-rules.md}"
SESSIONS_DIR="${CARD_SESSIONS_DIR:-$AGENT_ROOT/local/card-sessions}"

command -v jq >/dev/null 2>&1 || exit 0
[ -f "$RULES_FILE" ] || exit 0

input="$(cat)"
field() { printf '%s' "$input" | jq -r --arg f "$1" '.[$f] // empty' 2>/dev/null; }
prompt="$(field prompt)"
session="$(field session_id | tr -cd 'A-Za-z0-9._-')"
event="$(field hook_event_name)"; event="${event:-UserPromptSubmit}"
CODEX_RAN="$SESSIONS_DIR/codex-ran"
if [ -n "$(field turn_id)" ]; then   # Codex runs it, so the user has trusted it there
  mkdir -p "$SESSIONS_DIR" 2>/dev/null &&
    shasum -a 256 "$AGENT_ROOT/.codex/hooks.json" 2>/dev/null | cut -d' ' -f1 > "$CODEX_RAN" 2>/dev/null
fi

KEY_RE="${JIRA_PROJECT_KEY:-SCRUM}-[0-9]+"
CARD_COMMAND='^[[:space:]]*[/$]flow-(start|develop|verify|ac-check|push|review|finish|qa)([[:space:]]|$)'
GRILL_CARD="^[[:space:]]*[/\$]flow-grill[[:space:]]+$KEY_RE"
STATUS='^[[:space:]]*[/$]flow-status([[:space:]]|$)'

about_card=no
if printf '%s' "$prompt" | grep -q -E "$CARD_COMMAND"; then about_card=yes
elif printf '%s' "$prompt" | grep -q -i -E "$GRILL_CARD"; then about_card=yes
elif ! printf '%s' "$prompt" | grep -q -E "$STATUS" &&
     printf '%s' "$prompt" | grep -q -i -E "(^|[^A-Za-z0-9])$KEY_RE([^0-9]|$)"; then about_card=yes
fi

marker=""
[ -n "$session" ] && marker="$SESSIONS_DIR/$session"
[ "$about_card" = no ] && [ -n "$marker" ] && [ -f "$marker" ] && about_card=yes   # a later prompt in a card session
[ "$about_card" = yes ] || exit 0

# Remember the session's cards and this prompt's command, for the auto-save at the end of the reply (D87).
if [ -n "$marker" ] && mkdir -p "$SESSIONS_DIR" 2>/dev/null; then
  command_typed="$(printf '%s' "$prompt" | grep -o -E '^[[:space:]]*[/$]flow-[a-z-]+' | head -n 1 | tr -d '[:space:]' | sed 's/^\$/\//')"
  { { grep '^key ' "$marker" 2>/dev/null | cut -c5-
      printf '%s\n' "$prompt" | grep -o -i -E "$KEY_RE" | tr '[:lower:]' '[:upper:]'
    } | grep -E "^$KEY_RE\$" | sort -u | sed 's/^/key /'
    echo "last ${command_typed:-a reply}"
  } > "$marker.tmp" 2>/dev/null && mv "$marker.tmp" "$marker" 2>/dev/null
  find "$SESSIONS_DIR" -type f -mtime +7 ! -name codex-ran -delete 2>/dev/null
fi

context="closio-agent's card rules (rulesets/card-rules.md, added by the card-rules hook): follow them in this turn.

$(cat "$RULES_FILE")"
jq -n --arg event "$event" --arg context "$context" \
  '{hookSpecificOutput: {hookEventName: $event, additionalContext: $context}}' 2>/dev/null
exit 0
