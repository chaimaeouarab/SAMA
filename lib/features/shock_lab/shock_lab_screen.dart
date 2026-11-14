import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../domain/crop_model.dart';
import '../../domain/monte_carlo.dart';
import '../../domain/outcome_matrix.dart';
import '../../domain/rotation.dart';
import '../../domain/scenarios.dart';
import '../../state/assumptions.dart';
import '../../state/farm_state.dart';
import '../../state/results_provider.dart';
import '../../state/settings.dart';
import '../../widgets/common.dart';

/// Hypothetical what-if controls. Nothing here is NASA observation: every result says so.
class LabState {
  const LabState({
    this.rainMult = 1.0,
    this.warm = false,
    this.irrigation,
    this.rotation = 'A',
  });
  final double rainMult;
  final bool warm;

  /// Null = the farm's own irrigation.
  final IrrigationClass? irrigation;
  final String rotation;

  bool get isWhatIf => rainMult != 1.0 || warm || irrigation != null;
  Shock get shock => Shock(
    rainMult: rainMult,
    tempAdd: warm ? ModelConstants.warmerDeltaC : 0,
  );

  LabState copyWith({
    double? rainMult,
    bool? warm,
    IrrigationClass? irrigation,
    bool clearIrrigation = false,
    String? rotation,
  }) => LabState(
    rainMult: rainMult ?? this.rainMult,
    warm: warm ?? this.warm,
    irrigation: clearIrrigation ? null : (irrigation ?? this.irrigation),
    rotation: rotation ?? this.rotation,
  );

  @override
  bool operator ==(Object other) =>
      other is LabState &&
      other.rainMult == rainMult &&
      other.warm == warm &&
      other.irrigation == irrigation &&
      other.rotation == rotation;
  @override
  int get hashCode => Object.hash(rainMult, warm, irrigation, rotation);
}

class LabNotifier extends Notifier<LabState> {
  @override
  LabState build() => const LabState();
  void set(LabState s) => state = s;

  /// "What if there is less rain?": the dry what-if (also used by voice).
  void lessRain() => state = state.copyWith(rainMult: ModelConstants.rainDry);
  void reset() => state = LabState(rotation: state.rotation);
}

final labStateProvider = NotifierProvider<LabNotifier, LabState>(
  LabNotifier.new,
);

class LabResult {
  LabResult(this.before, this.after, this.sequence, this.bestAfter);
  final RotationResult? before;
  final RotationResult? after;
  final List<String> sequence;

  /// Best rotation under the what-if, when it differs from the chosen one.
  final Rotation? bestAfter;
}

final labProvider = FutureProvider.family<LabResult, String>((
  ref,
  cropId,
) async {
  final m = await ref.watch(modelProvider.future);
  final lab = ref.watch(labStateProvider);
  final rots = await ref.watch(rotationsProvider(cropId).future);
  final chosen = rots.firstWhere(
    (r) => r.id == lab.rotation,
    orElse: () => rots.first,
  );
  final seq = [for (final c in chosen.crops) c.id];
  final a = ref.watch(assumptionsProvider);
  final farm = ref.watch(farmProvider);
  final params = FarmParams(
    soilDepthM: a.soilDepth(farm.soil),
    irrigationMm: a.irrigationMm(lab.irrigation ?? farm.irrigation),
    tawPerM: a.tawPerM,
  );
  final catalog = m.catalog;
  final climate = m.climate;
  final futures = m.futures;
  final rules = m.data.rules;
  final threshold = m.threshold;
  final prev = m.inputs.previousFamily;
  final selected = catalog.byId(cropId);
  final out = await ref.read(heavyRunnerProvider)(() {
    final after = OutcomeMatrix.build(
      crops: catalog.annuals,
      climate: climate,
      farm: params,
      shock: lab.shock,
    );
    final res = evaluateRotation(
      cropIds: seq,
      matrix: after,
      futures: futures,
      threshold: threshold,
    );
    final ranked = rankRotations(
      buildRotations(
        selected: selected,
        catalog: catalog,
        matrix: after,
        futures: futures,
        rules: rules,
        previousFamily: prev,
        threshold: threshold,
      ),
    );
    return (res, ranked.isEmpty ? null : ranked.first);
  });
  final best = out.$2;
  final differs =
      best != null && best.crops.map((c) => c.id).join() != seq.join();
  return LabResult(chosen.result, out.$1, seq, differs ? best : null);
});

class ShockLabScreen extends ConsumerWidget {
  const ShockLabScreen({super.key, this.cropId});
  final String? cropId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final lang = ref.watch(langProvider);
    final lab = ref.watch(labStateProvider);
    final n = ref.read(labStateProvider.notifier);

