# SAMA — Master prompt for Codex / Claude Code

> Paste this whole file as the first message, or save it in the repo root as `AGENTS.md` (Codex) and `CLAUDE.md` (Claude Code). Then say: **"Start with Milestone 1."**

---

## 0. How you must work (read first)

You are the lead engineer building **SAMA**, a production-quality **Flutter** mobile app (Android first, iOS compatible). Rules that override everything else:

1. **Work milestone by milestone** (section 12). After each milestone: run `flutter analyze` (zero warnings), run `flutter test` (all green), run the app, then report: what works, what is a placeholder, what you need from me. Do not start the next milestone until I say "go".
2. **Never invent data.** Rainfall, soil, crop water needs, audio, photos and translations come from the sources in this file. Anything you cannot source is a clearly marked `TODO(source)` constant and is listed in `docs/OPEN_ITEMS.md`. Never present a guess as a fact in the UI.
3. **Ask before you decide** anything that is not specified here (product, UX, data, naming). Short question, 2–3 options, your recommendation first.
4. **No secrets in code.** API URLs and tokens come from `--dart-define` (`SAMA_TTS_URL`, `HF_TOKEN`, …). Never commit keys.
5. **No share / WhatsApp / social features anywhere.** Not in code, not in UI.
6. **Offline-first.** The core advice must work with no network, from bundled data.
7. **Keep it simple and readable.** Small files, feature folders, no clever abstractions, comments only where the *why* is not obvious. Every public function that holds model logic has a unit test.
8. **Accessibility is a feature:** touch targets ≥ 56 dp for primary actions, body text ≥ 16 sp, state never by colour alone (always icon + text), full RTL support, screen-reader labels on every control.

A starting point already exists: `sama_step1.zip` (project skeleton: theme, strings, first-launch language screen, settings, home shell). And a clickable web prototype: `docs/prototype.html` — **this is the visual and behavioural reference. Match it.** Reference design image: `docs/design_reference.png`.

---

## 1. Product

**Name:** SAMA (سما = "sky"). **Tagline:** *The sky still tells us when to plant.*
**Challenge:** NASA Space Apps — "Field Shift: Adapting Farms with NASA Data". **Place:** Saïs plain, Meknès, Morocco (towns: Boufakrane, El Hajeb, Sebaa Aioun, Aïn Taoujdate, Mhaya, plus Erfoud as a dry-region contrast).

**What it is:** a decision-support app for farmers. It is **statistics on 40 years of NASA rainfall, not machine learning** and must never claim to predict the weather or guarantee a result.

**One app, four decisions:** (1) which crop, (2) how much water, (3) when to plant, (4) what risk.

**Two modes (same app):**
- **Farmer mode (default):** very few words, big buttons, voice in and out, one clear answer per screen.
- **Advisor mode (toggle in Me):** same data plus the numbers: assumptions, season bars, parameters, export-free read-only detail.

**Languages (chosen on first launch, changeable any time):** Darija (Arabic script, RTL), English, French. A speaker button beside every important text plays it in Darija/English/French.

**Value for the jury (must be built):** **"Why this advice?"** — shows the 40 real seasons as bars (good / dry), the source (NASA POWER, years, location), the assumptions, and what would change the advice.

---

## 2. Tech stack

Flutter stable, Dart 3, null-safety. Use exactly:

`flutter_riverpod`, `go_router`, `dio`, `just_audio`, `geolocator`, `shared_preferences`, `path_provider`, `fl_chart`, `flutter_svg`, `connectivity_plus`, `intl` + `flutter_localizations`, `speech_to_text`, `permission_handler`, `mocktail` (dev), `flutter_lints` (dev).

