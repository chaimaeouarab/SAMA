# MODEL — how SAMA computes its numbers

SAMA is **statistics on 40 real seasons of NASA data plus cited agronomic formulas**. It is not machine learning, not a
weather forecast, and never a guarantee. Symbols follow FAO-56 and FAO-33. Every constant is in `SOURCES.md`.
Nothing in the agronomic tables has been verified by a person yet: the app shows a "provisional parameters" badge.

## 1. Data
NASA POWER daily point data, community AG, 1984-01-01 → 2024-12-31 (`PRECTOTCORR, T2M, T2M_MAX, T2M_MIN, RH2M, WS2M, PS,
ALLSKY_SFC_SW_DWN`). `-999` is missing and is never averaged in. A **season is an agricultural year, 1 Oct → 30 Sep**, so
summer crops fit; 40 seasons, 1984-85 … 2023-24. Rain of the *rainy season* (1 Oct → 31 May) is used only for labels and
scenario percentiles. POWER is gridded (MERRA-2, 0.5° × 0.625°): the data are for the cell, not the field, and satellite-derived
rain differs from rain gauges. The API echoes the requested coordinates, so the cell centre shown to the farmer is derived from the
grid definition (and checked: it predicts exactly which bundled points have identical data). Two places in one cell share the same
data (Sebaa Aioun, Mhaya, Meknès).

## 2. Reference evapotranspiration ET0 (FAO-56 Penman-Monteith, daily, G = 0)
ET0 = [0.408 Δ (Rn − G) + γ · 900/(T + 273) · u2 · (es − ea)] / [Δ + γ (1 + 0.34 u2)]  (mm/day)

with T = (Tmax + Tmin)/2, es = (e0(Tmax) + e0(Tmin))/2, ea = RHmean/100 · es, γ = 0.000665 · P, P from elevation (eq. 7),
Rns = 0.77 Rs, Rso = (0.75 + 2·10⁻⁵ z) Ra, Rnl from eq. 39. Missing inputs are carried forward from the previous day and counted;
missing radiation falls back to Hargreaves-Samani and is counted. Elevation z is the **grid-cell elevation POWER returns**
(its temperatures are consistent with it), not the town's.

## 3. Crop water requirement
ETc = Kc · ET0 per day. Kc follows the FAO-56 single-coefficient curve (flat initial, linear development, flat mid-season,
linear decline to the end value). Not modelled: dual Kc, climate adjustment of Kc mid, growing root depth (constant), runoff.

## 4. Soil water bucket and effective rain (daily, not a flat factor)
TAW = 1000 (θFC − θWP) Zr, used as TAW = (mm per metre) · min(Zr_max, soil depth). RAW = p · TAW. The bucket starts dry on 1 Oct
(summer drought); before sowing the soil is fallow (Kc = 0.3) so autumn and winter rain refill it, which gives the soil water at
sowing. Each day: rain refills the depletion Dr; rain beyond the capacity is **lost** (drainage/runoff). What the bucket keeps is the
effective rain. Irrigation (rainfed by default) is applied when Dr ≥ RAW, to refill, until the seasonal budget (mm) is used.
Stress: Ks = (TAW − Dr)/((1 − p) TAW) when Dr > RAW, else 1. ETa = Ks · ETc. A uniform-wetting bucket penalises deep soils
under frequent light rain: a known simplification.

## 5. Yield and "good season" (FAO-33)
1 − Ya/Ym = Ky · (1 − ETa/ETm), so **relative yield RY = 1 − Ky (1 − ETa/ETc)**, clamped to [0, 1], over the whole cycle.
A season is **good** when RY ≥ 80 % (configurable in Advisor mode). Crops with no documented Ky have no RY and are not recommended.
Temperature does not change yield directly: it enters only through ET0. Non-water effects (pests, markets) are not modelled; the
Phase 1 "3 % failure" was removed because it had no source.

