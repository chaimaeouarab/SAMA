import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../state/farm_state.dart';
import '../../state/settings.dart';
import '../../widgets/common.dart';
import '../../widgets/language_sheet.dart';
import '../../widgets/sama_logo.dart';

/// No share, no account, no login.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final lang = ref.watch(langProvider);
    final s = ref.watch(settingsProvider);
    final farm = ref.watch(farmProvider);
    final n = ref.read(settingsProvider.notifier);

    Widget label(IconData i, String k) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(i, size: 20, color: SamaColors.green),
          const SizedBox(width: 8),
          Text(t(k), style: const TextStyle(fontSize: 16)),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SamaTopBar(title: t('settings')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              const SizedBox(height: 8),
              SamaCard(
                child: InkWell(
                  onTap: () => showLanguageSheet(context, ref),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('language'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(lang.label),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SamaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('farm_title'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${farm.name} · ${farm.lat.toStringAsFixed(3)}, ${farm.lon.toStringAsFixed(3)}',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => context.go('/farm/location'),
                          child: Text(t('loc_search')),
                        ),
                        TextButton(
                          onPressed: () => context.go('/farm/inputs'),
                          child: Text(t('edit')),
                        ),
                      ],
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
                      t('mode'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      style: SegmentedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                      ),
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(t('mode_farmer')),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(t('mode_advisor')),
                        ),
                      ],
                      selected: {s.advisor},
                      onSelectionChanged: (v) => n.setAdvisor(v.first),
                    ),
                    if (s.advisor)
                      TextButton(
                        onPressed: () => context.go('/assumptions'),
                        child: Text(t('adv_assumptions')),
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
                      t('voice'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(t('voice_male')),
                    Text(
                      t('tts_note'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    label(Icons.volume_up, 'volume'),
                    Slider(
                      value: s.volume,
                      onChanged: n.setVolume,
                      semanticFormatterCallback: (v) => '${(v * 100).round()}%',
                    ),
                    label(Icons.speed, 'speed'),
                    Slider(
                      value: s.speed,
                      min: 0.7,
                      max: 1.3,
                      divisions: 6,
                      label: s.speed.toStringAsFixed(1),
                      onChanged: n.setSpeed,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SamaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: SamaLogo(height: 70)),
                    const SizedBox(height: 8),
                    Text(
                      t('about'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(t('source')),
                    const SizedBox(height: 8),
                    Text(
                      t('credits'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      t('credits_note'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t('prov_params'),
                      style: const TextStyle(
                        color: SamaColors.amber,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: const StadiumBorder(),
                ),
                onPressed: n.resetFirstLaunch,
                icon: const Icon(Icons.restart_alt),
                label: Text(t('reset_first')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
