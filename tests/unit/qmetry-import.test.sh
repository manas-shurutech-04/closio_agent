# scripts/qmetry-import.sh (and scripts/lib/xlsx-to-md.py): a QMetry export (.xlsx) saved as markdown in the card's
# folder, and how many of its cases the card's test cases cover. The .xlsx files are built here with python3's zipfile.

# make_xlsx <file> <story key> [empty]: a QMetry-like export, its first column and Summary as shared strings, the
# rest inline; a number, a "|" and a line break in cells; "empty" makes a sheet without rows
make_xlsx() {
  python3 -I - "$1" "$2" "${3:-}" <<'PY'
import sys, zipfile
from xml.sax.saxutils import escape
path, story, mode = sys.argv[1], sys.argv[2], sys.argv[3]
rows = [
    ["Key", "Summary", "Step", "Expected", "Story Linkages"],
    ["SCRUM-TC-419", "List schemes", "Open the list", "Shows 3", story],
    [None, None, "Click filter", "Filtered", None],
    ["SCRUM-TC-420", "Filter a|b", "Pick active", "Line 1\nLine 2", story],
    [None, None, "Step 2", 42, None],
]
if mode == "empty":
    rows = []
shared, cells_xml = [], []
for r, row in enumerate(rows, 1):
    cs = []
    for c, val in enumerate(row):
        if val is None:
            continue
        ref = "ABCDE"[c] + str(r)
        if isinstance(val, (int, float)):
            cs.append('<c r="%s"><v>%s</v></c>' % (ref, val))
        elif c < 2:
            shared.append(val)
            cs.append('<c r="%s" t="s"><v>%d</v></c>' % (ref, len(shared) - 1))
        else:
            cs.append('<c r="%s" t="inlineStr"><is><t>%s</t></is></c>' % (ref, escape(val)))
    cells_xml.append('<row r="%d">%s</row>' % (r, "".join(cs)))
ns = 'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"'
with zipfile.ZipFile(path, "w") as z:
    z.writestr("[Content_Types].xml", "<Types/>")
    z.writestr("xl/sharedStrings.xml", "<sst %s>%s</sst>" % (ns, "".join("<si><t>%s</t></si>" % escape(s) for s in shared)))
    z.writestr("xl/worksheets/sheet1.xml", "<worksheet %s><sheetData>%s</sheetData></worksheet>" % (ns, "".join(cells_xml)))
PY
}

setup_qmetry() {
  sandbox
  mkdir -p "$A/runs/SCRUM-5" "$T/downloads"
  make_xlsx "$T/downloads/export.xlsx" SCRUM-5
}

test_wrong_usage_shows_the_usage() {
  setup_qmetry
  local args
  for args in "" "SCRUM-5" "scrum-5 $T/downloads/export.xlsx" "OTHER-5 x.xlsx" "coverage" "coverage SCRUM"; do
    run qmetry-import.sh $args
    assert_rc 2
    assert_eq "$OUT" "Usage: bash scripts/qmetry-import.sh <CARD-KEY> <export.xlsx>   or   bash scripts/qmetry-import.sh coverage <CARD-KEY>" "usage for: $args"
  done
}

