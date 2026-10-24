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
# While reading each block, note whether it's an error AC: an HTTP 4xx/5xx status or error_code (D82).
gwt_missing=0
error_ac=""
for start in $ac_lines; do
  j=$((start + 1)); block=""
  while [ "$j" -lt "$n" ]; do
    is_ac_heading "${lines[j]}" && break
    is_section_heading "${lc[j]}" && break
    case "${lc[j]}" in "**error reference"*|"error reference"*) break ;; esac
    block="$block ${lc[j]}"
    j=$((j + 1))
  done
  if [ -z "$error_ac" ] && printf '%s' "$block" | grep -q -E 'http[[:space:]]*[45][0-9]{2}([^0-9]|$)|error_code|`[45][0-9]{2}([^0-9]|$)|(^|[^0-9])[45][0-9]{2}[[:space:]]*[(:]?[[:space:]]*`[a-z][a-z0-9_]+`'; then
    error_ac="$(printf '%s' "${lines[start]}" | sed -E 's/^\*\*AC ([0-9]+) — .*/\1/')"
  fi
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

# An error AC needs the Error reference table, with a "Raised by" column (D82)
err_ref_at=-1
i=0
while [ "$i" -lt "$n" ]; do
  case "${lc[i]}" in "**error reference"*|"error reference"*|"#"*"error reference"*) err_ref_at=$i; break ;; esac
  i=$((i + 1))
done
if [ -n "$error_ac" ]; then
  if [ "$err_ref_at" -lt 0 ]; then
    fail "AC $error_ac names an error, but the card has no **Error reference** table" "Add **Error reference** after the last AC: | HTTP | error_code | message | details | Raised by | Trigger |, one row per error the ACs name, codes and messages from the code ($TEMPLATE, section 2)."
  fi
fi
if [ "$err_ref_at" -ge 0 ]; then
  head_row=""
  j=$((err_ref_at + 1))
  while [ "$j" -lt "$n" ]; do
    case "${lc[j]}" in "|"*) head_row="${lc[j]}"; break ;; esac
    is_section_heading "${lc[j]}" && break
    j=$((j + 1))
  done
  if [ -z "$head_row" ]; then
    fail "**Error reference** has no table (line $((err_ref_at + 1)))" "Add the table: | HTTP | error_code | message | details | Raised by | Trigger | ($TEMPLATE, section 2)."
  elif ! printf '%s' "$head_row" | grep -q 'raised by'; then
    fail "The Error reference table has no \"Raised by\" column (line $((j + 1)))" "Add a Raised by column: WS2, WS1, or Web for a screen-only message ($TEMPLATE, section 2)."
  else
    pass "Error reference table with a Raised by column"
  fi
fi

# ---------------------------------------------------------------- 2b. API request and response (D84, rule A28)
# A card that names an API (a method and a path) needs ## API request and response, with the user's structures:
# one ### <METHOD> <path> block per API, a Response JSON in each (or "unchanged" next to its label when the response stays
# as it is today, D94), and a Request JSON for POST, PUT and PATCH.
api_line="$(grep -n -m 1 -E '(^|[^A-Za-z])(GET|POST|PUT|PATCH|DELETE)[[:space:]]+`?(/|\.\.\.|<)' "$FILE" | cut -d: -f1)"
api_at=-1
i=0
while [ "$i" -lt "$n" ]; do
  case "${lc[i]}" in "#"*) is_heading "${lc[i]}" "api request and response" && { api_at=$i; break; } ;; esac
  i=$((i + 1))
done
if [ -n "$api_line" ] && [ "$api_at" -lt 0 ]; then
  fail "The card names an API (line $api_line) but has no ## API request and response" "Add ## API request and response with ### <METHOD> <path> per API, each with **Request** and **Response (200)** as JSON blocks, exactly as the user gives them; never write one ($TEMPLATE, section 2, rule A28)."
