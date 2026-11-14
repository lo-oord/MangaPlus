import 'package:flutter/widgets.dart';

/// Spacing scale shared by every screen and component.
///
/// Screens should compose layouts from these steps instead of inventing values
/// such as 9, 13 or 18. The scale is a 4 px grid so vertical rhythm stays even
/// across unrelated screens.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;

  /// Horizontal inset every screen uses for its content column.
  static const double screen = 16;

  /// Gap between two content sections.
  static const double section = 24;

  /// Gap between a section heading and its card or list.
  static const double heading = 8;

  static const EdgeInsets screenHorizontal =
      EdgeInsets.symmetric(horizontal: screen);

  /// Default padding for a scrolling screen body.
  static const EdgeInsets pageInsets =
      EdgeInsets.fromLTRB(screen, xs, screen, xl);

  /// Padding inside a card or a grouped container.
  static const EdgeInsets cardInsets = EdgeInsets.all(md);

  /// List padding that keeps the last row clear of the floating navigation bar.
  static const EdgeInsets shellListInsets =
      EdgeInsets.fromLTRB(screen, xs, screen, shellBottom);

  static const double shellBottom = 28;

  static const SizedBox gapXxs = SizedBox(height: xxs);
  static const SizedBox gapXs = SizedBox(height: xs);
  static const SizedBox gapSm = SizedBox(height: sm);
  static const SizedBox gapMd = SizedBox(height: md);
  static const SizedBox gapLg = SizedBox(height: lg);
  static const SizedBox gapXl = SizedBox(height: xl);
}

/// Corner radii. A single set keeps cards, dialogs, sheets and chips visually
/// related instead of each screen choosing its own rounding.
class AppRadii {
  const AppRadii._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 26;

  /// Fully rounded chips, avatars and pills.
  static const double pill = 999;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}

/// Fixed sizes shared by controls, icons and bars.
class AppSizes {
  const AppSizes._();

  /// Height of a primary or secondary button.
  static const double controlHeight = 48;

  /// Height of a compact action (chip-sized or inline).
  static const double compactControlHeight = 38;

  /// Minimum touch target; never render an interactive control smaller.
  static const double touchTarget = 48;

  static const double iconSm = 16;
  static const double icon = 20;
  static const double iconMd = 22;
  static const double iconLg = 26;

  static const double appBarHeight = 60;
  static const double navBarHeight = 72;

  /// Maximum readable width for long-form content on tablets.
  static const double contentMaxWidth = 720;
}

