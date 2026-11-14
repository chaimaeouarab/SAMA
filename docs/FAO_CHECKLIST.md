# FAO checklist (fill this in, then correct `scripts/build_crops_json.py`)

Open the books and compare. **Nobody has verified these values yet.** Write the book value if different.
- Stage lengths: FAO-56 Table 11 (the app adapts them to Morocco; note any difference you accept).
- Kc ini / mid / end: FAO-56 Table 12.
- Zr max and p: FAO-56 Table 22.
- Ky: FAO-33 (yield response factor for the whole growing period). If a crop has no value: write `none`.
- Total available water 140 mm/m and fallow Kc 0.3: FAO-56 Table 19 and chapter 7 (see docs/SOURCES.md §C).

| crop | stages ini/dev/mid/late | Kc ini/mid/end | Zr max (m) | p | Ky | book values / OK | checked by |
|---|---|---|---|---|---|---|---|
| Soft wheat (`softwheat`) | 30/60/60/40 | 0.4/1.15/0.3 | 1.5 | 0.55 | 1.0 | ☐ | |
| Durum wheat (`durumwheat`) | 30/60/60/40 | 0.4/1.15/0.3 | 1.5 | 0.55 | 1.0 | ☐ | |
| Barley (`barley`) | 25/55/55/35 | 0.3/1.15/0.25 | 1.3 | 0.55 | 1.0 | ☐ | |
| Oats (`oats`) | 25/55/55/35 | 0.3/1.15/0.25 | 1.3 | 0.55 | none | ☐ | |
| Maize (`maize`) | 30/40/50/30 | 0.3/1.2/0.35 | 1.0 | 0.55 | 1.25 | ☐ | |
| Sorghum (`sorghum`) | 20/35/40/30 | 0.3/1.0/0.55 | 1.4 | 0.55 | 0.9 | ☐ | |
| Fava beans (`fava`) | 25/35/45/35 | 0.5/1.15/0.3 | 0.8 | 0.45 | 1.15 | ☐ | |
| Chickpea (`chickpea`) | 20/35/45/25 | 0.4/1.0/0.35 | 0.8 | 0.5 | none | ☐ | |
| Lentils (`lentil`) | 20/30/40/25 | 0.4/1.1/0.3 | 0.6 | 0.5 | none | ☐ | |
| Peas (`pea`) | 20/30/35/20 | 0.5/1.15/0.3 | 0.8 | 0.35 | 1.15 | ☐ | |
| Onion (`onion`) | 15/25/70/40 | 0.7/1.05/0.75 | 0.4 | 0.3 | 1.1 | ☐ | |
| Garlic (`garlic`) | 20/30/80/40 | 0.7/1.0/0.7 | 0.4 | 0.3 | none | ☐ | |
| Potato (`potato`) | 25/30/45/30 | 0.5/1.15/0.75 | 0.5 | 0.35 | 1.1 | ☐ | |
| Carrot (`carrot`) | 20/30/50/20 | 0.7/1.05/0.95 | 0.5 | 0.35 | none | ☐ | |
| Tomato (`tomato`) | 30/40/45/30 | 0.6/1.15/0.8 | 0.7 | 0.4 | 1.05 | ☐ | |
| Pepper (`pepper`) | 30/35/40/20 | 0.6/1.05/0.9 | 0.6 | 0.3 | 1.1 | ☐ | |
| Courgette (`courgette`) | 20/30/25/15 | 0.5/0.95/0.75 | 0.6 | 0.5 | none | ☐ | |
| Cabbage (`cabbage`) | 40/60/50/15 | 0.7/1.05/0.95 | 0.5 | 0.45 | 0.95 | ☐ | |
| Watermelon (`watermelon`) | 20/30/30/30 | 0.4/1.0/0.75 | 0.8 | 0.4 | 1.1 | ☐ | |
| Melon (`melon`) | 25/35/40/20 | 0.5/1.05/0.75 | 0.8 | 0.4 | 0.9 | ☐ | |
| Sunflower (`sunflower`) | 25/35/45/25 | 0.35/1.0/0.35 | 1.2 | 0.45 | 0.95 | ☐ | |
| Rapeseed (`rapeseed`) | 30/50/60/30 | 0.35/1.15/0.35 | 1.0 | 0.6 | none | ☐ | |
| Sugar beet (`sugarbeet`) | 30/45/90/50 | 0.35/1.2/0.7 | 1.2 | 0.55 | 1.0 | ☐ | |
| Alfalfa (`alfalfa`) | 20/50/150/40 | 0.4/1.2/1.15 | 1.5 | 0.55 | 1.1 | ☐ | |

Sowing dates (SAMA assumptions for Morocco, not in the FAO tables): validate with an agronomist or the regional extension service (ORMVA).

| crop | sowing day/month | OK / correction |
|---|---|---|
| Soft wheat | 15/11 | ☐ |
| Durum wheat | 15/11 | ☐ |
| Barley | 15/11 | ☐ |
| Oats | 15/11 | ☐ |
| Maize | 15/4 | ☐ |
| Sorghum | 1/5 | ☐ |
| Fava beans | 15/11 | ☐ |
| Chickpea | 30/11 | ☐ |
| Lentils | 30/11 | ☐ |
| Peas | 15/11 | ☐ |
| Onion | 1/12 | ☐ |
| Garlic | 15/11 | ☐ |
| Potato | 15/2 | ☐ |
| Carrot | 15/10 | ☐ |
| Tomato | 15/3 | ☐ |
| Pepper | 15/3 | ☐ |
| Courgette | 15/3 | ☐ |
| Cabbage | 15/10 | ☐ |
| Watermelon | 1/4 | ☐ |
| Melon | 1/4 | ☐ |
| Sunflower | 15/3 | ☐ |
| Rapeseed | 20/10 | ☐ |
| Sugar beet | 15/10 | ☐ |
| Alfalfa | 1/10 | ☐ |
