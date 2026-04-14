import 'package:equatable/equatable.dart';

/// Outcome of a synthesis request (local asset path or file URL from API).
class SynthesisResult extends Equatable {
  const SynthesisResult({
    required this.voiceProfileId,
    required this.text,
    required this.audioAssetPath,
  });

  final String voiceProfileId;
  final String text;
  /// Path usable with [just_audio] `setAsset`, e.g. `assets/audio/placeholder.wav`.
  final String audioAssetPath;

  @override
  List<Object?> get props => [voiceProfileId, text, audioAssetPath];
}
