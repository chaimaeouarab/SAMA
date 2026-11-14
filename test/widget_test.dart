import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sama/data/bundled_data_loader.dart';
import 'package:sama/data/crops_catalog.dart';
import 'package:sama/data/nasa_power_repository.dart';
import 'package:sama/main.dart';
import 'package:sama/state/results_provider.dart';
import 'package:sama/state/settings.dart';
import 'package:sama/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

late AppData data;

Future<void> pumpApp(
  WidgetTester tester, {
  String? lang,
  bool fail = false,
}) async {
  SharedPreferences.setMockInitialValues({'lang': ?lang});
  final prefs = await SharedPreferences.getInstance();
  tester.view
    ..physicalSize = const Size(600 * 2, 1100 * 2)
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        appDataProvider.overrideWith(
          (ref) => fail ? Future<AppData>.error('boom') : Future.value(data),
        ),
        onlineProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: const SamaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
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

  testWidgets('first launch shows the language screen, choice leads to home', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Choose your language'), findsOneWidget);
    expect(find.text('اختار اللغة ديالك'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('My farm today'), findsOneWidget);
    expect(
      find.textContaining('Typical for today'),
      findsOneWidget,
    ); // labelled as climatology
  });

  testWidgets(
    'the language is remembered: no language screen on the next start',
    (tester) async {
      await pumpApp(tester, lang: 'fr');
      expect(find.text('Choose your language'), findsNothing);
      expect(find.text('Ma ferme aujourd’hui'), findsOneWidget);
    },
  );

  testWidgets('Darija mirrors the whole tree (RTL)', (tester) async {
    await pumpApp(tester, lang: 'ar');
    final ctx = tester.element(find.byType(Scaffold).first);
    expect(Directionality.of(ctx), TextDirection.rtl);
    expect(find.text('الرئيسية'), findsOneWidget);
  });

  testWidgets('switching language at runtime updates texts and direction', (
    tester,
  ) async {
    await pumpApp(tester, lang: 'en');
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

  testWidgets('crop filter: Trees shows trees as Perennial, hides cereals', (
    tester,
  ) async {
    await pumpApp(tester, lang: 'en');
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

  testWidgets('crop detail leads to the three parallel futures', (
    tester,
  ) async {
    await pumpApp(tester, lang: 'en');
    await tester.tap(find.text('Crops'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Barley').first);
    await tester.pumpAndSettle();
    expect(find.text('Crop details'), findsOneWidget);
    expect(find.text('Chance of a good season'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('See 3 parallel futures'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('See 3 parallel futures'));
    await tester.pumpAndSettle();
    expect(find.text('3 parallel futures'), findsOneWidget);
    for (final p in ['A', 'B', 'C']) {
      expect(find.text(p), findsOneWidget);
    }
    expect(find.textContaining('in 10'), findsWidgets);
    expect(find.textContaining('Based on 40 past seasons'), findsOneWidget);
  });

  testWidgets('a tree has no futures button and says it is not in the model', (
    tester,
  ) async {
    await pumpApp(tester, lang: 'en');
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
  });

  testWidgets('error state offers a retry', (tester) async {
    await pumpApp(tester, lang: 'en', fail: true);
    expect(find.text('Something went wrong'), findsWidgets);
    expect(find.text('Retry'), findsWidgets);
  });

  testWidgets('empty state', (tester) async {
    SharedPreferences.setMockInitialValues({'lang': 'en'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: Scaffold(body: EmptyView())),
      ),
    );
    expect(find.text('Nothing here'), findsOneWidget);
  });
}
