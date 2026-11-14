import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/water_balance.dart';
import 'settings.dart';

class FarmState {
  const FarmState({
    this.townId = 'boufakrane',
    this.soil = SoilDepth.medium,
    this.previousLegume = false,
    this.areaHa = 1,
  });

  final String townId;
  final SoilDepth soil;
  final bool previousLegume;
  final int areaHa;

  FarmState copyWith({
    String? townId,
    SoilDepth? soil,
    bool? previousLegume,
    int? areaHa,
  }) => FarmState(
    townId: townId ?? this.townId,
    soil: soil ?? this.soil,
    previousLegume: previousLegume ?? this.previousLegume,
    areaHa: areaHa ?? this.areaHa,
  );
}

class FarmNotifier extends Notifier<FarmState> {
  @override
  FarmState build() {
    final p = ref.watch(prefsProvider);
    return FarmState(
      townId: p.getString('town') ?? 'boufakrane',
      soil: SoilDepth.values.firstWhere(
        (s) => s.name == p.getString('soil'),
        orElse: () => SoilDepth.medium,
      ),
      previousLegume: p.getBool('prevLegume') ?? false,
      areaHa: p.getInt('areaHa') ?? 1,
    );
  }

  void update({
    String? townId,
    SoilDepth? soil,
    bool? previousLegume,
    int? areaHa,
  }) {
    final p = ref.read(prefsProvider);
    state = state.copyWith(
      townId: townId,
      soil: soil,
      previousLegume: previousLegume,
      areaHa: areaHa,
    );
    p.setString('town', state.townId);
    p.setString('soil', state.soil.name);
    p.setBool('prevLegume', state.previousLegume);
    p.setInt('areaHa', state.areaHa);
  }
}

final farmProvider = NotifierProvider<FarmNotifier, FarmState>(
  FarmNotifier.new,
);
