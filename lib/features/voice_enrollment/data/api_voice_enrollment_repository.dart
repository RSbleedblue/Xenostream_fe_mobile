import '../../../core/api/xenostream_api_client.dart';
import '../../../shared/domain/voice_profile.dart';
import 'voice_enrollment_repository.dart';

/// Uploads the local recording to the backend via POST /v1/voices and
/// returns a [VoiceProfile] populated with the backend's `voice_id`.
class ApiVoiceEnrollmentRepository implements VoiceEnrollmentRepository {
  ApiVoiceEnrollmentRepository({required XenoStreamApiClient client})
      : _client = client;

  final XenoStreamApiClient _client;

  @override
  Future<VoiceProfile> enroll({
    required String localAudioPath,
    required String displayName,
    String? details,
    String? tags,
    String? metadata,
  }) async {
    final uploaded = await _client.uploadVoice(
      localFilePath: localAudioPath,
      displayName: displayName,
      details: details,
      tags: tags,
      metadata: metadata,
    );
    return VoiceProfile(
      id: uploaded.voiceId,
      createdAt: DateTime.now().toUtc(),
      name: displayName,
    );
  }

  @override
  Future<void> deleteVoice({required String voiceId}) async {
    await _client.deleteVoice(voiceId);
  }
}
