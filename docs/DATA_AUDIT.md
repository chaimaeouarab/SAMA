# DATA AUDIT

Run `python scripts/audit_data.py [--online id ...]`; it writes the per-point table to `docs/DATA_AUDIT_RESULTS.md`.
The audit was run on 2026-11-14 on the bundled file `assets/data/nasa_power.json` (15 points, 1984-2024).

## What was checked
| check | result |
|---|---|
| 40 seasons per point, each Oct 1 → Sep 30 (365 or 366 days, leap day only in seasons that contain 29 Feb) | pass |
| no values outside physical bounds (rain, Tmax, Tmin, RH, wind, radiation) | pass |
| missing days (NASA fill value -999) | 0 in all 15 points |
| daily season series vs per-year rain table (two independent paths) agree within 0.15 mm per season | pass for all points and seasons |
| **re-download from NASA and compare**, Boufakrane and Erfoud: 14 610 daily rain values each | 0 differences |
| grid-cell derivation (0.5° × 0.625°) predicts exactly which points have identical data | pass for all 105 pairs |
| ET0 building blocks against published FAO-56 values (e0 at 20 °C, Δ at 20 °C, pressure at 1800 m, Ra for 20°S on 3 Sep) | pass |
| ET0 for one day against an independent Python implementation | agree to 0.005 mm/day |
| worked example reproduced by a test | pass (docs/MODEL.md §10) |

## Findings you should know
1. **Sebaa Aioun, Mhaya and Meknès are one NASA cell**: their data are identical. Boufakrane, El Hajeb and Aïn Taoujdate are
   different cells. The app says so; it does not present six independent datasets.
2. **POWER returns the requested coordinates, not the cell centre.** Showing them as "the cell" would be wrong, so the app derives
   the centre from the MERRA-2 grid (33.5, −5.0 for Boufakrane).
3. **Elevation is the grid cell's** (Boufakrane 1377 m, El Hajeb 990 m, Meknès 414 m, Kenitra 8 m). It is consistent with POWER's own
   temperatures but is not the town's elevation. It changes pressure and clear-sky radiation by a few percent, ET0 by less.
4. **Satellite/reanalysis rain differs from rain gauges.** POWER PRECTOTCORR is a corrected reanalysis product on a 50–60 km cell.
   Local rain in a field can be quite different. No gauge series was available to quantify the bias; **this has not been compared with
   published climatology (DMN/ORMVA)** and that comparison is still to do.
5. Season rain (1 Oct → 31 May), mean / min / max over 40 seasons: Boufakrane 576 / 293 / 1003 mm · Meknès 510 / 262 / 922 · Kenitra 416 /
   146 / 727 · Agadir 248 / 105 / 511 · Erfoud 118 / 23 / 228. These are plausible for the regions but unchecked against gauges.
6. No season is incomplete: the last season is 2023-24 (the data end 31 Dec 2024), so the 2024-25 season is excluded.

## What was NOT checked
Gauge comparison; trends (the model assumes the 40 seasons are exchangeable, i.e. no climate trend and independent years);
spatial resolution finer than the grid cell; radiation quality (CERES).
