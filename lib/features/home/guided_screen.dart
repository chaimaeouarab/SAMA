import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../data/crops_catalog.dart';
import '../../domain/season_classifier.dart';
import '../../domain/water_balance.dart';
import '../../state/results_provider.dart';
import '../../state/settings.dart';
import '../../voice/phrase_builder.dart';
import '../../widgets/common.dart';
import '../../widgets/crop_art.dart';
import '../../widgets/speaker.dart';
import '../crop_detail/crop_detail_screen.dart';

/// The guided views behind the four home tiles: crop, water, timing, risk.
class GuidedScreen extends ConsumerWidget {
  const GuidedScreen({super.key, required this.topic});
  final String topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final model = ref.watch(fieldModelProvider);
    final title = t('g_$topic');
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SamaTopBar(
          title: title,
          onBack: () => context.go('/home'),
          trailing: SpeakerButton(['ans.$topic'], size: 40),
        ),
        AsyncBody(
          value: model,
          onRetry: () => ref.invalidate(fieldModelProvider),
          builder: (m) => switch (topic) {
            'water' => _Water(m: m),
            'timing' => _Timing(m: m),
            'risk' => _Risk(m: m),
            _ => _CropList(m: m),
          },
        ),
        const SourceNote(),
      ],
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.crop, required this.child, this.trailing});
  final Crop crop;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.go('/crop/${crop.id}'),
      child: SamaCard(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 56, height: 56, child: CropImage(crop)),
            ),
            const SizedBox(width: 12),
            Expanded(child: child),
            ?trailing,
          ],
        ),
      ),
    ),
  );
}

class _CropList extends ConsumerWidget {
  const _CropList({required this.m});
  final FieldModel m;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    return Column(
      children: [
        for (final c in m.rankedAnnuals.take(10))
          _Row(
            crop: c,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusLine(
                  statusOf(m.chances[c.id]!),
                  '${(m.chances[c.id]! * 100).round()}%',
                ),
                SpeakerButton(
                  PhraseBuilder.advice(c.id, (m.chances[c.id]! * 10).round()),
                  size: 40,
                ),
              ],
            ),
            child: Text(
              c.name(lang.code),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class _Water extends ConsumerWidget {
  const _Water({required this.m});
  final FieldModel m;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final lang = ref.watch(langProvider);
    final avail =
        m.ctx.rains
            .map((r) => waterAvailable(r, m.ctx.soil))
            .reduce((a, b) => a + b) /
        m.ctx.rains.length;
    final needs = {
      for (final c in m.catalog.annuals)
        c.id: waterNeeded(c.waterNeed!, previousLegume: m.ctx.previousLegume),
    };
    final scale = [avail, ...needs.values].reduce((a, b) => a > b ? a : b);
    final list = m.catalog.annuals
      ..sort((a, b) => needs[a.id]!.compareTo(needs[b.id]!));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          child: SamaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('water_have'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${avail.round()} ${t('water_unit')}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: SamaColors.water,
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: avail / scale,
                    minHeight: 12,
                    color: SamaColors.water,
                    backgroundColor: SamaColors.line,
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final c in list)
          _Row(
            crop: c,
            trailing: StatusLine(
              needs[c.id]! <= avail ? Status.good : Status.warn,
              needs[c.id]! <= avail ? '✓' : '!',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name(lang.code),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: needs[c.id]! / scale,
                    minHeight: 10,
                    color: SamaColors.amber,
                    backgroundColor: SamaColors.line,
                  ),
                ),
                Text(
                  '${needs[c.id]!.round()} ${t('water_unit')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
          child: Text(
            t('prov_needs'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _Timing extends ConsumerWidget {
  const _Timing({required this.m});
  final FieldModel m;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final monthly = m.climate.monthlyRain;
    // Season months Oct..May are drawn in green, the rest in grey (labelled in text below).
    const seasonMonths = {9, 10, 11, 0, 1, 2, 3, 4};
    final maxY = monthly.reduce((a, b) => a > b ? a : b) * 1.2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: SamaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  gridData: const FlGridData(drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) => Text(
                          '${v.toInt() + 1}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < 12; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: monthly[i],
                            width: 14,
                            color: seasonMonths.contains(i)
                                ? SamaColors.water
                                : SamaColors.line,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'mm / ${t('typical_now')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(t('g_timing_note'), style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _Risk extends ConsumerWidget {
  const _Risk({required this.m});
  final FieldModel m;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final lang = ref.watch(langProvider);
    final dry = {
      for (final c in m.catalog.annuals)
        c.id: classifySeasons(
          m.ctx.rains,
          c.waterNeed!,
          m.ctx.soil,
          previousLegume: m.ctx.previousLegume,
        ).where((g) => !g).length,
    };
    final list = m.catalog.annuals
      ..sort((a, b) => dry[b.id]!.compareTo(dry[a.id]!));
    return Column(
      children: [
        for (final c in list)
          _Row(
            crop: c,
            trailing: StatusLine(
              dry[c.id]! == 0
                  ? Status.good
                  : (dry[c.id]! <= 12 ? Status.warn : Status.bad),
              '${dry[c.id]} ${t('dry_n')}',
            ),
            child: Text(
              c.name(lang.code),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}
