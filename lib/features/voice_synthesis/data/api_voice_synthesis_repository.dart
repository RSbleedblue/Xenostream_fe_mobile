import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/api/xenostream_api_client.dart';
import '../domain/synthesis_result.dart';
import 'voice_synthesis_repository.dart';

/// Calls POST /v1/tts/file to retrieve WAV bytes, persists them into the app's
/// temporary directory, and returns a [SynthesisResult] pointing at the local
/// file so `just_audio` can play it via `setFilePath`.
class ApiVoiceSynthesisRepository implements VoiceSynthesisRepository {
  ApiVoiceSynthesisRepository({
    required XenoStreamApiClient client,
    this.language = 'en',
    this.speed = 1.0,
  }) : _client = client;

  final XenoStreamApiClient _client;
  final String language;
  final double speed;

  @override
  Future<SynthesisResult> synthesize({
    required String voiceProfileId,
    required String text,
  }) async {
    final bytes = await _client.synthesizeWavBytes(
      text: text,
      language: language,
      voiceId: voiceProfileId,
      speed: speed,
    );

    final dir = await getTemporaryDirectory();
    final filePath = p.join(
      dir.path,
      'synthesis_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    return SynthesisResult(
      voiceProfileId: voiceProfileId,
      text: text,
      audioFilePath: filePath,
    );
  }
}
