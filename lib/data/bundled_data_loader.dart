import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/rotation.dart';
import 'crops_catalog.dart';
import 'nasa_power_repository.dart';

/// Everything the core advice needs, read from bundled assets (works offline).
class AppData {
  AppData(this.power, this.catalog, this.rules);
  final PowerData power;
  final CropCatalog catalog;
  final RotationRules rules;
}

PowerData _parsePower(String raw) =>
    PowerData.fromJson(jsonDecode(raw) as Map<String, dynamic>);

/// The 5 MB NASA file is parsed in a separate isolate so the UI never freezes.
Future<AppData> loadBundledData(
  AssetBundle bundle, {
  bool useIsolate = true,
}) async {
  final raw = await bundle.loadString('assets/data/nasa_power.json');
  final power = useIsolate ? await compute(_parsePower, raw) : _parsePower(raw);
  final crops =
      jsonDecode(await bundle.loadString('assets/data/crops.json')) as List;
  final rules = jsonDecode(
    await bundle.loadString('assets/data/rotation_rules.json'),
  ) as Map<String, dynamic>;
  return AppData(
    power,
    CropCatalog([
      for (final c in crops) Crop.fromJson(c as Map<String, dynamic>),
    ]),
    RotationRules.fromJson(rules),
  );
}

final appDataProvider = FutureProvider<AppData>(
  (ref) => loadBundledData(rootBundle),
);
