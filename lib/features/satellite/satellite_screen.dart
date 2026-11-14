import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/colors.dart';
import '../../data/bundled_data_loader.dart';
import '../../data/places.dart';
import '../../domain/et0.dart';
import '../../state/farm_state.dart';
import '../../state/results_provider.dart';
import '../../state/settings.dart';
import '../../widgets/common.dart';
import 'gibs.dart';

class PlaceStats {
  PlaceStats(
    this.id,
    this.name,
    this.meanRain,
    this.meanEt0,
    this.meanTemp,
    this.cv,
    this.rains,
  );
  final String id;
  final String name;
  final double meanRain; // Oct-May, mm
  final double meanEt0; // Oct-Sep, mm
  final double meanTemp; // deg C, mean of (Tmax+Tmin)/2
  final double cv; // coefficient of variation of season rain
  final List<double> rains;

  /// Transparent water-stress indicator computed by SAMA from NASA data: rain minus ET0 (mm).
  double get balance => meanRain - meanEt0;
}

/// Computed from the bundled NASA data for every reference place and for the farm. No ML.
final placeStatsProvider = FutureProvider<List<PlaceStats>>((ref) async {
  final data = await ref.watch(appDataProvider.future);
  final farm = ref.watch(farmProvider);
  final res = await ref.watch(climateProvider.future);
  final lang = ref.read(langProvider).code;
  final job = <(String, String, dynamic)>[
    for (final p in places)
      if (data.power.points.containsKey(p.id))
        (p.id, p.name(lang), data.power.town(p.id)),
    ('farm', farm.name, res.climate),
  ];
  return ref.read(heavyRunnerProvider)(() {
    final out = <PlaceStats>[];
    for (final (id, name, c) in job) {
      final seasons = (c as dynamic).seasons as List;
      final rains = <double>[];
      var et0Sum = 0.0, tSum = 0.0, tN = 0;
      for (final s in seasons) {
        rains.add(s.rainySeasonRain as double);
        final e = et0Season(
          s,
          lat: c.srcLat as double,
          elev: c.elev as double,
        ).values;
        et0Sum += e.fold(0.0, (a, b) => a + b);
        for (var i = 0; i < s.days; i++) {
          final tx = s.tmax[i] as double?, tn = s.tmin[i] as double?;
          if (tx != null && tn != null) {
            tSum += (tx + tn) / 2;
            tN++;
          }
        }
      }
      final mean = rains.reduce((a, b) => a + b) / rains.length;
      final sd = sqrt(
        rains.fold(0.0, (a, b) => a + (b - mean) * (b - mean)) / rains.length,
      );
      out.add(
        PlaceStats(
          id,
          name,
          mean,
          et0Sum / seasons.length,
          tN == 0 ? 0 : tSum / tN,
          mean == 0 ? 0 : sd / mean,
          rains,
        ),
      );
    }
    return out;
  });
});

class SatelliteScreen extends ConsumerStatefulWidget {
  const SatelliteScreen({super.key});

  @override
  ConsumerState<SatelliteScreen> createState() => _SatelliteState();
}

