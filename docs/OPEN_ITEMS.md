# Open items

Everything below is a `TODO(source)`, a decision, or something not done. Nothing here is shown to the farmer as a fact.

## 1. Must do before the jury (a person is needed)
| item | why | who |
|---|---|---|
| **Check every agronomic parameter against FAO-56 (Tables 11, 12, 19, 22) and FAO-33** (`docs/SOURCES.md` §C–D), then set `verified:true` | The values were entered from memory. The app shows a "provisional parameters" badge until then. | agronomist |
| Native review of all Darija and Arabic (`docs/darija_review.csv`; UI strings in `lib/core/strings.dart` are not in the CSV yet) | everything is `reviewed:false` | native speakers |
| Source and licence of the 32 crop photos (`docs/IMAGE_CREDITS.md`); replace the 5 low-resolution ones | licence unknown | owner |
| Provide FAO-33 Ky (or another cited source) for oats, chickpea, lentil, garlic, carrot, courgette, rapeseed | without it they cannot be recommended | agronomist |
| Rotation rules: a source for the same-family and Solanaceae flags and the legume nitrogen note | flags only until then | agronomist |
| Compare POWER season rain with published climatology / gauges (DMN, ORMVA) | satellite rain ≠ gauge rain | hydrologist |
| Install the Android NDK and accept the SDK licences, then `flutter build apk --release` | the release build failed on this machine: "NDK 28.2.13676358 not installed" | you |
| Run `scripts/build_phrase_audio.py` (Darija Space, edge-tts for ar/en/fr) and run `docs/VOICE_TESTS.md` on a real phone | no audio clip exists yet; voice was never tested on a device | you |
| Set `--dart-define=SAMA_TILE_URL=...` (+ `SAMA_TILE_ATTRIBUTION`) with a provider you may use | see §3 | you |

## 2. Not implemented (decision or dependency needed)
- **GeoNames gazetteer**: not bundled (it is a file download, CC-BY). Search uses the 15 reference places only; manual coordinates and the
  map cover the rest. Online geocoding (Nominatim) is not implemented.
- **System TTS (Arabic, English, French)**: no TTS package is in the required stack; those languages need bundled clips or your own endpoint.
- **Spoken-language auto-detect** (optional): needs audio recording and your own Whisper Space.
- **Arabic-Indic digits option**: Western digits are always used.
- **Numeric NDVI / soil moisture**: Satellite Lens shows images only. AppEEARS needs an account: not integrated.
- **Cached GIBS tiles for offline**: not implemented; offline shows the numeric comparison instead.
- **iOS localized permission strings**: one trilingual string per permission in Info.plist.
- **Golden screenshot check against `docs/prototype.html` at 360×800**, **cold start < 2.5 s**, **60 fps** and **APK size**: not measured.
- **Seasons assumed independent**; no climate-trend analysis.
- **Heavy work runs in an isolate** (`heavyRunnerProvider`) but its speed on a mid-range phone is unmeasured.

## 3. Map tiles (usage policy)
OpenStreetMap's public tile server is not meant for heavy or commercial use and requires attribution and an identifying User-Agent.
SAMA does not hard-code any tile URL. Use a provider you are allowed to use (own tile server, or a commercial plan) via `SAMA_TILE_URL`.
Without it, the farm screen shows the accessible list and coordinates instead of a map. Satellite Lens uses NASA GIBS (no key).

## 4. Data and model notes
- Place coordinates (`lib/data/places.dart`) are approximate: verify. POWER elevation is the grid cell's.
- Same-cell places share data (Sebaa Aioun, Mhaya, Meknès).
- Aquifer parameters v = 3 m/yr, a = 0.30: `TODO(source)`; shown as "scenario, not measurement".
- Morocco UTC+1 for sunrise/sunset display: confirm.
- Credit to the AgriSat authors (Oulghazi Mustapha & Lahcen Asnaoui): ideas used (regional comparison, explainability); no code or data taken.
  **Ask the owner before adding the credit to About.**
