import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/strings.dart';

/// One entry of assets/data/phrases.json. `reviewed` is false for all draft Darija and Arabic.
class Phrase {
  const Phrase(
    this.id,
    this.dar,
    this.latin,
    this.ar,
    this.en,
    this.fr,
    this.reviewed,
  );
  final String id;

  /// Darija (display, Arabic script) and its Latin transliteration (TTS input).
  final String dar;
  final String latin;

  /// Modern Standard Arabic.
  final String ar;
  final String en;
  final String fr;
  final bool reviewed;

  /// Text shown on screen.
  String text(AppLang l) => switch (l) {
    AppLang.dar => dar,
    AppLang.ar => ar,
    AppLang.en => en,
    AppLang.fr => fr,
  };

  /// Text sent to a TTS engine (the Darija voice wants Latin script).
  String ttsText(AppLang l) => l == AppLang.dar ? latin : text(l);
}

class PhraseCatalog {
  PhraseCatalog(this.phrases);
  final Map<String, Phrase> phrases;

  factory PhraseCatalog.fromJson(Map<String, dynamic> j) => PhraseCatalog({
    for (final e in j.entries)
      e.key: Phrase(
        e.key,
        e.value['dar'] as String,
        e.value['latin'] as String,
        e.value['ar'] as String,
        e.value['en'] as String,
        e.value['fr'] as String,
        e.value['reviewed'] as bool,
      ),
  });

  Phrase? operator [](String id) => phrases[id];
}

final phraseCatalogProvider = FutureProvider<PhraseCatalog>((ref) async {
  final raw = await rootBundle.loadString('assets/data/phrases.json');
  return PhraseCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
});
