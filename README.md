# SAMA — سما

*The sky still tells us when to plant.* A decision-support app for farmers of the Saïs plain (Meknès), built on 40 years of NASA POWER rainfall.
It is statistics on 40 past seasons, **not** a forecast and not a guarantee. Offline-first; Darija, English, French.

## Run
```bash
flutter pub get
flutter run
```
Optional voice backends (never commit keys):
```bash
flutter run --dart-define=SAMA_TTS_URL=https://your-server/tts --dart-define=HF_TOKEN=... --dart-define=HF_MODEL=...
```

## Test and check
```bash
flutter analyze
flutter test
```

## Build
```bash
flutter build apk --release
```

## Data and assets
| what | how |
|---|---|
| NASA data | `python scripts/fetch_nasa_power.py` → `assets/data/sais_power.json` (already generated) |
| Crops | `python scripts/build_crops_json.py` → `assets/data/crops.json` |
| Phrases + review CSV | `python scripts/build_phrases_json.py` → `assets/data/phrases.json`, `docs/darija_review.csv` |
| Voice clips | `python scripts/build_phrase_audio.py --space <owner/name>` (you run it) |
| Crop photos | drop `assets/images/crops/<id>.jpg` (names in `assets/images/crops/README.md`) |

## Map of the code
`lib/core` theme, strings, constants · `lib/data` bundled data + towns + crops · `lib/domain` pure model (water balance, Monte-Carlo, plans, missing piece, aquifer, solar) ·
`lib/state` settings, farm, results · `lib/voice` phrases, builder, backends, player, intent matcher, STT · `lib/features` screens · `docs/prototype.html` visual reference.

See `docs/OPEN_ITEMS.md` for what is still provisional.
