/// Model constants. Every unsourced value is TODO(source) and listed in docs/OPEN_ITEMS.md.
class ModelConstants {
  /// TODO(source): confirm effective-rain share.
  static const effectiveRain = 0.65;

  /// TODO(source): m3/ha stored/irrigation baseline.
  static const baselineQ = 2400.0;

  /// TODO(source): share of the crop need actually required (0.8 in the spec).
  static const needFactor = 0.8;
  static const legumeNeedFactor = 0.9;

  /// TODO(source): non-climate failure (pests, market...).
  static const nonClimateFailure = 0.03;

  static const simulations = 1000;
  static const seasonsPerFuture = 3;
  static const seed = 42;
  static const missingPieceGap = 0.05;

  /// TODO(source): aquifer scenario parameters.
  static const aquiferV = 3.0; // m / year
  static const aquiferA = 0.30;
}

/// Voice backends come from --dart-define, never from code.
class Env {
  static const ttsUrl = String.fromEnvironment('SAMA_TTS_URL');
  static const hfToken = String.fromEnvironment('HF_TOKEN');
  static const hfModel = String.fromEnvironment('HF_MODEL');
}

const dataYears = '1984–2024';
const seasonCount = 40;
const firstSeasonYear = 1984;

/// Morocco keeps UTC+1 all year (TODO(source): confirm for sunrise display).
const moroccoUtcOffset = 1.0;
