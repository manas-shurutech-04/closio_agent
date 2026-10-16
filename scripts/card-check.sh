#!/usr/bin/env bash
# Checks a Jira card's text against the team's card template (F7, D58; docs/jira-card-template.md).
# Run it from the closio-agent folder:  bash scripts/card-check.sh <card file>
# The file holds the card's description as markdown. The flow-check-card command saves a Jira card to
# local/cards/<CARD-KEY>.md first; a card that isn't in Jira yet can be any .md file.
# Prints one line per finding:
#   ❌ not ready (the agent's pick-up stops and waits; with the fix, rule A11)   ⚠️ worth a look   ✅ fine
# Exit codes: 0 = no ❌, 1 = at least one ❌, 2 = wrong usage or the file can't be read.
# Only reads the file. It never prints a line that looks like a secret.
# It checks what a script can check reliably (template section 10). Alignment with the code, the WS1 rules,
# ACs inside the card's scope, real boundary values and every AC covered by a QA step stay with the AI (Phase 2).

set -u

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$AGENT_ROOT/config/project-settings.sh"
TEMPLATE="docs/jira-card-template.md"

to_fix=0
to_look=0

pass() { echo "✅ $1"; }
warn() {
  echo "⚠️ $1"
  [ -n "${2:-}" ] && echo "   Tip: $2"
  to_look=$((to_look + 1))
}
fail() {
  echo "❌ $1"
  echo "   Fix: $2"
  to_fix=$((to_fix + 1))
}
usage() {
  echo "Usage: bash scripts/card-check.sh <card file>"
  echo "  <card file>: the card's description as markdown, e.g. local/cards/SCRUM-567.md (saved by /flow-check-card)"
  echo "  or any .md file with a card that isn't in Jira yet."
}

# ---------------------------------------------------------------- input
if [ $# -ne 1 ] || [ -z "$1" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then usage; exit 2; fi
FILE="$1"
if [ ! -f "$FILE" ]; then
  fail "Can't find the card file: $FILE" "Give the path of a .md file with the card's text, e.g. local/cards/SCRUM-567.md (/flow-check-card SCRUM-567 saves it there)."
  exit 2
fi
if [ ! -r "$FILE" ]; then
  fail "Can't read the card file: $FILE" "Check the file's permissions."
  exit 2
fi

# Read the file once. Lines are kept in two arrays: as written, and lowercased (for case-insensitive checks).
# Works in the Mac's own bash 3.2 (no mapfile, no ${var,,}).
lines=()
lc=()
n=0
while IFS= read -r line || [ -n "$line" ]; do
  lines[n]="$line"
  lc[n]="$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')"
  n=$((n + 1))
done < "$FILE"
if [ "$n" -eq 0 ]; then
  fail "The card file is empty: $FILE" "Paste the card's description into it, or run /flow-check-card <CARD-KEY> to read the card from Jira."
  exit 1
fi

echo "card-check — $FILE ($n lines)"

# ---------------------------------------------------------------- helpers
# A markdown heading of level 1–4 with exactly this title (case-insensitive; a trailing ":" is allowed).
is_heading() { # <lowercased line> <lowercased title>
  printf '%s' "$1" | grep -q -E "^#{1,4}[[:space:]]+$2[[:space:]]*:?[[:space:]]*$"
}
# Any heading of level 1 or 2 (a section boundary).
is_section_heading() { printf '%s' "$1" | grep -q -E '^#{1,2}[[:space:]]+'; }
# An AC heading exactly in the template's format: **AC 1 — Title**
is_ac_heading() { printf '%s' "$1" | grep -q -E '^\*\*AC [0-9]+ — .+\*\*[[:space:]]*$'; }
# Something that is meant as an AC heading but isn't in the format: **AC1: …**, ### AC 1, AC-1 …, **AC 1 - …**
looks_like_ac_heading() { printf '%s' "$1" | grep -q -i -E '^(\*\*|#{1,4}[[:space:]]*|_)?[[:space:]]*ac[[:space:]]*-?[0-9]+([^0-9]|$)'; }
has_word() { printf '%s' "$1" | grep -q -E "(^|[^[:alnum:]_])$2([^[:alnum:]_]|$)"; }
# The patterns of scripts/memory.sh, plus a "key: value" form; a value in <angle brackets> is a placeholder, not a secret.
# The long-run pattern is letters and digits only: constant names (A_B_C) and API paths (/a/b/c) are normal in a card.
looks_secret() {
  printf '%s' "$1" | grep -q -i -E 'glpat-[A-Za-z0-9._-]{8,}|gh[pousr]_[A-Za-z0-9]{10,}|(^|[^a-z])sk-[A-Za-z0-9_-]{16,}|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{12,}|xox[bpas]-|bearer +[A-Za-z0-9._-]{16,}|(password|passwd|pwd|secret|token|api[_-]?key|client[_-]?secret|connect\.sid|cookie)[[:space:]]*[:=][[:space:]]*[`"'"'"']?[A-Za-z0-9._/+-]{8,}|[A-Za-z0-9]{40,}'
}

# ---------------------------------------------------------------- 1. required sections
context_at=-1; qa_at=-1; ac_at=-1; oos_at=-1
i=0
while [ "$i" -lt "$n" ]; do
  l="${lc[i]}"
  case "$l" in
    "#"*)
      if [ "$context_at" -lt 0 ] && is_heading "$l" "context"; then context_at=$i; fi
      if [ "$qa_at" -lt 0 ] && is_heading "$l" "how qa can test this"; then qa_at=$i; fi
      if [ "$ac_at" -lt 0 ] && is_heading "$l" "acceptance criteria"; then ac_at=$i; fi
      if [ "$oos_at" -lt 0 ] && is_heading "$l" "out of scope"; then oos_at=$i; fi
      ;;
  esac
  i=$((i + 1))
