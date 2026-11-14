import 'dart:math';

/// Coordinates are approximate (TODO(source): verify, docs/OPEN_ITEMS.md).
class Town {
  const Town(this.id, this.ar, this.en, this.fr, this.lat, this.lon);
  final String id;
  final String ar;
  final String en;
  final String fr;
  final double lat;
  final double lon;

  String name(String langCode) => switch (langCode) {
    'ar' => ar,
    'fr' => fr,
    _ => en,
  };
}

const towns = <Town>[
  Town('boufakrane', 'بوفكران', 'Boufakrane', 'Boufakrane', 33.72, -5.30),
  Town('elhajeb', 'الحاجب', 'El Hajeb', 'El Hajeb', 33.69, -5.37),
  Town('sebaaaioun', 'سبع عيون', 'Sebaa Aioun', 'Sebaa Aioun', 33.85, -5.46),
  Town(
    'aintaoujdate',
    'عين تاوجطات',
    'Aïn Taoujdate',
    'Aïn Taoujdate',
    33.93,
    -4.77,
  ),
  Town('mhaya', 'مهاية', 'Mhaya', 'Mhaya', 33.93, -5.43),
  Town('erfoud', 'أرفود', 'Erfoud', 'Erfoud', 31.43, -4.23),
];

Town townById(String id) =>
    towns.firstWhere((t) => t.id == id, orElse: () => towns.first);

double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      pow(sin(dLat / 2), 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLon / 2), 2);
  return 2 * r * asin(sqrt(a));
}

/// Nearest town within [maxKm], else null (the UI then asks the user to choose).
Town? snapToTown(double lat, double lon, {double maxKm = 50}) {
  Town? best;
  var bestD = double.infinity;
  for (final t in towns) {
    final d = distanceKm(lat, lon, t.lat, t.lon);
    if (d < bestD) {
      bestD = d;
      best = t;
    }
  }
  return bestD <= maxKm ? best : null;
}
