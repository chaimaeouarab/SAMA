import '../data/crops_catalog.dart';

enum Intent {
  cropAdvice,
  water,
  timing,
  risk,
  lessRain,
  rotation,
  explain,
  chooseField,
  repeat,
  changeLanguage,
  help,
}

class IntentMatch {
  const IntentMatch(this.intent, this.confidence, {this.cropId});
  final Intent? intent;
  final double confidence;
  final String? cropId;

  static const confidenceThreshold = 0.6;
  bool get confident => intent != null && confidence >= confidenceThreshold;
}

/// Closed-vocabulary matcher. No LLM: normalise, then fuzzy-match against keywords in 4 languages
/// (Darija in Arabic script and Arabizi, Modern Standard Arabic, English, French).
class IntentMatcher {
  IntentMatcher(this.catalog) {
    for (final c in catalog.crops) {
      for (final n in c.names.values) {
        _cropNames.add((c.id, _tokens(n)));
      }
    }
  }

  final CropCatalog catalog;
  final List<(String, List<String>)> _cropNames = [];

  // All keywords are native-review drafts (docs/VOICE_TESTS.md).
  static const keywords = <Intent, List<String>>{
    Intent.cropAdvice: [
      // Darija
      'شنو نزرع',
      'اش نزرع',
      'شنو نغرس',
      'chno nzra3',
      'ach nzra3',
      'chno nghers',
      // MSA
      'ماذا أزرع', 'ما المحصول المناسب', 'ماذا يمكنني أن أزرع',
      // English / French
      'which crop',
      'what to plant',
      'what should i plant',
      'quelle culture',
      'que planter',
      'que dois je planter',
    ],
    Intent.water: [
      'شحال ديال الما',
      'واش كتحتاج بزاف ديال الما',
      'chhal d lma',
      'wach katahtaj bzaf d lma',
      'كم من الماء',
      'هل يحتاج الكثير من الماء',
      'كم يحتاج من الماء',
      'how much water',
      'does it need a lot of water',
      'water need',
      'combien d eau',
      'besoin en eau',
      'a t il besoin de beaucoup d eau',
    ],
    Intent.timing: [
      'فاش نزرع',
      'وقتاش نزرع',
      'fach nzra3',
      'waqtach nzra3',
      'متى أزرع',
      'متى موعد الزراعة',
      'when to plant',
      'when should i plant',
      'quand semer',
      'quand planter',
    ],
    Intent.risk: [
      'شنو الخطر',
      'واش فيه خطر',
      'chno lkhatar',
      'wach fih khatar',
      'ما المخاطر',
      'هل هناك خطر',
      'what risk',
      'is it risky',
      'quel risque',
      'y a t il un risque',
    ],
    Intent.lessRain: [
      'شنو إلا قلت الشتا',
      'شنو يوقع إلا قلت الشتا',
      'ila 9allat chta',
      'chno ila 9allat chta',
      'chno ghadi ywa9a3 ila 9allat chta',
      'ماذا لو قل المطر',
      'ماذا يحدث إذا قل المطر',
      'ماذا لو انخفض المطر',
      'what if there is less rain',
      'less rain',
      'what happens if there is less rain',
      'drought',
      'et s il pleut moins',
      'moins de pluie',
      'que se passe t il s il pleut moins',
      'secheresse',
    ],
    Intent.rotation: [
      'شنو أحسن تناوب',
      'أي تناوب أحسن',
      'chno a7sen tanaoub',
      'ach a7sen tanaoub',
      'ما أفضل تناوب',
      'أي تناوب أنسب',
      'أي دورة زراعية أنسب',
      'which rotation is more suitable',
      'best rotation',
      'which rotation',
      'quelle rotation',
      'quelle rotation est la plus adaptee',
      'meilleure rotation',
    ],
    Intent.explain: [
      'شرح ليا النتيجة',
      'علاش هاد النتيجة',
      'sharah liya nnatija',
      '3lach had nnatija',
      'اشرح النتيجة',
      'لماذا هذه النتيجة',
      'فسر النتيجة',
      'explain this result',
      'explain the result',
      'why this result',
      'explique ce resultat',
      'expliquer le resultat',
      'pourquoi ce resultat',
    ],
    Intent.chooseField: [
      'بدل الفلاحة',
      'الفلاحة ديالي',
      'bddel lfla7a',
      'غير المزرعة',
      'غيّر المزرعة',
      'مزرعتي',
      'change field',
      'my field',
      'change my field',
      'changer de champ',
      'mon champ',
      'ma ferme',
    ],
    Intent.repeat: [
      'عاود',
      'عاود ليا',
      '3awd',
      'أعد',
      'كرر',
      'repeat',
      'say again',
      'again',
      'répète',
      'repete',
      'encore',
    ],
    Intent.changeLanguage: [
      'بدل اللغة',
      'bddel llogha',
      'غير اللغة',
      'غيّر اللغة',
      'change language',
      'language',
      'changer de langue',
      'langue',
    ],
    Intent.help: [
      'عاوني',
      'سعفني',
      '3awni',
      'مساعدة',
      'ساعدني',
      'help',
      'aide',
      'aidez moi',
      'au secours',
    ],
  };