done

missing=""
[ "$context_at" -ge 0 ] || missing="$missing, ## Context"
[ "$qa_at" -ge 0 ] || missing="$missing, ## How QA can test this"
[ "$ac_at" -ge 0 ] || missing="$missing, ## Acceptance Criteria"
if [ -n "$missing" ]; then
  fail "Required section(s) missing: ${missing#, }" "Add them with exactly these headings ($TEMPLATE, section 1). Context: the current gap, what changes, why. How QA can test this: numbered steps, each with what to expect. Acceptance Criteria: every AC as **AC 1 — Title** with Given / When / Then."
else
  pass "Required sections are there: Context, How QA can test this, Acceptance Criteria"
fi

# Where each section ends: the next level-1/2 heading, or the end of the file.
section_end() { # <start line index> -> prints the index of the first line after the section
  local j=$(($1 + 1))
  while [ "$j" -lt "$n" ]; do
    is_section_heading "${lc[j]}" && break
    j=$((j + 1))
  done
  echo "$j"
}
qa_end=-1; ac_end=-1; oos_end=-1
[ "$qa_at" -ge 0 ] && qa_end="$(section_end "$qa_at")"
[ "$ac_at" -ge 0 ] && ac_end="$(section_end "$ac_at")"
[ "$oos_at" -ge 0 ] && oos_end="$(section_end "$oos_at")"
in_qa() { [ "$qa_at" -ge 0 ] && [ "$1" -gt "$qa_at" ] && [ "$1" -lt "$qa_end" ]; }
in_oos() { [ "$oos_at" -ge 0 ] && [ "$1" -ge "$oos_at" ] && [ "$1" -lt "$oos_end" ]; }

# ---------------------------------------------------------------- 2. acceptance criteria
ac_lines=""      # indexes of the headings in the format
ac_numbers=""    # their numbers, in order
bad_ac=0
i=0
while [ "$i" -lt "$n" ]; do
  l="${lines[i]}"
  if is_ac_heading "$l"; then
    ac_lines="$ac_lines $i"
    num="$(printf '%s' "$l" | sed -E 's/^\*\*AC ([0-9]+) — .*/\1/')"
    ac_numbers="$ac_numbers $num"
  elif looks_like_ac_heading "${lc[i]}"; then
    fail "AC heading not in the format on line $((i + 1)): $l" "Write it as **AC <number> — <title>** (bold, a space after AC, an em dash —, then the title; $TEMPLATE, section 4)."
    bad_ac=$((bad_ac + 1))
  fi
  i=$((i + 1))
