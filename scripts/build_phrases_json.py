"""Generate assets/data/phrases.json and docs/darija_review.csv (Darija AND Modern Standard Arabic).

phrases.json is the closed phrase catalogue used by the voice layer:
  id -> {dar (display Darija), latin (sent to the Darija TTS), ar (display MSA), en, fr, reviewed}
All Darija and Arabic is a DRAFT (reviewed:false) until a native speaker approves it: fill the
`reviewed`/`reviewer` columns of docs/darija_review.csv, then set reviewed in this script.
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

NUMS = [  # dar, latin, ar, en, fr
    ("صفر", "sifr", "صفر", "zero", "zéro"), ("واحد", "wa7ed", "واحد", "one", "un"),
    ("جوج", "jouj", "اثنان", "two", "deux"), ("تلاتة", "tlata", "ثلاثة", "three", "trois"),
    ("ربعة", "rb3a", "أربعة", "four", "quatre"), ("خمسة", "khamsa", "خمسة", "five", "cinq"),
    ("ستة", "stta", "ستة", "six", "six"), ("سبعة", "sb3a", "سبعة", "seven", "sept"),
    ("تمنية", "tmnya", "ثمانية", "eight", "huit"), ("تسعود", "ts3oud", "تسعة", "nine", "neuf"),
    ("عشرة", "3chra", "عشرة", "ten", "dix"),
]

# id -> (dar, latin, ar, en, fr)
P = {}
for c in crops:
    n = c["names"]
    P[f"crop.{c['id']}"] = (n["dar"], CROP_LATIN[c["id"]], n["ar"], n["en"], n["fr"])
for i, n in enumerate(NUMS):
    P[f"num.{i}"] = n
P.update({
    "lang.dar": ("الدارجة", "ddarija", "الدارجة المغربية", "Moroccan Darija", "Darija marocaine"),
    "lang.ar": ("العربية", "l3arabia", "العربية الفصحى", "Arabic", "Arabe"),
    "lang.en": ("الإنجليزية", "inglizia", "الإنجليزية", "English", "Anglais"),
    "lang.fr": ("الفرنسية", "fransawia", "الفرنسية", "French", "Français"),
    "greet.morning": ("صباح الخير", "sba7 lkhir", "صباح الخير", "Good morning", "Bonjour"),
    "greet.afternoon": ("نهارك سعيد", "nharek sa3id", "طاب يومك", "Good afternoon", "Bon après-midi"),
    "greet.evening": ("مساء الخير", "msa lkhir", "مساء الخير", "Good evening", "Bonsoir"),
    "word.outof": ("من", "men", "من", "in", "sur"),
    "adv.chance": ("حظ موسم مزيان", "7ad mousim mziyan", "فرصة موسم جيد", "chance of a good season", "chance de bonne saison"),
    "adv.rot3": ("حظ 3 مواسم مزيانين", "7ad tlata mwassem mziyanin", "فرصة ثلاثة مواسم جيدة", "chance of three good seasons", "chance de trois bonnes saisons"),
    "adv.not_guarantee": ("ماشي ضمانة", "machi damana", "ليس ضمانا", "Not a guarantee", "Pas une garantie"),
    "wx.intro": ("الجو المعتاد فهاد النهار", "ljaw lm3tad f had nnhar", "الطقس المعتاد لهذا اليوم", "Typical weather for today", "Météo typique d'aujourd'hui"),
    "wx.note": ("ماشي توقعات", "machi tawaqo3at", "ليس توقعا", "Not a live forecast", "Pas une prévision"),
    "farm.choose": ("اختار الفلاحة ديالك", "ikhtar lfla7a dyalek", "اختر مزرعتك", "Choose your farm", "Choisissez votre ferme"),
    "farm.selected": ("الفلاحة ديالك تختارات. يالله نشوفو الخيارات", "lfla7a dyalek tkhtarat. yalah nchoufo lkhiyarat", "تم اختيار مزرعتك. لنستكشف خياراتك", "Your farm is selected. Let's explore your options", "Votre ferme est sélectionnée. Explorons vos options"),
    "ans.crop": ("هادو أحسن الزراعات ليك", "hadou a7sen zzra3at lik", "هذه أفضل المحاصيل لك", "These are the best crops for you", "Voici les meilleures cultures pour vous"),
    "ans.water": ("هادا هو الما اللي خاص لكل زراعة", "hada howa lma lli khass l kol zra3a", "هذا هو الماء الذي يحتاجه كل محصول", "This is the water each crop needs", "Voici l'eau nécessaire pour chaque culture"),
    "ans.timing": ("هادا هو الشتا شهر بشهر", "hada howa chta chhar b chhar", "هذا هو المطر شهرا بشهر", "This is the rain month by month", "Voici la pluie mois par mois"),
    "ans.risk": ("هادا هو الخطر ديال المواسم الصعيبة", "hada howa lkhatar d lmawassem ssa3iba", "هذه مخاطر المواسم الصعبة", "This is the risk of hard seasons", "Voici le risque de saisons difficiles"),
    "ans.field": ("بدل الفلاحة ديالك", "bddel lfla7a dyalek", "غيّر مزرعتك", "Change your field", "Changez votre champ"),
    "ans.rotation": ("هادا أحسن تناوب ليك", "hada a7sen tanaoub lik", "هذا أفضل تناوب لك", "This is the best rotation for you", "Voici la meilleure rotation pour vous"),
    "ans.lessrain": ("غادي نشوفو شنو إلا قلت الشتا ب 20 فالمية. هادا سيناريو ماشي حقيقة", "ghadi nchoufo chno ila 9allat chta b 20 f lmia. hada senario machi 7a9i9a", "نفعّل سيناريو: مطر أقل بنسبة عشرين بالمئة. هذا افتراض وليس رصدا", "Less rain scenario: 20 percent less rain. This is a what-if, not an observation", "Scénario : 20 pour cent de pluie en moins. C'est une hypothèse, pas une observation"),
    "ans.explain": ("هادا علاش: 40 موسم حقيقي من ناسا", "hada 3lach: 40 mousim 7a9i9i men nasa", "هذا هو السبب: 40 موسما حقيقيا من بيانات ناسا", "This is why: 40 real seasons of NASA data", "Voici pourquoi : 40 saisons réelles de données NASA"),
    "ui.not_understood": ("ما فهمتش", "ma fhemtch", "لم أفهم", "I did not understand", "Je n'ai pas compris"),
    "ui.help": ("تقدر تقول: شنو نزرع، شحال ديال الما، شنو إلا قلت الشتا، ولا شنو أحسن تناوب", "t9der t9ol: chno nzra3, chhal d lma, chno ila 9allat chta, wla chno a7sen tanaoub",
                "يمكنك أن تقول: ماذا أزرع، كم من الماء، ماذا لو قلّ المطر، أو ما أفضل تناوب",
                "You can say: which crop, how much water, what if there is less rain, or which rotation",
                "Vous pouvez dire : quelle culture, combien d'eau, et s'il pleut moins, ou quelle rotation"),
})
PLACES = [("boufakrane", "بوفكران", "بوفكران", "boufkran", "Boufakrane", "Boufakrane"),
          ("elhajeb", "الحاجب", "الحاجب", "l7ajeb", "El Hajeb", "El Hajeb"),
          ("sebaaaioun", "سبع عيون", "سبع عيون", "sb3 3youn", "Sebaa Aioun", "Sebaa Aioun"),
          ("aintaoujdate", "عين تاوجطات", "عين تاوجدات", "3in taoujtat", "Aïn Taoujdate", "Aïn Taoujdate"),
          ("mhaya", "مهاية", "مهاية", "mhaya", "Mhaya", "Mhaya"),
          ("meknes", "مكناس", "مكناس", "meknas", "Meknès", "Meknès"),
          ("erfoud", "أرفود", "أرفود", "erfoud", "Erfoud", "Erfoud")]
for pid, dar, ar, latin, en, fr in PLACES:
    P[f"place.{pid}"] = (dar, latin, ar, en, fr)

out = {k: {"dar": v[0], "latin": v[1], "ar": v[2], "en": v[3], "fr": v[4], "reviewed": False} for k, v in P.items()}
(ROOT / "assets/data/phrases.json").write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")

with open(ROOT / "docs/darija_review.csv", "w", encoding="utf-8-sig", newline="") as f:
    w = csv.writer(f)
    w.writerow(["key", "dar", "latin", "ar", "en", "fr", "reviewed", "reviewer"])
    for k, v in out.items():
        w.writerow([k, v["dar"], v["latin"], v["ar"], v["en"], v["fr"], "false", ""])
    # UI strings of lib/core/strings.dart are exported by scripts/export_ui_strings.py
print("phrases:", len(out))
