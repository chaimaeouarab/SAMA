# SAMA — Phase 2 prompt (for Claude Code, after Phase 1 works)

> Give this file to Claude Code in the SAMA repo (save as `docs/PHASE2.md`, then say: **"Read docs/PHASE2.md and SAMA_PROMPT.md. Do the First Task. Do not write code yet."**).
> Phase 1 (the app built from `SAMA_PROMPT.md`) already runs. **Do not redesign or rewrite it. Extend it.**

---

## 0. Rules (same as Phase 1, plus these)

1. **Milestone by milestone** (section 14). After each: `flutter analyze` clean, `flutter test` green, run the app, report *working / placeholder / limitations / what I need from you*. **Wait for "go".**
2. **No fake functionality.** No invented numbers, no fake satellite imagery, no demo-only shortcuts. If real data is unavailable, show an honest empty/offline state.
3. **Real NASA observations and hypothetical scenarios are always visually and verbally separated** ("Observed 1984–2024" vs "What-if scenario").
4. **Every number the farmer sees must be traceable** to: a NASA POWER value, a cited agronomic parameter, or a clearly labelled farmer input. Keep a `docs/SOURCES.md` listing every parameter with citation, value, unit, and who verified it.
5. **Ask before deciding** anything not specified. Short question, 2–3 options, your recommendation first.
6. Keep the SAMA design system, Riverpod, GoRouter, offline bundled NASA data, repositories, audio services, localization. Business logic never inside widgets. No new packages unless necessary (justify each).
7. No login, no account, no share/WhatsApp, no analytics, no hard-coded keys.

---

## 1. What I found in the extra material (read before planning)

I was given: (a) 32 crop photos, (b) a Python project "Agriculture Intelligente / AgriSat Morocco" (Flask + XGBoost/LSTM, 1,728 rows) and its paper, (c) a feature brief (Time Machine, Detective, Satellite Lens, Climate Shock Lab, Speak). Findings:

**AgriSat project — do NOT port its ML models into SAMA.**
- It uses **Open-Meteo**, not NASA, over **four other regions** (Souss-Massa, Gharb, Doukkala, Tadla), not the Saïs plain. NASA Space Apps requires NASA data.
- Its targets (`stress_hydrique`, `rendement_t_ha`) are **computed by a formula from the same features** (`rendement = ref × (1 − 0.8 × stress)` in `download_real_data_v2.py`; stress is ≈ −0.91 correlated with rainfall). A model "predicting" them with R² ≈ 1.000 is re-learning the formula, not predicting real yield. **Never present R² = 1.0 as validation to the jury.**
- Its own `metriques.json` (F1 stress 0.258, R² stress −0.049) contradicts the paper/`comparaison_modeles.json` (≈ 1.0). Another sign of leakage/inconsistency.
- Soil values come from fallback constants; the Kaggle crop dataset is synthetic and not Moroccan.
- XGBoost/LSTM/pickles can't run offline on a phone anyway.

**What we reuse instead (ideas, not code):**
- **Multi-region coverage:** add NASA POWER reference points for those regions so the app works nationwide and the offline fallback (§5) is meaningful: Kenitra 34.26,-6.58 · Sidi Slimane 34.26,-5.93 · El Jadida 33.25,-8.50 · Zemamra 32.63,-8.70 · Beni Mellal 32.34,-6.35 · Fquih Ben Salah 32.50,-6.69 · Taroudant 30.47,-8.87 · Agadir 30.35,-9.57 (+ the Saïs towns and Erfoud). Fetch **from NASA POWER**, never from their CSV.
- **A transparent regional water-stress comparison** in Satellite Lens, computed by SAMA from NASA data (rain vs reference evapotranspiration, §6) — explainable, no ML.
- **Explainability:** keep "Why this advice?" and add a plain **sensitivity ranking** in Detective (which input changes the answer most). No SHAP.
- Credit the authors in About only if their ideas are used: *Oulghazi Mustapha & Lahcen Asnaoui, AgriSat Morocco* — **ask me first**.