class _SatelliteState extends ConsumerState<SatelliteScreen> {
  int _overlay = -1; // index into the overlays that loaded, -1 = none
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    final lang = ref.watch(langProvider);
    final farm = ref.watch(farmProvider);
    final layers = ref.watch(gibsProvider);
    final stats = ref.watch(placeStatsProvider);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SamaTopBar(
          title: t('sat_title'),
          onBack: () =>
              context.canPop() ? context.pop() : context.go('/explore'),
        ),
        layers.when(
          loading: () => const Skeleton(height: 260),
          error: (_, _) => _offline(t),
          data: (ls) {
            if (ls.isEmpty) return _offline(t);
            final overlays = ls.skip(1).toList();
            final over = _overlay >= 0 && _overlay < overlays.length
                ? overlays[_overlay]
                : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      height: 300,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: const LatLng(33.8, -5.4),
                          initialZoom: 7,
                          minZoom: 3,
                          maxZoom: 9,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: ls.first.url,
                            maxNativeZoom: ls.first.layer.maxZoom,
                            userAgentPackageName: 'ma.sama.sama',
                          ),
                          if (over != null)
                            Opacity(
                              opacity: over.layer.opacity,
                              child: TileLayer(
                                urlTemplate: over.url,
                                maxNativeZoom: over.layer.maxZoom,
                                userAgentPackageName: 'ma.sama.sama',
                              ),
                            ),
                          MarkerLayer(
                            markers: [
                              for (final p in places)
                                Marker(
                                  point: LatLng(p.lat, p.lon),
                                  width: 34,
                                  height: 34,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _selected = p.id),
                                    child: Tooltip(
                                      message: p.name(lang.code),
                                      child: const Icon(
                                        Icons.location_on,
                                        color: SamaColors.danger,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                                ),
                              Marker(
                                point: LatLng(farm.lat, farm.lon),
                                width: 38,
                                height: 38,
                                child: const Icon(
                                  Icons.home_work,
                                  color: SamaColors.green,
                                  size: 32,
                                ),
                              ),
                            ],
                          ),
                          const RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution('NASA GIBS / EOSDIS'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('sat_layers'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(t('sat_true')),
                            selected: _overlay < 0,
                            onSelected: (_) => setState(() => _overlay = -1),
                          ),
                          for (var i = 0; i < overlays.length; i++)
                            ChoiceChip(
                              label: Text(t(overlays[i].layer.titleKey)),
                              selected: _overlay == i,
                              onSelected: (_) => setState(() => _overlay = i),
                            ),
                        ],
                      ),
                      // Name, acquisition date and resolution of what is on screen.
                      for (final l in [ls.first, ?over])
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${t(l.layer.titleKey)} · ${t('sat_date')}: ${l.date.toIso8601String().substring(0, 10)} · ${t('sat_res')}: ${l.layer.resolution}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        t('sat_modis'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: SamaColors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          child: Text(
            t('sat_compare'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            t('sat_stress_note'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        AsyncBody(
          value: stats,
          onRetry: () => ref.invalidate(placeStatsProvider),
          builder: (list) {
            final sorted = [...list]
              ..sort((a, b) => b.balance.compareTo(a.balance));
            final sel = list.where((s) => s.id == _selected).firstOrNull;
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Column(
                children: [
                  SamaCard(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        for (final s in sorted)
                          ListTile(
                            dense: true,
                            minTileHeight: 56,
                            selected: s.id == _selected,
                            onTap: () => setState(() => _selected = s.id),
                            leading: s.id == 'farm'
                                ? const Icon(
                                    Icons.home_work,
                                    color: SamaColors.green,
                                  )
                                : const Icon(Icons.place_outlined),
                            title: Text(
                              s.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${t('sat_mean_rain')}: ${s.meanRain.round()} · ${t('sat_mean_et0')}: ${s.meanEt0.round()} · ${s.meanTemp.toStringAsFixed(1)}°C',
                            ),
                            // No good/bad icon: there is no sourced threshold. Less negative = more water relative to demand.
                            trailing: Text(
                              '${s.balance.round()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${t('sat_balance')} ↓',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (sel != null) _RainBars(stats: sel, t: t),
                ],
              ),
            );
          },
        ),
        const SourceNote(),
      ],
    );
  }

  Widget _offline(String Function(String) t) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: SamaCard(child: StatusLine(Status.info, t('sat_offline'))),
  );
}

class _RainBars extends StatelessWidget {
  const _RainBars({required this.stats, required this.t});
  final PlaceStats stats;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    final maxY = (stats.rains.reduce(max) * 1.1).ceilToDouble();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SamaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${stats.name} · ${t('sat_mean_rain')}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (stats.cv > 0.25)
              Text(
                t('sat_varies'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  gridData: const FlGridData(drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    topTitles: AxisTitles(),
                    rightTitles: AxisTitles(),
                    bottomTitles: AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < stats.rains.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: stats.rains[i],
                            width: 4,
                            color: SamaColors.water,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
