import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../data/climate_repository.dart';
import '../../state/farm_state.dart';
import '../../state/settings.dart';
import '../../widgets/common.dart';
import '../../widgets/crop_art.dart';
import '../../widgets/logo_bar.dart';
import '../../widgets/motion.dart';

/// The Advisor's home: dense, numeric and comparative (the Farmer's home is big, visual and voice-first).
class AdvisorDashboard extends ConsumerWidget {
  const AdvisorDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final lang = ref.watch(langProvider);
    final fs = ref.watch(farmsProvider);
    final farm = fs.current;

    return ModelBody(
      builder: (m) {
        final c = m.climate;
        final rains = c.seasonRains;
        final meanRain = rains.reduce((a, b) => a + b) / rains.length;
        final res = m.resolution;
        final source = switch (res.kind) {
          ClimateKind.exactCache => t('data_cache'),
          ClimateKind.bundledExact => t('data_bundled'),
          ClimateKind.nearestReference => t('approx_title'),
        };
        final unknown = [
          if (!farm.soilKnown) t('soil'),
          if (!farm.irrigationKnown) t('irrigation'),
          if (!farm.previousKnown) t('prev_crop'),
        ];
        final top = m.rankedEligible.take(6).toList();
        double meanOf(String id, double Function(dynamic) f) {
          final o = m.matrix.byCrop[id]!;
          return o.map(f).reduce((a, b) => a + b) / o.length;
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            // Header card with the farm selector
            FadeSlideIn(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [advisorColor, Color(0xFF123F5C)],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x331D5F8A),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.dashboard_customize_outlined,
                          color: Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          t('dash_title'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: fs.currentId,
                          isExpanded: true,
                          dropdownColor: advisorColor,
                          iconEnabledColor: Colors.white,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          items: [
                            for (final f in fs.farms)
                              DropdownMenuItem(
                                value: f.id,
                                child: Text(
                                  f.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (id) => id == null
                              ? null
                              : ref.read(farmsProvider.notifier).select(id),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${farm.lat.toStringAsFixed(3)}, ${farm.lon.toStringAsFixed(3)} · ${t('grid_note').replaceFirst('%s', c.cellText)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // KPI tiles
            FadeSlideIn(
              index: 1,
              child: Row(
                children: [
                  _Kpi(
                    icon: Icons.agriculture_outlined,
                    value: '${fs.farms.length}',
                    label: t('dash_farms'),
                  ),
                  const SizedBox(width: 10),
                  _Kpi(
                    icon: Icons.water_drop_outlined,
                    value: '${meanRain.round()} mm',
                    label: t('sat_mean_rain'),
                  ),
                  const SizedBox(width: 10),
                  _Kpi(
                    icon: res.approximate
                        ? Icons.near_me
                        : Icons.verified_outlined,
                    value: '${(c.missingShare * 100).toStringAsFixed(1)}%',
                    label: '${t('missing_days')} · $source',
                    small: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Alerts
            FadeSlideIn(
              index: 2,
              child: _Card(
                title: t('dash_alerts'),
                icon: Icons.notifications_active_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (res.approximate)
                      _Alert(
                        Status.warn,
                        '${t('approx_title')}: ${res.referenceName} · ${res.distanceKm.round()} ${t('km')}',
                        action: farm.approxConfirmed
                            ? null
                            : (
                                t('confirm'),
                                () => ref
                                    .read(farmsProvider.notifier)
                                    .update(
                                      (f) => f.copyWith(approxConfirmed: true),
                                    ),
                              ),
                      ),
                    if (unknown.isNotEmpty)
                      _Alert(
                        Status.info,
                        '${t('dash_unknown')} (${unknown.join(', ')})',
                        action: (t('dt_title'), () => context.go('/detective')),
                      ),
                    _Alert(Status.warn, t('prov_params')),
                    if (!res.approximate && unknown.isEmpty)
                      _Alert(Status.good, t('dash_all_ok')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Rain over the 40 seasons
            FadeSlideIn(
              index: 3,
              child: _Card(
                title: t('dash_rain'),
                icon: Icons.bar_chart,
                child: SizedBox(
                  height: 120,
                  child: BarChart(
                    BarChartData(
                      gridData: const FlGridData(drawVerticalLine: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            interval: 250,
                            getTitlesWidget: (v, _) => Text(
                              '${v.round()}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) => v.toInt() % 10 != 0
                                ? const SizedBox.shrink()
                                : Text(
                                    '${1984 + v.toInt()}',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                          ),
                        ),
                      ),
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: meanRain,
                            color: advisorColor,
                            strokeWidth: 1.5,
                            dashArray: [5, 4],
                          ),
                        ],
                      ),
                      barGroups: [
                        for (var i = 0; i < rains.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: rains[i],
                                width: 4,
                                color: rains[i] < meanRain
                                    ? SamaColors.amber
                                    : advisorColor,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Top crops, as numbers
            FadeSlideIn(
              index: 4,
              child: _Card(
                title: t('dash_top'),
                icon: Icons.table_chart_outlined,
                child: Column(
                  children: [
                    for (var i = 0; i < top.length; i++)
                      InkWell(
                        onTap: () => context.go('/time?crop=${top[i].id}'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: SamaColors.muted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: CropImage(top[i]),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  top[i].name(lang.code),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _Num(
                                '${(m.chance(top[i].id)! * 100).round()}%',
                                t('chance').split(' ').first,
                              ),
                              _Num(
                                '${(meanOf(top[i].id, (o) => (o.ry ?? 0) as double) * 100).round()}%',
                                t('dash_mean_ry').split(' ').first,
                              ),
                              _Num(
                                '${meanOf(top[i].id, (o) => o.deficit as double).round()}',
                                t('deficit').split(' ').last,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Tools
            FadeSlideIn(
              index: 5,
              child: _Card(
                title: t('dash_actions'),
                icon: Icons.construction_outlined,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in [
                      (Icons.analytics_outlined, 'nav_analysis', '/analysis'),
                      (Icons.agriculture_outlined, 'nav_farms', '/farms'),
                      (Icons.tune, 'adv_assumptions', '/assumptions'),
                      (Icons.search, 'dt_title', '/detective'),
                      (Icons.water_drop_outlined, 'sl_title', '/shock'),
                      (Icons.timeline, 'tm_title', '/time'),
                      (Icons.satellite_alt, 'sat_title', '/satellite'),
                      (Icons.bar_chart, 'nav_results', '/results'),
                    ])
                      ActionChip(
                        avatar: Icon(a.$1, size: 18, color: advisorColor),
                        label: Text(t(a.$2)),
                        onPressed: () => context.go(a.$3),
                        backgroundColor: advisorColor.withValues(alpha: 0.08),
                        side: BorderSide.none,
                      ),
                  ],
                ),
              ),
            ),
            const SourceNote(),
          ],
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.icon,
    required this.value,
    required this.label,
    this.small = false,
  });
  final IconData icon;
  final String value;
  final String label;
  final bool small;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: samaCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: advisorColor, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: small ? 18 : 20,
              fontWeight: FontWeight.w800,
              color: SamaColors.ink,
            ),
          ),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: SamaColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: samaCardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: advisorColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _Alert extends StatelessWidget {
  const _Alert(this.status, this.text, {this.action});
  final Status status;
  final String text;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: StatusLine(status, text)),
        if (action != null)
          TextButton(onPressed: action!.$2, child: Text(action!.$1)),
      ],
    ),
  );
}

class _Num extends StatelessWidget {
  const _Num(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 52,
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9.5, color: SamaColors.muted),
        ),
      ],
    ),
  );
}
