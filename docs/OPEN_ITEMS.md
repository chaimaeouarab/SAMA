# Open items

Everything below is a `TODO(source)` or a decision still needed. Nothing here is shown in the UI as a fact.

## Data and model constants (lib/core/constants.dart)
| item | current value | needed |
|---|---|---|
| Effective-rain share | 0.65 | confirm source |
| Baseline stored/irrigation water Q | 2400 m³/ha | confirm source |
| Need factor | 0.8 | confirm source |
| Legume bonus on next crop's need | 0.9 | confirm source |
| Non-climate failure | 3 % | confirm source |
| Aquifer v and a | 3 m/yr, 0.30 | confirm source (shown as "scenario, not measurement") |
| Morocco UTC offset for sunrise/sunset | +1 all year | confirm |

## Crop water needs (assets/data/crops.json, `waterNeedM3PerHa`)
Placeholders from the brief, shown with a "provisional" note in the UI. Replace with values derived from
**FAO Irrigation and Drainage Paper 56 (Kc × ET0)** and cite the table here:

softwheat 4500, durumwheat 4500, barley 3500, oats 3500, maize 7000, sorghum 5500, fava 3500, chickpea 3000, lentil 2800, pea 3000,
onion 6500, garlic 5000, potato 6000, carrot 5000, tomato 6500, pepper 6500, courgette 5000, cabbage 5000, watermelon 5000, melon 5000,
sunflower 5000, rapeseed 4000, sugarbeet 7500, alfalfa 9000.

`sowMonths` is empty for every crop (not sourced). The Timing view therefore shows real monthly rain and says that exact sowing dates are not sourced yet.

## Observation about the model
With the brief's formula and constants, most light-water crops (cereals, legumes) are "good" in nearly every historical season at Boufakrane,
so their chance is about 90–97 % and many plans tie. This is a property of the placeholders, not a bug. It should be re-checked once the water needs and Q are sourced.

## Town coordinates (lib/data/towns.dart, scripts/fetch_nasa_power.py)
Approximate (Boufakrane 33.72,-5.30 · El Hajeb 33.69,-5.37 · Sebaa Aioun 33.85,-5.46 · Aïn Taoujdate 33.93,-4.77 · Mhaya 33.93,-5.43 · Erfoud 31.43,-4.23). Verify.

## Darija
All Darija text (UI strings, crop names, phrases, Latin transliterations sent to the TTS) is a draft, `reviewed:false`.
Review with `docs/darija_review.csv` (regenerate with `python scripts/build_phrases_json.py`). UI strings are in `lib/core/strings.dart` and are not in the CSV yet.

## Assets you provide
- Crop photos: `assets/images/crops/<id>.jpg`, exact names in `assets/images/crops/README.md`.
- Voice clips: run `python scripts/build_phrase_audio.py --space <owner/name>` (Darija) and the same script for EN/FR. Clips go to `assets/audio/{darija,en,fr}/male/`.
- Arabic font: bundle Noto Sans Arabic (or Naskh) in `assets/fonts` and declare it in `pubspec.yaml`; the theme already lists both as fallbacks.
- Own TTS endpoint: `--dart-define=SAMA_TTS_URL=...` (contract: POST JSON `{"text","lang"}` → audio bytes). Optional: `HF_TOKEN`, `HF_MODEL`.
- App icon and splash screen.

## Not implemented (by choice, needs a decision)
- **System Arabic TTS (opt-in)** and **English/French system TTS**: no TTS package is in the required stack. EN/FR use bundled clips made by the script; without clips the text is shown.
- **Voice "Auto-detect" language** (optional, off by default): needs raw audio recording and your own Whisper Space. The assistant uses `speech_to_text` fixed to the chosen language.
- **iOS localized permission strings**: Info.plist has one trilingual string per permission. Per-language `InfoPlist.strings` need the Xcode project.
- **Screenshot/golden check against the prototype at 360×800.**
- **Cold start < 2.5 s and 60 fps** were not measured on a device.
- **Sunrise/sunset** use standard NOAA formulas without refraction detail; display only.
