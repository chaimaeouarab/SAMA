import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../data/bundled_data_loader.dart';
import '../data/crops_catalog.dart';
import '../data/nasa_power_repository.dart';
import '../domain/plans.dart';
import 'farm_state.dart';

/// Everything derived from the bundled data and the farmer's field.
class FieldModel {
  FieldModel(this.data, this.climate, this.ctx, this.chances);
  final AppData data;
  final TownClimate climate;
  final FieldContext ctx;

  /// Chance of a good season per annual crop id.
  final Map<String, double> chances;

  CropCatalog get catalog => data.catalog;

  /// Annual crops, best chance first, then alphabetical by id.
  List<Crop> get rankedAnnuals {
    final l = catalog.annuals;
    l.sort((a, b) {
      final d = chances[b.id]!.compareTo(chances[a.id]!);
      return d != 0 ? d : a.id.compareTo(b.id);
    });
    return l;
  }
}

final fieldModelProvider = FutureProvider<FieldModel>((ref) async {
  final data = await ref.watch(appDataProvider.future);
  final farm = ref.watch(farmProvider);
  final climate = data.power.town(farm.townId);
  final ctx = FieldContext(
    rains: climate.seasonRains,
    soil: farm.soil,
    previousLegume: farm.previousLegume,
  );
  final chances = {
    for (final c in data.catalog.annuals) c.id: chanceOf(c, ctx),
  };
  return FieldModel(data, climate, ctx, chances);
});

final onlineProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  yield !(await c.checkConnectivity()).contains(ConnectivityResult.none);
  yield* c.onConnectivityChanged.map(
    (r) => !r.contains(ConnectivityResult.none),
  );
});
