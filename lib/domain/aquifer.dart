import '../core/constants.dart';

/// Scenario only, never a measurement: dh = -v * (1 - a * s) * t
/// [saving] s in 0..1, [years] t. Result in metres (negative = water table drops).
double aquiferChange({
  required double saving,
  required double years,
  double v = ModelConstants.aquiferV,
  double a = ModelConstants.aquiferA,
}) => -v * (1 - a * saving) * years;
