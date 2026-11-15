import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/colors.dart';
import '../../core/strings.dart';
import '../../state/settings.dart';
import '../../voice/phrase_builder.dart';
import '../../widgets/motion.dart';
import '../../widgets/sama_logo.dart';
import '../../widgets/speaker.dart';

/// First launch. A hero with a real crop photo and the logo, then four language cards
/// (each in its own script, with a speaker). Everything is shown in all four languages at once.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  static const _badge = {
    AppLang.dar: 'د',
    AppLang.ar: 'ع',
    AppLang.en: 'EN',
    AppLang.fr: 'FR',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: SamaColors.bg,
        body: SingleChildScrollView(
          child: Column(
            children: [
              const _Hero(),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FadeSlideIn(
                      index: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'اختار اللغة ديالك',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: SamaColors.green,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Choose your language',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: SamaColors.ink,
                            ),
                          ),
                          Text(
                            'Choisissez votre langue',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: SamaColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (var i = 0; i < AppLang.values.length; i++)
                      FadeSlideIn(
                        index: i + 2,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _LangCard(
                            lang: AppLang.values[i],
                            badge: _badge[AppLang.values[i]]!,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    const FadeSlideIn(index: 7, child: _TrustRow()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
      child: SizedBox(
        height: 330,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/crops/barley.jpg',
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: SamaColors.green),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    SamaColors.green.withValues(alpha: 0.55),
                    SamaColors.green.withValues(alpha: 0.82),
                    SamaColors.green,
                  ],
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // White logo straight on the photo: no background box.
                    const FadeSlideIn(child: SamaLogo(height: 74, white: true)),
                    const Spacer(),
                    const FadeSlideIn(
                      index: 1,
                      child: Text(
                        'The sky still tells us when to plant',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          height: 1.12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const FadeSlideIn(
                      index: 2,
                      child: Text(
                        'السما كتقول لينا فاش نزرعو · Le ciel nous dit quand semer',
                        style: TextStyle(
                          color: Color(0xFFE3F0E8),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangCard extends ConsumerWidget {
  const _LangCard({required this.lang, required this.badge});
  final AppLang lang;
  final String badge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: lang.label,
      child: Material(
        color: Colors.white,
        elevation: 3,
        shadowColor: const Color(0x330C5A3B),
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => ref.read(settingsProvider.notifier).setLang(lang),
          child: Container(
            height: 84,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: SamaColors.greenTint, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [SamaColors.green2, SamaColors.green],
                    ),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.label,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: SamaColors.green,
                        ),
                      ),
                      Text(
                        tr('lang_sub_${lang.code}', AppLang.en),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: SamaColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                SpeakerButton(PhraseBuilder.languageName(lang), lang: lang),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData i, String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SamaColors.greenTint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 16, color: SamaColors.green),
          const SizedBox(width: 6),
          Text(
            t,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: SamaColors.green,
            ),
          ),
        ],
      ),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        chip(Icons.satellite_alt, 'NASA POWER'),
        chip(Icons.science_outlined, 'FAO-56'),
        chip(Icons.wifi_off, 'Offline'),
      ],
    );
  }
}
