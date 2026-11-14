import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../state/farm_state.dart';
import '../../widgets/common.dart';

/// Soil depth, irrigation, previous crop and area. "I don't know" keeps the input unknown so the
/// Detective can ask about it later, only if the answer would change the result.
class FarmInputsScreen extends ConsumerWidget {
  const FarmInputsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final farm = ref.watch(farmProvider);
    final n = ref.read(farmsProvider.notifier);

    Widget heading(String k) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(t(k), style: Theme.of(context).textTheme.titleMedium),
    );

    Widget choice<T>({
      required List<(T, String)> options,
      required T? value,
      required bool known,
      required void Function(T) onPick,
      required VoidCallback onUnknown,
    }) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final o in options)
            ChoiceChip(
              label: Text(o.$2),
              selected: known && value == o.$1,
              showCheckmark: true,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              onSelected: (_) => onPick(o.$1),
            ),
          ChoiceChip(
            label: Text(t('dont_know')),
            selected: !known,
            showCheckmark: true,
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            onSelected: (_) => onUnknown(),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SamaTopBar(
          title: t('farm_title'),
          onBack: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SamaCard(
                child: Row(
                  children: [
                    const Icon(Icons.place, color: SamaColors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            farm.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            '${farm.lat.toStringAsFixed(5)}, ${farm.lon.toStringAsFixed(5)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/farm/location'),
                      child: Text(t('edit')),
                    ),
                  ],
                ),
              ),
              heading('soil'),
              choice<SoilClass>(
                options: [
                  for (final s in SoilClass.values) (s, t('soil_${s.name}')),
                ],
                value: farm.soil,
                known: farm.soilKnown,
                onPick: (v) =>
                    n.update((f) => f.copyWith(soil: v, soilKnown: true)),
                onUnknown: () => n.update((f) => f.copyWith(soilKnown: false)),
              ),
              heading('irrigation'),
              choice<IrrigationClass>(
                options: [
                  for (final s in IrrigationClass.values)
                    (s, t('irr_${s.name}')),
                ],
                value: farm.irrigation,
                known: farm.irrigationKnown,
                onPick: (v) => n.update(
                  (f) => f.copyWith(irrigation: v, irrigationKnown: true),
                ),
                onUnknown: () => n.update(
                  (f) => f.copyWith(
                    irrigationKnown: false,
                    irrigation: IrrigationClass.none,
                  ),
                ),
              ),
              heading('prev_crop'),
              choice<String>(
                options: [
                  for (final f in [
                    'Poaceae',
                    'Fabaceae',
                    'Solanaceae',
                    'other',
                  ])
                    (f, t('fam_$f')),
                ],
                value: farm.previousFamily,
                known: farm.previousKnown,
                onPick: (v) => n.update(
                  (f) => f.copyWith(previousFamily: v, previousKnown: true),
                ),
                onUnknown: () => n.update(
                  (f) => f.copyWith(previousKnown: false, clearPrevious: true),
                ),
              ),
              heading('area'),
              AreaStepper(
                value: farm.areaHa,
                onChanged: (v) => n.update((f) => f.copyWith(areaHa: v)),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: Text(t('save')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AreaStepper extends StatelessWidget {
  const AreaStepper({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton.filled(
        style: IconButton.styleFrom(
          backgroundColor: SamaColors.green,
          minimumSize: const Size(48, 48),
        ),
        tooltip: '−',
        onPressed: value > 1 ? () => onChanged(value - 1) : null,
        icon: const Icon(Icons.remove),
      ),
      SizedBox(
        width: 56,
        child: Text(
          '$value',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      IconButton.filled(
        style: IconButton.styleFrom(
          backgroundColor: SamaColors.green,
          minimumSize: const Size(48, 48),
        ),
        tooltip: '+',
        onPressed: value < 1000 ? () => onChanged(value + 1) : null,
        icon: const Icon(Icons.add),
      ),
    ],
  );
}
