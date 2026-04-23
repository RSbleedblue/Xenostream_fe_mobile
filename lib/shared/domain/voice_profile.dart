import 'package:equatable/equatable.dart';

/// Identifier for a cloned voice profile returned by the backend (stub today).
class VoiceProfile extends Equatable {
  const VoiceProfile({
    required this.id,
    required this.createdAt,
  });

  final String id;
  final DateTime createdAt;

  /// Short label for pickers and headers.
  String get displayName {
    if (id.length <= 20) {
      return id;
    }
    return '${id.substring(0, 8)}…';
  }

  @override
  List<Object?> get props => [id, createdAt];
}
