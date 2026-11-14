import '../core/constants.dart';
import '../data/crops_catalog.dart';
import 'monte_carlo.dart';
import 'water_balance.dart';

/// Everything the model needs to know about the farmer's field.
class FieldContext {
  const FieldContext({
    required this.rains,
    required this.soil,
    required this.previousLegume,
  });
  final List<double> rains;
  final SoilDepth soil;
  final bool previousLegume;

  FieldContext copyWith({SoilDepth? soil, bool? previousLegume}) =>
      FieldContext(
        rains: rains,
        soil: soil ?? this.soil,
        previousLegume: previousLegume ?? this.previousLegume,
      );
}

class Plan {
  const Plan(this.id, this.crops, this.sim, this.needAvg, this.availAvg);
  final String id; // 'A' | 'B' | 'C'
  final List<Crop> crops;
  final SimResult sim;

  /// Average water need per season (m3/ha) and typical availability, for the bar.
  final double needAvg;
  final double availAvg;
}

/// Chance of a good season (one season, this field) for each annual crop.
double chanceOf(Crop crop, FieldContext f) => simulate(
  sequence: [crop],
  rains: f.rains,
  soil: f.soil,
  previousLegume: f.previousLegume,
).p;

Crop _best(Iterable<Crop> candidates, Crop preferred, FieldContext f) {
  // Ties keep the earlier candidate; the farmer's own pick wins ties.
  final list = candidates.toList();
  var best = list.contains(preferred) ? preferred : list.first;
  var bestP = chanceOf(best, f);
  for (final c in list) {
    final p = chanceOf(c, f);
    if (p > bestP) {
      best = c;
      bestP = p;
    }
  }
  return best;
}

Plan _plan(String id, List<Crop> crops, FieldContext f) {
  final sim = simulate(
    sequence: crops,
    rains: f.rains,
    soil: f.soil,
    previousLegume: f.previousLegume,
  );
  var need = 0.0;
  for (var i = 0; i < crops.length; i++) {
    final prev = i == 0 ? f.previousLegume : crops[i - 1].legume;
    need += waterNeeded(crops[i].waterNeed!, previousLegume: prev);
  }
  final avail =
      f.rains.map((r) => waterAvailable(r, f.soil)).reduce((a, b) => a + b) /
      f.rains.length;
  return Plan(id, crops, sim, need / crops.length, avail);
}

/// Plans A (same crop), B (best crop / legume / best crop), C (three families).
/// [selected] must be an annual crop. Returned in A, B, C order.
List<Plan> buildPlans(Crop selected, CropCatalog catalog, FieldContext f) {
  final annuals = catalog.annuals;
  final best = _best(annuals, selected, f);
  final legumes = annuals.where((c) => c.legume);
  final bestLegume = _best(legumes, selected, f);

  // Plan C: the selected family first, then the best crop of the two next-best families.
  final families = cropCategories.where((c) => c != 'tree').toList();
  final bestPerFamily = {
    for (final fam in families)
      fam: _best(annuals.where((c) => c.category == fam), selected, f),
  };
  final others = families.where((c) => c != selected.category).toList()
    ..sort(
      (a, b) => chanceOf(
        bestPerFamily[b]!,
        f,
      ).compareTo(chanceOf(bestPerFamily[a]!, f)),
    );
  final c = [
    bestPerFamily[selected.category]!,
    bestPerFamily[others[0]]!,
    bestPerFamily[others[1]]!,
  ];

  return [
    _plan('A', List.filled(ModelConstants.seasonsPerFuture, selected), f),
    _plan('B', [best, bestLegume, best], f),
    _plan('C', c, f),
  ];
}

/// Best first. Ties keep A, B, C order (stable sort).
List<Plan> rankPlans(List<Plan> plans) {
  final indexed = plans.asMap().entries.toList()
    ..sort((a, b) {
      final d = b.value.sim.good.compareTo(a.value.sim.good);
      return d != 0 ? d : a.key.compareTo(b.key);
    });
  return [for (final e in indexed) e.value];
}
