import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../core/strings.dart';
import '../../data/crops_catalog.dart';
import '../../domain/monte_carlo.dart';
import '../../domain/rotation.dart';
import '../../domain/scenarios.dart';
import '../../state/results_provider.dart';
import '../../state/settings.dart';
import '../../voice/phrase_builder.dart';
import '../../widgets/common.dart';
import '../../widgets/crop_art.dart';
import '../../widgets/speaker.dart';

/// Time Machine: TODAY -> SEASON 1 -> 2 -> 3 on real NASA seasons and cited assumptions. Not a forecast.
class TimeMachineScreen extends ConsumerStatefulWidget {
  const TimeMachineScreen({super.key, this.cropId});
  final String? cropId;

  @override
  ConsumerState<TimeMachineScreen> createState() => _TimeMachineState();
}

class _TimeMachineState extends ConsumerState<TimeMachineScreen> {
  String? _start;
  String _rot = 'A'; // A | B | C | custom
  List<String>? _custom;
  ClimateYear? _year; // null = all observed seasons

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    final lang = ref.watch(langProvider);
    final advisor = ref.watch(settingsProvider.select((s) => s.advisor));

    return ModelBody(
      builder: (m) {
        final eligible = m.catalog.eligible;
        final startId = _start ?? widget.cropId ?? m.rankedEligible.first.id;
        final start = m.catalog.byId(startId);
        final rotsAsync = ref.watch(rotationsProvider(startId));

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SamaTopBar(
              title: t('tm_title'),
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/explore'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                t('tm_intro'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('start_crop'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  DropdownButton<String>(
                    value: startId,
                    isExpanded: true,
                    items: [
                      for (final c in m.catalog.annuals)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.name(lang.code) + (c.eligible ? '' : '  ?'),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _start = v;
                      _custom = null;
                      if (_rot == 'custom') _rot = 'A';
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t('tm_scenario'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(t('sc_observed')),
                        selected: _year == null,
                        onSelected: (_) => setState(() => _year = null),
                      ),
                      for (final y in ClimateYear.values)
                        ChoiceChip(
                          label: Text(t('sc_${y.name}')),
                          selected: _year == y,
                          onSelected: (_) => setState(() => _year = y),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (!start.eligible)
              Padding(
                padding: const EdgeInsets.all(18),
                child: StatusLine(Status.info, t('tm_need_info')),
              )
            else
              rotsAsync.when(
                loading: () =>
                    const Column(children: [Skeleton(height: 120), Skeleton()]),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(t('error')),
                ),
                data: (rots) => _body(
                  context,
                  m,
                  start,
                  rots,
                  lang.code,
                  advisor,
                  eligible,
                  t,
                ),
              ),
            const SourceNote(),
          ],
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    FieldModel m,
    Crop start,
    List<Rotation> rots,
    String lang,
    bool advisor,
    List<Crop> eligible,
    String Function(String) t,
  ) {
    final byId = {for (final r in rots) r.id: r};
    final cropsOf = <String, List<Crop>>{for (final r in rots) r.id: r.crops};
    final customCrops =
        (_custom ??
                (byId[_rot == 'custom' ? 'A' : _rot] ?? rots.first).crops
                    .map((c) => c.id)
                    .toList())
            .map(m.catalog.byId)
            .toList();
    final seq = _rot == 'custom'
        ? customCrops
        : (cropsOf[_rot] ?? rots.first.crops);

    // Selected rotation's evaluation (custom evaluates on the fly: cheap).
    final res = _rot == 'custom'
        ? evaluateRotation(
            cropIds: [for (final c in seq) c.id],
            matrix: m.matrix,
            futures: m.futures,
            threshold: m.threshold,
          )
        : byId[_rot]?.result;
    final flags = rotationFlags(
      seq,
      m.data.rules,
      previousFamily: m.inputs.previousFamily,
    );
    final ranked = rankRotations(rots);
    final notSeparable = topTwoWithinUncertainty(ranked);
    final yearIdx = _year == null
        ? null
        : scenarioSeasonIndex(m.climate.seasons, _year!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final id in ['A', 'B', 'C'])
                ChoiceChip(
                  label: Text('$id · ${t('rot_$id')}'),
                  selected: _rot == id,
                  onSelected: (_) => setState(() {
                    _rot = id;
                    _custom = null;
                  }),
                ),
              ChoiceChip(
                label: Text(t('rot_custom')),
                selected: _rot == 'custom',
                onSelected: (_) => setState(() {
                  _rot = 'custom';
                  _custom ??= [for (final c in seq) c.id];
                }),
              ),
            ],
          ),
        ),
        if (yearIdx != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            child: StatusLine(
              Status.info,
              '${t('sc_real_year')}: ${seasonLabel(yearIdx)} · ${m.climate.seasons[yearIdx].rainySeasonRain.round()} mm',
            ),
          ),
        // Timeline
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TodayNode(label: t('tm_today')),
                for (var i = 0; i < seq.length; i++)
                  _SeasonCard(
                    index: i,
                    crop: seq[i],
                    lang: lang,
                    model: m,
                    stat: res?.perSeason[i],
                    yearIdx: yearIdx,
                    eligible: eligible,
                    onPick: (id) => setState(() {
                      final l = [for (final c in seq) c.id];
                      l[i] = id;
                      _custom = l;
                      _rot = 'custom';
                    }),
                  ),
              ],
            ),
          ),
        ),
        if (res != null)
          _Summary(
            res: res,
            flags: flags,
            m: m,
            seq: seq,
            yearIdx: yearIdx,
            advisor: advisor,
          ),
        if (notSeparable)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: SamaCard(
              color: const Color(0xFFFBF0D9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusLine(Status.info, t('not_separable')),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => context.go('/detective?crop=${start.id}'),
                    icon: const Icon(Icons.search),
                    label: Text(t('dt_title')),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: Text(
            t('tm_compare'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        _CompareTable(rots: rots, lang: lang),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => context.go('/shock?crop=${start.id}'),
                  child: Text(t('sl_less_rain')),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: const StadiumBorder(),
            ),
            onPressed: () => context.go('/why?crop=${start.id}'),
            child: Text(t('why')),
          ),
        ),
      ],
    );
  }
}

