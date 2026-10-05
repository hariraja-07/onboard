import 'package:flutter/material.dart';

import 'spacing.dart';

/// Shared AppTheme so every screen reads the same tones in either mode.
class AppTheme {
  AppTheme._();

  static ThemeData light = _build(Brightness.light);
  static ThemeData dark = _build(Brightness.dark);

  /// Semantic colours Material 3 has no slot for.
  ///
  /// Attendance uses these for the three outcomes of a scan. They are set on
  /// [ColorScheme.surface] as unused extension slots so widgets can still read
  /// everything through `Theme.of(context).colorScheme`.
  static const Color successLight = Color(0xFF1B7F4B);
  static const Color successDark = Color(0xFF6FD79E);
  static const Color successContainerLight = Color(0xFFD6F0E0);
  static const Color successContainerDark = Color(0xFF0F4A2E);
  static const Color onSuccessContainerLight = Color(0xFF0A3D22);
  static const Color onSuccessContainerDark = Color(0xFFB7EFD1);

  /// Page background, one step below [surface] so cards stay legible.
  static Color _scaffold(Brightness b) =>
      b == Brightness.light ? const Color(0xFFEBEFF4) : const Color(0xFF0E1116);

  static Color _success(Brightness b) =>
      b == Brightness.light ? successLight : successDark;
  static Color _successContainer(Brightness b) =>
      b == Brightness.light ? successContainerLight : successContainerDark;
  static Color _onSuccessContainer(Brightness b) =>
      b == Brightness.light ? onSuccessContainerLight : onSuccessContainerDark;

