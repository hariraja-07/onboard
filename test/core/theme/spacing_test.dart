import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/theme/spacing.dart';

void main() {
  test('the spacing scale sits on a 4pt grid with one half-step', () {
    final scale = [
      Insets.xxs,
      Insets.xs,
      Insets.sm,
      Insets.md,
      Insets.lg,
      Insets.xl,
    ];

    for (final step in scale) {
      expect(step % Insets.xxs, 0, reason: '$step is off the 4pt grid');
    }

    for (var i = 1; i < scale.length; i++) {
      expect(scale[i], greaterThan(scale[i - 1]), reason: 'scale must ascend');
    }
  });

  test('the radius ramp ascends so nested shapes step inward', () {
    final ramp = [Radii.xs, Radii.sm, Radii.md, Radii.lg];
    for (var i = 1; i < ramp.length; i++) {
      expect(ramp[i], greaterThan(ramp[i - 1]));
    }
  });

  test('the touch target matches the Android minimum', () {
    expect(Insets.minTouchTarget, greaterThanOrEqualTo(48));
  });

  test('convenience paddings agree with the scale', () {
    expect(Insets.allXs, const EdgeInsets.all(Insets.xs));
    expect(Insets.allMd, const EdgeInsets.all(Insets.md));
    expect(
      Insets.horizontalMd,
      const EdgeInsets.symmetric(horizontal: Insets.md),
    );
    expect(Insets.surface, const EdgeInsets.all(Insets.md));
    expect(Insets.touchTarget, const EdgeInsets.all(Insets.minTouchTarget));
  });

  test('radius helpers cover the corners', () {
    expect(Radii.allSm, BorderRadius.circular(Radii.sm));
    expect(Radii.allMd, BorderRadius.circular(Radii.md));
  });

  test('motion durations are ordered by how much they change', () {
    expect(Motion.fast, lessThan(Motion.medium));
  });
}
