import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/theme/app_theme.dart';
import 'package:onboard/core/theme/spacing.dart';

/// Relative luminance per WCAG 2.1.
double _luminance(Color c) {
  double channel(double v) {
    return v <= 0.03928
        ? v / 12.92
        : ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055);
  }

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final first = _luminance(a);
  final second = _luminance(b);
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

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
      expect(theme.progressIndicatorTheme.color, theme.colorScheme.primary);
    }
  });

  test('scaffold and surface are distinct in both brightnesses', () {
    // A card drawn in `surface` has to be separable from the page behind it.
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(
        theme.scaffoldBackgroundColor,
        isNot(theme.colorScheme.surface),
        reason: 'cards would be invisible on an identical scaffold',
      );
      expect(
        _contrast(theme.scaffoldBackgroundColor, theme.colorScheme.surface),
        greaterThanOrEqualTo(1.12),
      );
    }
  });

  test('container levels step monotonically away from the scaffold', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final scheme = theme.colorScheme;
      final isLight = theme.brightness == Brightness.light;
      // Light mode steps down from the surface; dark mode steps up from the
      // scaffold. Both ladders are checked against their own base.
      final ladder = <Color>[
        isLight ? scheme.surfaceContainerLowest : theme.scaffoldBackgroundColor,
        scheme.surfaceContainerLow,
        scheme.surfaceContainer,
        scheme.surfaceContainerHigh,
        scheme.surfaceContainerHighest,
      ];

      for (var i = 1; i < ladder.length; i++) {
        final delta = _luminance(ladder[i]) - _luminance(ladder[i - 1]);
        if (isLight) {
          expect(delta, lessThan(0.0), reason: 'level $i must darken');
        } else {
          expect(delta, greaterThan(0.0), reason: 'level $i must lighten');
        }
      }
    }
  });

  test('body and label text clears 4.5:1 on every surface it sits on', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final scheme = theme.colorScheme;
      final surfaces = <Color>[
        theme.scaffoldBackgroundColor,
        scheme.surface,
        scheme.surfaceContainer,
        scheme.surfaceContainerHighest,
      ];

      for (final surface in surfaces) {
        expect(
          _contrast(scheme.onSurface, surface),
          greaterThanOrEqualTo(4.5),
          reason: 'onSurface on ${surface.toARGB32().toRadixString(16)}',
        );
        expect(
          _contrast(scheme.onSurfaceVariant, surface),
          greaterThanOrEqualTo(4.5),
          reason: 'onSurfaceVariant on ${surface.toARGB32().toRadixString(16)}',
        );
      }
    }
  });

  test('primary and outline clear 3:1 for non-text UI', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final scheme = theme.colorScheme;
      for (final surface in [theme.scaffoldBackgroundColor, scheme.surface]) {
        expect(_contrast(scheme.primary, surface), greaterThanOrEqualTo(3.0));
        expect(_contrast(scheme.outline, surface), greaterThanOrEqualTo(3.0));
      }
    }
  });

  test('container pairs keep their foreground legible', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final scheme = theme.colorScheme;
      expect(
        _contrast(scheme.onPrimaryContainer, scheme.primaryContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(scheme.onSecondaryContainer, scheme.secondaryContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(scheme.onErrorContainer, scheme.errorContainer),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('dividers use outlineVariant so they read in dark mode', () {
    // `outline` sits close to the surface in dark; the divider needs the
    // lower-contrast-but-still-visible token that separates from it.
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(theme.dividerTheme.color, theme.colorScheme.outlineVariant);
    }
  });

  test('text and app bar foregrounds stay legible per brightness', () {
    // App bar titles are content, not actions, so both modes read onSurface.
    expect(
      AppTheme.light.appBarTheme.foregroundColor,
      AppTheme.light.colorScheme.onSurface,
    );
    expect(
      AppTheme.dark.appBarTheme.foregroundColor,
      AppTheme.dark.colorScheme.onSurface,
    );

    expect(
      AppTheme.light.textTheme.headlineSmall?.color,
      AppTheme.light.colorScheme.onSurface,
    );
    expect(
      AppTheme.dark.textTheme.headlineSmall?.color,
      AppTheme.dark.colorScheme.onSurface,
    );
  });

  test('buttons meet the 48dp Android minimum touch target', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(
        theme.filledButtonTheme.style?.minimumSize?.resolve({}),
        const Size(48, 48),
      );
      expect(
        theme.elevatedButtonTheme.style?.minimumSize?.resolve({}),
        const Size(48, 48),
      );
      expect(
        theme.outlinedButtonTheme.style?.minimumSize?.resolve({}),
        const Size(48, 48),
      );
      expect(
        theme.textButtonTheme.style?.minimumSize?.resolve({}),
        const Size(48, 48),
      );
      expect(
        theme.iconButtonTheme.style?.minimumSize?.resolve({}),
        const Size(48, 48),
      );
    }
  });

  test('cards share one radius across both brightnesses', () {
    final lightShape = AppTheme.light.cardTheme.shape;
    final darkShape = AppTheme.dark.cardTheme.shape;
    expect(lightShape, darkShape);
    expect((lightShape! as RoundedRectangleBorder).borderRadius, Radii.allMd);
  });

  group('semantic tones outside ColorScheme', () {
    test('success clears 4.5:1 as text on its container', () {
      for (final brightness in Brightness.values) {
        final on = AppColors.onSuccessContainerFor(brightness);
        final bg = AppColors.successContainerFor(brightness);
        expect(
          _contrast(on, bg),
          greaterThanOrEqualTo(4.5),
          reason: 'success $brightness',
        );
      }
    });

    test('warning clears 4.5:1 as text on its container', () {
      for (final brightness in Brightness.values) {
        expect(
          _contrast(
            AppColors.warningFor(brightness),
            AppColors.warningContainerFor(brightness),
          ),
          greaterThanOrEqualTo(4.5),
          reason: 'warning $brightness',
        );
      }
    });

    test('success and warning are distinguishable hues, not tints', () {
      expect(
        AppColors.successFor(Brightness.light),
        isNot(AppColors.warningFor(Brightness.light)),
      );
      expect(
        AppColors.successFor(Brightness.dark),
        isNot(AppColors.warningFor(Brightness.dark)),
      );
    });

    test('onSuccess differs from the success fill it sits on', () {
      // A tick drawn on a filled circle needs its own foreground; returning
      // the fill colour itself made the tick invisible.
      for (final brightness in Brightness.values) {
        expect(
          AppColors.onSuccessFor(brightness),
          isNot(AppColors.successFor(brightness)),
        );
      }
    });
  });
}