**Photos:** all 32 crops are covered (see §3). Four are low-resolution and must be replaced when possible.

---

## 2. FIRST TASK (no code yet)

Reply with:
1. What from this document already exists in the app, what is partial, what is missing.
2. Scientific/technical problems in the current code (use §6 as the checklist).
3. A reuse-first implementation plan per milestone, with risks.
4. Up to 8 questions for me (recommended answer each).
5. Package choices for map, geocoding and tiles with licence/usage-policy notes.
Then **start with Milestone 1 only after I say go.**

---

## 3. Photos (real crop images)

Provided as `assets/images/crops/<id>.jpg` (max 1000 px, already normalised). Ids: softwheat, durumwheat, barley, oats, maize, sorghum, fava, chickpea, lentil, pea, onion, garlic, potato, carrot, tomato, pepper, courgette, cabbage, watermelon, melon, sunflower, rapeseed, sugarbeet, alfalfa, olive, almond, grape, fig, citrus, apple, pomegranate, plum.

- Use `Image.asset(..., fit: BoxFit.cover, cacheWidth: …)`; keep the bundled illustration as a fallback only if a file fails to load.
- **Low resolution — report and ask me for replacements:** rapeseed (235×132), plum (235×132), sugarbeet (235×161), citrus (424×283); soft wheat and pea are portrait 452×678 (check cropping on cards/hero).
- Licensing of these photos is **unknown**. Add an "Image credits" row in About with a `docs/IMAGE_CREDITS.md` file; list the source of each once I provide it. Do not claim they are original.

---

## 4. Languages: add Arabic (4 languages)

Selectable at first launch and in Me, each shown in its own script:
| code | label | script | notes |
|---|---|---|---|
| `dar` | الدارجة | Arabic, RTL | Moroccan Darija (primary) |
| `ar` | العربية | Arabic, RTL | Modern Standard Arabic (Fusha) |
| `en` | English | LTR | |
| `fr` | Français | LTR | |

- **Migration:** previous builds stored `ar` meaning Darija. On upgrade, map stored `ar` → `dar`, once.
- Strings: separate tables for `dar` and `ar` (they differ — do not copy one into the other). Both `reviewed:false` until a native speaker approves (`docs/darija_review.csv` also covers Arabic).
- Flutter `Locale` for both `dar` and `ar` = `ar` (RTL, Arabic digits setting: show Western digits 0–9 by default for farmers; add a Me option "Arabic-Indic digits").
- **Voice must work in all four languages** (§11): Darija → SpeechT5 pre-generated clips (Latin input), Arabic → system Arabic TTS is allowed (it *is* MSA) with a bundled-clip option, English/French → bundled clips or system TTS in that language.
- Speech recognition locales: `dar` → `ar_MA`, `ar` → `ar_SA` (or device default Arabic), `fr_FR`, `en_US`.

---

## 5. Farm location (complete spec)

### 5.1 Screen: three big options
1. **Use my GPS location**
2. **Search for my village or city**
3. **Select my farm on the map**

Plain instructions, large buttons, speaker button on each text. After confirming, show: **"Your farm is selected. Let's explore your agricultural options."** (all 4 languages).

### 5.2 Interactive map
- Interactive map (zoom/pan), initially Morocco, focused on Meknès/Saïs. Tap anywhere to place the marker. Show latitude, longitude (5 decimals), and the **nearest recognizable place name when available**.
- Package: `flutter_map` + `latlong2` unless you recommend better (tell me why). Tile source configured by `--dart-define=SAMA_TILE_URL=...` with attribution shown; **respect the tile provider's usage policy** (OpenStreetMap's public tile server is not for heavy/commercial use — flag this and propose an alternative).
- **Offline:** if tiles can't load, don't show a broken grey map. Show an **accessible offline location selector** (list of supported reference locations + manual latitude/longitude entry) and keep the app fully usable.

