import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'crops_catalog.dart';
import 'nasa_power_repository.dart';

/// Everything the core advice needs, read from bundled assets (works offline).
class AppData {
  AppData(this.power, this.catalog);
  final PowerData power;
  final CropCatalog catalog;
}

Future<AppData> loadBundledData(AssetBundle bundle) async {
  final power = jsonDecode(
    await bundle.loadString('assets/data/sais_power.json'),
  ) as Map<String, dynamic>;
  final crops =
      jsonDecode(await bundle.loadString('assets/data/crops.json')) as List;
  return AppData(
    PowerData.fromJson(power),
    CropCatalog([
      for (final c in crops) Crop.fromJson(c as Map<String, dynamic>),
    ]),
  );
}

final appDataProvider = FutureProvider<AppData>(
  (ref) => loadBundledData(rootBundle),
);
