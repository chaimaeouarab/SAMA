import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/strings.dart';
import '../state/settings.dart';
import '../voice/audio_player_service.dart';
import '../voice/phrase_catalog.dart';
import '../voice/phrase_builder.dart';

/// Last spoken sentence, for the "repeat" intent.
class LastSpoken extends Notifier<List<String>> {
  @override
  List<String> build() => const [];
  void set(List<String> ids) => state = ids;
}

final lastSpokenProvider = NotifierProvider<LastSpoken, List<String>>(
  LastSpoken.new,
);

/// Speak a sentence. If no audio can be found the text is shown: never fails silently.
/// Safe to call right before the calling widget is disposed (uses the root container).
Future<void> speakIds(
  BuildContext context,
  List<String> ids, {
  AppLang? lang,
}) => speakWith(
  ProviderScope.containerOf(context),
  ScaffoldMessenger.of(context),
  ids,
  lang: lang,
);

Future<void> speakWith(
  ProviderContainer c,
  ScaffoldMessengerState messenger,
  List<String> ids, {
  AppLang? lang,
}) async {
  final AppLang l = lang ?? c.read(langProvider);
  c.read(lastSpokenProvider.notifier).set(ids);
  try {
    final service = await c.read(audioServiceProvider.future);
    final catalog = await c.read(phraseCatalogProvider.future);
    final r = await service.speak(ids, l);
    if (!r.played) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Text(
              '${tr('voice_unavailable', l)}\n${r.text.isEmpty ? PhraseBuilder.text(ids, l, catalog) : r.text}',
            ),
          ),
        );
    }
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(tr('error', l))));
  }
}

/// Round speaker button (>= 48 dp, labelled for screen readers).
class SpeakerButton extends ConsumerWidget {
  const SpeakerButton(
    this.ids, {
    super.key,
    this.lang,
    this.onGreen = false,
    this.size = 48,
  });
  final List<String> ids;
  final AppLang? lang;
  final bool onGreen;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLang l = lang ?? ref.watch(langProvider);
    return Semantics(
      button: true,
      label: tr('listen', l),
      child: InkResponse(
        onTap: () => speakIds(context, ids, lang: lang),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onGreen ? Colors.white24 : SamaColors.green,
          ),
          child: Icon(Icons.volume_up, color: Colors.white, size: size * 0.5),
        ),
      ),
    );
  }
}
