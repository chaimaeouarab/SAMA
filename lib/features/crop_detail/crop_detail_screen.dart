import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../state/farm_state.dart';
import '../../state/results_provider.dart';
import '../../state/settings.dart';
import '../../voice/phrase_builder.dart';
import '../../widgets/common.dart';
import '../../widgets/crop_art.dart';
import '../../widgets/speaker.dart';
import '../home/field_setup_screen.dart';

Status statusOf(double p) =>
    p >= 0.7 ? Status.good : (p >= 0.4 ? Status.warn : Status.bad);

class CropDetailScreen extends ConsumerWidget {
  const CropDetailScreen({super.key, required this.cropId});
  final String cropId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final lang = ref.watch(langProvider);
    final model = ref.watch(fieldModelProvider);
    final farm = ref.watch(farmProvider);

    return AsyncBody(
      value: model,
      onRetry: () => ref.invalidate(fieldModelProvider),
      builder: (m) {
        final c = m.catalog.byId(cropId);
        final p = m.chances[c.id];
        final same = m.catalog.inCategory(c.category);
        final inTen = p == null ? null : (p * 10).round();
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            SamaTopBar(
              title: t('crop_details'),
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/crops'),
              trailing: inTen == null
                  ? null
                  : SpeakerButton(
                      PhraseBuilder.adviceWithDisclaimer(c.id, inTen),
                      size: 40,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 210,
                  width: double.infinity,
                  child: CropImage(c),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final x in same.take(5))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Semantics(
                        button: true,
                        label: x.name(lang.code),
                        child: InkWell(
                          onTap: () => context.go('/crop/${x.id}'),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: x.id == c.id
                                    ? SamaColors.green
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CropImage(x),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                boxShadow: samaCardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name(lang.code),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (p == null)
                              Text(
                                t('perennial'),
                                style: const TextStyle(
                                  color: SamaColors.green,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            else
                              StatusLine(statusOf(p), t('chance')),
                          ],
                        ),
                      ),
                      if (p != null)
                        Text(
                          '${(p * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: SamaColors.green,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t('area'),
                          style: const TextStyle(
                            color: SamaColors.muted,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      AreaStepper(
                        value: farm.areaHa,
                        onChanged: (v) =>
                            ref.read(farmProvider.notifier).update(areaHa: v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('desc'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p == null
                        ? '${t('cd_${c.category}')} ${t('notmodel')}'
                        : t('cd_${c.category}'),
                    style: const TextStyle(
                      color: SamaColors.muted,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    t('related'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final x in same.where((x) => x.id != c.id).take(4))
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Semantics(
                              button: true,
                              label: x.name(lang.code),
                              child: InkWell(
                                onTap: () => context.go('/crop/${x.id}'),
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CropImage(x),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (p != null)
                    FilledButton(
                      onPressed: () => context.go('/futures/${c.id}'),
                      child: Text(t('see3')),
                    ),
                  const SourceNote(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
