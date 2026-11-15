import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/colors.dart';
import 'core/strings.dart';
import 'features/advisor/advisor_screens.dart';
import 'features/aquifer/aquifer_screen.dart';
import 'features/crop_detail/crop_detail_screen.dart';
import 'features/crops/crops_screen.dart';
import 'features/detective/detective_screen.dart';
import 'features/explore/explore_screen.dart';
import 'features/farm/farm_inputs_screen.dart';
import 'features/farm/farm_location_screen.dart';
import 'features/home/guided_screen.dart';
import 'features/home/home_screen.dart';
import 'features/me/me_screen.dart';
import 'features/onboarding/language_screen.dart';
import 'features/results/results_screen.dart';
import 'features/satellite/satellite_screen.dart';
import 'features/shock_lab/shock_lab_screen.dart';
import 'features/time_machine/time_machine_screen.dart';
import 'features/why/why_screen.dart';
import 'state/settings.dart';
import 'voice/audio_player_service.dart';
import 'widgets/common.dart';
import 'widgets/logo_bar.dart';

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
      if (!hasLang) {
        return atStart ? null : '/start';
      }
      if (atStart) {
        return '/home';
      }
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
          GoRoute(path: '/explore', builder: (_, _) => const ExploreScreen()),
          GoRoute(path: '/crops', builder: (_, _) => const CropsScreen()),
          GoRoute(path: '/results', builder: (_, _) => const ResultsScreen()),
          GoRoute(path: '/me', builder: (_, _) => const MeScreen()),
          GoRoute(path: '/farms', builder: (_, _) => const FarmsScreen()),
          GoRoute(path: '/analysis', builder: (_, _) => const AnalysisScreen()),
          GoRoute(
            path: '/assumptions',
            builder: (_, _) => const AssumptionsScreen(),
          ),
          GoRoute(
            path: '/crop/:id',
            builder: (_, s) =>
                CropDetailScreen(cropId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/time',
            builder: (_, s) =>
                TimeMachineScreen(cropId: s.uri.queryParameters['crop']),
          ),
          GoRoute(
            path: '/shock',
            builder: (_, s) =>
                ShockLabScreen(cropId: s.uri.queryParameters['crop']),
          ),
          GoRoute(
            path: '/detective',
            builder: (_, s) =>
                DetectiveScreen(cropId: s.uri.queryParameters['crop']),
          ),
          GoRoute(
            path: '/satellite',
            builder: (_, _) => const SatelliteScreen(),
          ),
          GoRoute(
            path: '/why',
            builder: (_, s) => WhyScreen(cropId: s.uri.queryParameters['crop']),
          ),
          GoRoute(path: '/aquifer', builder: (_, _) => const AquiferScreen()),
          GoRoute(
            path: '/farm/location',
            builder: (_, s) =>
                FarmLocationScreen(addNew: s.uri.queryParameters['new'] == '1'),
          ),
          GoRoute(
            path: '/farm/inputs',
            builder: (_, _) => const FarmInputsScreen(),
          ),
          GoRoute(
            path: '/guided/:topic',
            builder: (_, s) => GuidedScreen(topic: s.pathParameters['topic']!),
          ),
        ],
      ),
    ],
  );
});

/// Bottom navigation: different for Farmer and Advisor (same app, two roles).
class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  static const _farmer = [
    ('/home', Icons.home_outlined, Icons.home, 'nav_home'),
    ('/explore', Icons.explore_outlined, Icons.explore, 'nav_explore'),
    ('/crops', Icons.eco_outlined, Icons.eco, 'nav_farm'),
    ('/results', Icons.bar_chart_outlined, Icons.bar_chart, 'nav_results'),
    ('/me', Icons.person_outline, Icons.person, 'nav_me'),
  ];
  static const _advisor = [
    ('/home', Icons.dashboard_outlined, Icons.dashboard, 'nav_dashboard'),
    ('/farms', Icons.agriculture_outlined, Icons.agriculture, 'nav_farms'),
    ('/explore', Icons.explore_outlined, Icons.explore, 'nav_explore'),
    ('/analysis', Icons.analytics_outlined, Icons.analytics, 'nav_analysis'),
    ('/me', Icons.person_outline, Icons.person, 'nav_me'),
  ];

  int _index(bool advisor) {
    final l = location;
    if (l.startsWith('/me') || l.startsWith('/assumptions')) return 4;
    if (l.startsWith('/explore') ||
        l.startsWith('/time') ||
        l.startsWith('/shock') ||
        l.startsWith('/detective') ||
        l.startsWith('/satellite')) {
      return 2;
    }
    if (advisor) {
      if (l.startsWith('/farms') || l.startsWith('/farm/')) return 1;
      if (l.startsWith('/analysis') ||
          l.startsWith('/results') ||
          l.startsWith('/why') ||
          l.startsWith('/aquifer') ||
          l.startsWith('/crop')) {
        return 3;
      }
      return 0;
    }
    if (l.startsWith('/crop')) return 2 + 0; // crop pages belong to Crops
    if (l.startsWith('/results') ||
        l.startsWith('/why') ||
        l.startsWith('/aquifer')) {
      return 3;
    }
    return 0;
  }

  int _farmerIndex() {
    final l = location;
    if (l.startsWith('/me') || l.startsWith('/assumptions')) return 4;
    if (l.startsWith('/results') ||
        l.startsWith('/why') ||
        l.startsWith('/aquifer')) {
      return 3;
    }
    if (l.startsWith('/crops') || l.startsWith('/crop/')) return 2;
    if (l.startsWith('/explore') ||
        l.startsWith('/time') ||
        l.startsWith('/shock') ||
        l.startsWith('/detective') ||
        l.startsWith('/satellite')) {
      return 1;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final advisor = ref.watch(settingsProvider.select((s) => s.advisor));
    final tabs = advisor ? _advisor : _farmer;
    final idx = advisor ? _index(true) - 0 : _farmerIndex();
    // In Advisor mode Explore is the 3rd tab (index 2); _index already returns that.
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const LogoBar(),
            const OfflineBadge(),
            const DataBanners(),
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
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => context.go(tabs[i].$1),
                      child: Semantics(
                        selected: idx == i,
                        button: true,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              idx == i ? tabs[i].$3 : tabs[i].$2,
                              color: idx == i
                                  ? (advisor ? advisorColor : SamaColors.green)
                                  : SamaColors.muted,
                            ),
                            Text(
                              tr(tabs[i].$4, lang),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: idx == i
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: idx == i
                                    ? (advisor
                                          ? advisorColor
                                          : SamaColors.green)
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