Structure:
```
lib/
  core/        colors.dart theme.dart strings.dart constants.dart
  data/        nasa_power_repository.dart  bundled_data_loader.dart  crops_catalog.dart  towns.dart
  domain/      water_balance.dart  season_classifier.dart  monte_carlo.dart  plans.dart  aquifer.dart  missing_piece.dart  rng.dart
  state/       settings.dart  farm_state.dart  results_provider.dart
  voice/       phrase_catalog.dart  phrase_builder.dart  audio_player_service.dart  tts_backends/  stt/ intent_matcher.dart
  features/    onboarding/ home/ crops/ crop_detail/ results/ futures/ aquifer/ why/ me/ voice_assistant/
  widgets/
assets/
  data/sais_power.json   phrases.json   crops.json
  images/crops/<id>.jpg  images/illustrations/
  audio/darija/male/<phraseId>.mp3
scripts/ fetch_nasa_power.py  build_phrase_audio.py
test/
docs/ prototype.html design_reference.png OPEN_ITEMS.md
```

---

## 3. Design system (match the prototype and the reference image)

Reference: green-header farming app — greeting header, search/voice pill, white rounded weather card overlapping the header, four category tiles, photo cards, detail screen with big green pill button, notes list, bottom nav.

**Colours** (`SamaColors`):
| token | hex | use |
|---|---|---|
| green | `#0C5A3B` | header, primary buttons, active nav |
| green2 | `#2A7556` | search pill, secondary surfaces |
| greenTint | `#E3F0E8` | chips, soft backgrounds |
| bg | `#F4F6F4` | screen background |
| ink | `#1B2B23` | text |
| muted | `#6B7A72` | secondary text |
| line | `#E6ECE8` | dividers |
| water | `#2F7FB5` | water icons |
| amber | `#C98A1C` | timing icons |
| danger | `#B4531A` | dry / risk only, never a primary button |

**Shape:** cards radius 22, tiles 16, pills fully rounded, header bottom radius 30, shadow `0 6 18 rgba(12,90,59,.12)`. Bottom nav: white, top radius 20, active = green icon + bold label.
**Type:** system font stack with Arabic fallback (Noto Naskh/Sans Arabic bundled as asset). Sizes: title 22–28 w800, body 16–17, caption 12–13.
**Icons:** line icons (Material Symbols outlined or bundled SVG). Status: ✓ (good), ! (warning), ✕ (bad) always with text.
**Motion:** 150–250 ms ease-out, no decorative animation. Respect reduce-motion.
**RTL:** whole tree mirrors when language = Darija; icons that imply direction flip.

---

## 4. Screens (exact behaviour)

### 4.1 First launch — Language
Logo + trilingual title ("اختار اللغة ديالك / Choose your language / Choisissez votre langue"), three 76-dp cards (الدارجة, English, Français), each with a speaker button that says the language name. Choice saved; never shown again unless reset in Me.

### 4.2 Home ("My farm today")
- Green header: greeting by time of day + date (localised), language chip, avatar, **search/voice pill** with mic (opens Voice assistant, §7).
- **Weather card** overlapping the header: place, big temperature, H/L, cloud/sun icon, 4 stats (humidity, rain, wind, pressure), sunrise–sunset arc with sun position. **Values = NASA POWER climatology for today's date at the chosen town** (bundled, offline) and **must be labelled as such** ("typical for today, 1984–2024"), not as a live forecast. Sunrise/sunset computed locally from latitude/date (NOAA solar formulas). Speaker button reads the card.
- "What do you want to know?" — 4 tiles: Crop, Water, Timing, Risk → each opens the matching view of the guided flow (§4.5).
- "Best crops for you" horizontal photo cards (top 6 annual crops by chance for the chosen field), "View all" → Crops tab.
- Footer note when data is placeholder.

### 4.3 Field setup
Choose town (list + "use my location" with `geolocator`, snap to nearest town ≤ 50 km else ask), soil depth (shallow / medium / deep → `f_soil` 0.85 / 1.00 / 1.15), previous crop (legume yes/no), area (ha). Stored in `FarmState`, persisted.

### 4.4 Crops tab
Filter chips: All, Cereals, Legumes, Vegetables & fruits, Industrial & fodder, Trees. 2-column photo cards with name + chance (annual) or "Perennial" (trees). Sorted by chance (annual) then alphabetical. Photo = `assets/images/crops/<id>.jpg`; if missing → bundled illustration fallback (never a blank card).

### 4.5 Crop detail
Back button, big photo + 5 thumbnails of same category, name, status line (✓ Chance of a good season), chance %, area stepper (ha), description, related crops, big green pill **"See 3 parallel futures"**. Speaker button reads name + chance + one-line advice.

