import 'dart:math';

import '../core/constants.dart';
import 'crop_model.dart';
import 'outcome_matrix.dart';
import 'rng.dart';

/// Pre-drawn futures: [runs] x [seasonsPerFuture] indices of WHOLE historical seasons (with replacement).
/// Each simulated season is one real season with its full daily series, so rain timing is preserved.
/// Seasons are assumed independent of each other (a simplification: real droughts can cluster).
/// Deterministic: same seed -> same draws on every device. Shared by all rotations (common random numbers).
List<List<int>> drawFutures({
  required int seasonCount,
  int runs = ModelConstants.simulations,
  int seasons = ModelConstants.seasonsPerFuture,
  int seed = ModelConstants.seed,
}) {
  final rng = Mulberry32(seed);
  return [
    for (var r = 0; r < runs; r++)
      [for (var k = 0; k < seasons; k++) rng.nextInt(seasonCount)],
  ];
}

double _quantile(List<double> sorted, double q) {
  if (sorted.isEmpty) return 0;
  final pos = (sorted.length - 1) * q;
  final lo = pos.floor(), hi = pos.ceil();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}

double quantile(List<double> values, double q) =>
    _quantile([...values]..sort(), q);

/// What the farmer sees for one season of a rotation (statistics over the 40 REAL seasons).
class SeasonStat {
  const SeasonStat({
    required this.cropId,
    required this.shareGood,
    required this.ryP10,
    required this.ryP50,
    required this.ryP90,
    required this.et0,
    required this.etc,
    required this.effectiveRain,
    required this.irrigation,
    required this.deficit,
    required this.bestSeason,
    required this.worstSeason,
  });
  final String cropId;
  final double shareGood;
  final double ryP10, ryP50, ryP90;
  final double et0, etc, effectiveRain, irrigation, deficit;

  /// Indices (into the 40 historical seasons) of the best and worst real example years.
  final int bestSeason, worstSeason;
}

class RotationResult {
  const RotationResult({
    required this.cropIds,
    required this.pAllGood,
    required this.expectedRy,
    required this.p10,
    required this.p50,
    required this.p90,
    required this.worst,
    required this.expectedDeficit,
    required this.perSeason,
  });

  final List<String> cropIds;

  /// Probability that all 3 seasons reach the yield threshold (shown as "X in 10").
  final double pAllGood;
  final double expectedRy;

  /// Quantiles of the mean relative yield over the 3 seasons.
  final double p10, p50, p90;
  final double worst;
  final double expectedDeficit; // mm over the 3 seasons
  final List<SeasonStat> perSeason;

  int get inTen => (10 * pAllGood).round();
}

/// Evaluate a 3-season sequence. Returns null if a crop has no documented Ky (cannot be evaluated).
RotationResult? evaluateRotation({
  required List<String> cropIds,
  required OutcomeMatrix matrix,
  required List<List<int>> futures,
  double threshold = ModelConstants.goodYieldThreshold,
}) {
  for (final id in cropIds) {
    final l = matrix.byCrop[id];
    if (l == null || l.first.ry == null) return null;
  }
  var allGood = 0;
  var sumRy = 0.0, sumDef = 0.0;
  final means = <double>[];
  for (final f in futures) {
    var good = true, ry = 0.0, def = 0.0;
    for (var k = 0; k < cropIds.length; k++) {
      final o = matrix.at(cropIds[k], f[k]);
      if (o.ry! < threshold) good = false;
      ry += o.ry!;
      def += o.deficit;
    }
    if (good) allGood++;
    ry /= cropIds.length;
    means.add(ry);
    sumRy += ry;
    sumDef += def;
  }
  final sorted = [...means]..sort();
  final n = futures.length;

  final stats = <SeasonStat>[];
  for (final id in cropIds) {
    final outs = matrix.byCrop[id]!;
    final rys = [for (final o in outs) o.ry!];
    var best = 0, worst = 0;
    for (var i = 1; i < rys.length; i++) {
      if (rys[i] > rys[best]) best = i;
      if (rys[i] < rys[worst]) worst = i;
    }
    double mean(double Function(SeasonOutcome) f) =>
        outs.map(f).reduce((a, b) => a + b) / outs.length;
    final sortedRy = [...rys]..sort();
    stats.add(
      SeasonStat(
        cropId: id,
        shareGood: rys.where((v) => v >= threshold).length / rys.length,
        ryP10: _quantile(sortedRy, 0.1),
        ryP50: _quantile(sortedRy, 0.5),
        ryP90: _quantile(sortedRy, 0.9),
        et0: mean((o) => o.et0Cycle),
        etc: mean((o) => o.etc),
        effectiveRain: mean((o) => o.effectiveRain),
        irrigation: mean((o) => o.irrigation),
        deficit: mean((o) => o.deficit),
        bestSeason: best,
        worstSeason: worst,
      ),
    );
  }
  return RotationResult(
    cropIds: cropIds,
    pAllGood: allGood / n,
    expectedRy: sumRy / n,
    p10: _quantile(sorted, 0.1),
    p50: _quantile(sorted, 0.5),
    p90: _quantile(sorted, 0.9),
    worst: sorted.isEmpty ? 0 : sorted.first,
    expectedDeficit: sumDef / n,
    perSeason: stats,
  );
}

/// Better = higher probability of three good seasons, then higher expected yield.
int compareRotations(RotationResult a, RotationResult b) {
  final d = b.pAllGood.compareTo(a.pAllGood);
  return d != 0 ? d : b.expectedRy.compareTo(a.expectedRy);
}

double clamp01(double v) => max(0.0, min(1.0, v));
