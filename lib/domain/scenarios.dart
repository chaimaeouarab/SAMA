import '../core/constants.dart';
import '../data/nasa_power_repository.dart';

/// What-if settings. A hypothetical result is always labelled "What-if scenario, not NASA observation".
class Shock {
  const Shock({this.rainMult = 1.0, this.tempAdd = 0.0});
  final double rainMult;
  final double tempAdd;
  bool get isHypothetical => rainMult != 1.0 || tempAdd != 0.0;

  static const none = Shock();

  @override
  bool operator ==(Object other) =>
      other is Shock && other.rainMult == rainMult && other.tempAdd == tempAdd;
  @override
  int get hashCode => Object.hash(rainMult, tempAdd);
}

enum ClimateYear { favorable, dry, veryDry }

/// Percentile of [sorted] values (linear position, nearest rank): q in 0..1.
int percentileIndex(int n, double q) => ((n - 1) * q).round().clamp(0, n - 1);

/// Pick the REAL historical season whose rainy-season rain is nearest to the requested percentile.
/// Returns the index in [seasons]. Never invents a season.
int scenarioSeasonIndex(List<SeasonSeries> seasons, ClimateYear y) {
  final rains = [for (final s in seasons) s.rainySeasonRain];
  final order = List<int>.generate(rains.length, (i) => i)
    ..sort((a, b) => rains[a].compareTo(rains[b]));
  final q = switch (y) {
    ClimateYear.favorable => ModelConstants.percentileFavorable,
    ClimateYear.dry => ModelConstants.percentileDry,
    ClimateYear.veryDry => ModelConstants.percentileVeryDry,
  };
  return order[percentileIndex(order.length, q)];
}

/// "1984–85" for the season that starts in October 1984 + [index].
String seasonLabel(int index, {int firstYear = 1984}) {
  final y = firstYear + index;
  final next = (y + 1) % 100;
  return '$y–${next < 10 ? '0' : ''}$next';
}
