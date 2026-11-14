import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../domain/missing_piece.dart';
import '../../domain/plans.dart';
import '../../domain/water_balance.dart';
import '../../state/farm_state.dart';
import '../../state/results_provider.dart';
import '../../state/settings.dart';
import '../../voice/phrase_builder.dart';
import '../../widgets/common.dart';
import '../../widgets/crop_art.dart';
import '../../widgets/speaker.dart';
import '../crop_detail/crop_detail_screen.dart';

class FuturesResult {
  FuturesResult(this.plans, this.missing);
  final List<Plan> plans;
  final MissingPiece? missing;
}

final futuresProvider = FutureProvider.family<FuturesResult, String>((
  ref,
  cropId,
) async {
  final m = await ref.watch(fieldModelProvider.future);
  final crop = m.catalog.byId(cropId);
  final plans = buildPlans(crop, m.catalog, m.ctx);
  return FuturesResult(plans, findMissingPiece(crop, m.catalog, m.ctx, plans));
});

class FuturesScreen extends ConsumerWidget {
  const FuturesScreen({super.key, required this.cropId});
  final String cropId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final lang = ref.watch(langProvider);
    final advisor = ref.watch(settingsProvider.select((s) => s.advisor));
    final res = ref.watch(futuresProvider(cropId));
    final model = ref.watch(fieldModelProvider).value;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SamaTopBar(
          title: t('futures'),
          onBack: () => context.go('/crop/$cropId'),
          trailing: res.value == null
              ? null
              : SpeakerButton(
                  PhraseBuilder.adviceWithDisclaimer(
                    cropId,
                    rankPlans(res.value!.plans).first.sim.inTen,
                  ),
                  size: 40,
                ),
        ),
        AsyncBody(
          value: res,
          onRetry: () => ref.invalidate(futuresProvider(cropId)),
          builder: (r) {
            final best = rankPlans(r.plans).first.id;
            return Column(
              children: [
                for (final p in r.plans)
                  _PlanCard(
                    plan: p,
                    isBest: p.id == best,
                    lang: lang.code,
                    advisor: advisor,
                  ),
                if (r.missing != null && model != null)
                  _MissingCard(piece: r.missing!),
                const SourceNote(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                  child: Text(
                    t('prov_needs'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({
    required this.plan,
    required this.isBest,
    required this.lang,
    required this.advisor,
  });
  final Plan plan;
  final bool isBest;
  final String lang;
  final bool advisor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final x = plan.sim.inTen;
    final scale = plan.availAvg > plan.needAvg
        ? plan.availAvg
        : plan.needAvg; // both bars share one scale
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: SamaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: SamaColors.green,
                  child: Text(
                    plan.id,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t('plan_${plan.id.toLowerCase()}'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (isBest)
                  const Icon(
                    Icons.star,
                    color: SamaColors.amber,
                    semanticLabel: 'best',
                  ),
              ],
            ),
            if (isBest)
              Text(
                t('best_plan'),
                style: const TextStyle(
                  color: SamaColors.amber,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final c in plan.crops)
                  Expanded(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 56,
                            width: 56,
                            child: CropImage(c),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.name(lang),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '$x ${t('in10')}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: SamaColors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatusLine(statusOf(plan.sim.p), t('all3good')),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(t('water_have'), style: Theme.of(context).textTheme.bodySmall),
            _Bar(value: plan.availAvg / scale, color: SamaColors.water),
            const SizedBox(height: 6),
            Text(t('water_need'), style: Theme.of(context).textTheme.bodySmall),
            _Bar(value: plan.needAvg / scale, color: SamaColors.amber),
            if (advisor)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${plan.availAvg.round()} / ${plan.needAvg.round()} ${t('water_unit')} · ${plan.sim.good}/${plan.sim.total}',
                  style: const TextStyle(fontSize: 13, color: SamaColors.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: LinearProgressIndicator(
      value: value,
      minHeight: 12,
      color: color,
      backgroundColor: SamaColors.line,
    ),
  );
}

class _MissingCard extends ConsumerWidget {
  const _MissingCard({required this.piece});
  final MissingPiece piece;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final isSoil = piece.question == 'soil';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: SamaCard(
        color: const Color(0xFFFBF0D9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.extension, color: SamaColors.amber),
                const SizedBox(width: 8),
                Text(
                  t('missing'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t(isSoil ? 'missing_q_soil' : 'missing_q_prev'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            for (final o in piece.outcomes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final n = ref.read(farmProvider.notifier);
                    if (isSoil) {
                      n.update(
                        soil: SoilDepth.values.firstWhere(
                          (s) => s.name == o.answerKey,
                        ),
                      );
                    } else {
                      n.update(previousLegume: o.answerKey == 'yes');
                    }
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isSoil ? t('soil_${o.answerKey}') : t(o.answerKey),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${t('best_plan')}: ${o.topPlanId} · '
                        '${o.chances.map((c) => (c * 10).round()).join('/')} ${t('in10')}',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
