import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'api_config.dart';
import 'api_exception.dart';

/// Thin HTTP client for the XenoStream FastAPI backend.
///
/// Mirrors the OpenAPI surface:
///   - GET  /healthz
///   - GET  /readyz
///   - POST /v1/voices             (multipart upload)
///   - GET  /v1/voices
///   - DEL  /v1/voices/{voice_id}
///   - POST /v1/tts                (JSON, returns metadata)
///   - POST /v1/tts/file           (JSON, returns WAV bytes)
///   - POST /v1/sts                (multipart, returns WAV bytes)
class XenoStreamApiClient {
  XenoStreamApiClient({required ApiConfig config, http.Client? httpClient})
      : _config = config,
        _http = httpClient ?? http.Client();

  ApiConfig _config;
  final http.Client _http;

  ApiConfig get config => _config;
  set config(ApiConfig value) => _config = value;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(_config.baseUrl);
    final merged = <String, dynamic>{
      ...base.queryParameters,
      if (query != null) ...query,
    };
    return base.replace(
      path: p.posix.join(base.path.isEmpty ? '/' : base.path, path.startsWith('/') ? path.substring(1) : path),
      queryParameters: merged.isEmpty ? null : merged.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Map<String, String> _headers({bool json = false}) {
    final key = _config.apiKey;
    return {
      if (json) 'Content-Type': 'application/json',
      if (key != null && key.isNotEmpty) 'x-api-key': key,
    };
  }

  // ---- Health ----------------------------------------------------------------

  Future<bool> healthz() async {
    final res = await _http.get(_uri('/healthz'));
    return res.statusCode == 200;
  }

  Future<bool> readyz() async {
    final res = await _http.get(_uri('/readyz'));
    return res.statusCode == 200;
  }

  // ---- Voices ----------------------------------------------------------------

  Future<VoiceUploadResult> uploadVoice({
    required String localFilePath,
    String? originalFilename,
  }) async {
    final file = File(localFilePath);
    if (!await file.exists()) {
      throw ApiException(message: 'Recording not found at $localFilePath');
    }

    final req = http.MultipartRequest('POST', _uri('/v1/voices'))
      ..headers.addAll(_headers())
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          localFilePath,
          filename: originalFilename ?? p.basename(localFilePath),
        ),
      );

    final streamed = await _http.send(req);
    final res = await http.Response.fromStream(streamed);
    _ensureOk(res, 'Upload voice');

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return VoiceUploadResult(
      voiceId: decoded['voice_id'] as String,
      filePath: decoded['file_path'] as String,
    );
  }

  Future<List<VoiceUploadResult>> listVoices() async {
    final res = await _http.get(_uri('/v1/voices'), headers: _headers());
    _ensureOk(res, 'List voices');
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final rawList = decoded['voices'] as List<dynamic>? ?? [];
    return rawList
        .cast<Map<String, dynamic>>()
        .map(
          (e) => VoiceUploadResult(
            voiceId: e['voice_id'] as String,
            filePath: e['file_path'] as String,
          ),
        )
        .toList();
  }

  Future<void> deleteVoice(String voiceId) async {
    final res =
        await _http.delete(_uri('/v1/voices/$voiceId'), headers: _headers());
    _ensureOk(res, 'Delete voice');
  }

  // ---- TTS -------------------------------------------------------------------

  /// POST /v1/tts — returns metadata (server-side path only).
  Future<SynthesizeMetadata> synthesizeMetadata({
    required String text,
    String language = 'en',
    String? voiceId,
    double speed = 1.0,
  }) async {
    final res = await _http.post(
      _uri('/v1/tts'),
      headers: _headers(json: true),
      body: jsonEncode({
        'text': text,
        'language': language,
        'voice_id': ?voiceId,
        'speed': speed,
      }),
    );
    _ensureOk(res, 'Synthesize');
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return SynthesizeMetadata(
      requestId: decoded['request_id'] as String,
      outputFile: decoded['output_file'] as String,
      sampleRate: (decoded['sample_rate'] as num).toInt(),
    );
  }

  /// POST /v1/tts/file — returns the rendered WAV bytes directly.
  Future<List<int>> synthesizeWavBytes({
    required String text,
    String language = 'en',
    String? voiceId,
    double speed = 1.0,
  }) async {
    final res = await _http.post(
      _uri('/v1/tts/file'),
      headers: _headers(json: true),
      body: jsonEncode({
        'text': text,
        'language': language,
        'voice_id': ?voiceId,
        'speed': speed,
      }),
    );
    _ensureOk(res, 'Synthesize (file)');
    return res.bodyBytes;
  }

  // ---- Speech-to-speech ------------------------------------------------------

  /// POST /v1/sts — returns the rendered WAV bytes for the cloned voice.
  Future<SpeechToSpeechResult> speechToSpeech({
    required String localAudioPath,
    String? voiceId,
    String? language,
    double speed = 1.0,
  }) async {
    final req = http.MultipartRequest('POST', _uri('/v1/sts'))
      ..headers.addAll(_headers());
    req.fields['speed'] = speed.toString();
    if (voiceId != null) req.fields['voice_id'] = voiceId;
    if (language != null) req.fields['language'] = language;
    req.files.add(await http.MultipartFile.fromPath('file', localAudioPath));

    final streamed = await _http.send(req);
    final res = await http.Response.fromStream(streamed);
    _ensureOk(res, 'Speech-to-speech');

    return SpeechToSpeechResult(
      wavBytes: res.bodyBytes,
      transcript: res.headers['x-transcript'],
      requestId: res.headers['x-request-id'],
    );
  }

  // ---- Internal --------------------------------------------------------------

  void _ensureOk(http.Response res, String action) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    String msg = '$action failed';
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['detail'] is String) {
        msg = decoded['detail'] as String;
      }
    } catch (_) {
      // response wasn't JSON.
    }
    throw ApiException(
      message: msg,
      statusCode: res.statusCode,
      body: res.body,
    );
  }

  void close() => _http.close();
}

/// Result of a POST /v1/voices upload.
class VoiceUploadResult {
  const VoiceUploadResult({required this.voiceId, required this.filePath});
  final String voiceId;
  final String filePath;
}

/// Metadata returned by POST /v1/tts.
class SynthesizeMetadata {
  const SynthesizeMetadata({
    required this.requestId,
    required this.outputFile,
    required this.sampleRate,
  });
  final String requestId;
  final String outputFile;
  final int sampleRate;
}

/// Result of POST /v1/sts — WAV bytes plus optional transcript header.
class SpeechToSpeechResult {
  const SpeechToSpeechResult({
    required this.wavBytes,
    this.transcript,
    this.requestId,
  });
  final List<int> wavBytes;
  final String? transcript;
  final String? requestId;
}
