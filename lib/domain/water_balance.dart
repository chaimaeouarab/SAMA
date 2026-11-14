import '../core/constants.dart';

enum SoilDepth {
  shallow(0.85),
  medium(1.00),
  deep(1.15);

  const SoilDepth(this.factor);
  final double factor;
}

/// Water available (m3/ha) for a season with [rainMm] of rain.
/// W_avail = 10 * 0.65 * P + Q * f_soil
double waterAvailable(double rainMm, SoilDepth soil) =>
    10 * ModelConstants.effectiveRain * rainMm +
    ModelConstants.baselineQ * soil.factor;

/// Water needed (m3/ha). W_need = B_c * 0.8 * (0.9 if previous crop is a legume).
double waterNeeded(double baseNeed, {required bool previousLegume}) =>
    baseNeed *
    ModelConstants.needFactor *
    (previousLegume ? ModelConstants.legumeNeedFactor : 1.0);

/// Climate-only test, without the random non-climate failure.
bool climateGood(
  double rainMm,
  double baseNeed,
  SoilDepth soil, {
  required bool previousLegume,
}) =>
    waterAvailable(rainMm, soil) >=
    waterNeeded(baseNeed, previousLegume: previousLegume);
