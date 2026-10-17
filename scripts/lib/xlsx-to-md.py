# Turns the first sheet of an .xlsx file (e.g. a QMetry test-case export) into a markdown table (C4, D67).
# Standard library only. Usage: python3 -I scripts/lib/xlsx-to-md.py <file.xlsx>   (prints the markdown)
import re
import sys
import zipfile
import xml.etree.ElementTree as ET

NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}


def col_index(ref):
    letters = re.match(r"[A-Z]+", ref).group(0)
    n = 0
    for ch in letters:
        n = n * 26 + (ord(ch) - 64)
    return n - 1


def main(path):
    with zipfile.ZipFile(path) as z:
        shared = []
        if "xl/sharedStrings.xml" in z.namelist():
            for si in ET.fromstring(z.read("xl/sharedStrings.xml")).findall("m:si", NS):
                shared.append("".join(t.text or "" for t in si.iter("{%s}t" % NS["m"])))
        sheets = sorted(n for n in z.namelist() if re.match(r"xl/worksheets/sheet\d+\.xml$", n))
        if not sheets:
            sys.exit("no worksheet in " + path)
        root = ET.fromstring(z.read(sheets[0]))
    rows = []
    for row in root.iter("{%s}row" % NS["m"]):
        cells = {}
        for c in row.findall("m:c", NS):
            t = c.get("t")
            v = c.find("m:v", NS)
            if t == "s" and v is not None:
                val = shared[int(v.text)]
            elif t == "inlineStr":
                val = "".join(x.text or "" for x in c.iter("{%s}t" % NS["m"]))
            else:
                val = v.text if v is not None else ""
            cells[col_index(c.get("r"))] = val
        if cells:
            rows.append([cells.get(i, "") for i in range(max(cells) + 1)])
    if not rows:
        sys.exit("the sheet is empty")
    width = max(len(r) for r in rows)
    clean = lambda s: (s or "").replace("|", "\\|").replace("\r", "").replace("\n", "<br>").strip()
    out = ["| " + " | ".join(clean(x) for x in rows[0] + [""] * (width - len(rows[0]))) + " |",
           "|" + "---|" * width]
    for r in rows[1:]:
        out.append("| " + " | ".join(clean(x) for x in r + [""] * (width - len(r))) + " |")
    print("\n".join(out))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: python3 -I scripts/lib/xlsx-to-md.py <file.xlsx>")
    main(sys.argv[1])
