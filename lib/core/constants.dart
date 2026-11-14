/// Model constants. Each one is documented in docs/SOURCES.md with its citation, unit and verification state.
/// Unsourced values are TODO(source) and listed in docs/OPEN_ITEMS.md.
class ModelConstants {
  /// Total available water per metre of soil (mm/m). Loam mid-range.
  /// TODO(source): FAO-56 Table 19 (check theta_FC - theta_WP for the texture).
  static const tawPerMetre = 140.0;

  /// Soil depth classes (m) used by the farmer-facing choice. SAMA classes, editable in Advisor mode.
  /// TODO(source): classes are a SAMA simplification.
  static const shallowDepth = 0.5;
  static const mediumDepth = 1.0;
  static const deepDepth = 1.5;

  /// Soil evaporation coefficient before sowing. TODO(source): FAO-56 chapter 7 (bare soil).
  static const fallowKc = 0.3;

  /// Root-zone depletion at Oct 1 as a share of TAW: dry soil after the summer. TODO(source): assumption.
  static const startDepletionShare = 1.0;

  /// Seasonal irrigation (mm) for each class. TODO(source): SAMA assumptions, editable in Advisor mode.
  static const irrigationNone = 0.0;
  static const irrigationLimited = 100.0;
  static const irrigationModerate = 250.0;
  static const irrigationAvailable = 500.0;

  /// A season is "good" when relative yield >= this (configurable; default 80 %).
  static const goodYieldThreshold = 0.8;
  static const cautionYieldThreshold = 0.5;

  /// What-if shocks. Hypothetical, never presented as NASA observation.
  static const rainDry = 0.8;
  static const rainVeryDry = 0.6;
  static const warmerDeltaC =
      2.0; // TODO(source): illustrative +2 C, not a projection

  /// Scenario seasons are real seasons picked by rainy-season rain percentile.
  static const percentileFavorable = 0.70;
  static const percentileDry = 0.25;
  static const percentileVeryDry = 0.07;

  static const waterloggingNoteMm = 150.0;

  static const simulations = 1000;
  static const seasonsPerFuture = 3;
  static const seed = 42;
  static const rotationUncertainty =
      0.05; // top two rotations closer than this are "not separable"

  /// Aquifer scenario parameters. TODO(source).
  static const aquiferV = 3.0; // m / year
  static const aquiferA = 0.30;
}

/// Voice and map backends come from --dart-define, never from code.
class Env {
  static const ttsUrl = String.fromEnvironment('SAMA_TTS_URL');
  static const hfToken = String.fromEnvironment('HF_TOKEN');
  static const hfModel = String.fromEnvironment('HF_MODEL');

  /// Raster tile URL template for the farm map, e.g. https://tiles.example/{z}/{x}/{y}.png
  static const tileUrl = String.fromEnvironment('SAMA_TILE_URL');
  static const tileAttribution = String.fromEnvironment(
    'SAMA_TILE_ATTRIBUTION',
  );
}

const dataYears = '1984–2024';
const seasonCount = 40;
const firstSeasonYear = 1984;
const userAgent =
    'SAMA-FieldShift/1.0 (NASA Space Apps; contact: set in repo README)';

/// Morocco keeps UTC+1 all year (TODO(source): confirm for sunrise display).
const moroccoUtcOffset = 1.0;
