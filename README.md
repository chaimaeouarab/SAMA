# SAMA — سما

*The sky still tells us when to plant.* Decision support for Moroccan farmers, built on 40 years of NASA POWER data and FAO-56 / FAO-33
formulas. It shows chances over 40 real past seasons: **not a forecast and not a guarantee**. Offline-first; Darija, Arabic, English, French.

## What it does
Farm location (GPS, search, map, coordinates) · ET0 / soil-water / yield model (docs/MODEL.md) · **Time Machine** (3 rotations on real
seasons) · **Climate Shock Lab** (what-if, always labelled) · **Detective** (asks one question, only when it matters) · **Satellite Lens**
(NASA GIBS images + a transparent regional comparison) · voice in/out in 4 languages · Farmer and Advisor modes.
**Agronomic parameters are provisional until a person has checked them** (docs/SOURCES.md); the app says so on every result.

## Run
```bash
flutter pub get
flutter run -d chrome        # or an Android device / emulator
```
Optional (never commit keys):
```bash
flutter run --dart-define=SAMA_TILE_URL=https://your-tiles/{z}/{x}/{y}.png --dart-define=SAMA_TILE_ATTRIBUTION="© provider" --dart-define=SAMA_TTS_URL=https://your-server/tts
```
Without `SAMA_TILE_URL` the farm screen shows an accessible list instead of a map.

## Check and build
```bash
flutter analyze
flutter test
flutter build apk --release   # needs the Android NDK, see docs/OPEN_ITEMS.md
```

## Data, scripts and docs
| what | how |
|---|---|
| NASA data (15 points) | `python scripts/fetch_nasa_power.py` → `assets/data/nasa_power.json` |
| audit | `python scripts/audit_data.py [--online boufakrane erfoud]` → docs/DATA_AUDIT_RESULTS.md |
| crops + rules | `python scripts/build_crops_json.py` |
| phrases + review CSV | `python scripts/build_phrases_json.py` |
| voice clips | `python scripts/build_phrase_audio.py --space <owner/name>` (you run it) |
| docs | MODEL · SOURCES · DATA_AUDIT · OPEN_ITEMS · VOICE_TESTS · DEMO · IMAGE_CREDITS · PHASE2 (the brief) |

## Map of the code
`lib/core` theme, strings (4 languages), constants · `lib/data` NASA data, places, crops, climate selection, NASA client + cache ·
`lib/domain` pure model (et0, crop_model, outcome_matrix, monte_carlo, rotation, detective, scenarios) · `lib/state` farms, assumptions,
settings, model providers · `lib/voice` phrases, backends, player, intent matcher, STT · `lib/features` screens.
