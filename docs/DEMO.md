# DEMO — 3 minutes for the NASA jury

Story: *"SAMA helps Moroccan farmers explore agricultural choices, understand climate risks, and make more informed decisions using
NASA Earth observation data."*

## Pre-demo checklist (do it the day before, on the demo phone)
- [ ] App installed from `flutter build apk --release` (see OPEN_ITEMS: the NDK must be installed first).
- [ ] Language set to the jury's language. Mode = Farmer (Advisor for the technical questions).
- [ ] Farm near Meknès selected (GPS or map) **while online**, so its NASA dataset is cached ("saved on your phone").
- [ ] Soil and irrigation set to "I don't know" if you want the Detective to ask a question (check once that it does).
- [ ] Audio clips generated and bundled (`scripts/build_phrase_audio.py`), volume up, speaker tested in the chosen language.
- [ ] Microphone and location permissions already granted.
- [ ] `--dart-define=SAMA_TILE_URL=...` set so the map shows (otherwise the app shows the accessible list).
- [ ] Airplane-mode rehearsal done once: Home, Crops, Time Machine, Shock Lab, Detective, voice clips all still work.

## Steps (what is shown, the data behind it)
| # | action | what the jury sees | data |
|---|---|---|---|
| 1 | Me → farm → "Use my GPS location" (or pick on the map) | privacy sentence, coordinates, NASA download with progress | NASA POWER point, rounded to 2 decimals |
| 2 | Home / Results | typical weather for today; 40 past seasons of rain, hard seasons marked ! | NASA POWER 1984-2024 for the grid cell (cell centre shown) |
| 3 | Crops → a cereal → "See 3 parallel futures" | Time Machine: TODAY → SEASON 1–3, rotations A / B / C with "X in 10" | ET0, soil-water bucket, FAO-33 yield, 1000 futures |
| 4 | Explore → "What if there is less rain?" | banner "What-if scenario, not NASA observation", Before / After | rain ×0.8 on every real day |
| 5 | Same screen | the comparison changes; a suggested alternative may appear | recomputed rotations |
| 6 | Explore → Detective | one question (soil depth) with big answer cards; answer → ranking recomputed | sensitivity of the ranking |
| 7 | Home → microphone: "شنو إلا قلت الشتا" | the app switches on the dry what-if and says the main change aloud | closed vocabulary, approved phrases |
| 8 | Airplane mode, repeat steps 2–4 | everything still works; badge "Offline — everything still works" | bundled + cached data |

Say plainly: the agronomic parameters are provisional until checked against FAO tables; the numbers are chances over 40 real seasons,
not predictions.