### 4.6 Results tab
Green card: season rain so far (mm, NASA), then **Past seasons** list (thumbnail, season, total mm, ✓ good / ! dry), then button **"Why this advice?"** (§4.8).

### 4.7 Three parallel futures
For the selected crop/field run the Monte-Carlo (§6) and show 3 plans as cards: **A** repeat the same crop, **B** best rotation with a legume, **C** three crop families. Each shows probability that all 3 seasons are good (`X` in 10), water need vs available bar, and ✓/!/✕. If the top two plans are within 5 points show **Missing Piece**: one question (usually soil depth) that would separate them.

### 4.8 Why this advice (jury feature)
Bar chart (`fl_chart`) of the 40 seasons coloured good/dry **with icons in the legend**, line for water need, text: source (NASA POWER, 1984–2024, coordinates), assumptions list, "what would change this advice". Advisor mode adds the raw parameters.

### 4.9 Aquifer view
Scenario only: Δh = −v·(1 − a·s)·t with v = 3 m/yr, a = 0.30, s = share of water-saving, t years. Always labelled **"scenario, not measurement"**.

### 4.10 Me
Language, mode (Farmer/Advisor), voice (male), **volume slider**, **speed slider 0.7–1.3**, about/source note, reset first launch. No share, no account, no login.

### 4.11 Required states on every data screen
Loading skeleton, empty, error with retry, offline badge, "data from <date>" stamp.

---

## 5. Crop catalogue (`assets/data/crops.json`)

Fields: `id, category, annual(bool), legume(bool), waterNeedM3PerHa (TODO source), sowMonths, photo, names{ar,en,fr}`.
Photos: `assets/images/crops/<id>.jpg` (I will provide; 800 px wide). Ids and categories:

- **cereal:** softwheat, durumwheat, barley, oats, maize, sorghum
- **legume (legume=true):** fava, chickpea, lentil, pea
- **veg:** onion, garlic, potato, carrot, tomato, pepper, courgette, cabbage, watermelon, melon
- **industrial:** sunflower, rapeseed, sugarbeet, alfalfa
- **tree (annual=false, not in the 3-season model):** olive, almond, grape, fig, citrus, apple, pomegranate, plum

**Water needs (m³/ha per season) — PLACEHOLDERS, mark `TODO(source)`, replace with values derived from FAO Irrigation and Drainage Paper 56 (Kc × ET0) and cite them in `docs/OPEN_ITEMS.md`:**
softwheat 4500, durumwheat 4500, barley 3500, oats 3500, maize 7000, sorghum 5500, fava 3500, chickpea 3000, lentil 2800, pea 3000, onion 6500, garlic 5000, potato 6000, carrot 5000, tomato 6500, pepper 6500, courgette 5000, cabbage 5000, watermelon 5000, melon 5000, sunflower 5000, rapeseed 4000, sugarbeet 7500, alfalfa 9000.

Names in 3 languages: reuse the strings object `T` in `docs/prototype.html`. **All Darija text is a draft and must stay flagged `reviewed:false` until a native speaker approves it** (§8).

---

## 6. Data and model

### 6.1 Data
- Source: **NASA POWER** daily point API, community `AG`, parameters `PRECTOTCORR, T2M, T2M_MAX, T2M_MIN, RH2M, WS2M, PS`, 1984-01-01 → 2024-12-31, one point per town.
  `https://power.larc.nasa.gov/api/temporal/daily/point?parameters=...&community=AG&longitude=<lon>&latitude=<lat>&start=19840101&end=20241231&format=JSON`
- `scripts/fetch_nasa_power.py` downloads for all towns and writes **one compact bundled file** `assets/data/sais_power.json` (per town: daily rain by year, plus per-day-of-year climatology of the other parameters). The app reads only the bundled file; no runtime dependency on NASA. Town coordinates in `towns.dart` are approximate → verify and document: Boufakrane 33.72,-5.30 · El Hajeb 33.69,-5.37 · Sebaa Aioun 33.85,-5.46 · Aïn Taoujdate 33.93,-4.77 · Mhaya 33.93,-5.43 · Erfoud 31.43,-4.23.
- Handle NASA fill value `-999` as missing; never average it in.

