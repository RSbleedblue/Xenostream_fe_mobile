import 'package:equatable/equatable.dart';

/// Identifier for a cloned voice profile returned by the backend (stub today).
class VoiceProfile extends Equatable {
  const VoiceProfile({
    required this.id,
    required this.createdAt,
    this.name,
  });

  final String id;
  final DateTime createdAt;
  final String? name;

  String get displayName => name ?? id;

  VoiceProfile copyWith({String? name}) => VoiceProfile(
        id: id,
        createdAt: createdAt,
        name: name ?? this.name,
      );

  @override
  List<Object?> get props => [id, createdAt, name];
}
