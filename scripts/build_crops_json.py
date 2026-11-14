"""Generate assets/data/crops.json (names reused from docs/prototype.html).
Water needs are PLACEHOLDERS (TODO(source): FAO-56 Kc x ET0). Darija is a draft (reviewed:false).
"""
import json
from pathlib import Path

# id, category, kind (illustration), c1, c2, water m3/ha, ar, en, fr
ROWS = [
    ("softwheat", "cereal", "cereal", "#EBC45A", "#C98A1C", 4500, "القمح اللين", "Soft wheat", "Blé tendre"),
    ("durumwheat", "cereal", "cereal", "#E6B94E", "#B8791A", 4500, "القمح الصلب", "Durum wheat", "Blé dur"),
    ("barley", "cereal", "cereal", "#D9C26A", "#9E8A2F", 3500, "الشعير", "Barley", "Orge"),
    ("oats", "cereal", "cereal", "#D8D58A", "#8C8A3A", 3500, "الخرطال", "Oats", "Avoine"),
    ("maize", "cereal", "corn", "#E9D86A", "#D9A71C", 7000, "الذرة", "Maize", "Maïs"),
    ("sorghum", "cereal", "corn", "#D9A27A", "#A8562A", 5500, "الذرة الرفيعة", "Sorghum", "Sorgho"),
    ("fava", "legume", "bean", "#8FC26A", "#3F7F2E", 3500, "الفول", "Fava beans", "Fèves"),
    ("chickpea", "legume", "bean", "#E0C48A", "#B68A3C", 3000, "الحمص", "Chickpea", "Pois chiche"),
    ("lentil", "legume", "bean", "#D39A6A", "#8E4A22", 2800, "العدس", "Lentils", "Lentilles"),
    ("pea", "legume", "bean", "#9FD27A", "#4C9A34", 3000, "الجلبانة", "Peas", "Petits pois"),
    ("onion", "veg", "root", "#E3B2C7", "#9A4F73", 6500, "البصلة", "Onion", "Oignon"),
    ("garlic", "veg", "root", "#E8DCC8", "#B9A27C", 5000, "التوم", "Garlic", "Ail"),
    ("potato", "veg", "root", "#D9B987", "#7A5A2B", 6000, "البطاطا", "Potato", "Pomme de terre"),
    ("carrot", "veg", "root", "#F1C79A", "#E0762B", 5000, "الخيزو", "Carrot", "Carotte"),
    ("tomato", "veg", "fruitveg", "#F2B8A8", "#D8402B", 6500, "الماطيشة", "Tomato", "Tomate"),
    ("pepper", "veg", "fruitveg", "#F1D49A", "#D8402B", 6500, "الفلفلة", "Pepper", "Poivron"),
    ("courgette", "veg", "fruitveg", "#BFE0A0", "#3F8A2E", 5000, "القرعة", "Courgette", "Courgette"),
    ("cabbage", "veg", "leaf", "#CDE6C4", "#5FA24A", 5000, "الكرنب", "Cabbage", "Chou"),
    ("watermelon", "veg", "melon", "#BEE3A8", "#2F8A3E", 5000, "الدلاح", "Watermelon", "Pastèque"),
    ("melon", "veg", "melon", "#F4E3A0", "#E2A92B", 5000, "الشمام", "Melon", "Melon"),
    ("sunflower", "industrial", "sun", "#F6E39A", "#F0B400", 5000, "عباد الشمس", "Sunflower", "Tournesol"),
    ("rapeseed", "industrial", "sun", "#EEF0A0", "#E7C700", 4000, "الكولزا", "Rapeseed", "Colza"),
    ("sugarbeet", "industrial", "root", "#E9C7D2", "#8A3A5B", 7500, "الشمندر السكري", "Sugar beet", "Betterave sucrière"),
    ("alfalfa", "industrial", "forage", "#C4E6A8", "#4C9A34", 9000, "الفصة", "Alfalfa", "Luzerne"),
    ("olive", "tree", "tree", "#DCE7C8", "#6B7F2E", None, "الزيتون", "Olive", "Olivier"),
    ("almond", "tree", "tree", "#F4E6E8", "#C9A07A", None, "اللوز", "Almond", "Amandier"),
    ("grape", "tree", "vine", "#E5D3EE", "#6B3F86", None, "العنب", "Grape", "Vigne"),
    ("fig", "tree", "tree", "#E8E0EE", "#6A3F5B", None, "الكرموس", "Fig", "Figuier"),
    ("citrus", "tree", "tree", "#FBE6B8", "#F28C1B", None, "الحوامض", "Citrus", "Agrumes"),
    ("apple", "tree", "tree", "#F6D5D0", "#D8402B", None, "التفاح", "Apple", "Pommier"),
    ("pomegranate", "tree", "tree", "#F3C7C4", "#B52A2A", None, "الرمان", "Pomegranate", "Grenadier"),
    ("plum", "tree", "tree", "#E3D0EC", "#7A3F9A", None, "البرقوق", "Plum", "Prunier"),
]

out = []
for id_, cat, kind, c1, c2, w, ar, en, fr in ROWS:
    out.append({
        "id": id_, "category": cat, "annual": cat != "tree",
        "legume": cat == "legume",
        "waterNeedM3PerHa": w,  # TODO(source): FAO-56
        "sowMonths": [],  # TODO(source)
        "photo": f"assets/images/crops/{id_}.jpg",
        "kind": kind, "c1": c1, "c2": c2,
        "names": {"ar": ar, "en": en, "fr": fr},
        "reviewed": False,
    })
path = Path(__file__).resolve().parent.parent / "assets" / "data" / "crops.json"
path.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
print("wrote", len(out), "crops")