  static String normalize(String s) {
    var t = s.toLowerCase();
    t = t.replaceAll(RegExp('[ً-ْـ]'), ''); // tashkeel, tatweel
    t = t
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
    const latin = {
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'à': 'a',
      'â': 'a',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'û': 'u',
      'ù': 'u',
      'ç': 'c',
      '’': ' ',
      '\'': ' ',
      '-': ' ',
      '?': ' ',
      '!': ' ',
      ',': ' ',
      '.': ' ',
      '،': ' ',
      '؟': ' ',
    };
    latin.forEach((k, v) => t = t.replaceAll(k, v));
    // Arabizi digits only inside Latin words (3 -> ع, 7 -> ح, 9 -> ق).
    t = t
        .split(RegExp(r'\s+'))
        .map((w) {
          if (RegExp('[a-z]').hasMatch(w)) {
            return w
                .replaceAll('3', 'ع')
                .replaceAll('7', 'ح')
                .replaceAll('9', 'ق');
          }
          return w;
        })
        .join(' ');
    return t.trim();
  }

  static List<String> _tokens(String s) =>
      normalize(s).split(' ').where((w) => w.isNotEmpty).toList();

  static int levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        cur[j] = [
          cur[j - 1] + 1,
          prev[j] + 1,
          prev[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      prev = cur;
    }
    return prev[b.length];
  }

  static double _sim(String a, String b) {
    final m = a.length > b.length ? a.length : b.length;
    return m == 0 ? 1 : 1 - levenshtein(a, b) / m;
  }

  /// Share of the keyword's tokens found (fuzzily) in the utterance.
  static double _score(List<String> utter, List<String> kw) {
    if (kw.isEmpty || utter.isEmpty) return 0;
    var sum = 0.0;
    for (final k in kw) {
      var best = 0.0;
      for (final u in utter) {
        final s = _sim(u, k);
        if (s > best) best = s;
      }
      sum += best >= 0.75 ? best : 0;
    }
    return sum / kw.length;
  }

  IntentMatch match(String utterance) {
    final u = _tokens(utterance);
    if (u.isEmpty) return const IntentMatch(null, 0);

    Intent? bestIntent;
    var best = 0.0;
    for (final e in keywords.entries) {
      for (final k in e.value) {
        final kt = _tokens(k);
        final s = _score(u, kt);
        // Longer phrases are stronger evidence; a phrase must also not be much longer than what was said.
        final coverage = kt.length > u.length ? u.length / kt.length : 1.0;
        final weight = (kt.length > 1 ? 1.0 : 0.9) * (0.5 + 0.5 * coverage);
        if (s * weight > best) {
          best = s * weight;
          bestIntent = e.key;
        }
      }
    }

    String? crop;
    var cropBest = 0.0;
    for (final (id, name) in _cropNames) {
      final s = _score(u, name);
      if (s > cropBest) {
        cropBest = s;
        crop = id;
      }
    }
    final cropId = cropBest >= 0.8 ? crop : null;
    // A crop name alone ("blé", "القمح") means "advice for that crop".
    if (cropId != null &&
        (bestIntent == null || best < IntentMatch.confidenceThreshold)) {
      return IntentMatch(Intent.cropAdvice, cropBest, cropId: cropId);
    }
    return IntentMatch(bestIntent, best, cropId: cropId);
  }
}
