import 'package:equatable/equatable.dart';

/// Outcome of a synthesis request.
///
/// Exactly one of [audioAssetPath] (bundled asset, dev/offline) or
/// [audioFilePath] (local file written after the API returned WAV bytes)
/// is populated.
class SynthesisResult extends Equatable {
  const SynthesisResult({
    required this.voiceProfileId,
    required this.text,
    this.audioAssetPath,
    this.audioFilePath,
  }) : assert(
          (audioAssetPath == null) != (audioFilePath == null),
          'Provide exactly one of audioAssetPath or audioFilePath',
        );

  final String voiceProfileId;
  final String text;

  /// Bundled asset path (e.g. `assets/audio/placeholder.wav`) for the fake repo.
  final String? audioAssetPath;

  /// Absolute path to a locally-cached WAV returned by the backend.
  final String? audioFilePath;

  @override
  List<Object?> get props => [voiceProfileId, text, audioAssetPath, audioFilePath];
}
