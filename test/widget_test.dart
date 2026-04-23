import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xenostream_fe_mobile/app/xenostream_app.dart';
import 'package:xenostream_fe_mobile/core/api/api_config.dart';
import 'package:xenostream_fe_mobile/core/api/xenostream_api_client.dart';
import 'package:xenostream_fe_mobile/core/session/active_voice_profile_store.dart';
import 'package:xenostream_fe_mobile/features/voice_enrollment/data/fake_voice_enrollment_repository.dart';
import 'package:xenostream_fe_mobile/features/voice_synthesis/data/fake_voice_synthesis_repository.dart';

void main() {
  testWidgets('Home hub renders', (WidgetTester tester) async {
    const config = ApiConfig(baseUrl: 'http://localhost:8000');
    await tester.pumpWidget(
      XenoStreamApp(
        apiConfig: config,
        apiClient: XenoStreamApiClient(config: config),
        activeVoiceProfileStore: ActiveVoiceProfileStore(),
        voiceEnrollmentRepository: FakeVoiceEnrollmentRepository(),
        voiceSynthesisRepository: FakeVoiceSynthesisRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Capture New'), findsOneWidget);
    expect(find.text('Start Recording'), findsOneWidget);
    expect(find.text('How to use it'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -360));
    await tester.pumpAndSettle();

    expect(find.text('Quick Synthesis'), findsOneWidget);
  });
}
