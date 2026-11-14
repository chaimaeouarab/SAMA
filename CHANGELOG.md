# Changelog

## 2.0.0 (Phase 2)
- **Model rebuilt on FAO-56 / FAO-33** (docs/MODEL.md): Penman-Monteith ET0 from NASA radiation, wind, humidity and temperature; Kc curve;
  daily soil-water bucket (effective rain per day); irrigation classes (rainfed by default); relative yield by FAO-33; whole-season
  Monte-Carlo (seed 42, 1000 futures). Removed the unsupported 3 % failure, flat 0.65 effective rain, fixed Q, and the "legume cuts water need" rule.
- **Data audit** (docs/DATA_AUDIT.md, `scripts/audit_data.py`): re-download comparison, season boundaries, leap years, bounds. Found that
  Sebaa Aioun, Mhaya and Meknès are one NASA cell, and that POWER echoes the requested coordinates (the cell centre is derived).
- **Farm location**: GPS (all permission states), search, map, manual coordinates, privacy screen, NASA download with progress/cancel/cache,
  nearest-reference fallback labelled and confirmed. 15 reference points (adds Meknès and 8 regional points).
- **Four languages** (Darija, Arabic, English, French) with migration of the old `ar` to `dar`; the voice works in all four.
- **Real crop photos** (32). Image credits file.
- **Time Machine** (rotations A/B/C by rules, real scenario years), **Climate Shock Lab**, **Detective** (asks only when the answer matters),
  **Satellite Lens** (NASA GIBS layers verified against the capabilities document), **Advisor mode** (several farms, assumptions editor,
  analysis), **SAMA Speak** intents for what-if, rotation and explanation.
- Three farmer labels (Suitable / Use caution / More information needed), each with icon and text. "Provisional parameters" badge everywhere.
- Fixed: the top of the home weather card was not tappable (a `Transform` leaves its overflow outside the hit-test box).
- Tests: 100+ (model, data, location, strings in 4 languages, voice, widgets incl. mocked GPS permission states).

## 1.0.0 (Phase 1, tag `v1-phase1`)
- All milestones of the first brief in one pass (base, data, catalogue, simple model, why, aquifer, voice out and in).
- M1 Base: theme/palette, first-launch language (RTL for Darija), home shell, Me with volume + speed, bottom nav.
- M2 Data: `scripts/fetch_nasa_power.py` → `assets/data/sais_power.json` (6 towns, 1984–2024, offline); weather card from NASA climatology of today (labelled "typical"), NOAA sunrise/sunset.
- M3 Catalogue: 32 crops, category filters, photo cards with illustration fallback, crop detail, related crops.
- M4 Model: water balance, 40-season classifier, deterministic Monte-Carlo (mulberry32, seed 42), plans A/B/C, Missing Piece, field setup (town, GPS snap ≤ 50 km, soil, previous crop, area), Futures and Results screens.
- M5 Why this advice (40-season bar chart, legend with icons, source, assumptions, what would change it), aquifer scenario, Advisor mode.
- M6 Voice out: phrase catalogue, `PhraseBuilder`, backend chain (bundled → disk cache → own Space → HF → text), speaker buttons, volume and speed.
- M7 Voice in: `speech_to_text`, closed-vocabulary `IntentMatcher`, listening sheet, low-confidence fallback to buttons.
- M8 States (skeleton, error + retry, empty, offline badge), tests (unit + widget), Android/iOS permissions.
