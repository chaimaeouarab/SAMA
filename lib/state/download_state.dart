import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/nasa_client.dart';
import 'farm_state.dart';
import 'results_provider.dart';

enum DownloadPhase { idle, running, done, failed, cancelled }

class DownloadState {
  const DownloadState(this.phase, [this.progress = 0]);
  final DownloadPhase phase;
  final double progress;
}

/// Background NASA POWER download for the current farm: progress, retry/backoff (in [NasaClient]), cancel.
/// The result is cached on disk keyed by rounded coordinates; no coordinates are logged.
class DownloadController extends Notifier<DownloadState> {
  CancelToken? _cancel;

  @override
  DownloadState build() => const DownloadState(DownloadPhase.idle);

  Future<void> start() async {
    if (state.phase == DownloadPhase.running) return;
    final farm = ref.read(farmProvider);
    _cancel = CancelToken();
    state = const DownloadState(DownloadPhase.running);
    try {
      final raw = await ref
          .read(nasaClientProvider)
          .fetchRaw(
            farm.lat,
            farm.lon,
            cancel: _cancel,
            onProgress: (p) => state = DownloadState(DownloadPhase.running, p),
          );
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final json = await buildFromRaw(raw, farm.lat, farm.lon, today);
      await ref.read(datasetCacheProvider).write(farm.lat, farm.lon, json);
      ref
          .read(datasetVersionProvider.notifier)
          .bump(); // recompute everything with the new dataset
      state = const DownloadState(DownloadPhase.done, 1);
    } on DioException catch (e) {
      state = DownloadState(
        CancelToken.isCancel(e)
            ? DownloadPhase.cancelled
            : DownloadPhase.failed,
      );
    } on Object {
      state = const DownloadState(DownloadPhase.failed);
    }
  }

  void cancel() => _cancel?.cancel();
  void reset() => state = const DownloadState(DownloadPhase.idle);
}

final downloadProvider = NotifierProvider<DownloadController, DownloadState>(
  DownloadController.new,
);
