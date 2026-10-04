import 'package:flutter/material.dart';

/// The app's light and dark palettes.
///
/// Both are built from the same seed so Material 3 widgets (chips, progress
/// bars, nav bar, dialogs) get correct container/outline tones per brightness,
/// while a few surfaces are pinned to OnBoard's brand colours.
class AppTheme {
  AppTheme._();

  static const _primary = Color(0xFF1A73E8);

  static ThemeData light = _build(Brightness.light);
  static ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: _primary,
          brightness: brightness,
        ).copyWith(
          surface: isLight ? const Color(0xFFFFFFFF) : const Color(0xFF16213E),
          surfaceContainerHighest: isLight
              ? const Color(0xFFF1F3F4)
              : const Color(0xFF1F2937),
          outline: isLight ? const Color(0xFFDADCE0) : const Color(0xFF3A4256),
        );

    final scaffold = isLight
        ? const Color(0xFFF8F9FA)
        : const Color(0xFF1A1A2E);
    final appBarBackground = isLight
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF16213E);
    final appBarForeground = isLight ? scheme.primary : Colors.white;
    final onSurface = scheme.onSurface;

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final buttonPadding = const EdgeInsets.symmetric(
      horizontal: 32,
      vertical: 14,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: appBarForeground,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: scheme.surface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: buttonPadding,
          shape: buttonShape,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: buttonPadding,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: buttonPadding,
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: isLight
            ? const Color(0xFFD2E3FC)
            : const Color(0xFF263A63),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? onSurface : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected
                ? (isLight ? scheme.primary : Colors.white)
                : scheme.onSurfaceVariant,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, space: 1),
      dialogTheme: DialogThemeData(backgroundColor: scheme.surface),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: onSurface,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400, color: onSurface),
        displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400, color: onSurface),
        displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: onSurface),
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: onSurface),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: onSurface),
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: onSurface),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: onSurface),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: onSurface),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: onSurface),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: onSurface),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: onSurface),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: onSurface),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: onSurface),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
