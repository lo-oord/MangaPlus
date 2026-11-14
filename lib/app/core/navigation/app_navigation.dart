import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Central entry point for named navigation.
///
/// GetX stays the navigation framework; this helper only adds the behaviour a
/// tap-driven app needs and GetX does not provide out of the box: two taps on a
/// card (or a double tap on a notification) can enqueue the same route twice
/// within a few milliseconds, which pushes two identical screens and makes the
/// back button feel broken.
///
/// The guard is intentionally narrow:
/// * it never blocks a route that is different from the last one;
/// * it never blocks a route unless the previous push of the same route is still
///   inside [duplicateWindow] or it is already the current route;
/// * it keeps arguments, parameters and the returned future intact.
class AppNavigation {
  const AppNavigation._();

  /// Range in which a repeated push of the same route counts as a double tap.
  static const Duration duplicateWindow = Duration(milliseconds: 280);

  static String? _lastRoute;
  static DateTime? _lastAt;

  static Future<T?>? toNamed<T>(
    String route, {
    dynamic arguments,
    Map<String, String>? parameters,
    bool preventDuplicates = true,
  }) {
    if (!shouldNavigate(route)) return null;
    return Get.toNamed<T>(
      route,
      arguments: arguments,
      parameters: parameters,
      preventDuplicates: preventDuplicates,
    );
  }

  /// Decides whether [route] may be pushed now.
  ///
  /// [now] is injectable so the throttle can be tested without wall-clock
  /// waits.
  static bool shouldNavigate(String route, {DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    final alreadyOpen = Get.currentRoute == route;
    final repeated = _lastRoute == route &&
        _lastAt != null &&
        timestamp.difference(_lastAt!) < duplicateWindow;
    if (alreadyOpen || repeated) return false;
    _lastRoute = route;
    _lastAt = timestamp;
    return true;
  }

  @visibleForTesting
  static void resetThrottle() {
    _lastRoute = null;
    _lastAt = null;
  }
}
