import '../../../shared/domain/voice_profile.dart';
import 'voice_enrollment_repository.dart';

class FakeVoiceEnrollmentRepository implements VoiceEnrollmentRepository {
  @override
  Future<VoiceProfile> enroll({required String localAudioPath, String? name}) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return VoiceProfile(
      id: 'voice_${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now().toUtc(),
      name: name,
    );
  }

  @override
  Future<void> deleteVoice({required String voiceId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}
