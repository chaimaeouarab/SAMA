import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sama/data/bundled_data_loader.dart';
import 'package:sama/data/crops_catalog.dart';
import 'package:sama/data/nasa_client.dart';
import 'package:sama/data/nasa_power_repository.dart';
import 'package:sama/domain/rotation.dart';
import 'package:sama/features/satellite/gibs.dart';
import 'package:sama/main.dart';
import 'package:sama/state/assumptions.dart';
import 'package:sama/state/farm_state.dart';
import 'package:sama/state/results_provider.dart';
import 'package:sama/state/settings.dart';
import 'package:sama/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

late AppData data;

/// Runs the "heavy" jobs directly: isolates do not mix with the test clock.
Future<T> _direct<T>(T Function() job) async => job();

/// In-memory cache: real file I/O never completes inside the widget-test clock.
class MemoryCache extends DatasetCache {
  final store = <String, Map<String, dynamic>>{};
  @override
  Future<TownClimate?> read(double lat, double lon) async {
    final j = store['${lat}_$lon'];
    return j == null ? null : TownClimate.fromJson('mem', j);
  }

  @override
  Future<void> write(
    double lat,
    double lon,
    Map<String, dynamic> pointJson,
  ) async => store['${lat}_$lon'] = pointJson;
}

class FakeGeo extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  FakeGeo({
    this.enabled = true,
    this.permission = LocationPermission.whileInUse,
    this.accuracy = 20,
    this.lat = 33.95,
    this.lon = -5.25,
  });
  bool enabled;
  LocationPermission permission;
  double accuracy, lat, lon;
  int settingsOpened = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<bool> openAppSettings() async {
    settingsOpened++;
    return true;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: lat,
    longitude: lon,
    timestamp: DateTime(2026),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  bool fail = false,
  bool online = true,
}) async {
  SharedPreferences.setMockInitialValues({...prefs});
  final p = await SharedPreferences.getInstance();
  tester.view
    ..physicalSize = const Size(600 * 2, 1100 * 2)
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      prefsProvider.overrideWithValue(p),
      appDataProvider.overrideWith(
        (ref) => fail ? Future<AppData>.error('boom') : Future.value(data),
      ),
      onlineProvider.overrideWith((ref) => Stream.value(online)),
      heavyRunnerProvider.overrideWithValue(_direct),
      datasetCacheProvider.overrideWithValue(MemoryCache()),
      gibsProvider.overrideWith((ref) async => const <AvailableLayer>[]),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const SamaApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

String _farmsJson({bool known = false}) => jsonEncode([
  Farm(
    id: 'farm1',
    name: 'Boufakrane',
    lat: 33.72,
    lon: -5.30,
    source: LocationSource.preset,
    soilKnown: known,
    irrigationKnown: known,
    previousKnown: known,
  ).toJson(),
]);

void setupForDebug() => setUpAll(_load);

void _load() {
  final power = jsonDecode(
    File('assets/data/nasa_power.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final crops =
      jsonDecode(File('assets/data/crops.json').readAsStringSync()) as List;
  final rules = RotationRules.fromJson(
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
}

void main() {
  setUpAll(() {
    final power = jsonDecode(
      File('assets/data/nasa_power.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final crops =
        jsonDecode(File('assets/data/crops.json').readAsStringSync()) as List;
    final rules = RotationRules.fromJson(
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

  group('onboarding and languages', () {
    testWidgets(
      'first launch shows four languages, each in its own script; choice leads to home',
      (tester) async {
        await pumpApp(tester);
        expect(find.text('Choose your language'), findsOneWidget);
        expect(find.text('اختار اللغة ديالك'), findsOneWidget);
        for (final l in ['الدارجة', 'العربية', 'English', 'Français']) {
          expect(find.text(l), findsOneWidget);
        }
        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();
        expect(find.text('My farm today'), findsOneWidget);
        expect(
          find.textContaining('Typical for today'),
          findsOneWidget,
        ); // labelled as climatology
        expect(
          find.textContaining('not a measurement in your field'),
          findsOneWidget,
        ); // grid-cell honesty
      },
    );

    testWidgets('the language is remembered', (tester) async {
      await pumpApp(tester, prefs: {'lang': 'fr', 'langMigrated2': true});
      expect(find.text('Choose your language'), findsNothing);
      expect(find.text('Ma ferme aujourd’hui'), findsOneWidget);
    });

    testWidgets(
      'upgrade: an old `ar` (Darija) becomes `dar`, RTL, Darija wording',
      (tester) async {
        final c = await pumpApp(tester, prefs: {'lang': 'ar'});
        expect(c.read(settingsProvider).lang!.code, 'dar');
        expect(
          Directionality.of(tester.element(find.byType(Scaffold).first)),
          TextDirection.rtl,
        );
        expect(find.text('الفلاحة ديالي اليوم'), findsOneWidget); // Darija
      },
    );

    testWidgets(
      'Modern Standard Arabic is a separate table from Darija, also RTL',
      (tester) async {
        await pumpApp(tester, prefs: {'lang': 'ar', 'langMigrated2': true});
        expect(
          Directionality.of(tester.element(find.byType(Scaffold).first)),
          TextDirection.rtl,
        );
        expect(find.text('مزرعتي اليوم'), findsOneWidget); // MSA
        expect(find.text('الفلاحة ديالي اليوم'), findsNothing);
      },
    );

    testWidgets('switching language at runtime updates texts and direction', (
      tester,
    ) async {
      await pumpApp(tester, prefs: {'lang': 'en', 'langMigrated2': true});
      await tester.tap(find.text('Me'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الدارجة').last);
      await tester.pumpAndSettle();
      expect(
        Directionality.of(tester.element(find.byType(Scaffold).first)),
        TextDirection.rtl,
      );
      expect(find.text('الإعدادات'), findsOneWidget);
    });
  });

  group('crops', () {
    testWidgets('filter: Trees are Perennial and cereals disappear', (
      tester,
    ) async {
      await pumpApp(tester, prefs: {'lang': 'en', 'langMigrated2': true});
      await tester.tap(find.text('Crops'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Soft wheat'), findsWidgets);
      await tester.dragUntilVisible(
        find.text('Trees'),
        find.byWidgetPredicate(
          (w) => w is ListView && w.scrollDirection == Axis.horizontal,
        ),
        const Offset(-200, 0),
      );
      await tester.tap(find.text('Trees'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Olive · Perennial'), findsOneWidget);
      expect(find.textContaining('Soft wheat'), findsNothing);
    });

    testWidgets(
      'a crop without a documented value shows ? and "More information needed"',
      (tester) async {
        await pumpApp(tester, prefs: {'lang': 'en', 'langMigrated2': true});
        await tester.tap(find.text('Crops'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Oats · ?'), findsOneWidget);
        await tester.ensureVisible(find.textContaining('Oats · ?'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Oats · ?'));
        await tester.pumpAndSettle();
        expect(find.text('More information needed'), findsWidgets);
        expect(find.textContaining('No documented value'), findsOneWidget);
      },
    );

    testWidgets(
      'a tree has no rotation button and says it is not in the model',
      (tester) async {
        await pumpApp(tester, prefs: {'lang': 'en', 'langMigrated2': true});
        await tester.tap(find.text('Crops'));
        await tester.pumpAndSettle();
        await tester.dragUntilVisible(
          find.text('Trees'),
          find.byWidgetPredicate(
            (w) => w is ListView && w.scrollDirection == Axis.horizontal,
          ),
          const Offset(-200, 0),
        );
        await tester.tap(find.text('Trees'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Olive'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('not part of the 3-season model'),
          findsOneWidget,
        );
        expect(find.text('See 3 parallel futures'), findsNothing);
      },
    );
  });

  group('Time Machine', () {
    testWidgets(
      'crop detail -> timeline TODAY, SEASON 1..3 with three rotations compared',
      (tester) async {
        await pumpApp(tester, prefs: {'lang': 'en', 'langMigrated2': true});
        await tester.tap(find.text('Crops'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Barley').first);
        await tester.pumpAndSettle();
        expect(find.text('Crop details'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('See 3 parallel futures'),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('See 3 parallel futures'));
        await tester.pumpAndSettle();
        expect(find.text('Time Machine'), findsOneWidget);
        expect(find.text('TODAY'), findsOneWidget);
        for (final s in ['SEASON 1', 'SEASON 2', 'SEASON 3']) {
          expect(find.text(s), findsOneWidget);
        }
        expect(find.textContaining('in 10'), findsWidgets);
        await tester.scrollUntilVisible(
          find.textContaining('Based on 40 past seasons'),
          500,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('Based on 40 past seasons'), findsOneWidget);
        expect(
          find.textContaining('Provisional agronomic parameters'),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'changing a crop in the timeline switches to "My own rotation" and recomputes',
      (tester) async {
        await pumpApp(tester, prefs: {'lang': 'en', 'langMigrated2': true});
        await tester.tap(find.text('Explore'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Time Machine'));
        await tester.pumpAndSettle();
        expect(find.textContaining('A ·'), findsWidgets);
        // tap the crop of season 2 and pick another one
        await tester.tap(find.byIcon(Icons.edit).at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Maize').last);
        await tester.pumpAndSettle();
        final chip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'My own rotation'),
        );
        expect(chip.selected, isTrue);
      },
    );

    testWidgets(
      'scenario years are real seasons: the season label and rain are shown',
      (tester) async {
        await pumpApp(tester, prefs: {'lang': 'en', 'langMigrated2': true});
        await tester.tap(find.text('Explore'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Time Machine'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, 'Very dry'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Real season'), findsOneWidget);
        expect(find.textContaining(RegExp(r'\d{4}–\d{2}')), findsWidgets);
      },
    );
  });

  group('Climate Shock Lab', () {
    testWidgets(
      '"What if there is less rain?" activates the dry what-if and shows before / after',
      (tester) async {
        final c = await pumpApp(
          tester,
          prefs: {'lang': 'en', 'langMigrated2': true},
        );
        await tester.tap(find.text('Explore'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('What if there is less rain?').first);
        await tester.pumpAndSettle();
        expect(find.text('Climate Shock Lab'), findsOneWidget);
        expect(find.textContaining('Before'), findsWidgets);
        expect(find.textContaining('After'), findsWidgets);
        await tester.tap(find.text('What if there is less rain?').first);
        await tester.pumpAndSettle();
        expect(
          find.text('What-if scenario, not NASA observation'),
          findsWidgets,
        );
        expect(find.text('Back to observed seasons'), findsOneWidget);
        expect(
          c.read(shockProvider).isHypothetical,
          isFalse,
        ); // the lab never mutates the observed model
      },
    );
  });

  group('Detective', () {
    testWidgets('asks nothing when every input is known', (tester) async {
      await pumpApp(
        tester,
        prefs: {
          'lang': 'en',
          'langMigrated2': true,
          'farms': _farmsJson(known: true),
          'farm.current': 'farm1',
        },
      );
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Detective'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No question needed'), findsOneWidget);
    });

    testWidgets(
      'with unknown inputs: either one question with big answer cards, or none (never a pointless one)',
      (tester) async {
        await pumpApp(
          tester,
          prefs: {
            'lang': 'en',
            'langMigrated2': true,
            'farms': _farmsJson(),
            'farm.current': 'farm1',
          },
        );
        await tester.tap(find.text('Explore'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Detective'));
        await tester.pumpAndSettle();
        final asked = find
            .textContaining('This answer changes the best rotation')
            .evaluate()
            .isNotEmpty;
        final none = find
            .textContaining('No question needed')
            .evaluate()
            .isNotEmpty;
        expect(asked != none, isTrue);
      },
    );
  });

  group('farm location', () {
    testWidgets(
      'privacy first, then three big options; search, pick, confirm, farm saved',
      (tester) async {
        final c = await pumpApp(
          tester,
          prefs: {'lang': 'en', 'langMigrated2': true},
        );
        await tester.tap(find.text('Edit').first);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('we send your approximate location'),
          findsOneWidget,
        );
        await tester.tap(find.text('I understand, continue'));
        await tester.pumpAndSettle();
        expect(find.text('Use my GPS location'), findsOneWidget);
        expect(find.text('Search for my village or city'), findsOneWidget);
        expect(find.text('Select my farm on the map'), findsOneWidget);

        await tester.tap(find.text('Search for my village or city'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Agadir');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Agadir'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Latitude: 30.35000'), findsOneWidget);
        await tester.tap(find.text('Confirm this location'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Your farm is selected'), findsOneWidget);
        final f = c.read(farmProvider);
        expect(f.name, 'Agadir');
        expect(f.lat, 30.35);
        expect(f.source, LocationSource.search);
      },
    );

    testWidgets('search finds nothing: honest empty state, no invented place', (
      tester,
    ) async {
      await pumpApp(
        tester,
        prefs: {'lang': 'en', 'langMigrated2': true, 'privacyAck': true},
      );
      await tester.tap(find.text('Edit').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search for my village or city'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Atlantis');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.textContaining('No match'), findsOneWidget);
    });

    testWidgets(
      'map without a tile provider: accessible offline selector instead of a grey map',
      (tester) async {
        await pumpApp(
          tester,
          prefs: {'lang': 'en', 'langMigrated2': true, 'privacyAck': true},
        );
        await tester.tap(find.text('Edit').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Select my farm on the map'));
        await tester.pumpAndSettle();
        expect(find.textContaining('No map tile provider'), findsOneWidget);
        expect(find.text('Supported locations'), findsOneWidget);
        expect(find.widgetWithText(ListTile, 'Meknès'), findsOneWidget);
      },
    );

    testWidgets('manual coordinates are validated', (tester) async {
      await pumpApp(
        tester,
        prefs: {'lang': 'en', 'langMigrated2': true, 'privacyAck': true},
      );
      await tester.tap(find.text('Edit').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search for my village or city'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), '95');
      await tester.enterText(fields.at(2), '10');
      await tester.tap(find.text('Enter coordinates by hand'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid coordinates'), findsOneWidget);
      await tester.enterText(fields.at(1), '34.5');
      await tester.enterText(fields.at(2), '-5.1');
      await tester.tap(find.text('Enter coordinates by hand'));
      await tester.pumpAndSettle();
      expect(find.textContaining('34.50000'), findsWidgets);
    });

    group('GPS permission states (mocked platform)', () {
      Future<void> openGps(WidgetTester tester) async {
        await pumpApp(
          tester,
          prefs: {'lang': 'en', 'langMigrated2': true, 'privacyAck': true},
        );
        await tester.tap(find.text('Edit').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use my GPS location'));
        await tester.pumpAndSettle();
        // plain-language reason first, permission only after "Continue"
        expect(find.textContaining('we need your location once'), findsWidgets);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }

      testWidgets(
        'granted: marker placed with coordinates, accuracy, and a Morocco check',
        (tester) async {
          GeolocatorPlatform.instance = FakeGeo(
            lat: 33.95,
            lon: -5.25,
            accuracy: 18,
          );
          await openGps(tester);
          expect(find.textContaining('33.95000'), findsOneWidget);
          expect(find.textContaining('Accuracy about 18'), findsOneWidget);
          expect(find.textContaining('outside Morocco'), findsNothing);
        },
      );

      testWidgets('outside Morocco: allowed, with a warning', (tester) async {
        GeolocatorPlatform.instance = FakeGeo(lat: 48.85, lon: 2.35);
        await openGps(tester);
        expect(find.textContaining('outside Morocco'), findsOneWidget);
        expect(find.text('Confirm this location'), findsOneWidget);
      });

      testWidgets('low accuracy: asks to confirm or pick on the map', (
        tester,
      ) async {
        GeolocatorPlatform.instance = FakeGeo(accuracy: 9000);
        await openGps(tester);
        expect(find.textContaining('Low accuracy'), findsOneWidget);
      });

      testWidgets('denied: offers manual choice', (tester) async {
        GeolocatorPlatform.instance = FakeGeo(
          permission: LocationPermission.denied,
        )..permission = LocationPermission.denied;
        await openGps(tester);
        expect(find.textContaining('denied'), findsWidgets);
      });

      testWidgets('denied forever: explains and offers to open settings', (
        tester,
      ) async {
        final geo = FakeGeo(permission: LocationPermission.deniedForever);
        GeolocatorPlatform.instance = geo;
        await openGps(tester);
        expect(find.textContaining('blocked'), findsOneWidget);
        await tester.tap(find.text('Open settings'));
        await tester.pumpAndSettle();
        expect(geo.settingsOpened, 1);
      });

      testWidgets('location services off', (tester) async {
        GeolocatorPlatform.instance = FakeGeo(enabled: false);
        await openGps(tester);
        expect(
          find.textContaining('Turn on location services'),
          findsOneWidget,
        );
      });
    });
  });

  group('roles', () {
    testWidgets('Farmer navigation: Home · Explore · Crops · Results · Me', (
      tester,
    ) async {
      await pumpApp(tester, prefs: {'lang': 'en', 'langMigrated2': true});
      for (final l in ['Home', 'Explore', 'Crops', 'Results', 'Me']) {
        expect(find.text(l), findsWidgets, reason: l);
      }
      expect(find.text('Dashboard'), findsNothing);
    });

    testWidgets(
      'Advisor navigation: Dashboard · Farms · Explore · Analysis · Me, and the farms list',
      (tester) async {
        await pumpApp(
          tester,
          prefs: {'lang': 'en', 'langMigrated2': true, 'advisor': true},
        );
        for (final l in ['Dashboard', 'Farms', 'Explore', 'Analysis', 'Me']) {
          expect(find.text(l), findsWidgets, reason: l);
        }
        await tester.tap(find.text('Farms'));
        await tester.pumpAndSettle();
        expect(find.text('Add a farm'), findsOneWidget);
        await tester.tap(find.text('Analysis'));
        await tester.pumpAndSettle();
        expect(find.text('Data provenance'), findsOneWidget);
      },
    );

    testWidgets(
      'Advisor assumptions editor shows the difference from defaults and resets',
      (tester) async {
        final c = await pumpApp(
          tester,
          prefs: {'lang': 'en', 'langMigrated2': true, 'advisor': true},
        );
        await tester.tap(find.text('Me'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Assumptions'));
        await tester.pumpAndSettle();
        expect(find.text('Good-yield threshold'), findsOneWidget);
        expect(find.textContaining('changed'), findsNothing);
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Reset to defaults'),
              )
              .onPressed,
          isNull,
        ); // nothing to reset yet

        c
            .read(assumptionsProvider.notifier)
            .set(const Assumptions(goodThreshold: 0.9));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('changed'),
          findsOneWidget,
        ); // visible difference
        expect(c.read(prefsProvider).getDouble('a.thr'), 0.9); // persisted

        await tester.tap(find.text('Reset to defaults'));
        await tester.pumpAndSettle();
        expect(c.read(assumptionsProvider).isDefault, isTrue);
        expect(find.textContaining('changed'), findsNothing);
      },
    );
  });

  group('states', () {
    testWidgets('error state offers a retry', (tester) async {
      await pumpApp(
        tester,
        prefs: {'lang': 'en', 'langMigrated2': true},
        fail: true,
      );
      expect(find.text('Something went wrong'), findsWidgets);
      expect(find.text('Retry'), findsWidgets);
    });

    testWidgets('offline badge', (tester) async {
      await pumpApp(
        tester,
        prefs: {'lang': 'en', 'langMigrated2': true},
        online: false,
      );
      expect(find.textContaining('Offline'), findsOneWidget);
      expect(
        find.text('My farm today'),
        findsOneWidget,
      ); // everything still works
    });

    testWidgets('empty state', (tester) async {
      SharedPreferences.setMockInitialValues({
        'lang': 'en',
        'langMigrated2': true,
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: Scaffold(body: EmptyView())),
        ),
      );
      expect(find.text('Nothing here'), findsOneWidget);
    });

    testWidgets(
      'approximate regional data is labelled and needs confirmation',
      (tester) async {
        final far = jsonEncode([
          const Farm(
            id: 'farm1',
            name: 'Far away',
            lat: 35.5,
            lon: -2.0,
            source: LocationSource.map,
          ).toJson(),
        ]);
        final c = await pumpApp(
          tester,
          prefs: {
            'lang': 'en',
            'langMigrated2': true,
            'farms': far,
            'farm.current': 'farm1',
          },
        );
        expect(
          find.textContaining('Approximate regional information'),
          findsWidgets,
        );
        expect(find.text('Confirm'), findsWidgets);
        await tester.tap(find.text('Confirm').first);
        await tester.pumpAndSettle();
        expect(c.read(farmProvider).approxConfirmed, isTrue);
        expect(
          find.textContaining('Approximate regional information'),
          findsWidgets,
        ); // the label stays
      },
    );
  });
}
