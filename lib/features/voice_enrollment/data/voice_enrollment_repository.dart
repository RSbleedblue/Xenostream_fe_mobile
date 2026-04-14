import '../../../shared/domain/voice_profile.dart';

abstract class VoiceEnrollmentRepository {
  /// Uploads or registers the local recording and returns a [VoiceProfile].
  Future<VoiceProfile> enroll({required String localAudioPath});
}
