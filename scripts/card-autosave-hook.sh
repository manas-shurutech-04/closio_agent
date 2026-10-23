#!/usr/bin/env bash
# The auto-save hook (D87, rule A30): at the end of every AI reply in a session working on a card, it commits and pushes
# the card's folder (runs/<KEY>/) to the card's own branch runs/<KEY> on GitHub, when the folder changed or a save isn't
# pushed yet: `bash scripts/run.sh save <KEY> "auto-saved after /flow-develop"` (or "auto-saved after a reply").
# Wired as a Stop hook in .claude/settings.json (Claude Code) and .codex/hooks.json (Codex); both send the session id
# on stdin. The session's cards and its last command come from the card-rules hook's note, local/card-sessions/<session>
# (scripts/card-rules-hook.sh); a session that named no card key (plain words) saves every card folder on this Mac.
#
# Only the card's own branch: never main, never a code repo, never a forced push (a teammate's newer save is left for
# the user, as run.sh save says). Never blocks: it always exits 0; a save that fails shows one warning line with its
# fix (systemMessage), and the next reply tries again. Never reads .env values or secrets (A6).
#
# Test it: echo '{"session_id":"test"}' | bash scripts/card-autosave-hook.sh
# Works in the Mac's own bash 3.2.

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh" 2>/dev/null || exit 0
SESSIONS_DIR="${CARD_SESSIONS_DIR:-$AGENT_ROOT/local/card-sessions}"
RUNS_DIR="${RUNS_DIR:-$AGENT_ROOT/runs}"
KEY_RE="${JIRA_PROJECT_KEY:-SCRUM}-[0-9]+"

command -v jq >/dev/null 2>&1 || exit 0
session="$(jq -r '.session_id // empty' 2>/dev/null | tr -cd 'A-Za-z0-9._-')"
[ -n "$session" ] || exit 0
marker="$SESSIONS_DIR/$session"
[ -f "$marker" ] || exit 0   # this session isn't working on a card

last="$(grep -m 1 '^last ' "$marker" | cut -c6-)"; last="${last:-a reply}"
keys="$(grep '^key ' "$marker" | cut -c5-)"
[ -n "$keys" ] || keys="$(ls "$RUNS_DIR" 2>/dev/null | grep -E "^$KEY_RE\$")"

warnings=""
for key in $keys; do
  bash "$AGENT_ROOT/scripts/run.sh" unsaved "$key" >/dev/null 2>&1 || continue   # nothing new, or no branch here
  out="$(bash "$AGENT_ROOT/scripts/run.sh" save "$key" "auto-saved after $last" 2>&1)" && continue
  problem="$(printf '%s\n' "$out" | grep -m 1 '^❌ ' | sed 's/^❌ //')"
  fix="$(printf '%s\n' "$out" | grep -m 1 '^   Fix: ' | sed 's/^   Fix: //')"
  warnings="${warnings:+$warnings
}⚠️ Auto-save of $key's folder: ${problem:-the save failed}.${fix:+ Fix: $fix} It tries again after your next reply."
done

[ -n "$warnings" ] && jq -n --arg m "$warnings" '{systemMessage: $m}' 2>/dev/null
exit 0
