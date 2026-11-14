import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/strings.dart';
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
    child: child,
  );
}

/// Status is never colour alone: icon + text.
enum Status { good, warn, bad }

class StatusLine extends StatelessWidget {
  const StatusLine(this.status, this.text, {super.key});
  final Status status;
  final String text;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      Status.good => (Icons.check_circle, SamaColors.green),
      Status.warn => (Icons.warning_amber_rounded, SamaColors.amber),
      Status.bad => (Icons.cancel, SamaColors.danger),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(color == SamaColors.green ? icon : icon, size: 18, color: color),
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

/// "Offline" banner. Data is bundled, so it only reassures.
class OfflineBadge extends ConsumerWidget {
  const OfflineBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineProvider).value ?? true;
    if (online) return const SizedBox.shrink();
    final t = trOf(ref);
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SamaColors.greenTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: SamaColors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t('offline'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class SourceNote extends ConsumerWidget {
  const SourceNote({super.key, this.stamp = true});
  final bool stamp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    return Padding(
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
      loading: () => const Column(
        children: [Skeleton(height: 160), Skeleton(), Skeleton()],
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