### 6.2 Season and water balance
A season = Oct 1 → May 31 (40 seasons: 1984–85 … 2023–24).
- `P` = season rain (mm).
- `W_avail = 10 · 0.65 · P + Q · f_soil` (m³/ha), `Q = 2400` m³/ha stored/irrigation baseline, `f_soil ∈ {1.15, 1.00, 0.85}`. 0.65 = effective-rain share (TODO(source): confirm).
- `W_need = B_c · 0.8 · (0.9 if previous crop is a legume else 1.0)` with `B_c` from §5.
- **Good season** ⇔ `W_avail ≥ W_need` **and** not hit by a 3 % non-climate failure (pests, market, etc. — drawn from the RNG).

### 6.3 Monte-Carlo
1000 simulated futures of 3 consecutive seasons; each season samples one of the 40 historical rainfall totals uniformly. A future is **good** only if all 3 seasons are good. `p = good / 1000`; display `X = round(10·p)` as "X in 10". **Deterministic:** `mulberry32(seed = 42)`; same input → same output on every device. Unit-test with fixed expectations.
- Plan A: same crop 3 seasons. Plan B: best crop for season 1, a legume in season 2 (gets the 0.9 factor next season), best in season 3. Plan C: three different families.
- **Missing Piece:** if the top two plans differ by < 5 points, return the single question (soil depth, previous crop) whose answer flips the order, and show both outcomes.

### 6.4 Aquifer
Pure function per §4.9. Scenario label mandatory.

### 6.5 Tests (must exist)
Water balance edge cases, season classification of all 40 seasons for a known town, Monte-Carlo determinism (same seed → identical), plan ordering, Missing Piece trigger, `-999` handling, aquifer formula, intent matcher (§7), phrase builder concatenation order.

---

## 7. Voice

### 7.1 App speaks (Darija / English / French)
Central requirement: the app answers by voice in the user's chosen language, **male voice by default**, with **volume** and **speed** controls (Me screen and an inline control in the assistant).

**Darija voice = `SpeechT5 Darija` (HAMMALE HF Space), male.** It takes **Latin-script Darija**. Therefore each phrase stores: `ar` (display, Arabic script), `latin` (sent to TTS), `en`, `fr`, `reviewed`.

**Architecture — pre-generated clips first, live API only as a bonus:**
1. `phrases.json` = closed catalogue (greetings, crop names, numbers 0–10, units, the advice sentence parts, risk words, prompts). Advice is composed from parts, so no free text ever needs live TTS.
2. `scripts/build_phrase_audio.py` calls the Space with `gradio_client`, normalises each clip (`ffmpeg silenceremove + loudnorm`, mono mp3), writes `assets/audio/darija/male/<id>.mp3`. **I run this on my own machine.**
3. `PhraseBuilder` concatenates clips (small gap) to say "X in 10 for wheat…".
4. `TtsBackend` chain, in order: **Bundled → DiskCache → GradioSpaceBackend (own Space, `SAMA_TTS_URL`) → optional HfInference (`HF_TOKEN`) → text only**. System Arabic TTS is **opt-in only** (it speaks Modern Standard Arabic, not Darija) and must be labelled so.
5. English/French: bundled clips the same way, or system TTS in that language.
6. Playback via `just_audio` with `setVolume` and `setSpeed`; stop on screen leave; never autoplay on launch.
7. Fallback is always visible text; the app never fails silently.

### 7.2 Farmer speaks (voice assistant)
Tap the mic pill → listening sheet (large mic, live transcript, cancel).
- **Language:** fixed to the chosen language by default using `speech_to_text` (`ar_MA`, `fr_FR`, `en_US`). Optional "Auto-detect" setting that sends audio to my own Space (Whisper language ID → Darija/FR/EN model); off by default; clearly optional.
- **Understanding:** no LLM. A closed-vocabulary `IntentMatcher`: normalise (lowercase, strip diacritics, unify Arabic letter variants أإآ→ا, ة→ه, ى→ي, Arabizi digits 3→ع 7→ح 9→ق), then fuzzy match (Levenshtein/token overlap) against intent keywords in the 3 languages. Intents: `crop_advice`, `water`, `timing`, `risk`, `choose_field`, `repeat`, `change_language`, `help`, plus crop-name entities from `crops.json`.
- **Confidence < 0.6 → do not guess:** say "I did not understand" and show 3–4 large buttons for the likely intents.
- The answer is spoken (§7.1) **and** shown on screen.
- Microphone permission requested at first use with a plain-language reason; if denied, the pill still works as a button menu.

