import 'dart:math';

/// Sunrise and sunset in minutes after local midnight (NOAA solar formulas).
class SunTimes {
  const SunTimes(this.sunrise, this.sunset);
  final double sunrise;
  final double sunset;

  static String format(double minutes) {
    final m = minutes.round();
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  /// 0..1 position of [nowMinutes] between sunrise and sunset.
  double fraction(double nowMinutes) =>
      ((nowMinutes - sunrise) / (sunset - sunrise)).clamp(0.0, 1.0);
}

SunTimes sunTimes({
  required double lat,
  required double lon,
  required DateTime date,
  required double utcOffset,
}) {
  final doy =
      DateTime.utc(
        date.year,
        date.month,
        date.day,
      ).difference(DateTime.utc(date.year, 1, 1)).inDays +
      1;
  final g = 2 * pi / 365 * (doy - 1);
  final eqTime =
      229.18 *
      (0.000075 +
          0.001868 * cos(g) -
          0.032077 * sin(g) -
          0.014615 * cos(2 * g) -
          0.040849 * sin(2 * g));
  final decl =
      0.006918 -
      0.399912 * cos(g) +
      0.070257 * sin(g) -
      0.006758 * cos(2 * g) +
      0.000907 * sin(2 * g) -
      0.002697 * cos(3 * g) +
      0.00148 * sin(3 * g);
  final latR = lat * pi / 180;
  final cosHa =
      cos(90.833 * pi / 180) / (cos(latR) * cos(decl)) - tan(latR) * tan(decl);
  final ha = acos(cosHa.clamp(-1.0, 1.0)) * 180 / pi;
  final offset = utcOffset * 60;
  return SunTimes(
    720 - 4 * (lon + ha) - eqTime + offset,
    720 - 4 * (lon - ha) - eqTime + offset,
  );
}
