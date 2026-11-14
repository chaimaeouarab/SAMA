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

/// Annual crops with a documented Ky first (by chance, then name), then annual crops that need more
/// information, then trees (all alphabetical).
List<Crop> sortedCrops(FieldModel m, String filter, String lang) {
  final list = m.catalog.crops
      .where((c) => filter == 'all' || c.category == filter)
      .toList();
  int rank(Crop c) => c.eligible ? 0 : (c.annual ? 1 : 2);
  list.sort((a, b) {
    if (rank(a) != rank(b)) return rank(a).compareTo(rank(b));
    if (a.eligible) {
      final d = m.chance(b.id)!.compareTo(m.chance(a.id)!);
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
        ModelBody(
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
                    CropCard(
                      crop: c,
                      chance: c.eligible ? m.chance(c.id) : null,
                    ),
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

/// Photo card: name + chance (annual with documented Ky), "?" (annual, needs information) or "Perennial" (trees).
class CropCard extends ConsumerWidget {
  const CropCard({super.key, required this.crop, required this.chance});
  final Crop crop;
  final double? chance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final t = trOf(ref);
    final tail = !crop.annual
        ? t('perennial')
        : (chance == null ? '?' : '${(chance! * 100).round()}%');
    final label = '${crop.name(lang.code)} · $tail';
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
