import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../data/towns.dart';
import '../../domain/solar.dart';
import '../../state/farm_state.dart';
import '../../state/results_provider.dart';
import '../../state/settings.dart';
import '../../voice/phrase_builder.dart';
import '../../widgets/common.dart';
import '../../widgets/crop_art.dart';
import '../../widgets/language_sheet.dart';
import '../../widgets/speaker.dart';
import '../voice_assistant/voice_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final t = trOf(ref);
    final model = ref.watch(fieldModelProvider);
    final farm = ref.watch(farmProvider);
    final town = townById(farm.townId);
    final now = DateTime.now();
    final h = now.hour;
    final greet = t(
      h < 12
          ? 'greet_morning'
          : h < 18
          ? 'greet_afternoon'
          : 'greet_evening',
    );
    final locale = {'ar': 'ar_MA', 'en': 'en_GB', 'fr': 'fr_FR'}[lang.code]!;
    final date = DateFormat('EEEE dd MMM yyyy', locale).format(now);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 84),
          decoration: const BoxDecoration(
            color: SamaColors.green,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greet,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          date,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          t('my_farm'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => showLanguageSheet(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70, width: 1.5),
                      minimumSize: const Size(56, 44),
                    ),
                    child: Semantics(
                      label: t('change_language'),
                      child: Text(lang.label),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const CircleAvatar(
                    radius: 23,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person_outline, color: SamaColors.green),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                label: t('ask'),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => showVoiceSheet(context),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: SamaColors.green2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.white70),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t('ask'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const Icon(Icons.mic, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -62),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: AsyncBody(
              value: model,
              onRetry: () => ref.invalidate(fieldModelProvider),
              builder: (m) => _WeatherCard(town: town, m: m, now: now),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -50),
          child: Column(
            children: [
              _FieldRow(town: town),
              _Section(
                title: t('know'),
                child: Row(
                  children: [
                    for (final a in const [
                      ('d_crop', Icons.eco_outlined, SamaColors.green, 'crop'),
                      (
                        'd_water',
                        Icons.water_drop_outlined,
                        SamaColors.water,
                        'water',
                      ),
                      (
                        'd_timing',
                        Icons.calendar_month_outlined,
                        SamaColors.amber,
                        'timing',
                      ),
                      (
                        'd_risk',
                        Icons.shield_outlined,
                        SamaColors.danger,
                        'risk',
                      ),
                    ])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Semantics(
                            button: true,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => context.go('/guided/${a.$4}'),
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 96,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: samaCardShadow,
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: a.$3.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(a.$2, color: a.$3),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      t(a.$1),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _Section(
                title: t('best'),
                trailing: TextButton(
                  onPressed: () => context.go('/crops'),
                  child: Text(t('all')),
                ),
                child: AsyncBody(
                  value: model,
                  onRetry: () => ref.invalidate(fieldModelProvider),
                  builder: (m) => SizedBox(
                    height: 140,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final c in m.rankedAnnuals.take(6))
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 12),
                            child: Semantics(
                              button: true,
                              label: c.name(lang.code),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => context.go('/crop/${c.id}'),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: SizedBox(
                                    width: 160,
                                    height: 136,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        CropImage(c),
                                        Align(
                                          alignment:
                                              AlignmentDirectional.bottomStart,
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.fromLTRB(
                                              10,
                                              18,
                                              10,
                                              8,
                                            ),
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Color(0x99000000),
                                                ],
                                              ),
                                            ),
                                            child: Text(
                                              '${c.name(lang.code)} · ${(m.chances[c.id]! * 100).round()}%',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
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
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SourceNote(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                child: Text(
                  t('prov_needs'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class _FieldRow extends ConsumerWidget {
  const _FieldRow({required this.town});
  final Town town;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final lang = ref.watch(langProvider);
    final farm = ref.watch(farmProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: SamaCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.landscape_outlined, color: SamaColors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${town.name(lang.code)} · ${t('soil_${farm.soil.name}')} · ${farm.areaHa} ha',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/field'),
              child: Text(t('edit')),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherCard extends ConsumerWidget {
  const _WeatherCard({required this.town, required this.m, required this.now});
  final Town town;
  final FieldModel m;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final lang = ref.watch(langProvider);
    final c = m.climate;
    String fmt(double? v, int d, [String unit = '']) =>
        v == null ? '–' : '${v.toStringAsFixed(d)}$unit';
    final temp = c.climToday('T2M', now);
    final tmax = c.climToday('T2M_MAX', now);
    final tmin = c.climToday('T2M_MIN', now);
    final wind = c.climToday('WS2M', now);
    final ps = c.climToday('PS', now);
    final sun = sunTimes(
      lat: town.lat,
      lon: town.lon,
      date: now,
      utcOffset: moroccoUtcOffset,
    );
    final nowMin = now.hour * 60.0 + now.minute;

    return SamaCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place, size: 18, color: SamaColors.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${town.name(lang.code)} · ${t('place_hint')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              SpeakerButton(PhraseBuilder.weather(town.id), size: 40),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      temp == null
                          ? '–'
                          : '${temp >= 0 ? '+' : ''}${temp.round()}',
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '°C\nH:${fmt(tmax, 0)}° L:${fmt(tmin, 0)}°',
                          style: const TextStyle(
                            fontSize: 14,
                            color: SamaColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.wb_sunny, color: Color(0xFFFDB441), size: 44),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Stat(t('hum'), fmt(c.climToday('RH2M', now), 0, '%')),
              _Stat(t('rain30'), fmt(c.rainLast30(now), 0, ' mm')),
              _Stat(
                t('wind'),
                wind == null ? '–' : '${(wind * 3.6).round()} km/h',
              ),
              _Stat(
                t('pressure'),
                ps == null ? '–' : '${(ps * 10).round()} hPa',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Sun(t('sunrise'), SunTimes.format(sun.sunrise)),
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: CustomPaint(
                    painter: _ArcPainter(sun.fraction(nowMin)),
                  ),
                ),
              ),
              _Sun(t('sunset'), SunTimes.format(sun.sunset)),
            ],
          ),
          const SizedBox(height: 8),
          // Labelled as climatology, never a live forecast.
          Text(t('wx_typical'), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: SamaColors.muted),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _Sun extends StatelessWidget {
  const _Sun(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 13, color: SamaColors.muted),
      ),
      Text(
        value,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.fraction);
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(4, size.height)
      ..quadraticBezierTo(
        size.width / 2,
        -size.height,
        size.width - 4,
        size.height,
      );
    final metric = path.computeMetrics().first;
    const dash = 4.0;
    final paint = Paint()
      ..color = const Color(0xFFC9D6CE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var d = 0.0; d < metric.length; d += dash * 2) {
      canvas.drawPath(metric.extractPath(d, d + dash), paint);
    }
    final pos = metric.getTangentForOffset(metric.length * fraction)!.position;
    canvas.drawCircle(pos, 5, Paint()..color = const Color(0xFFFDB441));
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.fraction != fraction;
}
