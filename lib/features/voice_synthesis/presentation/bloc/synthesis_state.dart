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
    this.selectedVoiceId,
    this.result,
    this.errorMessage,
  });

  final SynthesisPhase phase;
  final String text;
  final String? selectedVoiceId;
  final SynthesisResult? result;
  final String? errorMessage;

  bool get canGenerate => text.trim().isNotEmpty && selectedVoiceId != null;

  SynthesisState copyWith({
    SynthesisPhase? phase,
    String? text,
    String? selectedVoiceId,
    SynthesisResult? result,
    String? errorMessage,
    bool clearResult = false,
    bool clearError = false,
    bool clearVoiceId = false,
  }) {
    return SynthesisState(
      phase: phase ?? this.phase,
      text: text ?? this.text,
      selectedVoiceId: clearVoiceId ? null : (selectedVoiceId ?? this.selectedVoiceId),
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [phase, text, selectedVoiceId, result, errorMessage];
}
