import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../domain/scenarios.dart';
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

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SamaTopBar(
          title: t('why_title'),
          onBack: () =>
              context.canPop() ? context.pop() : context.go('/results'),
        ),
        ModelBody(
          builder: (m) {
            final eligible = m.catalog.eligible;
            var id = _crop ?? widget.cropId ?? m.rankedEligible.first.id;
            if (!eligible.any((c) => c.id == id)) {
              id = m.rankedEligible.first.id;
            }
            final crop = m.catalog.byId(id);
            final spec = crop.model!;
            final ry = m.matrix.ryList(id);
            final dryCount = ry.where((v) => v < m.threshold).length;
            final cell = m.climate.cellText;
            final mean = ry.reduce((a, b) => a + b) / ry.length;
            final outs = m.matrix.byCrop[id]!;
            double avg(double Function(dynamic) f) =>
                outs.map(f).reduce((a, b) => a + b) / outs.length;

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
                      for (final c in eligible)
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
                              maxY: 1,
                              minY: 0,
                              gridData: const FlGridData(
                                drawVerticalLine: false,
                              ),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(),
                                rightTitles: const AxisTitles(),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 38,
                                    interval: 0.25,
                                    getTitlesWidget: (v, _) => Text(
                                      '${(v * 100).round()}%',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 10,
                                    // One label every 10 seasons (the chart asks for every bar otherwise).
                                    getTitlesWidget: (v, _) =>
                                        v.toInt() % 10 != 0
                                        ? const SizedBox.shrink()
                                        : Text(
                                            '${1984 + v.toInt()}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              extraLinesData: ExtraLinesData(
                                horizontalLines: [
                                  HorizontalLine(
                                    y: m.threshold,
                                    color: SamaColors.ink,
                                    strokeWidth: 2,
                                    dashArray: [6, 4],
                                  ),
                                ],
                              ),
                              barGroups: [
                                for (var i = 0; i < ry.length; i++)
                                  BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: ry[i],
                                        width: 5,
                                        color: ry[i] >= m.threshold
                                            ? SamaColors.green
                                            : SamaColors.danger,
                                        // Hard seasons get an outline: not colour alone.
                                        borderSide: ry[i] >= m.threshold
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
                                  ' ${t('legend_thr')}: ${(m.threshold * 100).round()}%',
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
                          t('grid_note').replaceFirst('%s', cell),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '${t('coverage')}: ${m.climate.coverageText}',
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
                          'as_model',
                          'as_yield',
                          'as_future',
                          'as_irrig',
                          'as_bias',
                          'prov_params',
                        ])
                          _Bullet(t(k)),
                        const SizedBox(height: 12),
                        Text(
                          t('would_change'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (final k in [
                          'ch_soil_better',
                          'ch_irr',
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
                            'Kc ini / mid / end',
                            '${spec.kcIni} / ${spec.kcMid} / ${spec.kcEnd}',
                          ),
                          _Param(
                            'stages (ini/dev/mid/late)',
                            spec.stages.join(' / '),
                          ),
                          _Param('Zr max · p', '${spec.zrMax} m · ${spec.p}'),
                          _Param('Ky (FAO-33)', '${spec.ky}'),
                          _Param('verified', '${spec.verified}'),
                          _Param('TAW', '${m.assumptions.tawPerM} mm/m'),
                          _Param(
                            'soil depth · irrigation',
                            '${m.params.soilDepthM} m · ${m.params.irrigationMm.round()} mm',
                          ),
                          _Param(
                            'threshold',
                            '${(m.threshold * 100).round()}%',
                          ),
                          _Param(
                            'runs / seed',
                            '${ModelConstants.simulations} / ${ModelConstants.seed}',
                          ),
                          _Param(
                            '${t('et0')} (mean)',
                            '${avg((o) => o.et0Cycle as double).round()} mm',
                          ),
                          _Param(
                            '${t('etc')} (mean)',
                            '${avg((o) => o.etc as double).round()} mm',
                          ),
                          _Param(
                            '${t('eff_rain')} (mean)',
                            '${avg((o) => o.effectiveRain as double).round()} mm',
                          ),
                          _Param(
                            '${t('deficit')} (mean)',
                            '${avg((o) => o.deficit as double).round()} mm',
                          ),
                          _Param(
                            'mean relative yield',
                            '${(mean * 100).round()}%',
                          ),
                          _Param(
                            'worst · best',
                            '${seasonLabel(ry.indexOf(ry.reduce((a, b) => a < b ? a : b)))} · ${seasonLabel(ry.indexOf(ry.reduce((a, b) => a > b ? a : b)))}',
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
