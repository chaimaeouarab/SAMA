import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/colors.dart';
import '../state/settings.dart';
import 'common.dart';
import 'language_sheet.dart';
import 'sama_logo.dart';

/// Advisor mode has its own accent so the two roles are visibly different at a glance.
const advisorColor = Color(0xFF1D5F8A);

/// The SAMA logo stays at the top of every screen, with the role badge and the language button.
class LogoBar extends ConsumerWidget {
  const LogoBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final advisor = ref.watch(settingsProvider.select((s) => s.advisor));
    final accent = advisor ? advisorColor : SamaColors.green;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: accent.withValues(alpha: 0.25), width: 2),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.go('/home'),
            child: const SamaLogo(height: 38),
          ),
          const Spacer(),
          // Role badge: icon + word (never colour alone); tap opens settings to switch role.
          Semantics(
            button: true,
            label: t(advisor ? 'badge_advisor' : 'badge_farmer'),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.go('/me'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      advisor ? Icons.analytics_outlined : Icons.eco_outlined,
                      size: 17,
                      color: accent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      t(advisor ? 'badge_advisor' : 'badge_farmer'),
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: t('change_language'),
            onPressed: () => showLanguageSheet(context, ref),
            icon: Icon(Icons.translate, color: accent),
          ),
        ],
      ),
    );
  }
}
