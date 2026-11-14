import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/detective.dart';
import '../../state/farm_state.dart';
import '../../state/results_provider.dart';
import '../../state/settings.dart';
import '../../widgets/common.dart';

/// Asks ONE question at a time, only when a plausible answer would change or narrow the result.
class DetectiveScreen extends ConsumerWidget {
  const DetectiveScreen({super.key, this.cropId});
  final String? cropId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final advisor = ref.watch(settingsProvider.select((s) => s.advisor));
    return ModelBody(
      builder: (m) {
        final id = cropId ?? m.rankedEligible.first.id;
        final res = ref.watch(detectiveProvider(id));
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SamaTopBar(
              title: t('dt_title'),
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/explore'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: AsyncBody(
                value: res,
                onRetry: () => ref.invalidate(detectiveProvider(id)),
                builder: (r) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (r.question == null)
                      SamaCard(child: StatusLine(Status.good, t('dt_nothing')))
                    else
                      _Question(q: r.question!, cropId: id),
                    if (advisor) ...[
                      const SizedBox(height: 16),
                      Text(
                        t('dt_sens'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final s in r.sensitivity)
                        ListTile(
                          dense: true,
                          title: Text(_label(t, s.input)),
                          trailing: Text(
                            '${s.spread.toStringAsFixed(0)} ${t('pp')}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
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

String _label(String Function(String) t, DetectiveInput i) => switch (i) {
  DetectiveInput.soil => t('soil'),
  DetectiveInput.irrigation => t('irrigation'),
  DetectiveInput.previousCrop => t('prev_crop'),
};

class _Question extends ConsumerWidget {
  const _Question({required this.q, required this.cropId});
  final DetectiveQuestion q;
  final String cropId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final n = ref.read(farmsProvider.notifier);
    final text = switch (q.input) {
      DetectiveInput.soil => t('dt_q_soil'),
      DetectiveInput.irrigation => t('dt_q_irrigation'),
      DetectiveInput.previousCrop => t('dt_q_prev'),
    };

    String answerLabel(String k) => switch (q.input) {
      DetectiveInput.soil => t('soil_$k'),
      DetectiveInput.irrigation => t('irr_$k'),
      DetectiveInput.previousCrop => t('fam_$k'),
    };

    void answer(String k) => n.update(
      (f) => switch (q.input) {
        DetectiveInput.soil => f.copyWith(
          soil: SoilClass.values.firstWhere((s) => s.name == k),
          soilKnown: true,
        ),
        DetectiveInput.irrigation => f.copyWith(
          irrigation: IrrigationClass.values.firstWhere((s) => s.name == k),
          irrigationKnown: true,
        ),
        DetectiveInput.previousCrop => f.copyWith(
          previousFamily: k,
          previousKnown: true,
        ),
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(t('dt_why'), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        for (final o in q.outcomes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => answer(o.answerKey),
              child: SamaCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            answerLabel(o.answerKey),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${t('dt_best_if')}: ${o.topRotationId} · ${(o.topP * 10).round()} ${t('in10')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        Text(t('dont_know'), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
