import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../widgets/common.dart';

/// One door to the four exploration tools: not five separate apps.
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SamaTopBar(title: t('ex_title')),
        BigCard(
          icon: Icons.timeline,
          title: t('ex_time'),
          subtitle: t('tm_intro'),
          onTap: () => context.go('/time'),
        ),
        BigCard(
          icon: Icons.water_drop_outlined,
          title: t('ex_shock'),
          subtitle: t('whatif'),
          color: SamaColors.water,
          onTap: () => context.go('/shock'),
        ),
        BigCard(
          icon: Icons.search,
          title: t('ex_detective'),
          subtitle: t('dt_nothing'),
          color: SamaColors.amber,
          onTap: () => context.go('/detective'),
        ),
        BigCard(
          icon: Icons.satellite_alt,
          title: t('ex_sat'),
          subtitle: t('sat_modis'),
          color: SamaColors.green2,
          onTap: () => context.go('/satellite'),
        ),
        const SourceNote(),
      ],
    );
  }
}
