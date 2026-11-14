/// FAO-56 / FAO-33 parameters of one annual crop. DRAFT values (verified:false) until a person
/// has checked them against the books (docs/SOURCES.md).
class CropModelSpec {
  const CropModelSpec({
    required this.sowMonth,
    required this.sowDay,
    required this.stages,
    required this.kcIni,
    required this.kcMid,
    required this.kcEnd,
    required this.zrMax,
    required this.p,
    required this.ky,
    required this.verified,
  });

  final int sowMonth;
  final int sowDay;

  /// Stage lengths in days: initial, development, mid-season, late-season.
  final List<int> stages;
  final double kcIni;
  final double kcMid;
  final double kcEnd;

  /// Maximum rooting depth (m) and the fraction of TAW that can be depleted without stress.
  final double zrMax;
  final double p;

  /// FAO-33 yield response factor. Null = no documented value: the crop is not recommended.
  final double? ky;
  final bool verified;

  int get cycleDays => stages.fold(0, (a, b) => a + b);

  factory CropModelSpec.fromJson(Map<String, dynamic> j) {
    final s = j['stages'] as Map<String, dynamic>;
    final kc = j['kc'] as Map<String, dynamic>;
    final sow = j['sow'] as Map<String, dynamic>;
    return CropModelSpec(
      sowMonth: sow['month'] as int,
      sowDay: sow['day'] as int,
      stages: [
        s['ini'] as int,
        s['dev'] as int,
        s['mid'] as int,
        s['late'] as int,
      ],
      kcIni: (kc['ini'] as num).toDouble(),
      kcMid: (kc['mid'] as num).toDouble(),
      kcEnd: (kc['end'] as num).toDouble(),
      zrMax: (j['zrMax'] as num).toDouble(),
      p: (j['p'] as num).toDouble(),
      ky: (j['ky'] as num?)?.toDouble(),
      verified: j['verified'] as bool,
    );
  }
}

class Crop {
  const Crop({
    required this.id,
    required this.category,
    required this.family,
    required this.annual,
    required this.legume,
    required this.photo,
    required this.kind,
    required this.c1,
    required this.c2,
    required this.names,
    this.model,
  });

  final String id;
  final String category;
  final String family;
  final bool annual;
  final bool legume;
  final String photo;
  final String kind;
  final String c1;
  final String c2;

  /// Keys: dar, ar, en, fr.
  final Map<String, String> names;

  /// Null for perennial trees (not part of the 3-season model).
  final CropModelSpec? model;

  /// True when the crop can be recommended: annual and with a documented FAO-33 Ky.
  bool get eligible => annual && model?.ky != null;

  String name(String lang) => names[lang] ?? names['en']!;

  factory Crop.fromJson(Map<String, dynamic> j) => Crop(
    id: j['id'] as String,
    category: j['category'] as String,
    family: j['family'] as String,
    annual: j['annual'] as bool,
    legume: j['legume'] as bool,
    photo: j['photo'] as String,
    kind: j['kind'] as String,
    c1: j['c1'] as String,
    c2: j['c2'] as String,
    names: (j['names'] as Map<String, dynamic>).cast<String, String>(),
    model: j['model'] == null
        ? null
        : CropModelSpec.fromJson(j['model'] as Map<String, dynamic>),
  );
}

const cropCategories = ['cereal', 'legume', 'veg', 'industrial', 'tree'];

class CropCatalog {
  CropCatalog(this.crops);
  final List<Crop> crops;

  Crop byId(String id) => crops.firstWhere((c) => c.id == id);
  List<Crop> get annuals => crops.where((c) => c.annual).toList();

  /// Annual crops that have every parameter needed for a recommendation.
  List<Crop> get eligible => crops.where((c) => c.eligible).toList();
  List<Crop> inCategory(String cat) =>
      crops.where((c) => c.category == cat).toList();
}
