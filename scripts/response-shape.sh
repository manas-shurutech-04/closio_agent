#!/usr/bin/env bash
# Compares an API's real response with the response structure in the card (flow-verify; rule A28, D84).
# Run it from the closio-agent folder:
#
#   bash scripts/response-shape.sh <card file> "<METHOD> <path>" <response file>
#
#   <card file>      the card's text, e.g. runs/SCRUM-559/card.md. Its "## API request and response" holds a
#                    "### <METHOD> <path>" block per API, with a "**Response (200)**" JSON block: the structure the
#                    user gave. This script never writes or fixes a structure.
#   "<METHOD> <path>" the API, written as in its ### heading (backticks and spaces around it don't matter)
#   <response file>  the real response: a file saved with `bash scripts/api-call.sh … --save <file>`
#                    ("status: <code>" first, then the body), or a plain JSON file
#
# What it compares: the structure, not the values. The same keys at every level, and the same JSON type for each
# (string, number, boolean, object, array, null); an array by its first item. In the card's structure:
#   - null means "may be null": any type is accepted there;
#   - a type word written as the value ("string", "number", "integer", "boolean", "object", "array", "uuid",
#     "date", "datetime", "any") counts as that type ("uuid", "date" and "datetime" are strings; "any" is anything).
# Prints ✅ when the structures match, or one ❌ line per difference: missing in the response, not in the card,
# or a different type.
# Exit codes: 0 the same structure · 1 at least one difference · 2 wrong usage, the API or its Response isn't in
# the card, or the card's or the response's JSON can't be read (the fix: the user gives a valid structure).
# Only reads its two files. Works with the Mac's own /usr/bin/python3.

set -u
usage() { echo 'Usage: bash scripts/response-shape.sh <card file> "<METHOD> <path>" <response file>'; }
if [ $# -ne 3 ] || [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then usage; exit 2; fi
for f in "$1" "$3"; do
  if [ ! -r "$f" ]; then echo "❌ Can't read $f"; echo "   Fix: give the path of an existing file."; exit 2; fi
done

exec /usr/bin/python3 -I - "$1" "$2" "$3" <<'PY'
import json, re, sys

card_file, api, resp_file = sys.argv[1], sys.argv[2], sys.argv[3]
TYPE_WORDS = {"string": "string", "uuid": "string", "date": "string", "datetime": "string",
              "number": "number", "integer": "number", "boolean": "boolean",
              "object": "object", "array": "array", "any": "any"}

def stop(msg, fix):
    print("❌ " + msg); print("   Fix: " + fix); sys.exit(2)

def norm_api(s):
    return re.sub(r"\s+", " ", s.replace("`", "")).strip().upper()

card = open(card_file, encoding="utf-8").read().splitlines()
# The "## API request and response" section
start = next((i for i, l in enumerate(card) if re.match(r"^#{1,2}\s+api request and response\s*:?\s*$", l.strip(), re.I)), None)
if start is None:
    stop(f"{card_file} has no ## API request and response.", "the card needs the user's structure for this API (rule A28): ask the user for it.")
end = next((i for i in range(start + 1, len(card)) if re.match(r"^#{1,2}\s", card[i])), len(card))
want = norm_api(api)
block = None
for i in range(start + 1, end):
    m = re.match(r"^###\s+(.*)$", card[i])
    if m and norm_api(m.group(1)) == want:
        j = next((k for k in range(i + 1, end) if card[k].startswith("###")), end)
        block = card[i + 1:j]; break
if block is None:
    stop(f'"{api}" isn\'t in the card\'s ## API request and response.', "write the API as in its ### heading, or ask the user for its structure (rule A28).")
# The JSON block after the **Response label
text, inside, after_resp = [], False, False
for line in block:
    low = line.lower()
    if not inside and "**response" in low:
        after_resp = True; continue
    if not inside and ("**request" in low or "**error response" in low):
        after_resp = False; continue
    if line.strip().startswith("```"):
        if inside: break
        if after_resp: inside = True
        continue
    if inside: text.append(line)
if not text:
    stop(f'"{api}" has no Response JSON in the card.', "ask the user for the response structure and add it to the card (rule A28).")
try:
    expected = json.loads("\n".join(text))
except ValueError as e:
    stop(f'The card\'s Response for "{api}" isn\'t valid JSON ({e}).', "ask the user for a valid structure; never fix it yourself (rule A28).")

raw = open(resp_file, encoding="utf-8").read()
status = None
m = re.match(r"^status:\s*(\d+)\s*\n", raw)
if m:
    status, raw = m.group(1), raw[m.end():]
try:
    actual = json.loads(raw)
except ValueError:
    stop(f"The response in {resp_file} isn't JSON" + (f" (HTTP {status})" if status else "") + ".", "check the call; save it again with api-call.sh … --save.")

def jtype(v):
    if v is None: return "null"
    if isinstance(v, bool): return "boolean"
    if isinstance(v, (int, float)): return "number"
    if isinstance(v, str): return "string"
    if isinstance(v, list): return "array"
    return "object"

diffs = []
def walk(exp, act, path):
    if exp is None:
        return                                   # may be null: anything is accepted
    if isinstance(exp, str) and exp.strip().lower() in TYPE_WORDS:
        want_t = TYPE_WORDS[exp.strip().lower()]
        if want_t != "any" and jtype(act) != want_t and act is not None:
            diffs.append(f"type differs at {path or '(the body)'}: card {want_t}, response {jtype(act)}")
        return
    et, at = jtype(exp), jtype(act)
    if et != at:
        if act is None:
            diffs.append(f"null in the response at {path or '(the body)'}: card {et}")
        else:
            diffs.append(f"type differs at {path or '(the body)'}: card {et}, response {at}")
        return
    if et == "object":
        for k in exp:
            p = f"{path}.{k}" if path else k
            if k not in act: diffs.append(f"missing in the response: {p}")
            else: walk(exp[k], act[k], p)
        for k in act:
            if k not in exp:
                diffs.append(f"not in the card: {path + '.' + k if path else k}")
    elif et == "array" and exp and act:
        for idx, item in enumerate(act):
            walk(exp[0], item, f"{path}[{idx}]")

walk(expected, actual, "")
label = f"{api}" + (f" (HTTP {status})" if status else "")
if not diffs:
    print(f"✅ {label}: the response has the card's structure")
    sys.exit(0)
print(f"❌ {label}: {len(diffs)} difference(s) from the card's structure")
for d in diffs[:60]:
    print(f"   ❌ {d}")
if len(diffs) > 60:
    print(f"   … and {len(diffs) - 60} more")
print("   The user decides: fix the code, or confirm the card's structure (rule A28).")
sys.exit(1)
PY
