import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import 'farm_state.dart';
import 'settings.dart';

/// Editable model assumptions (Advisor mode). Defaults come from ModelConstants (docs/SOURCES.md).
class Assumptions {
  const Assumptions({
    this.goodThreshold = ModelConstants.goodYieldThreshold,
    this.tawPerM = ModelConstants.tawPerMetre,
    this.shallowM = ModelConstants.shallowDepth,
    this.mediumM = ModelConstants.mediumDepth,
    this.deepM = ModelConstants.deepDepth,
    this.irrLimited = ModelConstants.irrigationLimited,
    this.irrModerate = ModelConstants.irrigationModerate,
    this.irrAvailable = ModelConstants.irrigationAvailable,
  });

  final double goodThreshold;
  final double tawPerM;
  final double shallowM, mediumM, deepM;
  final double irrLimited, irrModerate, irrAvailable;

  double soilDepth(SoilClass s) => switch (s) {
    SoilClass.shallow => shallowM,
    SoilClass.medium => mediumM,
    SoilClass.deep => deepM,
  };

  double irrigationMm(IrrigationClass i) => switch (i) {
    IrrigationClass.none => 0,
    IrrigationClass.limited => irrLimited,
    IrrigationClass.moderate => irrModerate,
    IrrigationClass.available => irrAvailable,
  };

  bool get isDefault => this == const Assumptions();

  @override
  bool operator ==(Object other) =>
      other is Assumptions &&
      other.goodThreshold == goodThreshold &&
      other.tawPerM == tawPerM &&
      other.shallowM == shallowM &&
      other.mediumM == mediumM &&
      other.deepM == deepM &&
      other.irrLimited == irrLimited &&
      other.irrModerate == irrModerate &&
      other.irrAvailable == irrAvailable;

  @override
  int get hashCode => Object.hash(
    goodThreshold,
    tawPerM,
    shallowM,
    mediumM,
    deepM,
    irrLimited,
    irrModerate,
    irrAvailable,
  );

  Assumptions copyWith({
    double? goodThreshold,
    double? tawPerM,
    double? shallowM,
    double? mediumM,
    double? deepM,
    double? irrLimited,
    double? irrModerate,
    double? irrAvailable,
  }) => Assumptions(
    goodThreshold: goodThreshold ?? this.goodThreshold,
    tawPerM: tawPerM ?? this.tawPerM,
    shallowM: shallowM ?? this.shallowM,
    mediumM: mediumM ?? this.mediumM,
    deepM: deepM ?? this.deepM,
    irrLimited: irrLimited ?? this.irrLimited,
    irrModerate: irrModerate ?? this.irrModerate,
    irrAvailable: irrAvailable ?? this.irrAvailable,
  );
}

class AssumptionsNotifier extends Notifier<Assumptions> {
  static const _keys = [
    'a.thr',
    'a.taw',
    'a.sh',
    'a.me',
    'a.de',
    'a.i1',
    'a.i2',
    'a.i3',
  ];

  @override
  Assumptions build() {
    final p = ref.watch(prefsProvider);
    const d = Assumptions();
    return Assumptions(
      goodThreshold: p.getDouble('a.thr') ?? d.goodThreshold,
      tawPerM: p.getDouble('a.taw') ?? d.tawPerM,
      shallowM: p.getDouble('a.sh') ?? d.shallowM,
      mediumM: p.getDouble('a.me') ?? d.mediumM,
      deepM: p.getDouble('a.de') ?? d.deepM,
      irrLimited: p.getDouble('a.i1') ?? d.irrLimited,
      irrModerate: p.getDouble('a.i2') ?? d.irrModerate,
      irrAvailable: p.getDouble('a.i3') ?? d.irrAvailable,
    );
  }

  void set(Assumptions a) {
    final p = ref.read(prefsProvider);
    final v = [
      a.goodThreshold,
      a.tawPerM,
      a.shallowM,
      a.mediumM,
      a.deepM,
      a.irrLimited,
      a.irrModerate,
      a.irrAvailable,
    ];
    for (var i = 0; i < v.length; i++) {
      p.setDouble(_keys[i], v[i]);
    }
    state = a;
  }

  /// Reset to the documented defaults.
  void reset() {
    final p = ref.read(prefsProvider);
    for (final k in _keys) {
      p.remove(k);
    }
    state = const Assumptions();
  }
}

final assumptionsProvider = NotifierProvider<AssumptionsNotifier, Assumptions>(
  AssumptionsNotifier.new,
);
