import 'package:flutter/material.dart';

/// The single animation vocabulary of MangaPlus.
///
/// Every duration and curve used for feedback, interaction, page transitions
/// and overlays comes from here, so unrelated screens cannot invent their own
/// timing. Durations are split by purpose instead of by widget:
///
/// * [instant]  – state confirmation that must feel immediate (press release).
/// * [fast]     – small interactive feedback: chips, switches, icon swaps.
/// * [normal]   – standard UI motion: expansion, content switching, chrome.
/// * [slow]     – larger surface motion: navigation bar indicator.
/// * [page]     – route transitions.
///
/// All helpers take a [BuildContext] and collapse to zero when the platform asks
/// for reduced motion, so accessibility never depends on each caller
/// remembering `MediaQuery.disableAnimations`.
class AppMotion {
  const AppMotion._();

  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
  static const Duration page = Duration(milliseconds: 260);
  static const Duration chrome = Duration(milliseconds: 200);
  static const Duration entrance = Duration(milliseconds: 320);

  /// Enter and exit easing. Decelerating on the way in, accelerating out.
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve standard = Curves.easeInOutCubic;

  /// Material 3 emphasised easing, used for route and overlay transitions.
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Scale applied while a control is pressed, and the opacity used for
  /// pressed icon-only controls.
  static const double pressedScale = .97;

  /// Vertical travel of an entering section, as a fraction of its height.
  static const double entranceOffset = .04;

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Returns [duration] unless the platform requested reduced motion.
  static Duration effective(BuildContext context, Duration duration) =>
      reduceMotion(context) ? Duration.zero : duration;

  /// Returns [curve] unless motion is reduced (the caller usually pairs this
  /// with [effective]).
  static Curve curve(BuildContext context, Curve curve) =>
      reduceMotion(context) ? Curves.linear : curve;

  /// Scale for press feedback on the current platform.
  static double scaleFor(BuildContext context) =>
      reduceMotion(context) ? 1 : pressedScale;
}