test_a_missing_export_or_card_folder() {
  setup_qmetry
  run qmetry-import.sh SCRUM-5 "$T/downloads/none.xlsx"
  assert_rc 1
  assert_eq "$OUT" "❌ No file '$T/downloads/none.xlsx'
   Fix: give the full path of the QMetry export (.xlsx)."
  run qmetry-import.sh SCRUM-6 "$T/downloads/export.xlsx"
  assert_rc 1
  assert_eq "$OUT" "❌ No card folder runs/SCRUM-6 on this Mac
   Fix: bash scripts/run.sh branch SCRUM-6 (it brings the card's folder here), then run this again."
}

test_import_saves_the_cases_as_a_markdown_table() {
  setup_qmetry
  run qmetry-import.sh SCRUM-5 "$T/downloads/export.xlsx"
  assert_rc 0
  assert_eq "$OUT" "✅ 2 QMetry test case(s) (2 more row(s) of their steps) saved to runs/SCRUM-5/qmetry/export.md"
  assert_eq "$(cat "$A/runs/SCRUM-5/qmetry/export.md")" "# QMetry test cases of SCRUM-5

Imported from export.xlsx on $(date '+%Y-%m-%d'); the base for the card's test cases.

| Key | Summary | Step | Expected | Story Linkages |
|---|---|---|---|---|
| SCRUM-TC-419 | List schemes | Open the list | Shows 3 | SCRUM-5 |
|  |  | Click filter | Filtered |  |
| SCRUM-TC-420 | Filter a\\|b | Pick active | Line 1<br>Line 2 | SCRUM-5 |
|  |  | Step 2 | 42 |  |"
  assert_no_file "$A/runs/SCRUM-5/qmetry/export.md.tmp"
}

test_an_export_for_another_card_is_a_warning() {
  setup_qmetry
  make_xlsx "$T/downloads/other.xlsx" SCRUM-55
  run qmetry-import.sh SCRUM-5 "$T/downloads/other.xlsx"
  assert_rc 0
  assert_contains "$OUT" "✅ 2 QMetry test case(s)"
  assert_contains "$OUT" "⚠️ The export doesn't mention SCRUM-5: its cases may belong to another card
   Tip: check its \"Story Linkages\" column; if it's the wrong file, delete runs/SCRUM-5/qmetry/other.md and import the right one."
}

test_a_file_that_is_not_an_excel_export() {
  setup_qmetry
  printf 'Key,Summary\n' > "$T/downloads/cases.xlsx"
  run qmetry-import.sh SCRUM-5 "$T/downloads/cases.xlsx"
  assert_rc 1
  assert_contains "$OUT" "❌ Couldn't read '$T/downloads/cases.xlsx' as an Excel export
   Fix: export the test cases from QMetry again as .xlsx, then run this again."
  assert_eq "$(ls -A "$A/runs/SCRUM-5/qmetry")" "" "nothing saved, no temporary file left"
}

test_a_workbook_without_a_sheet_or_with_an_empty_one() {
  setup_qmetry
  python3 -I -c 'import sys, zipfile; z = zipfile.ZipFile(sys.argv[1], "w"); z.writestr("xl/workbook.xml", "<w/>"); z.close()' "$T/downloads/nosheet.xlsx"
  run qmetry-import.sh SCRUM-5 "$T/downloads/nosheet.xlsx"
  assert_rc 1
  assert_contains "$OUT" "no worksheet in $T/downloads/nosheet.xlsx"
  assert_contains "$OUT" "❌ Couldn't read"
  make_xlsx "$T/downloads/empty.xlsx" SCRUM-5 empty
  run qmetry-import.sh SCRUM-5 "$T/downloads/empty.xlsx"
  assert_rc 1
  assert_contains "$OUT" "the sheet is empty"
  assert_no_file "$A/runs/SCRUM-5/qmetry/empty.md"
}

test_xlsx_to_md_on_its_own_needs_one_file() {
  setup_qmetry
  run_in "$A" python3 -I scripts/lib/xlsx-to-md.py
  assert_rc 1; assert_eq "$OUT" "usage: python3 -I scripts/lib/xlsx-to-md.py <file.xlsx>"
}

test_coverage_counts_the_cases_named_in_the_cards_test_cases() {
  setup_qmetry
  run qmetry-import.sh SCRUM-5 "$T/downloads/export.xlsx"
  mkdir -p "$A/runs/SCRUM-5/api-checks" "$A/runs/SCRUM-5/e2e"
  printf '{"ac": 1, "cases": [{"name": "SCRUM-TC-419: list → 200"}]}\n' > "$A/runs/SCRUM-5/api-checks/ac-1.json"
  printf "test('AC 2 — SCRUM-TC-4200 filter', async () => {});\n" > "$A/runs/SCRUM-5/e2e/ac-2.spec.ts"
  run qmetry-import.sh coverage SCRUM-5
  assert_rc 0
  assert_eq "$OUT" "QMetry: 1 of 2 test cases covered (50%)"
  printf "test('AC 2 — SCRUM-TC-420 filter', async () => {});\n" > "$A/runs/SCRUM-5/e2e/ac-2.spec.ts"
  run qmetry-import.sh coverage SCRUM-5
  assert_eq "$OUT" "QMetry: 2 of 2 test cases covered (100%)"
}

test_coverage_over_two_exports_counts_each_case_once() {
  setup_qmetry
  run qmetry-import.sh SCRUM-5 "$T/downloads/export.xlsx"
  cp "$T/downloads/export.xlsx" "$T/downloads/again.xlsx"
  run qmetry-import.sh SCRUM-5 "$T/downloads/again.xlsx"
  run qmetry-import.sh coverage SCRUM-5
  assert_rc 0
  assert_eq "$OUT" "QMetry: 0 of 2 test cases covered (0%)"
}

test_coverage_without_an_export_or_without_cases() {
  setup_qmetry
  run qmetry-import.sh coverage SCRUM-5
  assert_rc 0
  assert_eq "$OUT" "No QMetry export saved for SCRUM-5: nothing to count."
  mkdir -p "$A/runs/SCRUM-5/qmetry"
  printf '# QMetry test cases of SCRUM-5\n\n| Key | Summary |\n|---|---|\n' > "$A/runs/SCRUM-5/qmetry/x.md"
  run qmetry-import.sh coverage SCRUM-5
  assert_rc 0
  assert_eq "$OUT" "⚠️ No QMetry test cases found in runs/SCRUM-5/qmetry/
   Tip: import the export again: bash scripts/qmetry-import.sh SCRUM-5 <export.xlsx>"
}
