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
    this.previewError,
    this.isPlaying = false,
    this.playbackPosition = Duration.zero,
    this.playbackDuration = Duration.zero,
  });

  final EnrollmentPhase phase;
  final Duration elapsed;
  final String? localRecordingPath;
  final VoiceProfile? profile;
  final String? errorMessage;
  final String? previewError;

  final bool isPlaying;
  final Duration playbackPosition;
  final Duration playbackDuration;

  bool get canSubmit =>
      phase == EnrollmentPhase.readyToSubmit && localRecordingPath != null;

  EnrollmentState copyWith({
    EnrollmentPhase? phase,
    Duration? elapsed,
    String? localRecordingPath,
    VoiceProfile? profile,
    String? errorMessage,
    String? previewError,
    bool? isPlaying,
    Duration? playbackPosition,
    Duration? playbackDuration,
    bool clearRecordingPath = false,
    bool clearError = false,
    bool clearProfile = false,
    bool clearPreviewError = false,
  }) {
    return EnrollmentState(
      phase: phase ?? this.phase,
      elapsed: elapsed ?? this.elapsed,
      localRecordingPath:
          clearRecordingPath ? null : (localRecordingPath ?? this.localRecordingPath),
      profile: clearProfile ? null : (profile ?? this.profile),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      previewError: clearPreviewError
          ? null
          : (previewError ?? this.previewError),
      isPlaying: isPlaying ?? this.isPlaying,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      playbackDuration: playbackDuration ?? this.playbackDuration,
    );
  }

  @override
  List<Object?> get props => [
        phase,
        elapsed,
        localRecordingPath,
        profile,
        errorMessage,
        previewError,
        isPlaying,
        playbackPosition,
        playbackDuration,
      ];
}
