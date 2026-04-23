/// A voice row returned by the backend (list/upload APIs).
class VoiceUploadResult {
  const VoiceUploadResult({
    required this.voiceId,
    required this.filePath,
  });

  final String voiceId;
  final String filePath;
}
