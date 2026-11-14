import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sama/core/strings.dart';
import 'package:sama/data/climate_repository.dart';
import 'package:sama/data/nasa_client.dart';
import 'package:sama/data/nasa_power_repository.dart';
import 'package:sama/data/places.dart';
import 'package:sama/state/farm_state.dart';
import 'package:sama/state/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

late PowerData power;

Map<String, dynamic> fakeNasaResponse({
  double lat = 33.9,
  double lon = -5.4,
  bool withMissing = false,
}) {
  // Two years are enough to exercise the builder; the app requests 1984-2024.
  Map<String, dynamic> param(double Function(DateTime) f) {
    final m = <String, dynamic>{};
    var d = DateTime.utc(1984, 1, 1);
    while (d.year <= 2024) {
      final k =
          '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
      m[k] = f(d);
      d = d.add(const Duration(days: 1));
    }
    return m;
  }

  final rain = param((d) => d.day == 1 ? 5.0 : 0.0);
  if (withMissing) rain['19841005'] = -999;
  return {
    'geometry': {
      'coordinates': [lon, lat, 512.5],
    },
    'properties': {
      'parameter': {
        'PRECTOTCORR': rain,
        'T2M': param((_) => 18.0),
        'T2M_MAX': param((_) => 25.0),
        'T2M_MIN': param((_) => 11.0),
        'RH2M': param((_) => 55.0),
        'WS2M': param((_) => 2.0),
        'PS': param((_) => 95.0),
        'ALLSKY_SFC_SW_DWN': param((_) => 18.0),
      },
    },
  };
}

