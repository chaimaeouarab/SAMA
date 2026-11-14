import '../core/constants.dart';
import '../data/crops_catalog.dart';
import 'monte_carlo.dart';
import 'outcome_matrix.dart';

/// Rotation rules come from assets/data/rotation_rules.json. They only raise visible flags:
/// no yield number is changed by a rule without a source.
class RotationRules {
  const RotationRules({
    required this.strongAvoid,
    required this.sameFamilyReason,
  });
  final List<({String family, String after})> strongAvoid;
  final String sameFamilyReason;

  factory RotationRules.fromJson(Map<String, dynamic> j) => RotationRules(
    strongAvoid: [
      for (final r in (j['strongAvoid'] as List))
        (family: (r as Map)['family'] as String, after: r['after'] as String),
    ],
    sameFamilyReason: (j['sameFamilyFlag'] as Map)['reason'] as String,
  );

  static const empty = RotationRules(strongAvoid: [], sameFamilyReason: '');
}

enum FlagKind { sameFamily, strongAvoid }

class RotationFlag {
  const RotationFlag(this.position, this.kind, this.family);

  /// 0-based season position where the problem appears.
  final int position;
  final FlagKind kind;
  final String family;
}

/// Flags for a sequence. [previousFamily] is the family of the crop grown before season 1 (may be null = unknown).
List<RotationFlag> rotationFlags(
  List<Crop> seq,
  RotationRules rules, {
  String? previousFamily,
}) {
  final flags = <RotationFlag>[];
  for (var i = 0; i < seq.length; i++) {
    final prev = i == 0 ? previousFamily : seq[i - 1].family;
    if (prev == null) continue;
    final fam = seq[i].family;
    if (prev == fam) {
      final strong = rules.strongAvoid.any(
        (r) => r.family == fam && r.after == prev,
      );
      flags.add(
        RotationFlag(
          i,
          strong ? FlagKind.strongAvoid : FlagKind.sameFamily,
          fam,
        ),
      );
    }
  }
  return flags;
}

class Rotation {
  const Rotation(this.id, this.crops, this.result, this.flags);

  /// 'A' repeat, 'B' best legume rotation, 'C' diversified.
  final String id;
  final List<Crop> crops;

  /// Null when it cannot be evaluated (a crop without documented Ky).
  final RotationResult? result;
  final List<RotationFlag> flags;
}

/// Three rotations for the starting crop [selected] (season 1), chosen by rules and ranked by the model:
/// A repeats the crop; B is the best sequence with at least one legume and no flag; C is the best with three families.
List<Rotation> buildRotations({
  required Crop selected,
  required CropCatalog catalog,
  required OutcomeMatrix matrix,
  required List<List<int>> futures,
  required RotationRules rules,
  String? previousFamily,
  double threshold = ModelConstants.goodYieldThreshold,
}) {
  RotationResult? eval(List<Crop> s) => evaluateRotation(
    cropIds: [for (final c in s) c.id],
    matrix: matrix,
    futures: futures,
    threshold: threshold,
  );

  final a = [selected, selected, selected];
  final out = <Rotation>[
    Rotation(
      'A',
      a,
      eval(a),
      rotationFlags(a, rules, previousFamily: previousFamily),
    ),
  ];

  final pool = catalog.eligible;
  Rotation? best(String id, bool Function(List<Crop>) ok) {
    List<Crop>? bestSeq;
    RotationResult? bestRes;
    if (selected.eligible) {
      for (final x in pool) {
        for (final y in pool) {
          final s = [selected, x, y];
          if (!ok(s) ||
              rotationFlags(
                s,
                rules,
                previousFamily: previousFamily,
              ).isNotEmpty) {
            continue;
          }
          final r = eval(s);
          if (r == null) continue;
          if (bestRes == null || compareRotations(r, bestRes) < 0) {
            bestRes = r;
            bestSeq = s;
          }
        }
      }
    }
    if (bestSeq == null) return null;
    return Rotation(id, bestSeq, bestRes, const []);
  }

  final b = best('B', (s) => s.any((c) => c.legume));
  final c = best('C', (s) => s.map((c) => c.family).toSet().length == 3);
  out.add(b ?? Rotation('B', [selected, selected, selected], null, const []));
  out.add(c ?? Rotation('C', [selected, selected, selected], null, const []));
  return out;
}

/// Evaluated rotations ranked best first. Ties keep A, B, C order.
List<Rotation> rankRotations(List<Rotation> rs) {
  final ok = rs.where((r) => r.result != null).toList();
  final idx = {for (var i = 0; i < ok.length; i++) ok[i]: i};
  ok.sort((x, y) {
    final d = compareRotations(x.result!, y.result!);
    return d != 0 ? d : idx[x]!.compareTo(idx[y]!);
  });
  return ok;
}

/// True when the top two rotations are within the model's uncertainty (so the ranking is not reliable).
bool topTwoWithinUncertainty(List<Rotation> ranked) {
  if (ranked.length < 2) return false;
  return (ranked[0].result!.pAllGood - ranked[1].result!.pAllGood).abs() <
      ModelConstants.rotationUncertainty;
}
