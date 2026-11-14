import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sama/data/bundled_data_loader.dart';
import 'package:sama/data/crops_catalog.dart';
import 'package:sama/data/nasa_power_repository.dart';
import 'package:sama/domain/aquifer.dart';
import 'package:sama/domain/missing_piece.dart';
import 'package:sama/domain/monte_carlo.dart';
import 'package:sama/domain/plans.dart';
import 'package:sama/domain/rng.dart';
import 'package:sama/domain/season_classifier.dart';
import 'package:sama/domain/solar.dart';
import 'package:sama/domain/water_balance.dart';

late AppData data;

void main() {
  setUpAll(() async {
    final power = jsonDecode(
      File('assets/data/sais_power.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final crops =
        jsonDecode(File('assets/data/crops.json').readAsStringSync()) as List;
    data = AppData(
      PowerData.fromJson(power),
      CropCatalog([
        for (final c in crops) Crop.fromJson(c as Map<String, dynamic>),
      ]),
    );
  });

  group('water balance', () {
    test('available water formula', () {
      expect(waterAvailable(0, SoilDepth.medium), 2400);
      expect(waterAvailable(100, SoilDepth.deep), closeTo(650 + 2760, 1e-9));
      expect(waterAvailable(100, SoilDepth.shallow), closeTo(650 + 2040, 1e-9));
    });
    test('need drops 10% after a legume', () {
      expect(waterNeeded(4500, previousLegume: false), closeTo(3600, 1e-9));
      expect(waterNeeded(4500, previousLegume: true), closeTo(3240, 1e-9));
    });
    test('boundary: exactly equal counts as good', () {
      // need 3600 -> P = (3600-2400)/6.5
      final p = 1200 / 6.5;
      expect(
        climateGood(p, 4500, SoilDepth.medium, previousLegume: false),
        isTrue,
      );
      expect(
        climateGood(p - 1, 4500, SoilDepth.medium, previousLegume: false),
        isFalse,
      );
    });
  });

  group('data', () {
    test('40 seasons for every town, none missing, -999 never counted', () {
      for (final t in data.power.towns.values) {
        final s = t.seasonRains;
        expect(s.length, 40);
        expect(s.every((v) => v > 0 && v < 2000), isTrue);
      }
    });
    test('missing days (-1) are skipped, not subtracted', () {
      final t = TownClimate(
        lat: 0,
        lon: 0,
        rain: {1984: List.filled(366, -1), 1985: List.filled(366, -1)},
        clim: {},
      );
      t.rain[1984]![300] = 100;
      t.rain[1985]![10] = 50;
      expect(t.seasonRain(1984), 15.0);
    });
    test(
      'classification of all 40 seasons for Boufakrane (wheat, medium soil)',
      () {
        final rains = data.power.town('boufakrane').seasonRains;
        final wheat = data.catalog.byId('softwheat');
        final r = classifySeasons(
          rains,
          wheat.waterNeed!,
          SoilDepth.medium,
          previousLegume: false,
        );
        expect(r.length, 40);
        // need 3600 m3/ha -> good when P >= 184.6 mm
        for (var i = 0; i < 40; i++) {
          expect(r[i], rains[i] >= 1200 / 6.5);
        }
        final maize = classifySeasons(
          rains,
          data.catalog.byId('maize').waterNeed!,
          SoilDepth.medium,
          previousLegume: false,
        );
        expect(
          maize.where((g) => !g).length,
          greaterThan(r.where((g) => !g).length - 1),
        );
      },
    );
    test('day slot is the same in leap and non-leap years and ignores DST', () {
      expect(TownClimate.slot(DateTime(2025, 1, 1)), 0);
      expect(
        TownClimate.slot(DateTime(2025, 3, 1)),
        60,
      ); // Feb 29 keeps slot 59
      expect(TownClimate.slot(DateTime(2024, 3, 1)), 60);
      expect(
        TownClimate.slot(DateTime(2025, 3, 30, 0, 30)),
        TownClimate.slot(DateTime(2025, 3, 30, 15)),
      );
      expect(TownClimate.slot(DateTime(2025, 12, 31)), 365);
      expect(TownClimate.slot(DateTime(2024, 10, 1)), 274);
      expect(TownClimate.slot(DateTime(2025, 10, 1)), 274);
    });
    test('season labels', () {
      expect(seasonLabel(0), '1984–85');
      expect(seasonLabel(15), '1999–00');
      expect(seasonLabel(39), '2023–24');
    });
  });

  group('rng and monte carlo', () {
    test('mulberry32 is deterministic and in [0,1)', () {
      final a = Mulberry32(42), b = Mulberry32(42);
      for (var i = 0; i < 100; i++) {
        final x = a.next();
        expect(x, b.next());
        expect(x >= 0 && x < 1, isTrue);
      }
    });
    test('mulberry32 reference value for seed 42', () {
      expect(Mulberry32(42).next(), closeTo(0.6011037519201636, 1e-12));
    });
    test('same seed gives identical results, different seed differs', () {
      final rains = data.power.town('boufakrane').seasonRains;
      final crop = data.catalog.byId('maize');
      SimResult run(int seed) => simulate(
        sequence: [crop, crop, crop],
        rains: rains,
        soil: SoilDepth.medium,
        previousLegume: false,
        seed: seed,
      );
      expect(run(42).good, run(42).good);
      expect(run(42).good, isNot(run(7).good));
    });
    test('always-good conditions are limited only by the 3% failure', () {
      final rains = List.filled(40, 2000.0);
      final r = simulate(
        sequence: [data.catalog.byId('barley')],
        rains: rains,
        soil: SoilDepth.deep,
        previousLegume: false,
      );
      expect(r.p, closeTo(0.97, 0.02));
    });
    test('no rain and shallow soil is never good for maize', () {
      final r = simulate(
        sequence: [data.catalog.byId('maize')],
        rains: List.filled(40, 0.0),
        soil: SoilDepth.shallow,
        previousLegume: false,
      );
      expect(r.good, 0);
    });
  });

  group('plans', () {
    FieldContext ctx(SoilDepth s) => FieldContext(
      rains: data.power.town('boufakrane').seasonRains,
      soil: s,
      previousLegume: false,
    );

    test('plan shapes A/B/C', () {
      final wheat = data.catalog.byId('softwheat');
      final plans = buildPlans(wheat, data.catalog, ctx(SoilDepth.medium));
      expect(plans.map((p) => p.id), ['A', 'B', 'C']);
      expect(plans[0].crops.every((c) => c.id == 'softwheat'), isTrue);
      expect(plans[1].crops[1].legume, isTrue);
      expect(plans[1].crops[0].id, plans[1].crops[2].id);
      expect(plans[2].crops.map((c) => c.category).toSet().length, 3);
    });
    test('ranking is best first and stable', () {
      final wheat = data.catalog.byId('softwheat');
      final ranked = rankPlans(
        buildPlans(wheat, data.catalog, ctx(SoilDepth.medium)),
      );
      for (var i = 1; i < ranked.length; i++) {
        expect(
          ranked[i - 1].sim.good,
          greaterThanOrEqualTo(ranked[i].sim.good),
        );
      }
    });
    test('plans are deterministic', () {
      final maize = data.catalog.byId('maize');
      final a = buildPlans(
        maize,
        data.catalog,
        ctx(SoilDepth.medium),
      ).map((p) => p.sim.good).toList();
      final b = buildPlans(
        maize,
        data.catalog,
        ctx(SoilDepth.medium),
      ).map((p) => p.sim.good).toList();
      expect(a, b);
    });
    test('missing piece only appears when top two are within 5 points', () {
      final maize = data.catalog.byId('maize');
      final c = ctx(SoilDepth.shallow);
      final plans = buildPlans(maize, data.catalog, c);
      final ranked = rankPlans(plans);
      final gap = ranked[0].sim.p - ranked[1].sim.p;
      final mp = findMissingPiece(maize, data.catalog, c, plans);
      if (gap >= 0.05) {
        expect(mp, isNull);
      } else if (mp != null) {
        expect(mp.outcomes.any((o) => o.topPlanId != ranked.first.id), isTrue);
      }
    });
    test('missing piece is null when plans are far apart', () {
      final maize = data.catalog.byId('maize');
      final c = ctx(SoilDepth.medium);
      const sims = [
        SimResult(900, 1000),
        SimResult(700, 1000),
        SimResult(650, 1000),
      ];
      final plans = [
        for (var i = 0; i < 3; i++)
          Plan('ABC'[i], [maize, maize, maize], sims[i], 0, 0),
      ];
      expect(findMissingPiece(maize, data.catalog, c, plans), isNull);
    });
    test('Erfoud is much drier than Boufakrane', () {
      double avg(String t) {
        final s = data.power.town(t).seasonRains;
        return s.reduce((a, b) => a + b) / s.length;
      }

      expect(avg('erfoud'), lessThan(avg('boufakrane') / 2));
    });
  });

  group('aquifer and sun', () {
    test('aquifer formula', () {
      expect(aquiferChange(saving: 0, years: 10), -30);
      expect(aquiferChange(saving: 1, years: 10), closeTo(-21, 1e-9));
      expect(aquiferChange(saving: 0.5, years: 0), 0);
    });
    test('sunrise before sunset, ~12h of day at the equinox for Meknès', () {
      final s = sunTimes(
        lat: 33.7,
        lon: -5.3,
        date: DateTime(2025, 3, 20),
        utcOffset: 1,
      );
      expect(s.sunrise, lessThan(s.sunset));
      expect((s.sunset - s.sunrise) / 60, closeTo(12.1, 0.3));
      expect(SunTimes.format(s.sunrise).length, 5);
    });
  });
}
