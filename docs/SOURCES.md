# SOURCES — every parameter, its citation, and who verified it

**Rule:** every number the farmer sees is a NASA POWER value, a parameter listed here, or a labelled farmer input.
**Verification state:** the column `verified` says whether a PERSON has checked the value against the cited page.
Today **nothing in the agronomic tables has been verified by a person**: the values were entered from memory of the
FAO publications and must be checked against the books before the app drops its "provisional parameters" badge.
Crops with no documented FAO-33 yield-response factor (Ky) are excluded from recommendations (shown as "?").

References
- **FAO-56** Allen R.G., Pereira L.S., Raes D., Smith M. (1998). *Crop evapotranspiration — Guidelines for computing crop water requirements.* FAO Irrigation and Drainage Paper 56.
- **FAO-33** Doorenbos J., Kassam A.H. (1979). *Yield response to water.* FAO Irrigation and Drainage Paper 33.
- **NASA POWER** Prediction Of Worldwide Energy Resources, daily point API, community AG. https://power.larc.nasa.gov/
- **MERRA-2 grid** 0.5° latitude × 0.625° longitude (POWER meteorology). CERES radiation is coarser.
- **NASA GIBS** Global Imagery Browse Services, WMTS. https://gibs.earthdata.nasa.gov/

## A. NASA POWER inputs (observed)
| symbol | NASA parameter | unit | use | verified |
|---|---|---|---|---|
| P | PRECTOTCORR | mm/day | rain | file audited against a live re-download for 2 points (0 differences), docs/DATA_AUDIT.md |
| Tmax, Tmin | T2M_MAX, T2M_MIN | °C | ET0 | same |
| RHmean | RH2M | % | ET0 (ea) | same |
| u2 | WS2M | m/s at 2 m | ET0 | same |
| Rs | ALLSKY_SFC_SW_DWN | MJ m⁻² day⁻¹ | ET0 (Rn) | same |
| z | elevation returned by POWER | m | pressure, Rso | the elevation of the grid cell, not of the town (e.g. Boufakrane 1377 m): see DATA_AUDIT.md |
| PS, T2M | PS, T2M | kPa, °C | home card only | same |

## B. FAO-56 equations implemented (`lib/domain/et0.dart`)
| item | equation (FAO-56) | verified |
|---|---|---|
| Penman-Monteith ET0 | eq. 6 with G = 0 (daily) | reproduced by an independent Python implementation to 0.005 mm/day (test) |
| saturation vapour pressure e0(T) | eq. 11 | test against Table 2.3 value at 20 °C (2.338 kPa) |
| slope Δ | eq. 13 | test against Table 2.4 (0.145 kPa/°C at 20 °C) |
| pressure from elevation | eq. 7 | test against Example 2 (81.8 kPa at 1800 m) |
| psychrometric constant γ | eq. 8 | by construction |
| actual vapour pressure from RHmean | eq. 19 | by construction |
| extra-terrestrial radiation Ra | eq. 21–25 | test against Example 8 (32.2 MJ m⁻² day⁻¹, 20°S, 3 Sep) |
| clear-sky radiation Rso | eq. 37 | by construction |
| net radiation Rn = Rns − Rnl | eq. 38–40 | by construction |
| Hargreaves-Samani fallback | Hargreaves & Samani (1985) | used only when radiation is missing (counted) |
| crop coefficient curve | FAO-56 ch. 6 (piecewise) | by construction |
| water stress Ks | FAO-56 eq. 84 | by construction |

