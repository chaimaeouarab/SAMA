import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../domain/aquifer.dart';
import '../../widgets/common.dart';

/// Scenario only: dh = -v (1 - a s) t. Never presented as a measurement.
class AquiferScreen extends ConsumerStatefulWidget {
  const AquiferScreen({super.key});

  @override
  ConsumerState<AquiferScreen> createState() => _AquiferScreenState();
}

class _AquiferScreenState extends ConsumerState<AquiferScreen> {
  double _saving = 0.3;
  double _years = 10;

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    final dh = aquiferChange(saving: _saving, years: _years);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SamaTopBar(
          title: t('aquifer'),
          onBack: () =>
              context.canPop() ? context.pop() : context.go('/results'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF0D9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: SamaColors.amber,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        t('aq_scenario'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SamaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('aq_result'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${dh.toStringAsFixed(1)} ${t('metres')}',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: SamaColors.water,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${t('aq_saving')}: ${(_saving * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Slider(
                      value: _saving,
                      divisions: 20,
                      label: '${(_saving * 100).round()}%',
                      onChanged: (v) => setState(() => _saving = v),
                    ),
                    Text(
                      '${t('aq_years')}: ${_years.round()}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Slider(
                      value: _years,
                      min: 1,
                      max: 30,
                      divisions: 29,
                      label: '${_years.round()}',
                      onChanged: (v) => setState(() => _years = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(t('aq_note'), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
