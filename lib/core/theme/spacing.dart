import 'package:flutter/widgets.dart';

/// Spacing, radius, and touch-target tokens.
///
/// The scale is a 4pt grid with a half-step at 12 for cases where 8 reads too
/// tight and 16 reads too loose. Anything not on this ramp is almost always a
/// magic number that accumulated while spacing a card by hand.
abstract final class Insets {
  Insets._();

  /// 4dp. Hairline separation, icon-to-label inside a dense control.
  static const double xxs = 4;

  /// 8dp. Between related elements: label and its value, chip and its icon.
  static const double xs = 8;

  /// 12dp. Inside compact controls and between tightly coupled rows.
  static const double sm = 12;

  /// 16dp. The default. Card padding and gaps between blocks of content.
  static const double md = 16;

  /// 24dp. Between unrelated sections and around a screen's main content.
  static const double lg = 24;

  /// 32dp. Above a page title or below a last element that needs breathing room.
  static const double xl = 32;

  /// 48dp. Minimum height for anything tappable. Also the Android minimum.
  static const double minTouchTarget = 48;

  static const EdgeInsets allXs = EdgeInsets.all(xs);
  static const EdgeInsets allSm = EdgeInsets.all(sm);
  static const EdgeInsets allMd = EdgeInsets.all(md);
  static const EdgeInsets allLg = EdgeInsets.all(lg);

  /// Horizontal page gutter used by list and form screens.
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);

  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);

  /// Vertical rhythm between stacked cards or form fields.
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);

  /// Pads a control out to the platform minimum without changing its content.
  static const EdgeInsets touchTarget = EdgeInsets.all(minTouchTarget);

  /// Content padding for a raised surface: card, dialog, or bottom sheet.
  static const EdgeInsets surface = EdgeInsets.all(md);
}

/// Corner radius ramp.
///
/// Shapes step inward as they nest, so a chip inside a card reads as
/// belonging to it rather than competing with the card's own corner.
abstract final class Radii {
  Radii._();

  /// 8dp. Small elements: badges, chips, thumbnails.
  static const double xs = 8;

  /// 12dp. Buttons and inputs.
  static const double sm = 12;

  /// 16dp. Cards and sheets.
  static const double md = 16;

  /// 20dp. Full-screen dialogs and large panels.
  static const double lg = 20;

  static const BorderRadius allXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius allSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius allMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius allLg = BorderRadius.all(Radius.circular(lg));
}

/// Motion durations, so a dismissal doesn't feel slower than a selection.
abstract final class Motion {
  Motion._();

  /// Colour and state changes. Short enough not to be noticed.
  static const Duration fast = Duration(milliseconds: 150);

  /// Sheets, dialogs, and anything that changes what occupies the screen.
  static const Duration medium = Duration(milliseconds: 250);
}
