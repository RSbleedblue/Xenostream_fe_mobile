import '../domain/synthesis_result.dart';
import 'voice_synthesis_repository.dart';

/// Returns a bundled asset so playback works offline when the backend is down.
class FakeVoiceSynthesisRepository implements VoiceSynthesisRepository {
  static const String placeholderAsset = 'assets/audio/placeholder.wav';

  @override
  Future<SynthesisResult> synthesize({
    required String voiceProfileId,
    required String text,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return SynthesisResult(
      voiceProfileId: voiceProfileId,
      text: text,
      audioAssetPath: placeholderAsset,
    );
  }
}
