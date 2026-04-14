import 'package:flutter/foundation.dart';

import '../../shared/domain/voice_profile.dart';

/// Holds the voice profile produced by enrollment for use in synthesis.
///
/// Replace with secure persistence or session tokens when wiring a real API.
class ActiveVoiceProfileStore extends ChangeNotifier {
  VoiceProfile? _profile;

  VoiceProfile? get profile => _profile;

  void setProfile(VoiceProfile profile) {
    _profile = profile;
    notifyListeners();
  }

  void clear() {
    _profile = null;
    notifyListeners();
  }
}
