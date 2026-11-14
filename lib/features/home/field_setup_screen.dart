import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../data/towns.dart';
import '../../domain/water_balance.dart';
import '../../state/farm_state.dart';
import '../../state/settings.dart';
import '../../widgets/common.dart';

class FieldSetupScreen extends ConsumerWidget {
  const FieldSetupScreen({super.key});

  Future<void> _locate(BuildContext context, WidgetRef ref) async {
    final t = trOf(ref);
    final messenger = ScaffoldMessenger.of(context);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        messenger.showSnackBar(SnackBar(content: Text(t('loc_denied'))));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
      final town = snapToTown(pos.latitude, pos.longitude);
      if (town == null) {
        messenger.showSnackBar(SnackBar(content: Text(t('loc_far'))));
      } else {
        ref.read(farmProvider.notifier).update(townId: town.id);
      }
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(t('loc_denied'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final lang = ref.watch(langProvider);
    final farm = ref.watch(farmProvider);
    final n = ref.read(farmProvider.notifier);

    Widget heading(String k) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(t(k), style: Theme.of(context).textTheme.titleMedium),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SamaTopBar(title: t('field'), onBack: () => context.go('/home')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading('town'),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: () => _locate(context, ref),
                icon: const Icon(Icons.my_location),
                label: Text(t('use_location')),
              ),
              const SizedBox(height: 8),
              SamaCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: RadioGroup<String>(
                  groupValue: farm.townId,
                  onChanged: (v) => n.update(townId: v),
                  child: Column(
                    children: [
                      for (final tw in towns)
                        RadioListTile<String>(
                          value: tw.id,
                          title: Text(
                            tw.name(lang.code),
                            style: const TextStyle(fontSize: 17),
                          ),
                          activeColor: SamaColors.green,
                        ),
                    ],
                  ),
                ),
              ),
              heading('soil'),
              SegmentedButton<SoilDepth>(
                style: SegmentedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                ),
                segments: [
                  for (final s in SoilDepth.values)
                    ButtonSegment(value: s, label: Text(t('soil_${s.name}'))),
                ],
                selected: {farm.soil},
                onSelectionChanged: (s) => n.update(soil: s.first),
              ),
              heading('prev_crop'),
              SegmentedButton<bool>(
                style: SegmentedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                ),
                segments: [
                  ButtonSegment(value: true, label: Text(t('yes'))),
                  ButtonSegment(value: false, label: Text(t('no'))),
                ],
                selected: {farm.previousLegume},
                onSelectionChanged: (s) => n.update(previousLegume: s.first),
              ),
              heading('area'),
              AreaStepper(
                value: farm.areaHa,
                onChanged: (v) => n.update(areaHa: v),
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
        onPressed: value < 50 ? () => onChanged(value + 1) : null,
        icon: const Icon(Icons.add),
      ),
    ],
  );
}
