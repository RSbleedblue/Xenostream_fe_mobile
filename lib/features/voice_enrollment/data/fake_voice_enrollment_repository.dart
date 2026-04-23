import '../../../shared/domain/voice_profile.dart';
import 'voice_enrollment_repository.dart';

class FakeVoiceEnrollmentRepository implements VoiceEnrollmentRepository {
  @override
  Future<VoiceProfile> enroll({
    required String localAudioPath,
    required String displayName,
    String? details,
    String? tags,
    String? metadata,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return VoiceProfile(
      id: 'voice_${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now().toUtc(),
      name: displayName,
    );
  }

  @override
  Future<void> deleteVoice({required String voiceId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}
