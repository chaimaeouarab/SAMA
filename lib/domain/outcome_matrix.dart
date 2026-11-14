import '../data/crops_catalog.dart';
import '../data/nasa_power_repository.dart';
import 'crop_model.dart';
import 'et0.dart';
import 'scenarios.dart';

/// Outcome of every annual crop in every historical season for one farm and one shock.
/// Built once; Monte-Carlo, rotations, Time Machine and Detective only read it.
class OutcomeMatrix {
  OutcomeMatrix._(this.byCrop, this.et0Seasons, this.seasonCount);

  final Map<String, List<SeasonOutcome>> byCrop;
  final List<Et0Series> et0Seasons;
  final int seasonCount;

  factory OutcomeMatrix.build({
    required List<Crop> crops,
    required TownClimate climate,
    required FarmParams farm,
    Shock shock = Shock.none,
    List<Et0Series>? et0Cache,
  }) {
    final seasons = climate.seasons;
    // ET0 does not depend on the farm inputs: callers that vary soil/irrigation reuse it.
    final et0 =
        et0Cache ??
        [
          for (final s in seasons)
            et0Season(
              s,
              lat: climate.srcLat,
              elev: climate.elev,
              tempAdd: shock.tempAdd,
            ),
        ];
    final out = <String, List<SeasonOutcome>>{};
    for (final c in crops) {
      final m = c.model;
      if (!c.annual || m == null) continue;
      out[c.id] = [
        for (var i = 0; i < seasons.length; i++)
          simulateSeason(
            crop: m,
            season: seasons[i],
            et0: et0[i].values,
            farm: farm,
            rainMult: shock.rainMult,
          ),
      ];
    }
    return OutcomeMatrix._(out, et0, seasons.length);
  }

  SeasonOutcome at(String cropId, int season) => byCrop[cropId]![season];

  /// Share of historical seasons with relative yield >= [threshold]. Null when the crop has no Ky.
  double? chance(String cropId, double threshold) {
    final l = byCrop[cropId];
    if (l == null || l.first.ry == null) return null;
    return l.where((o) => o.ry! >= threshold).length / l.length;
  }

  List<double> ryList(String cropId) => [
    for (final o in byCrop[cropId]!) o.ry ?? 0,
  ];
}
