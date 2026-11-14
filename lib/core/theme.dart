import 'package:flutter/material.dart';

import 'colors.dart';

// Noto Sans Arabic is listed as fallback; bundle the font file (see docs/OPEN_ITEMS.md).
const _fallback = ['Noto Sans Arabic', 'Noto Naskh Arabic'];

ThemeData samaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SamaColors.green,
    primary: SamaColors.green,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: SamaColors.bg,
    fontFamilyFallback: _fallback,
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: SamaColors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: SamaColors.ink,
      ),
      bodyLarge: TextStyle(fontSize: 17, color: SamaColors.ink),
      bodyMedium: TextStyle(fontSize: 16, color: SamaColors.ink),
      bodySmall: TextStyle(fontSize: 13, color: SamaColors.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        backgroundColor: SamaColors.green,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: SamaColors.green,
      thumbColor: SamaColors.green,
    ),
  );
}
