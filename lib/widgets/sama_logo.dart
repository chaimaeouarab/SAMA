import 'package:flutter/material.dart';

/// The SAMA logo (leaf + wordmark + tagline). Transparent PNG.
/// [white] is an all-white version for dark or photo backgrounds.
class SamaLogo extends StatelessWidget {
  const SamaLogo({super.key, this.height = 64, this.white = false});
  final double height;
  final bool white;

  @override
  Widget build(BuildContext context) => Image.asset(
    white
        ? 'assets/images/brand/sama_logo_white.png'
        : 'assets/images/brand/sama_logo.png',
    height: height,
    fit: BoxFit.contain,
    semanticLabel: 'SAMA',
    errorBuilder: (_, _, _) => Text(
      'SAMA',
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 24,
        color: white ? Colors.white : null,
      ),
    ),
  );
}