class _TodayNode extends StatelessWidget {
  const _TodayNode({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 76,
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: SamaColors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.flag, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _SeasonCard extends ConsumerWidget {
  const _SeasonCard({
    required this.index,
    required this.crop,
    required this.lang,
    required this.model,
    required this.stat,
    required this.yearIdx,
    required this.eligible,
    required this.onPick,
  });
  final int index;
  final Crop crop;
  final String lang;
  final FieldModel model;
  final SeasonStat? stat;
  final int? yearIdx;
  final List<Crop> eligible;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final m = model;
    // Water numbers: the chosen real season, or the mean over the 40 observed seasons.
    double etc, avail, deficit, fill;
    Status status;
    if (yearIdx != null) {
      final o = m.matrix.at(crop.id, yearIdx!);
      etc = o.etc;
      avail = o.effectiveRain + o.irrigation;
      deficit = o.deficit;
      fill = o.etc > 0 ? (o.eta / o.etc).clamp(0, 1).toDouble() : 1;
      status = (o.ry ?? 0) >= m.threshold ? Status.good : Status.warn;
    } else {
      final s = stat;
      etc = s?.etc ?? 0;
      avail = (s?.effectiveRain ?? 0) + (s?.irrigation ?? 0);
      deficit = s?.deficit ?? 0;
      fill = etc > 0 ? ((etc - deficit) / etc).clamp(0, 1).toDouble() : 1;
      status = statusOfChance(s?.shareGood);
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 10),
      child: SizedBox(
        width: 190,
        child: SamaCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${t('tm_season')} ${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: SamaColors.muted,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _pick(context, ref),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: CropImage(crop),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        crop.name(lang),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const Icon(Icons.edit, size: 16),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${t('etc')}: ${etc.round()} ${t('mm')}',
                style: const TextStyle(fontSize: 13),
              ),
              Text(
                '${t('water_have')}: ${avail.round()} ${t('mm')}',
                style: const TextStyle(fontSize: 13),
              ),
              Text(
                '${t('deficit')}: ${deficit.round()} ${t('mm')}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              // Simple water-level animation: how much of the crop's need was met.
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    Container(height: 14, color: SamaColors.line),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      height: 14,
                      width: 166 * fill,
                      color: SamaColors.water,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              StatusLine(
                status,
                t(switch (status) {
                  Status.good => 'st_suit',
                  Status.warn => 'st_caution',
                  Status.info => 'st_info',
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pick(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                t('pick_crop'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final x in eligible)
              ListTile(
                minTileHeight: 60,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: 44, height: 44, child: CropImage(x)),
                ),
                title: Text(x.name(lang)),
                selected: x.id == crop.id,
                onTap: () {
                  Navigator.pop(c);
                  onPick(x.id);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({
    required this.res,
    required this.flags,
    required this.m,
    required this.seq,
    required this.yearIdx,
    required this.advisor,
  });
  final RotationResult res;
  final List<RotationFlag> flags;
  final FieldModel m;
  final List<Crop> seq;
  final int? yearIdx;
  final bool advisor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final lang = ref.watch(langProvider);
    final x = res.inTen;
    final totalDeficit = res.expectedDeficit;
    // What-if / year: all three seasons use that one real season.
    String? yearLine;
    if (yearIdx != null) {
      final ry = [for (final c in seq) m.matrix.at(c.id, yearIdx!).ry ?? 0];
      final good = ry.every((v) => v >= m.threshold);
      yearLine =
          '${seasonLabel(yearIdx!)}: ${(ry.reduce((a, b) => a + b) / ry.length * 100).round()}% · ${good ? t('all3good') : t('st_caution')}';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: SamaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$x ${t('in10')}',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: SamaColors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatusLine(
                    statusOfChance(res.pAllGood),
                    t('all3good'),
                  ),
                ),
                SpeakerButton(
                  PhraseBuilder.rotation(seq.first.id, x),
                  size: 40,
                ),
              ],
            ),
            if (yearLine != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  yearLine,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '${t('exp_yield')}: ${(res.expectedRy * 100).round()}%   ·   ${t('worst_case')}: ${(res.worst * 100).round()}%',
              style: const TextStyle(fontSize: 15),
            ),
            Text(
              '${t('total_water')}: ${totalDeficit.round()} ${t('mm')}',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              trf('sum_template', lang, [x, (res.expectedRy * 100).round()]),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (flags.isNotEmpty) ...[
              const Divider(),
              Text(
                t('rot_effects'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final f in flags)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: StatusLine(
                    Status.warn,
                    '${t(f.kind == FlagKind.strongAvoid ? 'flag_strong' : 'flag_same')} ${t('flag_source')}',
                  ),
                ),
            ],
            if (seq.any((c) => c.legume))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  t('legume_note'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const Divider(),
            for (var i = 0; i < seq.length; i++)
              _Detail(
                i: i,
                s: res.perSeason[i],
                crop: seq[i],
                lang: lang.code,
                m: m,
                advisor: advisor,
              ),
          ],
        ),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({
    required this.i,
    required this.s,
    required this.crop,
    required this.lang,
    required this.m,
    required this.advisor,
  });
  final int i;
  final SeasonStat s;
  final Crop crop;
  final String lang;
  final FieldModel m;
  final bool advisor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    String pct(double v) => '${(v * 100).round()}%';
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: advisor,
      title: Text(
        '${t('tm_season')} ${i + 1} · ${crop.name(lang)}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${t('share_good')}: ${pct(s.shareGood)}'),
      children: [
        _row(t('et0'), '${s.et0.round()} ${t('mm')}'),
        _row(t('etc'), '${s.etc.round()} ${t('mm')}'),
        _row(t('eff_rain'), '${s.effectiveRain.round()} ${t('mm')}'),
        _row(t('irr_used'), '${s.irrigation.round()} ${t('mm')}'),
        _row(t('deficit'), '${s.deficit.round()} ${t('mm')}'),
        _row(
          t('ry_dist'),
          '${pct(s.ryP10)} / ${pct(s.ryP50)} / ${pct(s.ryP90)}',
        ),
        _row(t('ex_best'), seasonLabel(s.bestSeason)),
        _row(t('ex_worst'), seasonLabel(s.worstSeason)),
      ],
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(k, style: const TextStyle(color: SamaColors.muted)),
        ),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _CompareTable extends ConsumerWidget {
  const _CompareTable({required this.rots, required this.lang});
  final List<Rotation> rots;
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final ranked = rankRotations(rots);
    final bestId = ranked.isEmpty ? null : ranked.first.id;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: SamaCard(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            for (final r in rots)
              ListTile(
                dense: true,
                minTileHeight: 56,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: SamaColors.green,
                  child: Text(
                    r.id,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  r.crops.map((c) => c.name(lang)).join(' → '),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: r.result == null
                    ? Text(t('tm_need_info'))
                    : Text(
                        '${r.result!.inTen} ${t('in10')} · ${t('exp_yield')} ${(r.result!.expectedRy * 100).round()}% · ${t('worst_case')} ${(r.result!.worst * 100).round()}%',
                      ),
                trailing: r.id == bestId
                    ? const Icon(
                        Icons.star,
                        color: SamaColors.amber,
                        semanticLabel: 'best',
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
