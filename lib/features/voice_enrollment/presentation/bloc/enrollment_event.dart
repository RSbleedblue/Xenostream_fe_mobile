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
  const EnrollmentSubmitRequested();
}

final class EnrollmentResetRequested extends EnrollmentEvent {
  const EnrollmentResetRequested();
}
