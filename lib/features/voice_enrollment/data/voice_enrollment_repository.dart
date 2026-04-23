import '../../../shared/domain/voice_profile.dart';

abstract class VoiceEnrollmentRepository {
  /// Uploads or registers the local recording and returns a [VoiceProfile].
  Future<VoiceProfile> enroll({
    required String localAudioPath,
    required String displayName,
    String? details,
    String? tags,
    String? metadata,
  });

  /// Deletes a previously uploaded voice profile from the backend.
  Future<void> deleteVoice({required String voiceId});
}
