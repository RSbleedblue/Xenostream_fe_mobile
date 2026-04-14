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

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Record & lock voice'), findsOneWidget);
  });
}
