import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../data/crops_catalog.dart';
import '../../state/results_provider.dart';
import '../../state/settings.dart';
import '../../widgets/common.dart';
import '../../widgets/crop_art.dart';

class CropFilter extends Notifier<String> {
  @override
  String build() => 'all';
  void set(String v) => state = v;
}

final cropFilterProvider = NotifierProvider<CropFilter, String>(CropFilter.new);

/// Annual crops by chance, then alphabetical; trees last (alphabetical).
List<Crop> sortedCrops(FieldModel m, String filter, String lang) {
  final list = m.catalog.crops
      .where((c) => filter == 'all' || c.category == filter)
      .toList();
  list.sort((a, b) {
    if (a.annual != b.annual) return a.annual ? -1 : 1;
    if (a.annual) {
      final d = m.chances[b.id]!.compareTo(m.chances[a.id]!);
      if (d != 0) return d;
    }
    return a.name(lang).compareTo(b.name(lang));
  });
  return list;
}

class CropsScreen extends ConsumerWidget {
  const CropsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final lang = ref.watch(langProvider);
    final filter = ref.watch(cropFilterProvider);
    final model = ref.watch(fieldModelProvider);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SamaTopBar(title: t('nav_farm')),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            children: [
              for (final k in ['all', ...cropCategories])
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(t('c_$k')),
                    selected: filter == k,
                    showCheckmark: false,
                    selectedColor: SamaColors.green,
                    labelStyle: TextStyle(
                      color: filter == k ? Colors.white : SamaColors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    onSelected: (_) =>
                        ref.read(cropFilterProvider.notifier).set(k),
                  ),
                ),
            ],
          ),
        ),
        AsyncBody(
          value: model,
          onRetry: () => ref.invalidate(fieldModelProvider),
          builder: (m) {
            final list = sortedCrops(m, filter, lang.code);
            if (list.isEmpty) return const EmptyView();
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final c in list)
                    CropCard(crop: c, chance: m.chances[c.id]),
                ],
              ),
            );
          },
        ),
        const SourceNote(),
      ],
    );
  }
}

/// Photo card: name + chance (annual) or "Perennial" (trees).
class CropCard extends ConsumerWidget {
  const CropCard({super.key, required this.crop, required this.chance});
  final Crop crop;
  final double? chance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final t = trOf(ref);
    final label =
        '${crop.name(lang.code)} · ${chance == null ? t('perennial') : '${(chance! * 100).round()}%'}';
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/crop/${crop.id}'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CropImage(crop),
              Align(
                alignment: AlignmentDirectional.bottomStart,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x99000000)],
                    ),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
