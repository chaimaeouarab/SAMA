import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../data/places.dart';
import '../../state/download_state.dart';
import '../../state/farm_state.dart';
import '../../state/results_provider.dart';
import '../../state/settings.dart';
import '../../widgets/common.dart';
import '../../widgets/speaker.dart';

enum _Mode { none, gps, search, map }

/// Three big options: GPS, search, map. Confirm saves the farm and fetches NASA data for it.
class FarmLocationScreen extends ConsumerStatefulWidget {
  const FarmLocationScreen({super.key, this.addNew = false});

  /// Advisor mode: add another farm instead of changing the current one.
  final bool addNew;

  @override
  ConsumerState<FarmLocationScreen> createState() => _FarmLocationScreenState();
}

class _FarmLocationScreenState extends ConsumerState<FarmLocationScreen> {
  _Mode _mode = _Mode.none;
  LatLng? _pick;
  String _name = '';
  LocationSource _source = LocationSource.map;
  String? _message;
  double? _accuracy;
  bool _busy = false;
  bool _forever = false;
  final _query = TextEditingController();
  final _latC = TextEditingController();
  final _lonC = TextEditingController();
  List<Place> _results = const [];
  bool _searched = false;
  int _tileErrors = 0;
  bool _confirmed = false;

  @override
  void dispose() {
    _query.dispose();
    _latC.dispose();
    _lonC.dispose();
    super.dispose();
  }

  void _select(LatLng p, String name, LocationSource src) {
    setState(() {
      _pick = p;
      _name = name;
      _source = src;
      _latC.text = p.latitude.toStringAsFixed(5);
      _lonC.text = p.longitude.toStringAsFixed(5);
    });
  }

