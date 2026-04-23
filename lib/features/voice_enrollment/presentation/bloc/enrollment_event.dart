import 'package:equatable/equatable.dart';

sealed class EnrollmentEvent extends Equatable {
  const EnrollmentEvent();

  @override
  List<Object?> get props => [];
}

final class EnrollmentStartRequested extends EnrollmentEvent {
  const EnrollmentStartRequested();
}

final class EnrollmentStopRequested extends EnrollmentEvent {
  const EnrollmentStopRequested();
}

final class EnrollmentAutoStopRequested extends EnrollmentEvent {
  const EnrollmentAutoStopRequested();
}

final class EnrollmentElapsedUpdated extends EnrollmentEvent {
  const EnrollmentElapsedUpdated(this.elapsed);

  final Duration elapsed;

  @override
  List<Object?> get props => [elapsed];
}

final class EnrollmentSubmitRequested extends EnrollmentEvent {
  const EnrollmentSubmitRequested({
    required this.displayName,
    this.details,
    this.tags,
    this.metadata,
  });

  final String displayName;
  final String? details;
  final String? tags;
  final String? metadata;

  @override
  List<Object?> get props => [displayName, details, tags, metadata];
}

final class EnrollmentResetRequested extends EnrollmentEvent {
  const EnrollmentResetRequested();
}

final class EnrollmentPlaybackToggled extends EnrollmentEvent {
  const EnrollmentPlaybackToggled();
}

final class EnrollmentPlaybackPositionChanged extends EnrollmentEvent {
  const EnrollmentPlaybackPositionChanged(this.position);

  final Duration position;

  @override
  List<Object?> get props => [position];
}

final class EnrollmentPlaybackDurationChanged extends EnrollmentEvent {
  const EnrollmentPlaybackDurationChanged(this.duration);

  final Duration duration;

  @override
  List<Object?> get props => [duration];
}

final class EnrollmentPlaybackCompleted extends EnrollmentEvent {
  const EnrollmentPlaybackCompleted();
}

final class EnrollmentPlaybackSeekRequested extends EnrollmentEvent {
  const EnrollmentPlaybackSeekRequested(this.position);

  final Duration position;

  @override
  List<Object?> get props => [position];
}

final class EnrollmentDeleteRecordingRequested extends EnrollmentEvent {
  const EnrollmentDeleteRecordingRequested();
}
