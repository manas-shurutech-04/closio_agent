#!/usr/bin/env bash
# The builder's doc-check hook (D89, build rule R19, AGENTS.md rule 28): only for the builder of closio-agent, never in a
# card session. Wired as an end-of-reply (Stop) hook in .claude/settings.json (Claude Code) and .codex/hooks.json (Codex),
# next to the auto-save hook; both tools send the same JSON on stdin (session_id, stop_hook_active).
#
# It does something only when all three are true, else it ends at once and prints nothing:
#   1. this Mac is the builder's: the marker file local/builder exists (git-ignored, never pushed; made once, by hand);
#   2. the session isn't a card session: the card-rules hook has no note for it in local/card-sessions/ (it writes one as
#      soon as a prompt is about a card: a card command or a card key), so a card session never runs it;
#   3. closio-agent's own files have uncommitted changes (anything but runs/ and local/).
# Then it checks what the full doc sweep (rule R15) and the command rule (R17) ask for and a script can see:
#   - a build change (scripts/, .agents/, config/, rulesets/, AGENTS.md, .claude/, .codex/, e2e/) → docs/changelog.md changed;
#   - any change → build-memory/history.md changed;
#   - the newest decision in docs/design-decisions.md has its line in build-memory/decisions.md (and the other way);
#   - AGENTS.md changed → docs/agent-rules.md and build-memory/project-context.md changed;
#   - the agent rules: "A1–A<n>" and the build rules: "R1–R<n>" say the newest number everywhere;
#   - a command (.agents/skills/flow-*/SKILL.md) changed → docs/commands.md and docs/user-guide.md changed;
#     and bash scripts/help.sh check has no ❌;
#   - docs/user-guide.md changed → its "mirrored on" date is today (the Claude artifact was updated too);
#   - a new script → in docs/commands.md's helper scripts and pre-approved in both tools (a hook: set in both hook files);
#   - a build change and no rule file changed → a reminder to check each rule file (R15 step 6).
# Something missing: it holds the AI back once ({"decision":"block","reason":…}), so the AI updates it in the same reply.
# Never twice in one reply (stop_hook_active), and the same list is never repeated in a session (local/build-sweep/).
# It never reads .env values or secrets (A6) and always exits 0.
#
# Test it: echo '{"session_id":"test"}' | bash scripts/build-sweep-hook.sh
# Works in the Mac's own bash 3.2.

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BUILDER_MARKER="${BUILDER_MARKER:-$AGENT_ROOT/local/builder}"
SESSIONS_DIR="${CARD_SESSIONS_DIR:-$AGENT_ROOT/local/card-sessions}"
STATE_DIR="${BUILD_SWEEP_DIR:-$AGENT_ROOT/local/build-sweep}"
TODAY="${BUILD_SWEEP_TODAY:-$(date +%Y-%m-%d)}"

