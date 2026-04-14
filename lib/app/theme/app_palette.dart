import 'package:flutter/material.dart';

/// Design-system color scales (10 steps each, **50 = lightest → 900 = darkest**).
///
/// Anchors from the product kit:
/// - **Primary** base … [#5D5CDE] at [p500]
/// - **Secondary** base … [#1E1B4B] at [s800]
/// - **Tertiary** base … [#8B5CF6] at [t500]
/// - **Neutral** canvas … [#F8FAFC] at [n50]
///
/// For numeric shades use [AppPalette.primaryOf] etc.; for named steps use
/// [PrimaryPalette], …; [AppColors] exposes semantic aliases for widgets.
abstract final class PrimaryPalette {
  static const Color p50 = Color(0xFFF4F5FF);
  static const Color p100 = Color(0xFFE8EAFF);
  static const Color p200 = Color(0xFFD0D2FF);
  static const Color p300 = Color(0xFFB0B3FC);
  static const Color p400 = Color(0xFF888CF5);
  /// Kit base
  static const Color p500 = Color(0xFF5D5CDE);
  static const Color p600 = Color(0xFF4A49C9);
  static const Color p700 = Color(0xFF3D3CAB);
  static const Color p800 = Color(0xFF32328A);
  static const Color p900 = Color(0xFF28286A);

  static const List<Color> shades = <Color>[
    p50,
    p100,
    p200,
    p300,
    p400,
    p500,
    p600,
    p700,
    p800,
    p900,
  ];

  /// Material-style index: `50 → 0`, `900 → 9` (returns [p500] if unknown).
  static Color of(int materialShade) {
    final i = switch (materialShade) {
      50 => 0,
      100 => 1,
      200 => 2,
      300 => 3,
      400 => 4,
      500 => 5,
      600 => 6,
      700 => 7,
      800 => 8,
      900 => 9,
      _ => 5,
    };
    return shades[i.clamp(0, shades.length - 1)];
  }
}

abstract final class SecondaryPalette {
  static const Color s50 = Color(0xFFF0F1FA);
  static const Color s100 = Color(0xFFE0E2F2);
  static const Color s200 = Color(0xFFC0C4E5);
  static const Color s300 = Color(0xFF9BA0D4);
  static const Color s400 = Color(0xFF767CC0);
  static const Color s500 = Color(0xFF5A5FA8);
  static const Color s600 = Color(0xFF454A8C);
  static const Color s700 = Color(0xFF353970);
  /// Kit base (navy)
  static const Color s800 = Color(0xFF1E1B4B);
  static const Color s900 = Color(0xFF12102E);

  static const List<Color> shades = <Color>[
    s50,
    s100,
    s200,
    s300,
    s400,
    s500,
    s600,
    s700,
    s800,
    s900,
  ];

  static Color of(int materialShade) {
    final i = switch (materialShade) {
      50 => 0,
      100 => 1,
      200 => 2,
      300 => 3,
      400 => 4,
      500 => 5,
      600 => 6,
      700 => 7,
      800 => 8,
      900 => 9,
      _ => 8,
    };
    return shades[i.clamp(0, shades.length - 1)];
  }
}

abstract final class TertiaryPalette {
  static const Color t50 = Color(0xFFF5F3FF);
  static const Color t100 = Color(0xFFEDE9FE);
  static const Color t200 = Color(0xFFDDD6FE);
  static const Color t300 = Color(0xFFC4B5FC);
  static const Color t400 = Color(0xFFA78BFA);
  /// Kit base (violet)
  static const Color t500 = Color(0xFF8B5CF6);
  static const Color t600 = Color(0xFF7C3AED);
  static const Color t700 = Color(0xFF6D28D9);
  static const Color t800 = Color(0xFF5B21B6);
  static const Color t900 = Color(0xFF4C1D95);

  static const List<Color> shades = <Color>[
    t50,
    t100,
    t200,
    t300,
    t400,
    t500,
    t600,
    t700,
    t800,
    t900,
  ];

  static Color of(int materialShade) {
    final i = switch (materialShade) {
      50 => 0,
      100 => 1,
      200 => 2,
      300 => 3,
      400 => 4,
      500 => 5,
      600 => 6,
      700 => 7,
      800 => 8,
      900 => 9,
      _ => 5,
    };
    return shades[i.clamp(0, shades.length - 1)];
  }
}

abstract final class NeutralPalette {
  /// Kit neutral canvas
  static const Color n50 = Color(0xFFF8FAFC);
  static const Color n100 = Color(0xFFF1F5F9);
  static const Color n200 = Color(0xFFE2E8F0);
  static const Color n300 = Color(0xFFCBD5E1);
  static const Color n400 = Color(0xFF94A3B8);
  static const Color n500 = Color(0xFF64748B);
  static const Color n600 = Color(0xFF475569);
  static const Color n700 = Color(0xFF334155);
  static const Color n800 = Color(0xFF1E293B);
  static const Color n900 = Color(0xFF0F172A);

  static const List<Color> shades = <Color>[
    n50,
    n100,
    n200,
    n300,
    n400,
    n500,
    n600,
    n700,
    n800,
    n900,
  ];

  static Color of(int materialShade) {
    final i = switch (materialShade) {
      50 => 0,
      100 => 1,
      200 => 2,
      300 => 3,
      400 => 4,
      500 => 5,
      600 => 6,
      700 => 7,
      800 => 8,
      900 => 9,
      _ => 0,
    };
    return shades[i.clamp(0, shades.length - 1)];
  }
}

/// Numeric shade lookups (`50` … `900`). Prefer [PrimaryPalette.p500] etc. when static.
abstract final class AppPalette {
  static Color primaryOf(int materialShade) => PrimaryPalette.of(materialShade);

  static Color secondaryOf(int materialShade) => SecondaryPalette.of(materialShade);

  static Color tertiaryOf(int materialShade) => TertiaryPalette.of(materialShade);

  static Color neutralOf(int materialShade) => NeutralPalette.of(materialShade);
}
