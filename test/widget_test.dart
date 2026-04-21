import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xenostream_fe_mobile/app/xenostream_app.dart';
import 'package:xenostream_fe_mobile/core/session/active_voice_profile_store.dart';
import 'package:xenostream_fe_mobile/features/voice_enrollment/data/fake_voice_enrollment_repository.dart';
import 'package:xenostream_fe_mobile/features/voice_synthesis/data/fake_voice_synthesis_repository.dart';

void main() {
  testWidgets('Home hub renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      XenoStreamApp(
        activeVoiceProfileStore: ActiveVoiceProfileStore(),
        voiceEnrollmentRepository: FakeVoiceEnrollmentRepository(),
        voiceSynthesisRepository: FakeVoiceSynthesisRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Capture New'), findsOneWidget);
    expect(find.text('Start Recording'), findsOneWidget);
    expect(find.textContaining('Neural Echo'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -360));
    await tester.pumpAndSettle();

    expect(find.text('Quick Synthesis'), findsOneWidget);
  });
}
