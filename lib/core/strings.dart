import 'constants.dart';

/// UI strings in [Darija (Arabic script), English, French].
/// All Darija text is a DRAFT: reviewed:false until a native speaker approves it
/// (docs/darija_review.csv). Nothing in the UI is shown as "approved".
enum AppLang {
  ar('ar', 'الدارجة'),
  en('en', 'English'),
  fr('fr', 'Français');

  const AppLang(this.code, this.label);
  final String code;
  final String label;

  static AppLang? fromCode(String? c) {
    for (final l in values) {
      if (l.code == c) return l;
    }
    return null;
  }
}

const bool darijaReviewed = false;

const Map<String, List<String>> _s = {
  'greet_morning': ['صباح الخير', 'Good Morning', 'Bonjour'],
  'greet_afternoon': ['نهارك سعيد', 'Good Afternoon', 'Bon après-midi'],
  'greet_evening': ['مساء الخير', 'Good Evening', 'Bonsoir'],
  'my_farm': ['الفلاحة ديالي اليوم', 'My farm today', 'Ma ferme aujourd’hui'],
  'ask': [
    'قول ليا شنو بغيتي',
    'Tell me what you need',
    'Dites-moi ce qu’il vous faut',
  ],
  'hum': ['الرطوبة', 'Humidity', 'Humidité'],
  'rain': ['الشتا', 'Rain', 'Pluie'],
  'wind': ['الريح', 'Wind', 'Vent'],
  'pressure': ['الضغط', 'Pressure', 'Pression'],
  'sunrise': ['الشروق', 'Sunrise', 'Lever'],
  'sunset': ['الغروب', 'Sunset', 'Coucher'],
  'wx_typical': [
    'المعتاد فهاد النهار، $dataYears، معطيات ناسا (ماشي توقعات)',
    'Typical for today, $dataYears (NASA POWER). Not a live forecast.',
    'Typique pour aujourd’hui, $dataYears (NASA POWER). Pas une prévision.',
  ],
  'know': [
    'شنو بغيتي تعرف؟',
    'What do you want to know?',
    'Que voulez-vous savoir ?',
  ],
  'd_crop': ['شنو نزرع', 'Crop', 'Culture'],
  'd_water': ['الما', 'Water', 'Eau'],
  'd_timing': ['فاش نزرع', 'Timing', 'Moment'],
  'd_risk': ['الخطر', 'Risk', 'Risque'],
  'best': ['أحسن الزراعات ليك', 'Best crops for you', 'Meilleures cultures'],
  'all': ['شوف الكل', 'View all', 'Tout voir'],
  'nav_home': ['الرئيسية', 'Home', 'Accueil'],
  'nav_farm': ['الزراعات', 'Crops', 'Cultures'],
  'nav_results': ['النتايج', 'Results', 'Résultats'],
  'nav_me': ['أنا', 'Me', 'Moi'],
  'crop_details': ['تفاصيل الزراعة', 'Crop details', 'Détails de la culture'],
  'chance': [
    'حظ موسم مزيان',
    'Chance of a good season',
    'Chance de bonne saison',
  ],
  'area': ['المساحة (هكتار)', 'Area (ha)', 'Surface (ha)'],
  'desc': ['الوصف', 'Description', 'Description'],
  'related': ['زراعات أخرى', 'Other crops', 'Autres cultures'],
  'see3': [
    'شوف 3 مستقبلات',
    'See 3 parallel futures',
    'Voir 3 futurs parallèles',
  ],
  'season_rain': ['شتا الموسم', 'Season rain', 'Pluie de la saison'],
  'so_far': [
    'المعتاد من بداية الموسم',
    'Typical since the season started',
    'Typique depuis le début de saison',
  ],
  'past': ['المواسم اللي فاتو', 'Past seasons', 'Saisons passées'],
  'good': ['موسم مزيان', 'Good season', 'Bonne saison'],
  'dry': ['موسم ناشف', 'Dry season', 'Saison sèche'],
  'why': ['علاش هاد النصيحة؟', 'Why this advice?', 'Pourquoi ce conseil ?'],
  'settings': ['الإعدادات', 'Settings', 'Réglages'],
  'language': ['اللغة', 'Language', 'Langue'],
  'mode': ['الوضع', 'Mode', 'Mode'],
  'mode_farmer': ['فلاح', 'Farmer', 'Agriculteur'],
  'mode_advisor': [
    'مستشار (أرقام)',
    'Advisor (numbers)',
    'Conseiller (chiffres)',
  ],
  'volume': ['حجم الصوت', 'Volume', 'Volume'],
  'speed': ['سرعة الصوت', 'Voice speed', 'Vitesse de la voix'],
  'voice': ['الصوت', 'Voice', 'Voix'],
  'voice_male': ['صوت راجل', 'Male voice', 'Voix masculine'],
  'about': ['على التطبيق', 'About', 'À propos'],
  'source': [
    'المعطيات من ناسا (NASA POWER). هادي إحصائيات على 40 سنة، ماشي توقعات ولا ضمانة.',
    'Data from NASA POWER. Statistics on 40 past seasons, not a forecast and not a guarantee.',
    'Données NASA POWER. Statistiques sur 40 saisons passées, pas une prévision ni une garantie.',
  ],
  'reset_first': [
    'رجع لأول تشغيل',
    'Reset first launch',
    'Réinitialiser le premier lancement',
  ],
  'voice_unavailable': [
    'الصوت ما كايناش دابا. هادا هو النص:',
    'Voice is not available yet. Here is the text:',
    'La voix n’est pas disponible. Voici le texte :',
  ],
  'change_language': ['بدل اللغة', 'Change language', 'Changer de langue'],
  'sample': ['أرقام ديال المثال', 'Sample numbers', 'Chiffres d’exemple'],
  'c_all': ['الكل', 'All', 'Tout'],
  'c_cereal': ['الحبوب', 'Cereals', 'Céréales'],
  'c_legume': ['القطاني', 'Legumes', 'Légumineuses'],
  'c_veg': ['الخضرة والفواكه', 'Vegetables & fruits', 'Légumes et fruits'],
  'c_industrial': [
    'صناعية وعلف',
    'Industrial & fodder',
    'Industrielles et fourrage',
  ],
  'c_tree': ['الأشجار', 'Trees', 'Arbres'],
  'cd_cereal': [
    'حبوب كتعتامد على شتا الشتا، والحصاد فالصيف.',
    'A cereal that relies on winter rain; harvested in early summer.',
    'Une céréale qui dépend de la pluie d’hiver ; récolte en début d’été.',
  ],
  'cd_legume': [
    'بقولية كتجدد التربة وكتخلي الزراعة الجاية أحسن.',
    'A legume: it restores the soil for the next crop.',
    'Une légumineuse : elle enrichit le sol pour la culture suivante.',
  ],
  'cd_veg': [
    'كتحتاج الما بزاف، السقي ضروري.',
    'Needs plenty of water; irrigation is required.',
    'Demande beaucoup d’eau ; irrigation nécessaire.',
  ],
  'cd_industrial': [
    'زراعة صناعية أو علف للبهايم، كتحتاج حساب ديال الما.',
    'An industrial or fodder crop; water planning matters.',
    'Culture industrielle ou fourragère ; la gestion de l’eau est essentielle.',
  ],
  'cd_tree': [
    'شجرة كتبقى سنين. السقي والما ديال الفرشة مهمين.',
    'A perennial tree. Irrigation and groundwater matter.',
    'Un arbre pérenne. L’irrigation et la nappe sont déterminantes.',
  ],
  'perennial': ['شجرة دايمة', 'Perennial', 'Pérenne'],
  'notmodel': [
    'الأشجار ما دخلاتش فالحساب ديال 3 مواسم.',
    'Perennial — not part of the 3-season model.',
    'Pérenne — hors du modèle à 3 saisons.',
  ],
  'based40': [
    'مبني على 40 موسم فاتو. ماشي ضمانة.',
    'Based on 40 past seasons. Not a guarantee.',
    'Fondé sur 40 saisons passées. Pas une garantie.',
  ],
  'in10': ['من 10', 'in 10', 'sur 10'],
  'source_line': [
    'المصدر: NASA POWER، $dataYears',
    'Source: NASA POWER, $dataYears',
    'Source : NASA POWER, $dataYears',
  ],
  'data_stamp': ['معطيات', 'Data', 'Données'],
  'offline': [
    'بلا إنترنت — كلشي خدام',
    'Offline — everything still works',
    'Hors ligne — tout fonctionne',
  ],
  'retry': ['عاود', 'Retry', 'Réessayer'],
  'error': ['وقع مشكل', 'Something went wrong', 'Une erreur est survenue'],
  'empty': ['ما كاين والو', 'Nothing here', 'Rien ici'],
  'back': ['رجع', 'Back', 'Retour'],
  'listen': ['سمع', 'Listen', 'Écouter'],
  // field setup
  'field': ['الفلاحة ديالي', 'My field', 'Mon champ'],
  'town': ['المدينة', 'Town', 'Commune'],
  'use_location': ['استعمل موقعي', 'Use my location', 'Utiliser ma position'],
  'loc_far': [
    'أقرب مدينة بعيدة بزاف، اختار يدوي.',
    'Nearest town is too far; please choose one.',
    'La commune la plus proche est trop loin ; choisissez-en une.',
  ],
  'loc_denied': [
    'ما قدرناش نلقاو الموقع.',
    'Could not get your location.',
    'Position indisponible.',
  ],
  'soil': ['عمق التربة', 'Soil depth', 'Profondeur du sol'],
  'soil_shallow': ['قليلة', 'Shallow', 'Faible'],
  'soil_medium': ['متوسطة', 'Medium', 'Moyenne'],
  'soil_deep': ['عميقة', 'Deep', 'Profonde'],
  'prev_crop': [
    'الزراعة اللي فاتت قطنية؟',
    'Previous crop a legume?',
    'Culture précédente = légumineuse ?',
  ],
  'yes': ['إوا', 'Yes', 'Oui'],
  'no': ['لا', 'No', 'Non'],
  'save': ['سجل', 'Save', 'Enregistrer'],
  // futures
  'futures': ['3 مستقبلات', '3 parallel futures', '3 futurs parallèles'],
  'plan_a': [
    'نفس الزراعة 3 مواسم',
    'Same crop, 3 seasons',
    'Même culture, 3 saisons',
  ],
  'plan_b': [
    'دوران مع قطنية',
    'Rotation with a legume',
    'Rotation avec légumineuse',
  ],
  'plan_c': [
    '3 عائلات ديال الزراعة',
    '3 crop families',
    '3 familles de cultures',
  ],
  'all3good': ['3 مواسم مزيانين', 'All 3 seasons good', '3 saisons bonnes'],
  'water_need': ['الما اللي خاص', 'Water needed', 'Eau nécessaire'],
  'water_have': [
    'الما اللي كاين (عادي)',
    'Water available (typical)',
    'Eau disponible (typique)',
  ],
  'missing': ['حاجة ناقصة', 'Missing piece', 'Élément manquant'],
  'missing_q_soil': [
    'شحال عمق التربة ديالك؟',
    'How deep is your soil?',
    'Quelle est la profondeur de votre sol ?',
  ],
  'missing_q_prev': [
    'الزراعة اللي فاتت قطنية؟',
    'Was the previous crop a legume?',
    'La culture précédente était-elle une légumineuse ?',
  ],
  'best_plan': ['الأحسن', 'Best', 'Meilleur'],
  'no_model': [
    'الأشجار ما كاينش ليها حساب هنا',
    'No model for trees',
    'Pas de modèle pour les arbres',
  ],
  // why
  'why_title': [
    'علاش هاد النصيحة؟',
    'Why this advice?',
    'Pourquoi ce conseil ?',
  ],
  'legend_good': ['موسم مزيان ✓', 'Good season ✓', 'Bonne saison ✓'],
  'legend_dry': ['موسم ناشف !', 'Dry season !', 'Saison sèche !'],
  'legend_need': [
    'خط الما اللي خاص',
    'Water-need line',
    'Ligne du besoin en eau',
  ],
  'assumptions': ['الفرضيات', 'Assumptions', 'Hypothèses'],
  'would_change': [
    'شنو يبدل النصيحة',
    'What would change this advice',
    'Ce qui changerait ce conseil',
  ],
  'params': [
    'الأرقام (مستشار)',
    'Parameters (advisor)',
    'Paramètres (conseiller)',
  ],
  'pick_crop': ['اختار زراعة', 'Pick a crop', 'Choisissez une culture'],
  // aquifer
  'aquifer': ['الفرشة المائية', 'Aquifer', 'Nappe'],
  'aq_scenario': [
    'سيناريو، ماشي قياس',
    'Scenario, not measurement',
    'Scénario, pas une mesure',
  ],
  'aq_saving': [
    'نسبة تقليل الما',
    'Share of water saving',
    'Part d’économie d’eau',
  ],
  'aq_years': ['عدد السنين', 'Years', 'Années'],
  'aq_result': [
    'النزول ديال الما فالفرشة',
    'Water table drop',
    'Baisse de la nappe',
  ],
  // guided
  'g_crop': ['أحسن الزراعات', 'Best crops', 'Meilleures cultures'],
  'g_water': [
    'الما اللي خاص لكل زراعة',
    'Water needed per crop',
    'Eau nécessaire par culture',
  ],
  'g_timing': ['الشتا شهر بشهر', 'Rain month by month', 'Pluie mois par mois'],
  'g_timing_note': [
    'الموسم فالحساب من أكتوبر حتى ماي. تواريخ الزراعة بالضبط ما مصدرناهاش بعد.',
    'The model season runs October to May. Exact sowing dates are not sourced yet.',
    'La saison du modèle va d’octobre à mai. Les dates de semis exactes ne sont pas encore sourcées.',
  ],
  'g_risk': [
    'الخطر: مواسم ناشفة',
    'Risk: dry seasons',
    'Risque : saisons sèches',
  ],
  'risk_of': ['خطر', 'Risk', 'Risque'],
  // voice assistant
  'listening': ['كنسمع…', 'Listening…', 'J’écoute…'],
  'cancel': ['إلغاء', 'Cancel', 'Annuler'],
  'not_understood': [
    'ما فهمتش. اختار:',
    'I did not understand. Choose:',
    'Je n’ai pas compris. Choisissez :',
  ],
  'mic_reason': [
    'نحتاجو الميكرو باش نسمعو ليك.',
    'The microphone lets you speak to the app.',
    'Le micro vous permet de parler à l’application.',
  ],
  'mic_denied': [
    'الميكرو ما مسموحش. استعمل الأزرار.',
    'Microphone not allowed. Use the buttons.',
    'Micro refusé. Utilisez les boutons.',
  ],
  'i_crop': ['شنو نزرع', 'Which crop', 'Quelle culture'],
  'i_water': ['شحال ديال الما', 'How much water', 'Combien d’eau'],
  'i_timing': ['فاش نزرع', 'When to plant', 'Quand semer'],
  'i_risk': ['شنو الخطر', 'What risk', 'Quel risque'],
  'i_field': ['بدل الفلاحة', 'Change field', 'Changer de champ'],
  'i_repeat': ['عاود', 'Repeat', 'Répéter'],
  'i_lang': ['بدل اللغة', 'Change language', 'Changer de langue'],
  'i_help': ['عاوني', 'Help', 'Aide'],
  'help_text': [
    'تقدر تقول: شنو نزرع، شحال ديال الما، فاش نزرع، ولا شنو الخطر.',
    'You can say: which crop, how much water, when to plant, or what risk.',
    'Vous pouvez dire : quelle culture, combien d’eau, quand semer ou quel risque.',
  ],
  'auto_detect': [
    'كشف اللغة بالصوت (اختياري)',
    'Auto-detect spoken language (optional)',
    'Détection de la langue (optionnel)',
  ],
  'msa_tts': [
    'صوت النظام (فصحى، ماشي دارجة)',
    'System voice (Standard Arabic, not Darija)',
    'Voix système (arabe standard, pas darija)',
  ],
  'tts_note': [
    'الصوت ديال الدارجة كيتحمل من ملفات صوتية.',
    'Darija voice plays bundled audio clips.',
    'La voix darija utilise des clips audio intégrés.',
  ],
  'place_hint': ['سايس', 'Saïs', 'Saïs'],
  'prov_needs': [
    'حاجيات الما مؤقتة (المصدر باقي).',
    'Water needs are provisional values (source pending).',
    'Besoins en eau provisoires (source à confirmer).',
  ],
  'dry_n': [
    'مواسم ناشفة من 40',
    'dry seasons out of 40',
    'saisons sèches sur 40',
  ],
  'rain30': ['الشتا (30 يوم)', 'Rain (30 d)', 'Pluie (30 j)'],
  'mic_ok': ['كمل', 'Continue', 'Continuer'],
  'apply': ['طبق', 'Apply', 'Appliquer'],
  'typical_now': ['المعتاد دابا', 'Typical today', 'Typique aujourd’hui'],
  'best_for_you': ['الأحسن ليك', 'Best for you', 'Le meilleur pour vous'],
  'seasons_bars': [
    '40 موسم: الشتا (مم)',
    '40 seasons: rain (mm)',
    '40 saisons : pluie (mm)',
  ],
  'rain_needed': ['الشتا اللي خاصها', 'Rain needed', 'Pluie nécessaire'],
  'ch_soil_better': [
    'تربة أعمق كتزيد الما',
    'Deeper soil stores more water',
    'Un sol plus profond stocke plus d’eau',
  ],
  'ch_prev': [
    'قطنية قبل كتنقص الحاجة ديال الما ب 10%',
    'A legume before cuts the water need by 10%',
    'Une légumineuse avant réduit le besoin en eau de 10 %',
  ],
  'ch_crop': [
    'زراعة أخف على الما كتبدل النتيجة',
    'A lighter-water crop changes the result',
    'Une culture moins gourmande change le résultat',
  ],
  'ch_rain': [
    'موسم أشتى أو أنشف كيبدل كلشي',
    'A wetter or drier run of seasons changes it',
    'Une série plus humide ou plus sèche change tout',
  ],
  'as_season': [
    'الموسم: من أكتوبر حتى ماي',
    'Season: October to May',
    'Saison : octobre à mai',
  ],
  'as_avail': [
    'الما اللي كاين = 10 × 0.65 × الشتا + 2400 × عمق التربة',
    'Water available = 10 × 0.65 × rain + 2400 × soil factor',
    'Eau disponible = 10 × 0,65 × pluie + 2400 × facteur sol',
  ],
  'as_need': [
    'الما اللي خاص = حاجة الزراعة × 0.8 (× 0.9 بعد قطنية)',
    'Water needed = crop need × 0.8 (× 0.9 after a legume)',
    'Eau nécessaire = besoin × 0,8 (× 0,9 après légumineuse)',
  ],
  'as_fail': [
    '3% ديال الفشل ماشي من الشتا (مرض، سوق…)',
    '3% non-climate failure (pests, market…)',
    '3 % d’échec hors climat (maladies, marché…)',
  ],
  'as_future': [
    '1000 مستقبل، كل موسم من 40 فاتو',
    '1000 futures, each season drawn from the 40 past ones',
    '1000 futurs, chaque saison tirée parmi les 40 passées',
  ],
  'aq_note': [
    'هادا حساب ديال سيناريو (Δh = −v·(1 − a·s)·t). الأرقام مؤقتة.',
    'A scenario formula (Δh = −v·(1 − a·s)·t). Parameter values are provisional.',
    'Formule de scénario (Δh = −v·(1 − a·s)·t). Paramètres provisoires.',
  ],
  'metres': ['متر', 'm', 'm'],
  'listen_tip': [
    'ضغط على الميكرو وهضر',
    'Tap the mic and speak',
    'Touchez le micro et parlez',
  ],
  'field_summary': ['الفلاحة', 'Field', 'Champ'],
  'edit': ['بدل', 'Edit', 'Modifier'],
  'water_unit': ['م³/هكتار', 'm³/ha', 'm³/ha'],
};

String tr(String key, AppLang lang) {
  final v = _s[key];
  if (v == null) return key;
  return v[lang.index];
}

/// Keys, for the review CSV script and tests.
Iterable<String> get allStringKeys => _s.keys;
List<String>? rawString(String key) => _s[key];
