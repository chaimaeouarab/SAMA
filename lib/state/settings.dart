import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/strings.dart';

/// Overridden in main() with the real instance (and in tests).
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider'),
);

class SettingsState {
  const SettingsState({
    this.lang,
    this.advisor = false,
    this.volume = 0.8,
    this.speed = 1.0,
  });

  /// Null until the first-launch language screen has been answered.
  final AppLang? lang;
  final bool advisor;
  final double volume;
  final double speed;

  SettingsState copyWith({
    AppLang? lang,
    bool clearLang = false,
    bool? advisor,
    double? volume,
    double? speed,
  }) => SettingsState(
    lang: clearLang ? null : (lang ?? this.lang),
    advisor: advisor ?? this.advisor,
    volume: volume ?? this.volume,
    speed: speed ?? this.speed,
  );
}

class SettingsNotifier extends Notifier<SettingsState> {
  late SharedPreferences _p;

  @override
  SettingsState build() {
    _p = ref.watch(prefsProvider);
    return SettingsState(
      lang: AppLang.fromCode(_p.getString('lang')),
      advisor: _p.getBool('advisor') ?? false,
      volume: _p.getDouble('volume') ?? 0.8,
      speed: _p.getDouble('speed') ?? 1.0,
    );
  }

  void setLang(AppLang l) {
    _p.setString('lang', l.code);
    state = state.copyWith(lang: l);
  }

  void resetFirstLaunch() {
    _p.remove('lang');
    state = state.copyWith(clearLang: true);
  }

  void setAdvisor(bool v) {
    _p.setBool('advisor', v);
    state = state.copyWith(advisor: v);
  }

  void setVolume(double v) {
    _p.setDouble('volume', v);
    state = state.copyWith(volume: v);
  }

  void setSpeed(double v) {
    _p.setDouble('speed', v);
    state = state.copyWith(speed: v);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);

/// Language to use while building UI (English before the first choice).
final langProvider = Provider<AppLang>(
  (ref) => ref.watch(settingsProvider).lang ?? AppLang.en,
);
