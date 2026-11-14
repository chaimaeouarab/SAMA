import '../core/constants.dart';
import '../data/crops_catalog.dart';
import '../data/nasa_power_repository.dart';
import 'crop_model.dart';
import 'et0.dart';
import 'outcome_matrix.dart';
import 'rotation.dart';
import 'scenarios.dart';

/// What the model knows about the farm and what the farmer has not told us.
class FarmInputs {
  const FarmInputs({
    required this.soilDepthM,
    required this.irrigationMm,
    this.previousFamily,
    this.soilKnown = true,
    this.irrigationKnown = true,
    this.previousKnown = true,
  });

  final double soilDepthM;
  final double irrigationMm;
  final String? previousFamily;
  final bool soilKnown;
  final bool irrigationKnown;
  final bool previousKnown;

  FarmParams get params =>
      FarmParams(soilDepthM: soilDepthM, irrigationMm: irrigationMm);

  FarmInputs copyWith({
    double? soilDepthM,
    double? irrigationMm,
    String? previousFamily,
    bool clearPrev = false,
  }) => FarmInputs(
    soilDepthM: soilDepthM ?? this.soilDepthM,
    irrigationMm: irrigationMm ?? this.irrigationMm,
    previousFamily: clearPrev ? null : (previousFamily ?? this.previousFamily),
    soilKnown: soilKnown,
    irrigationKnown: irrigationKnown,
    previousKnown: previousKnown,
  );
}

enum DetectiveInput { soil, irrigation, previousCrop }

class DetectiveOutcome {
  const DetectiveOutcome(
    this.answerKey,
    this.topRotationId,
    this.topP,
    this.rankedIds,
    this.gap,
  );

  /// e.g. 'shallow' | 'medium' | 'deep' | 'none' | 'limited' | ... | family name
  final String answerKey;
  final String topRotationId;
  final double topP;
  final List<String> rankedIds;

  /// Chance gap between the best and second-best rotation under this answer.
  final double gap;
}

class DetectiveQuestion {
  const DetectiveQuestion(this.input, this.outcomes);
  final DetectiveInput input;
  final List<DetectiveOutcome> outcomes;
}

class DetectiveResult {
  const DetectiveResult(this.question, this.sensitivity);

  /// Null when no unknown input would change or narrow the decision: SAMA asks nothing.
  final DetectiveQuestion? question;

  /// How much each input moves the best rotation's chance (percentage points), largest first.
  final List<({DetectiveInput input, double spread})> sensitivity;
}

const _soilAlts = {
  'shallow': ModelConstants.shallowDepth,
  'medium': ModelConstants.mediumDepth,
  'deep': ModelConstants.deepDepth,
};
const _irrAlts = {
  'none': ModelConstants.irrigationNone,
  'limited': ModelConstants.irrigationLimited,
  'moderate': ModelConstants.irrigationModerate,
  'available': ModelConstants.irrigationAvailable,
};
const _prevAlts = ['Poaceae', 'Fabaceae', 'Solanaceae'];

List<Rotation> _rank(
  FarmInputs inputs,
  Crop selected,
  CropCatalog catalog,
  TownClimate climate,
  RotationRules rules,
  List<List<int>> futures,
  Shock shock,
  List<Et0Series> et0,
) {
  final m = OutcomeMatrix.build(
    crops: catalog.eligible,
    climate: climate,
    farm: inputs.params,
    shock: shock,
    et0Cache: et0,
  );
  final rs = buildRotations(
    selected: selected,
    catalog: catalog,
    matrix: m,
    futures: futures,
    rules: rules,
    previousFamily: inputs.previousFamily,
  );
  return rankRotations(rs);
}

/// Test plausible alternative values of the uncertain inputs, see whether the ranking changes,
/// and return the single most useful question. Asks nothing if nothing would change or narrow the result.
DetectiveResult runDetective({
  required Crop selected,
  required CropCatalog catalog,
  required TownClimate climate,
  required RotationRules rules,
  required FarmInputs inputs,
  required List<List<int>> futures,
  Shock shock = Shock.none,
}) {
  final base = OutcomeMatrix.build(
    crops: [selected],
    climate: climate,
    farm: inputs.params,
    shock: shock,
  );
  final et0 = base.et0Seasons;

  DetectiveOutcome outcomeFor(String key, FarmInputs alt) {
    final r = _rank(
      alt,
      selected,
      catalog,
      climate,
      rules,
      futures,
      shock,
      et0,
    );
    if (r.isEmpty) return DetectiveOutcome(key, '-', 0, const [], 0);
    final gap = r.length < 2
        ? 1.0
        : r[0].result!.pAllGood - r[1].result!.pAllGood;
    return DetectiveOutcome(key, r.first.id, r.first.result!.pAllGood, [
      for (final x in r) x.id,
    ], gap);
  }

  final current = _rank(
    inputs,
    selected,
    catalog,
    climate,
    rules,
    futures,
    shock,
    et0,
  );
  final currentTop = current.isEmpty ? null : current.first.id;
  final withinNow = topTwoWithinUncertainty(current);

  final alts = <DetectiveInput, List<DetectiveOutcome>>{
    DetectiveInput.soil: [
      for (final e in _soilAlts.entries)
        outcomeFor(e.key, inputs.copyWith(soilDepthM: e.value)),
    ],
    DetectiveInput.irrigation: [
      for (final e in _irrAlts.entries)
        outcomeFor(e.key, inputs.copyWith(irrigationMm: e.value)),
    ],
    DetectiveInput.previousCrop: [
      for (final f in _prevAlts)
        outcomeFor(f, inputs.copyWith(previousFamily: f)),
    ],
  };

  final sens = [
    for (final e in alts.entries)
      (
        input: e.key,
        spread:
            100 *
            (e.value.map((o) => o.topP).reduce((a, b) => a > b ? a : b) -
                e.value.map((o) => o.topP).reduce((a, b) => a < b ? a : b)),
      ),
  ]..sort((a, b) => b.spread.compareTo(a.spread));

  DetectiveQuestion? best;
  var bestScore = 0.0;
  final unknown = {
    DetectiveInput.soil: !inputs.soilKnown,
    DetectiveInput.irrigation: !inputs.irrigationKnown,
    DetectiveInput.previousCrop: !inputs.previousKnown,
  };
  for (final e in alts.entries) {
    if (unknown[e.key] != true) continue;
    final tops = e.value.map((o) => o.topRotationId).toSet();
    final changes =
        tops.length > 1 ||
        (currentTop != null && tops.any((t) => t != currentTop));
    // Narrows: the ranking is not separable now, but under some answer it is.
    final narrows =
        withinNow &&
        e.value.any((o) => o.gap >= ModelConstants.rotationUncertainty);
    if (!changes && !narrows) {
      continue; // ask only if the answer changes or narrows the result
    }
    final spread = sens.firstWhere((s) => s.input == e.key).spread;
    final score = tops.length * 100 + spread;
    if (score > bestScore) {
      bestScore = score;
      best = DetectiveQuestion(e.key, e.value);
    }
  }
  return DetectiveResult(best, sens);
}
