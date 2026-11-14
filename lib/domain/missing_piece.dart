import '../core/constants.dart';
import '../data/crops_catalog.dart';
import 'plans.dart';
import 'water_balance.dart';

class MissingOutcome {
  const MissingOutcome(this.answerKey, this.topPlanId, this.chances);

  /// 'shallow'|'medium'|'deep' or 'yes'|'no'.
  final String answerKey;
  final String topPlanId;

  /// P(all 3 good) of plans A, B, C under this answer.
  final List<double> chances;
}

class MissingPiece {
  const MissingPiece(this.question, this.outcomes);

  /// 'soil' or 'prev'.
  final String question;
  final List<MissingOutcome> outcomes;
}

/// If the top two plans are within 5 points, return the single question
/// (soil depth first, then previous crop) whose answer changes the best plan.
MissingPiece? findMissingPiece(
  Crop selected,
  CropCatalog catalog,
  FieldContext f,
  List<Plan> plans,
) {
  final ranked = rankPlans(plans);
  if (ranked.length < 2) return null;
  final gap = ranked[0].sim.p - ranked[1].sim.p;
  if (gap >= ModelConstants.missingPieceGap) return null;
  final currentTop = ranked.first.id;

  MissingOutcome outcome(String key, FieldContext ctx) {
    final ps = buildPlans(selected, catalog, ctx);
    return MissingOutcome(key, rankPlans(ps).first.id, [
      for (final p in ps) p.sim.p,
    ]);
  }

  final soil = [
    for (final s in SoilDepth.values) outcome(s.name, f.copyWith(soil: s)),
  ];
  if (soil.any((o) => o.topPlanId != currentTop)) {
    return MissingPiece('soil', soil);
  }

  final prev = [
    outcome('yes', f.copyWith(previousLegume: true)),
    outcome('no', f.copyWith(previousLegume: false)),
  ];
  if (prev.any((o) => o.topPlanId != currentTop)) {
    return MissingPiece('prev', prev);
  }
  return null;
}
