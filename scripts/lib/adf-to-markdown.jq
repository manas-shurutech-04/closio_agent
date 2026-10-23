# Jira's rich text (Atlassian Document Format, what its v3 API returns) → Markdown, for the Jira API backup (D88).
# Used by scripts/jira-api.sh, so a card or a comment read through the API looks the way the Jira connector shows it:
# headings as #, lists as - and 1., **bold**, *italic*, `code`, [links](url), tables as | a | b |.
# Input: one ADF node (a whole description or comment body), or null. Output: the Markdown text.

def spaces($n): [range(0; $n)] | map(" ") | join("");
def indent_rest($n): split("\n") | (.[0:1] + (.[1:] | map(if . == "" then . else spaces($n) + . end))) | join("\n");
def has_mark($t): ((.marks // []) | map(select(.type == $t)) | length) > 0;

def inline:
  if .type == "text" then
    . as $n
    | (.text // "")
    | if ($n | has_mark("code")) then "`" + . + "`" else . end
    | if ($n | has_mark("em")) then "*" + . + "*" else . end
    | if ($n | has_mark("strong")) then "**" + . + "**" else . end
    | if ($n | has_mark("strike")) then "~~" + . + "~~" else . end
    | ([($n.marks // [])[] | select(.type == "link") | .attrs.href][0]) as $href
    | if $href then "[" + . + "](" + $href + ")" else . end
  elif .type == "hardBreak" then "\n"
  elif .type == "mention" then (.attrs.text // "@someone")
  elif .type == "emoji" then (.attrs.text // .attrs.shortName // "")
  elif .type == "inlineCard" then (.attrs.url // "")
  elif .type == "date" then ((.attrs.timestamp // "0") | tonumber / 1000 | strftime("%Y-%m-%d"))
  elif .type == "status" then "[" + (.attrs.text // "") + "]"
  elif .type == "placeholder" then (.attrs.text // "")
  elif .type == "mediaInline" then "[attachment]"
  else ((.content // []) | map(inline) | join("")) end;
def inlines: (.content // []) | map(inline) | join("");

def block:
  def kids($sep): [(.content // [])[] | block] | join($sep);
  def item($marker): $marker + (kids("\n") | indent_rest($marker | length));
  def cell: kids("<br>") | gsub("\n"; "<br>") | gsub("\\|"; "\\|");
  def row($w): "| " + (. + [range(length; $w) | ""] | join(" | ")) + " |";
  if .type == "paragraph" then inlines
  elif .type == "heading" then ([range(0; (.attrs.level // 1))] | map("#") | join("")) + " " + inlines
  elif .type == "bulletList" then [(.content // [])[] | item("- ")] | join("\n")
  elif .type == "orderedList" then
    (.attrs.order // 1) as $s
    | [(.content // []) | to_entries[] | .key as $k | .value | item("\($s + $k). ")] | join("\n")
  elif .type == "taskList" then
    [(.content // [])[] | if .type == "taskItem" then (if .attrs.state == "DONE" then "- [x] " else "- [ ] " end) + inlines else block end] | join("\n")
  elif .type == "decisionList" then [(.content // [])[] | "- " + inlines] | join("\n")
  elif .type == "codeBlock" then "```" + (.attrs.language // "") + "\n" + ((.content // []) | map(.text // "") | join("")) + "\n```"
  elif .type == "blockquote" or .type == "panel" then kids("\n\n") | split("\n") | map(if . == "" then ">" else "> " + . end) | join("\n")
  elif .type == "rule" then "---"
  elif .type == "expand" or .type == "nestedExpand" then
    (if (.attrs.title // "") != "" then "**" + .attrs.title + "**\n\n" else "" end) + kids("\n\n")
  elif .type == "table" then
    [(.content // [])[] | [(.content // [])[] | cell]] as $rows
    | if ($rows | length) == 0 then "" else
        ($rows | map(length) | max) as $w
        | ([$rows[0] | row($w)] + ["| " + ([range(0; $w) | "---"] | join(" | ")) + " |"] + [$rows[1:][] | row($w)]) | join("\n")
      end
  elif .type == "mediaSingle" or .type == "mediaGroup" then
    [(.content // [])[] | select(.type == "media") | "![" + (.attrs.alt // "") + "](attachment:" + (.attrs.id // "") + ")"] | join("\n")
  elif .type == "media" then "![" + (.attrs.alt // "") + "](attachment:" + (.attrs.id // "") + ")"
  elif .type == "blockCard" or .type == "embedCard" then (.attrs.url // "")
  elif (.type == "text" or .type == "hardBreak" or .type == "mention" or .type == "emoji" or .type == "inlineCard"
        or .type == "date" or .type == "status" or .type == "mediaInline") then inline
  else kids("\n\n") end;

if . == null then "" elif type == "string" then . else block end
