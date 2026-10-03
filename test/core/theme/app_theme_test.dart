import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/theme/app_theme.dart';

void main() {
  test('light and dark themes expose matching brightness schemes', () {
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(AppTheme.light.colorScheme.brightness, Brightness.light);
    expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
  });

  test('surfaces differ per brightness and are wired into widgets', () {
    expect(
      AppTheme.light.colorScheme.surface,
      isNot(AppTheme.dark.colorScheme.surface),
    );

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(theme.scaffoldBackgroundColor, isNotNull);
      expect(theme.navigationBarTheme.indicatorColor, isNotNull);
      expect(theme.chipTheme.backgroundColor, isNotNull);
      expect(theme.dividerTheme.color, theme.colorScheme.outline);
      expect(theme.dialogTheme.backgroundColor, theme.colorScheme.surface);
      expect(theme.progressIndicatorTheme.color, theme.colorScheme.primary);
    }
  });

  test('text and app bar foregrounds stay legible per brightness', () {
    expect(
      AppTheme.light.appBarTheme.foregroundColor,
      AppTheme.light.colorScheme.primary,
    );
    expect(AppTheme.dark.appBarTheme.foregroundColor, Colors.white);

    expect(
      AppTheme.light.textTheme.headlineSmall?.color,
      AppTheme.light.colorScheme.onSurface,
    );
    expect(
      AppTheme.dark.textTheme.headlineSmall?.color,
      AppTheme.dark.colorScheme.onSurface,
    );
  });
}
