import 'package:flutter/material.dart';

import 'app/xenostream_app.dart';
import 'core/api/api_config.dart';
import 'core/api/xenostream_api_client.dart';
import 'core/session/active_voice_profile_store.dart';
import 'features/voice_enrollment/data/api_voice_enrollment_repository.dart';
import 'features/voice_synthesis/data/api_voice_synthesis_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final apiConfig = ApiConfig.defaults();
  final apiClient = XenoStreamApiClient(config: apiConfig);

  final activeVoiceProfileStore = ActiveVoiceProfileStore();
  final voiceEnrollmentRepository =
      ApiVoiceEnrollmentRepository(client: apiClient);
  final voiceSynthesisRepository =
      ApiVoiceSynthesisRepository(client: apiClient);

  runApp(
    XenoStreamApp(
      apiConfig: apiConfig,
      apiClient: apiClient,
      activeVoiceProfileStore: activeVoiceProfileStore,
      voiceEnrollmentRepository: voiceEnrollmentRepository,
      voiceSynthesisRepository: voiceSynthesisRepository,
    ),
  );
}
