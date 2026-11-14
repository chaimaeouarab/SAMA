import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/colors.dart';
import '../core/strings.dart';
import '../state/farm_state.dart';
import '../state/results_provider.dart';
import '../state/settings.dart';

/// Short translation helper for widgets.
String Function(String) trOf(WidgetRef ref) {
  final l = ref.watch(langProvider);
  return (k) => tr(k, l);
}

class SamaCard extends StatelessWidget {
  const SamaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(22),
      boxShadow: samaCardShadow,
    ),
    // A transparent Material gives ListTile/ExpansionTile their own ink surface above the coloured box.
    child: Material(type: MaterialType.transparency, child: child),
  );
}

/// Farmer-facing classes. Never colour alone: icon + text.
/// good = Suitable to explore, warn = Use caution, info = More information needed.
enum Status { good, warn, info }

Status statusOfChance(double? p) =>
    p == null ? Status.info : (p >= 0.7 ? Status.good : Status.warn);

class StatusLine extends StatelessWidget {
  const StatusLine(this.status, this.text, {super.key});
  final Status status;
  final String text;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      Status.good => (Icons.check_circle, SamaColors.green),
      Status.warn => (Icons.warning_amber_rounded, SamaColors.amber),
      Status.info => (Icons.help, SamaColors.muted),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// The three farmer labels for a chance (or null = no documented value).
class ChanceStatus extends ConsumerWidget {
  const ChanceStatus(this.chance, {super.key});
  final double? chance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final s = statusOfChance(chance);
    return StatusLine(
      s,
      t(switch (s) {
        Status.good => 'st_suit',
        Status.warn => 'st_caution',
        Status.info => 'st_info',
      }),
    );
  }
}

class SamaTopBar extends StatelessWidget {
  const SamaTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
    child: Row(
      children: [
        SizedBox(
          width: 48,
          child: onBack == null
              ? null
              : IconButton.outlined(
                  onPressed: onBack,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.arrow_forward
                        : Icons.arrow_back,
                  ),
                ),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        SizedBox(width: 48, child: trailing),
      ],
    ),
  );
}

/// "Offline" banner. Core data is bundled, so it only reassures.
class OfflineBadge extends ConsumerWidget {
  const OfflineBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineProvider).value ?? true;
    if (online) return const SizedBox.shrink();
    final t = trOf(ref);
    return _Banner(
      icon: Icons.cloud_off,
      text: t('offline'),
      color: SamaColors.greenTint,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.text,
    required this.color,
    this.action,
  });
  final IconData icon;
  final String text;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: SamaColors.ink),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        ?action,
      ],
    ),
  );
}

/// Shown on every result when the dataset is only the nearest reference, or a what-if is active.
class DataBanners extends ConsumerWidget {
  const DataBanners({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final lang = ref.watch(langProvider);
    final res = ref.watch(climateProvider).value;
    final shock = ref.watch(shockProvider);
    final farm = ref.watch(farmProvider);
    return Column(
      children: [
        if (res != null && res.approximate)
          _Banner(
            icon: Icons.near_me,
            color: const Color(0xFFFBF0D9),
            text:
                '${t('approx_title')}: ${res.referenceName == null ? '' : '${res.referenceName} · '}${res.distanceKm.round()} ${t('km')}',
            action: farm.approxConfirmed
                ? null
                : TextButton(
                    onPressed: () => ref
                        .read(farmsProvider.notifier)
                        .update((f) => f.copyWith(approxConfirmed: true)),
                    child: Text(t('confirm')),
                  ),
          ),
        if (shock.isHypothetical)
          _Banner(
            icon: Icons.science,
            color: const Color(0xFFE3EEF8),
            text: t('whatif'),
          ),
        if (lang == AppLang.ar) const SizedBox.shrink(),
      ],
    );
  }
}

/// Provisional-parameter badge: shown until the FAO tables have been checked by a person.
class ProvisionalBadge extends ConsumerWidget {
  const ProvisionalBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.science_outlined, size: 16, color: SamaColors.amber),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              t('prov_params'),
              style: const TextStyle(
                fontSize: 12,
                color: SamaColors.amber,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Source, honesty and sample notes shown under every result.
class SourceNote extends ConsumerWidget {
  const SourceNote({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          child: Column(
            children: [
              Text(
                t('source_line'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                t('based40'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const ProvisionalBadge(),
      ],
    );
  }
}

class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.height = 80});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    margin: const EdgeInsets.fromLTRB(18, 10, 18, 0),
    decoration: BoxDecoration(
      color: SamaColors.line,
      borderRadius: BorderRadius.circular(18),
    ),
  );
}

/// Loading skeleton, error with retry, then [builder] on data.
class AsyncBody<T> extends ConsumerWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
  });
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    return value.when(
      data: builder,
      loading: () => Column(
        children: [
          const Skeleton(height: 160),
          const Skeleton(),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              t('loading'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 40, color: SamaColors.danger),
            const SizedBox(height: 8),
            Text(t('error'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(t('retry')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Convenience: the model with the standard loading/error handling.
class ModelBody extends ConsumerWidget {
  const ModelBody({super.key, required this.builder});
  final Widget Function(FieldModel m) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncBody(
    value: ref.watch(modelProvider),
    onRetry: () => ref.invalidate(modelProvider),
    builder: builder,
  );
}

class EmptyView extends ConsumerWidget {
  const EmptyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Text(
        trOf(ref)('empty'),
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ),
  );
}

/// A big navigation card used on Explore and elsewhere (>= 56 dp).
class BigCard extends StatelessWidget {
  const BigCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.color = SamaColors.green,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
    child: Semantics(
      button: true,
      label: title,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: SamaCard(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left
                    : Icons.chevron_right,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void goHome(BuildContext context) => context.go('/home');