  Future<bool> _askReason() async {
    final t = trOf(ref);
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(t('loc_gps')),
            content: Text(t('gps_reason')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(t('cancel')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(120, 52)),
                onPressed: () => Navigator.pop(c, true),
                child: Text(t('mic_ok')),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Permission is asked only when the button is pressed, after the plain-language reason.
  Future<void> _useGps() async {
    final t = trOf(ref);
    if (!await _askReason() || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
      _forever = false;
      _accuracy = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _message = t('gps_off'));
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() {
          _message = t('gps_denied_forever');
          _forever = true;
        });
        return;
      }
      if (perm == LocationPermission.denied) {
        setState(() => _message = t('gps_denied'));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      final n = nearestPlace(pos.latitude, pos.longitude);
      _select(
        LatLng(pos.latitude, pos.longitude),
        n.km <= 30
            ? placeById(n.place.id).name(ref.read(langProvider).code)
            : '',
        LocationSource.gps,
      );
      setState(() {
        _accuracy = pos.accuracy;
        if (pos.accuracy > 5000) _message = t('gps_low');
      });
    } on TimeoutException {
      setState(() => _message = t('gps_timeout'));
    } on Object {
      setState(() => _message = t('gps_timeout'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _search() {
    setState(() {
      _results = searchPlaces(_query.text);
      _searched = true;
    });
  }

  void _manual() {
    final t = trOf(ref);
    final la = double.tryParse(_latC.text.replaceAll(',', '.'));
    final lo = double.tryParse(_lonC.text.replaceAll(',', '.'));
    if (la == null ||
        lo == null ||
        la < -90 ||
        la > 90 ||
        lo < -180 ||
        lo > 180) {
      setState(() => _message = t('loc_bad_coords'));
      return;
    }
    setState(() => _message = null);
    _select(LatLng(la, lo), '', LocationSource.map);
  }

  String _farmName() {
    if (_name.isNotEmpty) return _name;
    final p = _pick!;
    return '${p.latitude.toStringAsFixed(2)}, ${p.longitude.toStringAsFixed(2)}';
  }

  Future<void> _confirm() async {
    final p = _pick;
    if (p == null) return;
    final n = ref.read(farmsProvider.notifier);
    if (widget.addNew) {
      n.add(
        Farm(
          id: 'x',
          name: _farmName(),
          lat: p.latitude,
          lon: p.longitude,
          source: _source,
        ),
      );
    } else {
      n.update(
        (f) => f.copyWith(
          name: _farmName(),
          lat: p.latitude,
          lon: p.longitude,
          source: _source,
          approxConfirmed: false,
        ),
      );
    }
    setState(() => _confirmed = true);
    ref.read(downloadProvider.notifier).reset();
    // NASA data for these coordinates: background download when online and no exact data yet.
    final online = ref.read(onlineProvider).value ?? true;
    final res = await ref.read(climateProvider.future);
    if (online && res.approximate) {
      unawaited(ref.read(downloadProvider.notifier).start());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    final lang = ref.watch(langProvider);
    final prefs = ref.watch(prefsProvider);
    final acked = prefs.getBool('privacyAck') ?? false;

    if (!acked) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SamaTopBar(
            title: t('priv_title'),
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
          const SizedBox(height: 20),
          const Icon(
            Icons.privacy_tip_outlined,
            size: 56,
            color: SamaColors.green,
          ),
          const SizedBox(height: 16),
          Text(t('priv_body'), style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              await prefs.setBool('privacyAck', true);
              if (mounted) setState(() {});
            },
            child: Text(t('priv_ok')),
          ),
        ],
      );
    }

    final dl = ref.watch(downloadProvider);
    final climate = _confirmed ? ref.watch(climateProvider).value : null;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SamaTopBar(
          title: t('farm_title'),
          onBack: () => context.canPop() ? context.pop() : context.go('/home'),
          trailing: SpeakerButton(const ['farm.choose'], size: 40),
        ),
        if (_confirmed)
          ..._doneSection(context, t, dl, climate)
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final o in [
                  (_Mode.gps, Icons.my_location, 'loc_gps'),
                  (_Mode.search, Icons.search, 'loc_search'),
                  (_Mode.map, Icons.map_outlined, 'loc_map'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(64),
                        backgroundColor: _mode == o.$1
                            ? SamaColors.green
                            : SamaColors.green2,
                      ),
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() {
                                _mode = o.$1;
                                _message = null;
                              });
                              if (o.$1 == _Mode.gps) _useGps();
                            },
                      icon: Icon(o.$2),
                      label: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(t(o.$3)),
                      ),
                    ),
                  ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SamaCard(
                      color: const Color(0xFFFBF0D9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_message!, style: const TextStyle(fontSize: 16)),
                          if (_forever)
                            TextButton(
                              onPressed: Geolocator.openAppSettings,
                              child: Text(t('open_settings')),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (_mode == _Mode.search) _searchPanel(t, lang.code),
                if (_mode == _Mode.map) _mapPanel(t, lang.code),
                if (_mode == _Mode.gps && _pick == null && !_busy)
                  _manualPanel(t),
                if (_pick != null) _selectionCard(t, lang.code),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _doneSection(
    BuildContext context,
    String Function(String) t,
    DownloadState dl,
    dynamic climate,
  ) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: SamaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle, color: SamaColors.green, size: 40),
              const SizedBox(height: 8),
              Text(
                t('farm_selected'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (dl.phase == DownloadPhase.running) ...[
                Text(t('dl_progress')),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: dl.progress == 0 ? null : dl.progress,
                ),
                TextButton(
                  onPressed: ref.read(downloadProvider.notifier).cancel,
                  child: Text(t('dl_cancel')),
                ),
              ],
              if (dl.phase == DownloadPhase.failed ||
                  dl.phase == DownloadPhase.cancelled) ...[
                Text(
                  t('dl_failed'),
                  style: const TextStyle(color: SamaColors.danger),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: ref.read(downloadProvider.notifier).start,
                      child: Text(t('retry')),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              _ApproxAndProvenance(),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: FilledButton(
          onPressed: dl.phase == DownloadPhase.running
              ? null
              : () => context.go('/farm/inputs'),
          child: Text(t('mic_ok')),
        ),
      ),
    ];
  }

  Widget _selectionCard(String Function(String) t, String lang) {
    final p = _pick!;
    final near = nearestPlace(p.latitude, p.longitude);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SamaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place, color: SamaColors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _name.isEmpty ? t('farm_title') : _name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            Text(
              '${t('lat')}: ${p.latitude.toStringAsFixed(5)}   ${t('lon')}: ${p.longitude.toStringAsFixed(5)}',
            ),
            Text(
              '${t('loc_nearest')}: ${near.place.name(lang)} · ${near.km.round()} ${t('km')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_accuracy != null)
              Text(
                '${t('gps_accuracy')} ${_accuracy!.round()} ${t('metres')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (!insideMorocco(p.latitude, p.longitude))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: StatusLine(Status.warn, t('outside_morocco')),
              ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _confirm, child: Text(t('loc_confirm'))),
          ],
        ),
      ),
    );
  }

  Widget _manualPanel(String Function(String) t) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(t('gps_reason'), style: Theme.of(context).textTheme.bodySmall),
  );

  Widget _coordFields(String Function(String) t) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _latC,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: t('lat'),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _lonC,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: t('lon'),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: _manual,
        child: Text(t('loc_manual')),
      ),
    ],
  );

  Widget _searchPanel(String Function(String) t, String lang) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search on submit only (never per keystroke); bundled gazetteer, no network and no privacy cost.
        TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: t('loc_search_hint'),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: _search,
              tooltip: t('loc_search'),
            ),
          ),
        ),
        if (_searched && _results.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(t('loc_no_results')),
          ),
        for (final p in _results)
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.place_outlined),
            title: Text(p.name(lang)),
            subtitle: Text(p.region),
            onTap: () => _select(
              LatLng(p.lat, p.lon),
              p.name(lang),
              LocationSource.search,
            ),
          ),
        const SizedBox(height: 8),
        _coordFields(t),
      ],
    ),
  );

  Widget _mapPanel(String Function(String) t, String lang) {
    final canMap = Env.tileUrl.isNotEmpty && _tileErrors < 6;
    if (!canMap) {
      // Accessible offline selector: no broken grey map.
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Env.tileUrl.isEmpty ? t('map_no_tiles') : t('map_offline')),
            const SizedBox(height: 8),
            Text(
              t('ref_places'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final p in places)
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.place_outlined),
                title: Text(p.name(lang)),
                subtitle: Text(p.region),
                onTap: () => _select(
                  LatLng(p.lat, p.lon),
                  p.name(lang),
                  LocationSource.preset,
                ),
              ),
            _coordFields(t),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('map_tap'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 340,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _pick ?? const LatLng(33.8, -5.4),
                  initialZoom: _pick == null ? 7 : 10,
                  onTap: (_, p) => _select(p, '', LocationSource.map),
                ),
                children: [
                  TileLayer(
                    urlTemplate: Env.tileUrl,
                    userAgentPackageName: 'ma.sama.sama',
                    errorTileCallback: (_, _, _) {
                      if (mounted) setState(() => _tileErrors++);
                    },
                  ),
                  if (_pick != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _pick!,
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.location_on,
                            color: SamaColors.danger,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  if (Env.tileAttribution.isNotEmpty)
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(Env.tileAttribution),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _coordFields(t),
        ],
      ),
    );
  }
}

/// Provenance and approximation status of the dataset that now answers for the farm.
class _ApproxAndProvenance extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final res = ref.watch(climateProvider).value;
    if (res == null) return const SizedBox.shrink();
    final c = res.climate;
    final cell = c.cellText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('grid_note').replaceFirst('%s', cell),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          '${t('coverage')}: ${c.coverageText} · ${(c.missingShare * 100).toStringAsFixed(1)}% ${t('missing_days')}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (res.approximate) ...[
          const SizedBox(height: 8),
          StatusLine(
            Status.warn,
            '${t('approx_title')}: ${t('approx_body')} ${res.referenceName} (${res.distanceKm.round()} ${t('km')})',
          ),
          const DataBanners(),
        ],
      ],
    );
  }
}
