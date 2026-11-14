import 'nasa_power_repository.dart';
import 'places.dart';

/// Which dataset answers for a farm. Never substituted silently.
enum ClimateKind {
  /// Downloaded earlier for these (rounded) coordinates.
  exactCache,

  /// The farm is at a bundled reference point.
  bundledExact,

  /// No exact data: the nearest bundled reference point, with its distance. Needs the farmer's confirmation.
  nearestReference,
}

class ClimateResolution {
  const ClimateResolution(
    this.climate,
    this.kind, {
    this.distanceKm = 0,
    this.referenceName,
  });
  final TownClimate climate;
  final ClimateKind kind;
  final double distanceKm;
  final String? referenceName;

  bool get approximate => kind == ClimateKind.nearestReference;
}

/// Pure selection rule (unit-tested): exact cache > bundled point with the same rounded coordinates >
/// nearest bundled reference location.
ClimateResolution selectDataset({
  required double lat,
  required double lon,
  required PowerData bundled,
  TownClimate? cached,
}) {
  if (cached != null) return ClimateResolution(cached, ClimateKind.exactCache);
  for (final p in places) {
    if (round2(p.lat) == round2(lat) &&
        round2(p.lon) == round2(lon) &&
        bundled.points.containsKey(p.id)) {
      return ClimateResolution(
        bundled.town(p.id),
        ClimateKind.bundledExact,
        referenceName: p.id,
      );
    }
  }
  final n = nearestPlace(lat, lon);
  return ClimateResolution(
    bundled.town(n.place.id),
    ClimateKind.nearestReference,
    distanceKm: n.km,
    referenceName: n.place.id,
  );
}
