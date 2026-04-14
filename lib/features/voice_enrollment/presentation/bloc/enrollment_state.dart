import 'package:equatable/equatable.dart';

import '../../../../shared/domain/voice_profile.dart';

enum EnrollmentPhase {
  idle,
  recording,
  readyToSubmit,
  submitting,
  success,
  failure,
}

final class EnrollmentState extends Equatable {
  const EnrollmentState({
    this.phase = EnrollmentPhase.idle,
    this.elapsed = Duration.zero,
    this.localRecordingPath,
    this.profile,
    this.errorMessage,
  });

  final EnrollmentPhase phase;
  final Duration elapsed;
  final String? localRecordingPath;
  final VoiceProfile? profile;
  final String? errorMessage;

  bool get canSubmit =>
      phase == EnrollmentPhase.readyToSubmit && localRecordingPath != null;

  EnrollmentState copyWith({
    EnrollmentPhase? phase,
    Duration? elapsed,
    String? localRecordingPath,
    VoiceProfile? profile,
    String? errorMessage,
    bool clearRecordingPath = false,
    bool clearError = false,
    bool clearProfile = false,
  }) {
    return EnrollmentState(
      phase: phase ?? this.phase,
      elapsed: elapsed ?? this.elapsed,
      localRecordingPath:
          clearRecordingPath ? null : (localRecordingPath ?? this.localRecordingPath),
      profile: clearProfile ? null : (profile ?? this.profile),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        phase,
        elapsed,
        localRecordingPath,
        profile,
        errorMessage,
      ];
}