done

ac_count=0
for x in $ac_lines; do ac_count=$((ac_count + 1)); done
if [ "$ac_count" -eq 0 ] && [ "$bad_ac" -eq 0 ]; then
  fail "No acceptance criteria found" "Add them under ## Acceptance Criteria, each as **AC 1 — Title**, then * **Given** …, * **When** …, * **Then** … ($TEMPLATE, section 4)."
fi

# Numbers must be 1, 2, 3… in order
if [ "$ac_count" -gt 0 ]; then
  expected=1; order_ok=1
  for num in $ac_numbers; do
    [ "$num" -eq "$expected" ] || order_ok=0
    expected=$((expected + 1))
  done
  if [ "$order_ok" -eq 0 ]; then
    fail "AC numbers are$(printf '%s' "$ac_numbers" | sed 's/ /, /g; s/^, / /'), not 1, 2, 3…" "Renumber the ACs in order, starting at 1 ($TEMPLATE, section 4)."
  fi
fi

# Every AC has Given, When and Then (its block runs to the next AC heading, the Error reference table or the next section)
gwt_missing=0
for start in $ac_lines; do
  j=$((start + 1)); block=""
  while [ "$j" -lt "$n" ]; do
    is_ac_heading "${lines[j]}" && break
    is_section_heading "${lc[j]}" && break
    case "${lc[j]}" in "**error reference"*|"error reference"*) break ;; esac
    block="$block ${lc[j]}"
    j=$((j + 1))
  done
  lacks=""
  has_word "$block" "given" || lacks="$lacks Given"
  has_word "$block" "when" || lacks="$lacks When"
  has_word "$block" "then" || lacks="$lacks Then"
  if [ -n "$lacks" ]; then
    num="$(printf '%s' "${lines[start]}" | sed -E 's/^\*\*AC ([0-9]+) — .*/\1/')"
    fail "AC $num has no$(printf '%s' "$lacks" | sed 's/ /, /g; s/^,//') (line $((start + 1)))" "Write it as * **Given** (the starting state), * **When** (the action), * **Then** (the exact result: HTTP status, error_code, message, details or DB change)."
    gwt_missing=$((gwt_missing + 1))
  fi
done
if [ "$ac_count" -gt 0 ] && [ "$bad_ac" -eq 0 ] && [ "$gwt_missing" -eq 0 ] && [ "${order_ok:-1}" -eq 1 ]; then
  pass "$ac_count acceptance criteria, numbered 1–$ac_count, each with Given / When / Then"
fi

# ---------------------------------------------------------------- 3. QA steps
if [ "$qa_at" -ge 0 ]; then
  step_lines=""
  i=$((qa_at + 1))
  while [ "$i" -lt "$qa_end" ]; do
    if printf '%s' "${lines[i]}" | grep -q -E '^[[:space:]]*[0-9]+\.[[:space:]]'; then step_lines="$step_lines $i"; fi
    i=$((i + 1))
  done
  step_count=0
  for x in $step_lines; do step_count=$((step_count + 1)); done
  if [ "$step_count" -eq 0 ]; then
    fail "The QA section has no numbered steps" "Write the QA steps as a numbered list (1., 2., …), each ending with what to expect ($TEMPLATE, section 5)."
  else
    no_expect=0
    for start in $step_lines; do
      j=$((start + 1)); block="${lc[start]}"
      while [ "$j" -lt "$qa_end" ]; do
        printf '%s' "${lines[j]}" | grep -q -E '^[[:space:]]*[0-9]+\.[[:space:]]' && break
        block="$block ${lc[j]}"
        j=$((j + 1))
      done
      if ! printf '%s' "$block" | grep -q 'expect'; then
        num="$(printf '%s' "${lines[start]}" | sed -E 's/^[[:space:]]*([0-9]+)\..*/\1/')"
        warn "QA step $num has no \"Expect\" (line $((start + 1)))" "Say what QA should see after this step: \"Expect …\"."
        no_expect=$((no_expect + 1))
      fi
    done
    [ "$no_expect" -eq 0 ] && pass "QA steps: $step_count numbered steps, each with what to expect"
  fi

  # Steps the dev always does, and "after X lands" wording
  i=$((qa_at + 1))
  while [ "$i" -lt "$qa_end" ]; do
    l="${lc[i]}"
    if printf '%s' "$l" | grep -q -E '(^|[^[:alnum:]])(deploy|deployed|deploying|deployment|migrate|migration|migrations|restart|restarts|restarted)([^[:alnum:]]|$)'; then
      warn "QA step mentions deploying, a migration or a restart (line $((i + 1))): ${lines[i]}" "Leave out steps the dev always does (deploying, migrations, restarts); start from the data QA needs ($TEMPLATE, section 5)."
    fi
    if printf '%s' "$l" | grep -q -E '(after|once|when) [^.]{0,60}(lands|is merged|gets merged|is deployed|is built|is done|is finished|is released)'; then
      warn "QA step depends on other work being done first (line $((i + 1))): ${lines[i]}" "Give QA a workaround instead (seed SQL, a manual trigger, a direct API call), so the card can be tested on its own ($TEMPLATE, section 5)."
    fi
    i=$((i + 1))
  done
