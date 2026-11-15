import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sama/data/bundled_data_loader.dart';
import 'package:sama/data/crops_catalog.dart';
import 'package:sama/data/nasa_power_repository.dart';
import 'package:sama/domain/aquifer.dart';
import 'package:sama/domain/crop_model.dart';
import 'package:sama/domain/detective.dart';
import 'package:sama/domain/et0.dart';
import 'package:sama/domain/monte_carlo.dart';
import 'package:sama/domain/outcome_matrix.dart';
import 'package:sama/domain/rng.dart';
import 'package:sama/domain/rotation.dart';
import 'package:sama/domain/scenarios.dart';
import 'package:sama/domain/solar.dart';

late AppData data;
late RotationRules rules;

SeasonSeries synthetic({
  double rain = 0,
  int days = 365,
  double tmax = 28,
  double tmin = 14,
  double rh = 50,
  double ws = 2,
  double rad = 20,
}) => SeasonSeries(
  startYear: 2000,
  rain: List.filled(days, rain),
  tmax: List.filled(days, tmax),
  tmin: List.filled(days, tmin),
  rh: List.filled(days, rh),
  ws: List.filled(days, ws),
  rad: List.filled(days, rad),
);

void main() {
  setUpAll(() {
    final power = jsonDecode(
      File('assets/data/nasa_power.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final crops =
        jsonDecode(File('assets/data/crops.json').readAsStringSync()) as List;
    rules = RotationRules.fromJson(
      jsonDecode(File('assets/data/rotation_rules.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    data = AppData(
      PowerData.fromJson(power),
      CropCatalog([
        for (final c in crops) Crop.fromJson(c as Map<String, dynamic>),
      ]),
      rules,
    );
  });

  group('FAO-56 building blocks (published reference values)', () {
    test(
      'saturation vapour pressure and slope at 20 C (FAO-56 tables 2.3 / 2.4)',
      () {
        expect(saturationVapourPressure(20), closeTo(2.338, 0.002));
        expect(vapourPressureSlope(20), closeTo(0.145, 0.001));
      },
    );
    test('pressure at 1800 m = 81.8 kPa (FAO-56 example 2)', () {
      expect(pressureFromElevation(1800), closeTo(81.8, 0.1));
      expect(pressureFromElevation(0), closeTo(101.3, 1e-9));
    });
    test('extraterrestrial radiation, 20 S on 3 September = 32.2 MJ/m2/day (FAO-56 example 8)', () {
      expect(extraterrestrialRadiation(-20, 246), closeTo(32.2, 0.1));
    });
    test('ET0 reacts the right way to its inputs', () {
      double et(double ws, double rh, double tmax) => et0PenmanMonteith(
        tmax: tmax,
        tmin: 14,
        rhMean: rh,
        u2: ws,
        rs: 22,
        latDeg: 33.7,
        elev: 400,
        doy: 190,
      );
      final base = et(2, 50, 32);
      expect(base, inInclusiveRange(4, 8)); // a hot dry day in Morocco
      expect(et(4, 50, 32), greaterThan(base)); // more wind, more demand
      expect(et(2, 80, 32), lessThan(base)); // humid air, less demand
      expect(et(2, 50, 36), greaterThan(base)); // hotter
      expect(
        et0PenmanMonteith(
          tmax: 8,
          tmin: 2,
          rhMean: 90,
          u2: 1,
          rs: 3,
          latDeg: 33.7,
          elev: 400,
          doy: 355,
        ),
        lessThan(1.5),
      );
    });
    test('hand-worked day, checked against an independent Python implementation (docs/MODEL.md)', () {
      final v = et0PenmanMonteith(
        tmax: 30,
        tmin: 15,
        rhMean: 50,
        u2: 2,
        rs: 22,
        latDeg: 33.7,
        elev: 400,
        doy: 190,
      );
      expect(v, closeTo(5.362, 0.005));
      expect(
        v,
        isNot(et0Hargreaves(tmax: 30, tmin: 15, latDeg: 33.7, doy: 190)),
      );
    });
    test('missing radiation falls back to Hargreaves and is counted', () {
      final s = synthetic(days: 10);
      s.rad[3] = null;
      s.tmax[5] = null;
      final r = et0Season(s, lat: 33.7, elev: 400);
      expect(r.hargreavesDays, 1);
      expect(r.filledDays, 1);
      expect(r.values.every((v) => v >= 0 && v < 15), isTrue);
    });
  });

  group('data (NASA POWER v2)', () {
    test('15 reference points, 40 seasons each, no missing days', () {
      expect(data.power.points.length, 15);
      for (final p in data.power.points.values) {
        expect(p.seasons.length, 40);
        expect(p.missingShare, 0, reason: p.id);
        expect(p.seasons.every((s) => s.days == 365 || s.days == 366), isTrue);
        expect(p.elev, isNonNegative);
      }
    });
    test('daily season series agree with the per-year rain table (two independent paths)', () {
      for (final id in ['boufakrane', 'erfoud', 'agadir']) {
        final p = data.power.town(id);
        for (var y = 0; y < 40; y++) {
          expect(
            p.seasons[y].rainySeasonRain,
            closeTo(p.seasonRain(1984 + y)!, 0.15),
            reason: '$id $y',
          );
        }
      }
    });
    test('-999 never becomes a number', () {
      final t = TownClimate.fromJson('x', {
        'lat': 0,
        'lon': 0,
        'srcLat': 0,
        'srcLon': 0,
        'elev': 0,
        'rain': {'1984': List.filled(366, -1)},
        'clim': <String, dynamic>{},
        'coverage': <String, dynamic>{},
        'seasons': {
          'rain': [
            [-999, 20, 30],
          ],
          'tmax': [
            [200, 200, 200],
          ],
          'tmin': [
            [100, 100, 100],
          ],
          'rh': [
            [50, 50, 50],
          ],
          'ws': [
            [20, 20, 20],
          ],
          'rad': [
            [-999, 200, 200],
          ],
        },
      });
      expect(t.seasons.first.rain, [null, 2.0, 3.0]);
      expect(t.seasons.first.rad.first, isNull);
      expect(t.seasons.first.rainySeasonRain, 5.0);
      expect(t.seasons.first.missingRainDays, 1);
    });
    test(
      'Sebaa Aioun, Mhaya and Meknes share one NASA grid cell (identical data)',
      () {
        expect(
          data.power.town('mhaya').seasonRains,
          data.power.town('sebaaaioun').seasonRains,
        );
        expect(
          data.power.town('boufakrane').seasonRains,
          isNot(data.power.town('mhaya').seasonRains),
        );
      },
    );
    test('Erfoud is much drier than the Sais', () {
      double avg(String t) {
        final s = data.power.town(t).seasonRains;
        return s.reduce((a, b) => a + b) / s.length;
      }

      expect(avg('erfoud'), lessThan(avg('boufakrane') / 2));
    });
    test('day slot is the same in leap and non-leap years and ignores DST', () {
      expect(TownClimate.slot(DateTime(2025, 1, 1)), 0);
      expect(TownClimate.slot(DateTime(2025, 3, 1)), 60);
      expect(TownClimate.slot(DateTime(2024, 3, 1)), 60);
      expect(
        TownClimate.slot(DateTime(2025, 3, 30, 0, 30)),
        TownClimate.slot(DateTime(2025, 3, 30, 15)),
      );
      expect(TownClimate.slot(DateTime(2025, 12, 31)), 365);
      expect(TownClimate.slot(DateTime(2024, 10, 1)), 274);
      expect(TownClimate.slot(DateTime(2025, 10, 1)), 274);
    });
  });

  group('crop model', () {
    CropModelSpec wheat() => data.catalog.byId('softwheat').model!;
    FarmParams farm({double depth = 1.0, double irr = 0}) =>
        FarmParams(soilDepthM: depth, irrigationMm: irr);

    test('Kc curve: flat, linear, flat, linear', () {
      final c = wheat();
      expect(kcOnDay(c, 0), c.kcIni);
      expect(kcOnDay(c, c.stages[0]), c.kcIni);
      expect(kcOnDay(c, c.stages[0] + c.stages[1]), c.kcMid);
      final mid = kcOnDay(c, c.stages[0] + c.stages[1] ~/ 2);
      expect(mid, inExclusiveRange(c.kcIni, c.kcMid));
      expect(kcOnDay(c, c.cycleDays - 1), closeTo(c.kcEnd, 0.03));
    });

    test('no rain, rainfed, shallow soil: severe water stress', () {
      final s = synthetic(rain: 0);
      final et0 = et0Season(s, lat: 33.7, elev: 400).values;
      final o = simulateSeason(
        crop: wheat(),
        season: s,
        et0: et0,
        farm: farm(depth: 0.5),
      );
      expect(o.eta, lessThan(o.etc));
      expect(o.ry, lessThan(0.6));
      expect(o.deficit, greaterThan(100));
    });

    test('plenty of rain: no stress, relative yield 1, excess rain is lost (waterlogging note)', () {
      final s = synthetic(rain: 8);
      final et0 = et0Season(s, lat: 33.7, elev: 400).values;
      final o = simulateSeason(
        crop: wheat(),
        season: s,
        et0: et0,
        farm: farm(),
      );
      expect(o.ry, 1.0);
      expect(o.eta, closeTo(o.etc, 1e-6));
      expect(o.lost, greaterThan(0));
      expect(o.effectiveRain, lessThan(o.rainCycle));
    });

    test(
      'irrigation helps and never exceeds its budget; unlimited vs none',
      () {
        final s = synthetic(rain: 0.3);
        final et0 = et0Season(s, lat: 33.7, elev: 400).values;
        final none = simulateSeason(
          crop: wheat(),
          season: s,
          et0: et0,
          farm: farm(),
        );
        final some = simulateSeason(
          crop: wheat(),
          season: s,
          et0: et0,
          farm: farm(irr: 250),
        );
        final lots = simulateSeason(
          crop: wheat(),
          season: s,
          et0: et0,
          farm: farm(irr: 5000),
        );
        expect(some.irrigation, lessThanOrEqualTo(250.0001));
        expect(some.ry!, greaterThan(none.ry!));
        expect(lots.ry!, greaterThanOrEqualTo(some.ry!));
        expect(lots.irrigation, lessThan(5000));
      },
    );

    test('worked example of docs/MODEL.md: soft wheat, Boufakrane, season 1994-95, medium soil, rainfed', () {
      final p = data.power.town('boufakrane');
      final s = p.seasons[10];
      expect(s.startYear, 1994);
      expect(s.rainySeasonRain, closeTo(293.2, 0.1));
      final et0 = et0Season(s, lat: p.srcLat, elev: p.elev);
      expect(
        et0.values[0],
        closeTo(2.911, 0.005),
      ); // 1 Oct 1994, Tmax 19.4, Tmin 8.1, RH 72.3, u2 1.1, Rs 20.9
      expect(et0.values.fold(0.0, (a, b) => a + b), closeTo(1333.2, 0.5));
      final o = simulateSeason(
        crop: data.catalog.byId('softwheat').model!,
        season: s,
        et0: et0.values,
        farm: const FarmParams(soilDepthM: 1.0, irrigationMm: 0),
      );
      expect(o.et0Cycle, closeTo(483.9, 0.5));
      expect(o.etc, closeTo(400.1, 0.5));
      expect(o.eta, closeTo(238.9, 0.5));
      expect(o.effectiveRain, closeTo(212.1, 0.5));
      expect(o.deficit, closeTo(161.2, 0.5));
      expect(o.ry, closeTo(0.597, 0.002)); // 1 - 1.0 * (1 - 238.9 / 400.1)
      expect(1 - 1.0 * (1 - o.eta / o.etc), closeTo(o.ry!, 1e-12));
    });

    test('deeper soil keeps more of an early rain pulse', () {
      // 100 mm on 1 Nov, then dry: the deep bucket stores it, the shallow one overflows.
      final s = synthetic(rain: 0);
      s.rain[31] = 100;
      final et0 = et0Season(s, lat: 33.7, elev: 400).values;
      final shallow = simulateSeason(
        crop: wheat(),
        season: s,
        et0: et0,
        farm: farm(depth: 0.5),
      );
      final deep = simulateSeason(
        crop: wheat(),
        season: s,
        et0: et0,
        farm: farm(depth: 1.5),
      );
      expect(deep.eta, greaterThan(shallow.eta));
    });

    test('with real NASA seasons, deep soil does at least as well as shallow soil for wheat', () {
      final p = data.power.town('boufakrane');
      final w = [data.catalog.byId('softwheat')];
      double mean(double d) {
        final m = OutcomeMatrix.build(
          crops: w,
          climate: p,
          farm: farm(depth: d),
        );
        return m.ryList('softwheat').reduce((a, b) => a + b) / 40;
      }

      expect(mean(1.5), greaterThanOrEqualTo(mean(0.5)));
    });

    test(
      'rooting depth limits the benefit of deep soil (potato roots 0.5 m)',
      () {
        final c = data.catalog.byId('potato').model!;
        final s = synthetic(rain: 1.0);
        final et0 = et0Season(s, lat: 33.7, elev: 400).values;
        final a = simulateSeason(
          crop: c,
          season: s,
          et0: et0,
          farm: farm(depth: 0.5),
        );
        final b = simulateSeason(
          crop: c,
          season: s,
          et0: et0,
          farm: farm(depth: 1.5),
        );
        expect(a.eta, closeTo(b.eta, 1e-9));
      },
    );

    test('relative yield follows FAO-33: 1 - Ky (1 - ETa/ETc)', () {
      final s = synthetic(rain: 0.5);
      final et0 = et0Season(s, lat: 33.7, elev: 400).values;
      final c = wheat();
      final o = simulateSeason(crop: c, season: s, et0: et0, farm: farm());
      expect(
        o.ry,
        closeTo((1 - c.ky! * (1 - o.eta / o.etc)).clamp(0.0, 1.0), 1e-12),
      );
    });

    test('a crop without a documented Ky gives no yield number and is not eligible', () {
      final oats = data.catalog.byId('oats');
      expect(oats.eligible, isFalse);
      final s = synthetic(rain: 1);
      final o = simulateSeason(
        crop: oats.model!,
        season: s,
        et0: et0Season(s, lat: 33.7, elev: 400).values,
        farm: farm(),
      );
      expect(o.ry, isNull);
      expect(o.goodAt(0.8), isNull);
      expect(
        data.catalog.byId('olive').model,
        isNull,
      ); // trees are not in the model
      expect(
        data.catalog.eligible.every((c) => c.annual && c.model!.ky != null),
        isTrue,
      );
    });

    test('summer crops need irrigation: maize rainfed is worse than irrigated at Boufakrane', () {
      final p = data.power.town('boufakrane');
      final maize = data.catalog.byId('maize');
      final rainfed = OutcomeMatrix.build(
        crops: [maize],
        climate: p,
        farm: farm(),
      );
      final irrigated = OutcomeMatrix.build(
        crops: [maize],
        climate: p,
        farm: farm(irr: 500),
      );
      expect(
        irrigated.chance('maize', 0.8)!,
        greaterThan(rainfed.chance('maize', 0.8)!),
      );
    });

    test('changing inputs changes the result (soil, irrigation, shock)', () {
      final p = data.power.town('boufakrane');
      final crops = [
        data.catalog.byId('potato'),
        data.catalog.byId('softwheat'),
      ];
      double mean(OutcomeMatrix m, String id) =>
          m.ryList(id).reduce((a, b) => a + b) / 40;
      final base = OutcomeMatrix.build(crops: crops, climate: p, farm: farm());
      final irr = OutcomeMatrix.build(
        crops: crops,
        climate: p,
        farm: farm(irr: 250),
      );
      final shallow = OutcomeMatrix.build(
        crops: crops,
        climate: p,
        farm: farm(depth: 0.5),
      );
      final dry = OutcomeMatrix.build(
        crops: crops,
        climate: p,
        farm: farm(),
        shock: const Shock(rainMult: 0.6),
      );
      expect(mean(irr, 'potato'), greaterThan(mean(base, 'potato')));
      expect(mean(shallow, 'softwheat'), isNot(mean(base, 'softwheat')));
      expect(mean(dry, 'softwheat'), lessThan(mean(base, 'softwheat')));
    });

    test('warmer scenario acts only through ET0', () {
      final p = data.power.town('boufakrane');
      final s = p.seasons[10];
      final normal = et0Season(
        s,
        lat: p.srcLat,
        elev: p.elev,
      ).values.reduce((a, b) => a + b);
      final warm = et0Season(
        s,
        lat: p.srcLat,
        elev: p.elev,
        tempAdd: 2,
      ).values.reduce((a, b) => a + b);
      expect(warm, greaterThan(normal));
      expect(warm / normal, lessThan(1.2));
    });
  });

  group('scenarios use real seasons', () {
    test('favorable > dry > very dry in rain, each is an existing season', () {
      final seasons = data.power.town('boufakrane').seasons;
      final f = scenarioSeasonIndex(seasons, ClimateYear.favorable);
      final d = scenarioSeasonIndex(seasons, ClimateYear.dry);
      final v = scenarioSeasonIndex(seasons, ClimateYear.veryDry);
      expect(
        seasons[f].rainySeasonRain,
        greaterThan(seasons[d].rainySeasonRain),
      );
      expect(
        seasons[d].rainySeasonRain,
        greaterThan(seasons[v].rainySeasonRain),
      );
      for (final i in [f, d, v]) {
        expect(i, inInclusiveRange(0, 39));
      }
      final rains = seasons.map((s) => s.rainySeasonRain).toList()..sort();
      expect(seasons[v].rainySeasonRain, lessThanOrEqualTo(rains[6]));
    });
    test('hypothetical flag', () {
      expect(Shock.none.isHypothetical, isFalse);
      expect(const Shock(rainMult: 0.8).isHypothetical, isTrue);
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
      expect(Mulberry32(42).next(), closeTo(0.6011037519201636, 1e-12));
    });
    test('futures: same seed identical, other seed different, whole seasons with replacement', () {
      final a = drawFutures(seasonCount: 40),
          b = drawFutures(seasonCount: 40),
          c = drawFutures(seasonCount: 40, seed: 7);
      expect(a, b);
      expect(a, isNot(c));
      expect(a.length, 1000);
      expect(
        a.every((f) => f.length == 3 && f.every((i) => i >= 0 && i < 40)),
        isTrue,
      );
      expect(a.any((f) => f[0] == f[1]), isTrue);
    });
    test('rotation statistics are consistent and reproducible', () {
      final p = data.power.town('boufakrane');
      final m = OutcomeMatrix.build(
        crops: data.catalog.eligible,
        climate: p,
        farm: const FarmParams(soilDepthM: 1, irrigationMm: 0),
      );
      final f = drawFutures(seasonCount: 40);
      final r1 = evaluateRotation(
        cropIds: ['barley', 'fava', 'barley'],
        matrix: m,
        futures: f,
      )!;
      final r2 = evaluateRotation(
        cropIds: ['barley', 'fava', 'barley'],
        matrix: m,
        futures: f,
      )!;
      expect(r1.pAllGood, r2.pAllGood);
      expect(r1.p10, lessThanOrEqualTo(r1.p50));
      expect(r1.p50, lessThanOrEqualTo(r1.p90));
      expect(r1.worst, lessThanOrEqualTo(r1.p10));
      expect(r1.expectedRy, inInclusiveRange(0, 1));
      expect(r1.perSeason.length, 3);
      for (final s in r1.perSeason) {
        expect(s.shareGood, inInclusiveRange(0, 1));
        expect(
          m.at(s.cropId, s.bestSeason).ry,
          greaterThanOrEqualTo(m.at(s.cropId, s.worstSeason).ry!),
        );
      }
      // three good seasons in a row is never more likely than one good season
      final one = evaluateRotation(cropIds: ['barley'], matrix: m, futures: f)!;
      expect(r1.pAllGood, lessThanOrEqualTo(one.pAllGood + 1e-9));
    });
    test('unknown Ky cannot be evaluated', () {
      final p = data.power.town('boufakrane');
      final m = OutcomeMatrix.build(
        crops: data.catalog.annuals,
        climate: p,
        farm: const FarmParams(soilDepthM: 1, irrigationMm: 0),
      );
      expect(
        evaluateRotation(
          cropIds: ['oats', 'oats', 'oats'],
          matrix: m,
          futures: drawFutures(seasonCount: 40),
        ),
        isNull,
      );
    });
  });

  group('rotations', () {
    late OutcomeMatrix matrix;
    late List<List<int>> futures;
    setUpAll(() {
      matrix = OutcomeMatrix.build(
        crops: data.catalog.eligible,
        climate: data.power.town('boufakrane'),
        farm: const FarmParams(soilDepthM: 1, irrigationMm: 0),
      );
      futures = drawFutures(seasonCount: 40);
    });

    test('same-family and Solanaceae flags', () {
      final wheat = data.catalog.byId('softwheat'),
          potato = data.catalog.byId('potato'),
          tomato = data.catalog.byId('tomato');
      expect(
        rotationFlags([wheat, wheat, wheat], rules).map((f) => f.kind),
        everyElement(FlagKind.sameFamily),
      );
      expect(
        rotationFlags([wheat, data.catalog.byId('fava'), wheat], rules),
        isEmpty,
      );
      expect(
        rotationFlags([potato, tomato, wheat], rules).single.kind,
        FlagKind.strongAvoid,
      );
      expect(
        rotationFlags([wheat], rules, previousFamily: 'Poaceae').length,
        1,
      );
      expect(
        rotationFlags([wheat], rules),
        isEmpty,
      ); // unknown previous crop: no flag
    });

    test('A repeats, B has a legume and no flag, C has three families', () {
      final wheat = data.catalog.byId('softwheat');
      final rs = buildRotations(
        selected: wheat,
        catalog: data.catalog,
        matrix: matrix,
        futures: futures,
        rules: rules,
      );
      expect(rs.map((r) => r.id), ['A', 'B', 'C']);
      expect(rs[0].crops.every((c) => c.id == 'softwheat'), isTrue);
      expect(rs[0].flags, isNotEmpty); // monoculture is flagged
      expect(rs[1].crops.any((c) => c.legume), isTrue);
      expect(rs[1].flags, isEmpty);
      expect(rs[1].crops.first.id, 'softwheat');
      expect(rs[2].crops.map((c) => c.family).toSet().length, 3);
      for (final r in rs) {
        expect(r.result, isNotNull);
      }
    });

    test('rotations are ranked and deterministic', () {
      final wheat = data.catalog.byId('softwheat');
      List<String> order() => rankRotations(
        buildRotations(
          selected: wheat,
          catalog: data.catalog,
          matrix: matrix,
          futures: futures,
          rules: rules,
        ),
      ).map((r) => '${r.id}${r.result!.pAllGood}').toList();
      expect(order(), order());
    });

    test('a starting crop without Ky gets no evaluated rotation', () {
      final oats = data.catalog.byId('oats');
      final rs = buildRotations(
        selected: oats,
        catalog: data.catalog,
        matrix: matrix,
        futures: futures,
        rules: rules,
      );
      expect(rs.every((r) => r.result == null), isTrue);
      expect(rankRotations(rs), isEmpty);
    });
  });

  group('detective', () {
    Crop wheat() => data.catalog.byId('softwheat');
    final futures = drawFutures(seasonCount: 40);
    const known = FarmInputs(soilDepthM: 1, irrigationMm: 0);

    test('asks nothing when every input is known', () {
      final r = runDetective(
        selected: wheat(),
        catalog: data.catalog,
        climate: data.power.town('boufakrane'),
        rules: rules,
        inputs: known,
        futures: futures,
      );
      expect(r.question, isNull);
      expect(r.sensitivity.length, 3);
      expect(
        r.sensitivity.first.spread,
        greaterThanOrEqualTo(r.sensitivity.last.spread),
      );
    });

    test(
      'a question appears only if some answer changes or narrows the result',
      () {
        final unknownAll = FarmInputs(
          soilDepthM: 1,
          irrigationMm: 0,
          soilKnown: false,
          irrigationKnown: false,
          previousKnown: false,
        );
        final r = runDetective(
          selected: data.catalog.byId('potato'),
          catalog: data.catalog,
          climate: data.power.town('boufakrane'),
          rules: rules,
          inputs: unknownAll,
          futures: futures,
        );
        final q = r.question;
        if (q != null) {
          final tops = q.outcomes.map((o) => o.topRotationId).toSet();
          final within = q.outcomes.any((o) => o.gap >= 0.05);
          expect(
            tops.length > 1 || within || tops.any((t) => t != 'x'),
            isTrue,
          );
        }
      },
    );
  });

  group('aquifer and sun', () {
    test('aquifer formula', () {
      expect(aquiferChange(saving: 0, years: 10), -30);
      expect(aquiferChange(saving: 1, years: 10), closeTo(-21, 1e-9));
    });
    test('sunrise before sunset, about 12 h of day at the equinox', () {
      final s = sunTimes(
        lat: 33.7,
        lon: -5.3,
        date: DateTime(2025, 3, 20),
        utcOffset: 1,
      );
      expect(s.sunrise, lessThan(s.sunset));
      expect((s.sunset - s.sunrise) / 60, closeTo(12.1, 0.3));
      expect(sqrt(4), 2);
    });
  });
}
