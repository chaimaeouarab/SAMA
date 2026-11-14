import 'dart:math';

/// A supported reference location with bundled NASA data.
/// Coordinates are approximate (TODO(source): verify, docs/OPEN_ITEMS.md).
class Place {
  const Place(
    this.id,
    this.dar,
    this.ar,
    this.en,
    this.fr,
    this.lat,
    this.lon, {
    this.region = '',
  });
  final String id;
  final String dar;
  final String ar;
  final String en;
  final String fr;
  final double lat;
  final double lon;
  final String region;

  String name(String lang) => switch (lang) {
    'dar' => dar,
    'ar' => ar,
    'fr' => fr,
    _ => en,
  };
}

const places = <Place>[
  Place(
    'boufakrane',
    'بوفكران',
    'بوفكران',
    'Boufakrane',
    'Boufakrane',
    33.72,
    -5.30,
    region: 'Saïs',
  ),
  Place(
    'elhajeb',
    'الحاجب',
    'الحاجب',
    'El Hajeb',
    'El Hajeb',
    33.69,
    -5.37,
    region: 'Saïs',
  ),
  Place(
    'sebaaaioun',
    'سبع عيون',
    'سبع عيون',
    'Sebaa Aioun',
    'Sebaa Aioun',
    33.85,
    -5.46,
    region: 'Saïs',
  ),
  Place(
    'aintaoujdate',
    'عين تاوجطات',
    'عين تاوجدات',
    'Aïn Taoujdate',
    'Aïn Taoujdate',
    33.93,
    -4.77,
    region: 'Saïs',
  ),
  Place(
    'mhaya',
    'مهاية',
    'مهاية',
    'Mhaya',
    'Mhaya',
    33.93,
    -5.43,
    region: 'Saïs',
  ),
  Place(
    'meknes',
    'مكناس',
    'مكناس',
    'Meknès',
    'Meknès',
    33.89,
    -5.55,
    region: 'Saïs',
  ),
  Place(
    'erfoud',
    'أرفود',
    'أرفود',
    'Erfoud',
    'Erfoud',
    31.43,
    -4.23,
    region: 'Tafilalet',
  ),
  Place(
    'kenitra',
    'القنيطرة',
    'القنيطرة',
    'Kenitra',
    'Kénitra',
    34.26,
    -6.58,
    region: 'Gharb',
  ),
  Place(
    'sidislimane',
    'سيدي سليمان',
    'سيدي سليمان',
    'Sidi Slimane',
    'Sidi Slimane',
    34.26,
    -5.93,
    region: 'Gharb',
  ),
  Place(
    'eljadida',
    'الجديدة',
    'الجديدة',
    'El Jadida',
    'El Jadida',
    33.25,
    -8.50,
    region: 'Doukkala',
  ),
  Place(
    'zemamra',
    'زمامرة',
    'الزمامرة',
    'Zemamra',
    'Zemamra',
    32.63,
    -8.70,
    region: 'Doukkala',
  ),
  Place(
    'benimellal',
    'بني ملال',
    'بني ملال',
    'Beni Mellal',
    'Béni Mellal',
    32.34,
    -6.35,
    region: 'Tadla',
  ),
  Place(
    'fquihbensalah',
    'الفقيه بن صالح',
    'الفقيه بن صالح',
    'Fquih Ben Salah',
    'Fquih Ben Salah',
    32.50,
    -6.69,
    region: 'Tadla',
  ),
  Place(
    'taroudant',
    'تارودانت',
    'تارودانت',
    'Taroudant',
    'Taroudant',
    30.47,
    -8.87,
    region: 'Souss-Massa',
  ),
  Place(
    'agadir',
    'أكادير',
    'أكادير',
    'Agadir',
    'Agadir',
    30.35,
    -9.57,
    region: 'Souss-Massa',
  ),
];

Place placeById(String id) =>
    places.firstWhere((p) => p.id == id, orElse: () => places.first);

double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1), dLon = rad(lon2 - lon1);
  final a =
      pow(sin(dLat / 2), 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLon / 2), 2);
  return 2 * r * asin(sqrt(a));
}

/// Nearest supported place, always returned with its distance (callers decide if it is close enough).
({Place place, double km}) nearestPlace(double lat, double lon) {
  Place best = places.first;
  var bestD = double.infinity;
  for (final p in places) {
    final d = distanceKm(lat, lon, p.lat, p.lon);
    if (d < bestD) {
      bestD = d;
      best = p;
    }
  }
  return (place: best, km: bestD);
}

/// Coordinates sent to NASA and used as cache key are rounded to 2 decimals (about 1 km).
double round2(double v) => (v * 100).round() / 100;
String cacheKey(double lat, double lon) =>
    '${round2(lat).toStringAsFixed(2)}_${round2(lon).toStringAsFixed(2)}';

/// Rough Morocco bounding box, only to warn that assumptions are calibrated for Morocco.
bool insideMorocco(double lat, double lon) =>
    lat >= 20.5 && lat <= 36.0 && lon >= -17.5 && lon <= -0.9;

/// Search the bundled gazetteer (no network). Matches the name in any language, ignoring case and accents.
List<Place> searchPlaces(String query) {
  String norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâ]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll('ï', 'i')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .trim();
  final q = norm(query);
  if (q.isEmpty) return const [];
  return [
    for (final p in places)
      if ([p.dar, p.ar, p.en, p.fr, p.region].any((n) => norm(n).contains(q)))
        p,
  ];
}

/// POWER meteorology (MERRA-2) is gridded at 0.5 deg latitude x 0.625 deg longitude. The API echoes the REQUESTED
/// coordinates, not the cell, so the cell centre is derived here from the grid definition. Two places in the same
/// cell get identical data (verified: Sebaa Aioun, Mhaya and Meknes). Approximation: solar radiation (CERES) is coarser.
({double lat, double lon}) gridCell(double lat, double lon) => (
  lat: (lat / 0.5).round() * 0.5,
  lon: ((lon + 180) / 0.625).round() * 0.625 - 180,
);