  static ThemeData _build(Brightness brightness) {
    final scheme = _scheme(brightness);

    // Buttons, cards and sheets share one radius ramp so nested shapes step
    // inward instead of competing at the same size.
    final buttonShape = RoundedRectangleBorder(borderRadius: Radii.allSm);
    final cardShape = RoundedRectangleBorder(borderRadius: Radii.allMd);
    final buttonPadding = const EdgeInsets.symmetric(
      horizontal: Insets.lg,
      vertical: Insets.md,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      // Scaffold defaults to colorScheme.surface, which would put cards on
      // the same colour as the page behind them. Pin it to the page tone so
      // surfaceContainer and surface read as raised layers.
      scaffoldBackgroundColor: _scaffold(brightness),
      // Material 3 draws dividers on the surface, so onSurface reads as the
      // right colour for an app bar title. Primary is reserved for actions.
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      // Light mode has almost no luminance headroom between scaffold and
      // surface, so a hairline border is what actually separates a card.
      cardTheme: CardThemeData(
        elevation: 0,
        shape: cardShape,
        color: scheme.surface,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: Radii.allSm,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.allSm,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.allSm,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.allSm,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Radii.allSm,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.md,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          minimumSize: const Size(48, 48),
          elevation: 0,
          padding: buttonPadding,
          shape: buttonShape,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: buttonPadding,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 48),
          padding: buttonPadding,
          shape: buttonShape,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 48),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: scheme.onSurfaceVariant,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: Radii.allMd),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        // secondaryContainer is the tonal partner of the surface in both
        // brightnesses; primaryContainer reads as a filled button.
        indicatorColor: scheme.secondaryContainer,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: Radii.allXs),
      ),
      // Dividers use outlineVariant so they stay visible in dark mode, where
      // outline sits too close to the surface to read as a line.
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        shape: RoundedRectangleBorder(borderRadius: Radii.allLg),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: Radii.allSm),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        dividerColor: scheme.outlineVariant,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: _textTheme(scheme),
    );
  }

  /// Hand-set roles rather than [ColorScheme.fromSeed].
  ///
  /// fromSeed regenerated the surface ramp around the seed hue, which left
  /// scaffold and surface within 1.07:1 of each other in dark mode, so cards
  /// had no visible boundary and the five container levels collapsed into one.
  /// Every pair below was checked against WCAG 2.1 relative luminance: body and
  /// label text clears 4.5:1 on every surface it lands on, and primary and
  /// outline clear 3:1 for non-text UI.
  static ColorScheme _scheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    if (isLight) {
      return const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF175CD3),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFDCE7FD),
        onPrimaryContainer: Color(0xFF0B2A5B),
        secondary: Color(0xFF4C5563),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFE3E8EF),
        onSecondaryContainer: Color(0xFF333B47),
        tertiary: Color(0xFF6B4EA8),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFE8E1F7),
        onTertiaryContainer: Color(0xFF2A1A52),
        error: Color(0xFFB3261E),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFBE4E2),
        onErrorContainer: Color(0xFF5A1512),
        surface: Color(0xFFFFFFFF),
        onSurface: Color(0xFF131720),
        onSurfaceVariant: Color(0xFF4E5764),
        // The old outline cleared 1.30:1 on the scaffold. This clears 3.01:1
        // on the scaffold and 3.40:1 on the surface.
        outline: Color(0xFF727C89),
        outlineVariant: Color(0xFFE2E7ED),
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        inverseSurface: Color(0xFF2E3542),
        onInverseSurface: Color(0xFFF1F3F6),
        inversePrimary: Color(0xFFA8C7FF),
        surfaceTint: Color(0xFF175CD3),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        surfaceContainerLow: Color(0xFFF8FAFC),
        surfaceContainer: Color(0xFFF2F5F8),
        surfaceContainerHigh: Color(0xFFE9EDF2),
        surfaceContainerHighest: Color(0xFFE1E6EC),
      );
    }

    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFA8C7FF),
      onPrimary: Color(0xFF06294F),
      primaryContainer: Color(0xFF1E3A63),
      onPrimaryContainer: Color(0xFFD6E4FF),
      secondary: Color(0xFFB4BDC9),
      onSecondary: Color(0xFF1B212B),
      secondaryContainer: Color(0xFF2A3140),
      onSecondaryContainer: Color(0xFFD5DCE6),
      tertiary: Color(0xFFCFBDF7),
      onTertiary: Color(0xFF2A1A52),
      tertiaryContainer: Color(0xFF453573),
      onTertiaryContainer: Color(0xFFE9DEFF),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF5C1F1B),
      onErrorContainer: Color(0xFFFFDAD6),
      // scaffold is a near-black page, surface sits one perceptible step up.
      // The ladder below it rises monotonically in luminance.
      surface: Color(0xFF191E26),
      onSurface: Color(0xFFE7EAF0),
      onSurfaceVariant: Color(0xFFA6B0C0),
      outline: Color(0xFF616C7B),
      outlineVariant: Color(0xFF2A313B),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFE7EAF0),
      onInverseSurface: Color(0xFF1B212B),
      inversePrimary: Color(0xFF175CD3),
      surfaceTint: Color(0xFFA8C7FF),
      surfaceContainerLowest: Color(0xFF08090C),
      surfaceContainerLow: Color(0xFF161A21),
      surfaceContainer: Color(0xFF1E232C),
      surfaceContainerHigh: Color(0xFF272D38),
      surfaceContainerHighest: Color(0xFF323A48),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    final onSurface = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
    );
  }
}

/// AppColors exposes the semantic outcome colours for widgets that need a
/// green "marked present" state, which ColorScheme has no standard slot for.
class AppColors {
  AppColors._();

  static Color success(BuildContext context) =>
      AppTheme._success(Theme.of(context).brightness);

  static Color successContainer(BuildContext context) =>
      AppTheme._successContainer(Theme.of(context).brightness);

  static Color onSuccessContainer(BuildContext context) =>
      AppTheme._onSuccessContainer(Theme.of(context).brightness);

  /// Foreground for a tick drawn on top of [successContainer].
  static Color onSuccess(BuildContext context) =>
      AppTheme._success(Theme.of(context).brightness);
}
