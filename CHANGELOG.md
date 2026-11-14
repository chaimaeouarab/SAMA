# Changelog

## 1.0.0 (all milestones built in one pass)
- M1 Base: theme/palette, first-launch language (RTL for Darija), home shell, Me with volume + speed, bottom nav.
- M2 Data: `scripts/fetch_nasa_power.py` → `assets/data/sais_power.json` (6 towns, 1984–2024, offline); weather card from NASA climatology of today (labelled "typical"), NOAA sunrise/sunset.
- M3 Catalogue: 32 crops, category filters, photo cards with illustration fallback, crop detail, related crops.
- M4 Model: water balance, 40-season classifier, deterministic Monte-Carlo (mulberry32, seed 42), plans A/B/C, Missing Piece, field setup (town, GPS snap ≤ 50 km, soil, previous crop, area), Futures and Results screens.
- M5 Why this advice (40-season bar chart, legend with icons, source, assumptions, what would change it), aquifer scenario, Advisor mode.
- M6 Voice out: phrase catalogue, `PhraseBuilder`, backend chain (bundled → disk cache → own Space → HF → text), speaker buttons, volume and speed.
- M7 Voice in: `speech_to_text`, closed-vocabulary `IntentMatcher`, listening sheet, low-confidence fallback to buttons.
- M8 States (skeleton, error + retry, empty, offline badge), tests (unit + widget), Android/iOS permissions.
