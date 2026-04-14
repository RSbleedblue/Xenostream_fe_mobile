import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_radii.dart';

abstract final class AppTheme {
  /// Hero CTAs: primary brand → tertiary accent.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [PrimaryPalette.p500, TertiaryPalette.t600],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static TextTheme _mergedTextTheme(TextTheme inter, Color onSurface) {
    TextStyle manropeFrom(TextStyle? base) => GoogleFonts.manrope(
          textStyle: base,
          color: onSurface,
          height: base?.height,
        );

    TextStyle interFrom(TextStyle? base) => GoogleFonts.inter(
          textStyle: base,
          color: onSurface,
          height: base?.height,
        );

    return inter.copyWith(
      displayLarge: manropeFrom(inter.displayLarge),
      displayMedium: manropeFrom(inter.displayMedium),
      displaySmall: manropeFrom(inter.displaySmall),
      headlineLarge: manropeFrom(inter.headlineLarge),
      headlineMedium: manropeFrom(inter.headlineMedium),
      headlineSmall: manropeFrom(inter.headlineSmall),
      titleLarge: manropeFrom(inter.titleLarge),
      titleMedium: interFrom(inter.titleMedium),
      titleSmall: interFrom(inter.titleSmall),
      bodyLarge: interFrom(inter.bodyLarge),
      bodyMedium: interFrom(inter.bodyMedium),
      bodySmall: interFrom(inter.bodySmall),
      labelLarge: interFrom(inter.labelLarge),
      labelMedium: interFrom(inter.labelMedium),
      labelSmall: interFrom(inter.labelSmall),
    );
  }

  static ThemeData get light {
    final colorScheme = ColorScheme.light(
      primary: PrimaryPalette.p500,
      onPrimary: Colors.white,
      secondary: SecondaryPalette.s800,
      onSecondary: Colors.white,
      tertiary: TertiaryPalette.t500,
      onTertiary: Colors.white,
      surface: AppColors.card,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.chipBackground,
      outline: NeutralPalette.n300,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
    );

    final interBase = GoogleFonts.interTextTheme(base.textTheme);
    final textTheme = _mergedTextTheme(interBase, AppColors.textPrimary);

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.manrope(
          textStyle: textTheme.titleMedium,
          fontWeight: FontWeight.w600,
          color: PrimaryPalette.p500,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.xlBorder),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: PrimaryPalette.p500,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.lgBorder),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PrimaryPalette.p500,
          side: const BorderSide(color: PrimaryPalette.p500),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.lgBorder),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PrimaryPalette.p500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: AppRadii.lgBorder,
          borderSide: BorderSide(color: NeutralPalette.n300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.lgBorder,
          borderSide: BorderSide(color: NeutralPalette.n300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.lgBorder,
          borderSide: const BorderSide(color: PrimaryPalette.p500, width: 1.5),
        ),
        labelStyle: TextStyle(color: AppColors.textSecondary),
        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.75)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: PrimaryPalette.p500,
        inactiveTrackColor: PrimaryPalette.p500.withValues(alpha: 0.2),
        thumbColor: PrimaryPalette.p500,
        overlayColor: PrimaryPalette.p500.withValues(alpha: 0.12),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: PrimaryPalette.p500,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.card,
        indicatorColor: PrimaryPalette.p500.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? PrimaryPalette.p500 : AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? PrimaryPalette.p500 : AppColors.textSecondary,
          );
        }),
        height: 72,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: PrimaryPalette.p500,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }
}