fi

# ---------------------------------------------------------------- 4. whole card
placeholders=0; tables=0; secrets=0; literal_nl=0; oos_outside=0; assumptions=0
i=0
while [ "$i" -lt "$n" ]; do
  l="${lines[i]}"; low="${lc[i]}"
  case "$low" in
    *"assumption:"*|*"assumptions:"*)
      fail "Assumption written into the card (line $((i + 1))): $l" "Ask the question and settle it before the card is final; cards hold no assumptions ($TEMPLATE, section 8)."
      assumptions=$((assumptions + 1)) ;;
  esac
  if printf '%s' "$l" | grep -q -E '⟦|⟧|(^|[^[:alnum:]])(TODO|TBD)([^[:alnum:]]|$)'; then
    fail "Unfilled placeholder (line $((i + 1))): $l" "Fill it in before the card is final."
    placeholders=$((placeholders + 1))
  fi
  if printf '%s' "$low" | grep -q -E 'files? (changed|in scope|change)|self[- ]check'; then
    fail "Forbidden table or heading (line $((i + 1))): $l" "Remove it. File names go in the text of Scope or Dev notes only when needed; the 12-point AC check is done in chat, not in the card ($TEMPLATE, section 2)."
    tables=$((tables + 1))
  fi
  if looks_secret "$l"; then
    fail "Line $((i + 1)) looks like it holds a secret (a token, key, password or cookie); the line isn't shown here" "Remove it from the card and change that secret. Secrets never go in cards (rule A6, D33)."
    secrets=$((secrets + 1))
  fi
  case "$l" in
    *'\n'*)
      warn "Literal \\n in the text (line $((i + 1)))" "Replace it with a real line break; Jira shows \\n as text ($TEMPLATE, section 8)."
      literal_nl=$((literal_nl + 1)) ;;
  esac
  if ! in_oos "$i" && [ "$i" -ne "$oos_at" ]; then
    if printf '%s' "$low" | grep -q -E 'not in (this card|scope)|out of scope|out-of-scope'; then
      warn "Out-of-scope line outside the Out of Scope section (line $((i + 1))): $l" "Move it into the ## Out of Scope section, the only place for out-of-scope ($TEMPLATE, section 2)."
      oos_outside=$((oos_outside + 1))
    fi
  fi
  i=$((i + 1))
done
if [ "$assumptions" -eq 0 ] && [ "$placeholders" -eq 0 ] && [ "$tables" -eq 0 ] && [ "$secrets" -eq 0 ]; then
  pass "No assumptions, placeholders, forbidden tables or secrets"
fi

# ---------------------------------------------------------------- result
echo
echo "Result: $to_fix to fix, $to_look to look at."
echo "Not checked by this script (the AI does it when it plans the card): alignment with the code, the WS1 rules, ACs inside the card's scope, real boundary values, every AC covered by a QA step."
[ "$to_fix" -eq 0 ] && exit 0
exit 1
