import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'voice_upload_result.dart';

/// Thin HTTP client for voice list/delete. Tweak paths to match your backend.
class XenoStreamApiClient {
  XenoStreamApiClient(this._config);

  final ApiConfig _config;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (_config.apiKey.isNotEmpty) 'Authorization': 'Bearer ${_config.apiKey}',
      };

  Future<List<VoiceUploadResult>> listVoices() async {
    if (_config.baseUrl.isEmpty) {
      return [];
    }
    final uri = Uri.parse('${_config.baseUrl}/voices');
    try {
      final r = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 12));
      if (r.statusCode < 200 || r.statusCode >= 300) {
        return [];
      }
      final dynamic data = jsonDecode(utf8.decode(r.bodyBytes));
      if (data is! List) return [];
      return data.map((dynamic e) {
        if (e is! Map) {
          return null;
        }
        final m = Map<String, dynamic>.from(e);
        final id = m['voice_id'] as String? ?? m['id'] as String? ?? m['voiceId'] as String?;
        final path = m['file_path'] as String? ?? m['path'] as String? ?? m['filePath'] as String? ?? '';
        if (id == null) return null;
        return VoiceUploadResult(voiceId: id, filePath: path);
      }).whereType<VoiceUploadResult>().toList();
    } on Exception {
      return [];
    }
  }

  Future<void> deleteVoice(String voiceId) async {
    final uri = Uri.parse('${_config.baseUrl}/voices/$voiceId');
    final r = await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 12));
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Delete failed (${r.statusCode})');
    }
  }
}
