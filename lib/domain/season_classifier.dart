import 'water_balance.dart';

/// Classify each historical season (climate only) for a crop and field.
/// Index 0 = season 1984-85. True = good.
List<bool> classifySeasons(
  List<double> seasonRains,
  double baseNeed,
  SoilDepth soil, {
  required bool previousLegume,
}) => [
  for (final p in seasonRains)
    climateGood(p, baseNeed, soil, previousLegume: previousLegume),
];

String seasonLabel(int index, {int firstYear = 1984}) {
  final y = firstYear + index;
  return '$y–${(y + 1) % 100 < 10 ? '0' : ''}${(y + 1) % 100}';
}
