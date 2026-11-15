# SAMA (سما): The sky still tells us when to plant

**NASA Space Apps Challenge 2026, Meknès · Challenge: Field Shift: Adapting Farms with NASA Data**

**Team: The Astravia**, Euromed University of Fes, Morocco
Hajar Belghali (team leader) · Chaimae Ouarab · Houda Fattouh

SAMA is a mobile app that helps small farmers in Morocco decide **what to plant, how much water to plan for, when to act, and what risk to watch**. It turns 40 years of NASA POWER data (1984–2024) into clear answers, with the real seasons shown behind each one.

## Why
Farmers decide before they know how the season will go. The NASA data that could help is in English, in technical tables. SAMA closes that gap.

## How it works
1. **Data:** NASA POWER daily data, 1984–2024, bundled for 15 locations. Audit: `docs/DATA_AUDIT.md`.
2. **Water need:** FAO-56 Penman-Monteith ET0; crop need ETc = Kc × ET0.
3. **Soil water:** daily balance, rainfed by default, optional irrigation.
4. **Yield:** FAO-33 relative yield, 1 − Ky × (1 − ETa/ETc); a good season reaches 80% (adjustable).
5. **Futures:** Monte-Carlo, 1,000 three-season futures from whole real seasons (fixed seed 42). "X in 10" means all three seasons are good.

See `docs/MODEL.md`. This is **not machine learning** and **not a weather forecast**.

## Features
Farmer and Adviser modes · 32 crops · Time Machine (rotations) · Climate Shock Lab · Detective · Satellite Lens · "Why this advice?" · Darija, Arabic, French, English · GPS, search or map location.

## Status: what works and what does not yet
| Area | Status |
|---|---|
| Model, data, screens | Working. 112 automated tests pass. |
| Offline | Works for the 15 bundled locations. New locations need internet once. |
| Voice | Voice search, speaker buttons and a closed-vocabulary voice assistant exist. Audio clips are **not generated yet**, so the app shows the text instead. Speech recognition is not tested across devices. |
| Satellite Lens map | Layer information and place comparison work. The base map needs a tile provider (`SAMA_TILE_URL`), not configured yet. |
| Crop parameters | Provisional, to be verified (`docs/FAO_CHECKLIST.md`). |
| NASA rainfall vs. local stations | Not compared yet. |
| Darija and Arabic text | Drafts, awaiting native-speaker review. |
| Field tests with farmers | Not done yet. |

## Limits
Not a forecast and not a guarantee. NASA data is a grid cell, not a field sensor. The model is simple: no growing roots, no direct temperature effect on yield, seasons assumed independent.

## Run it
```bash
flutter pub get
flutter run -d chrome
```
Tests: `flutter test` · Analysis: `flutter analyze`

## Data and resources
- NASA POWER: https://power.larc.nasa.gov/
- NASA GIBS: https://nasa-gibs.github.io/gibs-api-docs/
- FAO Irrigation and Drainage Papers 56 and 33
- Flutter: https://flutter.dev
- SpeechT5 Darija (planned voice): https://huggingface.co/spaces/HAMMALE/speecht5-darija
- **Crop photos:** collected from public web sources. Owners and licences are not verified. Used for illustration in this competition prototype only. To be replaced with credited free-licence images (`docs/IMAGE_CREDITS.md`).

## AI use
SAMA was designed and directed by the team. We used **Claude Code (Anthropic)** as a coding assistant; scientific design, data choices, testing and review were done by the team. Slide images were generated with Canva AI. Text drafts, including translations, were written with AI assistance.

## Privacy
No accounts, no usage tracking, no keys in the code. Location is requested only when the user chooses it.
