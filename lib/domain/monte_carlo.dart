import '../core/constants.dart';
import '../data/crops_catalog.dart';
import 'rng.dart';
import 'water_balance.dart';

class SimResult {
  const SimResult(this.good, this.total);
  final int good;
  final int total;
  double get p => total == 0 ? 0 : good / total;

  /// "X in 10"
  int get inTen => (10 * p).round();
}

/// Simulate futures where each season is one of the historical [rains] totals.
/// A future is good only if every season in [sequence] is good.
/// Deterministic: a fresh mulberry32(seed) per call, so same input -> same output.
SimResult simulate({
  required List<Crop> sequence,
  required List<double> rains,
  required SoilDepth soil,
  required bool previousLegume,
  int runs = ModelConstants.simulations,
  int seed = ModelConstants.seed,
}) {
  assert(
    sequence.every((c) => c.waterNeed != null),
    'trees are not part of the model',
  );
  final rng = Mulberry32(seed);
  var good = 0;
  for (var r = 0; r < runs; r++) {
    var allGood = true;
    for (var i = 0; i < sequence.length; i++) {
      // Always draw both numbers so every plan consumes the random stream the same way.
      final rain = rains[rng.nextInt(rains.length)];
      final failed = rng.next() < ModelConstants.nonClimateFailure;
      final prevLegume = i == 0 ? previousLegume : sequence[i - 1].legume;
      if (failed ||
          !climateGood(
            rain,
            sequence[i].waterNeed!,
            soil,
            previousLegume: prevLegume,
          )) {
        allGood = false;
      }
    }
    if (allGood) good++;
  }
  return SimResult(good, runs);
}
