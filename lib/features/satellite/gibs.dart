import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';

/// NASA GIBS WMTS (EPSG:3857, "best"), no key. Identifiers, tile matrix sets, formats and date
/// ranges below were read from
/// https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/1.0.0/WMTSCapabilities.xml (2026-11-14), not assumed.
/// Native resolution texts are SAMA's reading of the product pages and are flagged in docs/SOURCES.md.
class GibsLayer {
  const GibsLayer({
    required this.id,
    required this.titleKey,
    required this.tileMatrixSet,
    required this.maxZoom,
    required this.ext,
    required this.resolution,
    required this.lagDays,
    this.monthly = false,
    this.opacity = 1.0,
  });

  final String id;
  final String titleKey;
  final String tileMatrixSet;
  final int maxZoom;
  final String ext;
  final String resolution;

  /// The newest dates are not published yet: try today minus this many days, then step back.
  final int lagDays;
  final bool monthly;
  final double opacity;

  String urlFor(DateTime date) =>
      'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/$id/default/${_fmt(date)}/$tileMatrixSet/{z}/{y}/{x}.$ext';

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${monthly ? '01' : d.day.toString().padLeft(2, '0')}';

  /// Candidate dates, newest first.
  List<DateTime> candidates(DateTime now) {
    if (monthly) {
      return [
        for (var k = 2; k <= 6; k++) DateTime(now.year, now.month - k, 1),
      ];
    }
    final start = now.subtract(Duration(days: lagDays));
    return [for (var k = 0; k < 6; k++) start.subtract(Duration(days: k))];
  }
}

const gibsBase = GibsLayer(
  id: 'MODIS_Terra_CorrectedReflectance_TrueColor',
  titleKey: 'sat_true',
  tileMatrixSet: 'GoogleMapsCompatible_Level9',
  maxZoom: 9,
  ext: 'jpeg',
  resolution: '≈ 250 m',
  lagDays: 2,
);

const gibsOverlays = <GibsLayer>[
  GibsLayer(
    id: 'MODIS_Terra_L3_NDVI_Monthly',
    titleKey: 'sat_ndvi',
    tileMatrixSet: 'GoogleMapsCompatible_Level7',
    maxZoom: 7,
    ext: 'png',
    resolution: '≈ 5 km (0.05°)',
    lagDays: 0,
    monthly: true,
    opacity: 0.8,
  ),
  GibsLayer(
    id: 'IMERG_Precipitation_Rate',
    titleKey: 'sat_imerg',
    tileMatrixSet: 'GoogleMapsCompatible_Level6',
    maxZoom: 6,
    ext: 'png',
    resolution: '≈ 10 km (0.1°)',
    lagDays: 4,
    opacity: 0.7,
  ),
  GibsLayer(
    id: 'SMAP_L4_Analyzed_Surface_Soil_Moisture',
    titleKey: 'sat_smap',
    tileMatrixSet: 'GoogleMapsCompatible_Level6',
    maxZoom: 6,
    ext: 'png',
    resolution: '≈ 9 km',
    lagDays: 7,
    opacity: 0.7,
  ),
];

/// A layer that really loaded, with the date of its image.
class AvailableLayer {
  const AvailableLayer(this.layer, this.date);
  final GibsLayer layer;
  final DateTime date;
  String get url => layer.urlFor(date);
}

/// Request one real tile over Morocco (z5, x15, y12). Only layers that answer are offered.
Future<AvailableLayer?> probeLayer(Dio dio, GibsLayer l, DateTime now) async {
  for (final d in l.candidates(now)) {
    final url = l
        .urlFor(d)
        .replaceFirst('{z}', '5')
        .replaceFirst('{y}', '12')
        .replaceFirst('{x}', '15');
    try {
      final r = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
          validateStatus: (s) => s != null && s < 500,
          headers: {'User-Agent': userAgent},
        ),
      );
      if (r.statusCode == 200 && (r.data?.isNotEmpty ?? false)) {
        return AvailableLayer(l, d);
      }
    } on Object {
      return null; // offline or blocked: stop early
    }
  }
  return null;
}

final gibsProvider = FutureProvider<List<AvailableLayer>>((ref) async {
  final dio = Dio();
  final now = DateTime.now().toUtc();
  final out = <AvailableLayer>[];
  final base = await probeLayer(dio, gibsBase, now);
  if (base == null) return const [];
  out.add(base);
  for (final l in gibsOverlays) {
    final a = await probeLayer(dio, l, now);
    if (a != null) out.add(a);
  }
  return out;
});
