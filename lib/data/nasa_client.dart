import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import 'nasa_power_repository.dart';
import 'places.dart';

const _params =
    'PRECTOTCORR,T2M,T2M_MAX,T2M_MIN,RH2M,WS2M,PS,ALLSKY_SFC_SW_DWN';
const _clim = ['T2M', 'T2M_MAX', 'T2M_MIN', 'RH2M', 'WS2M', 'PS'];
const _seasonVars = {
  'rain': 'PRECTOTCORR',
  'tmax': 'T2M_MAX',
  'tmin': 'T2M_MIN',
  'rh': 'RH2M',
  'ws': 'WS2M',
  'rad': 'ALLSKY_SFC_SW_DWN',
};

/// NASA POWER daily point API, community AG. Coordinates are rounded to 2 decimals (about 1 km) BEFORE sending.
/// No coordinates are ever logged.
class NasaClient {
  NasaClient(this._dio);
  final Dio _dio;

  /// Returns the raw POWER response. Retries with backoff (rate-limit friendly). Cancellable.
  Future<Map<String, dynamic>> fetchRaw(
    double lat,
    double lon, {
    void Function(double progress)? onProgress,
    CancelToken? cancel,
  }) async {
    final url =
        'https://power.larc.nasa.gov/api/temporal/daily/point'
        '?parameters=$_params&community=AG&longitude=${round2(lon)}&latitude=${round2(lat)}'
        '&start=${firstSeasonYear}0101&end=20241231&format=JSON';
    Object? last;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final r = await _dio.get<String>(
          url,
          cancelToken: cancel,
          options: Options(
            responseType: ResponseType.plain,
            receiveTimeout: const Duration(minutes: 3),
            headers: {'User-Agent': userAgent},
          ),
          onReceiveProgress: (got, total) {
            if (total > 0) onProgress?.call(got / total);
          },
        );
        // Parsing ~10 MB of JSON happens off the UI thread.
        return await compute(_decode, r.data!);
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) rethrow;
        last = e;
        await Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)));
      }
    }
    throw last ?? StateError('NASA POWER request failed');
  }
}

Map<String, dynamic> _decode(String s) => jsonDecode(s) as Map<String, dynamic>;

int _slot(DateTime d) => TownClimate.slot(d);

/// Build the same structure as the bundled file from a raw POWER response (port of scripts/fetch_nasa_power.py).
/// NASA fill value -999 is missing. Runs in an isolate via [buildFromRaw].
Map<String, dynamic> buildPointJson(
  Map<String, dynamic> js,
  double lat,
  double lon,
  String today,
) {
  final par = (js['properties'] as Map)['parameter'] as Map<String, dynamic>;
  final coords = ((js['geometry'] as Map)['coordinates'] as List).cast<num>();
  double? val(String k, String key) {
    final v = (par[k] as Map)[key];
    if (v == null) return null;
    final d = (v as num).toDouble();
    return d <= -990 ? null : d;
  }

  const y0 = firstSeasonYear, y1 = 2024;
  final rain = {for (var y = y0; y <= y1; y++) '$y': List<int>.filled(366, -1)};
  final sums = {for (final k in _clim) k: List<double>.filled(366, 0)};
  final cnt = {for (final k in _clim) k: List<int>.filled(366, 0)};
  final missing = {for (final k in _params.split(',')) k: 0};
  var d = DateTime.utc(y0, 1, 1);
  final end = DateTime.utc(y1, 12, 31);
  while (!d.isAfter(end)) {
    final key =
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    final i = _slot(d);
    for (final k in missing.keys) {
      if (val(k, key) == null) missing[k] = missing[k]! + 1;
    }
    final r = val('PRECTOTCORR', key);
    if (r != null) rain['${d.year}']![i] = (r * 10).round();
    for (final k in _clim) {
      final v = val(k, key);
      if (v != null) {
        sums[k]![i] += v;
        cnt[k]![i]++;
      }
    }
    d = d.add(const Duration(days: 1));
  }
  final clim = {
    for (final k in _clim)
      k: [
        for (var i = 0; i < 366; i++)
          cnt[k]![i] == 0 ? null : (sums[k]![i] / cnt[k]![i] * 10).round() / 10,
      ],
  };
  final seasons = {for (final n in _seasonVars.keys) n: <List<int>>[]};
  for (var y = y0; y < y1; y++) {
    final cols = {for (final n in _seasonVars.keys) n: <int>[]};
    var day = DateTime.utc(y, 10, 1);
    final last = DateTime.utc(y + 1, 9, 30);
    while (!day.isAfter(last)) {
      final key =
          '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
      _seasonVars.forEach((n, k) {
        final v = val(k, key);
        cols[n]!.add(v == null ? -999 : (v * 10).round());
      });
      day = day.add(const Duration(days: 1));
    }
    cols.forEach((n, l) => seasons[n]!.add(l));
  }
  return {
    'lat': round2(lat),
    'lon': round2(lon),
    'srcLon': coords[0],
    'srcLat': coords[1],
    'elev': coords.length > 2 ? coords[2] : 0,
    'coverage': missing,
    'rain': rain,
    'clim': clim,
    'seasons': seasons,
    'fetched': today,
  };
}

Map<String, dynamic> _buildArgs(List<Object> a) => buildPointJson(
  a[0] as Map<String, dynamic>,
  a[1] as double,
  a[2] as double,
  a[3] as String,
);

Future<Map<String, dynamic>> buildFromRaw(
  Map<String, dynamic> raw,
  double lat,
  double lon,
  String today,
) => compute(_buildArgs, <Object>[raw, lat, lon, today]);

/// Disk cache of downloaded datasets, keyed by rounded coordinates.
class DatasetCache {
  DatasetCache([this._dirOverride]);
  final Directory? _dirOverride;

  Future<File> _file(double lat, double lon) async {
    final base =
        _dirOverride ??
        Directory('${(await getApplicationSupportDirectory()).path}/nasa');
    if (!await base.exists()) await base.create(recursive: true);
    return File('${base.path}/v2_${cacheKey(lat, lon)}.json');
  }

  Future<TownClimate?> read(double lat, double lon) async {
    try {
      final f = await _file(lat, lon);
      if (!await f.exists()) return null;
      return TownClimate.fromJson(
        'cache_${cacheKey(lat, lon)}',
        jsonDecode(await f.readAsString()) as Map<String, dynamic>,
      );
    } on Object {
      return null; // a corrupt file is treated as a miss
    }
  }

  Future<void> write(
    double lat,
    double lon,
    Map<String, dynamic> pointJson,
  ) async {
    final f = await _file(lat, lon);
    await f.writeAsString(jsonEncode(pointJson));
  }
}
