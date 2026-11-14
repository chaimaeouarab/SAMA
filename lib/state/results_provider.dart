import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bundled_data_loader.dart';
import '../data/climate_repository.dart';
import '../data/crops_catalog.dart';
import '../data/nasa_client.dart';
import '../data/nasa_power_repository.dart';
import '../domain/crop_model.dart';
import '../domain/detective.dart';
import '../domain/monte_carlo.dart';
import '../domain/outcome_matrix.dart';
import '../domain/rotation.dart';
import '../domain/scenarios.dart';
import 'assumptions.dart';
import 'farm_state.dart';

/// Runs heavy pure computations off the UI thread. Tests override it with a direct call.
typedef HeavyRunner = Future<T> Function<T>(T Function() job);

final heavyRunnerProvider = Provider<HeavyRunner>(
  (ref) =>
      <T>(T Function() job) => compute<void, T>((_) => job(), null),
);

final datasetCacheProvider = Provider<DatasetCache>((ref) => DatasetCache());
final nasaClientProvider = Provider<NasaClient>((ref) => NasaClient(Dio()));

/// Bumped after a successful download so the climate provider re-reads the cache.
class DatasetVersion extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final datasetVersionProvider = NotifierProvider<DatasetVersion, int>(
  DatasetVersion.new,
);

/// Which dataset answers for the current farm (never substituted silently).
final climateProvider = FutureProvider<ClimateResolution>((ref) async {
  final data = await ref.watch(appDataProvider.future);
  final farm = ref.watch(farmProvider);
  ref.watch(datasetVersionProvider);
  final cached = await ref.read(datasetCacheProvider).read(farm.lat, farm.lon);
  return selectDataset(
    lat: farm.lat,
    lon: farm.lon,
    bundled: data.power,
    cached: cached,
  );
});

/// What-if settings shared by Climate Shock Lab and the model. Hypothetical, never an observation.
class ShockNotifier extends Notifier<Shock> {
  @override
  Shock build() => Shock.none;
  void set(Shock s) => state = s;
  void reset() => state = Shock.none;
}

final shockProvider = NotifierProvider<ShockNotifier, Shock>(ShockNotifier.new);

/// Everything derived from the data and the current farm.
class FieldModel {
  FieldModel({
    required this.data,
    required this.resolution,
    required this.farm,
    required this.assumptions,
    required this.shock,
    required this.matrix,
    required this.futures,
  });

  final AppData data;
  final ClimateResolution resolution;
  final Farm farm;
  final Assumptions assumptions;
  final Shock shock;
  final OutcomeMatrix matrix;
  final List<List<int>> futures;

  TownClimate get climate => resolution.climate;
  CropCatalog get catalog => data.catalog;
  double get threshold => assumptions.goodThreshold;
  FarmParams get params => farm.params(assumptions);
  FarmInputs get inputs => FarmInputs(
    soilDepthM: assumptions.soilDepth(farm.soil),
    irrigationMm: assumptions.irrigationMm(farm.irrigation),
    previousFamily: farm.previousKnown ? farm.previousFamily : null,
    soilKnown: farm.soilKnown,
    irrigationKnown: farm.irrigationKnown,
    previousKnown: farm.previousKnown,
  );

  /// Share of the 40 real seasons that reach the yield threshold. Null: no documented Ky (not recommended).
  double? chance(String cropId) => matrix.chance(cropId, threshold);

  /// Eligible crops, best chance first, then by id.
  List<Crop> get rankedEligible {
    final l = catalog.eligible;
    l.sort((a, b) {
      final d = chance(b.id)!.compareTo(chance(a.id)!);
      return d != 0 ? d : a.id.compareTo(b.id);
    });
    return l;
  }
}

final modelProvider = FutureProvider<FieldModel>((ref) async {
  final data = await ref.watch(appDataProvider.future);
  final resolution = await ref.watch(climateProvider.future);
  final farm = ref.watch(farmProvider);
  final assumptions = ref.watch(assumptionsProvider);
  final shock = ref.watch(shockProvider);
  final params = farm.params(assumptions);
  final catalog = data.catalog;
  final climate = resolution.climate;
  final matrix = await ref.read(heavyRunnerProvider)(
    () => OutcomeMatrix.build(
      crops: catalog.annuals,
      climate: climate,
      farm: params,
      shock: shock,
    ),
  );
  return FieldModel(
    data: data,
    resolution: resolution,
    farm: farm,
    assumptions: assumptions,
    shock: shock,
    matrix: matrix,
    futures: drawFutures(seasonCount: climate.seasons.length),
  );
});

/// The three rotations A/B/C for a starting crop, ranked by the model.
final rotationsProvider = FutureProvider.family<List<Rotation>, String>((
  ref,
  cropId,
) async {
  final m = await ref.watch(modelProvider.future);
  final crop = m.catalog.byId(cropId);
  return ref.read(heavyRunnerProvider)(
    () => buildRotations(
      selected: crop,
      catalog: m.catalog,
      matrix: m.matrix,
      futures: m.futures,
      rules: m.data.rules,
      previousFamily: m.inputs.previousFamily,
      threshold: m.threshold,
    ),
  );
});

final detectiveProvider = FutureProvider.family<DetectiveResult, String>((
  ref,
  cropId,
) async {
  final m = await ref.watch(modelProvider.future);
  final crop = m.catalog.byId(cropId);
  return ref.read(heavyRunnerProvider)(
    () => runDetective(
      selected: crop,
      catalog: m.catalog,
      climate: m.climate,
      rules: m.data.rules,
      inputs: m.inputs,
      futures: m.futures,
      shock: m.shock,
    ),
  );
});

final onlineProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  yield !(await c.checkConnectivity()).contains(ConnectivityResult.none);
  yield* c.onConnectivityChanged.map(
    (r) => !r.contains(ConnectivityResult.none),
  );
});
