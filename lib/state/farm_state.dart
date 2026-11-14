import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/places.dart';
import '../domain/crop_model.dart';
import 'assumptions.dart';
import 'settings.dart';

enum SoilClass { shallow, medium, deep }

enum IrrigationClass { none, limited, moderate, available }

/// How the location was chosen.
enum LocationSource { gps, search, map, preset }

/// One farm. Location + the inputs that change the water balance.
/// Unknown inputs stay "unknown" (flags below) so the Detective can ask about them.
class Farm {
  const Farm({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.source,
    this.soil = SoilClass.medium,
    this.soilKnown = false,
    this.irrigation = IrrigationClass.none,
    this.irrigationKnown = false,
    this.previousFamily,
    this.previousKnown = false,
    this.areaHa = 1,
    this.approxConfirmed = false,
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
  final LocationSource source;
  final SoilClass soil;
  final bool soilKnown;

  /// Default = rainfed, unless the farmer says otherwise.
  final IrrigationClass irrigation;
  final bool irrigationKnown;
  final String? previousFamily;
  final bool previousKnown;
  final int areaHa;

  /// The farmer accepted approximate regional data (nearest reference) for this farm.
  final bool approxConfirmed;

  Farm copyWith({
    String? name,
    double? lat,
    double? lon,
    LocationSource? source,
    SoilClass? soil,
    bool? soilKnown,
    IrrigationClass? irrigation,
    bool? irrigationKnown,
    String? previousFamily,
    bool clearPrevious = false,
    bool? previousKnown,
    int? areaHa,
    bool? approxConfirmed,
  }) => Farm(
    id: id,
    name: name ?? this.name,
    lat: lat ?? this.lat,
    lon: lon ?? this.lon,
    source: source ?? this.source,
    soil: soil ?? this.soil,
    soilKnown: soilKnown ?? this.soilKnown,
    irrigation: irrigation ?? this.irrigation,
    irrigationKnown: irrigationKnown ?? this.irrigationKnown,
    previousFamily: clearPrevious
        ? null
        : (previousFamily ?? this.previousFamily),
    previousKnown: previousKnown ?? this.previousKnown,
    areaHa: areaHa ?? this.areaHa,
    approxConfirmed: approxConfirmed ?? this.approxConfirmed,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lat': lat,
    'lon': lon,
    'source': source.name,
    'soil': soil.name,
    'soilKnown': soilKnown,
    'irrigation': irrigation.name,
    'irrigationKnown': irrigationKnown,
    'previousFamily': previousFamily,
    'previousKnown': previousKnown,
    'areaHa': areaHa,
    'approxConfirmed': approxConfirmed,
  };

  factory Farm.fromJson(Map<String, dynamic> j) => Farm(
    id: j['id'] as String,
    name: j['name'] as String,
    lat: (j['lat'] as num).toDouble(),
    lon: (j['lon'] as num).toDouble(),
    source: LocationSource.values.firstWhere(
      (s) => s.name == j['source'],
      orElse: () => LocationSource.preset,
    ),
    soil: SoilClass.values.firstWhere(
      (s) => s.name == j['soil'],
      orElse: () => SoilClass.medium,
    ),
    soilKnown: j['soilKnown'] as bool? ?? false,
    irrigation: IrrigationClass.values.firstWhere(
      (s) => s.name == j['irrigation'],
      orElse: () => IrrigationClass.none,
    ),
    irrigationKnown: j['irrigationKnown'] as bool? ?? false,
    previousFamily: j['previousFamily'] as String?,
    previousKnown: j['previousKnown'] as bool? ?? false,
    areaHa: (j['areaHa'] as num?)?.toInt() ?? 1,
    approxConfirmed: j['approxConfirmed'] as bool? ?? false,
  );

  FarmParams params(Assumptions a) => FarmParams(
    soilDepthM: a.soilDepth(soil),
    irrigationMm: a.irrigationMm(irrigation),
    tawPerM: a.tawPerM,
  );
}

class FarmsState {
  const FarmsState(this.farms, this.currentId);
  final List<Farm> farms;
  final String currentId;
  Farm get current =>
      farms.firstWhere((f) => f.id == currentId, orElse: () => farms.first);
}

Farm defaultFarm() {
  final p = placeById('boufakrane');
  return Farm(
    id: 'farm1',
    name: p.en,
    lat: p.lat,
    lon: p.lon,
    source: LocationSource.preset,
  );
}

/// Several farms (Advisor mode); Farmer mode uses one. Persisted in shared_preferences:
/// `farm.lat`, `farm.lon`, `farm.name`, `farm.source` always describe the CURRENT farm; the whole list is in `farms`.
class FarmsNotifier extends Notifier<FarmsState> {
  @override
  FarmsState build() {
    final p = ref.watch(prefsProvider);
    final raw = p.getString('farms');
    if (raw != null) {
      try {
        final list = [
          for (final j in jsonDecode(raw) as List)
            Farm.fromJson(j as Map<String, dynamic>),
        ];
        if (list.isNotEmpty) {
          return FarmsState(list, p.getString('farm.current') ?? list.first.id);
        }
      } on Object {
        // corrupt data: fall through to the default farm
      }
    }
    // Migrate Phase 1: a single `town` key.
    final town = p.getString('town');
    if (town != null) {
      final pl = placeById(town);
      final f = Farm(
        id: 'farm1',
        name: pl.en,
        lat: pl.lat,
        lon: pl.lon,
        source: LocationSource.preset,
        areaHa: p.getInt('areaHa') ?? 1,
      );
      return FarmsState([f], f.id);
    }
    final f = defaultFarm();
    return FarmsState([f], f.id);
  }

  void _save(FarmsState s) {
    state = s;
    final p = ref.read(prefsProvider);
    p.setString('farms', jsonEncode([for (final f in s.farms) f.toJson()]));
    p.setString('farm.current', s.currentId);
    final c = s.current;
    p.setDouble('farm.lat', c.lat);
    p.setDouble('farm.lon', c.lon);
    p.setString('farm.name', c.name);
    p.setString('farm.source', c.source.name);
  }

  void update(Farm Function(Farm) change) {
    final cur = state.current;
    final next = change(cur);
    _save(
      FarmsState([
        for (final f in state.farms) f.id == cur.id ? next : f,
      ], state.currentId),
    );
  }

  /// Advisor mode: add a farm and select it.
  String add(Farm f) {
    final id = 'farm${DateTime.now().microsecondsSinceEpoch}';
    final nf = Farm(
      id: id,
      name: f.name,
      lat: f.lat,
      lon: f.lon,
      source: f.source,
      soil: f.soil,
      soilKnown: f.soilKnown,
      irrigation: f.irrigation,
      irrigationKnown: f.irrigationKnown,
      previousFamily: f.previousFamily,
      previousKnown: f.previousKnown,
      areaHa: f.areaHa,
      approxConfirmed: f.approxConfirmed,
    );
    _save(FarmsState([...state.farms, nf], id));
    return id;
  }

  void select(String id) => _save(FarmsState(state.farms, id));

  void remove(String id) {
    if (state.farms.length <= 1) return;
    final left = state.farms.where((f) => f.id != id).toList();
    _save(
      FarmsState(left, state.currentId == id ? left.first.id : state.currentId),
    );
  }
}

final farmsProvider = NotifierProvider<FarmsNotifier, FarmsState>(
  FarmsNotifier.new,
);

/// The farm everything is computed for. Changing it recomputes every provider that depends on it.
final farmProvider = Provider<Farm>((ref) => ref.watch(farmsProvider).current);