## C. Model constants (`lib/core/constants.dart`): SAMA assumptions
| constant | value | unit | source | verified |
|---|---|---|---|---|
| total available water per metre of soil | 140 | mm/m | loam, mid-range of FAO-56 Table 19: **TODO(source): check the value** | no |
| soil depth classes shallow / medium / deep | 0.5 / 1.0 / 1.5 | m | SAMA classes (editable in Advisor mode) | n/a |
| soil evaporation before sowing (fallow Kc) | 0.3 | – | **TODO(source)**: FAO-56 ch. 7 | no |
| root-zone depletion on 1 Oct | 100 % of TAW | – | assumption: dry soil after the summer; autumn rain refills it before sowing | n/a |
| irrigation limited / moderate / available | 100 / 250 / 500 | mm per season | SAMA assumptions (editable) | n/a |
| good season | relative yield ≥ 80 % | – | configurable default | n/a |
| Warmer scenario | +2 | °C | illustrative what-if, **not a projection** | n/a |
| Dry / very dry rain multipliers | ×0.8 / ×0.6 | – | what-if | n/a |
| scenario percentiles favorable / dry / very dry | 70 / 25 / 7 | % of season rain | picks the nearest REAL season | n/a |
| Monte-Carlo | 1000 futures, seed 42, 3 seasons | – | spec | n/a |
| rotations "not separable" | top two within 5 points | – | SAMA rule | n/a |
| aquifer v, a | 3 m/yr, 0.30 | – | **TODO(source)**; always shown as "scenario, not measurement" | no |

Removed from Phase 1 because unsupported: flat effective-rain share 0.65, fixed Q = 2400 m³/ha, need factor 0.8,
legume ×0.9 on water need, 3 % random "non-climate failure".

## D. Crop parameters (`assets/data/crops.json`): DRAFT, verified by nobody
Source of every column: FAO-56 Table 11 (stage lengths), Table 12 (Kc), Table 22 (Zr, p); FAO-33 (Ky).
Sowing dates are SAMA assumptions for Morocco (not in the FAO tables). Stage lengths are adapted, not copied.

| crop | family | sowing d/m | stages ini/dev/mid/late (days) | Kc ini/mid/end | Zr max (m) | p | Ky | verified |
|---|---|---|---|---|---|---|---|---|
| softwheat | Poaceae | 15/11 | 30/60/60/40 | 0.4/1.15/0.3 | 1.5 | 0.55 | 1.0 | no |
| durumwheat | Poaceae | 15/11 | 30/60/60/40 | 0.4/1.15/0.3 | 1.5 | 0.55 | 1.0 | no |
| barley | Poaceae | 15/11 | 25/55/55/35 | 0.3/1.15/0.25 | 1.3 | 0.55 | 1.0 | no |
| oats | Poaceae | 15/11 | 25/55/55/35 | 0.3/1.15/0.25 | 1.3 | 0.55 | **none (excluded)** | no |
| maize | Poaceae | 15/4 | 30/40/50/30 | 0.3/1.2/0.35 | 1.0 | 0.55 | 1.25 | no |
| sorghum | Poaceae | 1/5 | 20/35/40/30 | 0.3/1.0/0.55 | 1.4 | 0.55 | 0.9 | no |
| fava | Fabaceae | 15/11 | 25/35/45/35 | 0.5/1.15/0.3 | 0.8 | 0.45 | 1.15 | no |
| chickpea | Fabaceae | 30/11 | 20/35/45/25 | 0.4/1.0/0.35 | 0.8 | 0.5 | **none (excluded)** | no |
| lentil | Fabaceae | 30/11 | 20/30/40/25 | 0.4/1.1/0.3 | 0.6 | 0.5 | **none (excluded)** | no |
| pea | Fabaceae | 15/11 | 20/30/35/20 | 0.5/1.15/0.3 | 0.8 | 0.35 | 1.15 | no |
| onion | Amaryllidaceae | 1/12 | 15/25/70/40 | 0.7/1.05/0.75 | 0.4 | 0.3 | 1.1 | no |
| garlic | Amaryllidaceae | 15/11 | 20/30/80/40 | 0.7/1.0/0.7 | 0.4 | 0.3 | **none (excluded)** | no |
| potato | Solanaceae | 15/2 | 25/30/45/30 | 0.5/1.15/0.75 | 0.5 | 0.35 | 1.1 | no |
| carrot | Apiaceae | 15/10 | 20/30/50/20 | 0.7/1.05/0.95 | 0.5 | 0.35 | **none (excluded)** | no |
| tomato | Solanaceae | 15/3 | 30/40/45/30 | 0.6/1.15/0.8 | 0.7 | 0.4 | 1.05 | no |
| pepper | Solanaceae | 15/3 | 30/35/40/20 | 0.6/1.05/0.9 | 0.6 | 0.3 | 1.1 | no |
| courgette | Cucurbitaceae | 15/3 | 20/30/25/15 | 0.5/0.95/0.75 | 0.6 | 0.5 | **none (excluded)** | no |
| cabbage | Brassicaceae | 15/10 | 40/60/50/15 | 0.7/1.05/0.95 | 0.5 | 0.45 | 0.95 | no |
| watermelon | Cucurbitaceae | 1/4 | 20/30/30/30 | 0.4/1.0/0.75 | 0.8 | 0.4 | 1.1 | no |
| melon | Cucurbitaceae | 1/4 | 25/35/40/20 | 0.5/1.05/0.75 | 0.8 | 0.4 | 0.9 | no |
| sunflower | Asteraceae | 15/3 | 25/35/45/25 | 0.35/1.0/0.35 | 1.2 | 0.45 | 0.95 | no |
| rapeseed | Brassicaceae | 20/10 | 30/50/60/30 | 0.35/1.15/0.35 | 1.0 | 0.6 | **none (excluded)** | no |
| sugarbeet | Chenopodiaceae | 15/10 | 30/45/90/50 | 0.35/1.2/0.7 | 1.2 | 0.55 | 1.0 | no |
| alfalfa | Fabaceae | 1/10 | 20/50/150/40 | 0.4/1.2/1.15 | 1.5 | 0.55 | 1.1 | no |
Crops with Ky = none (oats, chickpea, lentil, garlic, carrot, courgette, rapeseed) have no value I can cite: they stay in the
catalogue, show "More information needed" and are never recommended. Trees are not part of the 3-season model.

