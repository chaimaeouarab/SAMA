import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../core/strings.dart';
import '../state/settings.dart';
import 'phrase_catalog.dart';
import 'tts_backends/tts_backend.dart';

class SpeakResult {
  const SpeakResult({required this.played, required this.text});

  /// False when at least one clip could not be found: the UI then shows [text].
  final bool played;
  final String text;
}

/// Resolves each phrase through the backend chain and plays the clips in order.
/// Never autoplays; call [stop] when the screen is left.
class AudioPlayerService {
  AudioPlayerService(
    this._backends,
    this._catalog,
    this._settings, {
    AudioPlayer Function()? playerFactory,
  }) : _playerFactory = playerFactory ?? AudioPlayer.new;

  final List<TtsBackend> _backends;
  final PhraseCatalog _catalog;
  final SettingsState Function() _settings;
  final AudioPlayer Function() _playerFactory;
  AudioPlayer? _player;
  int _token = 0;

  static const gap = Duration(milliseconds: 150);

  Future<AudioRef?> _resolve(Phrase p, AppLang lang) async {
    for (final b in _backends) {
      final r = await b.resolve(p, lang);
      if (r != null) return r;
    }
    return null;
  }

  Future<SpeakResult> speak(List<String> ids, AppLang lang) async {
    await stop();
    final my = ++_token;
    final phrases = [for (final id in ids) _catalog[id]]
        .whereType<Phrase>()
        .toList();
    final text = phrases.map((p) => p.text(lang)).join(' ');
    final refs = <AudioRef>[];
    for (final p in phrases) {
      final r = await _resolve(p, lang);
      if (r == null) {
        return SpeakResult(
          played: false,
          text: text,
        ); // all-or-nothing: no half sentences
      }
      refs.add(r);
    }
    if (refs.isEmpty || my != _token) {
      return SpeakResult(played: false, text: text);
    }

    final player = _player = _playerFactory();
    try {
      final s = _settings();
      await player.setVolume(s.volume);
      await player.setSpeed(s.speed);
      for (final r in refs) {
        if (my != _token) break;
        await (r.isAsset
            ? player.setAsset(r.path)
            : player.setFilePath(r.path));
        await player.play(); // completes when the clip ends
        await Future<void>.delayed(gap);
      }
      return SpeakResult(played: true, text: text);
    } on Object {
      return SpeakResult(played: false, text: text);
    } finally {
      if (identical(_player, player)) _player = null;
      await player.dispose();
    }
  }

  Future<void> stop() async {
    _token++;
    final p = _player;
    _player = null;
    await p?.stop();
  }
}

final audioServiceProvider = FutureProvider<AudioPlayerService>((ref) async {
  final catalog = await ref.watch(phraseCatalogProvider.future);
  final dio = Dio();
  final service = AudioPlayerService(
    [
      BundledBackend(loadAssetManifest),
      DiskCacheBackend(),
      GradioSpaceBackend(dio),
      HfInferenceBackend(dio),
    ],
    catalog,
    () => ref.read(settingsProvider),
  );
  ref.onDispose(service.stop);
  return service;
});
