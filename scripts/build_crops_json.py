"""Generate assets/data/crops.json (v2) and assets/data/rotation_rules.json.

EVERY agronomic number below is a DRAFT taken from memory of FAO-56 (Tables 11, 12, 22) and FAO-33 (Ky),
marked verified:false. They must be checked against the books by a person (docs/SOURCES.md) before the
app can drop its "provisional parameters" badge. Crops with no FAO-33 yield-response factor (ky = None)
are EXCLUDED from recommendations instead of guessed ("More information needed").

Names reuse docs/prototype.html. Darija ("dar") is a draft; Modern Standard Arabic ("ar") is a draft too.
"""
import json
from pathlib import Path

# id, category, family, legume, sow(month, day), stages (ini, dev, mid, late), kc (ini, mid, end),
# zr max (m), p (depletion fraction), ky (None = no FAO-33 value), illustration kind, c1, c2, dar, ar, en, fr
R = [
    ("softwheat", "cereal", "Poaceae", False, (11, 15), (30, 60, 60, 40), (0.40, 1.15, 0.30), 1.5, 0.55, 1.0, "cereal", "#EBC45A", "#C98A1C", "القمح اللين", "القمح الطري", "Soft wheat", "Blé tendre"),
    ("durumwheat", "cereal", "Poaceae", False, (11, 15), (30, 60, 60, 40), (0.40, 1.15, 0.30), 1.5, 0.55, 1.0, "cereal", "#E6B94E", "#B8791A", "القمح الصلب", "القمح الصلب", "Durum wheat", "Blé dur"),
    ("barley", "cereal", "Poaceae", False, (11, 15), (25, 55, 55, 35), (0.30, 1.15, 0.25), 1.3, 0.55, 1.0, "cereal", "#D9C26A", "#9E8A2F", "الشعير", "الشعير", "Barley", "Orge"),
    ("oats", "cereal", "Poaceae", False, (11, 15), (25, 55, 55, 35), (0.30, 1.15, 0.25), 1.3, 0.55, None, "cereal", "#D8D58A", "#8C8A3A", "الخرطال", "الشوفان", "Oats", "Avoine"),
    ("maize", "cereal", "Poaceae", False, (4, 15), (30, 40, 50, 30), (0.30, 1.20, 0.35), 1.0, 0.55, 1.25, "corn", "#E9D86A", "#D9A71C", "الذرة", "الذرة", "Maize", "Maïs"),
    ("sorghum", "cereal", "Poaceae", False, (5, 1), (20, 35, 40, 30), (0.30, 1.00, 0.55), 1.4, 0.55, 0.9, "corn", "#D9A27A", "#A8562A", "الذرة الرفيعة", "الذرة الرفيعة", "Sorghum", "Sorgho"),
    ("fava", "legume", "Fabaceae", True, (11, 15), (25, 35, 45, 35), (0.50, 1.15, 0.30), 0.8, 0.45, 1.15, "bean", "#8FC26A", "#3F7F2E", "الفول", "الفول", "Fava beans", "Fèves"),
    ("chickpea", "legume", "Fabaceae", True, (11, 30), (20, 35, 45, 25), (0.40, 1.00, 0.35), 0.8, 0.50, None, "bean", "#E0C48A", "#B68A3C", "الحمص", "الحمص", "Chickpea", "Pois chiche"),
    ("lentil", "legume", "Fabaceae", True, (11, 30), (20, 30, 40, 25), (0.40, 1.10, 0.30), 0.6, 0.50, None, "bean", "#D39A6A", "#8E4A22", "العدس", "العدس", "Lentils", "Lentilles"),
    ("pea", "legume", "Fabaceae", True, (11, 15), (20, 30, 35, 20), (0.50, 1.15, 0.30), 0.8, 0.35, 1.15, "bean", "#9FD27A", "#4C9A34", "الجلبانة", "البازلاء", "Peas", "Petits pois"),
    ("onion", "veg", "Amaryllidaceae", False, (12, 1), (15, 25, 70, 40), (0.70, 1.05, 0.75), 0.4, 0.30, 1.1, "root", "#E3B2C7", "#9A4F73", "البصلة", "البصل", "Onion", "Oignon"),
    ("garlic", "veg", "Amaryllidaceae", False, (11, 15), (20, 30, 80, 40), (0.70, 1.00, 0.70), 0.4, 0.30, None, "root", "#E8DCC8", "#B9A27C", "التوم", "الثوم", "Garlic", "Ail"),
    ("potato", "veg", "Solanaceae", False, (2, 15), (25, 30, 45, 30), (0.50, 1.15, 0.75), 0.5, 0.35, 1.1, "root", "#D9B987", "#7A5A2B", "البطاطا", "البطاطس", "Potato", "Pomme de terre"),
    ("carrot", "veg", "Apiaceae", False, (10, 15), (20, 30, 50, 20), (0.70, 1.05, 0.95), 0.5, 0.35, None, "root", "#F1C79A", "#E0762B", "الخيزو", "الجزر", "Carrot", "Carotte"),
    ("tomato", "veg", "Solanaceae", False, (3, 15), (30, 40, 45, 30), (0.60, 1.15, 0.80), 0.7, 0.40, 1.05, "fruitveg", "#F2B8A8", "#D8402B", "الماطيشة", "الطماطم", "Tomato", "Tomate"),
    ("pepper", "veg", "Solanaceae", False, (3, 15), (30, 35, 40, 20), (0.60, 1.05, 0.90), 0.6, 0.30, 1.1, "fruitveg", "#F1D49A", "#D8402B", "الفلفلة", "الفلفل", "Pepper", "Poivron"),
    ("courgette", "veg", "Cucurbitaceae", False, (3, 15), (20, 30, 25, 15), (0.50, 0.95, 0.75), 0.6, 0.50, None, "fruitveg", "#BFE0A0", "#3F8A2E", "القرعة", "الكوسا", "Courgette", "Courgette"),
    ("cabbage", "veg", "Brassicaceae", False, (10, 15), (40, 60, 50, 15), (0.70, 1.05, 0.95), 0.5, 0.45, 0.95, "leaf", "#CDE6C4", "#5FA24A", "الكرنب", "الملفوف", "Cabbage", "Chou"),
    ("watermelon", "veg", "Cucurbitaceae", False, (4, 1), (20, 30, 30, 30), (0.40, 1.00, 0.75), 0.8, 0.40, 1.1, "melon", "#BEE3A8", "#2F8A3E", "الدلاح", "البطيخ الأحمر", "Watermelon", "Pastèque"),
    ("melon", "veg", "Cucurbitaceae", False, (4, 1), (25, 35, 40, 20), (0.50, 1.05, 0.75), 0.8, 0.40, 0.9, "melon", "#F4E3A0", "#E2A92B", "الشمام", "الشمام", "Melon", "Melon"),
    ("sunflower", "industrial", "Asteraceae", False, (3, 15), (25, 35, 45, 25), (0.35, 1.00, 0.35), 1.2, 0.45, 0.95, "sun", "#F6E39A", "#F0B400", "عباد الشمس", "دوار الشمس", "Sunflower", "Tournesol"),
    ("rapeseed", "industrial", "Brassicaceae", False, (10, 20), (30, 50, 60, 30), (0.35, 1.15, 0.35), 1.0, 0.60, None, "sun", "#EEF0A0", "#E7C700", "الكولزا", "اللفت الزيتي", "Rapeseed", "Colza"),
    ("sugarbeet", "industrial", "Chenopodiaceae", False, (10, 15), (30, 45, 90, 50), (0.35, 1.20, 0.70), 1.2, 0.55, 1.0, "root", "#E9C7D2", "#8A3A5B", "الشمندر السكري", "الشمندر السكري", "Sugar beet", "Betterave sucrière"),
    ("alfalfa", "industrial", "Fabaceae", True, (10, 1), (20, 50, 150, 40), (0.40, 1.20, 1.15), 1.5, 0.55, 1.1, "forage", "#C4E6A8", "#4C9A34", "الفصة", "البرسيم الحجازي", "Alfalfa", "Luzerne"),
    ("olive", "tree", "Oleaceae", False, None, None, None, None, None, None, "tree", "#DCE7C8", "#6B7F2E", "الزيتون", "الزيتون", "Olive", "Olivier"),
    ("almond", "tree", "Rosaceae", False, None, None, None, None, None, None, "tree", "#F4E6E8", "#C9A07A", "اللوز", "اللوز", "Almond", "Amandier"),
    ("grape", "tree", "Vitaceae", False, None, None, None, None, None, None, "vine", "#E5D3EE", "#6B3F86", "العنب", "العنب", "Grape", "Vigne"),
    ("fig", "tree", "Moraceae", False, None, None, None, None, None, None, "tree", "#E8E0EE", "#6A3F5B", "الكرموس", "التين", "Fig", "Figuier"),
    ("citrus", "tree", "Rutaceae", False, None, None, None, None, None, None, "tree", "#FBE6B8", "#F28C1B", "الحوامض", "الحمضيات", "Citrus", "Agrumes"),
    ("apple", "tree", "Rosaceae", False, None, None, None, None, None, None, "tree", "#F6D5D0", "#D8402B", "التفاح", "التفاح", "Apple", "Pommier"),
    ("pomegranate", "tree", "Lythraceae", False, None, None, None, None, None, None, "tree", "#F3C7C4", "#B52A2A", "الرمان", "الرمان", "Pomegranate", "Grenadier"),
    ("plum", "tree", "Rosaceae", False, None, None, None, None, None, None, "tree", "#E3D0EC", "#7A3F9A", "البرقوق", "البرقوق", "Plum", "Prunier"),
]

