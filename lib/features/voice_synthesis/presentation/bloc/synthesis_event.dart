import 'package:equatable/equatable.dart';

sealed class SynthesisEvent extends Equatable {
  const SynthesisEvent();

  @override
  List<Object?> get props => [];
}

final class SynthesisTextChanged extends SynthesisEvent {
  const SynthesisTextChanged(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

final class SynthesisGenerateRequested extends SynthesisEvent {
  const SynthesisGenerateRequested();
}

final class SynthesisPlayPauseToggled extends SynthesisEvent {
  const SynthesisPlayPauseToggled();
}

final class SynthesisPlaybackEnded extends SynthesisEvent {
  const SynthesisPlaybackEnded();
}

final class SynthesisResultCleared extends SynthesisEvent {
  const SynthesisResultCleared();
}