### 5.3 GPS
- Large "Use my location" button. Ask permission **only when pressed**, with a plain-language reason first. Handle: granted, denied (offer manual choice), denied forever (explain and offer to open settings), services off, timeout, low accuracy (show accuracy radius; ask to confirm).
- Works anywhere in the world. If outside Morocco: allow it but warn that the crop catalogue and assumptions are calibrated for Morocco.
- Never transmit precise GPS to third parties without explaining why (§5.7).

### 5.4 Search
- Search a city/village/commune; show matching results; tap moves the map and sets the marker. **Never invent names.**
- Prefer a **bundled offline gazetteer** of Moroccan places (GeoNames, CC-BY — cite) for search and for reverse "nearest place" (no network, no privacy cost). Online geocoding (e.g. Nominatim) only as an optional extra with consent, **search on submit (no per-keystroke calls), ≤ 1 request/second, identify the app in the User-Agent**, and cache results.

### 5.5 Confirm, save, edit
Confirm button → save coordinates locally via the existing Riverpod state + `shared_preferences` (key `farm.lat`, `farm.lon`, `farm.name`, `farm.source` = gps|search|map|preset). Editable later from Home ("My farm") and Me. Support **multiple farms** in Advisor mode (§9); Farmer mode keeps one.

### 5.6 NASA data for the chosen coordinates
- When online, request NASA POWER daily point data for the selected coordinates (community AG, 1984-01-01 → last complete year), parameters needed by §6: `PRECTOTCORR, T2M, T2M_MAX, T2M_MIN, RH2M, WS2M, PS, ALLSKY_SFC_SW_DWN` (verify names against the current POWER API docs; handle `-999` as missing).
- **Round requested coordinates to 2 decimals** (~1 km). Show the farmer the **actual source coordinates returned by NASA (grid-cell centre)** and the **temporal coverage** (first/last date, % missing).
- **Be honest about resolution:** POWER meteorological data is gridded (about 0.5° × 0.625°). Two farms in the same cell share the same data. Say so: "NASA data for your area (grid cell centred at X, Y), not a measurement in your field."
- **Cache** each successful dataset on disk keyed by rounded coordinates + dataset version; reuse offline; show "downloaded on <date>".
- **Offline and no exact cache:** offer the **nearest supported reference location** with distance in km, labelled **"approximate regional information"**; require the farmer's confirmation. **Never substitute silently.**
- Download in the background with progress, retry/backoff, cancel, and a clear error state. Respect POWER rate limits.

### 5.7 Privacy (must be in the UI)
Before the first GPS/NASA request, a one-screen explanation in the user's language: *"To get NASA data for your area we send your approximate location (to about 1 km) to NASA. Your location stays on your phone otherwise."* Also disclose map tile and optional online search requests. No coordinates in logs or crash reports.

### 5.8 Integration and recalculation
Selected farm drives: Home weather card, Crops chances, Time Machine, Climate Shock Lab, Detective, Satellite Lens, Results, voice answers. **Changing the farm recomputes everything** (invalidate providers; show loading state).

### 5.9 Tests
Coordinate persistence, farm change → recompute, rounding/cache key, NASA dataset selection (exact cache > nearest reference with label), offline fallback, permission states (mocked), `-999` handling, gazetteer nearest-place.

---

## 6. Scientific model review and rebuild (Milestone 1 — do this first)

Audit the current engine and **fix what is unsupported**. Write `docs/MODEL.md` (formulas, symbols, units, sources, assumptions, limitations) and `docs/DATA_AUDIT.md`.

### 6.1 Data audit (my request: "analyse the data, check the statistics are correct")
- Script `scripts/audit_data.py`: re-download a sample of points from NASA POWER and compare with the bundled JSON (must match); check seasons count, missing days, outliers, leap years, season boundaries (Oct 1 → May 31 spans two calendar years).
- Report per town: season rain mean/median/P10/P90/min/max, number of dry seasons by the thresholds below. Sanity-check against published climatology for Meknès (e.g. Direction de la Météorologie Nationale / ORMVA). **State the known bias of satellite-derived rainfall vs gauges** and don't hide it.
- Report every inconsistency in the existing code or numbers. Fix or flag.

