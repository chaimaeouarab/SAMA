import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/colors.dart';
import 'core/strings.dart';
import 'features/aquifer/aquifer_screen.dart';
import 'features/crop_detail/crop_detail_screen.dart';
import 'features/crops/crops_screen.dart';
import 'features/futures/futures_screen.dart';
import 'features/home/field_setup_screen.dart';
import 'features/home/guided_screen.dart';
import 'features/home/home_screen.dart';
import 'features/me/me_screen.dart';
import 'features/onboarding/language_screen.dart';
import 'features/results/results_screen.dart';
import 'features/why/why_screen.dart';
import 'state/settings.dart';
import 'widgets/common.dart';
import 'voice/audio_player_service.dart';

/// Stops any speech when the screen changes.
class _StopSpeechObserver extends NavigatorObserver {
  _StopSpeechObserver(this.ref);
  final Ref ref;

  void _stop() => ref.read(audioServiceProvider).value?.stop();
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _stop();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _stop();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(settingsProvider.select((s) => s.lang), (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    observers: [_StopSpeechObserver(ref)],
    redirect: (context, state) {
      final hasLang = ref.read(settingsProvider).lang != null;
      final atStart = state.matchedLocation == '/start';
      if (!hasLang) return atStart ? null : '/start';
      if (atStart) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/start', builder: (_, _) => const LanguageScreen()),
      ShellRoute(
        observers: [_StopSpeechObserver(ref)],
        builder: (context, state, child) =>
            ShellScaffold(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/crops', builder: (_, _) => const CropsScreen()),
          GoRoute(path: '/results', builder: (_, _) => const ResultsScreen()),
          GoRoute(path: '/me', builder: (_, _) => const MeScreen()),
          GoRoute(
            path: '/crop/:id',
            builder: (_, s) =>
                CropDetailScreen(cropId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/futures/:id',
            builder: (_, s) => FuturesScreen(cropId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/why',
            builder: (_, s) => WhyScreen(cropId: s.uri.queryParameters['crop']),
          ),
          GoRoute(path: '/aquifer', builder: (_, _) => const AquiferScreen()),
          GoRoute(path: '/field', builder: (_, _) => const FieldSetupScreen()),
          GoRoute(
            path: '/guided/:topic',
            builder: (_, s) => GuidedScreen(topic: s.pathParameters['topic']!),
          ),
        ],
      ),
    ],
  );
});

/// Bottom navigation shared by every screen after onboarding.
class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  static const _tabs = [
    ('/home', Icons.home_outlined, Icons.home, 'nav_home'),
    ('/crops', Icons.eco_outlined, Icons.eco, 'nav_farm'),
    ('/results', Icons.bar_chart_outlined, Icons.bar_chart, 'nav_results'),
    ('/me', Icons.person_outline, Icons.person, 'nav_me'),
  ];

  int get _index {
    if (location.startsWith('/crop') || location.startsWith('/futures')) {
      return 1;
    }
    if (location.startsWith('/results') ||
        location.startsWith('/why') ||
        location.startsWith('/aquifer')) {
      return 2;
    }
    if (location.startsWith('/me')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const OfflineBadge(),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: SamaColors.shadow,
              blurRadius: 14,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 70,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => context.go(_tabs[i].$1),
                      child: Semantics(
                        selected: _index == i,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _index == i ? _tabs[i].$3 : _tabs[i].$2,
                              color: _index == i
                                  ? SamaColors.green
                                  : SamaColors.muted,
                            ),
                            Text(
                              tr(_tabs[i].$4, lang),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _index == i
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: _index == i
                                    ? SamaColors.green
                                    : SamaColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