out = []
for (id_, cat, fam, leg, sow, st, kc, zr, p, ky, kind, c1, c2, dar, ar, en, fr) in R:
    annual = cat != "tree"
    out.append({
        "id": id_, "category": cat, "family": fam, "annual": annual, "legume": leg,
        "photo": f"assets/images/crops/{id_}.jpg", "kind": kind, "c1": c1, "c2": c2,
        "names": {"dar": dar, "ar": ar, "en": en, "fr": fr},
        # FAO-56 / FAO-33 parameters. verified:false until checked by a person.
        "model": None if not annual else {
            "sow": {"month": sow[0], "day": sow[1]},
            "stages": {"ini": st[0], "dev": st[1], "mid": st[2], "late": st[3]},
            "kc": {"ini": kc[0], "mid": kc[1], "end": kc[2]},
            "zrMax": zr, "p": p,
            "ky": ky,  # null = no FAO-33 value: excluded from recommendations
            "verified": False,
        },
        "reviewed": False,
    })
root = Path(__file__).resolve().parent.parent / "assets" / "data"
(root / "crops.json").write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")

rules = {
    "_note": "Rotation rules live in data, not code. Sources are TODO(source) (docs/SOURCES.md). "
             "Rules only raise a visible flag; no yield number is changed by an unsourced rule.",
    "sameFamilyFlag": {"severity": "caution", "source": "TODO(source)",
                       "reason": "Same botanical family two seasons in a row can build up pests and diseases."},
    "strongAvoid": [{"family": "Solanaceae", "after": "Solanaceae", "severity": "caution", "source": "TODO(source)"}],
    "legumeCredit": {"affectsWater": False, "source": "TODO(source)",
                     "note": "A legume can leave nitrogen for the next crop. This changes fertiliser need, not water need, so SAMA does not change water or yield for it."},
}
(root / "rotation_rules.json").write_text(json.dumps(rules, ensure_ascii=False, indent=1), encoding="utf-8")
print("wrote", len(out), "crops; excluded (ky null):", [r[0] for r in R if r[1] != "tree" and r[9] is None])
