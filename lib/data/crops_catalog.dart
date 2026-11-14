class Crop {
  const Crop({
    required this.id,
    required this.category,
    required this.annual,
    required this.legume,
    required this.waterNeed,
    required this.photo,
    required this.kind,
    required this.c1,
    required this.c2,
    required this.names,
  });

  final String id;
  final String category;
  final bool annual;
  final bool legume;

  /// m3/ha per season. TODO(source): placeholder values, FAO-56. Null for trees.
  final double? waterNeed;
  final String photo;
  final String kind;
  final String c1;
  final String c2;
  final Map<String, String> names;

  String name(String lang) => names[lang] ?? names['en']!;

  factory Crop.fromJson(Map<String, dynamic> j) => Crop(
    id: j['id'] as String,
    category: j['category'] as String,
    annual: j['annual'] as bool,
    legume: j['legume'] as bool,
    waterNeed: (j['waterNeedM3PerHa'] as num?)?.toDouble(),
    photo: j['photo'] as String,
    kind: j['kind'] as String,
    c1: j['c1'] as String,
    c2: j['c2'] as String,
    names: (j['names'] as Map<String, dynamic>).cast<String, String>(),
  );
}

const cropCategories = ['cereal', 'legume', 'veg', 'industrial', 'tree'];

class CropCatalog {
  CropCatalog(this.crops);
  final List<Crop> crops;

  Crop byId(String id) => crops.firstWhere((c) => c.id == id);
  List<Crop> get annuals => crops.where((c) => c.annual).toList();
  List<Crop> inCategory(String cat) =>
      crops.where((c) => c.category == cat).toList();
}
