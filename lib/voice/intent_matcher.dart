import '../data/crops_catalog.dart';

enum Intent {
  cropAdvice,
  water,
  timing,
  risk,
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

/// Closed-vocabulary matcher. No LLM: normalise, then fuzzy-match against keywords.
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

  // Darija (Arabic + Arabizi), English, French keywords per intent.
  static const keywords = <Intent, List<String>>{
    Intent.cropAdvice: [
      'شنو نزرع',
      'اش نزرع',
      'شنو نغرس',
      'الزراعة',
      'زراعة',
      'chno nzra3',
      'ach nzra3',
      'which crop',
      'what to plant',
      'what should i plant',
      'crop',
      'quelle culture',
      'que planter',
      'culture',
    ],
    Intent.water: [
      'شحال ديال الما',
      'الما',
      'السقي',
      'chhal d lma',
      'lma',
      'water',
      'how much water',
      'irrigation',
      'eau',
      'combien d eau',
      'arrosage',
    ],
    Intent.timing: [
      'فاش نزرع',
      'وقتاش نزرع',
      'علاش وقت',
      'fach nzra3',
      'waqtach nzra3',
      'when to plant',
      'when',
      'timing',
      'quand semer',
      'quand',
      'moment',
    ],
    Intent.risk: [
      'شنو الخطر',
      'الخطر',
      'chno lkhatar',
      'lkhatar',
      'risk',
      'what risk',
      'is it risky',
      'risque',
      'quel risque',
      'danger',
    ],
    Intent.chooseField: [
      'بدل الفلاحة',
      'الفلاحة',
      'الارض',
      'bddel lfla7a',
      'change field',
      'my field',
      'change my field',
      'champ',
      'changer de champ',
      'mon champ',
    ],
    Intent.repeat: [
      'عاود',
      'عاود ليا',
      '3awd',
      'repeat',
      'say again',
      'again',
      'répète',
      'repete',
      'encore',
    ],
    Intent.changeLanguage: [
      'بدل اللغة',
      'اللغة',
      'bddel llogha',
      'change language',
      'language',
      'changer de langue',
      'langue',
    ],
    Intent.help: [
      'عاوني',
      'مساعدة',
      'سعفني',
      '3awni',
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
        final s = _score(u, _tokens(k));
        // A longer matched keyword is stronger evidence than a one-word hit.
        final weight = _tokens(k).length > 1 ? 1.0 : 0.95;
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
    if (bestIntent == Intent.cropAdvice && cropId != null) {
      return IntentMatch(bestIntent, best, cropId: cropId);
    }
    return IntentMatch(bestIntent, best, cropId: cropId);
  }
}
