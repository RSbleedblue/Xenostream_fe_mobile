import '../domain/synthesis_result.dart';

abstract class VoiceSynthesisRepository {
  Future<SynthesisResult> synthesize({
    required String voiceProfileId,
    required String text,
  });
}
