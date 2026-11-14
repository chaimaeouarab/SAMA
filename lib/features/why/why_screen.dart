import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../data/towns.dart';
import '../../domain/season_classifier.dart';
import '../../domain/water_balance.dart';
import '../../state/farm_state.dart';
import '../../state/results_provider.dart';
import '../../state/settings.dart';
import '../../widgets/common.dart';

/// "Why this advice?": the 40 real seasons, source, assumptions, what would change it.
class WhyScreen extends ConsumerStatefulWidget {
  const WhyScreen({super.key, this.cropId});
  final String? cropId;

  @override
  ConsumerState<WhyScreen> createState() => _WhyScreenState();
}

class _WhyScreenState extends ConsumerState<WhyScreen> {
  String? _crop;

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    final lang = ref.watch(langProvider);
    final advisor = ref.watch(settingsProvider.select((s) => s.advisor));
    final model = ref.watch(fieldModelProvider);
    final farm = ref.watch(farmProvider);
    final town = townById(farm.townId);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SamaTopBar(
          title: t('why_title'),
          onBack: () =>
              context.canPop() ? context.pop() : context.go('/results'),
        ),
        AsyncBody(
          value: model,
          onRetry: () => ref.invalidate(fieldModelProvider),
          builder: (m) {
            final id = _crop ?? widget.cropId ?? m.rankedAnnuals.first.id;
            final crop = m.catalog.byId(id);
            final rains = m.ctx.rains;
            final good = classifySeasons(
              rains,
              crop.waterNeed!,
              m.ctx.soil,
              previousLegume: m.ctx.previousLegume,
            );
            final need = waterNeeded(
              crop.waterNeed!,
              previousLegume: m.ctx.previousLegume,
            );
            // Rain at which available water equals the need.
            final rainNeeded = (need - 2400 * m.ctx.soil.factor) / (10 * 0.65);
            final dryCount = good.where((g) => !g).length;
            final maxY = (rains.reduce((a, b) => a > b ? a : b) * 1.1)
                .ceilToDouble();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButton<String>(
                    value: id,
                    isExpanded: true,
                    hint: Text(t('pick_crop')),
                    items: [
                      for (final c in m.catalog.annuals)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name(lang.code)),
                        ),
                    ],
                    onChanged: (v) => setState(() => _crop = v),
                  ),
                  SamaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('seasons_bars'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 220,
                          child: BarChart(
                            BarChartData(
                              maxY: maxY,
                              minY: 0,
                              gridData: const FlGridData(
                                drawVerticalLine: false,
                              ),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(),
                                rightTitles: const AxisTitles(),
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 38,
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 10,
                                    getTitlesWidget: (v, _) => Text(
                                      "'${(84 + v.toInt()) % 100}".padLeft(
                                        3,
                                        '0',
                                      ),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                              ),
                              extraLinesData: ExtraLinesData(
                                horizontalLines: [
                                  HorizontalLine(
                                    y: rainNeeded.clamp(0, maxY),
                                    color: SamaColors.ink,
                                    strokeWidth: 2,
                                    dashArray: [6, 4],
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
                                        width: 5,
                                        color: good[i]
                                            ? SamaColors.green
                                            : SamaColors.danger,
                                        // Dry bars get an outline: not colour alone.
                                        borderSide: good[i]
                                            ? BorderSide.none
                                            : const BorderSide(
                                                color: SamaColors.ink,
                                                width: 1,
                                              ),
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Legend with icons, not just colours.
                        Wrap(
                          spacing: 16,
                          runSpacing: 6,
                          children: [
                            StatusLine(Status.good, t('legend_good')),
                            StatusLine(Status.warn, t('legend_dry')),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.horizontal_rule, size: 18),
                                Text(
                                  ' ${t('legend_need')}: ${rainNeeded.round()} mm',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$dryCount ${t('dry_n')}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SamaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('source_line'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${town.name(lang.code)}: ${m.climate.lat.toStringAsFixed(2)}, ${m.climate.lon.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          t('based40'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t('assumptions'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (final k in [
                          'as_season',
                          'as_avail',
                          'as_need',
                          'as_fail',
                          'as_future',
                          'prov_needs',
                        ])
                          _Bullet(t(k)),
                        const SizedBox(height: 12),
                        Text(
                          t('would_change'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (final k in [
                          'ch_soil_better',
                          'ch_prev',
                          'ch_crop',
                          'ch_rain',
                        ])
                          _Bullet(t(k)),
                      ],
                    ),
                  ),
                  if (advisor) ...[
                    const SizedBox(height: 12),
                    SamaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('params'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          _Param(
                            'B_c',
                            '${crop.waterNeed!.round()} ${t('water_unit')}',
                          ),
                          _Param(
                            'W_need',
                            '${need.round()} ${t('water_unit')}',
                          ),
                          _Param(
                            'f_soil',
                            m.ctx.soil.factor.toStringAsFixed(2),
                          ),
                          _Param(
                            'Q',
                            '${ModelConstants.baselineQ.round()} ${t('water_unit')}',
                          ),
                          _Param(
                            'effective rain',
                            ModelConstants.effectiveRain.toString(),
                          ),
                          _Param(
                            'failure',
                            '${(ModelConstants.nonClimateFailure * 100).round()}%',
                          ),
                          _Param(
                            'runs / seed',
                            '${ModelConstants.simulations} / ${ModelConstants.seed}',
                          ),
                          _Param('rain needed', '${rainNeeded.round()} mm'),
                          _Param(
                            'mean rain',
                            '${(rains.reduce((a, b) => a + b) / rains.length).round()} mm',
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SourceNote(),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontSize: 16)),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
      ],
    ),
  );
}

class _Param extends StatelessWidget {
  const _Param(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(k, style: const TextStyle(color: SamaColors.muted)),
        ),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