### 6.2 Required corrections
| Issue in Phase 1 | Required fix |
|---|---|
| Crop water needs were **placeholders** | Replace with **FAO-56**: `ETc = Kc × ET0` per growth stage, stage lengths and Kc values from FAO Irrigation & Drainage Paper 56 (Tables 11–12). Cite page/table in `SOURCES.md`. If a crop lacks a documented value, mark it `TODO(source)` and exclude it from recommendations rather than guess. |
| `W_avail = 10·0.65·P + Q·f_soil` (flat 0.65, fixed Q=2400) | **Effective rain** from a documented method (e.g. USDA-SCS / FAO method) applied **per rain event or per day**, not a flat factor; **soil water storage** from soil depth and texture: `TAW = 1000·(θFC − θWP)·Zr` (FAO-56 ch. 8); a **daily soil-water balance** (bucket) over the season. |
| Irrigation baseline Q assumed equal for all farms | **Configurable irrigation availability** per farm: None (rainfed) / Limited / Moderate / Available, each an explicit mm or m³/ha per season, editable in Advisor mode, **default = rainfed** unless the farmer says otherwise. |
| 3 % "non-climate failure" | **Remove.** Unsupported. If a risk factor is kept, it needs a cited source and a label. |
| Good season = `W_avail ≥ W_need` | Use **FAO-33 yield response to water**: `1 − Ya/Ym = Ky·(1 − ETa/ETm)`; define a season as "good" when relative yield ≥ a **configurable threshold (default 80 %)**. Ky per crop from FAO-33 (cited). |
| Previous-crop effect = ×0.9 on need | Replace with **rotation logic** (§6.4): legume nitrogen credit and same-family penalty, each with source and bounds. Do not alter *water need* for non-water effects. |
| ET0 missing | Compute **ET0 with FAO-56 Penman-Monteith** from POWER inputs (T2M_MAX/MIN, RH2M, WS2M, ALLSKY_SFC_SW_DWN, PS, latitude, elevation). Fall back to Hargreaves-Samani only if radiation is missing, and say so. Elevation: from SRTM (NASA) if bundled/available, else a documented approximation — never silently zero. |

### 6.3 Climate scenarios (separate observed from hypothetical)
- **Observed:** the 40 real historical seasons of the farm's NASA grid cell.
- **Named scenario years** are *real* historical seasons chosen by season-rain percentile: **Favorable** ≈ 70th percentile, **Dry** ≈ 25th, **Very dry** ≈ 7th (define percentiles in `MODEL.md`, pick the nearest real season, show its year). Never fabricate a season to fit a label.
- **Hypothetical shocks** (Climate Shock Lab): rainfall multiplier (Normal 1.0, −20 %, −40 %) applied to daily rain; temperature "Warmer" scenario (+X °C, X documented) which **affects results only through ET0 (Penman-Monteith depends on temperature)** — a documented relationship. Do **not** add arbitrary temperature effects on yield unless a documented, cited temperature-sensitive crop model is implemented; otherwise display "temperature effect on yield not modelled".
- Always label hypothetical results "What-if scenario, not NASA observation".

