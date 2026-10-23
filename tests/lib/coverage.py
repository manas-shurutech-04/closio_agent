"""closio-agent's line coverage (D92): which lines of its scripts the tests ran.

python3 tests/lib/coverage.py <records file> <closio-agent folder> <minimum %> <report folder>

The records come from tests/lib/coverage-env.sh (<path>:<line>, one per line run, from the throwaway copies the tests
make). Each path is matched to the same file in this folder by what follows its last "/scripts/" (or
config/project-settings.sh). A line counts when it can run on its own: not blank, not a comment, not inside a
here-document or a text that spans lines, not the rest of a command continued from the line above, and not only
fi, done, esac, then, else, do, {, }, ;; or a case pattern. Prints a table per file and the total; writes the lines
not run to <report folder>/missed.txt; exit code 1 when the total is under the minimum.
"""
import os
import re
import sys

STRUCTURAL = re.compile(r"^(then|else|do|fi|done|esac|\{|\}|;;|\)|\(|fi;|esac;|done;|\};)$")
CLOSERS = re.compile(r"^((done|fi|esac)\b|\}(\s|;|\||&|>|<|$))")
EMPTY_PATTERN = re.compile(r"^[^()]*\)\s*;;$")


def scan(line, quote):
    """Returns (code without its comment, the quote still open at the end or None, here-document terminators)."""
    out = []
    heredocs = []
    i = 0
    n = len(line)
    while i < n:
        c = line[i]
        if quote == "'":
            if c == "'":
                quote = None
            out.append(c)
            i += 1
            continue
        if quote == '"':
            if c == "\\" and i + 1 < n:
                out.append(line[i:i + 2])
                i += 2
                continue
            if c == '"':
                quote = None
            out.append(c)
            i += 1
            continue
        if c == "\\" and i + 1 < n:
            out.append(line[i:i + 2])
            i += 2
            continue
        if c in "'\"":
            quote = c
            out.append(c)
            i += 1
            continue
        if c == "#" and (i == 0 or line[i - 1] in " \t;(|&"):
            break
        if line.startswith("<<", i) and not line.startswith("<<<", i):
            m = re.match(r"<<-?\s*(['\"]?)([A-Za-z0-9_]+)\1", line[i:])
            if m:
                heredocs.append((m.group(2), line[i:].startswith("<<-")))
                out.append(m.group(0))
                i += len(m.group(0))
                continue
        out.append(c)
        i += 1
    return "".join(out), quote, heredocs


def case_pattern(stripped):
    """A case pattern on its own line, e.g. start) or "$1"|-h)"""
    return stripped.endswith(")") and "(" not in stripped and not stripped.startswith("case ")


def executable_lines(text):
    """Returns (sure, maybe, owner): lines that can certainly run on their own; lines that may be recorded when they
    run (a command continued from the line above, the inside of a text that spans lines, done < … or } > …); and, for
    each continued line, the line its command starts on. A sure line not run is missed; a maybe line counts only when
    it ran; bash records a command that spans lines on one of its later lines, so that counts for its first line too."""
    lines = text.split("\n")
    sure, maybe, owner = set(), set(), {}
    start = None
    quote = None
    cont = False
    heredoc = []
    for no, raw in enumerate(lines, 1):
        if heredoc:
            term, dash = heredoc[0]
            if (raw.lstrip("\t") if dash else raw) == term:
                heredoc.pop(0)
            continue
        started_inside = cont or quote is not None
        code, quote, docs = scan(raw, quote)
        stripped = code.strip()
        heredoc.extend(docs)
        cont = quote is None and bool(re.search(r"(\\|\||&&|\|\|)\s*$", stripped))
        if no == 1 and stripped.startswith("#!"):
            continue
        if started_inside:
            if stripped:
                maybe.add(no)
                if start is not None:
                    owner[no] = start
            continue
        start = None
        if not stripped or STRUCTURAL.match(stripped) or EMPTY_PATTERN.match(stripped) or case_pattern(stripped):
            continue
        if CLOSERS.match(stripped):
            maybe.add(no)
            continue
        sure.add(no)
        start = no
    return sure, maybe, owner


def main():
    records, root, minimum, report = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4]
    files = {}
    for d in ("scripts", "scripts/lib"):
        for name in sorted(os.listdir(os.path.join(root, d))):
            if name.endswith(".sh"):
                files[d + "/" + name] = None
    files["config/project-settings.sh"] = None
    for rel in list(files):
        with open(os.path.join(root, rel), encoding="utf-8") as fh:
            sure, maybe, owner = executable_lines(fh.read())
        files[rel] = {"sure": sure, "maybe": maybe, "owner": owner, "ran": set()}
    with open(records, encoding="utf-8", errors="replace") as fh:
        for rec in fh:
            path, _, no = rec.rstrip("\n").rpartition(":")
            if not no.isdigit():
                continue
            path = "/" + path
            if path.endswith("/config/project-settings.sh"):
                rel = "config/project-settings.sh"
            else:
                k = path.rfind("/scripts/")
                if k < 0:
                    continue
                rel = path[k + 1:]
            if rel in files:
                files[rel]["ran"].add(int(no))
    total = covered = 0
    rows = []
    missed_out = []
    for rel, f in files.items():
        ran_all = f["ran"] | {f["owner"][x] for x in f["ran"] if x in f["owner"]}
        lines = f["sure"] | (f["maybe"] & ran_all)
        ran = ran_all & lines
        total += len(lines)
        covered += len(ran)
        pct = 100.0 * len(ran) / len(lines) if lines else 100.0
        rows.append((pct, rel, len(ran), len(lines)))
        missed = sorted(lines - ran)
        if missed:
            missed_out.append("%s: %s" % (rel, ", ".join(str(m) for m in missed)))
    width = max(len(r[1]) for r in rows)
    print("Line coverage of closio-agent's scripts (lines the tests ran / lines that can run)")
    for pct, rel, ran, lines in sorted(rows, key=lambda r: r[1]):
        print("  %-*s  %5.1f%%  (%d/%d)" % (width, rel, pct, ran, lines))
    pct_total = 100.0 * covered / total if total else 100.0
    print("  %-*s  %5.1f%%  (%d/%d)" % (width, "TOTAL", pct_total, covered, total))
    os.makedirs(report, exist_ok=True)
    with open(os.path.join(report, "missed.txt"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(missed_out) + "\n")
    shown = os.path.relpath(os.path.join(report, "missed.txt"), root)  # the same inside the Docker container (D93)
    print("Lines not run, per script: %s" % shown)
    if pct_total + 1e-9 < minimum:
        print("❌ Coverage %.1f%% is under %.0f%%" % (pct_total, minimum))
        print("   Fix: add tests for the lines in %s, then run bash tests/run.sh --coverage again." % shown)
        return 1
    print("✅ Coverage %.1f%% (at least %.0f%%)" % (pct_total, minimum))
    return 0


if __name__ == "__main__":
    sys.exit(main())
