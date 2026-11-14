import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../core/strings.dart';
import '../../data/bundled_data_loader.dart';
import '../../state/results_provider.dart';
import '../../state/settings.dart';
import '../../voice/intent_matcher.dart';
import '../../voice/phrase_builder.dart';
import '../../voice/stt/stt_service.dart';
import '../../widgets/language_sheet.dart';
import '../../widgets/speaker.dart';
import '../shock_lab/shock_lab_screen.dart';

Future<void> showVoiceSheet(BuildContext context) {
  final router = GoRouter.of(context);
  final container = ProviderScope.containerOf(context);
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _VoiceSheet(
      router: router,
      container: container,
      messenger: messenger,
      rootContext: context,
    ),
  );
}

enum _Phase { reason, listening, menu }

class _VoiceSheet extends ConsumerStatefulWidget {
  const _VoiceSheet({
    required this.router,
    required this.container,
    required this.messenger,
    required this.rootContext,
  });
  final GoRouter router;
  final ProviderContainer container;
  final ScaffoldMessengerState messenger;
  final BuildContext rootContext;

  @override
  ConsumerState<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends ConsumerState<_VoiceSheet> {
  final _stt = SttService();
  _Phase _phase = _Phase.reason;
  String _transcript = '';
  String? _message; // visible answer / help / not understood
  bool _micProblem = false;

  @override
  void initState() {
    super.initState();
    // Reason first, once. After that the mic starts directly.
    if (ref.read(prefsProvider).getBool('micAsked') ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  @override
  void dispose() {
    _stt.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    await ref.read(prefsProvider).setBool('micAsked', true);
    final status = await _stt.prepare();
    if (!mounted) return;
    if (status != SttStatus.ready) {
      setState(() {
        _phase = _Phase.menu;
        _micProblem = true;
      });
      return;
    }
    setState(() {
      _phase = _Phase.listening;
      _transcript = '';
      _message = null;
    });
    await _stt.listen(ref.read(langProvider), (text, isFinal) {
      if (!mounted) return;
      setState(() => _transcript = text);
      if (isFinal) _handle(text);
    });
  }

  Future<void> _handle(String text) async {
    final data = await ref.read(appDataProvider.future);
    final m = IntentMatcher(data.catalog).match(text);
    if (!mounted) return;
    if (!m.confident) {
      // Low confidence: never guess. Say so and offer buttons.
      final l = ref.read(langProvider);
      setState(() {
        _phase = _Phase.menu;
        _micProblem = false;
        _message = tr('not_understood', l);
      });
      speakWith(widget.container, widget.messenger, const [
        'ui.not_understood',
      ]);
      return;
    }
    await _run(m.intent!, cropId: m.cropId);
  }

  Future<void> _run(Intent intent, {String? cropId}) async {
    final c = widget.container;
    final msg = widget.messenger;
    final r = widget.router;
    final l = ref.read(langProvider);

    switch (intent) {
      case Intent.help:
        setState(() {
          _phase = _Phase.menu;
          _micProblem = false;
          _message = tr('help_text', l);
        });
        speakWith(c, msg, const ['ui.help']);
        return;
      case Intent.repeat:
        final last = c.read(lastSpokenProvider);
        if (mounted) Navigator.of(context).pop();
        if (last.isNotEmpty) speakWith(c, msg, last);
        return;
      case Intent.changeLanguage:
        final root = widget.rootContext;
        Navigator.of(context).pop();
        if (root.mounted) showLanguageSheet(root, ref);
        return;
      case Intent.chooseField:
        Navigator.of(context).pop();
        r.go('/farm/location');
        speakWith(c, msg, PhraseBuilder.answer('field'));
      case Intent.water || Intent.timing || Intent.risk:
        Navigator.of(context).pop();
        r.go('/guided/${intent.name}');
        speakWith(c, msg, PhraseBuilder.answer(intent.name));
      case Intent.rotation:
        Navigator.of(context).pop();
        r.go('/time');
        speakWith(c, msg, PhraseBuilder.answer('rotation'));
      case Intent.explain:
        Navigator.of(context).pop();
        r.go('/why');
        speakWith(c, msg, PhraseBuilder.answer('explain'));
      case Intent.lessRain:
        // Voice-guided simulation: switch on the dry what-if, show it, then say the main change.
        Navigator.of(context).pop();
        c.read(labStateProvider.notifier).lessRain();
        r.go('/shock');
        speakWith(c, msg, PhraseBuilder.answer('lessrain'));
        final model = await c.read(modelProvider.future);
        final start = model.rankedEligible.first.id;
        final res = await c.read(labProvider(start).future);
        final after = res.after;
        if (after != null) {
          await Future<void>.delayed(const Duration(seconds: 6));
          speakWith(
            c,
            msg,
            PhraseBuilder.rotation(res.sequence.first, after.inTen),
          );
        }
      case Intent.cropAdvice:
        Navigator.of(context).pop();
        if (cropId != null) {
          r.go('/crop/$cropId');
          final fm = await c.read(modelProvider.future);
          final crop = fm.catalog.byId(cropId);
          // Trees and crops without a documented value never get a spoken number.
          if (crop.eligible) {
            speakWith(
              c,
              msg,
              PhraseBuilder.advice(cropId, (fm.chance(cropId)! * 10).round()),
            );
          }
        } else {
          r.go('/guided/crop');
          speakWith(c, msg, PhraseBuilder.answer('crop'));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(langProvider);
    String t(String k) => tr(k, l);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_phase == _Phase.reason) ...[
                const Icon(Icons.mic, size: 56, color: SamaColors.green),
                const SizedBox(height: 12),
                Text(
                  t('mic_reason'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _start, child: Text(t('mic_ok'))),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _phase = _Phase.menu),
                  child: Text(t('i_help')),
                ),
              ],
              if (_phase == _Phase.listening) ...[
                Semantics(
                  liveRegion: true,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      color: SamaColors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic, color: Colors.white, size: 52),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _transcript.isEmpty ? t('listening') : _transcript,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t('listen_tip'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(160, 56),
                  ),
                  onPressed: () {
                    _stt.cancel();
                    Navigator.of(context).pop();
                  },
                  child: Text(t('cancel')),
                ),
              ],
              if (_phase == _Phase.menu) ...[
                if (_micProblem)
                  Text(
                    t('mic_denied'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17),
                  ),
                if (_message != null)
                  Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 12),
                // Large buttons for the likely intents (also the whole UI when the mic is denied).
                for (final b in [
                  (Intent.cropAdvice, 'i_crop', Icons.eco_outlined),
                  (Intent.water, 'i_water', Icons.water_drop_outlined),
                  (Intent.lessRain, 'i_less_rain', Icons.cloud_off_outlined),
                  (Intent.rotation, 'i_rotation', Icons.autorenew),
                  (Intent.explain, 'i_explain', Icons.help_outline),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FilledButton.icon(
                      icon: Icon(b.$3),
                      label: Text(t(b.$2)),
                      onPressed: () => _run(b.$1),
                    ),
                  ),
                if (!_micProblem)
                  TextButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.mic),
                    label: Text(t('listen_tip')),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
