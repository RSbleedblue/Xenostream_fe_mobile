import 'package:equatable/equatable.dart';

import '../../domain/synthesis_result.dart';

enum SynthesisPhase {
  idle,
  generating,
  ready,
  playing,
  failure,
}

final class SynthesisState extends Equatable {
  const SynthesisState({
    this.phase = SynthesisPhase.idle,
    this.text = '',
    this.result,
    this.errorMessage,
  });

  final SynthesisPhase phase;
  final String text;
  final SynthesisResult? result;
  final String? errorMessage;

  bool get canGenerate => text.trim().isNotEmpty;

  SynthesisState copyWith({
    SynthesisPhase? phase,
    String? text,
    SynthesisResult? result,
    String? errorMessage,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return SynthesisState(
      phase: phase ?? this.phase,
      text: text ?? this.text,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [phase, text, result, errorMessage];
}