---

## 8. Language quality (Darija)

- Display Darija in **Arabic script**, short sentences, everyday words a farmer uses. Avoid MSA constructions.
- Every string and phrase carries `reviewed:false` until a native speaker ticks it; show nothing as "approved" in the UI. Maintain `docs/darija_review.csv` (`key, ar, latin, en, fr, reviewed, reviewer`) generated by a script so review is easy.
- Numbers, units and place names get explicit entries (don't rely on the TTS to read digits).

---

## 9. Persistence and settings

`shared_preferences`: language, mode, volume, speed, town, soil, previous-crop, area, first-launch flag. A single `SettingsNotifier`/`FarmNotifier` (Riverpod `Notifier`) with typed state and `copyWith`. No analytics, no accounts, no network calls except the optional voice backends.

---

## 10. Quality bar

- `flutter analyze` clean, formatted (`dart format`), `flutter test` green, no `print`, no TODO without a matching entry in `docs/OPEN_ITEMS.md`.
- Cold start < 2.5 s on a mid-range Android; scrolling 60 fps; APK size reported at each milestone.
- Works in airplane mode (except optional voice backends).
- Widget tests for: first-launch flow, language switch + RTL, crop filter, crop detail → futures, error/empty states.
- Golden or screenshot check against `docs/prototype.html` at 360×800.
- Android: min SDK 23, `INTERNET`, `RECORD_AUDIO`, `ACCESS_COARSE_LOCATION` only. iOS Info.plist strings for mic and location in all 3 languages.
- Release notes per milestone in `CHANGELOG.md`.

---

## 11. Honesty rules (user-facing)

- Never write "prediction" or "forecast" for what the model does. Use "based on 40 past seasons".
- Always show the source line and a "not a guarantee" note on result screens.
- Trees show "Perennial — not part of the 3-season model".
- Placeholder numbers must show a "sample" badge until real data replaces them.

---

## 12. Milestones (stop after each, report, wait for "go")

1. **Base** — import `sama_step1.zip`, update palette/theme to §3, restructure to §2, first-launch language, home shell, Me/settings with volume + speed, bottom nav, RTL. *Acceptance: matches prototype screens 1, 2 (static), Me.*
2. **Data** — `fetch_nasa_power.py`, bundled `sais_power.json`, repositories, towns, climatology for today, sunrise/sunset, Home weather card with real values + labels. *Acceptance: numbers for each town match the NASA JSON; offline works.*
3. **Catalogue** — `crops.json`, filters, photo cards with fallback, crop detail, related crops, thumbnails. *Acceptance: all 32 crops open; missing photo shows illustration.*
4. **Model** — water balance, season classifier, Monte-Carlo, plans A/B/C, Missing Piece, Field setup, Futures + Results screens. *Acceptance: all model tests pass; determinism proven.*
5. **Why this advice + Aquifer + Advisor mode.**
6. **Voice out** — `phrases.json`, `build_phrase_audio.py`, `PhraseBuilder`, backend chain, speaker buttons everywhere, volume/speed. *Acceptance: Darija/EN/FR clips play offline; full advice sentence is spoken.*
7. **Voice in** — speech_to_text, IntentMatcher, listening sheet, low-confidence fallback, optional auto-detect.
8. **Polish** — states (loading/empty/error/offline), accessibility pass, performance, icons/splash, APK build, README with run/build steps, `docs/OPEN_ITEMS.md` final.

---

## 13. First reply I expect from you

Before writing code: (a) confirm you read this file; (b) list every point you find ambiguous or risky (max 8), each with your recommended answer; (c) list the assets and decisions you need from me (photos, TTS Space URL, Darija review, crop water sources). Then wait for my answer and start **Milestone 1**.
