import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_router.dart';
import 'core/strings.dart';
import 'core/theme.dart';
import 'state/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      // Bundled data does not heal by retrying: show the error and a Retry button at once.
      retry: (_, _) => null,
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const SamaApp(),
    ),
  );
}

class SamaApp extends ConsumerWidget {
  const SamaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    return MaterialApp.router(
      title: 'SAMA',
      debugShowCheckedModeBanner: false,
      theme: samaTheme(),
      // Darija uses the Arabic locale, which mirrors the whole tree (RTL).
      locale: Locale(lang.code),
      supportedLocales: [for (final l in AppLang.values) Locale(l.code)],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
