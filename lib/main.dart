import 'package:flutter/material.dart';

import 'app/xenostream_app.dart';
import 'core/session/active_voice_profile_store.dart';
import 'features/voice_enrollment/data/fake_voice_enrollment_repository.dart';
import 'features/voice_synthesis/data/fake_voice_synthesis_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final activeVoiceProfileStore = ActiveVoiceProfileStore();
  final voiceEnrollmentRepository = FakeVoiceEnrollmentRepository();
  final voiceSynthesisRepository = FakeVoiceSynthesisRepository();

  runApp(
    XenoStreamApp(
      activeVoiceProfileStore: activeVoiceProfileStore,
      voiceEnrollmentRepository: voiceEnrollmentRepository,
      voiceSynthesisRepository: voiceSynthesisRepository,
    ),
  );
}
