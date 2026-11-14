import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import '../../core/strings.dart';
import '../phrase_catalog.dart';

/// Where a playable clip lives.
class AudioRef {
  const AudioRef.asset(this.path) : isAsset = true;
  const AudioRef.file(this.path) : isAsset = false;
  final String path;
  final bool isAsset;
}

/// One link of the chain: Bundled -> DiskCache -> GradioSpace -> HfInference -> (text only).
abstract class TtsBackend {
  String get name;
  Future<AudioRef?> resolve(Phrase phrase, AppLang lang);
}

/// Folder of pre-generated clips per language (Darija keeps the historical folder name).
String langDir(AppLang l) => l == AppLang.dar ? 'darija' : l.code;

/// Pre-generated clips shipped in the app (scripts/build_phrase_audio.py).
class BundledBackend implements TtsBackend {
  BundledBackend(this._manifest);
  final Future<Set<String>> Function() _manifest;
  @override
  String get name => 'bundled';

  @override
  Future<AudioRef?> resolve(Phrase phrase, AppLang lang) async {
    final path = 'assets/audio/${langDir(lang)}/male/${phrase.id}.mp3';
    return (await _manifest()).contains(path) ? AudioRef.asset(path) : null;
  }
}

Future<File> _cacheFile(Phrase p, AppLang l) async {
  final dir = Directory(
    '${(await getApplicationCacheDirectory()).path}/tts/${langDir(l)}',
  );
  if (!await dir.exists()) await dir.create(recursive: true);
  return File('${dir.path}/${p.id}.mp3');
}

/// Clips downloaded earlier by a network backend.
class DiskCacheBackend implements TtsBackend {
  @override
  String get name => 'cache';

  @override
  Future<AudioRef?> resolve(Phrase phrase, AppLang lang) async {
    final f = await _cacheFile(phrase, lang);
    return await f.exists() ? AudioRef.file(f.path) : null;
  }
}

Future<AudioRef?> _download(
  Dio dio,
  Phrase p,
  AppLang l,
  Future<Response<List<int>>> Function() call,
) async {
  try {
    final r = await call();
    final bytes = r.data;
    if (bytes == null || bytes.isEmpty) return null;
    final f = await _cacheFile(p, l);
    await f.writeAsBytes(bytes);
    return AudioRef.file(f.path);
  } on Object {
    return null; // never throws: the chain moves on, the UI shows text
  }
}

/// Own Space / server. Contract: POST {url} JSON {"text":..., "lang":"ar|en|fr"} -> audio bytes.
/// URL comes from --dart-define=SAMA_TTS_URL, never from code.
class GradioSpaceBackend implements TtsBackend {
  GradioSpaceBackend(this._dio, {this._url = Env.ttsUrl});
  final Dio _dio;
  final String _url;
  @override
  String get name => 'space';

  @override
  Future<AudioRef?> resolve(Phrase phrase, AppLang lang) async {
    if (_url.isEmpty) return null;
    return _download(
      _dio,
      phrase,
      lang,
      () => _dio.post<List<int>>(
        _url,
        data: {'text': phrase.ttsText(lang), 'lang': lang.code},
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 20),
        ),
      ),
    );
  }
}

/// Optional Hugging Face Inference API (--dart-define=HF_TOKEN=..., HF_MODEL=...).
class HfInferenceBackend implements TtsBackend {
  HfInferenceBackend(
    this._dio, {
    this._token = Env.hfToken,
    this._model = Env.hfModel,
  });
  final Dio _dio;
  final String _token;
  final String _model;
  @override
  String get name => 'hf';

  @override
  Future<AudioRef?> resolve(Phrase phrase, AppLang lang) async {
    if (_token.isEmpty || _model.isEmpty) return null;
    return _download(
      _dio,
      phrase,
      lang,
      () => _dio.post<List<int>>(
        'https://api-inference.huggingface.co/models/$_model',
        data: {'inputs': phrase.ttsText(lang)},
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Authorization': 'Bearer $_token'},
          receiveTimeout: const Duration(seconds: 30),
        ),
      ),
    );
  }
}

Future<Set<String>> loadAssetManifest() async {
  final m = await AssetManifest.loadFromAssetBundle(rootBundle);
  return m.listAssets().toSet();
}
