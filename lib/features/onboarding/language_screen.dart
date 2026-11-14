import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/colors.dart';
import '../../core/strings.dart';
import '../../state/settings.dart';
import '../../voice/phrase_builder.dart';
import '../../widgets/speaker.dart';

/// First launch: pick a language. Trilingual title, three 76 dp cards, speaker on each.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.wb_sunny_outlined,
                        color: SamaColors.green,
                        size: 32,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'SAMA',
                        style: TextStyle(
                          color: SamaColors.green,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    'اختار اللغة ديالك',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: SamaColors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose your language',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const Text(
                    'Choisissez votre langue',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 24),
                  for (final l in AppLang.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Semantics(
                        button: true,
                        label: l.label,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () =>
                              ref.read(settingsProvider.notifier).setLang(l),
                          child: Container(
                            height: 76,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: SamaColors.green,
                                width: 2,
                              ),
                              boxShadow: samaCardShadow,
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l.label,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      color: SamaColors.green,
                                    ),
                                  ),
                                ),
                                SpeakerButton(
                                  PhraseBuilder.languageName(l),
                                  lang: l,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
