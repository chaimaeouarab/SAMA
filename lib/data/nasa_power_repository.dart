import '../core/constants.dart';

/// Climate numbers for one town, parsed from the bundled NASA POWER file.
/// Rain is stored per year as 366 slots in tenths of mm (index = day of year - 1,
/// Feb 29 always has its own slot); -1 = missing (NASA fill value -999 is never counted).
class TownClimate {
  TownClimate({
    required this.lat,
    required this.lon,
    required this.rain,
    required this.clim,
  });

  final double lat;
  final double lon;
  final Map<int, List<int>> rain;
  final Map<String, List<double?>> clim;

  factory TownClimate.fromJson(Map<String, dynamic> j) {
    final rain = <int, List<int>>{
      for (final e in (j['rain'] as Map<String, dynamic>).entries)
        int.parse(e.key): (e.value as List)
            .cast<num>()
            .map((v) => v.toInt())
            .toList(),
    };
    final clim = <String, List<double?>>{
      for (final e in (j['clim'] as Map<String, dynamic>).entries)
        e.key: (e.value as List).map((v) => (v as num?)?.toDouble()).toList(),
    };
    return TownClimate(
      lat: (j['lat'] as num).toDouble(),
      lon: (j['lon'] as num).toDouble(),
      rain: rain,
      clim: clim,
    );
  }

  /// Index in the 366-slot layout for a calendar date.
  static int slot(DateTime d) {
    final leap = d.year % 4 == 0 && (d.year % 100 != 0 || d.year % 400 == 0);
    // UTC on both sides: local time zones with daylight saving would be off by one day.
    final yday = DateTime.utc(
      d.year,
      d.month,
      d.day,
    ).difference(DateTime.utc(d.year, 1, 1)).inDays;
    return (!leap && yday >= 59) ? yday + 1 : yday;
  }

  /// Season = Oct 1 (slot 274) -> May 31 (slot 151 of next year).
  static const _octFirst = 274;
  static const _mayLast = 151;

  /// Rain (mm) of the season starting in [startYear]; null if a needed year is missing.
  double? seasonRain(int startYear) {
    final a = rain[startYear];
    final b = rain[startYear + 1];
    if (a == null || b == null) return null;
    var tenths = 0;
    for (var i = _octFirst; i < 366; i++) {
      if (a[i] > 0) tenths += a[i];
    }
    for (var i = 0; i <= _mayLast; i++) {
      if (b[i] > 0) tenths += b[i];
    }
    return tenths / 10;
  }

  /// The 40 historical season totals (1984-85 ... 2023-24).
  List<double> get seasonRains => [
    for (var y = firstSeasonYear; y < firstSeasonYear + seasonCount; y++)
      seasonRain(y) ?? 0,
  ];

  /// Mean daily rain (mm) for a slot over all years, ignoring missing days.
  double meanRain(int slot) {
    var sum = 0, n = 0;
    for (final r in rain.values) {
      if (r[slot] >= 0) {
        sum += r[slot];
        n++;
      }
    }
    return n == 0 ? 0 : sum / n / 10;
  }

  /// Mean rain (mm) per calendar month (1..12), summing daily climatology.
  List<double> get monthlyRain {
    final out = List<double>.filled(12, 0);
    const days = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    var slot = 0;
    for (var m = 0; m < 12; m++) {
      for (var d = 0; d < days[m]; d++) {
        out[m] += meanRain(slot++);
      }
    }
    out[1] -= meanRain(59) * (1 - 0.2425); // Feb 29 only exists in ~1 year in 4
    return out;
  }

  /// Typical cumulative rain (mm) from Oct 1 up to and including [today] (season to date).
  double typicalSeasonToDate(DateTime today) {
    final s = slot(today);
    var sum = 0.0;
    if (s >= _octFirst) {
      for (var i = _octFirst; i <= s; i++) {
        sum += meanRain(i);
      }
    } else {
      for (var i = _octFirst; i < 366; i++) {
        sum += meanRain(i);
      }
      for (var i = 0; i <= s; i++) {
        sum += meanRain(i);
      }
    }
    return sum;
  }

  double? climToday(String key, DateTime d) => clim[key]?[slot(d)];

  /// Typical rain (mm) over the 30 days ending today, a readable "Rain" stat.
  double rainLast30(DateTime d) {
    var sum = 0.0;
    final s = slot(d);
    for (var k = 0; k < 30; k++) {
      sum += meanRain((s - k + 366) % 366);
    }
    return sum;
  }
}

class PowerData {
  PowerData(this.towns);
  final Map<String, TownClimate> towns;

  factory PowerData.fromJson(Map<String, dynamic> j) => PowerData({
    for (final e in (j['towns'] as Map<String, dynamic>).entries)
      e.key: TownClimate.fromJson(e.value as Map<String, dynamic>),
  });

  TownClimate town(String id) => towns[id] ?? towns.values.first;
}
