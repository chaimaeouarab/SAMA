"""Export every UI string of lib/core/strings.dart to docs/ui_strings_review.csv for native-speaker review.
Darija and Modern Standard Arabic are drafts: reviewed = false until a person signs.
Run: python scripts/export_ui_strings.py
"""
import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
src = (ROOT / "lib/core/strings.dart").read_text(encoding="utf-8")
body = src[src.index("const Map<String, List<String>> _s"):src.index("String tr(")]
QUOTED = re.compile(r"'((?:[^'\\]|\\.)*)'")
rows = []
for m in re.finditer(r"'([A-Za-z0-9_]+)':\s*\[(.*?)\],", body, flags=re.S):
    vals = QUOTED.findall(m.group(2))
    if len(vals) == 4:
        rows.append([m.group(1)] + vals)
with open(ROOT / "docs/ui_strings_review.csv", "w", encoding="utf-8-sig", newline="") as f:
    w = csv.writer(f)
    w.writerow(["key", "dar", "ar", "en", "fr", "reviewed", "reviewer", "correction"])
    for r in rows:
        w.writerow(r + ["false", "", ""])
print("strings:", len(rows))
