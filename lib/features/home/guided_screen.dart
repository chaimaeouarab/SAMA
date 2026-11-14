import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../data/crops_catalog.dart';
import '../../state/results_provider.dart';
import '../../state/settings.dart';
import '../../voice/phrase_builder.dart';
import '../../widgets/common.dart';
import '../../widgets/crop_art.dart';
import '../../widgets/speaker.dart';

/// The guided views behind the four home tiles: crop, water, timing, risk. All numbers come from the model.
class GuidedScreen extends ConsumerWidget {
  const GuidedScreen({super.key, required this.topic});
  final String topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SamaTopBar(
          title: t('g_$topic'),
          onBack: () => context.go('/home'),
          trailing: SpeakerButton(PhraseBuilder.answer(topic), size: 40),
        ),
        ModelBody(
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
    final t = trOf(ref);
    return Column(
      children: [
        for (final c in m.rankedEligible.take(10))
          _Row(
            crop: c,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(m.chance(c.id)! * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    ChanceStatus(m.chance(c.id)),
                  ],
                ),
                SpeakerButton(
                  PhraseBuilder.advice(c.id, (m.chance(c.id)! * 10).round()),
                  size: 40,
                ),
              ],
            ),
            child: Text(
              c.name(lang.code),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        for (final c in m.catalog.annuals.where((c) => !c.eligible))
          _Row(
            crop: c,
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
                StatusLine(Status.info, t('st_info')),
              ],
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
    final list = m.rankedEligible;
    double mean(String id, double Function(dynamic) f) {
      final o = m.matrix.byCrop[id]!;
      return o.map(f).reduce((a, b) => a + b) / o.length;
    }

    final scale = list
        .map((c) => mean(c.id, (o) => o.etc as double))
        .reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final c in list)
          _Row(
            crop: c,
            child: Builder(
              builder: (_) {
                final etc = mean(c.id, (o) => o.etc as double);
                final have = mean(
                  c.id,
                  (o) => (o.effectiveRain as double) + (o.irrigation as double),
                );
                final deficit = mean(c.id, (o) => o.deficit as double);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name(lang.code),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${t('water_need')}: ${etc.round()} ${t('mm')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: etc / scale,
                        minHeight: 10,
                        color: SamaColors.amber,
                        backgroundColor: SamaColors.line,
                      ),
                    ),
                    Text(
                      '${t('water_have')}: ${have.round()} ${t('mm')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: have / scale,
                        minHeight: 10,
                        color: SamaColors.water,
                        backgroundColor: SamaColors.line,
                      ),
                    ),
                    StatusLine(
                      deficit < 30 ? Status.good : Status.warn,
                      '${t('deficit')}: ${deficit.round()} ${t('mm')}',
                    ),
                  ],
                );
              },
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
    final lang = ref.watch(langProvider);
    final monthly = m.climate.monthlyRain;
    const seasonMonths = {9, 10, 11, 0, 1, 2, 3, 4};
    final maxY = monthly.reduce((a, b) => a > b ? a : b) * 1.2;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          child: SamaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 200,
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
                Text(
                  'mm / ${t('observed')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(t('g_timing_note'), style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
        for (final c in m.rankedEligible.take(6))
          _Row(
            crop: c,
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
                Text(
                  '${t('sow')}: ${c.model!.sowDay}/${c.model!.sowMonth} · ${c.model!.cycleDays}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
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
    final hard = {
      for (final c in m.catalog.eligible)
        c.id: m.matrix.ryList(c.id).where((v) => v < m.threshold).length,
    };
    final list = m.catalog.eligible
      ..sort((a, b) => hard[b.id]!.compareTo(hard[a.id]!));
    return Column(
      children: [
        for (final c in list)
          _Row(
            crop: c,
            trailing: StatusLine(
              hard[c.id]! <= 8 ? Status.good : Status.warn,
              '${hard[c.id]} ${t('dry_n')}',
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
