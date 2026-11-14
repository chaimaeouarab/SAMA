import '../core/constants.dart';
import 'places.dart';

/// One agricultural year (Oct 1 -> Sep 30) of daily NASA POWER values. null = missing (-999 in the file).
class SeasonSeries {
  SeasonSeries({
    required this.startYear,
    required this.rain,
    required this.tmax,
    required this.tmin,
    required this.rh,
    required this.ws,
    required this.rad,
  });

  /// Year in which the season starts (October).
  final int startYear;
  final List<double?> rain; // mm/day
  final List<double?> tmax; // deg C
  final List<double?> tmin;
  final List<double?> rh; // %
  final List<double?> ws; // m/s at 2 m
  final List<double?> rad; // MJ/m2/day (ALLSKY_SFC_SW_DWN)

  int get days => rain.length;
  DateTime dateAt(int i) =>
      DateTime.utc(startYear, 10, 1).add(Duration(days: i));

  /// Rain from Oct 1 to May 31 (the rainy season), mm. Missing days count as 0 and are reported by [missingRainDays].
  double get rainySeasonRain {
    final end = DateTime.utc(
      startYear + 1,
      6,
      1,
    ).difference(DateTime.utc(startYear, 10, 1)).inDays;
    var s = 0.0;
    for (var i = 0; i < end && i < days; i++) {
      s += rain[i] ?? 0;
    }
    return s;
  }

  int get missingRainDays => rain.where((v) => v == null).length;

  SeasonSeries copyWith({
    List<double?>? rain,
    List<double?>? tmax,
    List<double?>? tmin,
  }) => SeasonSeries(
    startYear: startYear,
    rain: rain ?? this.rain,
    tmax: tmax ?? this.tmax,
    tmin: tmin ?? this.tmin,
    rh: rh,
    ws: ws,
    rad: rad,
  );
}

/// Climate numbers for one point, parsed from the bundled NASA POWER file (or a cached download).
/// `rain` holds 366 slots per year in tenths of mm (index = day of year - 1, Feb 29 keeps slot 59), -1 = missing.
class TownClimate {
  TownClimate({
    required this.id,
    required this.lat,
    required this.lon,
    required this.srcLat,
    required this.srcLon,
    required this.elev,
    required this.rain,
    required this.clim,
    required this.seasons,
    required this.coverage,
    this.fetched,
  });

  final String id;
  final double lat;
  final double lon;

  /// What NASA returned: centre of the grid cell and its elevation (m). Not a field measurement.
  final double srcLat;
  final double srcLon;
  final double elev;
  final Map<int, List<int>> rain;
  final Map<String, List<double?>> clim;
  final List<SeasonSeries> seasons;
  final Map<String, int> coverage;
  final String? fetched;

  static List<double?> _col(List v, double scale) => [
    for (final x in v) (x as num) <= -990 ? null : x.toDouble() / scale,
  ];

  factory TownClimate.fromJson(String id, Map<String, dynamic> j) {
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
    final s = j['seasons'] as Map<String, dynamic>;
    final n = (s['rain'] as List).length;
    final seasons = [
      for (var i = 0; i < n; i++)
        SeasonSeries(
          startYear: firstSeasonYear + i,
          rain: _col((s['rain'] as List)[i] as List, 10),
          tmax: _col((s['tmax'] as List)[i] as List, 10),
          tmin: _col((s['tmin'] as List)[i] as List, 10),
          rh: _col((s['rh'] as List)[i] as List, 10),
          ws: _col((s['ws'] as List)[i] as List, 10),
          rad: _col((s['rad'] as List)[i] as List, 10),
        ),
    ];
    return TownClimate(
      id: id,
      lat: (j['lat'] as num).toDouble(),
      lon: (j['lon'] as num).toDouble(),
      srcLat: (j['srcLat'] as num).toDouble(),
      srcLon: (j['srcLon'] as num).toDouble(),
      elev: (j['elev'] as num?)?.toDouble() ?? 0,
      rain: rain,
      clim: clim,
      seasons: seasons,
      coverage: (j['coverage'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      ),
      fetched: j['fetched'] as String?,
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

  static const _octFirst = 274;
  static const _mayLast = 151;

  /// Rain (mm) Oct 1 -> May 31 of the season starting in [startYear]; null if a needed year is missing.
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

  /// The historical rainy-season totals (1984-85 ... 2023-24).
  List<double> get seasonRains => [for (final s in seasons) s.rainySeasonRain];

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

  /// Mean rain (mm) per calendar month (index 0 = January).
  List<double> get monthlyRain {
    final out = List<double>.filled(12, 0);
    const days = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    var slot = 0;
    for (var m = 0; m < 12; m++) {
      for (var d = 0; d < days[m]; d++) {
        out[m] += meanRain(slot++);
      }
    }
    out[1] -= meanRain(59) * (1 - 0.2425); // Feb 29 exists in about 1 year in 4
    return out;
  }

  /// Typical cumulative rain (mm) from Oct 1 up to [today].
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

  /// Typical rain (mm) over the 30 days ending [d].
  double rainLast30(DateTime d) {
    var sum = 0.0;
    final s = slot(d);
    for (var k = 0; k < 30; k++) {
      sum += meanRain((s - k + 366) % 366);
    }
    return sum;
  }

  /// Centre of the NASA grid cell that answers for this point, as text ("lat, lon").
  String get cellText {
    final g = gridCell(lat, lon);
    return '${g.lat.toStringAsFixed(3)}, ${g.lon.toStringAsFixed(3)}';
  }

  /// First/last date covered and share of missing days (rain), for the provenance card.
  String get coverageText =>
      '${seasons.first.startYear}-10-01 → ${seasons.last.startYear + 1}-09-30';
  double get missingShare {
    final total = seasons.fold<int>(0, (a, s) => a + s.days);
    final miss = seasons.fold<int>(0, (a, s) => a + s.missingRainDays);
    return total == 0 ? 0 : miss / total;
  }
}

class PowerData {
  PowerData(this.points);
  final Map<String, TownClimate> points;

  factory PowerData.fromJson(Map<String, dynamic> j) => PowerData({
    for (final e in (j['points'] as Map<String, dynamic>).entries)
      e.key: TownClimate.fromJson(e.key, e.value as Map<String, dynamic>),
  });

  TownClimate town(String id) => points[id] ?? points.values.first;
}