### 6.4 Rotation logic
Each crop has: `family` (Poaceae, Fabaceae, Solanaceae, Amaryllidaceae, Brassicaceae, Cucurbitaceae, Asteraceae, Chenopodiaceae, Apiaceae, tree…), `legume`, `perennial`.
- **Same-family consecutive seasons** carry a documented yield penalty/risk flag (disease, pest build-up); the value and source go in `SOURCES.md`, bounded and labelled as agronomic guidance.
- **Legume before another crop:** documented nitrogen credit (state the value and the source; if the credit only affects fertiliser need and not water, **don't** reduce water need).
- Forbid or warn on documented bad sequences (e.g. solanaceous after solanaceous). Keep the rule table in data (`rotation_rules.json`), not in code.
- Perennial trees are **excluded** from the 3-season model and shown as "Perennial — not part of the 3-season model".

### 6.5 Monte-Carlo (deterministic, testable)
- Same seed → same output (`mulberry32`, seed 42 by default, injectable). 
- Each simulated season samples **one whole historical season (its full daily series)**, so rain *timing* is preserved. 3 consecutive seasons, N = 1000 futures, sampling with replacement; note the independence assumption.
- Outputs per rotation: probability all 3 seasons good, expected relative yield, P10/P50/P90, worst case, expected water deficit, and the **share of historical seasons** in each class. Display as "X in 10", never as a guarantee.

### 6.6 Farmer-facing classes (3 labels + icon + text)
✓ **Suitable to explore** · ! **Use caution** · ? **More information needed** (when a key input is missing or uncertain). Severe shortage still reads "Use caution" with the reason in plain words. Keep the simplified "Why this advice?" (one short plain explanation) instead of a separate technical screen.

### 6.7 Edge cases (each needs a test and a visible state)
No rain / extreme rain (cap with waterlogging note) · missing days (`-999`) · incomplete first/last season · leap year · season spanning two calendar years · very small/large area · irrigation unlimited vs none · soil unknown (→ Detective) · previous crop unknown · perennial crop selected · location outside Morocco · offline with no cache · dataset shorter than 40 seasons (show actual n) · identical results for different inputs (flag as a bug: **changing inputs must produce model-based differences**).
Add a hand-worked example in `docs/MODEL.md` (one town, one crop, one season: ET0 → ETc → ETa → RY) and make a test reproduce it.

### 6.8 The three rotations A / B / C (must be correct, detailed, NASA-driven)
For the selected farm and starting crop, generate three **3-season rotations** by rules, not by hand:
- **A — Repeat:** same crop 3 seasons (shows monoculture penalty).
- **B — Best legume rotation:** search allowed sequences containing at least one legume; pick the highest expected relative yield subject to rotation rules.
- **C — Diversified:** three different families; pick the best under the rules.
For **each season of each rotation** show: crop, ET0 over the cycle, ETc requirement, effective rain, irrigation used, deficit (mm), relative-yield distribution (P10/P50/P90), % of historical seasons that were good, and a **real example year** (best / worst). For the **rotation**: probability all 3 good ("X in 10"), expected yield, worst case, total water, the rotation effects applied (legume credit, family penalty) with their sources, and a plain-language summary in the chosen language. If two rotations are within the model's uncertainty, say so and hand over to Detective.

---

## 7. Feature 1 — SAMA Time Machine
Not a weather forecast: an **interactive scenario simulator** on historical NASA data and cited assumptions.
- Select farm and current crop; choose a rotation (A/B/C or custom).
- Three climate scenarios: Favorable / Dry / Very dry (real historical years, §6.3).
- **Horizontal timeline:** TODAY → SEASON 1 → SEASON 2 → SEASON 3. Each season: crop, water requirement, available water, shortage indicator, compatibility status (✓ / ! / ?). Change any crop at any point → recompute the affected seasons.
- "Try another future" compares strategies side by side.
- Visuals: smooth transitions, crop photos, seasonal indicators, simple water-level animation, large buttons, green/amber/warning **with text labels**. No heavy 3D.
- Answers: "What could happen under different climate conditions if I choose this rotation?"

## 8. Features 2–4

### Feature 2 — SAMA Detective (upgrade Missing Piece)
Never recommend blindly when key information is missing. Evaluate rotations with known inputs; identify uncertain inputs (soil depth, irrigation, previous crop…); **test plausible alternative values**; check if the ranking changes; ask the **single most useful question**, one at a time, with large cards (e.g. Deep soil / Shallow soil / I don't know); recompute after the answer. **Only ask if the answer changes or narrows the result.** If nothing changes the decision, show no question. Add a plain **sensitivity ranking** ("which input matters most") in Advisor mode.
Example (French): « Ton sol est-il profond ou peu profond ? » — Darija and Arabic wording must be native-reviewed.

### Feature 3 — SAMA Satellite Lens (real NASA data only)
- Map centred on the Saïs; markers for Meknès, Boufakrane, El Hajeb, Sebaa Aioun, Aïn Taoujdate, Mhaya, optional Erfoud (+ the farmer's own farm).
- Per location: historical rainfall, historical temperature patterns, side-by-side **comparison of towns**; the transparent regional water-stress comparison from §1; farmer-friendly sentences ("Rainfall varies a lot between past seasons.").
- **Real NASA imagery layers via NASA GIBS (WMTS, no key):** e.g. MODIS/VIIRS true colour, NDVI (vegetation), IMERG precipitation, SMAP soil moisture. **Verify layer identifiers, tile matrix sets, formats and date ranges from the GIBS capabilities document; do not assume them.** Show layer name, **acquisition date and resolution** (MODIS ≈ 250 m: it cannot show individual small fields — say so). Only layers that load are offered; otherwise hide them.
- Do **not** generate fake imagery or present illustrations as measurements. Do not present NASA POWER grid data as field measurements.
- Offline: cached tiles of the last viewed area if available, otherwise the offline location selector (§5.2). Numeric NDVI/soil-moisture values only if a genuine NASA source is integrated (e.g. AppEEARS needs an account — **ask me**); otherwise imagery is visual only.

### Feature 4 — SAMA Climate Shock Lab
Controls: Rainfall (Normal / −20 % / −40 %), Temperature (Historical / Warmer), Irrigation (Limited / Moderate / Available), Rotation (A/B/C). On change: recompute water availability, compatible options, risk classes, rotation comparison; show **Before / After**, important differences, and suggested alternatives to explore. Prominent button **"What if there is less rain?"** → activates the dry scenario. Plain language, no agronomy training needed. Temperature rule in §6.3.

---

## 9. Farmer vs Advisor: two different roles

Same data, **different experience** (switch in Me; remember the choice).

**Farmer** (default): one farm, big buttons, voice-first, 3 labels (Suitable / Caution / More info), short explanation. Bottom nav: **Home · Explore · Crops · Results · Me**.

**Advisor** (field technician / cooperative adviser):
- **Multiple farms** (list, add, rename, compare), per-farm location, soil, irrigation, previous crop.
- Full **assumptions editor** (irrigation mm, soil depth/TAW, effectiveness threshold, scenario percentiles) with a "reset to defaults" and visible difference from defaults.
- **Detailed analysis:** season-by-season tables, NASA rain/temperature charts, ET0/ETc/ETa, distributions (P10/P50/P90), Detective sensitivity ranking, data provenance (coordinates returned by NASA, coverage, download date, cache vs fresh), model version.
- **Compare** farms or locations and rotations side by side.
- Bottom nav: **Dashboard · Farms · Explore · Analysis · Me**. No sharing/export.

---

## 10. Navigation (integrate, don't add five apps)
Home (farm overview, crop guidance, climate summary) · Explore (Satellite Lens, Time Machine, Climate Shock Lab) · Crops (catalogue with photos, details, rotation selection) · Results (strategies, comparison, Detective) · Me (language ×4, voice, Farmer/Advisor, settings, about, credits). Keep "Why this advice?" reachable from every result.

---

## 11. Feature 5 — SAMA Speak (voice, 4 languages)
Voice-first for farmers who prefer speaking. **All four languages must work, in both directions**, in this order of priority: Darija, Arabic, French, English.

- **Questions to support** (each with natural Darija/Arabic/French/English phrasings, native-reviewed): "What should I plant?", "Does this crop need a lot of water?", "What happens if there is less rain?", "Which rotation is more suitable?", "Explain this result.", plus repeat / change language / help.
- Flow: receive speech → recognise (device STT in the selected language) → `IntentMatcher` (closed vocabulary, normalisation, fuzzy match) → fetch the answer from SAMA's engine → compose a short answer **from approved phrases** → **speak it and show the same text**.
- **Voice-guided simulations:** "What if there is less rain?" activates the dry scenario in Climate Shock Lab, updates results and explains the main change aloud. Same for Time Machine (change crop, next season, compare).
- Reuse the Phase 1 voice architecture: bundled clips first, disk cache, optional Space/HF, text fallback. Male voice default, volume + speed controls.
- If recognition is uncertain (< 0.6): ask to repeat or show option buttons. **Never pretend to understand.** Never invent agricultural advice.
- Provide a **voice test matrix** in `docs/VOICE_TESTS.md` (language × intent × online/offline × bundled/live) and run it on a real device.
- Phrase catalogue grows with all new screens; `reviewed:false` flags stay until a native speaker signs off; `scripts/build_phrase_audio.py` regenerates clips (I run it on my machine).

---

## 12. UX and design
Preserve the SAMA design system (deep green, soft green surfaces, white cards, rounded corners, real crop photos, clear type, smooth transitions). Accessibility: touch targets ≥ 56 dp primary, text ≥ 16 sp, full RTL for `dar`/`ar`, voice playback on every key text, **never colour alone**. Performance: heavy computation (Monte-Carlo, ET0 over 40 seasons) in an isolate with progress and caching; UI stays at 60 fps.

---

## 13. Quality, tests, security
- Unit tests for every new calculation: ET0, effective rain, soil-water bucket, ETa, yield response, scenario selection, rotation generator and rules, Monte-Carlo determinism, Detective ranking-change detection, location persistence, cache keys, offline fallback, intent matching (4 languages), phrase composition.
- Golden-number tests from the worked example in `MODEL.md`.
- Widget/integration tests: location flow (GPS denied/granted, search, tap map), Time Machine edit, Shock Lab before/after, Detective question appears **only** when it changes the ranking, language switch incl. migration `ar`→`dar`.
- `flutter analyze` clean, `dart format`, no `print`, no secret in repo, Android release build (`flutter build apk --release`) with size reported.
- Offline test: airplane mode — Home, Crops, Time Machine, Shock Lab, Detective, bundled voice, cached location all work.

---

## 14. Milestones (stop after each; report; wait for "go")
1. **Scientific model review + data audit** (§6, `MODEL.md`, `DATA_AUDIT.md`, `SOURCES.md`, tests). Nothing else starts before this.
2. **Farm location** (§5): map, GPS, search, gazetteer, NASA fetch/cache/fallback, privacy screen, recompute pipeline.
3. **Arabic + photos + roles** (§3, §4, §9): 4 languages with migration, real photos, Advisor mode and its navigation.
4. **Time Machine** (§7) incl. the detailed A/B/C rotations (§6.8).
5. **Climate Shock Lab** (§8).
6. **SAMA Detective** (§8).
7. **Satellite Lens** with NASA GIBS (§8).
8. **SAMA Speak** in 4 languages with voice-guided simulations (§11).
9. **Final polish:** navigation integration, accessibility, RTL check, error/offline states, performance, tests, release APK, README, `OPEN_ITEMS.md`.

---

## 15. Final demo for the NASA jury (3 minutes — must run on real features)
1. Select a farm near Meknès (GPS or map). 2. Show its historical NASA rainfall. 3. Compare three rotations in Time Machine. 4. Activate the drought scenario in Climate Shock Lab. 5. Show how the comparison changes. 6. Detective asks one missing question (soil depth) that changes the ranking. 7. Ask a short question in Darija with SAMA Speak. 8. Switch to airplane mode and show the essentials still work.
Story: *"SAMA helps Moroccan farmers explore agricultural choices, understand climate risks, and make more informed decisions using NASA Earth observation data."*
Add `docs/DEMO.md` with the exact steps, the data used, and a pre-demo checklist (cached datasets, audio clips, permissions).

---

## 16. Honesty rules (user-facing, always)
"Based on 40 past seasons of NASA data", never "prediction". Observed ≠ scenario. NASA grid data ≠ field measurement. Satellite layers show their date and resolution. Placeholders carry a visible "sample" badge. Sources and "not a guarantee" on every result screen.