elif [ "$api_at" -ge 0 ]; then
  api_end="$(section_end "$api_at")"
  apis=0; api_bad=0
  i=$((api_at + 1))
  while [ "$i" -lt "$api_end" ]; do
    if printf '%s' "${lines[i]}" | grep -q -E '^###[[:space:]]+`?(GET|POST|PUT|PATCH|DELETE)[[:space:]]'; then
      apis=$((apis + 1))
      method="$(printf '%s' "${lines[i]}" | sed -E 's/^###[[:space:]]+`?([A-Z]+).*/\1/')"
      j=$((i + 1)); req=0; resp=0; seen_req=0; seen_resp=0
      while [ "$j" -lt "$api_end" ]; do
        case "${lc[j]}" in "###"*) break ;; esac
        case "${lc[j]}" in *"**request"*) seen_req=1; seen_resp=0 ;; *"**response"*) seen_resp=1; seen_req=0 ;; *"**error response"*) seen_req=0; seen_resp=0 ;; esac
        case "${lc[j]}" in *"**response"*unchanged*) resp=1 ;; esac   # the response stays as it is today (D94)
        case "${lc[j]}" in '```'*|*'```json'*)
          [ "$seen_req" -eq 1 ] && req=1
          [ "$seen_resp" -eq 1 ] && resp=1 ;;
        esac
        j=$((j + 1))
      done
      if [ "$resp" -eq 0 ]; then
        fail "No Response JSON for ${lines[i]#\#\#\# } (line $((i + 1)))" "Add **Response (200)** with the JSON the user gave for this API, or \"**Response (200)**: unchanged (AC <n>)\" when the card says it stays as it is today (rule A28, D94)."; api_bad=$((api_bad + 1))
      fi
      case "$method" in POST|PUT|PATCH)
        if [ "$req" -eq 0 ]; then
          fail "No Request JSON for ${lines[i]#\#\#\# } (line $((i + 1)))" "Add **Request** with the JSON body the user gave for this API (rule A28)."; api_bad=$((api_bad + 1))
        fi ;;
      esac
    fi
    i=$((i + 1))
  done
  if [ "$apis" -eq 0 ]; then
    fail "## API request and response has no API in it (line $((api_at + 1)))" "Add a ### <METHOD> <path> block per API, each with **Request** and **Response (200)** JSON from the user (rule A28)."
  elif [ "$api_bad" -eq 0 ]; then
    pass "API request and response: $apis API(s), each with its structure"
  fi
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

  # Every AC is named by at least one QA step, e.g. "(AC 3)" (D82)
  if [ "$ac_count" -gt 0 ]; then
    qa_text=""
    i=$((qa_at + 1))
    while [ "$i" -lt "$qa_end" ]; do qa_text="$qa_text ${lc[i]}"; i=$((i + 1)); done
    unnamed=""
    for num in $ac_numbers; do
      printf '%s' "$qa_text" | grep -q -E "(^|[^[:alnum:]])ac ?$num([^0-9]|$)" || unnamed="$unnamed $num"
    done
    if [ -n "$unnamed" ]; then
      warn "No QA step names AC$(printf '%s' "$unnamed" | sed 's/ /, /g; s/^,//')" "End the step that proves each AC with its name, e.g. \"Expect … (AC 3)\". Every AC needs a QA step ($TEMPLATE, section 5)."
    else
      pass "Every AC is named by a QA step"
    fi
  fi
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
    fail "Line $((i + 1)) looks like it holds a secret (a token, key, password or cookie); the line isn't shown here" "Remove it from the card and change that secret. Secrets never go in cards."
    secrets=$((secrets + 1))
  fi
  case "$l" in
    *'\n'*)
      warn "Literal \\n in the text (line $((i + 1)))" "Replace it with a real line break; Jira shows \\n as text ($TEMPLATE, section 8)."
      literal_nl=$((literal_nl + 1)) ;;
  esac
  if printf '%s' "$low" | grep -q -E "(can'?t|cannot|can not) trigger|code review only|checked in code review|not testable by qa"; then
    warn "An AC left out of QA's testing (line $((i + 1))): $l" "Every AC is testable by QA on its own: give a workaround (seed SQL, a direct API call, or a mocked response with its exact body) ($TEMPLATE, sections 4 and 5)."
  fi
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
echo "Not checked by this script (the AI does it when it plans the card): alignment with the code, the WS1 rules, ACs inside the card's scope, real boundary values, whether the QA step that names an AC really proves it."
[ "$to_fix" -eq 0 ] && exit 0
exit 1
