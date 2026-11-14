import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../data/bundled_data_loader.dart';
import '../../data/climate_repository.dart';
import '../../domain/outcome_matrix.dart';
import '../../domain/scenarios.dart';
import '../../state/assumptions.dart';
import '../../state/farm_state.dart';
import '../../state/results_provider.dart';
import '../../state/settings.dart';
import '../../widgets/common.dart';

/// Advisor mode: several farms, with a side-by-side comparison.
class FarmsScreen extends ConsumerWidget {
  const FarmsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final fs = ref.watch(farmsProvider);
    final n = ref.read(farmsProvider.notifier);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SamaTopBar(title: t('nav_farms')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              for (final f in fs.farms)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SamaCard(
                    color: f.id == fs.currentId
                        ? SamaColors.greenTint
                        : Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              f.id == fs.currentId
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: SamaColors.green,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                f.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${f.lat.toStringAsFixed(3)}, ${f.lon.toStringAsFixed(3)} · ${f.soilKnown ? t('soil_${f.soil.name}') : '?'} · ${f.irrigationKnown ? t('irr_${f.irrigation.name}') : '?'} · ${f.areaHa} ha',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (f.id != fs.currentId)
                              TextButton(
                                onPressed: () => n.select(f.id),
                                child: Text(t('confirm')),
                              ),
                            TextButton(
                              onPressed: () async {
                                n.select(f.id);
                                final c = TextEditingController(text: f.name);
                                final name = await showDialog<String>(
                                  context: context,
                                  builder: (d) => AlertDialog(
                                    title: Text(t('adv_rename')),
                                    content: TextField(
                                      controller: c,
                                      autofocus: true,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(d),
                                        child: Text(t('cancel')),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(d, c.text.trim()),
                                        child: Text(t('save')),
                                      ),
                                    ],
                                  ),
                                );
                                if (name != null && name.isNotEmpty) {
                                  n.update((x) => x.copyWith(name: name));
                                }
                              },
                              child: Text(t('adv_rename')),
                            ),
                            TextButton(
                              onPressed: () {
                                n.select(f.id);
                                context.go('/farm/inputs');
                              },
                              child: Text(t('edit')),
                            ),
                            if (fs.farms.length > 1)
                              TextButton(
                                onPressed: () => n.remove(f.id),
                                child: Text(t('adv_delete')),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: () => context.go('/farm/location?new=1'),
                icon: const Icon(Icons.add),
                label: Text(t('adv_add')),
              ),
              const SizedBox(height: 16),
              if (fs.farms.length > 1) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    t('adv_compare'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const _FarmCompare(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class FarmCompareRow {
  FarmCompareRow(this.name, this.cropChances, this.approx, this.cell);
  final String name;
  final Map<String, double> cropChances;
  final bool approx;
  final String cell;
}

/// Every farm evaluated with its own dataset and inputs: chance of a good season for the top crops.
final farmCompareProvider = FutureProvider<List<FarmCompareRow>>((ref) async {
  final data = await ref.watch(appDataProvider.future);
  final fs = ref.watch(farmsProvider);
  final a = ref.watch(assumptionsProvider);
  final cache = ref.read(datasetCacheProvider);
  final out = <FarmCompareRow>[];
  for (final f in fs.farms) {
    final cached = await cache.read(f.lat, f.lon);
    final res = selectDataset(
      lat: f.lat,
      lon: f.lon,
      bundled: data.power,
      cached: cached,
    );
    final params = f.params(a);
    final catalog = data.catalog;
    final thr = a.goodThreshold;
    final chances = await ref.read(heavyRunnerProvider)(() {
      final m = OutcomeMatrix.build(
        crops: catalog.eligible,
        climate: res.climate,
        farm: params,
      );
      return {for (final c in catalog.eligible) c.id: m.chance(c.id, thr)!};
    });
    out.add(
      FarmCompareRow(f.name, chances, res.approximate, res.climate.cellText),
    );
  }
  return out;
});

class _FarmCompare extends ConsumerWidget {
  const _FarmCompare();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final lang = ref.watch(langProvider);
    final data = ref.watch(appDataProvider).value;
    return AsyncBody(
      value: ref.watch(farmCompareProvider),
      onRetry: () => ref.invalidate(farmCompareProvider),
      builder: (rows) {
        if (data == null) return const SizedBox.shrink();
        final ids = data.catalog.eligible.map((c) => c.id).toList()
          ..sort(
            (a, b) => rows
                .map((r) => r.cropChances[b]!)
                .reduce((x, y) => x + y)
                .compareTo(
                  rows.map((r) => r.cropChances[a]!).reduce((x, y) => x + y),
                ),
          );
        return SamaCard(
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(label: Text(t('nav_farm'))),
                for (final r in rows)
                  DataColumn(label: Text(r.name + (r.approx ? ' ≈' : ''))),
              ],
              rows: [
                for (final id in ids.take(8))
                  DataRow(
                    cells: [
                      DataCell(Text(data.catalog.byId(id).name(lang.code))),
                      for (final r in rows)
                        DataCell(
                          Text('${(r.cropChances[id]! * 100).round()}%'),
                        ),
                    ],
                  ),
                DataRow(
                  cells: [
                    DataCell(Text(t('grid_note').split('(').first.trim())),
                    for (final r in rows)
                      DataCell(
                        Text(r.cell, style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Advisor "Analysis": data provenance, season table and links to the deep tools.
class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final lang = ref.watch(langProvider);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SamaTopBar(title: t('nav_analysis')),
        ModelBody(
          builder: (m) {
            final c = m.climate;
            final res = m.resolution;
            final src = switch (res.kind) {
              ClimateKind.exactCache =>
                '${t('data_cache')} · ${t('data_from')} ${c.fetched ?? '?'}',
              ClimateKind.bundledExact => t('data_bundled'),
              ClimateKind.nearestReference =>
                '${t('approx_title')} (${res.referenceName}, ${res.distanceKm.round()} ${t('km')})',
            };
            final top = m.rankedEligible.take(5).toList();
            final rains = c.seasonRains;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SamaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('adv_provenance'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(src),
                        Text(
                          t('grid_note').replaceFirst(
                            '%s',
                            '${c.cellText} · ${c.elev.round()} m',
                          ),
                        ),
                        Text(
                          '${t('coverage')}: ${c.coverageText} · ${(c.missingShare * 100).toStringAsFixed(2)}% ${t('missing_days')}',
                        ),
                        Text(
                          '${t('adv_model_version')}: FAO-56 PM · FAO-33 · seed 42 × 1000 · v2',
                        ),
                        if (m.shock.isHypothetical)
                          StatusLine(Status.info, t('whatif')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final cr in top)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => context.go('/time?crop=${cr.id}'),
                        child: SamaCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cr.name(lang.code),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text('${(m.chance(cr.id)! * 100).round()}%'),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => context.go('/results'),
                        child: Text(t('nav_results')),
                      ),
                      OutlinedButton(
                        onPressed: () => context.go('/detective'),
                        child: Text(t('dt_title')),
                      ),
                      OutlinedButton(
                        onPressed: () => context.go('/shock'),
                        child: Text(t('sl_title')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SamaCard(
                    padding: const EdgeInsets.all(8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text(t('adv_seasons_table'))),
                          DataColumn(label: Text(t('rain'))),
                          for (final cr in top.take(3))
                            DataColumn(label: Text(cr.name(lang.code))),
                        ],
                        rows: [
                          for (var i = rains.length - 1; i >= 0; i--)
                            DataRow(
                              cells: [
                                DataCell(Text(seasonLabel(i))),
                                DataCell(Text('${rains[i].round()} mm')),
                                for (final cr in top.take(3))
                                  DataCell(
                                    Text(
                                      '${((m.matrix.at(cr.id, i).ry ?? 0) * 100).round()}%',
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
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

/// Assumptions editor with "reset to defaults" and the visible difference from the defaults.
class AssumptionsScreen extends ConsumerWidget {
  const AssumptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final a = ref.watch(assumptionsProvider);
    final n = ref.read(assumptionsProvider.notifier);
    const d = Assumptions();

    Widget row(
      String label,
      double v,
      double def,
      double min,
      double max,
      int div,
      void Function(double) on,
    ) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                v.toStringAsFixed(v < 5 ? 2 : 0),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (v != def)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    '(${t('adv_changed')}: ${def.toStringAsFixed(def < 5 ? 2 : 0)})',
                    style: const TextStyle(
                      color: SamaColors.amber,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          Slider(
            value: v.clamp(min, max),
            min: min,
            max: max,
            divisions: div,
            onChanged: on,
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SamaTopBar(
          title: t('adv_assumptions'),
          onBack: () => context.canPop() ? context.pop() : context.go('/me'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: SamaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                row(
                  t('adv_threshold'),
                  a.goodThreshold,
                  d.goodThreshold,
                  0.5,
                  1.0,
                  10,
                  (v) => n.set(a.copyWith(goodThreshold: v)),
                ),
                row(
                  t('adv_taw'),
                  a.tawPerM,
                  d.tawPerM,
                  60,
                  220,
                  16,
                  (v) => n.set(a.copyWith(tawPerM: v)),
                ),
                row(
                  '${t('adv_depth')} · ${t('soil_shallow')}',
                  a.shallowM,
                  d.shallowM,
                  0.3,
                  1.0,
                  14,
                  (v) => n.set(a.copyWith(shallowM: v)),
                ),
                row(
                  '${t('adv_depth')} · ${t('soil_medium')}',
                  a.mediumM,
                  d.mediumM,
                  0.5,
                  1.5,
                  20,
                  (v) => n.set(a.copyWith(mediumM: v)),
                ),
                row(
                  '${t('adv_depth')} · ${t('soil_deep')}',
                  a.deepM,
                  d.deepM,
                  1.0,
                  2.5,
                  15,
                  (v) => n.set(a.copyWith(deepM: v)),
                ),
                row(
                  '${t('adv_irr_mm')} · ${t('irr_limited')}',
                  a.irrLimited,
                  d.irrLimited,
                  0,
                  400,
                  40,
                  (v) => n.set(a.copyWith(irrLimited: v)),
                ),
                row(
                  '${t('adv_irr_mm')} · ${t('irr_moderate')}',
                  a.irrModerate,
                  d.irrModerate,
                  0,
                  800,
                  40,
                  (v) => n.set(a.copyWith(irrModerate: v)),
                ),
                row(
                  '${t('adv_irr_mm')} · ${t('irr_available')}',
                  a.irrAvailable,
                  d.irrAvailable,
                  0,
                  1200,
                  24,
                  (v) => n.set(a.copyWith(irrAvailable: v)),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: a.isDefault ? null : n.reset,
                  icon: const Icon(Icons.restart_alt),
                  label: Text(t('adv_reset')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