## E. Rotation rules (`assets/data/rotation_rules.json`)
| rule | effect | source |
|---|---|---|
| same botanical family two seasons in a row | visible "Use caution" flag, **no yield change** | TODO(source) |
| Solanaceae after Solanaceae | visible flag, **no yield change** | TODO(source) |
| legume before another crop | note only (nitrogen, not water): **no water or yield change** | TODO(source) |

## F. Satellite layers (`lib/features/satellite/gibs.dart`)
Identifiers, tile matrix sets, formats and date ranges were read from the GIBS WMTS capabilities document on 2026-11-14.
| layer | tile matrix set | format | resolution shown | verified |
|---|---|---|---|---|
| MODIS_Terra_CorrectedReflectance_TrueColor | GoogleMapsCompatible_Level9 | jpeg | ≈ 250 m | capabilities: yes; resolution text: no |
| MODIS_Terra_L3_NDVI_Monthly | GoogleMapsCompatible_Level7 | png | ≈ 5 km (0.05°) | capabilities: yes; resolution text: no |
| IMERG_Precipitation_Rate | GoogleMapsCompatible_Level6 | png | ≈ 10 km (0.1°) | capabilities: yes; resolution text: no |
| SMAP_L4_Analyzed_Surface_Soil_Moisture | GoogleMapsCompatible_Level6 | png | ≈ 9 km | capabilities: yes; resolution text: no |

Only layers whose test tile loads are offered. These are images, not numeric NDVI or soil-moisture values.

## G. Places (`lib/data/places.dart`)
15 reference points (6 Saïs/Erfoud from the first brief, Meknès, 8 regional points from the Phase 2 brief). Coordinates are
approximate and not verified. This is NOT the GeoNames gazetteer (not bundled, see OPEN_ITEMS.md).
