import '../core/strings.dart';
import 'phrase_catalog.dart';

/// Builds spoken sentences as ordered lists of phrase ids, so no free text
/// ever needs live TTS. Playback concatenates the clips in this order.
class PhraseBuilder {
  const PhraseBuilder._();

  /// `crop. chance of a good season: X in 10`
  static List<String> advice(String cropId, int inTen) => [
    'crop.$cropId',
    'adv.chance',
    'num.${inTen.clamp(0, 10)}',
    'word.outof',
    'num.10',
  ];

  static List<String> adviceWithDisclaimer(String cropId, int inTen) => [
    ...advice(cropId, inTen),
    'adv.not_guarantee',
  ];

  /// The place name is spoken only for a known preset, never invented for custom coordinates.
  static List<String> weather([String? placeId]) => [
    'wx.intro',
    if (placeId != null) 'place.$placeId',
    'wx.note',
  ];

  /// `crop. chance of three good seasons: X in 10`
  static List<String> rotation(String cropId, int inTen) => [
    'crop.$cropId',
    'adv.rot3',
    'num.${inTen.clamp(0, 10)}',
    'word.outof',
    'num.10',
    'adv.not_guarantee',
  ];

  /// One of the fixed answer sentences (see phrases.json, ids `ans.*`).
  static List<String> answer(String key) => ['ans.$key'];

  static List<String> greeting(DateTime now) => [
    now.hour < 12
        ? 'greet.morning'
        : now.hour < 18
        ? 'greet.afternoon'
        : 'greet.evening',
  ];

  static List<String> languageName(AppLang l) => ['lang.${l.code}'];

  /// Readable text of a sentence (the visible fallback when no audio exists).
  static String text(List<String> ids, AppLang lang, PhraseCatalog cat) {
    final parts = <String>[];
    for (var i = 0; i < ids.length; i++) {
      final p = cat[ids[i]];
      if (p == null) continue;
      parts.add(p.text(lang));
    }
    return parts.join(' ');
  }
}