[ -f "$BUILDER_MARKER" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
input="$(cat)"
session="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null | tr -cd 'A-Za-z0-9._-')"
[ -n "$session" ] || exit 0
[ -f "$SESSIONS_DIR/$session" ] && exit 0                    # a card session: never
[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && exit 0

cd "$AGENT_ROOT" 2>/dev/null || exit 0
changed="$({ git diff --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } |
  grep -v -E '^(runs|local)/' | sort -u)"
[ -n "$changed" ] || exit 0
added="$(git ls-files --others --exclude-standard 2>/dev/null)"

has() { printf '%s\n' "$changed" | grep -q -E "$1"; }
missing=""
miss() { missing="$missing
- $1"; }

BUILD='^(scripts/|\.agents/|config/|rulesets/|AGENTS\.md$|\.claude/|\.codex/|e2e/)'
if has "$BUILD"; then
  has '^docs/changelog\.md$' || miss "docs/changelog.md: no entry for this change yet."
fi
has '^build-memory/history\.md$' || miss "build-memory/history.md: no row for this step yet (rule R10)."

d_doc="$(grep -o -E '^### D[0-9]+ ' docs/design-decisions.md 2>/dev/null | tr -dc '0-9\n' | sort -n | tail -1)"
d_mem="$(grep -o -E '^- \*\*D[0-9]+:\*\*' build-memory/decisions.md 2>/dev/null | tr -dc '0-9\n' | sort -n | tail -1)"
[ "$d_doc" = "$d_mem" ] || miss "Decisions: the newest in docs/design-decisions.md is D${d_doc:-?}, in build-memory/decisions.md D${d_mem:-?} (one line per decision, rule R11)."

if has '^AGENTS\.md$'; then
  has '^docs/agent-rules\.md$' || miss "AGENTS.md changed, docs/agent-rules.md didn't (the team copy of the agent rules)."
  has '^build-memory/project-context\.md$' || miss "AGENTS.md changed, build-memory/project-context.md didn't (the build copy of the agent rules)."
fi
count_check() { # <letter> <newest number>: every "<L>1–<L><n>" in the docs says <newest>
  local l="$1" n="$2" stale
  [ -n "$n" ] || return 0
  stale="$(git grep -l -E "${l}1–${l}[0-9]+" -- '*.md' 2>/dev/null |
    grep -v -E '^(docs/changelog\.md|docs/design-decisions\.md|build-memory/history\.md|build-memory/full-chat-transcript\.md|runs/)' |
    while IFS= read -r f; do grep -o -E "${l}1–${l}[0-9]+" "$f" | grep -v -x "${l}1–${l}$n" >/dev/null && printf '%s ' "$f"; done)"
  [ -z "$stale" ] || miss "\"${l}1–${l}…\" isn't ${l}1–${l}$n in: ${stale% } (the newest rule is ${l}$n)."
}
count_check A "$(grep -o -E '^\| A[0-9]+ \|' docs/agent-rules.md 2>/dev/null | tr -dc '0-9\n' | sort -n | tail -1)"
count_check R "$(grep -o -E '^\| R[0-9]+ \|' build-memory/rules.md 2>/dev/null | tr -dc '0-9\n' | sort -n | tail -1)"

if has '^\.agents/skills/flow-[a-z-]+/SKILL\.md$'; then
  has '^docs/commands\.md$' || miss "A command changed, docs/commands.md didn't (its section, rule R17)."
  has '^docs/user-guide\.md$' || miss "A command changed, docs/user-guide.md didn't (its step or row, and then the Claude artifact, rule R17)."
fi
if has "$BUILD"; then
  help="$(bash scripts/help.sh check 2>&1 | grep -E '^❌' | sed 's/^❌ //')"
  [ -z "$help" ] || miss "bash scripts/help.sh check: $(printf '%s' "$help" | tr '\n' ';' | sed 's/;$//; s/;/; /g')."
fi
if has '^docs/user-guide\.md$'; then
  mirrored="$(grep -o -E 'mirrored on [0-9]{4}-[0-9]{2}-[0-9]{2}' docs/user-guide.md 2>/dev/null | head -1 | cut -c13-)"
  [ "$mirrored" = "$TODAY" ] || miss "docs/user-guide.md changed but says \"mirrored on ${mirrored:-?}\": update its Claude artifact the same way, then set the date to $TODAY and every command (rule R17)."
fi

for f in $(printf '%s\n' "$added" | grep -E '^scripts/[^/]+\.sh$' | grep -v -x 'scripts/build-sweep-hook.sh'); do
  name="${f#scripts/}"
  grep -q -F "\`$name" docs/commands.md 2>/dev/null || miss "New script $name: not in docs/commands.md's helper scripts."
  case "$name" in
    *-hook.sh)
      grep -q -F "scripts/$name" .claude/settings.json 2>/dev/null && grep -q -F "scripts/$name" .codex/hooks.json 2>/dev/null ||
        miss "New hook $name: not set in both .claude/settings.json and .codex/hooks.json." ;;
    *)
      grep -q -F "scripts/$name" .claude/settings.json 2>/dev/null && grep -q -F "scripts/$name" .codex/rules/closio-agent.rules 2>/dev/null ||
        miss "New script $name: not pre-approved in both .claude/settings.json and .codex/rules/closio-agent.rules (if a command runs it)." ;;
  esac
done

RULE_FILES='^(rulesets/|AGENTS\.md$|docs/agent-rules\.md$|build-memory/project-context\.md$|build-memory/rules\.md$|\.claude/settings\.json$|\.codex/rules/closio-agent\.rules$)'
if has "$BUILD" && ! has "$RULE_FILES"; then
  miss "No rule file changed: go through rulesets/, AGENTS.md, docs/agent-rules.md, build-memory/project-context.md, build-memory/rules.md and the two pre-approval files, and say in your reply which you checked (rule R15, step 6)."
fi

[ -n "$missing" ] || exit 0
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
seen="$(printf '%s' "$missing" | shasum -a 256 | cut -d' ' -f1)"
[ "$(cat "$STATE_DIR/$session" 2>/dev/null)" = "$seen" ] && exit 0   # the same list again: said once already
printf '%s\n' "$seen" > "$STATE_DIR/$session" 2>/dev/null
find "$STATE_DIR" -type f -mtime +7 -delete 2>/dev/null

reason="The builder's doc check (closio-agent, the builder's Mac only, never in a card session) found these updates missing. Before you finish this reply, make each one (or say why it isn't needed), then say in your reply which files you updated:$missing"
jq -n --arg r "$reason" '{decision: "block", reason: $r}' 2>/dev/null
exit 0