    return ModelBody(
      builder: (m) {
        final id = cropId ?? m.rankedEligible.first.id;
        final res = ref.watch(labProvider(id));
        Widget chips<T>(List<(T, String)> o, T cur, void Function(T) on) =>
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final x in o)
                  ChoiceChip(
                    label: Text(x.$2),
                    selected: cur == x.$1,
                    onSelected: (_) => on(x.$1),
                  ),
              ],
            );
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SamaTopBar(
              title: t('sl_title'),
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/explore'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(60),
                      backgroundColor: SamaColors.water,
                    ),
                    onPressed: n.lessRain,
                    icon: const Icon(Icons.water_drop_outlined),
                    label: Text(t('sl_less_rain')),
                  ),
                  const SizedBox(height: 12),
                  SamaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('sl_rain'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        chips<double>(
                          [
                            (1.0, t('sl_normal')),
                            (ModelConstants.rainDry, t('sl_m20')),
                            (ModelConstants.rainVeryDry, t('sl_m40')),
                          ],
                          lab.rainMult,
                          (v) => n.set(lab.copyWith(rainMult: v)),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          t('sl_temp'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        chips<bool>(
                          [(false, t('sl_hist')), (true, t('sl_warm'))],
                          lab.warm,
                          (v) => n.set(lab.copyWith(warm: v)),
                        ),
                        Text(
                          t('sl_temp_note'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          t('sl_irrig'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        chips<IrrigationClass?>(
                          [
                            (null, '= ${t('farm_title')}'),
                            for (final i in IrrigationClass.values)
                              (i, t('irr_${i.name}')),
                          ],
                          lab.irrigation,
                          (v) => n.set(
                            v == null
                                ? lab.copyWith(clearIrrigation: true)
                                : lab.copyWith(irrigation: v),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          t('sl_rotation'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        chips<String>(
                          [
                            for (final r in ['A', 'B', 'C'])
                              (r, '$r · ${t('rot_$r')}'),
                          ],
                          lab.rotation,
                          (v) => n.set(lab.copyWith(rotation: v)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (lab.isWhatIf) StatusLine(Status.info, t('whatif')),
                  AsyncBody(
                    value: res,
                    onRetry: () => ref.invalidate(labProvider(id)),
                    builder: (r) => _BeforeAfter(
                      r: r,
                      lang: lang.code,
                      cropId: id,
                      lab: lab,
                    ),
                  ),
                  if (lab.isWhatIf)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: n.reset,
                      child: Text(t('sl_reset')),
                    ),
                ],
              ),
            ),
            const SourceNote(),
          ],
        );
      },
    );
  }
}

class _BeforeAfter extends ConsumerWidget {
  const _BeforeAfter({
    required this.r,
    required this.lang,
    required this.cropId,
    required this.lab,
  });
  final LabResult r;
  final String lang;
  final String cropId;
  final LabState lab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final m = ref.watch(modelProvider).value;
    final b = r.before, a = r.after;
    if (b == null || a == null || m == null) {
      return StatusLine(Status.info, t('tm_need_info'));
    }
    final dp = ((a.pAllGood - b.pAllGood) * 10).round();
    final names = r.sequence
        .map((id) => m.catalog.byId(id).name(lang))
        .join(' → ');

    Widget col(
      String title,
      RotationResult x, {
      required bool after,
    }) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SamaCard(
          color: after && lab.isWhatIf ? const Color(0xFFE3EEF8) : Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                '${x.inTen} ${t('in10')}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: SamaColors.green,
                ),
              ),
              StatusLine(statusOfChance(x.pAllGood), t('all3good')),
              const SizedBox(height: 6),
              Text(
                '${t('exp_yield')}: ${(x.expectedRy * 100).round()}%',
                style: const TextStyle(fontSize: 13),
              ),
              Text(
                '${t('worst_case')}: ${(x.worst * 100).round()}%',
                style: const TextStyle(fontSize: 13),
              ),
              Text(
                '${t('deficit')}: ${x.expectedDeficit.round()} ${t('mm')}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(names, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            col('${t('sl_before')} · ${t('observed')}', b, after: false),
            col(
              '${t('sl_after')}${lab.isWhatIf ? ' · ${t('whatif')}' : ''}',
              a,
              after: true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${t('sl_diff')}: ${dp > 0 ? '+' : ''}$dp ${t('in10')} · ${((a.expectedRy - b.expectedRy) * 100).round()}% ${t('exp_yield')}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        if (r.bestAfter != null) ...[
          const SizedBox(height: 12),
          SamaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('sl_alternatives'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${r.bestAfter!.id} · ${r.bestAfter!.crops.map((c) => c.name(lang)).join(' → ')}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${r.bestAfter!.result!.inTen} ${t('in10')} · ${t('whatif')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 6),
      ],
    );
  }
}
