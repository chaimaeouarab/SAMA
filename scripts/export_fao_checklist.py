"""Generate docs/FAO_CHECKLIST.md: one line per crop parameter to check against the FAO books.
For each value the reviewer ticks OK or writes the book value. Then fix scripts/build_crops_json.py and rerun it.
Run: python scripts/export_fao_checklist.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
crops = json.loads((ROOT / "assets/data/crops.json").read_text(encoding="utf-8"))
out = [
    "# FAO checklist (fill this in, then correct `scripts/build_crops_json.py`)",
    "",
    "Open the books and compare. **Nobody has verified these values yet.** Write the book value if different.",
    "- Stage lengths: FAO-56 Table 11 (the app adapts them to Morocco; note any difference you accept).",
    "- Kc ini / mid / end: FAO-56 Table 12.",
    "- Zr max and p: FAO-56 Table 22.",
    "- Ky: FAO-33 (yield response factor for the whole growing period). If a crop has no value: write `none`.",
    "- Total available water 140 mm/m and fallow Kc 0.3: FAO-56 Table 19 and chapter 7 (see docs/SOURCES.md §C).",
    "",
    "| crop | stages ini/dev/mid/late | Kc ini/mid/end | Zr max (m) | p | Ky | book values / OK | checked by |",
    "|---|---|---|---|---|---|---|---|",
]
for c in crops:
    m = c.get("model")
    if not m:
        continue
    s = m["stages"]
    out.append(
        f"| {c['names']['en']} (`{c['id']}`) | {s['ini']}/{s['dev']}/{s['mid']}/{s['late']} | "
        f"{m['kc']['ini']}/{m['kc']['mid']}/{m['kc']['end']} | {m['zrMax']} | {m['p']} | "
        f"{m['ky'] if m['ky'] is not None else 'none'} | ☐ | |"
    )
out += [
    "",
    "Sowing dates (SAMA assumptions for Morocco, not in the FAO tables): validate with an agronomist or the regional extension service (ORMVA).",
    "",
    "| crop | sowing day/month | OK / correction |",
    "|---|---|---|",
]
for c in crops:
    m = c.get("model")
    if m:
        out.append(f"| {c['names']['en']} | {m['sow']['day']}/{m['sow']['month']} | ☐ |")
(ROOT / "docs/FAO_CHECKLIST.md").write_text("\n".join(out) + "\n", encoding="utf-8")
print("ok")
