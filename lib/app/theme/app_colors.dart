import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Semantic colors mapped from [PrimaryPalette], [SecondaryPalette],
/// [TertiaryPalette], and [NeutralPalette].
///
/// Prefer palette tokens for new surfaces; keep using [AppColors] for
/// consistent imports across existing widgets.
abstract final class AppColors {
  static const Color canvas = PrimaryPalette.p50;
  static const Color primaryPurple = PrimaryPalette.p500;
  static const Color primaryPurpleDeep = SecondaryPalette.s800;
  static const Color accentViolet = TertiaryPalette.t500;
  static const Color card = Colors.white;
  static const Color textPrimary = NeutralPalette.n900;
  static const Color textSecondary = NeutralPalette.n600;
  static const Color chipBackground = NeutralPalette.n100;
  static const Color bannerPurple = PrimaryPalette.p600;
}
