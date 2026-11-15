# SAMA (سما): The sky still tells us when to plant

**NASA Space Apps Challenge 2026, Meknès · Challenge: Field Shift: Adapting Farms with NASA Data**
**Team: The Astravia** · Euromed University of Fes, Morocco
Hajar Belghali (team leader) · Chaimae Ouarab · Houd Fattouh

SAMA is a mobile app that helps small farmers in Morocco decide **what to plant, how much water to plan for, when to act, and what risk to watch**. It turns 40 years of NASA POWER data (1984–2024) into clear answers, in Darija, Arabic, French and English.

## Why
Farmers decide before they know how the season will go. The NASA data that could help is in English, in technical tables. SAMA closes that gap.

## How it works
1. **Data:** NASA POWER daily rainfall, temperature, humidity, wind and solar radiation, 1984–2024, for 15 locations (Saïs plain, Erfoud and regional points). Data audit: `docs/DATA_AUDIT.md`.
2. **Water need:** FAO-56 Penman-Monteith reference evapotranspiration (ET0); crop need ETc = Kc × ET0.
3. **Soil water:** daily soil-water balance, with optional irrigation (rainfed by default).
4. **Yield:** FAO-33 relative yield, 1 − Ky × (1 − ETa/ETc). A season is "good" if yield reaches 80% (adjustable).
5. **Futures:** Monte-Carlo with 1,000 three-season futures, each season a whole real past season (fixed seed, 42). Results read "X in 10".

Details: `docs/MODEL.md`. This is **not machine learning** and **not a weather forecast**.

## Features
- Farmer mode (simple) and Adviser mode (numbers)
- 32 crops, with chance of a good season
- **Time Machine:** three seasons in a row, rotation scenarios
- **Climate Shock Lab:** "what if it rains less?" (always labelled as a scenario)
- **Detective:** asks one question, only when it changes the result
- **Satellite Lens:** NASA GIBS layers and a place comparison
- **Why this advice?:** the 40 real seasons, sources and assumptions
- Four languages: Darija, Arabic, French, English

## Honesty and limits
- Not a forecast and not a guarantee. NASA data is a grid cell, not a field sensor.
- Crop parameters are **provisional, to be verified** (`docs/FAO_CHECKLIST.md`).
- NASA rainfall has not yet been compared with local rain stations.
- Darija and Arabic text are drafts awaiting native-speaker review.
- Not yet tested with farmers in the field.

## Run it
```bash
flutter pub get
flutter run -d chrome
```
Tests: `flutter test` (112 tests). Static analysis: `flutter analyze`.

## Data and resources
- NASA POWER: https://power.larc.nasa.gov/
- NASA GIBS: https://nasa-gibs.github.io/gibs-api-docs/
- FAO Irrigation and Drainage Papers 56 and 33
- Flutter: https://flutter.dev
- Darija TTS (planned voice): SpeechT5 Darija Space by HAMMALE on Hugging Face
- Crop photos and credits: see `docs/IMAGE_CREDITS.md`

## AI use
SAMA was designed and directed by Team Astravia. We used **Claude Code (Anthropic)** as a coding assistant; the scientific design, data choices, testing and review were done by the team. Slide images were generated with Canva AI and carry a visible "AI-generated" mark. Text drafts, including translations, were written with AI assistance and need native-speaker review.

## Privacy
No accounts, no usage tracking, no keys in the code. Location is requested only when the user chooses it.