## 6. Monte-Carlo (deterministic)
1000 futures × 3 seasons. Each simulated season is **one whole historical season** (full daily series, so rain timing is
preserved), drawn with replacement by `mulberry32(seed 42)`. Seasons are assumed independent (real droughts can cluster).
All rotations use the same draws (common random numbers) so differences are real, not noise.
Outputs: P(all 3 good) shown as "X in 10", expected RY, P10/P50/P90 of the mean RY, worst, expected deficit (mm), plus per season
the share of the 40 real seasons that were good and the best/worst real example year.

## 7. Rotations A / B / C
Start crop = season 1. **A** repeats it. **B** is the best sequence with at least one legume and no rule flag. **C** is the best
sequence of three different families with no flag. "Best" = higher P(all good), then higher expected RY. Rules
(`rotation_rules.json`) only raise visible flags (same family twice, Solanaceae after Solanaceae); a legume's nitrogen credit is a
note, not a water or yield change. If the top two are within 5 points the model says it cannot separate them and hands over to
the Detective.

## 8. Scenarios (observed ≠ hypothetical)
**Observed**: the 40 real seasons. **Favorable / Dry / Very dry**: the REAL season nearest the 70th / 25th / 7th percentile of
rainy-season rain (its year is shown). **What-if shocks** (Climate Shock Lab): rain ×0.8 or ×0.6 on every day; "Warmer" = +2 °C on
Tmax and Tmin (ET0 recomputed). Always labelled "What-if scenario, not NASA observation". Temperature effect on yield is not modelled.

## 9. Detective
For each input the farmer marked "I don't know" (soil depth, irrigation, previous crop) it tests the plausible alternatives, ranks
the rotations again, and asks **one** question only if some answer changes the best rotation or separates a tie. If nothing would
change or narrow the result it asks nothing. The sensitivity ranking (Advisor mode) is the spread, in points, of the best
rotation's chance across an input's alternatives.

## 10. Worked example (reproduced by a test)
Boufakrane (NASA cell 33.5, −5.0; elevation 1377 m), soft wheat sown 15 Nov, medium soil (1.0 m, Zr = 1.0 m → TAW 140 mm, p = 0.55),
rainfed, season **1994-95** (the driest of the 40: 293.2 mm from 1 Oct to 31 May).

1. ET0 on 1 Oct 1994: Tmax 19.4 °C, Tmin 8.1 °C, RH 72.3 %, u2 1.1 m/s, Rs 20.9 MJ/m²/day → **2.91 mm/day**. Over the year: 1333.2 mm.
2. Over the 190-day cycle: ET0 = 483.9 mm, **ETc = Σ Kc·ET0 = 400.1 mm**.
3. Rain on the cycle 212.1 mm, all kept by the bucket (0 lost) → **effective rain 212.1 mm**; no irrigation.
4. Stress when the bucket empties in spring: **ETa = 238.9 mm**, deficit 161.2 mm.
5. **RY = 1 − 1.0 × (1 − 238.9/400.1) = 0.597**: below 80 %, a hard season (shown as "!").

The wettest season (2009-10, 1003 mm) gives RY 0.936 (22.6 mm deficit, 604 mm of rain lost to drainage: waterlogging note).

## 11. Edge cases and their tests (`test/model_test.dart`, `test/location_test.dart`)
no rain / extreme rain (lost rain) · missing days (-999) · leap years and seasons spanning two calendar years · irrigation unlimited vs
none · soil unknown → Detective · previous crop unknown → no flag · perennial crop → "not part of the 3-season model" · location outside
Morocco (allowed, warned) · offline with no cache → nearest reference, labelled and confirmed · crop without Ky → "?" · changing inputs
changes results (test).

## 12. Limitations (say them to the jury)
Provisional agronomic parameters · bucket model with constant roots · no dual Kc · no temperature stress on yield · seasons assumed
independent · satellite rain ≠ gauge rain · grid-cell elevation · one soil texture · 7 crops excluded for lack of a cited Ky ·
rotation rules unsourced (flags only) · not measured on a phone (performance).
