"""Generate assets/data/phrases.json and docs/darija_review.csv.

phrases.json is the closed phrase catalogue used by the voice layer:
  id -> {ar (display), latin (sent to the Darija TTS), en, fr, reviewed}
All Darija is a DRAFT (reviewed:false) until a native speaker approves it:
fill the `reviewed`/`reviewer` columns of docs/darija_review.csv, then set reviewed in this script.
"""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
crops = json.loads((ROOT / "assets/data/crops.json").read_text(encoding="utf-8"))

# draft Latin-script Darija for the crop names (TTS input)
CROP_LATIN = {
    "softwheat": "l9mh llin", "durumwheat": "l9mh sslb", "barley": "chi3ir", "oats": "lkhertal",
    "maize": "ddra", "sorghum": "ddra rfi3a", "fava": "lfoul", "chickpea": "lhommos", "lentil": "l3dss",
    "pea": "ljilbana", "onion": "lbasla", "garlic": "ttoum", "potato": "lbatata", "carrot": "lkhizzou",
    "tomato": "lmatisha", "pepper": "lflifla", "courgette": "l9r3a", "cabbage": "lkrnb",
    "watermelon": "ddlla7", "melon": "chmam", "sunflower": "3bbad chchams", "rapeseed": "lkolza",
    "sugarbeet": "chmandar ssokkari", "alfalfa": "lfesa", "olive": "zzitoun", "almond": "llouz",
    "grape": "l3nb", "fig": "lkarmous", "citrus": "l7wamed", "apple": "ttfa7", "pomegranate": "rrmman",
    "plum": "lbarqouq",
}

NUMS = [  # ar, latin, en, fr
    ("صفر", "sifr", "zero", "zéro"), ("واحد", "wa7ed", "one", "un"), ("جوج", "jouj", "two", "deux"),
    ("تلاتة", "tlata", "three", "trois"), ("ربعة", "rb3a", "four", "quatre"), ("خمسة", "khamsa", "five", "cinq"),
    ("ستة", "stta", "six", "six"), ("سبعة", "sb3a", "seven", "sept"), ("تمنية", "tmnya", "eight", "huit"),
    ("تسعود", "ts3oud", "nine", "neuf"), ("عشرة", "3chra", "ten", "dix"),
]

# id -> (ar, latin, en, fr)
P = {}
for c in crops:
    n = c["names"]
    P[f"crop.{c['id']}"] = (n["ar"], CROP_LATIN[c["id"]], n["en"], n["fr"])
for i, n in enumerate(NUMS):
    P[f"num.{i}"] = n
P.update({
    "lang.ar": ("الدارجة", "ddarija", "Darija", "Darija"),
    "lang.en": ("الإنجليزية", "inglizia", "English", "Anglais"),
    "lang.fr": ("الفرنسية", "fransawia", "French", "Français"),
    "greet.morning": ("صباح الخير", "sba7 lkhir", "Good morning", "Bonjour"),
    "greet.afternoon": ("نهارك سعيد", "nharek sa3id", "Good afternoon", "Bon après-midi"),
    "greet.evening": ("مساء الخير", "msa lkhir", "Good evening", "Bonsoir"),
    "word.outof": ("من", "men", "in", "sur"),
    "adv.chance": ("حظ موسم مزيان", "7ad mousim mziyan", "chance of a good season", "chance de bonne saison"),
    "adv.not_guarantee": ("ماشي ضمانة", "machi damana", "Not a guarantee", "Pas une garantie"),
    "wx.intro": ("الجو المعتاد فهاد النهار", "ljaw lm3tad f had nnhar", "Typical weather for today", "Météo typique d'aujourd'hui"),
    "wx.note": ("ماشي توقعات", "machi tawaqo3at", "Not a live forecast", "Pas une prévision"),
    "ans.crop": ("هادو أحسن الزراعات ليك", "hadou a7sen zzra3at lik", "These are the best crops for you", "Voici les meilleures cultures pour vous"),
    "ans.water": ("هادا هو الما اللي خاص لكل زراعة", "hada howa lma lli khass l kol zra3a", "This is the water each crop needs", "Voici l'eau nécessaire pour chaque culture"),
    "ans.timing": ("هادا هو الشتا شهر بشهر", "hada howa chta chhar b chhar", "This is the rain month by month", "Voici la pluie mois par mois"),
    "ans.risk": ("هادا هو الخطر ديال المواسم الناشفة", "hada howa lkhatar d lmawassem nnachfa", "This is the risk of dry seasons", "Voici le risque de saisons sèches"),
    "ans.field": ("بدل الفلاحة ديالك", "bddel lfla7a dyalek", "Change your field", "Changez votre champ"),
    "ui.not_understood": ("ما فهمتش", "ma fhemtch", "I did not understand", "Je n'ai pas compris"),
    "ui.help": ("تقدر تقول: شنو نزرع، شحال ديال الما، فاش نزرع، ولا شنو الخطر", "t9der t9ol: chno nzra3, chhal d lma, fach nzra3, wla chno lkhatar",
                "You can say: which crop, how much water, when to plant, or what risk", "Vous pouvez dire : quelle culture, combien d'eau, quand semer ou quel risque"),
})
for t in [("boufakrane", "بوفكران", "boufkran"), ("elhajeb", "الحاجب", "l7ajeb"), ("sebaaaioun", "سبع عيون", "sb3 3youn"),
          ("aintaoujdate", "عين تاوجطات", "3in taoujtat"), ("mhaya", "مهاية", "mhaya"), ("erfoud", "أرفود", "erfoud")]:
    P[f"place.{t[0]}"] = (t[1], t[2], {"boufakrane": "Boufakrane", "elhajeb": "El Hajeb", "sebaaaioun": "Sebaa Aioun",
                                       "aintaoujdate": "Aïn Taoujdate", "mhaya": "Mhaya", "erfoud": "Erfoud"}[t[0]],
                          {"aintaoujdate": "Aïn Taoujdate"}.get(t[0], {"elhajeb": "El Hajeb", "sebaaaioun": "Sebaa Aioun"}.get(t[0], t[0].capitalize())))

out = {k: {"ar": v[0], "latin": v[1], "en": v[2], "fr": v[3], "reviewed": False} for k, v in P.items()}
(ROOT / "assets/data/phrases.json").write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")

with open(ROOT / "docs/darija_review.csv", "w", encoding="utf-8-sig", newline="") as f:
    w = csv.writer(f)
    w.writerow(["key", "ar", "latin", "en", "fr", "reviewed", "reviewer"])
    for k, v in out.items():
        w.writerow([k, v["ar"], v["latin"], v["en"], v["fr"], "false", ""])
print("phrases:", len(out))
