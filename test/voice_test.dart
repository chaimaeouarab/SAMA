import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sama/core/strings.dart';
import 'package:sama/data/crops_catalog.dart';
import 'package:sama/voice/intent_matcher.dart';
import 'package:sama/voice/phrase_builder.dart';
import 'package:sama/voice/phrase_catalog.dart';

void main() {
  late IntentMatcher matcher;
  late PhraseCatalog phrases;

  setUpAll(() {
    final crops =
        jsonDecode(File('assets/data/crops.json').readAsStringSync()) as List;
    matcher = IntentMatcher(
      CropCatalog([
        for (final c in crops) Crop.fromJson(c as Map<String, dynamic>),
      ]),
    );
    phrases = PhraseCatalog.fromJson(
      jsonDecode(File('assets/data/phrases.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });

  group('IntentMatcher', () {
    test('normalises Arabic variants, diacritics and Arabizi digits', () {
      expect(
        IntentMatcher.normalize('أَلْقَمْح'),
        IntentMatcher.normalize('القمح'),
      );
      expect(
        IntentMatcher.normalize('الزراعة'),
        IntentMatcher.normalize('الزراعه'),
      );
      expect(IntentMatcher.normalize('Café'), 'cafe');
      expect(IntentMatcher.normalize('3awni'), 'عawni');
      expect(IntentMatcher.normalize('l9mh'), 'lقmh');
      expect(
        IntentMatcher.normalize('2024'),
        '2024',
      ); // digits alone stay digits
    });

    test('Levenshtein', () {
      expect(IntentMatcher.levenshtein('water', 'water'), 0);
      expect(IntentMatcher.levenshtein('water', 'watar'), 1);
      expect(IntentMatcher.levenshtein('', 'abc'), 3);
    });

    test('English, French and Darija utterances', () {
      expect(matcher.match('how much water').intent, Intent.water);
      expect(matcher.match('quand semer').intent, Intent.timing);
      expect(matcher.match('what risk').intent, Intent.risk);
      expect(matcher.match('شنو نزرع').intent, Intent.cropAdvice);
      expect(matcher.match('chno lkhatar').intent, Intent.risk);
      expect(matcher.match('change language').intent, Intent.changeLanguage);
      expect(matcher.match('repeat').intent, Intent.repeat);
      expect(matcher.match('aidez moi').intent, Intent.help);
    });

    test('tolerates small speech-recognition mistakes', () {
      final m = matcher.match('how much watr');
      expect(m.intent, Intent.water);
      expect(m.confident, isTrue);
    });

    test('a crop name alone means crop advice for that crop', () {
      expect(matcher.match('barley').cropId, 'barley');
      expect(matcher.match('barley').intent, Intent.cropAdvice);
      expect(matcher.match('الشعير').cropId, 'barley');
      expect(matcher.match('pomme de terre').cropId, 'potato');
    });

    test('Phase 2 intents in the four languages', () {
      const cases = <String, Intent>{
        'شنو إلا قلت الشتا': Intent.lessRain,
        'ماذا لو قل المطر': Intent.lessRain,
        'what if there is less rain': Intent.lessRain,
        'et s il pleut moins': Intent.lessRain,
        'chno ila 9allat chta': Intent.lessRain,
        'شنو أحسن تناوب': Intent.rotation,
        'ما أفضل تناوب': Intent.rotation,
        'which rotation is more suitable': Intent.rotation,
        'quelle rotation': Intent.rotation,
        'explain this result': Intent.explain,
        'اشرح النتيجة': Intent.explain,
        'explique ce resultat': Intent.explain,
        'ماذا أزرع': Intent.cropAdvice,
        'كم من الماء': Intent.water,
        'does it need a lot of water': Intent.water,
        'متى أزرع': Intent.timing,
      };
      cases.forEach((said, intent) {
        final m = matcher.match(said);
        expect(m.intent, intent, reason: said);
        expect(m.confident, isTrue, reason: said);
      });
    });

    test('low confidence is never guessed', () {
      for (final s in ['', 'blah blah zzz', 'qwertyuiop']) {
        expect(matcher.match(s).confident, isFalse, reason: s);
      }
    });
  });

  group('PhraseBuilder', () {
    test('advice sentence order', () {
      expect(PhraseBuilder.advice('barley', 8), [
        'crop.barley',
        'adv.chance',
        'num.8',
        'word.outof',
        'num.10',
      ]);
      expect(PhraseBuilder.advice('barley', 99).contains('num.10'), isTrue);
      expect(
        PhraseBuilder.adviceWithDisclaimer('barley', 3).last,
        'adv.not_guarantee',
      );
    });

    test('every id the builder can produce exists in phrases.json', () {
      final ids = <String>[
        ...PhraseBuilder.weather('boufakrane'),
        ...PhraseBuilder.greeting(DateTime(2025, 1, 1, 9)),
        for (final l in AppLang.values) ...PhraseBuilder.languageName(l),
        for (var i = 0; i <= 10; i++) ...PhraseBuilder.advice('softwheat', i),
        'ans.crop',
        'ans.water',
        'ans.timing',
        'ans.risk',
        'ans.field',
        'ui.help',
        'ui.not_understood',
      ];
      for (final id in ids) {
        expect(phrases[id], isNotNull, reason: id);
      }
    });

    test('text is joined in the same order, per language', () {
      final ids = PhraseBuilder.advice('barley', 8);
      expect(
        PhraseBuilder.text(ids, AppLang.en, phrases),
        'Barley chance of a good season eight in ten',
      );
      expect(
        PhraseBuilder.text(ids, AppLang.fr, phrases),
        'Orge chance de bonne saison huit sur dix',
      );
    });

    test('weather sentence never invents a place name', () {
      expect(PhraseBuilder.weather(), ['wx.intro', 'wx.note']);
      expect(PhraseBuilder.weather('meknes'), [
        'wx.intro',
        'place.meknes',
        'wx.note',
      ]);
    });

    test('rotation sentence order', () {
      expect(PhraseBuilder.rotation('barley', 7), [
        'crop.barley',
        'adv.rot3',
        'num.7',
        'word.outof',
        'num.10',
        'adv.not_guarantee',
      ]);
    });

    test('all Darija and Arabic is draft, never marked approved', () {
      expect(phrases.phrases.values.every((p) => !p.reviewed), isTrue);
      expect(darijaReviewed, isFalse);
    });

    test('TTS text for Darija is the Latin script', () {
      expect(phrases['num.8']!.ttsText(AppLang.dar), 'tmnya');
      expect(
        phrases['num.8']!.ttsText(AppLang.ar),
        'ثمانية',
      ); // MSA is spoken as Arabic script
      expect(phrases['num.8']!.text(AppLang.dar), 'تمنية');
      expect(phrases['num.8']!.ttsText(AppLang.en), 'eight');
    });
  });
}
