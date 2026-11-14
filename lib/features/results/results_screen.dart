import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../domain/scenarios.dart';
import '../../state/farm_state.dart';
import '../../state/settings.dart';
import '../../widgets/common.dart';
import '../../widgets/crop_art.dart';

/// Reference crop for the good/hard marks of the past seasons.
class ResultsCrop extends Notifier<String> {
  @override
  String build() => 'softwheat';
  void set(String id) => state = id;
}

final resultsCropProvider = NotifierProvider<ResultsCrop, String>(
  ResultsCrop.new,
);

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final lang = ref.watch(langProvider);
    final farm = ref.watch(farmProvider);
    final cropId = ref.watch(resultsCropProvider);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SamaTopBar(title: t('season_rain')),
        ModelBody(
          builder: (m) {
            final eligible = m.catalog.eligible;
            final id = eligible.any((c) => c.id == cropId)
                ? cropId
                : m.rankedEligible.first.id;
            final ry = m.matrix.ryList(id);
            final rains = m.climate.seasonRains;
            final toDate = m.climate.typicalSeasonToDate(DateTime.now());
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: SamaColors.green,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('so_far'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${toDate.round()} mm',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${farm.name} · NASA POWER ${t('observed')}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.water_drop,
                        color: Colors.white,
                        size: 44,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  child: SamaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('past'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        DropdownButton<String>(
                          value: id,
                          isExpanded: true,
                          items: [
                            for (final c in eligible)
                              DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name(lang.code)),
                              ),
                          ],
                          onChanged: (v) =>
                              ref.read(resultsCropProvider.notifier).set(v!),
                        ),
                        for (var i = ry.length - 1; i >= 0; i--)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: SamaColors.line),
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: SvgPicture.string(
                                      wheatArtSvg(
                                        ry[i] >= m.threshold
                                            ? '#E8B84A'
                                            : '#C9A56B',
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${seasonLabel(i)} · ${rains[i].round()} mm · ${(ry[i] * 100).round()}%',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      StatusLine(
                                        ry[i] >= m.threshold
                                            ? Status.good
                                            : Status.warn,
                                        t(
                                          ry[i] >= m.threshold ? 'good' : 'dry',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => context.go('/why?crop=$id'),
                          icon: const Icon(Icons.help_outline),
                          label: Text(t('why')),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () => context.go('/time?crop=$id'),
                          icon: const Icon(Icons.timeline),
                          label: Text(t('tm_title')),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () => context.go('/aquifer'),
                          icon: const Icon(Icons.water),
                          label: Text(t('aquifer')),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SourceNote(),
      ],
    );
  }
}
