import 'dart:math';

import '../core/constants.dart';
import '../data/crops_catalog.dart';
import '../data/nasa_power_repository.dart';

/// Farm inputs that change the water balance.
class FarmParams {
  const FarmParams({
    required this.soilDepthM,
    required this.irrigationMm,
    this.tawPerM = ModelConstants.tawPerMetre,
    this.fallowKc = ModelConstants.fallowKc,
    this.startDepletionShare = ModelConstants.startDepletionShare,
  });

  /// Usable soil depth (m). Limits the rooting depth.
  final double soilDepthM;

  /// Irrigation water available for one season (mm). 0 = rainfed.
  final double irrigationMm;

  /// Total available water per metre of soil (mm/m).
  final double tawPerM;
  final double fallowKc;

  /// Depletion at Oct 1 as a share of TAW (dry soil after the summer).
  final double startDepletionShare;
}

class SeasonOutcome {
  const SeasonOutcome({
    required this.etc,
    required this.eta,
    required this.et0Cycle,
    required this.rainCycle,
    required this.effectiveRain,
    required this.irrigation,
    required this.lost,
    required this.ry,
  });

  /// Crop evapotranspiration requirement and actual, over the crop cycle (mm).
  final double etc;
  final double eta;
  final double et0Cycle;
  final double rainCycle;

  /// Rain that stayed in the root zone (rain minus drainage/runoff), mm.
  final double effectiveRain;
  final double irrigation;

  /// Rain lost to drainage/runoff during the cycle (waterlogging note above [ModelConstants.waterloggingNoteMm]).
  final double lost;

  /// Relative yield 0..1 (FAO-33), null when the crop has no documented Ky.
  final double? ry;

  double get deficit => max(0.0, etc - eta);
  bool? goodAt(double threshold) => ry == null ? null : ry! >= threshold;
}

/// FAO-56 single crop coefficient on cycle day [d] (0-based): flat initial, linear development,
/// flat mid-season, linear decline to the end value (eq. 66 pattern).
double kcOnDay(CropModelSpec c, int d) {
  final ini = c.stages[0],
      dev = c.stages[1],
      mid = c.stages[2],
      late = c.stages[3];
  if (d < ini) return c.kcIni;
  if (d < ini + dev) return c.kcIni + (c.kcMid - c.kcIni) * (d - ini) / dev;
  if (d < ini + dev + mid) return c.kcMid;
  return c.kcMid + (c.kcEnd - c.kcMid) * (d - ini - dev - mid) / late;
}

/// Daily soil-water bucket over one agricultural year.
///
/// Before sowing the soil is fallow (soil evaporation only, Kc = fallowKc) so that autumn/winter rain
/// refills the root zone; this gives the initial depletion at sowing instead of an arbitrary number.
/// Rain beyond the root-zone capacity is lost (drainage/runoff): effective rain is what the bucket keeps,
/// computed day by day. Irrigation is applied when the depletion reaches RAW, until the seasonal budget is used.
/// Stress (FAO-56 eq. 84): Ks = (TAW - Dr) / ((1 - p) TAW) when Dr > RAW. Root depth is constant (simplification).
SeasonOutcome simulateSeason({
  required CropModelSpec crop,
  required SeasonSeries season,
  required List<double> et0,
  required FarmParams farm,
  double rainMult = 1.0,
}) {
  final zr = min(crop.zrMax, farm.soilDepthM);
  final taw = farm.tawPerM * zr;
  final raw = crop.p * taw;
  var dr = taw * farm.startDepletionShare;
  var budget = farm.irrigationMm;

  final sowYear = crop.sowMonth >= 10 ? season.startYear : season.startYear + 1;
  final sowIdx = DateTime.utc(
    sowYear,
    crop.sowMonth,
    crop.sowDay,
  ).difference(DateTime.utc(season.startYear, 10, 1)).inDays;
  final endIdx = min(season.days, sowIdx + crop.cycleDays);

  double etc = 0, eta = 0, et0c = 0, rainC = 0, lostC = 0, irrC = 0;
  for (var i = 0; i < endIdx; i++) {
    final rain = (season.rain[i] ?? 0) * rainMult;
    dr -= rain;
    var lost = 0.0;
    if (dr < 0) {
      lost = -dr;
      dr = 0;
    }
    final inCycle = i >= sowIdx;
    if (!inCycle) {
      dr = min(taw, dr + farm.fallowKc * et0[i]);
      continue;
    }
    if (dr >= raw && budget > 0) {
      final irr = min(dr, budget);
      dr -= irr;
      budget -= irr;
      irrC += irr;
    }
    final kc = kcOnDay(crop, i - sowIdx);
    final ks = dr <= raw ? 1.0 : max(0.0, (taw - dr) / (taw - raw));
    final dayEtc = kc * et0[i];
    final dayEta = ks * dayEtc;
    dr = min(taw, dr + dayEta);
    etc += dayEtc;
    eta += dayEta;
    et0c += et0[i];
    rainC += rain;
    lostC += lost;
  }
  final ky = crop.ky;
  final ry = (ky == null || etc <= 0)
      ? null
      : (1 - ky * (1 - eta / etc)).clamp(0.0, 1.0);
  return SeasonOutcome(
    etc: etc,
    eta: eta,
    et0Cycle: et0c,
    rainCycle: rainC,
    effectiveRain: max(0.0, rainC - lostC),
    irrigation: irrC,
    lost: lostC,
    ry: ry,
  );
}
