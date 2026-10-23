# Markdown → Jira wiki markup (what Jira's v2 API takes for a comment or a description), for the Jira API backup (D88).
# Used by scripts/jira-api.sh, so a comment or a card written through the API looks the way the Jira connector writes it:
# # → h1., - → *, 1. → #, **bold** → *bold*, *italic* → _italic_, `code` → {{code}}, [text](url) → [text|url],
# ``` → {code}, > → bq., tables with their header row as || a || b ||. A { in the text (and { } in `code`) is escaped, so it
# isn't read as a macro.
# Input: the Markdown as one raw string (jq -Rs). Output: the wiki text.

def rep($s; $n): [range(0; $n)] | map($s) | join("");
def depth($sp): (($sp | length) / 2 | floor) + 1;

# Text outside `code`: braces, lone [, links, images, bold, italic, strike.
def spans:
  gsub("\\{"; "\\{")
  | gsub("\\[(?![^\\]]*\\]\\()"; "\\[")
  | gsub("!\\[(?<a>[^\\]]*)\\]\\((?<u>[^)\\s]+)\\)"; "!\(.u)!")
  | gsub("\\[(?<t>[^\\]]+)\\]\\((?<u>[^)\\s]+)\\)"; "[\(.t)|\(.u)]")
  | gsub("(?<![*\\w])\\*(?<t>[^*\\s][^*]*?)\\*(?![*\\w])"; "_\(.t)_")
  | gsub("\\*\\*(?<t>[^*]+?)\\*\\*"; "*\(.t)*")
  | gsub("(?<!\\w)__(?<t>[^_]+?)__(?!\\w)"; "*\(.t)*")
  | gsub("~~(?<t>[^~]+?)~~"; "-\(.t)-");

def inline_md:
  split("`") as $parts
  | if ($parts | length) % 2 == 0 then spans
    else $parts | to_entries | map(if .key % 2 == 1 then "{{" + (.value | gsub("(?<b>[{}])"; "\\\(.b)")) + "}}" else (.value | spans) end) | join("") end;

def line:
  if test("^#{1,6} ") then capture("^(?<h>#{1,6}) (?<t>.*)$") | "h\(.h | length). " + (.t | inline_md)
  elif test("^\\s*[-*+] \\[[ xX]\\] ") then
    capture("^(?<s>\\s*)[-*+] \\[(?<c>[ xX])\\] (?<t>.*)$")
    | rep("*"; depth(.s)) + (if .c == " " then " ☐ " else " ☑ " end) + (.t | inline_md)
  elif test("^\\s*[-*+] ") then capture("^(?<s>\\s*)[-*+] (?<t>.*)$") | rep("*"; depth(.s)) + " " + (.t | inline_md)
  elif test("^\\s*[0-9]+[.)] ") then capture("^(?<s>\\s*)[0-9]+[.)] (?<t>.*)$") | rep("#"; depth(.s)) + " " + (.t | inline_md)
  elif test("^\\s*(-{3,}|\\*{3,}|_{3,})\\s*$") then "----"
  elif test("^>") then "bq. " + (sub("^> ?"; "") | inline_md)
  else inline_md end;

def table_rule: test("\\|") and test("-{3}") and test("^[\\s|:-]+$");

split("\n")
| reduce .[] as $l ({out: [], code: false};
    if .code then
      if ($l | test("^\\s*```")) then .code = false | .out += ["{code}"] else .out += [$l] end
    elif ($l | test("^\\s*```")) then
      ($l | capture("^\\s*```(?<lang>[A-Za-z0-9_+-]*)").lang) as $lang
      | .code = true | .out += [if $lang == "" then "{code}" else "{code:" + $lang + "}" end]
    elif ($l | table_rule) and ((.out | length) > 0) and (.out[-1] | test("^\\s*\\|")) then
      .out[-1] |= gsub("\\|"; "||")
    else .out += [$l | line] end)
| .out | join("\n") | sub("\\s+$"; "")
