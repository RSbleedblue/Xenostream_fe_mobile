import 'package:equatable/equatable.dart';

/// Identifier for a cloned voice profile returned by the backend (stub today).
class VoiceProfile extends Equatable {
  const VoiceProfile({
    required this.id,
    required this.createdAt,
  });

  final String id;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, createdAt];
}
