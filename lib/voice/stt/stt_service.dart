import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/strings.dart';

String sttLocale(AppLang l) => switch (l) {
  AppLang.dar => 'ar_MA',
  AppLang.ar => 'ar_SA',
  AppLang.fr => 'fr_FR',
  AppLang.en => 'en_US',
};

enum SttStatus { ready, denied, unavailable }

/// Speech-to-text fixed to the chosen language (no auto-detect, see docs/OPEN_ITEMS.md).
class SttService {
  final SpeechToText _stt = SpeechToText();

  /// Asks for the microphone at first use. The caller shows the plain-language reason first.
  Future<SttStatus> prepare() async {
    final perm = await Permission.microphone.request();
    if (!perm.isGranted) return SttStatus.denied;
    final ok = await _stt.initialize();
    return ok ? SttStatus.ready : SttStatus.unavailable;
  }

  Future<void> listen(
    AppLang lang,
    void Function(String text, bool isFinal) onResult,
  ) => _stt.listen(
    listenOptions: SpeechListenOptions(
      partialResults: true,
      cancelOnError: true,
      localeId: sttLocale(lang),
      pauseFor: const Duration(seconds: 3),
    ),
    onResult: (r) => onResult(r.recognizedWords, r.finalResult),
  );

  Future<void> stop() => _stt.stop();
  Future<void> cancel() => _stt.cancel();
}