void main() {
  setUpAll(() {
    power = PowerData.fromJson(
      jsonDecode(File('assets/data/nasa_power.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });

  group('coordinates and cache key', () {
    test('rounding to 2 decimals (about 1 km) is what is sent and what keys the cache', () {
      expect(round2(33.7249), 33.72);
      expect(round2(-5.305), anyOf(-5.31, -5.3));
      expect(cacheKey(33.7249, -5.2951), '33.72_-5.30');
      expect(
        cacheKey(33.724, -5.296),
        cacheKey(33.7249, -5.2951),
      ); // same ~1 km cell, same cache entry
      expect(cacheKey(33.73, -5.30), isNot(cacheKey(33.72, -5.30)));
    });
    test('Morocco box and distances', () {
      expect(insideMorocco(33.9, -5.4), isTrue);
      expect(insideMorocco(48.85, 2.35), isFalse);
      expect(distanceKm(33.72, -5.30, 33.72, -5.30), 0);
      expect(distanceKm(33.89, -5.55, 30.35, -9.57), closeTo(520, 30));
    });
  });

  group('NASA grid cell (0.5 x 0.625 degrees, derived because the API echoes the request)', () {
    test('cell centres', () {
      expect(gridCell(33.89, -5.55), (lat: 34.0, lon: -5.625));
      expect(gridCell(33.72, -5.30), (lat: 33.5, lon: -5.0));
      expect(gridCell(30.35, -9.57), (lat: 30.5, lon: -9.375));
    });
    test('the derivation predicts which bundled points have identical data (all 105 pairs)', () {
      final ids = power.points.keys.toList();
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          final a = power.town(ids[i]), b = power.town(ids[j]);
          final sameCell = gridCell(a.lat, a.lon) == gridCell(b.lat, b.lon);
          final sameData = a.seasonRains.toString() == b.seasonRains.toString();
          expect(sameCell, sameData, reason: '${ids[i]} vs ${ids[j]}');
        }
      }
    });
    test('cellText is what the farmer sees', () {
      expect(power.town('meknes').cellText, '34.000, -5.625');
    });
  });

  group('gazetteer', () {
    test('nearest place with its distance', () {
      final n = nearestPlace(33.70, -5.31);
      expect(n.place.id, 'boufakrane');
      expect(n.km, lessThan(5));
      expect(nearestPlace(35.5, -6.0).km, greaterThan(40));
    });
    test('search in four scripts, accents ignored, never invents names', () {
      expect(searchPlaces('meknes').map((p) => p.id), contains('meknes'));
      expect(searchPlaces('Meknès').map((p) => p.id), contains('meknes'));
      expect(searchPlaces('مكناس').map((p) => p.id), contains('meknes'));
      expect(searchPlaces('azrou'), isEmpty);
      expect(searchPlaces('   '), isEmpty);
      expect(
        searchPlaces('gharb').length,
        greaterThanOrEqualTo(2),
      ); // by region
    });
  });

  group('dataset selection: exact cache > bundled exact > nearest reference (labelled)', () {
    test('bundled exact point', () {
      final r = selectDataset(lat: 33.72, lon: -5.30, bundled: power);
      expect(r.kind, ClimateKind.bundledExact);
      expect(r.approximate, isFalse);
      expect(r.referenceName, 'boufakrane');
    });
    test('cache wins over the bundled point', () {
      final cached = power.town('erfoud');
      final r = selectDataset(
        lat: 33.72,
        lon: -5.30,
        bundled: power,
        cached: cached,
      );
      expect(r.kind, ClimateKind.exactCache);
      expect(r.climate, same(cached));
    });
    test('anything else: nearest reference, with distance, flagged approximate (never silent)', () {
      final r = selectDataset(lat: 34.0, lon: -4.0, bundled: power);
      expect(r.kind, ClimateKind.nearestReference);
      expect(r.approximate, isTrue);
      expect(r.distanceKm, greaterThan(0));
      expect(r.referenceName, isNotNull);
    });
    test('offline with no cache still answers (approximate), anywhere in the world', () {
      final r = selectDataset(lat: 48.85, lon: 2.35, bundled: power);
      expect(r.approximate, isTrue);
      expect(r.distanceKm, greaterThan(1000));
    });
  });

  group('NASA response -> dataset (offline fallback and -999)', () {
    test('builds seasons, grid cell and elevation from a POWER response', () {
      final j = buildPointJson(fakeNasaResponse(), 33.9, -5.4, '2026-11-14');
      final t = TownClimate.fromJson('x', j);
      expect(t.seasons.length, 40);
      expect(t.srcLat, 33.9);
      expect(t.srcLon, -5.4);
      expect(t.elev, 512.5);
      expect(t.fetched, '2026-11-14');
      expect(t.missingShare, 0);
      expect(t.seasons.first.tmax.first, 25.0);
      expect(t.seasons.first.startYear, 1984);
      expect(t.climToday('T2M', DateTime(2025, 7, 1)), 18.0);
      expect(t.seasons.first.days, 365); // Oct 1984 -> Sep 1985 has no Feb 29
      expect(t.seasons[3].days, 366); // 1987-88 contains Feb 29, 1988
    }, skip: false);
    test('-999 is missing, counted, never averaged in', () {
      final j = buildPointJson(
        fakeNasaResponse(withMissing: true),
        33.9,
        -5.4,
        '2026-11-14',
      );
      final t = TownClimate.fromJson('x', j);
      expect(t.coverage['PRECTOTCORR'], 1);
      expect(t.seasons.first.rain[4], isNull); // Oct 5
      expect(t.missingShare, greaterThan(0));
      expect(t.rain[1984]![TownClimate.slot(DateTime(1984, 10, 5))], -1);
    });
    test('disk cache round trip keyed by rounded coordinates', () async {
      final dir = Directory.systemTemp.createTempSync('sama_cache_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final cache = DatasetCache(dir);
      expect(await cache.read(33.9, -5.4), isNull);
      await cache.write(
        33.9,
        -5.4,
        buildPointJson(fakeNasaResponse(), 33.9, -5.4, '2026-11-14'),
      );
      final back = await cache.read(33.904, -5.396); // same rounded cell
      expect(back, isNotNull);
      expect(back!.seasons.length, 40);
      expect(await cache.read(34.5, -5.4), isNull);
      File('${dir.path}/v2_${cacheKey(10, 10)}.json')
          .writeAsStringSync('not json');
      expect(
        await cache.read(10, 10),
        isNull,
      ); // corrupt file = miss, not a crash
    });
  });

  group('farms: persistence, migration, language migration', () {
    Future<ProviderContainer> container(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      final p = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(p)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('default farm, then coordinates persist under farm.lat / farm.lon / farm.name / farm.source', () async {
      final c = await container({});
      expect(c.read(farmProvider).name, 'Boufakrane');
      c
          .read(farmsProvider.notifier)
          .update(
            (f) => f.copyWith(
              name: 'Ma ferme',
              lat: 33.123,
              lon: -5.456,
              source: LocationSource.map,
            ),
          );
      final p = c.read(prefsProvider);
      expect(p.getDouble('farm.lat'), 33.123);
      expect(p.getDouble('farm.lon'), -5.456);
      expect(p.getString('farm.name'), 'Ma ferme');
      expect(p.getString('farm.source'), 'map');
      // a new container (app restart) reads it back
      final c2 = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(p)],
      );
      addTearDown(c2.dispose);
      expect(c2.read(farmProvider).lat, 33.123);
      expect(c2.read(farmProvider).source, LocationSource.map);
    });

    test('unknown inputs stay unknown until answered', () async {
      final c = await container({});
      final f = c.read(farmProvider);
      expect(f.soilKnown, isFalse);
      expect(f.irrigationKnown, isFalse);
      expect(f.irrigation, IrrigationClass.none); // default = rainfed
      c
          .read(farmsProvider.notifier)
          .update((x) => x.copyWith(soil: SoilClass.deep, soilKnown: true));
      expect(c.read(farmProvider).soilKnown, isTrue);
    });

    test('Phase 1 single-town preference migrates to a farm', () async {
      final c = await container({'town': 'erfoud', 'areaHa': 7});
      final f = c.read(farmProvider);
      expect(f.name, 'Erfoud');
      expect(f.areaHa, 7);
      expect(f.source, LocationSource.preset);
    });

    test(
      'Advisor: several farms, select, remove (never the last one)',
      () async {
        final c = await container({});
        final n = c.read(farmsProvider.notifier);
        final id = n.add(
          const Farm(
            id: 'x',
            name: 'B',
            lat: 34.26,
            lon: -6.58,
            source: LocationSource.search,
          ),
        );
        expect(c.read(farmsProvider).farms.length, 2);
        expect(c.read(farmProvider).name, 'B');
        n.select('farm1');
        expect(c.read(farmProvider).name, 'Boufakrane');
        n.remove(id);
        n.remove('farm1');
        expect(c.read(farmsProvider).farms.length, 1);
      },
    );

    test('previous builds stored `ar` meaning Darija: migrated to `dar` exactly once', () async {
      final c = await container({'lang': 'ar'});
      expect(c.read(settingsProvider).lang, AppLang.dar);
      expect(c.read(prefsProvider).getString('lang'), 'dar');
      // the user later picks real Arabic: it must not be migrated again
      c.read(settingsProvider.notifier).setLang(AppLang.ar);
      final p = c.read(prefsProvider);
      final c2 = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(p)],
      );
      addTearDown(c2.dispose);
      expect(c2.read(settingsProvider).lang, AppLang.ar);
    });

    test('other languages are left alone by the migration', () async {
      final c = await container({'lang': 'fr'});
      expect(c.read(settingsProvider).lang, AppLang.fr);
    });
  });

  group('strings', () {
    test('every UI string has all four languages, and Darija differs from Arabic somewhere', () {
      var differs = 0;
      for (final k in allStringKeys) {
        final v = rawString(k)!;
        expect(v.length, 4, reason: k);
        expect(v.every((s) => s.trim().isNotEmpty), isTrue, reason: k);
        if (v[0] != v[1]) differs++;
      }
      expect(differs, greaterThan(allStringKeys.length ~/ 2));
    });
    test('every key used in lib/ exists', () {
      final used = <String>{};
      final re = RegExp(
        r"""\bt\('([a-zA-Z0-9_]+)'\)|tr\('([a-zA-Z0-9_]+)'|trf\('([a-zA-Z0-9_]+)'""",
      );
      for (final f
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        for (final m in re.allMatches(f.readAsStringSync())) {
          used.add(m.group(1) ?? m.group(2) ?? m.group(3)!);
        }
      }
      final missing = used.where((k) => rawString(k) == null).toList();
      expect(missing, isEmpty);
    });
    test('dynamic key families exist (soil_*, irr_*, fam_*, sc_*, rot_*, c_*, cd_*)', () {
      for (final k in [
        for (final s in ['shallow', 'medium', 'deep']) 'soil_$s',
        for (final s in ['none', 'limited', 'moderate', 'available']) 'irr_$s',
        for (final s in ['Poaceae', 'Fabaceae', 'Solanaceae', 'other'])
          'fam_$s',
        for (final s in ['favorable', 'dry', 'veryDry']) 'sc_$s',
        for (final s in ['A', 'B', 'C', 'custom']) 'rot_$s',
        for (final s in [
          'all',
          'cereal',
          'legume',
          'veg',
          'industrial',
          'tree',
        ])
          'c_$s',
        for (final s in ['cereal', 'legume', 'veg', 'industrial', 'tree'])
          'cd_$s',
        for (final s in ['crop', 'water', 'timing', 'risk']) 'g_$s',
      ]) {
        expect(rawString(k), isNotNull, reason: k);
      }
    });
    test('trf fills placeholders in order', () {
      expect(
        trf('sum_template', AppLang.en, [7, 85]),
        'In 7 futures out of 10 all three seasons are good. Expected yield 85%.',
      );
      expect(
        trf('grid_note', AppLang.en, ['33.7, -5.3']),
        contains('33.7, -5.3'),
      );
    });
  });
}
